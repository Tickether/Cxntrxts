//SPDX-License-Identifier: MIT
// Code by @0xGeeLoko

pragma solidity ^0.8.0;

import "./Solscription.sol";

contract SolscriptionFactory {

    Solscription[] public solscriptionContracts;

    function createSolscriptionContract() public {
        Solscription subscription = new Solscription();
        solscriptionContracts.push(subscription);
    }
}
