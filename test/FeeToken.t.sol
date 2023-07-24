pragma solidity ^0.8.20;

import "forge-std/StdUtils.sol";
import { Test } from "forge-std/Test.sol";
import { EncumberableToken } from "../src/EncumberableToken.sol";
import { FeeToken } from "../src/test/FeeToken.sol";

contract FeeTokenTest is Test {
    FeeToken public feeToken;
    EncumberableToken public wrappedToken;

    address alice = address(10);
    address bob = address(11);
    address charlie = address(12);

    function setUp() public {
        feeToken = new FeeToken("Fee Token", "FEETO");
        wrappedToken = new EncumberableToken(address(feeToken));
    }

    function testFeeOnTransfer() public {
        deal(address(feeToken), alice, 100e18);

        vm.prank(alice);
        feeToken.transfer(bob, 100e18);

        assertEq(feeToken.balanceOf(alice), 0);
        assertEq(feeToken.balanceOf(bob), 99e18);
        assertEq(feeToken.balanceOf(address(feeToken)), 1e18);
    }

    function testFeeOnTransferFrom() public {
        deal(address(feeToken), alice, 100e18);

        vm.prank(alice);
        feeToken.approve(bob, 100e18);

        vm.prank(bob);
        feeToken.transferFrom(alice, charlie, 100e18);

        assertEq(feeToken.balanceOf(alice), 0);
        assertEq(feeToken.balanceOf(bob), 0);
        assertEq(feeToken.balanceOf(charlie), 99e18);
        assertEq(feeToken.balanceOf(address(feeToken)), 1e18);
    }

    function testRevertOnTransferInWithFee() public {
        deal(address(feeToken), alice, 100e18);

        vm.startPrank(alice);
        feeToken.approve(address(wrappedToken), 100e18);

        vm.expectRevert("ERC7246: insufficient amount transferred in");
        wrappedToken.wrap(alice, 100e18);

        vm.stopPrank();
    }
}