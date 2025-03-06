// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "forge-std/console.sol";
import {PokerLogic} from "./PokerLogic.sol";

contract PokerTable is PokerLogic {
    // Core table values...
    uint public tableId;
    uint public smallBlind;
    uint public bigBlind;
    uint public minBuyin;
    uint public maxBuyin;
    uint public numSeats;

    uint public handId;

    // Player data we need:
    address[9] public plrActionAddr;
    address[9] public plrOwnerAddr;
    uint[9] public plrStack;
    bool[9] public plrInHand;
    bool[9] public plrAutoPost;
    uint[9] public plrBetStreet;
    uint[9] public plrShowdownVal;
    ActionType[9] public plrLastActionType;
    uint[9] public plrLastAmount;
    uint[9] public plrHolecards;

    // Table data we need:
    HandStage public handStage;
    uint8 public button;
    uint8 public whoseTurn;
    uint public facingBet;
    uint public lastRaise;
    uint public potInitial;
    int public closingActionCount;
    uint public lastAmount;
    ActionType public lastActionType;
    Pot[] public pots;

    struct TableInfo {
        uint _tableId;
        uint _smallBlind;
        uint _bigBlind;
        uint _minBuyin;
        uint _maxBuyin;
        uint _numSeats;
        int _numActivePlayers;
    }

    struct PlayerState {
        address addr;
        bool inHand;
        uint stack;
        uint betStreet;
        ActionType lastActionType;
        uint lastAmount;
    }

    struct TableState {
        HandStage handStage;
        uint8 button;
        uint facingBet;
        uint lastRaise;
    }

    constructor(
        uint _tableId,
        uint _smallBlind,
        uint _bigBlind,
        uint _minBuyin,
        uint _maxBuyin,
        uint _numSeats
    ) {
        // Issue is - tableId must be unique
        tableId = _tableId;
        smallBlind = _smallBlind;
        bigBlind = _bigBlind;
        // TODO - add assertions for min/max buyins
        minBuyin = _minBuyin;
        maxBuyin = _maxBuyin;
        numSeats = _numSeats;

        // plrActionAddr = new address[](_numSeats);
        // plrOwnerAddr = new address[](_numSeats);
        // plrStack = new uint[](_numSeats);
        // plrInHand = new bool[](_numSeats);
        // plrBetStreet = new uint[](_numSeats);
        // plrShowdownVal = new uint[](_numSeats);
        // plrLastActionType = new ActionType[](_numSeats);
        // plrLastAmount = new uint[](_numSeats);
        // plrHolecards = new uint[](_numSeats);
    }

    function _depositOk(
        uint stackCurr,
        uint depositAmount
    ) internal view returns (bool) {
        // As long as deposit keeps player's stack in range [minBuyin, maxBuyin] it's ok
        uint stackNew = stackCurr = depositAmount;
        return stackNew >= minBuyin && stackNew <= maxBuyin;
    }

    function joinTable(
        uint8 seatI,
        address actionAddr,
        uint depositAmount,
        bool autoPost
    ) external {
        // TODOTODO - check these...
        // assert 0 <= seat_i <= self.num_seats - 1, "Invalid seat_i!"
        //   assert self.seats[seat_i] == None, "seat_i taken!"
        //   assert address not in self.player_to_seat, "Player already joined!"
        //   assert (
        //       self.min_buyin <= deposit_amount <= self.max_buyin
        //   ), "Invalid deposit amount!"

        require(seatI >= 0 && seatI < numSeats, "Invalid seat!");

        // Make sure it's ok for them to join (seat available)
        require(plrActionAddr[seatI] == address(0));
        // Prevent player from joining multiple times - more efficient way to do this?
        // TODO - reenable this, have to figure out play...

        for (uint256 i = 0; i < numSeats; i++) {
            require(plrOwnerAddr[i] != msg.sender, "Player already joined!");
        }

        require(
            depositAmount >= minBuyin && depositAmount <= maxBuyin,
            "Invalid deposit amount!"
        );

        // Make sure their deposit amount is in bounds
        require(_depositOk(0, depositAmount));

        plrActionAddr[seatI] = actionAddr;
        plrOwnerAddr[seatI] = msg.sender;
        plrStack[seatI] = depositAmount;
        plrHolecards[seatI] = 53;
        plrAutoPost[seatI] = autoPost;
        plrBetStreet[seatI] = 0;
        plrShowdownVal[seatI] = 0;
        plrLastActionType[seatI] = ActionType.Null;
        plrLastAmount[seatI] = 0;

        // TODO - need to initialize whoseTurn and button properly
        // HandStage handStage = _getTblHandStage(tblDataId);
        // if (handStage != HandStage.SBPostStage) {
        //     _setPlrInHand(plrDataId, false);
        // } else {
        //     _setPlrInHand(plrDataId, true);
        // }

        // // Assign button if it's the first player
        // if (getPlayerCount() == 1) {
        //     _setTblButton(tblDataId, seatI);
        //     _setTblWhoseTurn(tblDataId, seatI);
        // }
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
        uint stack = plrStack[seatI];
        uint256 newStack = stack + rebuyAmount;
        require(
            newStack >= minBuyin && newStack <= maxBuyin,
            "Invalid rebuy amount!"
        );

        plrStack[seatI] = newStack;
    }

    function getPlayerCount() internal view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < numSeats; i++) {
            if (plrActionAddr[i] == address(0)) {
                count++;
            }
        }
        return count;
    }

    function _sort(uint[] memory data) internal pure returns (uint[] memory) {
        uint n = data.length;
        for (uint i = 0; i < n; i++) {
            for (uint j = 0; j < n - i - 1; j++) {
                if (data[j] > data[j + 1]) {
                    // Swap the elements
                    uint temp = data[j];
                    data[j] = data[j + 1];
                    data[j + 1] = temp;
                }
            }
        }
        return data;
    }

    function _nextStreet() internal {
        // Set the turn to the next player
        // TODO - can we improve this logic?  Is logic flawed?
        if (button == 0) {
            button = uint8(numSeats - 1);
        } else {
            button = uint8((button - 1) % numSeats);
        }

        // _setTblWhoseTurn(tblDataId, button);
        (whoseTurn, closingActionCount) = _incrementWhoseTurn(
            whoseTurn,
            plrInHand,
            plrStack,
            closingActionCount
        );
        // whoseTurn = button;
        // uint8 whoseTurn = _getTblWhoseTurn(tblDataId);

        // Reset table betting state
        facingBet = 0;
        lastRaise = 0;
        lastActionType = ActionType.Null;
        lastAmount = 0;
        closingActionCount = 0;

        uint potInitialNew = 0;

        uint256 potInitialLeft = potInitialNew;
        uint numPots = pots.length;
        for (uint256 i = 0; i < numPots; i++) {
            Pot memory pot = pots[i];
            potInitialLeft -= pot.amount;
        }

        // Track the amounts each player bet on this street
        uint256[] memory betThisStreetAmounts = new uint256[](numSeats);
        bool[] memory inHand = new bool[](numSeats);
        uint256[] memory allInAmountsSorted = new uint256[](numSeats);
        bool allInPlayer = false;
        for (uint256 i = 0; i < numSeats; i++) {
            inHand[i] = plrInHand[i];
            betThisStreetAmounts[i] = plrBetStreet[i];
            if (betThisStreetAmounts[i] > 0 && plrStack[i] == 0) {
                allInPlayer = true;
                allInAmountsSorted[i] = betThisStreetAmounts[i];
            }
        }

        if (allInPlayer) {
            // If our scenario was
            // [50, 60, 40, 50] (bet this street)
            // [true, true, true, false] (in hand)
            // [50, 0, 40, 0] (all-in amounts)
            // [0, 19, 0, 50] (stacks remaining)
            // We want to end up with:
            // 120 (40*4) with players 0, 1, 2
            // 30 (10*3) with players 0, 1
            allInAmountsSorted = _sort(allInAmountsSorted);
            // And clean up a arrays, from [0, 0, 40, 50] we want: [0, 0, 40, 10]
            for (uint256 i = 0; i < numSeats; i++) {
                for (uint256 j = i + 1; j < numSeats; j++) {
                    allInAmountsSorted[j] -= allInAmountsSorted[i];
                }
            }

            for (uint256 i = 0; i < numSeats; i++) {
                // With the arrays/sorting lots of the pots will be 0, so skip them
                if (allInAmountsSorted[i] == 0) {
                    continue;
                }

                uint256 amount = allInAmountsSorted[i];
                // Just for the first hand - should include this
                uint256 potAmount = potInitialLeft;
                potInitialLeft = 0;

                Pot memory sidePot;
                // So we have to update -
                sidePot.players = new bool[](numSeats);
                for (uint256 j = 0; j < numSeats; j++) {
                    if (betThisStreetAmounts[j] >= amount) {
                        potAmount += amount;
                        betThisStreetAmounts[j] -= amount;
                        if (inHand[j]) {
                            sidePot.players[j] = true;
                        }
                    } else {
                        potAmount += betThisStreetAmounts[j];
                        betThisStreetAmounts[j] = 0;
                    }
                }
                sidePot.amount = potAmount;

                // uint potI = pots.length;
                pots.push(sidePot);
            }
        }

        // Reset player betting state
        for (uint256 i = 0; i < numSeats; i++) {
            potInitialNew += plrBetStreet[i];
            plrBetStreet[i] = 0;
            plrLastActionType[i] = ActionType.Null;
            plrLastAmount[i] = 0;
        }

        potInitial = potInitialNew;
    }

    function _nextHand() internal {
        potInitial = 0;
        closingActionCount = 0;
        facingBet = 0;
        lastRaise = 0;
        lastActionType = ActionType.Null;
        lastAmount = 0;

        // _setTblFlop(tblDataId, 53, 53, 53);
        // _setTblTurn(tblDataId, 53);
        // _setTblRiver(tblDataId, 53);
        // _setNumPots(tblDataId, 0);

        // Reset players
        for (uint i = 0; i < numSeats; i++) {
            if (plrActionAddr[i] != address(0)) {
                plrHolecards[i] = 53;
                plrInHand[i] = true;
                plrLastActionType[i] = ActionType.Null;
                plrLastAmount[i] = 0;

                plrBetStreet[i] = 0;
                plrShowdownVal[i] = 8000;

                // Handle bust and sitting out conditions
                // if (plrStack[i] <= smallBlind) {
                //     plrSittingOut[i] = true;
                // }
                // TODO - what was this logic?  Why can't have both?
                // ) {
                //     seats[seat_i].inHand = false;
                //     seats[seat_i].sittingOut = true;
                // } else {
                //     seats[seat_i].inHand = true;
                //     seats[seat_i].sittingOut = false;
                // }
            }
        }

        button = (button + 1) % uint8(numSeats);
        // uint8 button = _getTblButton(tblDataId);
        // _setTblWhoseTurn(tblDataId, button);
        handId++;
    }

    function _processAction(
        ActionType actionType,
        uint8 seatI,
        uint256 amount
    ) internal view returns (HandState memory) {
        address player = msg.sender;
        // Group player-related variables into a struct
        PlayerState memory playerState = PlayerState({
            addr: plrActionAddr[seatI],
            inHand: plrInHand[seatI],
            stack: plrStack[seatI],
            betStreet: plrBetStreet[seatI],
            // Switching it to use table one now
            // lastActionType: _getPlrLastActionType(plrDataId),
            lastActionType: lastActionType,
            lastAmount: plrLastAmount[seatI]
        });

        require(playerState.addr == player, "Player not at seat!");
        require(playerState.inHand, "Player not in hand!");

        // Create a HandState struct to manage hand transitions
        HandState memory hsNew;

        // Group table-related variables into a struct
        TableState memory tableState = TableState({
            handStage: handStage,
            button: button,
            facingBet: facingBet,
            lastRaise: lastRaise // Assuming lastRaise comes from the same source
        });
        HandState memory hs = HandState({
            playerStack: playerState.stack,
            playerBetStreet: playerState.betStreet,
            handStage: tableState.handStage,
            lastActionType: playerState.lastActionType,
            lastActionAmount: playerState.lastAmount,
            transitionNextStreet: false,
            facingBet: tableState.facingBet,
            lastRaise: tableState.lastRaise,
            button: tableState.button
        });

        // Transition the hand state
        hsNew = _transitionHandState(hs, actionType, amount);
        return hsNew;
    }

    function allIn() internal view returns (bool) {
        // TODO - definitely cleaner logic for this, look to refactor
        uint count = 0;
        for (uint256 i = 0; i < numSeats; i++) {
            bool cond1 = plrActionAddr[i] != address(0);
            bool cond2 = plrInHand[i] == true;
            bool cond3 = plrStack[i] > 0;
            if (cond1 && cond2 && cond3) {
                count++;
            }
        }
        return count <= 1 && closingActionCount == 0;
    }

    function allFolded() internal view returns (bool) {
        // TODO - definitely cleaner logic for this, look to refactor
        uint count = 0;
        for (uint256 i = 0; i < numSeats; i++) {
            if (plrActionAddr[i] != address(0)) {
                if (plrInHand[i] == true) {
                    count++;
                }
            }
        }
        return count == 1;
    }

    function _getNewCards(
        uint numCards
    ) internal pure returns (uint8[] memory) {
        uint8[] memory retCards = new uint8[](numCards);
        for (uint i = 0; i < numCards; i++) {
            retCards[i] = 1;
        }
        return retCards;
    }

    function _dealHolecards() internal {}

    function _dealFlop() internal {}

    function _dealTurn() internal {}

    function _dealRiver() internal {}

    function _handStageOverCheck() internal view returns (bool) {
        return (closingActionCount > 0) && uint(closingActionCount) >= numSeats;
    }

    function _getShowdownVal(
        uint8[] memory cards
    ) internal pure returns (uint) {
        // TODO - !?!?!?!  Why did we have this logic here?
        require(cards.length == 7, "Must provide 7 cards.");
        return 22;
    }

    function _showdown() internal {
        // Create action struct for showdown event
        // uint256[] memory showdownCards = new uint256[](numSeats);

        // Find players still in the hand
        uint256[] memory stillInHand = new uint256[](numSeats);
        uint256 count = 0;

        for (uint256 i = 0; i < numSeats; i++) {
            if (plrInHand[i]) {
                stillInHand[count++] = i;
            }
        }

        // If only one player remains, they win the pot automatically
        if (count == 1) {
            // Best possible SD value
            plrShowdownVal[stillInHand[0]] = 0;
        } else {
            // How are we doing evaluation?
            // uint8[] memory cards = new uint8[](7);
            // (cards[0], cards[1], cards[2]) = (flop0, flop1, flop2);
            // cards[3] = turn;
            // cards[4] = river;
            // for (uint256 i = 0; i < numSeats; i++) {
            //     if (plrInHand[i]) {
            //         (cards[5], cards[6]) = (plrHolecards[i], plrHolecards[i]);
            //         uint showdownVal = _getShowdownVal(cards);
            //         plrShowdownVal[i] = showdownVal;
            //     }
            // }
        }
    }

    // Maybe move to other file?

    function _transitionHandStage(HandStage hs) internal {
        // Blinds
        if (hs == HandStage.SBPostStage) {
            handStage = HandStage.BBPostStage;
            _transitionHandStage(HandStage.BBPostStage);
            return;
        } else if (hs == HandStage.BBPostStage) {
            handStage = HandStage.HolecardsDeal;
            _transitionHandStage(HandStage.HolecardsDeal);
            return;
        }
        // Deal Holecards
        else if (hs == HandStage.HolecardsDeal) {
            // _dealHolecards();
            handStage = HandStage.PreflopBetting;
            _transitionHandStage(HandStage.PreflopBetting);
            return;
        }
        // Preflop Betting
        else if (hs == HandStage.PreflopBetting) {
            if (_handStageOverCheck() || allFolded() || allIn()) {
                _nextStreet();
                handStage = HandStage.FlopDeal;
                _transitionHandStage(HandStage.FlopDeal);
            }
            return;
        }
        // Deal Flop
        else if (hs == HandStage.FlopDeal) {
            // _dealFlop();
            handStage = HandStage.FlopBetting;
            _transitionHandStage(HandStage.FlopBetting);
            return;
        }
        // Flop Betting
        else if (hs == HandStage.FlopBetting) {
            if (_handStageOverCheck() || allFolded() || allIn()) {
                _nextStreet();
                handStage = HandStage.TurnDeal;
                _transitionHandStage(HandStage.TurnDeal);
            }
            return;
        }
        // Deal Turn
        else if (hs == HandStage.TurnDeal) {
            // _dealTurn();
            handStage = HandStage.TurnBetting;
            _transitionHandStage(HandStage.TurnBetting);
            return;
        }
        // Turn Betting
        else if (hs == HandStage.TurnBetting) {
            if (_handStageOverCheck() || allFolded() || allIn()) {
                _nextStreet();
                handStage = HandStage.RiverDeal;
                _transitionHandStage(HandStage.RiverDeal);
            }
            return;
        }
        // Deal River
        else if (hs == HandStage.RiverDeal) {
            // _dealRiver();
            handStage = HandStage.RiverBetting;
            _transitionHandStage(HandStage.RiverBetting);
            return;
        }
        // River Betting
        else if (hs == HandStage.RiverBetting) {
            if (_handStageOverCheck() || allFolded() || allIn()) {
                handStage = HandStage.Showdown;
                _transitionHandStage(HandStage.Showdown);
            }
            return;
        }
        // Showdown
        else if (hs == HandStage.Showdown) {
            _showdown();
            handStage = HandStage.Settle;
            _transitionHandStage(HandStage.Settle);
            return;
        }
        // Settle Stage
        else if (hs == HandStage.Settle) {
            _settle(plrShowdownVal, pots);
            _nextHand();
            // Reset to post blinds stage
            handStage = HandStage.SBPostStage;
            return;
        }
    }

    function takeAction(
        ActionType actionType,
        uint8 seatI,
        uint256 amount
    ) external {
        require(whoseTurn == seatI, "Not your turn!");
        require(plrActionAddr[seatI] == msg.sender, "Not your seat!");

        HandState memory hsNew = _processAction(actionType, seatI, amount);

        // uint pot = potInitial;

        plrStack[seatI] = hsNew.playerStack;
        plrBetStreet[seatI] = hsNew.playerBetStreet;
        plrLastAmount[seatI] = amount;
        plrLastActionType[seatI] = actionType;
        if (actionType == ActionType.Fold) {
            plrInHand[seatI] = false;
        }

        facingBet = hsNew.facingBet;

        // Should either be reset or incremented
        if (
            actionType == ActionType.SBPost || actionType == ActionType.BBPost
        ) {
            closingActionCount = -1;
        } else if (actionType == ActionType.Bet) {
            closingActionCount = 0;
        }

        (whoseTurn, closingActionCount) = _incrementWhoseTurn(
            whoseTurn,
            plrInHand,
            plrStack,
            closingActionCount
        );
        lastRaise = hsNew.lastRaise;
        lastActionType = hsNew.lastActionType;
        lastAmount = hsNew.lastActionAmount;

        _transitionHandStage(handStage);
    }
}
