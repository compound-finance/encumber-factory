pragma solidity ^0.8.15;

import "./erc20/ERC20.sol";
import "./erc20/IERC20.sol";
import "./erc20/IERC20Metadata.sol";
import "./interfaces/IERC999.sol";

/**
 * @title EncumbranceWrapper
 * @notice A contract that takes an existing ERC20 and creates a wrapped token
 * with encumbrance capabilities
 * @author Compound
 */
contract EncumbranceWrapper is ERC20, IERC999 {
    /// @notice Number of decimals used for the user represenation of the token
    uint8 private immutable _decimals;

    /// @notice Address of the ERC20 token that this token wraps
    address public immutable underlyingToken;

    /// @notice Amount of an address's token balance that is encumbered
    mapping (address => uint) public encumberedBalance;

    /// @notice Amount encumbered from owner to taker (owner => taker => balance)
    mapping (address => mapping (address => uint)) public encumbrances;

    /// @notice Index to apply when storing or returning principal balances
    uint256 private idx = 1e15;

    // @notice The scale for factors
    uint256 constant private FACTOR_SCALE = 1e15;

    /// @notice This contract's balance of the underlying token, when last
    /// checked
    uint256 private lastUnderlyingBalance;

    /**
     * @notice Construct a new wrapper instance
     * @param _underlyingToken Address of the underlying token to wrap
     **/
    constructor(address _underlyingToken) ERC20(
        string.concat("Encumberable ", IERC20Metadata(_underlyingToken).name()),
        string.concat("e", IERC20Metadata(_underlyingToken).symbol())
    ) {
        _decimals = IERC20Metadata(_underlyingToken).decimals();
        underlyingToken = _underlyingToken;
    }

    /**
     * @notice Total supply of the token
     * @dev is a reflection not of the number of wrapped tokens that have been
     * minted, but of the number of underlying token that those wrapped tokens
     * can be redeemed for
     */
    function totalSupply() public view virtual override returns (uint256) {
        return ERC20(underlyingToken).balanceOf(address(this));
    }

    /**
     * @notice Number of decimals used for the user represenation of the token
     */
    function decimals() public override view returns (uint8) {
        return _decimals;
    }

    /**
     * @notice Returns the amount of tokens owned by `owner`.
     * @dev internal balance is used to determine the portion of the underlying
     * balance that belongs to `owner`
     */
    function balanceOf(address owner) public view override returns (uint256) {
        if (lastUnderlyingBalance == 0) {
            return 0;
        }
        return super.balanceOf(owner) * idx * ERC20(underlyingToken).balanceOf(address(this)) / FACTOR_SCALE / lastUnderlyingBalance;
    }

    /**
     * @notice Amount of an address's token balance that is not encumbered
     * @param a Address to check the free balance of
     * @return uint Unencumbered balance
     */
    function freeBalanceOf(address a) public view returns (uint) {
        return (balanceOf(a) - encumberedBalance[a]);
    }

    /**
     * @notice Moves `amount` tokens from the caller's account to `dst`
     * @dev Confirms the free balance of the caller is sufficient to cover
     * transfer
     * @param dst Address to transfer tokens to
     * @param amount Amount of token to transfer
     * @return bool Whether the operation was successful
     */
    function transfer(address dst, uint amount) public override returns (bool) {
        // check but dont spend encumbrance
        require(freeBalanceOf(msg.sender) >= amount, "ERC999: insufficient free balance");
        _transfer(msg.sender, dst, amount);
        return true;
    }

    /**
     * @notice Moves `amount` tokens from `src` to `dst` using the encumbrance
     * and allowance of the caller
     * @dev Spends the caller's encumbrance from `src` first, then their
     * allowance from `src` (if necessary)
     * @param src Address to transfer tokens from
     * @param dst Address to transfer tokens to
     * @param amount Amount of token to transfer
     * @return bool Whether the operation was successful
     */
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

    /**
     * @notice Transfers `amount` of tokens from `from` to `to`
     */
    function _update(address from, address to, uint256 amount) internal override {
        uint256 principalAmount = amount * FACTOR_SCALE / idx;
        if (from != address(0)) {
            uint256 fromBalance = _balances[from];
            require(fromBalance >= principalAmount, "ERC20: transfer amount exceeds balance");
            _balances[from] = fromBalance - principalAmount;
        }

        if (to != address(0)) {
            _balances[to] += principalAmount;
        }

        emit Transfer(from, to, amount);
    }

    /**
     * @dev Spend `amount` of `owner`'s encumbrance to `taker`
     */
    function _spendEncumbrance(address owner, address taker, uint amount) internal {
        uint currentEncumbrance = encumbrances[owner][taker];
        require(currentEncumbrance >= amount, "insufficient encumbrance");
        uint newEncumbrance = currentEncumbrance - amount;
        encumbrances[owner][taker] = newEncumbrance;
        encumberedBalance[owner] -= amount;
    }

    /**
     * @notice Increases the amount of tokens that the caller has encumbered to
     * `taker` by `amount`
     * @param taker Address to increase encumbrance to
     * @param amount Amount of tokens to increase the encumbrance by
     * @return bool Whether the operation was successful
     */
    function encumber(address taker, uint amount) external returns (bool) {
        _encumber(msg.sender, taker, amount);
        return true;
    }

    /**
     * @dev Increase `owner`'s encumbrance to `taker` by `amount`
     */
    function _encumber(address owner, address taker, uint amount) private {
        require(freeBalanceOf(owner) >= amount, "ERC999: insufficient free balance");
        encumbrances[owner][taker] += amount;
        encumberedBalance[owner] += amount;
        emit Encumber(owner, taker, amount);
    }

    /**
     * @notice Increases the amount of tokens that `owner` has encumbered to
     * `taker` by `amount`.
     * @dev Spends the caller's `allowance`
     * @param owner Address to increase encumbrance from
     * @param taker Address to increase encumbrance to
     * @param amount Amount of tokens to increase the encumbrance to `taker` by
     * @return bool Whether the operation was successful
     */
    function encumberFrom(address owner, address taker, uint amount) external returns (bool) {
        require(allowance(owner, msg.sender) >= amount, "ERC999: insufficient allowance");
        // spend caller's allowance
        _spendAllowance(owner, msg.sender, amount);
        _encumber(owner, taker, amount);
        return true;
    }

    /**
     * @notice Reduces amount of tokens encumbered from `owner` to caller by
     * `amount`
     * @dev Spends all of the encumbrance if `amount` is greater than `owner`'s
     * current encumbrance to caller
     * @param owner Address to decrease encumbrance from
     * @param amount Amount of tokens to decrease the encumbrance by
     * @return bool Whether the operation was successful
     */
    function release(address owner, uint amount) external returns (bool) {
        _release(owner, msg.sender, amount);
        return true;
    }

    /**
     * @dev Reduce `owner`'s encumbrance to `taker` by `amount`
     */
    function _release(address owner, address taker, uint amount) private {
        if (encumbrances[owner][taker] < amount) {
          amount = encumbrances[owner][taker];
        }
        encumbrances[owner][taker] -= amount;
        encumberedBalance[owner] -= amount;
        emit Release(owner, taker, amount);
    }

    /**
     * @notice Creates `amount` tokens and assigns them to `recipient` in
     * exchange for an equal amount of the underlying token
     * @param recipient Address to mint tokens to
     * @param amount Number of tokens to mint
     * @return bool Whether the operation was successful
     */
    function mint(address recipient, uint amount) external returns (bool) {
        accrue();

        IERC20(underlyingToken).transferFrom(msg.sender, address(this), amount);
        lastUnderlyingBalance = ERC20(underlyingToken).balanceOf(address(this));

        _mint(recipient, amount);
        return true;
    }

    function accrue() internal {
        uint currentBalance = ERC20(underlyingToken).balanceOf(address(this));
        uint diff = currentBalance - lastUnderlyingBalance;
        if (diff != 0) {
            idx += idx * (diff * FACTOR_SCALE / lastUnderlyingBalance) / FACTOR_SCALE;
            lastUnderlyingBalance = currentBalance;
        }
    }

    /**
     * @notice Destroys `amount` tokens and transfers the same amount of the underlying token to `recipient`
     * @param amount Number of tokens to burn
     * @return bool Whether the operation was successful
     */
    function burn(uint amount) public returns (bool) {
        accrue();

        uint freeBalance = freeBalanceOf(msg.sender);
        require(freeBalance >= amount, "ERC999: burn amount exceeds free balance");

        IERC20(underlyingToken).transfer(msg.sender, amount);
        lastUnderlyingBalance = ERC20(underlyingToken).balanceOf(address(this));

        _burn(msg.sender, amount);
        return true;
    }
}
