// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.15;

import "./erc20/ERC20.sol";
import "./erc20/IERC20.sol";
import "./erc20/IERC20Metadata.sol";
import "./erc20/IERC20NonStandard.sol";
import "./erc20/IERC20Permit.sol";
import "./interfaces/IERC999.sol";

/**
 * @title EncumberableToken
 * @notice A contract that takes an existing ERC20 and creates a wrapped token
 * with encumbrance capabilities
 * @author Compound
 */
contract EncumberableToken is ERC20, IERC20Permit, IERC999 {
    /// @notice The major version of this contract
    string public constant version = "0";

    /// @dev The highest valid value for s in an ECDSA signature pair (0 < s < secp256k1n ÷ 2 + 1)
    ///  See https://ethereum.github.io/yellowpaper/paper.pdf #307)
    uint internal constant MAX_VALID_ECDSA_S = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0;

    /// @dev The EIP-712 typehash for authorization via permit
    bytes32 internal constant AUTHORIZATION_TYPEHASH = keccak256("Authorization(address owner,address spender,uint256 amount,uint256 nonce,uint256 expiry)");

    /// @dev The EIP-712 typehash for the contract's domain
    bytes32 internal constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    /// @notice Number of decimals used for the user represenation of the token
    uint8 private immutable _decimals;

    /// @notice Address of the ERC20 token that this token wraps
    address public immutable underlyingToken;

    /// @notice The next expected nonce for an address, for validating authorizations via signature
    mapping(address => uint) public nonces;

    /// @notice Amount of an address's token balance that is encumbered
    mapping (address => uint) public encumberedBalanceOf;

    /// @notice Amount encumbered from owner to taker (owner => taker => balance)
    mapping (address => mapping (address => uint)) public encumbrances;

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
     * @notice Number of decimals used for the user represenation of the token
     */
    function decimals() public override view returns (uint8) {
        return _decimals;
    }

    /**
     * @notice Amount of an address's token balance that is not encumbered
     * @param a Address to check the available balance of
     * @return uint Unencumbered balance
     */
    function availableBalanceOf(address a) public view returns (uint) {
        return (balanceOf(a) - encumberedBalanceOf[a]);
    }

    /**
     * @notice Moves `amount` tokens from the caller's account to `dst`
     * @dev Confirms the available balance of the caller is sufficient to cover
     * transfer
     * @param dst Address to transfer tokens to
     * @param amount Amount of token to transfer
     * @return bool Whether the operation was successful
     */
    function transfer(address dst, uint amount) public override returns (bool) {
        // check but dont spend encumbrance
        require(availableBalanceOf(msg.sender) >= amount, "ERC999: insufficient available balance");
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
        if (amount > encumberedToTaker)  {
            uint excessAmount = amount - encumberedToTaker;
            // Exceeds Encumbrance, so spend all of it
            _spendEncumbrance(src, msg.sender, encumberedToTaker);

            // Having spent all the tokens encumbered to the mover,
            // We are now moving only "available" tokens and must check
            // to not unfairly move tokens encumbered to others

           require(availableBalanceOf(src) >= excessAmount, "insufficient balance");

            _spendAllowance(src, msg.sender, excessAmount);
        } else {
            _spendEncumbrance(src, msg.sender, amount);
        }

        _transfer(src, dst, amount);
        return true;
    }

    /**
     * @dev Spend `amount` of `owner`'s encumbrance to `taker`
     */
    function _spendEncumbrance(address owner, address taker, uint amount) internal {
        uint currentEncumbrance = encumbrances[owner][taker];
        require(currentEncumbrance >= amount, "insufficient encumbrance");
        uint newEncumbrance = currentEncumbrance - amount;
        encumbrances[owner][taker] = newEncumbrance;
        encumberedBalanceOf[owner] -= amount;
    }

    /**
     * @notice Increases the amount of tokens that the caller has encumbered to
     * `taker` by `amount`
     * @param taker Address to increase encumbrance to
     * @param amount Amount of tokens to increase the encumbrance by
     */
    function encumber(address taker, uint amount) external {
        _encumber(msg.sender, taker, amount);
    }

    /**
     * @dev Increase `owner`'s encumbrance to `taker` by `amount`
     */
    function _encumber(address owner, address taker, uint amount) private {
        require(availableBalanceOf(owner) >= amount, "ERC999: insufficient available balance");
        encumbrances[owner][taker] += amount;
        encumberedBalanceOf[owner] += amount;
        emit Encumber(owner, taker, amount);
    }

    /**
     * @notice Increases the amount of tokens that `owner` has encumbered to
     * `taker` by `amount`.
     * @dev Spends the caller's `allowance`
     * @param owner Address to increase encumbrance from
     * @param taker Address to increase encumbrance to
     * @param amount Amount of tokens to increase the encumbrance to `taker` by
     */
    function encumberFrom(address owner, address taker, uint amount) external {
        require(allowance(owner, msg.sender) >= amount, "ERC999: insufficient allowance");
        // spend caller's allowance
        _spendAllowance(owner, msg.sender, amount);
        _encumber(owner, taker, amount);
    }

    /**
     * @notice Reduces amount of tokens encumbered from `owner` to caller by
     * `amount`
     * @dev Spends all of the encumbrance if `amount` is greater than `owner`'s
     * current encumbrance to caller
     * @param owner Address to decrease encumbrance from
     * @param amount Amount of tokens to decrease the encumbrance by
     */
    function release(address owner, uint amount) external {
        _release(owner, msg.sender, amount);
    }

    /**
     * @dev Reduce `owner`'s encumbrance to `taker` by `amount`
     */
    function _release(address owner, address taker, uint amount) private {
        if (encumbrances[owner][taker] < amount) {
          amount = encumbrances[owner][taker];
        }
        encumbrances[owner][taker] -= amount;
        encumberedBalanceOf[owner] -= amount;
        emit Release(owner, taker, amount);
    }

    /**
     * @notice Creates `amount` tokens and assigns them to `recipient` in
     * exchange for an equal amount of the underlying token
     * @param recipient Address to mint tokens to
     * @param amount Number of tokens to mint
     */
    function mint(address recipient, uint amount) external {
        doTransferIn(underlyingToken, msg.sender, amount);
        _mint(recipient, amount);
    }

    /**
     * @notice Destroys `amount` tokens and transfers the same amount of the
     * underlying token to `recipient`
     * @param recipient Address to burn tokens to
     * @param amount Number of tokens to burn
     */
    function burn(address recipient, uint amount) external {
        uint availableBalance = availableBalanceOf(msg.sender);
        require(availableBalance >= amount, "ERC999: burn amount exceeds available balance");
        _burn(msg.sender, amount);
        doTransferOut(underlyingToken, recipient, amount);
    }

    /**
     * @notice Returns the domain separator used in the encoding of the
     * signature for permit
     */
    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name())), keccak256(bytes(version)), block.chainid, address(this)));
    }

    /**
     * @notice Sets authorization status for a manager via signature from signatory
     * @param owner The address that signed the signature
     * @param spender The address to authorize (or rescind authorization from)
     * @param amount Amount that `owner` is approving for `spender`
     * @param expiry Expiration time for the signature
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function permit(
        address owner,
        address spender,
        uint256 amount,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(uint256(s) <= MAX_VALID_ECDSA_S, "Invalid value s");
        // v ∈ {27, 28} (source: https://ethereum.github.io/yellowpaper/paper.pdf #308)
        require(v == 27 || v == 28, 'Invalid value v');
        uint nonce = nonces[owner];
        bytes32 structHash = keccak256(abi.encode(AUTHORIZATION_TYPEHASH, owner, spender, amount, nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), structHash));
        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), 'Bad signatory');
        require(owner == signatory, 'Bad signatory');
        require(block.timestamp < expiry, 'Signature expired');
        _approve(owner, spender, amount);
        nonces[signatory]++;
    }

    /**
     * @notice Similar to ERC-20 transfer, except it properly handles `transferFrom` from non-standard ERC-20 tokens
     * @param asset The ERC-20 token to transfer in
     * @param from The address to transfer from
     * @param amount The amount of the token to transfer
     * @dev Note: This does not check that the amount transferred in is actually equals to the amount specified (e.g. fee tokens will not revert)
     * @dev Note: This wrapper safely handles non-standard ERC-20 tokens that do not return a value. See here: https://medium.com/coinmonks/missing-return-value-bug-at-least-130-tokens-affected-d67bf08521ca
     */
    function doTransferIn(address asset, address from, uint amount) internal {
        IERC20NonStandard(asset).transferFrom(from, address(this), amount);

        bool success;
        assembly {
            switch returndatasize()
                case 0 {                       // This is a non-standard ERC-20
                    success := not(0)          // set success to true
                }
                case 32 {                      // This is a compliant ERC-20
                    returndatacopy(0, 0, 32)
                    success := mload(0)        // Set `success = returndata` of override external call
                }
                default {                      // This is an excessively non-compliant ERC-20, revert.
                    revert(0, 0)
                }
        }
        require(success, "Transfer in failed");
    }

    /**
     * @notice Similar to ERC-20 transfer, except it properly handles `transfer` from non-standard ERC-20 tokens
     * @param asset The ERC-20 token to transfer out
     * @param to The recipient of the token transfer
     * @param amount The amount of the token to transfer
     * @dev Note: This wrapper safely handles non-standard ERC-20 tokens that do not return a value. See here: https://medium.com/coinmonks/missing-return-value-bug-at-least-130-tokens-affected-d67bf08521ca
     */
    function doTransferOut(address asset, address to, uint amount) internal {
        IERC20NonStandard(asset).transfer(to, amount);

        bool success;
        assembly {
            switch returndatasize()
                case 0 {                      // This is a non-standard ERC-20
                    success := not(0)         // set success to true
                }
                case 32 {                     // This is a compliant ERC-20
                    returndatacopy(0, 0, 32)
                    success := mload(0)       // Set `success = returndata` of override external call
                }
                default {                     // This is an excessively non-compliant ERC-20, revert.
                    revert(0, 0)
                }
        }
        require(success, "Transfer out failed");
    }
}
