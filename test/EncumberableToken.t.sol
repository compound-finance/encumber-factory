pragma solidity ^0.8.20;

import "forge-std/StdUtils.sol";
import { Test } from "forge-std/Test.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { EncumberableToken } from "../src/EncumberableToken.sol";

contract EncumberableTokenTest is Test {
    event EncumbranceUpdate(address indexed owner, address indexed taker, uint256 previousAmount, uint256 newAmount);

    ERC20 public underlyingToken;
    EncumberableToken public wrappedToken;

    address alice = address(10);
    address bob = address(11);
    address charlie = address(12);

    function setUp() public {
        underlyingToken = new ERC20("TEST TOKEN", "TTKN");
        wrappedToken = new EncumberableToken(address(underlyingToken));
    }

    function testWrappedName() public {
        assertEq(wrappedToken.name(), "Encumberable TEST TOKEN");
    }

    function testWrappedSymbol() public {
        assertEq(wrappedToken.symbol(), "eTTKN");
    }

    function testWrappedDecimals() public {
        // XXX test with a value other than 18
        assertEq(wrappedToken.decimals(), 18);
    }

    function testAvailableBalanceOf() public {
        vm.startPrank(alice);

        // availableBalanceOf is 0 by default
        assertEq(wrappedToken.availableBalanceOf(alice), 0);

        // reflects balance when there are no encumbrances
        deal(address(wrappedToken), alice, 100e18);
        assertEq(wrappedToken.balanceOf(alice), 100e18);
        assertEq(wrappedToken.availableBalanceOf(alice), 100e18);

        // is reduced by encumbrances
        wrappedToken.encumber(bob, 20e18);
        assertEq(wrappedToken.balanceOf(alice), 100e18);
        assertEq(wrappedToken.availableBalanceOf(alice), 80e18);

        // is reduced by transfers
        wrappedToken.transfer(bob, 20e18);
        assertEq(wrappedToken.balanceOf(alice), 80e18);
        assertEq(wrappedToken.availableBalanceOf(alice), 60e18);

        vm.stopPrank();

        vm.startPrank(bob);

        // is NOT reduced by transferFrom (from an encumbered address)
        wrappedToken.transferFrom(alice, charlie, 10e18);
        assertEq(wrappedToken.balanceOf(alice), 70e18);
        assertEq(wrappedToken.availableBalanceOf(alice), 60e18);
        assertEq(wrappedToken.encumbrances(alice, bob), 10e18);
        assertEq(wrappedToken.balanceOf(charlie), 10e18);

        // is increased by a release
        wrappedToken.release(alice, 5e18);
        assertEq(wrappedToken.balanceOf(alice), 70e18);
        assertEq(wrappedToken.availableBalanceOf(alice), 65e18);
        assertEq(wrappedToken.encumbrances(alice, bob), 5e18);

        vm.stopPrank();
    }

    function testTransferRevertInsufficentBalance() public {
        deal(address(wrappedToken), alice, 100e18);
        vm.startPrank(alice);

        // alice encumbers half her balance to bob
        wrappedToken.encumber(bob, 50e18);

        // alice attempts to transfer her entire balance
        vm.expectRevert("ERC7246: insufficient available balance");
        wrappedToken.transfer(charlie, 100e18);

        vm.stopPrank();
    }

    function testEncumberRevert() public {
        deal(address(wrappedToken), alice, 100e18);
        vm.startPrank(alice);

        // alice encumbers half her balance to bob
        wrappedToken.encumber(bob, 50e18);

        // alice attempts to encumber more than her remaining available balance
        vm.expectRevert("ERC7246: insufficient available balance");
        wrappedToken.encumber(charlie, 60e18);

        vm.stopPrank();
    }

    function testEncumber() public {
        deal(address(wrappedToken), alice, 100e18);
        vm.startPrank(alice);

        // emits EncumbranceUpdate event
        vm.expectEmit(true, true, true, true);
        emit EncumbranceUpdate(alice, bob, 0, 60e18);

        // alice encumbers some of her balance to bob
        wrappedToken.encumber(bob, 60e18);

        // balance is unchanged
        assertEq(wrappedToken.balanceOf(alice), 100e18);
        // available balance is reduced
        assertEq(wrappedToken.availableBalanceOf(alice), 40e18);

        // creates encumbrance for taker
        assertEq(wrappedToken.encumbrances(alice, bob), 60e18);

        // updates encumbered balance of owner
        assertEq(wrappedToken.encumberedBalanceOf(alice), 60e18);
    }

    function testTransferFromSufficientEncumbrance() public {
        deal(address(wrappedToken), alice, 100e18);
        vm.prank(alice);

        // alice encumbers some of her balance to bob
        wrappedToken.encumber(bob, 60e18);

        assertEq(wrappedToken.balanceOf(alice), 100e18);
        assertEq(wrappedToken.availableBalanceOf(alice), 40e18);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 60e18);
        assertEq(wrappedToken.encumbrances(alice, bob), 60e18);
        assertEq(wrappedToken.balanceOf(charlie), 0);

        // bob calls transfers from alice to charlie
        vm.startPrank(bob);
        // emits EncumbranceUpdate event
        vm.expectEmit(true, true, true, true);
        emit EncumbranceUpdate(alice, bob, 60e18, 20e18);
        wrappedToken.transferFrom(alice, charlie, 40e18);
        vm.stopPrank();

        // alice balance is reduced
        assertEq(wrappedToken.balanceOf(alice), 60e18);
        // alice encumbrance to bob is reduced
        assertEq(wrappedToken.availableBalanceOf(alice), 40e18);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 20e18);
        assertEq(wrappedToken.encumbrances(alice, bob), 20e18);
        // transfer is completed
        assertEq(wrappedToken.balanceOf(charlie), 40e18);
    }

    function testTransferFromEncumbranceAndAllowance() public {
        deal(address(wrappedToken), alice, 100e18);
        vm.startPrank(alice);

        // alice encumbers some of her balance to bob
        wrappedToken.encumber(bob, 20e18);

        // she also grants him an approval
        wrappedToken.approve(bob, 30e18);

        vm.stopPrank();

        assertEq(wrappedToken.balanceOf(alice), 100e18);
        assertEq(wrappedToken.availableBalanceOf(alice), 80e18);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 20e18);
        assertEq(wrappedToken.encumbrances(alice, bob), 20e18);
        assertEq(wrappedToken.allowance(alice, bob), 30e18);
        assertEq(wrappedToken.balanceOf(charlie), 0);

        // bob calls transfers from alice to charlie
        vm.prank(bob);
        wrappedToken.transferFrom(alice, charlie, 40e18);

        // alice balance is reduced
        assertEq(wrappedToken.balanceOf(alice), 60e18);

        // her encumbrance to bob has been fully spent
        assertEq(wrappedToken.availableBalanceOf(alice), 60e18);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 0);
        assertEq(wrappedToken.encumbrances(alice, bob), 0);

        // her allowance to bob has been partially spent
        assertEq(wrappedToken.allowance(alice, bob), 10e18);

        // the dst receives the transfer
        assertEq(wrappedToken.balanceOf(charlie), 40e18);
    }

    function testTransferFromInsufficientAllowance() public {
        deal(address(wrappedToken), alice, 100e18);

        vm.startPrank(alice);

        // alice encumbers some of her balance to bob
        wrappedToken.encumber(bob, 10e18);

        // she also grants him an approval
        wrappedToken.approve(bob, 20e18);

        vm.stopPrank();

        assertEq(wrappedToken.balanceOf(alice), 100e18);
        assertEq(wrappedToken.availableBalanceOf(alice), 90e18);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 10e18);
        assertEq(wrappedToken.encumbrances(alice, bob), 10e18);
        assertEq(wrappedToken.allowance(alice, bob), 20e18);
        assertEq(wrappedToken.balanceOf(charlie), 0);

        // bob tries to transfer more than his encumbered and allowed balances
        vm.prank(bob);
        vm.expectRevert("ERC20: insufficient allowance");
        wrappedToken.transferFrom(alice, charlie, 40e18);
    }

    function testEncumberFromInsufficientAllowance() public {
        deal(address(wrappedToken), alice, 100e18);

        // alice grants bob an approval
        vm.prank(alice);
        wrappedToken.approve(bob, 50e18);

        // but bob tries to encumber more than his allowance
        vm.prank(bob);
        vm.expectRevert("ERC7246: insufficient allowance");
        wrappedToken.encumberFrom(alice, charlie, 60e18);
    }

    function testEncumberFrom() public {
        deal(address(wrappedToken), alice, 100e18);

        // alice grants bob an approval
        vm.prank(alice);
        wrappedToken.approve(bob, 100e18);

        assertEq(wrappedToken.balanceOf(alice), 100e18);
        assertEq(wrappedToken.availableBalanceOf(alice), 100e18);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 0e18);
        assertEq(wrappedToken.encumbrances(alice, bob), 0e18);
        assertEq(wrappedToken.allowance(alice, bob), 100e18);
        assertEq(wrappedToken.balanceOf(charlie), 0);

        // but bob tries to encumber more than his allowance
        vm.prank(bob);
        // emits an EncumbranceUpdate event
        vm.expectEmit(true, true, true, true);
        emit EncumbranceUpdate(alice, charlie, 0, 60e18);
        wrappedToken.encumberFrom(alice, charlie, 60e18);

        // no balance is transferred
        assertEq(wrappedToken.balanceOf(alice), 100e18);
        assertEq(wrappedToken.balanceOf(charlie), 0);
        // but available balance is reduced
        assertEq(wrappedToken.availableBalanceOf(alice), 40e18);
        // encumbrance to charlie is created
        assertEq(wrappedToken.encumberedBalanceOf(alice), 60e18);
        assertEq(wrappedToken.encumbrances(alice, bob), 0e18);
        assertEq(wrappedToken.encumbrances(alice, charlie), 60e18);
        // allowance is partially spent
        assertEq(wrappedToken.allowance(alice, bob), 40e18);
    }

    function testRelease() public {
        deal(address(wrappedToken), alice, 100e18);

        vm.prank(alice);

        // alice encumbers her balance to bob
        wrappedToken.encumber(bob, 100e18);

        assertEq(wrappedToken.balanceOf(alice), 100e18);
        assertEq(wrappedToken.availableBalanceOf(alice), 0);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 100e18);
        assertEq(wrappedToken.encumbrances(alice, bob), 100e18);

        // bob releases part of the encumbrance
        vm.prank(bob);
        // emits EncumbranceUpdate event
        vm.expectEmit(true, true, true, true);
        emit EncumbranceUpdate(alice, bob, 100e18, 60e18);
        wrappedToken.release(alice, 40e18);

        assertEq(wrappedToken.balanceOf(alice), 100e18);
        assertEq(wrappedToken.availableBalanceOf(alice), 40e18);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 60e18);
        assertEq(wrappedToken.encumbrances(alice, bob), 60e18);
    }

    function testReleaseInsufficientEncumbrance() public {
        deal(address(wrappedToken), alice, 100e18);

        vm.prank(alice);

        // alice encumbers her balance to bob
        wrappedToken.encumber(bob, 100e18);

        assertEq(wrappedToken.balanceOf(alice), 100e18);
        assertEq(wrappedToken.availableBalanceOf(alice), 0);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 100e18);
        assertEq(wrappedToken.encumbrances(alice, bob), 100e18);

        // bob releases a greater amount than is encumbered to him
        vm.prank(bob);
        vm.expectRevert("ERC7246: insufficient encumbrance");
        wrappedToken.release(alice, 200e18);

        assertEq(wrappedToken.balanceOf(alice), 100e18);
        assertEq(wrappedToken.availableBalanceOf(alice), 0);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 100e18);
        assertEq(wrappedToken.encumbrances(alice, bob), 100e18);
    }

    function testWrap() public {
        // alice has a balance of the underlying token
        deal(address(underlyingToken), alice, 100e18);

        // she wraps 40 tokens to bob
        vm.startPrank(alice);
        underlyingToken.approve(address(wrappedToken), 100e18);
        wrappedToken.wrap(bob, 40e18);
        vm.stopPrank();

        // the underlying token has been transferred in from alice
        assertEq(underlyingToken.balanceOf(alice), 60e18);
        assertEq(underlyingToken.balanceOf(address(wrappedToken)), 40e18);

        // bob has a balance of the wrapped token
        assertEq(wrappedToken.balanceOf(bob), 40e18);

        // total supply is increased
        assertEq(wrappedToken.totalSupply(), 40e18);
    }

    function testWrapRevert() public {
        // alice has a balance of the underlying token
        deal(address(underlyingToken), alice, 100e18);

        // she wraps more than she has in the underlying token
        vm.startPrank(alice);
        underlyingToken.approve(address(wrappedToken), type(uint256).max);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        wrappedToken.wrap(alice, 200e18);
        vm.stopPrank();
    }

    function testUnwrap() public {
        // alice has a balance of the underlying token
        deal(address(underlyingToken), alice, 100e18);

        // she wraps 40 tokens to herself
        vm.startPrank(alice);
        underlyingToken.approve(address(wrappedToken), 100e18);
        wrappedToken.wrap(alice, 40e18);

        // the underlying token has been transferred in from alice
        assertEq(underlyingToken.balanceOf(alice), 60e18);
        assertEq(underlyingToken.balanceOf(address(wrappedToken)), 40e18);

        // alice has a balance of the wrapped token
        assertEq(wrappedToken.balanceOf(alice), 40e18);

        // total supply is increased
        assertEq(wrappedToken.totalSupply(), 40e18);

        // she unwraps 20 wrapped tokens
        wrappedToken.unwrap(alice, 20e18);

        // alice's balance of the wrapped token is decreased
        assertEq(wrappedToken.balanceOf(alice), 20e18);

        // total supply is decreased
        assertEq(wrappedToken.totalSupply(), 20e18);

        // the underlying token has been transferred back to alice
        assertEq(underlyingToken.balanceOf(alice), 80e18);
        assertEq(underlyingToken.balanceOf(address(wrappedToken)), 20e18);

        vm.stopPrank();
    }

    function testUnwrapInsufficientAvailableBalance() public {
        // alice has a balance of the underlying token
        deal(address(underlyingToken), alice, 100e18);

        // she wraps 40 tokens to herself
        vm.startPrank(alice);
        underlyingToken.approve(address(wrappedToken), 100e18);
        wrappedToken.wrap(alice, 40e18);

        // the underlying token has been transferred in from alice
        assertEq(underlyingToken.balanceOf(alice), 60e18);
        assertEq(underlyingToken.balanceOf(address(wrappedToken)), 40e18);

        // alice has a balance of the wrapped token
        assertEq(wrappedToken.balanceOf(alice), 40e18);

        // total supply is increased
        assertEq(wrappedToken.totalSupply(), 40e18);

        // she encumbers her balance and then attempts to unwrap it
        wrappedToken.encumber(bob, 40e18);
        vm.expectRevert("ERC7246: unwrap amount exceeds available balance");
        wrappedToken.unwrap(alice, 40e18);

        vm.stopPrank();
    }
}
