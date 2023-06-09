// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC999 standard as defined in the EIP.
 */
interface IERC999 {
    /**
     * @dev Emitted when `amount` tokens are encumbered from `owner` to `taker`.
     */
    event Encumber(address indexed owner, address indexed taker, uint amount);

    /**
     * @dev Emitted when `amount` tokens are released from `owner` by `taker`.
     */
    event Release(address indexed owner, address indexed taker, uint amount);

    /**
     * @dev Returns the amount of tokens owned by `owner` that are currently
     * encumbered.
     */
    function encumberedBalance(address owner) external returns (uint);

    /**
     * @dev Returns the number of tokens that `owner` has encumbered to `taker`.
     * This is zero by default.
     *
     * This value changes when {encumber}, {encumberFrom}, {release},
     * {transfer}, or {transferFrom} are called.
     */
    function encumbrances(address owner, address taker) external returns (uint);

    /**
     * @dev Increases the amount of tokens that the caller has encumbered to
     * `taker` by `amount`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits an {Encumber} event.
     */
    function encumber(address taker, uint amount) external returns (bool);

    /**
     * @dev Increases the amount of tokens that `owner` has encumbered to
     * `taker` by `amount`. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits an {Encumber} event.
     */
    function encumberFrom(address owner, address taker, uint amount) external returns (bool);

    /**
     * @dev Reduces amount of tokens encumbered from `owner` to caller by
     * `amount`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Release} event.
     */
    function release(address owner, uint amount) external returns (bool);
}
