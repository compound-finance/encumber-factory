pragma solidity ^0.8.15;

import "./EncumbranceWrapper.sol";

contract EncumbranceWrapperFactory {
    bytes32 constant SALT = "";

    function deploy(address underlyingToken) external returns (address) {
        EncumbranceWrapper wrapper = createWrapper(underlyingToken);
        return address(wrapper);
    }

    function createWrapper(address underlyingToken) internal returns (EncumbranceWrapper) {
        return new EncumbranceWrapper{salt: ""}(underlyingToken);
    }

    function getDeploymentAddress(address underlyingToken) external view returns (address) {
        address predictedAddress = address(uint160(uint(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            SALT,
            keccak256(abi.encodePacked(
                type(EncumbranceWrapper).creationCode,
                abi.encode(underlyingToken)
            ))
        )))));

        return predictedAddress;
    }
}
