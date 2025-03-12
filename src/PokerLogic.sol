// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;
import {EnumsAndActions} from "./EnumsAndActions.sol";
import "forge-std/console.sol";

contract PokerLogic is EnumsAndActions {
    function _transitionHandState(
        HandState memory handState,
        ActionType actionType,
        uint amount
    ) internal pure returns (HandState memory) {
        HandState memory newHandState = handState;

        if (actionType == ActionType.SBPost) {
            // CHECKS:
            // we're at the proper stage
            require(
                handState.handStage == HandStage.SBPostStage,
                "Not SBPostStage!"
            );
            newHandState.facingBet = amount;
            newHandState.lastRaise = amount;
            newHandState.playerStack -= amount;
            newHandState.playerBetStreet = amount;
            newHandState.lastAmount = amount;
        } else if (actionType == ActionType.BBPost) {
            // CHECKS:
            // we're at the proper stage
            require(
                handState.lastActionType == ActionType.SBPost,
                "Not SBPost!"
            );
            require(
                handState.handStage == HandStage.BBPostStage,
                "Not BBPostStage!"
            );
            newHandState.facingBet = amount;
            newHandState.lastRaise = amount;
            newHandState.playerStack -= amount;
            newHandState.playerBetStreet = amount;
            newHandState.lastAmount = amount;
        } else if (actionType == ActionType.Bet) {
            // CHECKS:
            // facing action is valid
            // bet amount is valid
            require(
                handState.lastActionType == ActionType.Null ||
                    handState.lastActionType == ActionType.BBPost ||
                    handState.lastActionType == ActionType.Bet ||
                    handState.lastActionType == ActionType.Fold ||
                    handState.lastActionType == ActionType.Call ||
                    handState.lastActionType == ActionType.Check,
                "Not a valid bet!"
            );
            // TODO - need more careful check here, need to be tracking raise amounts
            require(amount > handState.facingBet, "Invalid bet amount");
            uint newBetAmount = amount - handState.playerBetStreet;
            newHandState.playerStack -= newBetAmount;
            newHandState.playerBetStreet = amount;
            newHandState.facingBet = amount;
            newHandState.lastRaise = amount - handState.facingBet;
            newHandState.lastAmount = newBetAmount;
        } else if (actionType == ActionType.Fold) {
            // CHECKS:
            // None?  But what if someone folds before they post SB/BB?
            newHandState.lastAmount = 0;
        } else if (actionType == ActionType.Call) {
            // CHECKS:
            // facing action is valid - easier to check for a facing bet?
            require(handState.facingBet > 0, "Not a valid call!");
            uint newCallAmount = handState.facingBet -
                handState.playerBetStreet;
            if (newCallAmount > handState.playerStack) {
                newCallAmount = handState.playerStack;
            }
            newHandState.playerStack -= newCallAmount;
            newHandState.playerBetStreet += newCallAmount;
            newHandState.lastAmount = newCallAmount;
        } else if (actionType == ActionType.Check) {
            // CHECKS:
            // Either facing amount is 0
            // Or we're BB and SB has called
            // TODO - would this let SB check?
            require(
                handState.facingBet == handState.playerBetStreet,
                "Not a valid check!"
            );
            newHandState.lastAmount = 0;
        }

        // We'll get an underflow if they don't have enough funds
        // require(newHandState.playerStack >= 0, "Insufficient funds");
        newHandState.lastActionType = actionType;

        return newHandState;
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

    function _buildPots(
        uint8 numSeats,
        bool[9] memory plrInHand,
        uint[9] memory plrBetHand
    ) internal pure returns (Pot[] memory pots) {
        uint[] memory sortedBets = new uint[](numSeats);
        for (uint i = 0; i < numSeats; i++) {
            sortedBets[i] = plrBetHand[i];
        }
        sortedBets = _sort(sortedBets);

        // Create pots array
        pots = new Pot[](numSeats);
        pots[0] = Pot({amount: 0, players: new bool[](numSeats)});

        uint potCount = 0;

        for (uint i = 0; i < numSeats; i++) {
            bool closePot = false;
            if (sortedBets[i] == 0) {
                continue;
            }
            // If it's [50, 100, 100], we need to end up with [0, 50, 50] after first iteration
            for (uint j = i + 1; j < numSeats; j++) {
                sortedBets[j] -= sortedBets[i];
            }

            // Now go through each player and add up for pot
            for (uint j = 0; j < numSeats; j++) {
                if (plrBetHand[j] > 0) {
                    // Sanity check during testing -
                    // Due to logic they should always have at least the amount
                    require(
                        plrBetHand[j] >= sortedBets[i],
                        "Invalid bet amount"
                    );
                    pots[potCount].amount += (sortedBets[i]);
                    plrBetHand[j] -= sortedBets[i];
                    if (plrInHand[j]) {
                        pots[potCount].players[j] = true;
                        // Only close pot if they were in the hand!
                        if (plrBetHand[j] == 0) {
                            closePot = true;
                        }
                    }
                }
            }
            if (closePot) {
                potCount++;
                if (potCount < numSeats) {
                    pots[potCount] = Pot({
                        amount: 0,
                        players: new bool[](numSeats)
                    });
                }
            }
        }

        // Create new array with correct size and copy pots
        Pot[] memory finalPots = new Pot[](potCount);
        for (uint i = 0; i < potCount; i++) {
            finalPots[i] = pots[i];
        }
        return finalPots;
    }

    function _incrementWhoseTurn(
        uint8 numSeats,
        uint8 whoseTurn,
        bool[9] memory inHand,
        uint[9] memory stacks,
        int closingActionCount,
        bool isShowdown
    ) internal pure returns (uint8, int) {
        // bool incremented = false;
        for (uint256 i = 1; i <= numSeats; i++) {
            // Go around the table in order, starting from whoever's turn it is
            uint256 seatI = (whoseTurn + i) % numSeats;
            closingActionCount++;

            // The player must be in the hand and have some funds
            if (inHand[seatI] && (isShowdown || stacks[seatI] > 0)) {
                whoseTurn = uint8(seatI);
                // incremented = true;
                break;
            }
        }

        // TODO - think it's possible to not increment if we have one player - make sure
        // require(incremented, "Failed to increment whoseTurn!");
        // TODO - is this a valid check?
        // require(closingActionCount <= (numSeats + 1), "Too high closingActionCount!");
        return (whoseTurn, closingActionCount);
    }

    function _incrementButton(
        uint8 button,
        bool[9] memory plrSittingOut,
        uint[9] memory stacks
    ) internal pure returns (uint8) {
        // TODO - what if there's only one player?
        // We'll iterate through seats and never break...
        uint8 numSeats = uint8(plrSittingOut.length);

        bool incremented = false;
        for (uint256 i = 1; i <= numSeats; i++) {
            uint256 seatI = (button + i) % numSeats;
            // The player must be active and have some funds
            if (!plrSittingOut[seatI] && stacks[seatI] > 0) {
                button = uint8(seatI);
                incremented = true;
                break;
            }
        }
        // Sanity check - we can handle this case but don't let it happen
        // without thinking through it
        require(incremented, "Failed to increment button!");

        return button;
    }
}
