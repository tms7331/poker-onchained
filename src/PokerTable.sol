// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;
import "forge-std/console.sol";
import {PokerLogic} from "./PokerLogic.sol";
import {CardDealer} from "./CardDealer.sol";
import {LookupTables} from "./LookupTables.sol";

contract PokerTable is PokerLogic {
    // Core table values...
    uint public tableId;
    uint public handId;

    uint public smallBlind;
    uint public bigBlind;
    uint public minBuyin;
    uint public maxBuyin;
    uint8 public numSeats;

    // Player data we need:
    address[9] public plrActionAddr;
    address[9] public plrOwnerAddr;
    uint[9] public plrStack;
    bool[9] public plrInHand;
    bool[9] public plrSittingOut;
    bool[9] public plrAutoPost;
    uint[9] public plrBetStreet;
    uint[9] public plrBetHand;
    uint16[9] public plrShowdownVal;
    // Temporary solution - holecards fully public until we integrate coprocessor
    uint8[9] public plrHolecardsA;
    uint8[9] public plrHolecardsB;
    // Temporary solution - holecards fully public until we integrate coprocessor
    CardDealer private cardDealer;
    LookupTables private lookupTables;
    uint8 public flop0;
    uint8 public flop1;
    uint8 public flop2;
    uint8 public turn;
    uint8 public river;

    // Table data we need:
    HandStage public handStage;
    uint8 public button;
    uint8 public whoseTurn;
    uint8 public closingActionCount;
    // The largest amount any player has put in on a given street
    uint public maxBetThisStreet;
    uint public lastRaiseAmount;

    bool public actionComplete;

    uint32[] private primes = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41];

    constructor(
        uint _tableId,
        uint _smallBlind,
        uint _bigBlind,
        uint _minBuyin,
        uint _maxBuyin,
        uint8 _numSeats,
        address _lookupTableAddr
    ) {
        // Issue is - tableId must be unique
        tableId = _tableId;
        smallBlind = _smallBlind;
        bigBlind = _bigBlind;
        // TODO - add assertions for min/max buyins
        minBuyin = _minBuyin;
        maxBuyin = _maxBuyin;
        require(
            _numSeats == 2 || _numSeats == 6 || _numSeats == 9,
            "Invalid number of seats!"
        );
        numSeats = _numSeats;
        cardDealer = new CardDealer();
        lookupTables = LookupTables(_lookupTableAddr);
    }

    function _depositOk(
        uint stackCurr,
        uint depositAmount
    ) internal view returns (bool) {
        // As long as deposit keeps player's stack in range [minBuyin, maxBuyin] it's ok
        uint stackNew = stackCurr + depositAmount;
        return stackNew >= minBuyin && stackNew <= maxBuyin;
    }

    function joinTable(
        uint8 seatI,
        address actionAddr,
        uint depositAmount,
        bool autoPost
    ) external {
        require(seatI >= 0 && seatI < numSeats, "Invalid seat!");
        // TODO - think through edge cases if they join with address of 0, maybe it's ok
        require(actionAddr != address(0), "Invalid action address!");
        // Seat must be available and player must not be already joined
        require(plrActionAddr[seatI] == address(0), "Seat already taken!");
        // we could store a mapping of players for O(1) instead, is it worth it?
        for (uint256 i = 0; i < numSeats; i++) {
            require(plrOwnerAddr[i] != msg.sender, "Player already joined!");
        }
        require(_depositOk(0, depositAmount));

        plrActionAddr[seatI] = actionAddr;
        plrOwnerAddr[seatI] = msg.sender;
        plrStack[seatI] = depositAmount;
        plrHolecardsA[seatI] = 0;
        plrHolecardsB[seatI] = 0;
        plrAutoPost[seatI] = autoPost;
        plrBetStreet[seatI] = 0;
        plrShowdownVal[seatI] = 0;

        // TODO - need to initialize whoseTurn and button properly
        // HandStage handStage = _getTblHandStage(tblDataId);
        // TODO - more complicated than this!  In most situations they can't join until they're posting the BB!
        if (handStage != HandStage.SBPostStage) {
            plrInHand[seatI] = false;
        } else {
            plrInHand[seatI] = true;
            // TODO - any better way to fix whoseTurn?
            if (_getPlayerCount() == 3) {
                (whoseTurn, ) = _incrementWhoseTurn(
                    numSeats,
                    button,
                    plrInHand,
                    plrStack,
                    int8(closingActionCount),
                    false
                );
            }
        }

        // Assign button if it's the first player
        if (_getPlayerCount() == 1) {
            button = seatI;
            whoseTurn = seatI;
        }
    }

    function leaveTable(uint256 seatI) public {
        require(plrOwnerAddr[seatI] == msg.sender, "Player not at seat!");

        plrActionAddr[seatI] = address(0);
        plrOwnerAddr[seatI] = address(0);

        // TODO - send them their funds
        plrStack[seatI] = 0;
        //uint256 amountStack = plrStack[seatI];
        //(bool success, ) = msg.sender.call{value: amountStack}("");
        //require(success, "Transfer failed");
    }

    function rebuy(uint256 seatI, uint256 rebuyAmount) public {
        require(plrOwnerAddr[seatI] == msg.sender, "Player not at seat!");
        require(_depositOk(plrStack[seatI], rebuyAmount));
        plrStack[seatI] += rebuyAmount;
    }

    function sitInOut(uint256 seatI, bool sitOut) public {
        require(plrOwnerAddr[seatI] == msg.sender, "Player not at seat!");
        plrSittingOut[seatI] = sitOut;
    }

    function _getPlayerCount() internal view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < numSeats; i++) {
            if (plrActionAddr[i] != address(0)) {
                count++;
            }
        }
        return count;
    }

    function _nextStreet(bool isShowdown) internal {
        (whoseTurn, ) = _incrementWhoseTurn(
            numSeats,
            button,
            plrInHand,
            plrStack,
            int8(closingActionCount),
            isShowdown
        );

        closingActionCount = 0;
        maxBetThisStreet = 0;
        lastRaiseAmount = 0;

        // Reset player betting state
        for (uint256 i = 0; i < numSeats; i++) {
            plrBetHand[i] += plrBetStreet[i];
            plrBetStreet[i] = 0;
        }
    }

    function _nextHand() internal {
        closingActionCount = 0;
        maxBetThisStreet = 0;
        lastRaiseAmount = 0;

        actionComplete = false;

        flop0 = 0;
        flop1 = 0;
        flop2 = 0;
        turn = 0;
        river = 0;

        // Reset players
        for (uint i = 0; i < numSeats; i++) {
            if (plrActionAddr[i] != address(0)) {
                plrHolecardsA[i] = 0;
                plrHolecardsB[i] = 0;

                plrBetStreet[i] = 0;
                plrBetHand[i] = 0;
                plrShowdownVal[i] = 8000;

                // Handle bust and sitting out conditions
                if (plrStack[i] < bigBlind) {
                    plrSittingOut[i] = true;
                }
                if (!plrSittingOut[i]) {
                    plrInHand[i] = true;
                } else {
                    plrInHand[i] = false;
                }
            }
        }

        button = _incrementButton(button, plrSittingOut, plrStack);
        if (_getPlayerCount() == 2) {
            whoseTurn = button;
        } else {
            (whoseTurn, ) = _incrementWhoseTurn(
                numSeats,
                button,
                plrInHand,
                plrStack,
                int8(closingActionCount),
                false
            );
        }
        handId++;

        // Have to reset the deck after each hand
        cardDealer.reset();
    }

    function _processAction(
        ActionType actionType,
        uint8 seatI,
        uint256 amount
    ) internal view returns (HandState memory) {
        HandState memory hs = HandState({
            playerStack: plrStack[seatI],
            playerBetThisStreet: plrBetStreet[seatI],
            lastRaiseAmount: lastRaiseAmount,
            maxBetThisStreet: maxBetThisStreet
        });
        // Transition the hand state
        return _transitionHandState(hs, actionType, amount);
    }

    function actionCompleteCheck() internal returns (bool) {
        // Making two checks:
        // 1. If there's only one active player - everyone else has folded and hand is instantly over
        // 2. If there's only one player with stack > 0, that round needs to finish
        // (as if someone goes all-in, there is currently one player with stack > 0,
        // but the other player needs to act before we can fast forward through the other streets)
        if (!actionComplete) {
            uint inHandCount = 0;
            uint inHandStackCount = 0;
            for (uint256 i = 0; i < numSeats; i++) {
                if (plrActionAddr[i] != address(0)) {
                    if (plrInHand[i] == true) {
                        inHandCount++;
                        if (plrStack[i] > 0) {
                            inHandStackCount++;
                        }
                    }
                }
            }
            bool allFolded = inHandCount == 1;
            bool allAllIn = inHandStackCount <= 1 && closingActionCount == 0;
            actionComplete = allFolded || allAllIn;
        }
        return actionComplete;
    }

    function _dealHolecards() internal {
        for (uint256 i = 0; i < numSeats; i++) {
            if (plrInHand[i]) {
                uint[] memory cards = cardDealer.dealCards(2);
                plrHolecardsA[i] = uint8(cards[0]);
                plrHolecardsB[i] = uint8(cards[1]);
            }
        }
    }

    function _dealFlop() internal {
        uint[] memory cards = cardDealer.dealCards(3);
        flop0 = uint8(cards[0]);
        flop1 = uint8(cards[1]);
        flop2 = uint8(cards[2]);
    }

    function _dealTurn() internal {
        uint[] memory cards = cardDealer.dealCards(1);
        turn = uint8(cards[0]);
    }

    function _dealRiver() internal {
        uint[] memory cards = cardDealer.dealCards(1);
        river = uint8(cards[0]);
    }

    function _handStageOverCheck() internal view returns (bool) {
        return closingActionCount >= numSeats;
    }

    function _showdownCheck() internal returns (bool skipShowCards) {
        // Find players still in the hand
        skipShowCards = false;
        uint256[] memory stillInHand = new uint256[](numSeats);
        uint256 count = 0;

        for (uint256 i = 0; i < numSeats; i++) {
            if (plrInHand[i]) {
                stillInHand[count++] = i;
            }
        }

        // Sanity check - this should never happen
        require(count > 0, "No players in hand!");

        // If only one player remains, they win the pot automatically
        if (count == 1) {
            // Best possible SD value
            plrShowdownVal[stillInHand[0]] = 0;
            skipShowCards = true;
        } else {
            // _nextStreet(); was called after riverBetting, so whoseTurn should be set?
        }
    }

    // Below this point - try to refactor and move to logic file?

    function _transitionHandStage(HandStage hs) internal returns (HandStage) {
        // Blinds
        if (hs == HandStage.SBPostStage) {
            return HandStage.BBPostStage;
        } else if (hs == HandStage.BBPostStage) {
            return _transitionHandStage(HandStage.HolecardsDeal);
        }
        // Deal Holecards
        else if (hs == HandStage.HolecardsDeal) {
            _dealHolecards();
            return _transitionHandStage(HandStage.PreflopBetting);
        }
        // Preflop Betting
        else if (hs == HandStage.PreflopBetting) {
            if (_handStageOverCheck() || actionCompleteCheck()) {
                _nextStreet(false);
                return _transitionHandStage(HandStage.FlopDeal);
            }
            return hs;
        }
        // Deal Flop
        else if (hs == HandStage.FlopDeal) {
            _dealFlop();
            return _transitionHandStage(HandStage.FlopBetting);
        }
        // Flop Betting
        else if (hs == HandStage.FlopBetting) {
            if (_handStageOverCheck() || actionCompleteCheck()) {
                _nextStreet(false);
                return _transitionHandStage(HandStage.TurnDeal);
            }
            return hs;
        }
        // Deal Turn
        else if (hs == HandStage.TurnDeal) {
            _dealTurn();
            return _transitionHandStage(HandStage.TurnBetting);
        }
        // Turn Betting
        else if (hs == HandStage.TurnBetting) {
            if (_handStageOverCheck() || actionCompleteCheck()) {
                _nextStreet(false);
                return _transitionHandStage(HandStage.RiverDeal);
            }
            return hs;
        }
        // Deal River
        else if (hs == HandStage.RiverDeal) {
            _dealRiver();
            return _transitionHandStage(HandStage.RiverBetting);
        }
        // River Betting
        else if (hs == HandStage.RiverBetting) {
            if (_handStageOverCheck() || actionCompleteCheck()) {
                // Want to run this a final time to get the final bets calculated
                _nextStreet(true);
                return _transitionHandStage(HandStage.Showdown);
            }
            return hs;
        }
        // Showdown
        else if (hs == HandStage.Showdown) {
            // If only one player remains, nobody needs to call 'showCards'
            bool skipShowCards = _showdownCheck();
            if (skipShowCards) {
                return _transitionHandStage(HandStage.Settle);
            }
            return hs;
        }
        // Settle Stage
        else if (hs == HandStage.Settle) {
            Pot[] memory pots = _buildPots(numSeats, plrInHand, plrBetHand);
            _settle(pots);
            _nextHand();
            // Reset to post blinds stage
            return HandStage.SBPostStage;
        }
        // This will never get hit
        return hs;
    }

    function takeAction(
        ActionType actionType,
        uint8 seatI,
        uint256 amount
    ) external {
        require(whoseTurn == seatI, "Not your turn!");
        require(plrActionAddr[seatI] == msg.sender, "Not your seat!");

        // Ensure we can only do SB and BB posts at the right time
        if (actionType == ActionType.SBPost) {
            require(amount == smallBlind, "Invalid SB post amount!");
            require(
                handStage == HandStage.SBPostStage,
                "Not valid betting stage!"
            );
        } else if (actionType == ActionType.BBPost) {
            require(
                handStage == HandStage.BBPostStage,
                "Not valid betting stage!"
            );
            require(amount == bigBlind, "Invalid BB post amount!");
        } else {
            // Make sure it's not one of the other stages where we can't act
            require(
                handStage != HandStage.SBPostStage &&
                    handStage != HandStage.BBPostStage &&
                    handStage != HandStage.Showdown &&
                    handStage != HandStage.Settle,
                "Not valid betting stage!"
            );
        }
        HandState memory hsNew = _processAction(actionType, seatI, amount);

        plrStack[seatI] = hsNew.playerStack;
        plrBetStreet[seatI] = hsNew.playerBetThisStreet;
        maxBetThisStreet = hsNew.maxBetThisStreet;
        lastRaiseAmount = hsNew.lastRaiseAmount;

        if (actionType == ActionType.Fold) {
            plrInHand[seatI] = false;
        }

        // Should either be reset or incremented
        int8 closingActionCount_;
        if (
            actionType == ActionType.SBPost || actionType == ActionType.BBPost
        ) {
            closingActionCount_ = -1;
        } else if (actionType == ActionType.Bet) {
            closingActionCount_ = 0;
        } else {
            closingActionCount_ = int8(closingActionCount);
        }

        (whoseTurn, closingActionCount) = _incrementWhoseTurn(
            numSeats,
            whoseTurn,
            plrInHand,
            plrStack,
            closingActionCount_,
            false
        );

        handStage = _transitionHandStage(handStage);
    }

    function showCards(
        bool muck,
        bool isFlush,
        bool[7] memory useCards
    ) public {
        require(handStage == HandStage.Showdown, "Not showdown stage!");
        // TODO - if only one player they should not need to show cards
        // Fully trusting front end to feed in lookupVal, will replace with proof
        require(plrActionAddr[whoseTurn] == msg.sender, "Not your turn!");
        if (muck) {
            // Worst possible lookupVal - think we don't have to do this since it was initialized to this
            plrShowdownVal[whoseTurn] = 8000;
        } else {
            plrShowdownVal[whoseTurn] = _evaluate_hand(
                whoseTurn,
                useCards,
                isFlush
            );
        }

        (whoseTurn, closingActionCount) = _incrementWhoseTurn(
            numSeats,
            whoseTurn,
            plrInHand,
            plrStack,
            int8(closingActionCount),
            true
        );

        // call to increment handStage if it's last player!
        if (_handStageOverCheck()) {
            handStage = _transitionHandStage(HandStage.Settle);
        }
    }

    function _settle(Pot[] memory pots) internal {
        // TODO - lots of room for optimization here
        for (uint8 potI = 0; potI < pots.length; potI++) {
            Pot memory pot = pots[potI];

            uint256 winnerVal = 9000;
            bool[] memory isWinner = new bool[](numSeats);
            uint256 winnerCount = 0;
            for (uint256 i = 0; i < numSeats; i++) {
                // uint8 ev = pot.players[i] ? 1 : 0;
                if (pot.players[i] && plrShowdownVal[i] <= winnerVal) {
                    if (plrShowdownVal[i] < winnerVal) {
                        // Ugly but we have to clear out previous winners
                        for (uint256 j = 0; j < numSeats; j++) {
                            isWinner[j] = false;
                        }
                        winnerVal = plrShowdownVal[i];
                        isWinner[i] = true;
                        winnerCount = 1;
                    } else {
                        isWinner[i] = true;
                        winnerCount++;
                    }
                }
            }
            // Credit winnings
            for (uint8 i = 0; i < numSeats; i++) {
                if (isWinner[i]) {
                    uint256 winAmount = pot.amount / winnerCount;
                    plrStack[i] += winAmount;
                }
            }
        }
    }

    function _evaluate_hand(
        uint8 seatI,
        bool[7] memory use_cards,
        bool is_flush
    ) internal view returns (uint16) {
        uint bool_count = 0;
        uint8[7] memory cards = [
            plrHolecardsA[seatI],
            plrHolecardsB[seatI],
            flop0,
            flop1,
            flop2,
            turn,
            river
        ];

        uint32 lookupMult = 1;
        uint16 lookupVal;
        if (is_flush) {
            // TODO - clean up this logic
            uint8 suitCheck = 123;
            for (uint i = 0; i < 7; i++) {
                if (use_cards[i]) {
                    bool_count += 1;
                    uint8 suit = cards[i] / 13;
                    // Hacky way to verify all cards are of the same suit
                    if (suitCheck != 123) {
                        require(
                            suit == suitCheck,
                            "All cards must be of the same suit!"
                        );
                    } else {
                        suitCheck = suit;
                    }
                    lookupMult = lookupMult * primes[(cards[i] % 13)];
                }
            }
            lookupVal = lookupTables.lookupFlush(lookupMult);
        } else {
            for (uint i = 0; i < 7; i++) {
                if (use_cards[i]) {
                    bool_count += 1;
                    lookupMult = lookupMult * primes[(cards[i] % 13)];
                }
            }
            lookupVal = lookupTables.lookupBasic(lookupMult);
        }

        // Must use exactly 5 cards
        require(bool_count == 5, "Must use exactly 5 cards!");
        // This can only happen if they passed in an invalid lookupMult!
        require(lookupVal != 0, "Lookup value is 0!");
        return lookupVal;
    }
}
