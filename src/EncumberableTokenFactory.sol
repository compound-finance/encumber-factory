// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { EncumberableToken } from "./EncumberableToken.sol";

/**
 * @title EncumberableTokenFactory
 * @notice A factory contract that deploys new EncumberableToken wrappers around
 * existing ERC20 tokens
 * @author Compound
 */
contract EncumberableTokenFactory {
    /// @notice Salt to use when deploying contracts
    bytes32 internal constant SALT = "EIP-7246";

    /**
     * @notice Deploys a new instance of EncumberableToken, wrapping the `underlyingToken`
     * @dev Will revert if an instance of EncumberableToken is already deployed for that `underlyingToken`
     * @param underlyingToken Address of the ERC20 token to create an EncumberableToken wrapper for
     * @return address The address of the newly-deployed EncumberableToken wrapper contract
     */
    function deploy(address underlyingToken) external returns (address) {
        EncumberableToken wrapper = createEncumberableToken(underlyingToken);
        return address(wrapper);
    }

    /**
     * @dev Deploy a new EncumberableToken wrapper for `underlyingToken`
     */
    function createEncumberableToken(address underlyingToken) internal returns (EncumberableToken) {
        return new EncumberableToken{salt: SALT}(underlyingToken);
    }

    /**
     * @notice Returns the EncumberableToken wrapper address for a given
     * underlyingToken (whether that contract has been deployed or not)
     * @param underlyingToken The token to return an EncumberableToken address for
     * @return address The address of the EncumberableToken wrapper for `underlyingToken`
     */
    function getDeploymentAddress(address underlyingToken) external view returns (address) {
        address predictedAddress = address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            SALT,
            keccak256(abi.encodePacked(
                type(EncumberableToken).creationCode,
                abi.encode(underlyingToken)
            ))
        )))));

        return predictedAddress;
    }
}
