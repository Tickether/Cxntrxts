//SPDX-License-Identifier: MIT
//Code by @0xGeeLoko

pragma solidity ^0.8.9;

import "./MetaEstateRents.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract MetaEstateFactory is ReentrancyGuard {

    MetaEstateRents[] public metaEstateRentsContracts;

    function createSolscriptionContract(
        
    ) nonReentrant external returns (address) {
        MetaEstateRents metaEstateRents = new MetaEstateRents();
        
        metaEstateRentsContracts.push(metaEstateRents);

        //metaEstateRents.setNameSymbol(name, symbol);
        //metaEstateRents.setFeesMaxMonth(subscriptionFee, subscriptionFeeNative, maxMonthlySubs);
        metaEstateRents.transferOwnership(msg.sender);

        return address(metaEstateRents);
    }
}
/*
string calldata name, 
        string calldata symbol, 
        uint256 subscriptionFee, 
        uint256 subscriptionFeeNative, 
        uint256 maxMonthlySubs
        */