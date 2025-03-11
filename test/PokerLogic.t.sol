// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {EnumsAndActions} from "../src/EnumsAndActions.sol";
import {PokerLogic} from "../src/PokerLogic.sol";

// Contract with all internal methods exposed for testing
contract PokerLogicHarness is PokerLogic {
    function exposed_buildPots(
        uint8 numSeats,
        bool[9] memory plrInHand,
        uint[9] memory plrBetHand
    ) public pure returns (EnumsAndActions.Pot[] memory) {
        return _buildPots(numSeats, plrInHand, plrBetHand);
    }
}

contract TestPokerLogic is Test, EnumsAndActions {
    PokerLogicHarness internal logic;

    function setUp() public {
        logic = new PokerLogicHarness();
    }

    function test_buildPotsAllIn() public {
        uint8 numSeats = 2;
        bool[9] memory plrInHand;
        uint[9] memory plrBetHand;
        uint[9] memory plrStack;

        // Set up scenario where:
        // Player1 bet 200 and is all-in
        // Player2 bet 250 and has stack remaining
        plrInHand[0] = true;
        plrInHand[1] = true;

        plrBetHand[0] = 200;
        plrBetHand[1] = 250;

        plrStack[0] = 0; // Player1 is all-in
        plrStack[1] = 50; // Player2 has stack remaining

        Pot[] memory pots = logic.exposed_buildPots(
            numSeats,
            plrInHand,
            plrBetHand
        );

        // Should create two pots:
        // 1. Main pot with both players for 400 (200 × 2)
        // 2. Side pot with only player2 for 50
        assertEq(pots.length, 2, "Should create two pots");

        // Check main pot
        assertEq(pots[0].amount, 400, "Main pot should be 400");
        assertTrue(pots[0].players[0], "Player1 should be in main pot");
        assertTrue(pots[0].players[1], "Player2 should be in main pot");

        // Check side pot
        assertEq(pots[1].amount, 50, "Side pot should be 50");
        assertFalse(pots[1].players[0], "Player1 should not be in side pot");
        assertTrue(pots[1].players[1], "Player2 should be in side pot");
    }

    function test_buildPotsFoldedPlayer() public {
        uint8 numSeats = 3;
        bool[9] memory plrInHand;
        uint[9] memory plrBetHand;
        uint[9] memory plrStack;

        // Set up scenario where:
        // Player1 bet 100 but folded
        // Player2 bet 150 and is in hand
        // Player3 bet 150 and is in hand
        plrInHand[0] = false; // Player1 folded
        plrInHand[1] = true; // Player2 in hand
        plrInHand[2] = true; // Player3 in hand

        plrBetHand[0] = 100;
        plrBetHand[1] = 150;
        plrBetHand[2] = 150;

        plrStack[0] = 900; // Remaining stacks don't matter for this test
        plrStack[1] = 850;
        plrStack[2] = 850;

        Pot[] memory pots = logic.exposed_buildPots(
            numSeats,
            plrInHand,
            plrBetHand
        );

        // Should create one pot of 400 total with only player2 and player3 eligible
        assertEq(pots.length, 1, "Should create one pot");
        assertEq(
            pots[0].amount,
            400,
            "Pot should contain all bets (100 + 150 + 150)"
        );

        // Check player eligibility
        assertFalse(pots[0].players[0], "Folded player should not be eligible");
        assertTrue(pots[0].players[1], "Player2 should be eligible");
        assertTrue(pots[0].players[2], "Player3 should be eligible");
    }
}
