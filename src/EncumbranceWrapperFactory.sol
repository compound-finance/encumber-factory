pragma solidity ^0.8.15;

import "./EncumbranceWrapper.sol";

contract EncumbranceWrapperFactory {
    uint constant SALT = 0;

    function deploy(address underlyingToken) public returns (address) {
        EncumbranceWrapper wrapper = createWrapper(underlyingToken);
        return address(wrapper);
    }

    function createWrapper(address underlyingToken) internal returns (EncumbranceWrapper) {
        address payable addr;
        bytes memory code = abi.encodePacked(
            type(EncumbranceWrapper).creationCode,
            abi.encode(underlyingToken)
        );
        uint salt = SALT;

        assembly {
            addr := create2(0, add(code, 0x20), mload(code), salt)
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }

        return EncumbranceWrapper(addr);
    }

    function getDeploymentAddress(address underlyingToken) public view returns (address) {
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
