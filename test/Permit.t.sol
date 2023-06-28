pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import "../src/vendor/ERC20.sol";
import "../src/vendor/IERC20Metadata.sol";
import "../src/EncumberableToken.sol";

contract PermitTest is Test {
    ERC20 public underlyingToken;
    EncumberableToken public wrappedToken;

    uint256 alicePrivateKey = 0xa11ce;
    address alice; // see setup()
    address bob = address(11);
    address charlie = address(12);

    bytes32 internal constant AUTHORIZATION_TYPEHASH = keccak256("Authorization(address owner,address spender,uint256 amount,uint256 nonce,uint256 expiry)");

    function setUp() public {
        underlyingToken = new ERC20("TEST TOKEN", "TTKN");
        wrappedToken = new EncumberableToken(address(underlyingToken));

        alice = vm.addr(alicePrivateKey);
    }

    function aliceAuthorization(uint256 amount, uint256 nonce, uint256 expiry) internal view returns (uint8, bytes32, bytes32) {
        bytes32 structHash = keccak256(abi.encode(AUTHORIZATION_TYPEHASH, alice, bob, amount, nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", wrappedToken.DOMAIN_SEPARATOR(), structHash));
        return vm.sign(alicePrivateKey, digest);
    }

    function testPermit() public {
        // bob's allowance from alice is 0
        assertEq(wrappedToken.allowance(alice, bob), 0);

        uint256 allowance = 123e18;
        uint256 nonce = wrappedToken.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceAuthorization(allowance, nonce, expiry);

        // bob calls permit with the signature
        vm.prank(bob);
        wrappedToken.permit(alice, bob, allowance, expiry, v, r, s);

        // bob's allowance from alice equals allowance
        assertEq(wrappedToken.allowance(alice, bob), allowance);

        // alice's nonce is incremented
        assertEq(wrappedToken.nonces(alice), nonce + 1);
    }

    function testPermitRevertsForBadOwner() public {
        // bob's allowance from alice is 0
        assertEq(wrappedToken.allowance(alice, bob), 0);

        uint256 allowance = 123e18;
        uint256 nonce = wrappedToken.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceAuthorization(allowance, nonce, expiry);

        // bob calls permit with the signature, but he manipulates the owner
        vm.prank(bob);
        vm.expectRevert("Bad signatory");
        wrappedToken.permit(charlie, bob, allowance, expiry, v, r, s);

        // bob's allowance from alice is unchanged
        assertEq(wrappedToken.allowance(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(wrappedToken.nonces(alice), nonce);
    }

    function testPermitRevertsForBadSpender() public {
        // bob's allowance from alice is 0
        assertEq(wrappedToken.allowance(alice, bob), 0);

        uint256 allowance = 123e18;
        uint256 nonce = wrappedToken.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceAuthorization(allowance, nonce, expiry);

        // bob calls permit with the signature, but he manipulates the spender
        vm.prank(bob);
        vm.expectRevert("Bad signatory");
        wrappedToken.permit(alice, charlie, allowance, expiry, v, r, s);

        // bob's allowance from alice is unchanged
        assertEq(wrappedToken.allowance(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(wrappedToken.nonces(alice), nonce);
    }

    function testPermitRevertsForBadAmount() public {
        // bob's allowance from alice is 0
        assertEq(wrappedToken.allowance(alice, bob), 0);

        uint256 allowance = 123e18;
        uint256 nonce = wrappedToken.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceAuthorization(allowance, nonce, expiry);

        // bob calls permit with the signature, but he manipulates the allowance
        vm.prank(bob);
        vm.expectRevert("Bad signatory");
        wrappedToken.permit(alice, bob, allowance + 1 wei, expiry, v, r, s);

        // bob's allowance from alice is unchanged
        assertEq(wrappedToken.allowance(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(wrappedToken.nonces(alice), nonce);
    }

    function testPermitRevertsForBadExpiry() public {
        // bob's allowance from alice is 0
        assertEq(wrappedToken.allowance(alice, bob), 0);

        uint256 allowance = 123e18;
        uint256 nonce = wrappedToken.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceAuthorization(allowance, nonce, expiry);

        // bob calls permit with the signature, but he manipulates the expiry
        vm.prank(bob);
        vm.expectRevert("Bad signatory");
        wrappedToken.permit(alice, bob, allowance, expiry + 1, v, r, s);

        // bob's allowance from alice is unchanged
        assertEq(wrappedToken.allowance(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(wrappedToken.nonces(alice), nonce);
    }

    function testPermitRevertsForBadNonce() public {
        // bob's allowance from alice is 0
        assertEq(wrappedToken.allowance(alice, bob), 0);

        // alice signs an authorization with an invalid nonce
        uint256 allowance = 123e18;
        uint256 nonce = wrappedToken.nonces(alice);
        uint256 badNonce = nonce + 1;
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceAuthorization(allowance, badNonce, expiry);

        // bob calls permit with the signature with an invalid nonce
        vm.prank(bob);
        vm.expectRevert("Bad signatory");
        wrappedToken.permit(alice, bob, allowance, expiry, v, r, s);

        // bob's allowance from alice is unchanged
        assertEq(wrappedToken.allowance(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(wrappedToken.nonces(alice), nonce);
    }

    function testPermitRevertsOnRepeatedCall() public {
        // bob's allowance from alice is 0
        assertEq(wrappedToken.allowance(alice, bob), 0);

        uint256 allowance = 123e18;
        uint256 nonce = wrappedToken.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceAuthorization(allowance, nonce, expiry);

        // bob calls permit with the signature
        vm.prank(bob);
        wrappedToken.permit(alice, bob, allowance, expiry, v, r, s);

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
        wrappedToken.permit(alice, bob, allowance, expiry, v, r, s);

        // bob's allowance from alice is unchanged
        assertEq(wrappedToken.allowance(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(wrappedToken.nonces(alice), nonce + 1);
    }

    function testPermitRevertsForExpiredSignature() public {
        // bob's allowance from alice is 0
        assertEq(wrappedToken.allowance(alice, bob), 0);

        uint256 allowance = 123e18;
        uint256 nonce = wrappedToken.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceAuthorization(allowance, nonce, expiry);

        // the expiry block arrives
        vm.warp(expiry);

        // bob calls permit with the signature after the expiry
        vm.prank(bob);
        vm.expectRevert("Signature expired");
        wrappedToken.permit(alice, bob, allowance, expiry, v, r, s);

        // bob's allowance from alice is unchanged
        assertEq(wrappedToken.allowance(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(wrappedToken.nonces(alice), nonce);
    }

    function testPermitRevertsInvalidV() public {
        // bob's allowance from alice is 0
        assertEq(wrappedToken.allowance(alice, bob), 0);

        uint256 allowance = 123e18;
        uint256 nonce = wrappedToken.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

        (, bytes32 r, bytes32 s) = aliceAuthorization(allowance, nonce, expiry);
        uint8 invalidV = 26;

        // bob calls permit with the signature with invalid `v` value
        vm.prank(bob);
        vm.expectRevert("Invalid value v");
        wrappedToken.permit(alice, bob, allowance, expiry, invalidV, r, s);

        // bob's allowance from alice is unchanged
        assertEq(wrappedToken.allowance(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(wrappedToken.nonces(alice), nonce);
    }

    function testPermitRevertsInvalidS() public {
        // bob's allowance from alice is 0
        assertEq(wrappedToken.allowance(alice, bob), 0);

        uint256 allowance = 123e18;
        uint256 nonce = wrappedToken.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, ) = aliceAuthorization(allowance, nonce, expiry);

        // 1 greater than the max value of s
        bytes32 invalidS = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A1;

        // bob calls permit with the signature with invalid `s` value
        vm.prank(bob);
        vm.expectRevert("Invalid value s");
        wrappedToken.permit(alice, bob, allowance, expiry, v, r, invalidS);

        // bob's allowance from alice is unchanged
        assertEq(wrappedToken.allowance(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(wrappedToken.nonces(alice), nonce);
    }
}