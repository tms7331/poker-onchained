// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {EnumsAndActions} from "../src/EnumsAndActions.sol";
import {PokerTable} from "../src/PokerTable.sol";
// Contract with all internal methods exposed
contract PokerTableHarness is PokerTable {
    constructor(
        uint _tableId,
        uint _smallBlind,
        uint _bigBlind,
        uint _minBuyin,
        uint _maxBuyin,
        uint _numSeats
    )
        PokerTable(
            _tableId,
            _smallBlind,
            _bigBlind,
            _minBuyin,
            _maxBuyin,
            _numSeats
        )
    {}
}

contract TestPokerTable is Test {
    function deploy() internal returns (PokerTableHarness) {
        uint tableId = 0;
        uint smallBlind = 1;
        uint bigBlind = 2;
        uint minBuyin = 20;
        uint maxBuyin = 200;
        uint numPlayers = 6;
        PokerTableHarness pth = new PokerTableHarness(
            tableId,
            smallBlind,
            bigBlind,
            minBuyin,
            maxBuyin,
            numPlayers
        );
        return pth;
    }

    function test_initTable() public {
        // Just make sure basic contract initialization works
        deploy();
    }

    function test_joinTable() public {
        // Deploy the contract
        PokerTableHarness pth = deploy();

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
        PokerTableHarness pth = deploy();

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
        PokerTableHarness pth = deploy();

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
        PokerTableHarness pth = deploy();

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
        PokerTableHarness pth = deploy();

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

    function test_foldPreflop() public {
        // Deploy the contract
        PokerTableHarness pth = deploy();

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

    function test_thirdHand() public {
        // Make sure button resets to 0 on third hand
        PokerTableHarness pth = deploy();

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
        PokerTableHarness pth = deploy();

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
        // (uint8 flop1, uint8 flop2, uint8 flop3) = pth.exposed_getTblFlop(
        //     pth.tblDataId()
        // );
        // assertTrue(
        //     flop1 != 53 && flop2 != 53 && flop3 != 53,
        //     "Flop should be dealt"
        // );

        // Flop betting
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Bet, 0, 5);
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Bet, 1, 10);
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Call, 0, 0);

        // Check turn
        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.TurnBetting),
            "Hand stage should be TurnBetting"
        );
        // uint8 turn = pth.exposed_getTblTurn(pth.tblDataId());
        // assertTrue(turn != 53, "Turn should be dealt");

        // Turn betting
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Check, 0, 0);
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Check, 1, 0);

        // Check river
        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.RiverBetting),
            "Hand stage should be RiverBetting"
        );
        // uint8 river = pth.exposed_getTblRiver(pth.tblDataId());
        // assertTrue(river != 53, "River should be dealt");

        // River betting
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Bet, 0, 5);
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Call, 1, 0);

        // Check final state
        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.SBPostStage),
            "Hand stage should be SBPostStage"
        );

        // Check final stacks (split pot)
        assertEq(pth.plrStack(0), 100, "Player 0 stack should be 100");
        assertEq(pth.plrStack(1), 100, "Player 1 stack should be 100");
    }

    function test_integration2pFold() public {
        // Deploy the contract
        PokerTableHarness pth = deploy();

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
        PokerTableHarness pth = deploy();

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
        PokerTableHarness pth = deploy();

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

        // Flop betting
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Bet, 0, 10);
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Bet, 1, 20);
        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.Call, 2, 0);
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Call, 0, 0);

        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.TurnBetting),
            "Hand stage should be TurnBetting"
        );

        // Turn betting
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Check, 0, 0);
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Check, 1, 0);
        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.Check, 2, 0);

        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.RiverBetting),
            "Hand stage should be RiverBetting"
        );

        // River betting
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Bet, 0, 5);
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Call, 1, 0);
        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.Call, 2, 0);

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
        PokerTableHarness pth = deploy();

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
        // (uint8 flop1, uint8 flop2, uint8 flop3) = pth.exposed_getTblFlop(
        //     pth.tblDataId()
        // );
        // assertTrue(
        //     flop1 != 53 && flop2 != 53 && flop3 != 53,
        //     "Flop should be dealt"
        // );

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
        // uint8 turn = pth.exposed_getTblTurn(pth.tblDataId());
        // assertTrue(turn != 53, "Turn should be dealt");

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
        // uint8 river = pth.exposed_getTblRiver(pth.tblDataId());
        // assertTrue(river != 53, "River should be dealt");

        // River betting
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Bet, 0, 5);
        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.Call, 2, 0);

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
        PokerTableHarness pth = deploy();

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

        // Check flop cards
        // (uint8 c1, uint8 c2, uint8 c3) = pth.exposed_getTblFlop(
        //     pth.tblDataId()
        // );
        // assertTrue(c1 != 53 && c2 != 53 && c3 != 53);

        // Flop betting
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Check, 0, 0);
        vm.prank(p1);
        pth.takeAction(EnumsAndActions.ActionType.Bet, 1, 10);
        vm.prank(p2);
        pth.takeAction(EnumsAndActions.ActionType.Fold, 2, 0);
        vm.prank(p0);
        pth.takeAction(EnumsAndActions.ActionType.Fold, 0, 0);

        // Check final state
        assertEq(
            uint(pth.handStage()),
            uint(EnumsAndActions.HandStage.SBPostStage)
        );

        assertEq(pth.plrStack(0), 98);
        assertEq(pth.plrStack(1), 104);
        assertEq(pth.plrStack(2), 98);
    }

    function test_integration3pAllIn() public {
        PokerTableHarness pth = deploy();

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
        PokerTableHarness pth = deploy();

        address p0 = address(0x123);
        address p1 = address(0x456);
        address p2 = address(0x789);
        address p3 = address(0xabc);

        vm.prank(p0);
        pth.joinTable(0, p0, 200, false);
        vm.prank(p1);
        pth.joinTable(1, p1, 100, false);
        vm.prank(p2);
        pth.joinTable(2, p2, 50, false);
        vm.prank(p3);
        pth.joinTable(3, p3, 100, false);

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
        PokerTableHarness pth = deploy();

        address p0 = address(0x123);
        address p1 = address(0x456);
        address p2 = address(0x789);
        address p3 = address(0xabc);

        vm.prank(p0);
        pth.joinTable(0, p0, 200, false);
        vm.prank(p1);
        pth.joinTable(1, p1, 100, false);
        vm.prank(p2);
        pth.joinTable(2, p2, 50, false);
        vm.prank(p3);
        pth.joinTable(3, p3, 100, false);

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
        PokerTableHarness pth = deploy();

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
        // assertFalse(pth.plrSittingOut(0));
        // assertFalse(pth.plrSittingOut(1));
    }

    function test_integration3pOpenFold() public {
        PokerTableHarness pth = deploy();

        address p0 = address(0x123);
        address p1 = address(0x456);
        address p2 = address(0x789);
        // Initialize the table
        // bytes memory initData = pth.initTable();
        // (bool success, ) = address(pth).call(initData);
        // require(success, "Table initialization failed");

        // Join table
        vm.prank(p0);
        pth.joinTable(0, p0, 200, false);
        vm.prank(p1);
        pth.joinTable(1, p1, 100, false);
        vm.prank(p2);
        pth.joinTable(2, p2, 50, false);

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
        // (uint8 c1, uint8 c2, uint8 c3) = pth.exposed_getTblFlop(
        //     pth.tblDataId()
        // );
        // assertTrue(c1 != 53 && c2 != 53 && c3 != 53, "Flop not dealt");

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
        // uint8 turn = pth.exposed_getTblTurn(pth.tblDataId());
        // assertTrue(turn != 53, "Turn not dealt");

        assertEq(pth.whoseTurn(), 1);
    }
}
