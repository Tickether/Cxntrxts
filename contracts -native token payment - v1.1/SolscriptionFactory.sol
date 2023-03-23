//SPDX-License-Identifier: MIT
//Code by @0xGeeLoko

pragma solidity ^0.8.9;

import "./Solscription.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SolscriptionFactory is ReentrancyGuard {

    Solscription[] public solscriptionContracts;

    function createSolscriptionContract(
        string memory name, 
        string memory symbol, 
        uint256 subscriptionFee, 
        uint256 subscriptionFeeNative, 
        uint256 maxMonthlySubs
    ) nonReentrant external returns (address) {
        Solscription solscription = new Solscription(name, symbol);
        
        solscriptionContracts.push(solscription);

        solscription.setFeesMaxMonth(subscriptionFee, subscriptionFeeNative, maxMonthlySubs);
        solscription.transferOwnership(msg.sender);

        return address(solscription);
    }
}
