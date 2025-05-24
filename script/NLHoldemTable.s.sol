// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/NLHoldemTable.sol";

contract DeployNLHoldemTable is Script {
    function setUp() public {}
    function run() external {
        vm.startBroadcast();

        uint _tableId = 0;
        uint _smallBlind = 1;
        uint _bigBlind = 2;
        uint _minBuyin = 100;
        uint _maxBuyin = 1000;
        uint8 _numSeats = 6;
        address _lookupTableAddr = 0x89bB04df3cA85980F6c90B614e2791eD9c5Ad224;
        NLHoldemTable pokerTable = new NLHoldemTable(
            _tableId,
            _smallBlind,
            _bigBlind,
            _minBuyin,
            _maxBuyin,
            _numSeats,
            _lookupTableAddr
        );

        vm.stopBroadcast();

        console.log("NLHoldemTable deployed to:", address(pokerTable));
    }
}
