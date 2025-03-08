// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "forge-std/console.sol";

contract CardDealer {
    mapping(uint => bool) public dealtCards;

    function dealCards(uint n) public returns (uint[] memory) {
        uint[] memory newCards = new uint[](n);
        uint dealtCount = 0;
        uint noise = 0;

        while (dealtCount < n) {
            uint randomCard = (uint(
                keccak256(abi.encodePacked(block.timestamp, noise))
            ) % 52) + 1;
            noise++;

            // Check if card hasn't been dealt yet
            if (!dealtCards[randomCard]) {
                dealtCards[randomCard] = true;
                newCards[dealtCount] = randomCard;
                dealtCount++;
            }
        }

        return newCards;
    }

    function reset() public {
        // Reset all cards to undealt state
        for (uint i = 1; i <= 52; i++) {
            dealtCards[i] = false;
        }
    }
}
