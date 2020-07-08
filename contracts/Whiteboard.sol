// SPDX-License-Identifier: MIT

pragma solidity 0.6.10;
pragma experimental AccountAbstraction;

account contract Whiteboard {
    uint256 nonce;
    string message;

    function setMessage(uint256 txNonce, uint256 gasPrice, string calldata newMessage, bool failAfterPaygas) public {
        require(nonce == txNonce);
        nonce = txNonce + 1;
        assembly { paygas(gasPrice) }
        message = newMessage;
        require(!failAfterPaygas);
    }

    function getNonce() public view returns (uint256) {
        assembly { paygas(0) }
        return nonce;
    }

    function getMessage() public view returns (string memory) {
        assembly { paygas(0) }
        return message;
    }

    constructor() public payable {}
}