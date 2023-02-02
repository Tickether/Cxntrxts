//SPDX-License-Identifier: MIT
// Code by @0xGeeLoko

pragma solidity ^0.8.0;

import "./Solscription.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract SolscriptionFactory {

    Solscription[] public solscriptionContracts;

    address public immutable solscriptionImplementation; 

    constructor() {
        solscriptionImplementation = address(new Solscription());
    }

    function createSolscriptionContract(address _owner) public {
        
        address solscriptionClone = Clones.clone(solscriptionImplementation);
        Solscription solscription = Solscription(solscriptionClone);
        
        solscription.initialize(_owner);

        solscriptionContracts.push(solscription);
    }
}
