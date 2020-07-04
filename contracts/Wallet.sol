// SPDX-License-Identifier: MIT

pragma solidity 0.6.10;
pragma experimental AccountAbstraction;

import { ECDSA } from "./ECDSA.sol";

account contract Wallet is ECDSA {
    uint256 nonce;
    address owner;

    modifier paygasZero {
        assembly { paygas(0) }
        _;
    }

    function transfer(uint256 txNonce, uint256 gasPrice, address payable to, uint256 amount, bytes calldata signature) public {
        assert(nonce == txNonce);
        bytes32 hash = keccak256(abi.encodePacked(this, txNonce, gasPrice, to, amount));
        bytes32 messageHash = toEthSignedMessageHash(hash);
        address signer = recover(messageHash, signature);
        require(signer == owner);
        nonce = txNonce + 1;
        assembly { paygas(gasPrice) }
        to.transfer(amount);
    }
    
    function getNonce() public view paygasZero returns (uint256) {
        return nonce;
    }
    
    function getOwner() public view paygasZero returns (address) {
        return owner;
    }
    
    constructor() public payable {
        owner = msg.sender;
    }
}