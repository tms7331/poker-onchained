// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {EnumsAndActions} from "../src/EnumsAndActions.sol";
import {NLHoldemTable} from "../src/NLHoldemTable.sol";

contract MockLookupTables {
    function lookupFlush(uint32) public pure returns (uint16) {
        return 1234;
    }

    function lookupBasic(uint32) public pure returns (uint16) {
        return 1234;
    }
}

// Contract with all internal methods exposed
contract NLHoldemTableHarness is NLHoldemTable {
    constructor(
        uint _tableId,
        uint _smallBlind,
        uint _bigBlind,
        uint _minBuyin,
        uint _maxBuyin,
        uint8 _numSeats,
        address _lookupTableAddr
    )
        NLHoldemTable(
            _tableId,
            _smallBlind,
            _bigBlind,
            _minBuyin,
            _maxBuyin,
            _numSeats,
            _lookupTableAddr
        )
    {}

    function setPlrPostedBlinds() public {
        for (uint8 i = 0; i < plrPostedBlinds.length; i++) {
            plrPostedBlinds[i] = int8(numSeats);
        }
    }

    function setWhoseTurn(uint8 seatI) public {
        whoseTurn = seatI;
    }

    function getWhoseTurn() public view returns (uint8) {
        return whoseTurn;
    }

    function exposed_recomputeInHand() public {
        _recomputeInHand();
    }
}

contract TestNLHoldemTable is Test {
    function deploy() internal returns (NLHoldemTableHarness) {
        MockLookupTables mockLookupTables = new MockLookupTables();
        uint tableId = 0;
        uint smallBlind = 1;
        uint bigBlind = 2;
        uint minBuyin = 20;
        uint maxBuyin = 200;
        uint8 numPlayers = 6;
        NLHoldemTableHarness pth = new NLHoldemTableHarness(
            tableId,
            smallBlind,
            bigBlind,
            minBuyin,
            maxBuyin,
            numPlayers,
            address(mockLookupTables)
        );
        return pth;
    }

    function test_initTable() public {
        // Just make sure basic contract initialization works
        deploy();
    }

    function test_joinTable() public {
        // Deploy the contract
        NLHoldemTableHarness pth = deploy();

        // Check that seat 2 is initially empty
        uint8 seatI = 2;
        assertEq(
            pth.plrActionAddr(seatI),
            address(0),
            "Seat 2 should be empty initially"
        );

        // Join the table at seat 2
        address plrAddr = address(0x123);
        uint depositAmount = 100;
        bool autoPost = false;
        vm.prank(plrAddr);
        pth.joinTable(seatI, plrAddr, depositAmount, autoPost);

        // Stack should be 100
        uint initialStack = pth.plrStack(seatI);
        assertEq(initialStack, 100, "Initial stack should be 100");

        // Check that seat 2 is now occupied by the new player
        assertEq(
            pth.plrActionAddr(seatI),
            plrAddr,
            "Seat 2 should be occupied by the new player"
        );
    }

    function test_noBadJoinTables() public {
        // Deploy the contract
        NLHoldemTableHarness pth = deploy();

        // Join at a seat that is not 0
        address player1 = address(0x123);
        uint8 seatI = 2;
        uint depositAmount = 100;
        bool autoPost = false;
        vm.prank(player1);
        pth.joinTable(seatI, player1, depositAmount, autoPost);

        // Same player Joining at same or different seat should fail
        vm.expectRevert();
        vm.prank(player1);
        pth.joinTable(seatI, player1, depositAmount, autoPost);

        vm.expectRevert();
        vm.prank(player1);
        pth.joinTable(0, player1, depositAmount, autoPost);

        // Different player joining at same seat should fail
        address player2 = address(0x456);
        vm.expectRevert();
        vm.prank(player2);
        pth.joinTable(seatI, player2, depositAmount, autoPost);

        // Joining at an out of bounds index should fail
        vm.expectRevert();
        vm.prank(player2);
        pth.joinTable(9, player2, depositAmount, autoPost);

        // Bad buying amount should fail
        vm.expectRevert();
        vm.prank(player2);
        pth.joinTable(1, player2, 100000, autoPost);

        vm.expectRevert();
        vm.prank(player2);
        pth.joinTable(1, player2, 1, autoPost);
    }

    function test_leaveTable() public {
        // Deploy the contract
        NLHoldemTableHarness pth = deploy();

        // Join the table at seat 0
        address plrAddr = address(0x123);
        uint8 seatI = 0;
        uint depositAmount = 100;
        bool autoPost = false;
        vm.prank(plrAddr);
        pth.joinTable(seatI, plrAddr, depositAmount, autoPost);

        // Check that seat 0 is occupied by the new player
        address player = pth.plrActionAddr(seatI);
        assertEq(
            player,
            plrAddr,
            "Seat 0 should be occupied by the new player"
        );

        // Leave the table
        vm.prank(plrAddr);
        pth.leaveTable(seatI);

        // Check that seat 0 is now empty
        player = pth.plrActionAddr(seatI);
        assertEq(player, address(0), "Seat 0 should be empty after leaving");
    }

    function test_rebuy() public {
        // Deploy the contract
        NLHoldemTableHarness pth = deploy();

        // Join the table at seat 0
        address plrAddr = address(0x123);
        uint8 seatI = 0;
        uint depositAmount = 100;
        bool autoPost = false;
        vm.prank(plrAddr);
        pth.joinTable(seatI, plrAddr, depositAmount, autoPost);

        // Check initial stack
        uint initialStack = pth.plrStack(seatI);
        assertEq(initialStack, 100, "Initial stack should be 100");

        // Rebuy for 100 more
        uint rebuyAmount = 100;
        vm.prank(plrAddr);
        pth.rebuy(seatI, rebuyAmount);

        // Check final stack
        uint finalStack = pth.plrStack(seatI);
        assertEq(finalStack, 200, "Final stack should be 200 after rebuy");
    }

    function test_postBlinds() public {
        // Deploy the contract
        NLHoldemTableHarness pth = deploy();

        // Set up players
        address p0 = address(0x123);
        address p1 = address(0x456);

        // Join table
        vm.prank(p0);
        pth.joinTable(0, p0, 100, false);

        vm.prank(p1);
        pth.joinTable(1, p1, 100, false);

        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.SBPostStage),
            "Hand stage should be SBPostStage"
        );

        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.SBPost, 0, 1);

        // Should now be BB's turn
        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.BBPostStage),
            "Hand stage should be BBPostStage"
        );

        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.BBPost, 1, 2);

        // Should now be preflop
        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.PreflopBetting),
            "Hand stage should be PreflopBetting"
        );

        // And make sure they got their holecards
        uint8 c0 = pth.plrHolecardsA(0);
        uint8 c1 = pth.plrHolecardsB(0);
        assertTrue((c0 != 0 || c1 != 0), "Player 0 should have got holecards");
        c0 = pth.plrHolecardsA(1);
        c1 = pth.plrHolecardsB(1);
        assertTrue((c0 != 0 || c1 != 0), "Player 1 should have got holecards");
        c0 = pth.plrHolecardsA(2);
        c1 = pth.plrHolecardsB(2);
        // Other players should NOT have gotten holecards
        assertTrue(
            (c0 == 0 && c1 == 0),
            "Player 2 should not have got holecards"
        );
    }

    function test_foldPreflop2p() public {
        // Deploy the contract
        NLHoldemTableHarness pth = deploy();

        // Set up players
        address p0 = address(0x123);
        address p1 = address(0x456);

        // Join table
        vm.prank(p0);
        pth.joinTable(0, p0, 100, false);

        vm.prank(p1);
        pth.joinTable(1, p1, 100, false);

        assertEq(uint(pth.button()), 0, "Button should be 0");
        assertEq(uint(pth.whoseTurn()), 0, "Whose turn should be 0");

        // Post blinds
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.SBPost, 0, 1);
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.BBPost, 1, 2);

        // Player 0 folds
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Fold, 0, 0);

        // Whose turn should be 1
        assertEq(uint(pth.button()), 1, "Button should be 1");
        assertEq(uint(pth.whoseTurn()), 1, "Whose turn should be 1");

        // Now post blinds for next hand
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.SBPost, 1, 1);
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.BBPost, 0, 2);

        // Player 1 folds
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Fold, 1, 0);

        // Whose turn should be 0
        assertEq(uint(pth.whoseTurn()), 0, "Whose turn should be 0");
        assertEq(uint(pth.button()), 0, "Button should be 0");
    }

    function test_foldPreflop3p() public {
        // Deploy the contract
        NLHoldemTableHarness pth = deploy();

        // Set up players
        address p0 = address(0x123);
        address p1 = address(0x456);
        address p2 = address(0x789);

        // Join table
        vm.prank(p0);
        pth.joinTable(0, p0, 100, false);
        vm.prank(p1);
        pth.joinTable(1, p1, 100, false);
        vm.prank(p2);
        pth.joinTable(2, p2, 100, false);

        // Have to manually make state look like an ongoing hand
        pth.setPlrPostedBlinds();
        pth.setWhoseTurn(1);
        pth.exposed_recomputeInHand();

        // Post blinds
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.SBPost, 1, 1);
        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.BBPost, 2, 2);

        // Player 0 folds
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Fold, 0, 0);
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Fold, 1, 0);

        // Whose turn should be 1
        assertEq(uint(pth.button()), 1, "Button should be 1");
        assertEq(uint(pth.whoseTurn()), 2, "Whose turn should be 1");

        // Now post blinds for next hand
        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.SBPost, 2, 1);
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.BBPost, 0, 2);

        // Player 1 folds
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Fold, 1, 0);
        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.Fold, 2, 0);

        // Whose turn should be 0
        assertEq(uint(pth.button()), 2, "Button should be 0");
        assertEq(uint(pth.whoseTurn()), 0, "Whose turn should be 0");
    }

    function test_basic2p() public {
        // Deploy the contract
        NLHoldemTableHarness pth = deploy();

        // Set up players
        address p0 = address(0x123);
        address p1 = address(0x456);

        // Join table
        vm.prank(p0);
        pth.joinTable(0, p0, 100, false);

        vm.prank(p1);
        pth.joinTable(1, p1, 100, false);

        // Post blinds
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.SBPost, 0, 1);
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.BBPost, 1, 2);

        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Call, 0, 0);
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Check, 1, 0);

        // Should be on flop
        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.FlopBetting),
            "Hand stage should be FlopBetting"
        );
        assertTrue(
            pth.flop0() != 0 || pth.flop1() != 0 || pth.flop2() != 0,
            "Flop should be dealt"
        );

        // Now it is p1's turn to go first!
        assertEq(uint(pth.whoseTurn()), 1, "Whose turn should be 1");

        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Bet, 1, 1);

        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Call, 0, 0);

        // Should be on turn
        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.TurnBetting),
            "Hand stage should be TurnBetting"
        );
        assertTrue(pth.turn() != 0, "Turn should be dealt");

        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Check, 1, 0);

        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Check, 0, 0);

        // Should be on river
        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.RiverBetting),
            "Hand stage should be RiverBetting"
        );
        assertTrue(pth.river() != 0, "River should be dealt");

        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Bet, 1, 1);
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Call, 0, 0);

        // Should be on showdown
        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.Showdown),
            "Hand stage should be Showdown"
        );

        // Showdown
        vm.prank(p1);
        pth.showCards(
            false,
            false,
            [true, true, true, true, true, false, false]
        );
        vm.prank(p0);
        pth.showCards(
            false,
            false,
            [true, true, true, true, true, false, false]
        );

        // Should be on SBPostStage
        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.SBPostStage),
            "Hand stage should be SBPostStage"
        );
    }

    function test_thirdHand() public {
        // Make sure button resets to 0 on third hand
        NLHoldemTableHarness pth = deploy();

        // Set up players
        address p0 = address(0x123);
        address p1 = address(0x456);

        // Join table
        vm.prank(p0);
        pth.joinTable(0, p0, 100, false);

        vm.prank(p1);
        pth.joinTable(1, p1, 100, false);

        // Post blinds
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.SBPost, 0, 1);
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.BBPost, 1, 2);

        // Player 0 folds
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Fold, 0, 0);

        // Now post blinds for next hand
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.SBPost, 1, 1);
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.BBPost, 0, 2);

        // Player 1 folds
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Fold, 1, 0);

        // Whose turn should be 0
        assertEq(uint(pth.whoseTurn()), 0, "Whose turn should be 0");

        // Third hand
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.SBPost, 0, 1);
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.BBPost, 1, 2);

        // Player 0 folds
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Fold, 0, 0);

        assertEq(uint(pth.whoseTurn()), 1, "Whose turn should be 1");
        assertEq(uint(pth.button()), 1, "Button should be 1");
    }

    function test_integration2pShowdown() public {
        // Deploy the contract
        NLHoldemTableHarness pth = deploy();

        // Set up players
        address p0 = address(0x123);
        address p1 = address(0x456);

        // Join table
        vm.prank(p0);
        pth.joinTable(0, p0, 100, false);

        vm.prank(p1);
        pth.joinTable(1, p1, 100, false);

        // Post blinds
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.SBPost, 0, 1);
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.BBPost, 1, 2);

        // Check hand stage
        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.PreflopBetting),
            "Hand stage should be PreflopBetting"
        );

        // Preflop betting
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Call, 0, 0);
        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.PreflopBetting),
            "Hand stage should still be PreflopBetting"
        );

        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Check, 1, 0);

        // Check flop
        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.FlopBetting),
            "Hand stage should be FlopBetting"
        );

        // Would be better to check that two of three are not zeroes
        assertTrue(
            pth.flop0() != 0 || pth.flop1() != 0 || pth.flop2() != 0,
            "Flop should be dealt"
        );

        // Flop betting
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Bet, 1, 5);

        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Bet, 0, 10);
        /*
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Call, 1, 0);

        // Check turn
        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.TurnBetting),
            "Hand stage should be TurnBetting"
        );
        assertTrue(pth.turn() != 0, "Turn should be dealt");

        // Turn betting
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Check, 1, 0);
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Check, 0, 0);

        // Check river
        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.RiverBetting),
            "Hand stage should be RiverBetting"
        );
        assertTrue(pth.river() != 0, "River should be dealt");

        // River betting
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Bet, 1, 5);

        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Call, 0, 0);

        // Will split pot
        vm.prank(p1);
        pth.showCards(
            false,
            false,
            [true, true, true, true, true, false, false]
        );
        vm.prank(p0);
        pth.showCards(
            false,
            false,
            [true, true, true, true, true, false, false]
        );

        // Check final state
        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.SBPostStage),
            "Hand stage should be SBPostStage"
        );

        // Check final stacks (split pot)
        assertEq(pth.plrStack(0), 100, "Player 0 stack should be 100");
        assertEq(pth.plrStack(1), 100, "Player 1 stack should be 100");
        */
    }

    function test_integration2pFold() public {
        // Deploy the contract
        NLHoldemTableHarness pth = deploy();

        // Set up players
        address p0 = address(0x123);
        address p1 = address(0x456);

        // Join table
        vm.prank(p0);
        pth.joinTable(0, p0, 100, false);

        vm.prank(p1);
        pth.joinTable(1, p1, 100, false);

        // Post blinds
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.SBPost, 0, 1);

        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.BBPost, 1, 2);

        // Player 0 folds
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Fold, 0, 0);

        // Check final state
        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.SBPostStage),
            "Hand stage should be SBPostStage after fold"
        );

        // Check final stacks
        assertEq(
            pth.plrStack(0),
            99,
            "Player 0 stack should be 99 after folding"
        );
        assertEq(
            pth.plrStack(1),
            101,
            "Player 1 stack should be 101 after winning"
        );
    }

    function test_integration2pAllIn() public {
        // Deploy the contract
        NLHoldemTableHarness pth = deploy();

        // Set up players
        address p0 = address(0x123);
        address p1 = address(0x456);

        // Join table
        vm.prank(p0);
        pth.joinTable(0, p0, 100, false);

        vm.prank(p1);
        pth.joinTable(1, p1, 100, false);

        // Post blinds
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.SBPost, 0, 1);

        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.BBPost, 1, 2);

        // Player 0 goes all-in
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Bet, 0, 100);

        // Check hand stage
        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.PreflopBetting),
            "Hand stage should be PreflopBetting"
        );

        // Player 1 calls all-in
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Call, 1, 0);

        vm.prank(p1);
        pth.showCards(
            false,
            false,
            [true, true, true, true, true, false, false]
        );
        vm.prank(p0);
        pth.showCards(
            false,
            false,
            [true, true, true, true, true, false, false]
        );

        // Check final state
        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.SBPostStage),
            "Hand stage should be SBPostStage after all-in"
        );

        // Check final stacks (split pot)
        assertEq(pth.plrStack(0), 100, "Player 0 stack should be 100");
        assertEq(pth.plrStack(1), 100, "Player 1 stack should be 100");
    }

    function test_integration3pShowdown() public {
        // Deploy the contract
        NLHoldemTableHarness pth = deploy();

        // Set up players
        address p0 = address(0x123);
        address p1 = address(0x456);
        address p2 = address(0x789);

        // Join table
        vm.prank(p0);
        pth.joinTable(0, p0, 100, false);
        vm.prank(p1);
        pth.joinTable(1, p1, 100, false);
        vm.prank(p2);
        pth.joinTable(2, p2, 100, false);

        // Have to manually make state look like an ongoing hand
        pth.setPlrPostedBlinds();
        pth.setWhoseTurn(1);
        pth.exposed_recomputeInHand();

        // Post blinds and initial betting
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.SBPost, 1, 1);
        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.BBPost, 2, 2);
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Call, 0, 0);

        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.PreflopBetting),
            "Hand stage should be PreflopBetting"
        );

        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Call, 1, 0);
        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.Check, 2, 0);

        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.FlopBetting),
            "Hand stage should be FlopBetting"
        );

        // Flop betting
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Bet, 1, 10);
        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.Bet, 2, 20);
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Call, 0, 0);
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Call, 1, 0);

        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.TurnBetting),
            "Hand stage should be TurnBetting"
        );

        // Turn betting
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Check, 1, 0);
        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.Check, 2, 0);
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Check, 0, 0);

        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.RiverBetting),
            "Hand stage should be RiverBetting"
        );

        // River betting
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Bet, 1, 5);
        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.Call, 2, 0);
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Call, 0, 0);

        vm.prank(p1);
        pth.showCards(
            false,
            false,
            [true, true, true, true, true, false, false]
        );
        vm.prank(p2);
        pth.showCards(
            false,
            false,
            [true, true, true, true, true, false, false]
        );
        vm.prank(p0);
        pth.showCards(
            false,
            false,
            [true, true, true, true, true, false, false]
        );

        // Check final state
        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.SBPostStage),
            "Hand stage should be SBPostStage after showdown"
        );

        // Check final stacks (split pot)
        assertEq(
            pth.plrStack(0),
            100,
            "Player 0 stack should be 100 after split pot"
        );
        assertEq(
            pth.plrStack(1),
            100,
            "Player 1 stack should be 100 after split pot"
        );
        assertEq(
            pth.plrStack(2),
            100,
            "Player 2 stack should be 100 after split pot"
        );
    }

    function test_integration3pOneFold() public {
        // Deploy the contract
        NLHoldemTableHarness pth = deploy();

        // Set up players
        address p0 = address(0x123);
        address p1 = address(0x456);
        address p2 = address(0x789);

        // Join table
        // P2 joins first to make it so p0 is SB
        vm.prank(p2);
        pth.joinTable(2, p2, 100, false);
        vm.prank(p0);
        pth.joinTable(0, p0, 100, false);
        vm.prank(p1);
        pth.joinTable(1, p1, 100, false);

        // Have to manually make state look like an ongoing hand
        pth.setPlrPostedBlinds();
        pth.setWhoseTurn(0);
        pth.exposed_recomputeInHand();

        // Post blinds and initial betting
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.SBPost, 0, 1);
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.BBPost, 1, 2);
        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.Call, 2, 0);

        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.PreflopBetting),
            "Hand stage should be PreflopBetting"
        );

        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Call, 0, 0);
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Check, 1, 0);

        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.FlopBetting),
            "Hand stage should be FlopBetting"
        );

        // Check that flop is dealt
        assertTrue(
            pth.flop0() != 0 || pth.flop1() != 0 || pth.flop2() != 0,
            "Flop should be dealt"
        );

        // Flop betting
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Bet, 0, 10);
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Fold, 1, 0);
        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.Call, 2, 0);

        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.TurnBetting),
            "Hand stage should be TurnBetting"
        );

        // Check that turn is dealt
        assertTrue(pth.turn() != 0, "Turn should be dealt");

        // Turn betting
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Check, 0, 0);
        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.Check, 2, 0);

        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.RiverBetting),
            "Hand stage should be RiverBetting"
        );

        // Check that river is dealt
        assertTrue(pth.river() != 0, "River should be dealt");

        // River betting
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Bet, 0, 5);
        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.Call, 2, 0);

        vm.prank(p0);
        pth.showCards(
            false,
            false,
            [true, true, true, true, true, false, false]
        );
        vm.prank(p2);
        pth.showCards(
            false,
            false,
            [true, true, true, true, true, false, false]
        );

        // Check final state
        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.SBPostStage),
            "Hand stage should be SBPostStage after showdown"
        );

        // Check final stacks
        assertEq(
            pth.plrStack(0),
            101,
            "Player 0 stack should be 101 after winning"
        );
        assertEq(
            pth.plrStack(1),
            98,
            "Player 1 stack should be 98 after folding"
        );
        assertEq(
            pth.plrStack(2),
            101,
            "Player 2 stack should be 101 after winning"
        );
    }

    function test_integration3pTwoFolds() public {
        NLHoldemTableHarness pth = deploy();

        address p0 = address(0x123);
        address p1 = address(0x456);
        address p2 = address(0x789);

        // Join table
        vm.prank(p0);
        pth.joinTable(0, p0, 100, false);
        vm.prank(p1);
        pth.joinTable(1, p1, 100, false);
        vm.prank(p2);
        pth.joinTable(2, p2, 100, false);

        // Have to manually make state look like an ongoing hand
        pth.setPlrPostedBlinds();
        pth.setWhoseTurn(1);
        pth.exposed_recomputeInHand();

        // Post blinds and initial betting
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.SBPost, 1, 1);
        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.BBPost, 2, 2);
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Call, 0, 0);

        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.PreflopBetting)
        );

        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Call, 1, 1);

        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.PreflopBetting)
        );

        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.Check, 2, 0);

        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.FlopBetting)
        );

        // Check flop cards
        assertTrue(
            pth.flop0() != 0 || pth.flop1() != 0 || pth.flop2() != 0,
            "Flop should be dealt"
        );

        // Flop betting
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Check, 1, 0);
        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.Bet, 2, 10);
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Fold, 0, 0);
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Fold, 1, 0);

        // Check final state
        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.SBPostStage)
        );

        assertEq(pth.plrStack(1), 98);
        assertEq(pth.plrStack(2), 104);
        assertEq(pth.plrStack(0), 98);
    }

    function test_integration3pAllIn() public {
        NLHoldemTableHarness pth = deploy();

        address p0 = address(0x123);
        address p1 = address(0x456);
        address p2 = address(0x789);

        // Join table
        vm.prank(p2);
        pth.joinTable(2, p2, 100, false);
        vm.prank(p0);
        pth.joinTable(0, p0, 100, false);
        vm.prank(p1);
        pth.joinTable(1, p1, 100, false);

        // Have to manually make state look like an ongoing hand
        pth.setPlrPostedBlinds();
        pth.setWhoseTurn(0);
        pth.exposed_recomputeInHand();

        // Post blinds and initial betting
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.SBPost, 0, 1);
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.BBPost, 1, 2);
        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.Call, 2, 2);
        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.PreflopBetting)
        );
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Call, 0, 1);
        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.PreflopBetting)
        );
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Check, 1, 0);
        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.FlopBetting)
        );

        // Everyone all-in on flop
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Bet, 0, 98);
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Call, 1, 98);
        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.Call, 2, 98);

        vm.prank(p0);
        pth.showCards(
            false,
            false,
            [true, true, true, true, true, false, false]
        );
        vm.prank(p1);
        pth.showCards(
            false,
            false,
            [true, true, true, true, true, false, false]
        );
        vm.prank(p2);
        pth.showCards(
            false,
            false,
            [true, true, true, true, true, false, false]
        );

        // Should progress to river and split pot
        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.SBPostStage)
        );

        // It was a split pot, so all should have 100
        assertEq(pth.plrStack(0), 100);
        assertEq(pth.plrStack(1), 100);
        assertEq(pth.plrStack(2), 100);
    }

    function test_integration3pWeirdAllIn() public {
        NLHoldemTableHarness pth = deploy();

        address p0 = address(0x123);
        address p1 = address(0x456);
        address p2 = address(0x789);
        address p3 = address(0xabc);

        vm.prank(p3);
        pth.joinTable(3, p3, 100, false);
        vm.prank(p0);
        pth.joinTable(0, p0, 200, false);
        vm.prank(p1);
        pth.joinTable(1, p1, 100, false);
        vm.prank(p2);
        pth.joinTable(2, p2, 50, false);

        // Have to manually make state look like an ongoing hand
        pth.setPlrPostedBlinds();
        pth.setWhoseTurn(0);
        pth.exposed_recomputeInHand();

        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.SBPost, 0, 1);
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.BBPost, 1, 2);
        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.Call, 2, 0);
        vm.prank(p3);
        pth.takeAction(EnumsAndActions.ActionType.Call, 3, 0);

        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Call, 0, 0);
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Check, 1, 0);

        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.FlopBetting)
        );

        // Preflop betting was 8
        // Flop betting -
        // all-in on flop - P1 betting more than others but less than their stack
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Check, 0, 0);
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Bet, 1, 10);
        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.Call, 2, 0);
        vm.prank(p3);
        pth.takeAction(EnumsAndActions.ActionType.Call, 3, 0);
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Bet, 0, 123);
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Fold, 1, 0);
        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.Call, 2, 0);
        vm.prank(p3);
        pth.takeAction(EnumsAndActions.ActionType.Call, 3, 0);

        vm.prank(p0);
        pth.showCards(
            false,
            false,
            [true, true, true, true, true, false, false]
        );
        vm.prank(p2);
        pth.showCards(
            false,
            false,
            [true, true, true, true, true, false, false]
        );
        vm.prank(p3);
        pth.showCards(
            false,
            false,
            [true, true, true, true, true, false, false]
        );

        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.SBPostStage)
        );

        // It was a split pot, but p2 folded
        // p2 put in 2 preflop and 10 on flop, so should be 12 to split among other 3
        assertEq(pth.plrStack(0), 204);
        // Down 12
        assertEq(pth.plrStack(1), 88);
        assertEq(pth.plrStack(2), 54);
        assertEq(pth.plrStack(3), 104);
    }

    function test_integration3pWeirdAllInDifferentStreets() public {
        NLHoldemTableHarness pth = deploy();

        address p0 = address(0x123);
        address p1 = address(0x456);
        address p2 = address(0x789);
        address p3 = address(0xabc);

        vm.prank(p3);
        pth.joinTable(3, p3, 100, false);
        vm.prank(p0);
        pth.joinTable(0, p0, 200, false);
        vm.prank(p1);
        pth.joinTable(1, p1, 100, false);
        vm.prank(p2);
        pth.joinTable(2, p2, 50, false);

        // Have to manually make state look like an ongoing hand
        pth.setPlrPostedBlinds();
        pth.setWhoseTurn(0);
        pth.exposed_recomputeInHand();

        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.SBPost, 0, 1);
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.BBPost, 1, 2);
        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.Call, 2, 0);
        vm.prank(p3);
        pth.takeAction(EnumsAndActions.ActionType.Call, 3, 0);

        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Call, 0, 0);
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Check, 1, 0);

        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.FlopBetting)
        );

        // Preflop betting was 8
        // Flop betting -
        // all-in on flop - P1 betting more than others but less than their stack
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Check, 0, 0);
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Bet, 1, 10);
        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.Call, 2, 0);
        vm.prank(p3);
        pth.takeAction(EnumsAndActions.ActionType.Call, 3, 0);
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Bet, 0, 70);
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Fold, 1, 0);
        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.Call, 2, 0);
        vm.prank(p3);
        pth.takeAction(EnumsAndActions.ActionType.Call, 3, 0);

        // Now turn - put in the rest
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Bet, 0, 53);
        vm.prank(p3);
        pth.takeAction(EnumsAndActions.ActionType.Call, 3, 0);

        vm.prank(p0);
        pth.showCards(
            false,
            false,
            [true, true, true, true, true, false, false]
        );
        vm.prank(p2);
        pth.showCards(
            false,
            false,
            [true, true, true, true, true, false, false]
        );
        vm.prank(p3);
        pth.showCards(
            false,
            false,
            [true, true, true, true, true, false, false]
        );

        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.SBPostStage)
        );

        // It was a split pot, but p2 folded
        // p2 put in 2 preflop and 10 on flop, so should be 12 to split among other 3
        assertEq(pth.plrStack(0), 204);
        // Down 12
        assertEq(pth.plrStack(1), 88);
        assertEq(pth.plrStack(2), 54);
        assertEq(pth.plrStack(3), 104);
    }

    function test_integration2pFoldTwoHands() public {
        NLHoldemTableHarness pth = deploy();

        address p0 = address(0x123);
        address p1 = address(0x456);

        // Join table for both players
        vm.prank(p0);
        pth.joinTable(0, p0, 100, false);
        vm.prank(p1);
        pth.joinTable(1, p1, 100, false);

        // First hand
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.SBPost, 0, 1);

        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.BBPost, 1, 2);

        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Fold, 0, 0);

        // Assertions for the first hand
        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.SBPostStage),
            "Bad hand stage"
        );

        assertEq(pth.plrStack(0), 99);
        assertEq(pth.plrStack(1), 101);
        assertEq(pth.button(), 1, "Bad button");
        assertEq(pth.whoseTurn(), 1, "Bad whose turn");

        // Second hand
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.SBPost, 1, 1);

        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.BBPost, 0, 2);

        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Fold, 1, 0);

        // Assertions for the second hand
        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.SBPostStage)
        );

        assertEq(pth.plrStack(0), 100);
        assertEq(pth.plrStack(1), 100);

        assertTrue(pth.plrInHand(0));
        assertTrue(pth.plrInHand(1));
    }

    function test_integration3pOpenFold() public {
        NLHoldemTableHarness pth = deploy();

        address p0 = address(0x123);
        address p1 = address(0x456);
        address p2 = address(0x789);

        // Join table
        vm.prank(p2);
        pth.joinTable(2, p2, 50, false);
        vm.prank(p0);
        pth.joinTable(0, p0, 200, false);
        vm.prank(p1);
        pth.joinTable(1, p1, 100, false);
        // Have to manually make state look like an ongoing hand
        pth.setPlrPostedBlinds();
        pth.setWhoseTurn(0);
        pth.exposed_recomputeInHand();

        // Post blinds and initial betting
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.SBPost, 0, 1);
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.BBPost, 1, 2);
        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.Call, 2, 2);

        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.PreflopBetting)
        );

        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Call, 0, 1);

        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.PreflopBetting)
        );

        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Check, 1, 0);

        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.FlopBetting)
        );

        // Check that flop is dealt
        assertTrue(
            pth.flop0() != 0 || pth.flop1() != 0 || pth.flop2() != 0,
            "Flop should be dealt"
        );

        // Flop betting
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Fold, 0, 0);
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Check, 1, 0);
        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.Check, 2, 0);

        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.TurnBetting)
        );

        // Check that turn is dealt
        assertTrue(pth.turn() != 0, "Turn should be dealt");

        // P0 folded, so P1's turn
        assertEq(pth.whoseTurn(), 1);
    }

    function test_sitOutAfterSBPost() public {
        NLHoldemTableHarness pth = deploy();

        address p0 = address(0x123);
        address p1 = address(0x456);
        address p2 = address(0x789);

        // Join table with 3 players
        vm.prank(p0);
        pth.joinTable(0, p0, 100, false);
        vm.prank(p1);
        pth.joinTable(1, p1, 100, false);
        vm.prank(p2);
        pth.joinTable(2, p2, 100, false);

        // Have to manually make state look like an ongoing hand
        pth.setPlrPostedBlinds();
        pth.setWhoseTurn(0);
        pth.exposed_recomputeInHand();

        // SB posts
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.SBPost, 0, 1);

        // BB sits out
        vm.prank(p1);
        pth.sitIn(1, false);

        // Check that it's now p2's turn to post BB
        assertEq(pth.whoseTurn(), 2, "Should be p2's turn to post BB");

        // p2 posts BB
        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.BBPost, 2, 2);

        // Check that p0 is now in hand and it's their turn to act
        assertEq(pth.whoseTurn(), 0, "Should be p0's turn to act");
        assertTrue(pth.plrInHand(0), "p0 should be in hand");
        assertFalse(pth.plrInHand(1), "p1 should not be in hand");
        assertTrue(pth.plrInHand(2), "p2 should be in hand");

        // p0 folds
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Fold, 0, 0);

        // Check that p2 wins the pot
        assertEq(pth.plrStack(0), 99, "p0 should have 99 chips after folding");
        assertEq(
            pth.plrStack(1),
            100,
            "p1 should have 100 chips after sitting out"
        );
        assertEq(
            pth.plrStack(2),
            101,
            "p2 should have 101 chips after winning"
        );
    }

    function test_skipSBPost3p() public {
        NLHoldemTableHarness pth = deploy();

        address p0 = address(0x123);
        address p1 = address(0x456);
        address p2 = address(0x789);

        // Join table with 3 players
        vm.prank(p0);
        pth.joinTable(0, p0, 100, false);
        vm.prank(p1);
        pth.joinTable(1, p1, 100, false);
        vm.prank(p2);
        pth.joinTable(2, p2, 100, false);

        // Have to manually make state look like an ongoing hand
        pth.setPlrPostedBlinds();
        pth.setWhoseTurn(0);
        pth.exposed_recomputeInHand();

        // SB sits out
        vm.prank(p0);
        pth.sitIn(0, false);

        // Check that it's now p1's turn to post BB
        assertEq(pth.whoseTurn(), 1, "Should be p1's turn to post BB");

        // p1 posts BB
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.BBPost, 1, 2);

        // Check that p2 is now in hand and it's their turn to act
        assertEq(pth.whoseTurn(), 2, "Should be p2's turn to act");
        assertFalse(pth.plrInHand(0), "p0 should not be in hand");
        assertTrue(pth.plrInHand(1), "p1 should be in hand");
        assertTrue(pth.plrInHand(2), "p2 should be in hand");

        // p2 folds
        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.Fold, 2, 0);

        // Check that p1 wins the pot
        assertEq(
            pth.plrStack(0),
            100,
            "p0 should have 100 chips after sitting out"
        );
        assertEq(
            pth.plrStack(1),
            100,
            "p1 should have 101 chips after winning"
        );
        assertEq(
            pth.plrStack(2),
            100,
            "p2 should have 100 chips after folding"
        );
    }

    function test_mustPostBlindsFirst() public {
        NLHoldemTableHarness pth = deploy();

        address p0 = address(0x123);
        address p1 = address(0x456);
        address p2 = address(0x789);

        vm.prank(p0);
        pth.joinTable(0, p0, 200, false);
        vm.prank(p1);
        pth.joinTable(1, p1, 100, false);
        vm.prank(p2);
        pth.joinTable(2, p2, 50, false);

        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.SBPost, 0, 1);

        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.BBPost, 1, 2);

        // Should only be two players!
        // This should FAIL!
        vm.expectRevert();
        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.Call, 2, 0);

        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Fold, 0, 0);
        //Hand is over - now next hand they should be able to post, and it should be 3 ways

        uint8 whoseTurn = pth.getWhoseTurn();
        assertEq(uint(whoseTurn), 1);

        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.SBPost, 1, 1);

        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.BBPost, 2, 2);
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Call, 0, 0);

        // SB's turn, still preflop betting stag
        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.PreflopBetting)
        );
    }

    function test_sitOutAfterBothBlinds() public {
        NLHoldemTableHarness pth = deploy();

        address p0 = address(0x123);
        address p1 = address(0x456);

        // Join table with 2 players
        vm.prank(p0);
        pth.joinTable(0, p0, 100, false);
        vm.prank(p1);
        pth.joinTable(1, p1, 100, false);

        // Have to manually make state look like an ongoing hand
        // pth.setPlrPostedBlinds();
        // pth.setWhoseTurn(0);
        // pth.exposed_recomputeInHand();

        // First hand
        // p0 posts SB
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.SBPost, 0, 1);

        // p1 posts BB
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.BBPost, 1, 2);

        // end hand...
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Fold, 0, 0);

        // Second hand
        // p1 posts SB
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.SBPost, 1, 1);

        // p0 posts BB
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.BBPost, 0, 2);

        // p1 calls
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Fold, 1, 0);

        // p1 sits out before third hand
        vm.prank(p1);
        pth.sitIn(1, false);

        // Check that p1 has BB credits (can play next hand)
        assertEq(
            pth.plrPostedBlinds(1),
            1,
            "p1 should have BB credits after posting both blinds"
        );

        // p1 sits back in
        vm.prank(p1);
        pth.sitIn(1, true);

        // Verify p1 is in hand
        assertTrue(
            pth.plrInHand(1),
            "p1 should be in hand after sitting back in"
        );

        // Third hand starts
        // p0 posts SB
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.SBPost, 0, 1);

        // p1 posts BB
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.BBPost, 1, 2);

        // Verify p1 is still in hand
        assertTrue(
            pth.plrInHand(1),
            "p1 should still be in hand after posting BB"
        );
    }

    function test_sitOutAfterPlayingHand() public {
        NLHoldemTableHarness pth = deploy();

        address p0 = address(0x123);
        address p1 = address(0x456);

        // Join table with 2 players
        vm.prank(p0);
        pth.joinTable(0, p0, 100, false);
        vm.prank(p1);
        pth.joinTable(1, p1, 100, false);

        // First hand
        // p0 posts SB
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.SBPost, 0, 1);

        // p1 posts BB
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.BBPost, 1, 2);

        // p0 calls
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Fold, 0, 0);

        // Second hand starts
        // p1 sits out before posting SB
        vm.prank(p1);
        pth.sitIn(1, false);

        // Check that p1 has no BB credits (can't play next hand)
        assertEq(
            pth.plrPostedBlinds(1),
            0,
            "p1 should have no BB credits after sitting out before posting SB"
        );

        // Verify p1 is not in hand
        assertFalse(
            pth.plrInHand(1),
            "p1 should not be in hand after sitting out"
        );
    }
}
