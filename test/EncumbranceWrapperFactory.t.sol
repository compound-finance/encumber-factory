pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../src/EncumbranceWrapperFactory.sol";
import "../src/erc20/ERC20.sol";
import "../src/erc20/IERC20Metadata.sol";


contract EncumbranceWrapperFactoryTest is Test {
    EncumbranceWrapperFactory public wrapperFactory;
    ERC20 public erc20;
    address public wrappedTestToken;

    function setUp() public {
        wrapperFactory = new EncumbranceWrapperFactory();
        erc20 = new ERC20("TEST TOKEN", "TTKN");
        wrappedTestToken = wrapperFactory.deploy(address(erc20));
    }

    function testWrappedName() public {
        assertEq(IERC20Metadata(wrappedTestToken).name(), "encumbered TEST TOKEN");
    }

    function testWrappedSymbol() public {
        assertEq(IERC20Metadata(wrappedTestToken).symbol(), "eTTKN");
    }

    function testGetDeploymentAddress() public {
        assertEq(
            wrapperFactory.getDeploymentAddress(address(erc20)),
            wrappedTestToken
        );
    }

    function testRevertOnDuplicate() public {
        // should revert if deploy is attempted a second time with the same
        // ERC20 address
        vm.expectRevert();
        wrapperFactory.deploy(address(erc20));
    }
}
