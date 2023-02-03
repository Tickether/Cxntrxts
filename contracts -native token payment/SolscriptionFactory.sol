//SPDX-License-Identifier: MIT
// Code by @0xGeeLoko

pragma solidity ^0.8.0;

import "./Solscription.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SolscriptionFactory is ReentrancyGuard {

    Solscription[] public solscriptionContracts;

    function createSolscriptionContract(
        string calldata name, 
        string calldata symbol, 
        uint256 subscriptionFee, 
        uint256 subscriptionFeeNative, 
        uint256 maxMonthlySubs
    ) external nonReentrant {
        Solscription solscription = new Solscription();
        
        solscriptionContracts.push(solscription);

        solscription.setNameSymbol(name, symbol);
        solscription.setFeesMaxMonth(subscriptionFee, subscriptionFeeNative, maxMonthlySubs);
        solscription.transferOwnership(msg.sender);
    }
}
