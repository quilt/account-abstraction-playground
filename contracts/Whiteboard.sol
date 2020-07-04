// SPDX-License-Identifier: MIT

pragma solidity 0.6.10;
pragma experimental AccountAbstraction;

account contract Whiteboard {
    uint256 nonce;
    string message;

    function setMessage(uint256 txNonce, uint256 gasPrice, bool failAfterPaygas, string calldata newMessage) public {
        require(nonce == txNonce);
        nonce = txNonce + 1;
        assembly { paygas(gasPrice) }
        require(!failAfterPaygas);
        message = newMessage;
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