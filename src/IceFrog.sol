// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract IceFrog is ERC20, Ownable {
    constructor(
        uint256 initialSupply
    ) ERC20("IceFrog", "IF") Ownable(msg.sender) {
        _mint(msg.sender, initialSupply);
    }
}
