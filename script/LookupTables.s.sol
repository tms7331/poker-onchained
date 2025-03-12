// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/LookupTables.sol";

contract DeployLookupTables is Script {
    function setUp() public {}
    function run() external {
        vm.startBroadcast();

        // Deploy LookupTables contract
        LookupTables lookupTables = new LookupTables();

        vm.stopBroadcast();

        console.log("LookupTables deployed to:", address(lookupTables));
    }
}
