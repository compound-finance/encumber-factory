// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC7246 standard.
 */
interface IERC7246 {
    /**
     * @dev Emitted when `amount` tokens are encumbered from `owner` to `taker`.
     */
    event Encumber(address indexed owner, address indexed taker, uint256 amount);

    /**
     * @dev Emitted when the encumbrance of an `owner` to a `taker` is reduced
     * by `amount`.
     */
    event Release(address indexed owner, address indexed taker, uint256 amount);

    /**
     * @dev Emitted when `amount` of encumbrance of an `owner` to a `taker` is
     * spent.
     */
    event EncumbranceSpend(address indexed owner, address indexed taker, uint256 amount);

    /**
     * @dev Returns the total amount of tokens owned by `owner` that are
     * currently encumbered.  MUST never exceed `balanceOf(owner)`
     *
     * Any function which would reduce balanceOf(owner) below
     * encumberedBalanceOf(owner) MUST revert
     */
    function encumberedBalanceOf(address owner) external view returns (uint256);

    /**
     * @dev Returns the number of tokens that `owner` has encumbered to `taker`.
     *
     * This value increases when {encumber} or {encumberFrom} are called by the
     * `owner` or by another permitted account.
     * This value decreases when {release} and {transferFrom} are called by
     * `taker`.
     */
    function encumbrances(address owner, address taker) external view returns (uint256);

    /**
     * @dev Increases the amount of tokens that the caller has encumbered to
     * `taker` by `amount`.
     * Grants to `taker` a guaranteed right to transfer `amount` from the
     * caller's balance by using `transferFrom`.
     *
     * MUST revert if caller does not have `amount` tokens available (e.g. if
     * `balanceOf(caller) - encumbrances(caller) < amount`).
     *
     * Emits an {Encumber} event.
     */
    function encumber(address taker, uint256 amount) external;

    /**
     * @dev Increases the amount of tokens that `owner` has encumbered to
     * `taker` by `amount`.
     * Grants to `taker` a guaranteed right to transfer `amount` from `owner`
     * using transferFrom
     *
     * The function SHOULD revert unless the owner account has deliberately
     * authorized the sender of the message via some mechanism.
     *
     * MUST revert if `owner` does not have `amount` tokens available (e.g. if
     * `balanceOf(owner) - encumbrances(owner) < amount`).
     *
     * Emits an {Encumber} event.
     */
    function encumberFrom(address owner, address taker, uint256 amount) external;

    /**
     * @dev Reduces amount of tokens encumbered from `owner` to caller by
     * `amount`.
     *
     * Emits a {Release} event.
     */
    function release(address owner, uint256 amount) external;

    /**
     * @dev Convenience function for reading the unencumbered balance of an address.
     * Trivially implemented as `balanceOf(owner) - encumberedBalanceOf(owner)`
     */
    function availableBalanceOf(address owner) external view returns (uint256);
}