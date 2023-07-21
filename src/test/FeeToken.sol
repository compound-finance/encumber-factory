// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FeeToken is ERC20 {
    uint256 constant TRANSFER_FEE = 1e18;

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        _transfer(msg.sender, to, amount - TRANSFER_FEE);
        _transfer(msg.sender, address(this), TRANSFER_FEE);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount - TRANSFER_FEE);
        _transfer(from, address(this), TRANSFER_FEE);
        return true;
    }
}