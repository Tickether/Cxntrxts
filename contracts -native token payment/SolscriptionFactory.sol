//SPDX-License-Identifier: MIT
// Code by @0xGeeLoko

pragma solidity ^0.8.0;

import "./Solscription.sol";

contract SolscriptionFactory {

    Solscription[] public solscriptionContracts;

    function createSolscriptionContract(

        string memory _name, 
        string memory _symbol

    ) external {
        Solscription solscription = new Solscription(
            _name, 
            _symbol
        );
        
        solscriptionContracts.push(solscription); 

        solscription.transferOwnership(msg.sender);
    }
}
