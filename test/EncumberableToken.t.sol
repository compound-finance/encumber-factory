pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import "../src/vendor/ERC20.sol";
import "../src/vendor/IERC20Metadata.sol";
import "../src/EncumberableToken.sol";

contract EncumberableTokenTest is Test {
    event Encumber(address indexed owner, address indexed taker, uint amount);
    event Release(address indexed owner, address indexed taker, uint amount);

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
        vm.expectRevert("ERC999: insufficient available balance");
        wrappedToken.transfer(charlie, 100e18);

        vm.stopPrank();
    }

    function testEncumberRevert() public {
        deal(address(wrappedToken), alice, 100e18);
        vm.startPrank(alice);

        // alice encumbers half her balance to bob
        wrappedToken.encumber(bob, 50e18);

        // alice attempts to encumber more than her remaining available balance
        vm.expectRevert("ERC999: insufficient available balance");
        wrappedToken.encumber(charlie, 60e18);

        vm.stopPrank();
    }

    function testEncumber() public {
        deal(address(wrappedToken), alice, 100e18);
        vm.startPrank(alice);

        // emits Encumber event
        vm.expectEmit(true, true, true, true);
        emit Encumber(alice, bob, 60e18);

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
        vm.prank(bob);
        wrappedToken.transferFrom(alice, charlie, 40e18);

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
        vm.expectRevert("ERC999: insufficient allowance");
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
        // emits an Encumber event
        vm.expectEmit(true, true, true, true);
        emit Encumber(alice, charlie, 60e18);
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

        // alice encumbers some of her balance to bob
        wrappedToken.encumber(bob, 100e18);

        assertEq(wrappedToken.balanceOf(alice), 100e18);
        assertEq(wrappedToken.availableBalanceOf(alice), 0);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 100e18);
        assertEq(wrappedToken.encumbrances(alice, bob), 100e18);

        // bob releases part of the encumbrance
        vm.prank(bob);
        // emits Release event
        vm.expectEmit(true, true, true, true);
        emit Release(alice, bob, 40e18);
        wrappedToken.release(alice, 40e18);

        assertEq(wrappedToken.balanceOf(alice), 100e18);
        assertEq(wrappedToken.availableBalanceOf(alice), 40e18);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 60e18);
        assertEq(wrappedToken.encumbrances(alice, bob), 60e18);
    }

    function testMint() public {
        // alice has a balance of the underlying token
        deal(address(underlyingToken), alice, 100e18);

        // she mints 40 wrapped tokens to bob
        vm.startPrank(alice);
        underlyingToken.approve(address(wrappedToken), 100e18);
        wrappedToken.mint(bob, 40e18);
        vm.stopPrank();

        // the underlying token has been transferred in from alice
        assertEq(underlyingToken.balanceOf(alice), 60e18);
        assertEq(underlyingToken.balanceOf(address(wrappedToken)), 40e18);

        // bob has a balance of the wrapped token
        assertEq(wrappedToken.balanceOf(bob), 40e18);

        // total supply is increased
        assertEq(wrappedToken.totalSupply(), 40e18);
    }

    function testMintRevert() public {
        // alice has a balance of the underlying token
        deal(address(underlyingToken), alice, 100e18);

        // she mints more than she has in the underlying token
        vm.startPrank(alice);
        underlyingToken.approve(address(wrappedToken), type(uint256).max);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        wrappedToken.mint(alice, 200e18);
        vm.stopPrank();
    }

    function testBurn() public {
        // alice has a balance of the underlying token
        deal(address(underlyingToken), alice, 100e18);

        // she mints 40 wrapped tokens to herself
        vm.startPrank(alice);
        underlyingToken.approve(address(wrappedToken), 100e18);
        wrappedToken.mint(alice, 40e18);

        // the underlying token has been transferred in from alice
        assertEq(underlyingToken.balanceOf(alice), 60e18);
        assertEq(underlyingToken.balanceOf(address(wrappedToken)), 40e18);

        // alice has a balance of the wrapped token
        assertEq(wrappedToken.balanceOf(alice), 40e18);

        // total supply is increased
        assertEq(wrappedToken.totalSupply(), 40e18);

        // she burns 20 wrapped tokens
        wrappedToken.burn(alice, 20e18);

        // alice's balance of the wrapped token is decreased
        assertEq(wrappedToken.balanceOf(alice), 20e18);

        // total supply is decreased
        assertEq(wrappedToken.totalSupply(), 20e18);

        // the underlying token has been transferred back to alice
        assertEq(underlyingToken.balanceOf(alice), 80e18);
        assertEq(underlyingToken.balanceOf(address(wrappedToken)), 20e18);

        vm.stopPrank();
    }

    function testBurnInsufficientAvailableBalance() public {
        // alice has a balance of the underlying token
        deal(address(underlyingToken), alice, 100e18);

        // she mints 40 wrapped tokens to herself
        vm.startPrank(alice);
        underlyingToken.approve(address(wrappedToken), 100e18);
        wrappedToken.mint(alice, 40e18);

        // the underlying token has been transferred in from alice
        assertEq(underlyingToken.balanceOf(alice), 60e18);
        assertEq(underlyingToken.balanceOf(address(wrappedToken)), 40e18);

        // alice has a balance of the wrapped token
        assertEq(wrappedToken.balanceOf(alice), 40e18);

        // total supply is increased
        assertEq(wrappedToken.totalSupply(), 40e18);

        // she encumbers her balance and then attempts to burn it
        wrappedToken.encumber(bob, 40e18);
        vm.expectRevert("ERC999: burn amount exceeds available balance");
        wrappedToken.burn(alice, 40e18);

        vm.stopPrank();
    }
}
