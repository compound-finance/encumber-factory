pragma solidity ^0.8.15;

import { Test } from "forge-std/Test.sol";
import { EncumberableTokenFactory } from "../src/EncumberableTokenFactory.sol";
import { ERC20 } from "../src/vendor/ERC20.sol";
import { IERC20Metadata } from "../src/vendor/IERC20Metadata.sol";

contract EncumberableTokenFactoryTest is Test {
    EncumberableTokenFactory public wrapperFactory;
    ERC20 public erc20;
    address public wrappedToken;

    function setUp() public {
        wrapperFactory = new EncumberableTokenFactory();
        erc20 = new ERC20("TEST TOKEN", "TTKN");
        wrappedToken = wrapperFactory.deploy(address(erc20));
    }

    function testWrappedName() public {
        assertEq(IERC20Metadata(wrappedToken).name(), "Encumberable TEST TOKEN");
    }

    function testWrappedSymbol() public {
        assertEq(IERC20Metadata(wrappedToken).symbol(), "eTTKN");
    }

    function testGetDeploymentAddress() public {
        assertEq(
            wrapperFactory.getDeploymentAddress(address(erc20)),
            wrappedToken
        );
    }

    function testRevertOnDuplicate() public {
        // should revert if deploy is attempted a second time with the same
        // ERC20 address
        vm.expectRevert();
        wrapperFactory.deploy(address(erc20));
    }
}
