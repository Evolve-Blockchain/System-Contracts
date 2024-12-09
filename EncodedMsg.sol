// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract EncodedMessage {
    
    string private constant genesisMessage = "Evolve blockchains genesis block is the cornerstone of a new paradigm, where transparency, security, and innovation drive the digital evolution.";
    
    function getMessage() external pure returns (string memory) {
        return genesisMessage;
    }
}
