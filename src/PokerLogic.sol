// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {EnumsAndActions} from "./EnumsAndActions.sol";

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
            newHandState.lastActionAmount = amount;
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
            newHandState.lastActionAmount = amount;
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
            newHandState.lastActionAmount = newBetAmount;
        } else if (actionType == ActionType.Fold) {
            // CHECKS:
            // None?  But what if someone folds before they post SB/BB?
            newHandState.lastActionAmount = 0;
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
            newHandState.lastActionAmount = newCallAmount;
        } else if (actionType == ActionType.Check) {
            // CHECKS:
            // facing action is valid (check, None)
            // easier to check on betsizes?
            // If we're BB and action goes SBPost, BBPost, call, we can check
            require(
                handState.lastActionType == ActionType.Check ||
                    handState.lastActionType == ActionType.Null ||
                    // TODO - refine this
                    handState.lastActionType == ActionType.Call,
                "Not a valid check!"
            );
            newHandState.lastActionAmount = 0;
        }

        // We'll get an underflow if they don't have enough funds
        // require(newHandState.playerStack >= 0, "Insufficient funds");
        newHandState.lastActionType = actionType;

        return newHandState;
    }

    function _settle(
        uint[9] memory plrShowdownVal,
        Pot[] memory pots
    ) internal pure {
        uint8 numSeats = uint8(plrShowdownVal.length);
        // ??????

        // uint handId = _getHandId(tblDataId);
        // uint256[] memory lookupVals = new uint256[](numSeats);
        // for (uint256 i = 0; i < numSeats; i++) {
        //     Suave.DataId plrDataId = plrDataIdArr[i];
        //     uint showdownVal = _getPlrShowdownVal(plrDataId);
        //     lookupVals[i] = showdownVal;
        // }
        // uint numPots = _getNumPots(tblDataId);

        for (uint8 potI = 0; potI < pots.length; potI++) {
            // Pot memory pot = _getTblPotsComplete(plrDataIdArr[potI]);
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
            // for (uint8 i = 0; i < numSeats; i++) {
            //     if (isWinner[i]) {
            //         uint256 amount = pot.amount / winnerCount;

            //         _setPlrStack(
            //             plrDataIdArr[i],
            //             _getPlrStack(plrDataIdArr[i]) + amount
            //         );
            //         emitSettle(tableId, handId, potI, amount, i);
            //         (uint8 card0, uint8 card1) = _getPlrHolecards(
            //             plrDataIdArr[i]
            //         );
            //         emitShowdown(tableId, handId, i, card0, card1);
            //     }
            // }
        }
    }

    function _calculateFinalPot(
        bool[9] memory inHand,
        uint[9] memory betThisStreetAmounts,
        Pot[] memory pots,
        uint256 potAmount
    ) internal pure returns (Pot memory) {
        // uint256 alreadyBet - do we need this?

        uint8 numSeats = uint8(inHand.length);
        bool[] memory streetPlayers = new bool[](numSeats);
        // uint256 playerCount = 0;

        // uint8[] memory activePlayers = new bool[](numSeats);

        // Identify players still in hand and with positive stack
        for (uint256 i = 0; i < numSeats; i++) {
            if (inHand[i] && betThisStreetAmounts[i] > 0) {
                streetPlayers[i] = true;
            }
        }

        // uint potAmount = _getTblPotInitial(tblDataId);

        // uint numPots = _getNumPots(tblDataId);
        uint numPots = pots.length;
        for (uint256 i = 0; i < numPots; i++) {
            Pot memory pot = pots[i];
            potAmount -= pot.amount;
        }
        for (uint256 i = 0; i < numSeats; i++) {
            // Suave.DataId plrDataId = plrDataIdArr[i];
            potAmount += betThisStreetAmounts[i];
        }

        Pot memory mainPot;
        mainPot.players = streetPlayers;
        mainPot.amount = potAmount;

        // uint potI = _getNumPots(tblDataId);
        // _setTblPotsComplete(plrDataIdArr[potI], mainPot);
        // _setNumPots(tblDataId, potI + 1);
        return mainPot;
    }

    function _incrementWhoseTurn(
        uint8 whoseTurn,
        bool[9] memory inHand,
        uint[9] memory stacks,
        int closingActionCount
    ) internal pure returns (uint8, int) {
        uint8 numSeats = uint8(inHand.length);
        bool incremented = false;
        // uint8 whoseTurn = _getTblWhoseTurn(tblDataId);
        // int closingActionCount = _getTblClosingActionCount(tblDataId);
        uint8 newWhoseTurn;

        for (uint256 i = 1; i <= numSeats; i++) {
            // Want to go around the table in order, starting from
            // whoever's turn it is
            uint256 seatI = (whoseTurn + i) % numSeats;
            // Suave.DataId plrDataId = plrDataIdArr[seatI];
            closingActionCount++;

            // if (_getPlrAddr(plrDataId) == address(0)) {
            //     continue;
            // }

            // The player must be in the hand and have some funds
            if (inHand[seatI] && stacks[seatI] > 0) {
                whoseTurn = uint8(seatI);
                incremented = true;
                break;
            }
        }

        // _setTblClosingActionCount(tblDataId, closingActionCount);
        // Optionally assert checks for debugging
        // require(closingActionCount <= (numSeats + 1), "Too high closingActionCount!");

        // require(incremented, "Failed to increment whoseTurn!");
        return (newWhoseTurn, closingActionCount);
    }

    function _incrementButton(
        uint8 button,
        bool[9] memory inHand,
        uint[9] memory stacks
    ) internal pure returns (uint8) {
        // Count active players
        uint256 activePlayers = 0;
        uint8 newButton;
        uint8 numSeats = uint8(inHand.length);
        for (uint256 i = 0; i < numSeats; i++) {
            // Suave.DataId plrDataId = plrDataIdArr[i];
            bool cond1 = inHand[i];
            bool cond2 = stacks[i] > 0;
            uint cond1u = cond1 ? 1 : 0;
            uint cond2u = cond2 ? 1 : 0;
            activePlayers += cond1u + cond2u;
            // if (
            //     _getPlrAddr(plrDataId) != address(0) &&
            //     _getPlrSittingOut(plrDataId) == false
            // ) {
            //     activePlayers++;
            // }
        }

        // Ensure at least two active players before moving the button
        if (activePlayers >= 2) {
            while (true) {
                newButton = (button + 1) % uint8(numSeats);
                // _setTblButton(tblDataId, newButton);
                // Suave.DataId plrDataId = plrDataIdArr[newButton];
                // address addr = _getPlrAddr(plrDataId);
                if (inHand[newButton] && stacks[newButton] > 0) {
                    break;
                }
            }
        }
        return newButton;
    }
}
