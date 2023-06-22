pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import "../src/vendor/ERC20.sol";
import "../src/vendor/IERC20Metadata.sol";
import "../src/EncumberableToken.sol";

contract EncumberBySigTest is Test {
    ERC20 public underlyingToken;
    EncumberableToken public wrappedToken;

    uint256 alicePrivateKey = 0xa11ce;
    address alice; // see setup()
    address bob = address(11);
    address charlie = address(12);

    bytes32 internal constant ENCUMBER_TYPEHASH = keccak256("Encumber(address owner,address taker,uint256 amount,uint256 nonce,uint256 expiry)");

    function setUp() public {
        underlyingToken = new ERC20("TEST TOKEN", "TTKN");
        wrappedToken = new EncumberableToken(address(underlyingToken));

        alice = vm.addr(alicePrivateKey);
    }

    function aliceAuthorization(uint256 amount, uint256 nonce, uint256 expiry) internal view returns (uint8, bytes32, bytes32) {
        bytes32 structHash = keccak256(abi.encode(ENCUMBER_TYPEHASH, alice, bob, amount, nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", wrappedToken.DOMAIN_SEPARATOR(), structHash));
        return vm.sign(alicePrivateKey, digest);
    }

    function testEncumberBySig() public {
        uint aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice has 100 wrapped tokens
        deal(address(wrappedToken), alice, aliceBalance);

        assertEq(wrappedToken.balanceOf(alice), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(alice), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 0);
        assertEq(wrappedToken.encumbrances(alice, bob), 0);

        uint nonce = wrappedToken.nonces(alice);
        uint expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceAuthorization(encumbranceAmount, nonce, expiry);

        // bob calls encumberBySig with the signature
        vm.prank(bob);
        wrappedToken.encumberBySig(alice, bob, encumbranceAmount, expiry, v, r, s);

        assertEq(wrappedToken.balanceOf(alice), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(alice), aliceBalance - encumbranceAmount);
        assertEq(wrappedToken.encumberedBalanceOf(alice), encumbranceAmount);
        assertEq(wrappedToken.encumbrances(alice, bob), encumbranceAmount);

        // alice's nonce is incremented
        assertEq(wrappedToken.nonces(alice), nonce + 1);
    }

    function testEncumberBySigRevertsForBadOwner() public {
        uint aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice has 100 wrapped tokens
        deal(address(wrappedToken), alice, aliceBalance);

        assertEq(wrappedToken.balanceOf(alice), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(alice), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 0);
        assertEq(wrappedToken.encumbrances(alice, bob), 0);

        uint nonce = wrappedToken.nonces(alice);
        uint expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceAuthorization(encumbranceAmount, nonce, expiry);

        // bob calls encumberBySig with the signature, but he manipulates the owner
        vm.prank(bob);
        vm.expectRevert("Bad signatory");
        wrappedToken.encumberBySig(charlie, bob, encumbranceAmount, expiry, v, r, s);

        // no encumbrance is created
        assertEq(wrappedToken.balanceOf(alice), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(alice), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 0);
        assertEq(wrappedToken.encumbrances(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(wrappedToken.nonces(alice), nonce);
    }

    function testEncumberBySigRevertsForBadSpender() public {
        uint aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice has 100 wrapped tokens
        deal(address(wrappedToken), alice, aliceBalance);

        assertEq(wrappedToken.balanceOf(alice), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(alice), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 0);
        assertEq(wrappedToken.encumbrances(alice, bob), 0);

        uint nonce = wrappedToken.nonces(alice);
        uint expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceAuthorization(encumbranceAmount, nonce, expiry);

        // bob calls encumberBySig with the signature, but he manipulates the spender
        vm.prank(bob);
        vm.expectRevert("Bad signatory");
        wrappedToken.encumberBySig(alice, charlie, encumbranceAmount, expiry, v, r, s);

        // no encumbrance is created
        assertEq(wrappedToken.balanceOf(alice), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(alice), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 0);
        assertEq(wrappedToken.encumbrances(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(wrappedToken.nonces(alice), nonce);
    }

    function testEncumberBySigRevertsForBadAmount() public {
        uint aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice has 100 wrapped tokens
        deal(address(wrappedToken), alice, aliceBalance);

        assertEq(wrappedToken.balanceOf(alice), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(alice), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 0);
        assertEq(wrappedToken.encumbrances(alice, bob), 0);

        uint nonce = wrappedToken.nonces(alice);
        uint expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceAuthorization(encumbranceAmount, nonce, expiry);

        // bob calls encumberBySig with the signature, but he manipulates the encumbranceAmount
        vm.prank(bob);
        vm.expectRevert("Bad signatory");
        wrappedToken.encumberBySig(alice, bob, encumbranceAmount + 1 wei, expiry, v, r, s);

        // no encumbrance is created
        assertEq(wrappedToken.balanceOf(alice), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(alice), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 0);
        assertEq(wrappedToken.encumbrances(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(wrappedToken.nonces(alice), nonce);
    }

    function testEncumberBySigRevertsForBadExpiry() public {
        // bob's allowance from alice is 0
        assertEq(wrappedToken.allowance(alice, bob), 0);

        uint256 allowance = 123e18;
        uint nonce = wrappedToken.nonces(alice);
        uint expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceAuthorization(encumbranceAmount, nonce, expiry);

        // bob calls encumberBySig with the signature, but he manipulates the expiry
        vm.prank(bob);
        vm.expectRevert("Bad signatory");
        wrappedToken.encumberBySig(alice, bob, allowance, expiry + 1, v, r, s);

        // bob's allowance from alice is unchanged
        assertEq(wrappedToken.allowance(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(wrappedToken.nonces(alice), nonce);
    }

    function testEncumberBySigRevertsForBadNonce() public {
        // bob's allowance from alice is 0
        assertEq(wrappedToken.allowance(alice, bob), 0);

        // alice signs an authorization with an invalid nonce
        uint256 allowance = 123e18;
        uint nonce = wrappedToken.nonces(alice);
        uint badNonce = nonce + 1;
        uint expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceAuthorization(encumbranceAmount, badNonce, expiry);

        // bob calls encumberBySig with the signature, but he manipulates the expiry
        vm.prank(bob);
        vm.expectRevert("Bad signatory");
        wrappedToken.encumberBySig(alice, bob, allowance, expiry, v, r, s);

        // bob's allowance from alice is unchanged
        assertEq(wrappedToken.allowance(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(wrappedToken.nonces(alice), nonce);
    }

    function testEncumberBySigRevertsOnRepeatedCall() public {
        // bob's allowance from alice is 0
        assertEq(wrappedToken.allowance(alice, bob), 0);

        uint256 allowance = 123e18;
        uint nonce = wrappedToken.nonces(alice);
        uint expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceAuthorization(encumbranceAmount, nonce, expiry);

        // bob calls encumberBySig with the signature
        vm.prank(bob);
        wrappedToken.encumberBySig(alice, bob, allowance, expiry, v, r, s);

        // bob's allowance from alice equals allowance
        assertEq(wrappedToken.allowance(alice, bob), allowance);

        // alice's nonce is incremented
        assertEq(wrappedToken.nonces(alice), nonce + 1);

        // alice revokes bob's allowance
        vm.prank(alice);
        wrappedToken.approve(bob, 0);
        assertEq(wrappedToken.allowance(alice, bob), 0);

        // bob tries to reuse the same signature twice
        vm.prank(bob);
        vm.expectRevert("Bad signatory");
        wrappedToken.encumberBySig(alice, bob, allowance, expiry, v, r, s);


        // bob's allowance from alice is unchanged
        assertEq(wrappedToken.allowance(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(wrappedToken.nonces(alice), nonce + 1);
    }

    function testEncumberBySigRevertsForExpiredSignature() public {
        // bob's allowance from alice is 0
        assertEq(wrappedToken.allowance(alice, bob), 0);

        uint256 allowance = 123e18;
        uint nonce = wrappedToken.nonces(alice);
        uint expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceAuthorization(encumbranceAmount, nonce, expiry);

        // the expiry block arrives
        vm.warp(expiry);

        // bob calls encumberBySig with the signature, but he manipulates the expiry
        vm.prank(bob);
        vm.expectRevert("Signature expired");
        wrappedToken.encumberBySig(alice, bob, allowance, expiry, v, r, s);

        // bob's allowance from alice is unchanged
        assertEq(wrappedToken.allowance(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(wrappedToken.nonces(alice), nonce);
    }

    function testEncumberBySigRevertsInvalidV() public {
        // bob's allowance from alice is 0
        assertEq(wrappedToken.allowance(alice, bob), 0);

        uint256 allowance = 123e18;
        uint nonce = wrappedToken.nonces(alice);
        uint expiry = block.timestamp + 1000;

        (, bytes32 r, bytes32 s) = aliceAuthorization(encumbranceAmount, nonce, expiry);
        uint8 invalidV = 26;

        // bob calls encumberBySig with the signature, but he manipulates the expiry
        vm.prank(bob);
        vm.expectRevert("Invalid value v");
        wrappedToken.encumberBySig(alice, bob, allowance, expiry, invalidV, r, s);

        // bob's allowance from alice is unchanged
        assertEq(wrappedToken.allowance(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(wrappedToken.nonces(alice), nonce);
    }

    function testEncumberBySigRevertsInvalidS() public {
        // bob's allowance from alice is 0
        assertEq(wrappedToken.allowance(alice, bob), 0);

        uint256 allowance = 123e18;
        uint nonce = wrappedToken.nonces(alice);
        uint expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, ) = aliceAuthorization(encumbranceAmount, nonce, expiry);

        // 1 greater than the max value of s
        bytes32 invalidS = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A1;

        // bob calls encumberBySig with the signature, but he manipulates the expiry
        vm.prank(bob);
        vm.expectRevert("Invalid value s");
        wrappedToken.encumberBySig(alice, bob, allowance, expiry, v, r, invalidS);

        // bob's allowance from alice is unchanged
        assertEq(wrappedToken.allowance(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(wrappedToken.nonces(alice), nonce);
    }
*/

    // XXX encumber for someone else; if you have an allowance, encumber part of that allowance to someone else
}
