// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract EnumsAndActions {
    enum HandStage {
        SBPostStage,
        BBPostStage,
        HolecardsDeal,
        PreflopBetting,
        FlopDeal,
        FlopBetting,
        TurnDeal,
        TurnBetting,
        RiverDeal,
        RiverBetting,
        Showdown,
        Settle
    }

    enum ActionType {
        Null,
        SBPost,
        BBPost,
        Bet,
        Fold,
        Call,
        Check
    }

    struct Pot {
        uint256 amount;
        bool[] players;
    }

    struct Action {
        uint256 amount;
        ActionType act;
    }

    struct HandState {
        uint256 playerStack;
        uint256 playerBetStreet;
        HandStage handStage;
        ActionType lastActionType;
        uint256 lastActionAmount;
        bool transitionNextStreet;
        uint256 facingBet;
        uint256 lastRaise;
        uint256 button;
    }
}
