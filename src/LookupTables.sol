// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

contract LookupTables {
    // uint32  4294967296
    // Max value is: 104553157
    mapping(uint32 => uint16) lookupFlushTable;
    mapping(uint32 => uint16) lookupBasicTable;
    bool mappingComplete = false;

    function insertFlush(
        uint32[] calldata lookupMult,
        uint16[] calldata lookupVal
    ) public {
        require(!mappingComplete, "Mapping already complete!");
        for (uint256 i = 0; i < lookupMult.length; i++) {
            // Should we check it offline instead?
            require(lookupVal[i] != 0, "Lookup value is 0!");
            lookupFlushTable[lookupMult[i]] = lookupVal[i];
        }
    }

    function insertBasic(
        uint32[] calldata lookupMult,
        uint16[] calldata lookupVal
    ) public {
        require(!mappingComplete, "Mapping already complete!");
        for (uint256 i = 0; i < lookupMult.length; i++) {
            // Should we check it offline instead?
            require(lookupVal[i] != 0, "Lookup value is 0!");
            lookupBasicTable[lookupMult[i]] = lookupVal[i];
        }
    }

    function completeMapping() public {
        mappingComplete = true;
    }

    function lookupFlush(uint32 lookupMult) public view returns (uint16) {
        return lookupFlushTable[lookupMult];
    }

    function lookupBasic(uint32 lookupMult) public view returns (uint16) {
        return lookupBasicTable[lookupMult];
    }
}
