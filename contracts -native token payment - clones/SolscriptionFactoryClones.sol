//SPDX-License-Identifier: MIT
// Code by @0xGeeLoko

pragma solidity ^0.8.0;

import "./Solscription.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract SolscriptionFactoryClones {

    Solscription[] public solscriptionContracts;

    address public immutable solscriptionImplementation; 

    constructor() {
        solscriptionImplementation = address(new Solscription());
    }

    function createSolscriptionContract( ) public {
        
        address solscriptionClone = Clones.clone(solscriptionImplementation);
        Solscription solscription = Solscription(solscriptionClone);
        
        solscription.transferOwnership(msg.sender);

        solscriptionContracts.push(solscription);
    }
}
