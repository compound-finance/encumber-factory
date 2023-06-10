pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "./MockRebasingERC20.sol";
import "../src/EncumbranceWrapper.sol";

contract RebaseTest is Test {
    MockRebasingERC20 public rebasingToken;
    EncumbranceWrapper public wrappedToken;

    address alice = address(10);
    address bob = address(11);
    address charlie = address(12);

    function setUp() public {
        rebasingToken = new MockRebasingERC20("Rebasing ERC20", "rERC");
        wrappedToken = new EncumbranceWrapper(address(rebasingToken));
    }

    function testRebase() public {
        // alice and bob have 10 rebasing tokens
        deal(address(rebasingToken), alice, 10e18);
        deal(address(rebasingToken), bob, 10e18);

        assertEq(rebasingToken.balanceOf(alice), 10e18);
        assertEq(rebasingToken.balanceOf(bob), 10e18);
        assertEq(rebasingToken.balanceOf(address(wrappedToken)), 0);
        assertEq(wrappedToken.balanceOf(alice), 0);
        assertEq(wrappedToken.balanceOf(bob), 0);

        // alice mints 10 wrapped tokens
        vm.startPrank(alice);
        rebasingToken.approve(address(wrappedToken), type(uint256).max);
        wrappedToken.mint(alice, 10e18);
        assertEq(rebasingToken.balanceOf(alice), 0);
        assertEq(rebasingToken.balanceOf(bob), 10e18);
        assertEq(rebasingToken.balanceOf(address(wrappedToken)), 10e18);
        assertEq(wrappedToken.balanceOf(alice), 10e18);
        assertEq(wrappedToken.balanceOf(bob), 0);

        // a rebase occurs, increasing the wrapped token's balance
        rebasingToken.mint(address(wrappedToken), 5e18);
        assertEq(rebasingToken.balanceOf(address(wrappedToken)), 15e18);
        // ...increasing alice's balance of the wrapped token
        assertEq(wrappedToken.balanceOf(alice), 15e18);
        assertEq(wrappedToken.balanceOf(bob), 0);

        // alice encumbers her new balance of 15 tokens to charlie
        wrappedToken.encumber(charlie, 15e18);
        assertEq(wrappedToken.balanceOf(alice), 15e18);
        assertEq(wrappedToken.freeBalanceOf(alice), 0);
        assertEq(wrappedToken.encumberedBalance(alice), 15e18);
        assertEq(wrappedToken.encumbrances(alice, charlie), 15e18);

        vm.stopPrank();

        // bob supplies his 10 underlying token
        vm.startPrank(bob);
        rebasingToken.approve(address(wrappedToken), type(uint256).max);
        wrappedToken.mint(bob, 10e18);
        assertEq(rebasingToken.balanceOf(bob), 0);
        // 10 supplied by alice + 5 rebased + 10 supplied by bob
        assertEq(rebasingToken.balanceOf(address(wrappedToken)), 25e18);
        // now alice and bob are splitting the rebased balance of the wrapped token
        assertEq(wrappedToken.balanceOf(alice), 12.5e18); // <!-- alice's balance has dropped
        assertEq(wrappedToken.balanceOf(bob), 12.5e18);

        vm.stopPrank();

        // now, when charlie tries to claim the 15 tokens that are encumbered to him...
        vm.startPrank(charlie);
        // ...call revert with: "ERC20: transfer amount exceeds balance"
        wrappedToken.transferFrom(alice, charlie, 15e18);

        vm.stopPrank();
    }
}