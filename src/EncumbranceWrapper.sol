pragma solidity ^0.8.15;

import "./erc20/ERC20.sol";
import "./erc20/IERC20.sol";
import "./erc20/IERC20Metadata.sol";
import "./interfaces/IERC999.sol";

contract EncumbranceWrapper is ERC20, IERC999 {
    uint8 private immutable _decimals;
    address public immutable underlyingToken;

    mapping (address => uint) public encumberedBalance;

    mapping (address => mapping (address => uint)) public encumbrances;

    constructor(address _underlyingToken) ERC20(
        string.concat("encumbered ", IERC20Metadata(_underlyingToken).name()),
        string.concat("e", IERC20Metadata(_underlyingToken).symbol())
    ) {
        _decimals = IERC20Metadata(_underlyingToken).decimals();
        underlyingToken = _underlyingToken;
    }

    function decimals() public override view returns (uint8) {
        return _decimals;
    }

    function freeBalanceOf(address a) public view returns (uint) {
        return (balanceOf(a) - encumberedBalance[a]);
    }

    function transfer(address dst, uint amount) public override returns (bool) {
        // check but dont spend encumbrance
        require(freeBalanceOf(msg.sender) >= amount, "ERC999: insufficient free balance");
        _transfer(msg.sender, dst, amount);
        return true;
    }

    function transferFrom(address src, address dst, uint amount) public override returns (bool) {
        uint encumberedToTaker = encumbrances[src][msg.sender];
        bool exceedsEncumbrance = amount > encumberedToTaker;
        if (exceedsEncumbrance)  {
            uint excessAmount = amount - encumberedToTaker;
            // Exceeds Encumbrance, so spend all of it
            _spendEncumbrance(src, msg.sender, encumberedToTaker);

            // Having spent all the tokens encumbered to the mover,
            // We are now moving only "free" tokens and must check
            // to not unfairly move tokens encumbered to others

           require(freeBalanceOf(src) >= excessAmount, "insufficient balance");

            _spendAllowance(src, msg.sender, excessAmount);
        } else {
            _spendEncumbrance(src, msg.sender, amount);
        }

        _transfer(src, dst, amount);
        return true;
    }

    function _spendEncumbrance(address owner, address taker, uint amount) internal {
        uint currentEncumbrance = encumbrances[owner][taker];
        require(currentEncumbrance >= amount, "insufficient encumbrance");
        uint newEncumbrance = currentEncumbrance - amount;
        encumbrances[owner][taker] = newEncumbrance;
        encumberedBalance[owner] -= amount;
    }

    function encumber(address taker, uint amount) external returns (bool) {
        _encumber(msg.sender, taker, amount);
        return true;
    }

    function _encumber(address owner, address taker, uint amount) private {
        require(freeBalanceOf(owner) >= amount, "ERC999: insufficient free balance");
        encumbrances[owner][taker] += amount;
        encumberedBalance[owner] += amount;
        emit Encumber(owner, taker, amount);
    }

    function encumberFrom(address owner, address taker, uint amount) external returns (bool) {
        require(allowance(owner, msg.sender) >= amount, "ERC999: insufficient allowance");
        // spend caller's allowance
        _spendAllowance(owner, msg.sender, amount);
        _encumber(owner, taker, amount);
        return true;
    }

    function release(address owner, uint amount) external returns (bool) {
        _release(owner, msg.sender, amount);
        return true;
    }

    function _release(address owner, address taker, uint amount) private {
        if (encumbrances[owner][taker] < amount) {
          amount = encumbrances[owner][taker];
        }
        encumbrances[owner][taker] -= amount;
        encumberedBalance[owner] -= amount;
        emit Release(owner, taker, amount);
    }

    function mint(address recipient, uint amount) external returns (bool) {
        _mint(recipient, amount);
        IERC20(underlyingToken).transferFrom(msg.sender, address(this), amount);
        return true;
    }

    function burn(uint amount) public returns (bool) {
        uint freeBalance = freeBalanceOf(msg.sender);
        require(freeBalance >= amount, "ERC999: burn amount exceeds free balance");
        _burn(msg.sender, amount);
        IERC20(underlyingToken).transfer(msg.sender, amount);
        return true;
    }
}
