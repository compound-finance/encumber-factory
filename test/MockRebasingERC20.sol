// XXX license

import "../src/erc20/ERC20.sol";

pragma solidity ^0.8.15;

contract MockRebasingERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address account, uint256 amount) public returns (bool) {
        _mint(account, amount);
        return true;
    }
}