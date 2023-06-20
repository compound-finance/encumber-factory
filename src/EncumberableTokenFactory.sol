// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.15;

import "./EncumberableToken.sol";

contract EncumberableTokenFactory {
    bytes32 constant SALT = "";

    function deploy(address underlyingToken) external returns (address) {
        EncumberableToken wrapper = createEncumberableToken(underlyingToken);
        return address(wrapper);
    }

    function createEncumberableToken(address underlyingToken) internal returns (EncumberableToken) {
        return new EncumberableToken{salt: SALT}(underlyingToken);
    }

    function getDeploymentAddress(address underlyingToken) external view returns (address) {
        address predictedAddress = address(uint160(uint(keccak256(abi.encodePacked(
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
