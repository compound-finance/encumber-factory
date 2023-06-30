pragma solidity ^0.8.15;

import "forge-std/StdUtils.sol";
import { Test } from "forge-std/Test.sol";
import { ERC20 } from "../src/vendor/ERC20.sol";
import { IERC20Metadata } from "../src/vendor/IERC20Metadata.sol";
import { EncumberableToken } from "../src/EncumberableToken.sol";
import { EIP1271Signer } from "../src/test/EIP1271Signer.sol";

contract EncumberBySigTest is Test {
    ERC20 public underlyingToken;
    EncumberableToken public wrappedToken;

    uint256 alicePrivateKey = 0xa11ce;
    address alice; // see setup()
    address aliceContract; // contract that can verify EIP1271 signatures
    address bob = address(11);
    address charlie = address(12);

    bytes32 internal constant ENCUMBER_TYPEHASH = keccak256("Encumber(address owner,address taker,uint256 amount,uint256 nonce,uint256 expiry)");

    function setUp() public {
        alice = vm.addr(alicePrivateKey);

        underlyingToken = new ERC20("TEST TOKEN", "TTKN");
        wrappedToken = new EncumberableToken(address(underlyingToken));
        aliceContract = address(new EIP1271Signer(alice));
    }

    function aliceAuthorization(uint256 amount, uint256 nonce, uint256 expiry) internal view returns (uint8, bytes32, bytes32) {
        bytes32 structHash = keccak256(abi.encode(ENCUMBER_TYPEHASH, alice, bob, amount, nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", wrappedToken.DOMAIN_SEPARATOR(), structHash));
        return vm.sign(alicePrivateKey, digest);
    }

    function aliceContractAuthorization(uint256 amount, uint256 nonce, uint256 expiry) internal view returns (uint8, bytes32, bytes32) {
        bytes32 structHash = keccak256(abi.encode(ENCUMBER_TYPEHASH, aliceContract, bob, amount, nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", wrappedToken.DOMAIN_SEPARATOR(), structHash));
        return vm.sign(alicePrivateKey, digest);
    }

    function testEncumberBySig() public {
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice has 100 wrapped tokens
        deal(address(wrappedToken), alice, aliceBalance);

        assertEq(wrappedToken.balanceOf(alice), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(alice), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 0);
        assertEq(wrappedToken.encumbrances(alice, bob), 0);

        uint256 nonce = wrappedToken.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

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
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice has 100 wrapped tokens
        deal(address(wrappedToken), alice, aliceBalance);

        assertEq(wrappedToken.balanceOf(alice), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(alice), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 0);
        assertEq(wrappedToken.encumbrances(alice, bob), 0);

        uint256 nonce = wrappedToken.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

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
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice has 100 wrapped tokens
        deal(address(wrappedToken), alice, aliceBalance);

        assertEq(wrappedToken.balanceOf(alice), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(alice), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 0);
        assertEq(wrappedToken.encumbrances(alice, bob), 0);

        uint256 nonce = wrappedToken.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

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
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice has 100 wrapped tokens
        deal(address(wrappedToken), alice, aliceBalance);

        assertEq(wrappedToken.balanceOf(alice), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(alice), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 0);
        assertEq(wrappedToken.encumbrances(alice, bob), 0);

        uint256 nonce = wrappedToken.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

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
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice has 100 wrapped tokens
        deal(address(wrappedToken), alice, aliceBalance);

        assertEq(wrappedToken.balanceOf(alice), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(alice), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 0);
        assertEq(wrappedToken.encumbrances(alice, bob), 0);

        uint256 nonce = wrappedToken.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceAuthorization(encumbranceAmount, nonce, expiry);

        // bob calls encumberBySig with the signature, but he manipulates the expiry
        vm.prank(bob);
        vm.expectRevert("Bad signatory");
        wrappedToken.encumberBySig(alice, bob, encumbranceAmount, expiry + 1, v, r, s);

        // no encumbrance is created
        assertEq(wrappedToken.balanceOf(alice), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(alice), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 0);
        assertEq(wrappedToken.encumbrances(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(wrappedToken.nonces(alice), nonce);
    }

    function testEncumberBySigRevertsForBadNonce() public {
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice has 100 wrapped tokens
        deal(address(wrappedToken), alice, aliceBalance);

        assertEq(wrappedToken.balanceOf(alice), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(alice), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 0);
        assertEq(wrappedToken.encumbrances(alice, bob), 0);

        // alice signs an authorization with an invalid nonce
        uint256 nonce = wrappedToken.nonces(alice);
        uint256 badNonce = nonce + 1;
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceAuthorization(encumbranceAmount, badNonce, expiry);

        // bob calls encumberBySig with the signature with an invalid nonce
        vm.prank(bob);
        vm.expectRevert("Bad signatory");
        wrappedToken.encumberBySig(alice, bob, encumbranceAmount, expiry, v, r, s);

        // no encumbrance is created
        assertEq(wrappedToken.balanceOf(alice), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(alice), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 0);
        assertEq(wrappedToken.encumbrances(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(wrappedToken.nonces(alice), nonce);
    }

    function testEncumberBySigRevertsOnRepeatedCall() public {
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;
        uint256 transferAmount = 30e18;

        // alice has 100 wrapped tokens
        deal(address(wrappedToken), alice, aliceBalance);

        assertEq(wrappedToken.balanceOf(alice), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(alice), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 0);
        assertEq(wrappedToken.encumbrances(alice, bob), 0);

        uint256 nonce = wrappedToken.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceAuthorization(encumbranceAmount, nonce, expiry);

        // bob calls encumberBySig with the signature
        vm.startPrank(bob);
        wrappedToken.encumberBySig(alice, bob, encumbranceAmount, expiry, v, r, s);

        // the encumbrance is created
        assertEq(wrappedToken.balanceOf(alice), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(alice), aliceBalance - encumbranceAmount);
        assertEq(wrappedToken.encumberedBalanceOf(alice), encumbranceAmount);
        assertEq(wrappedToken.encumbrances(alice, bob), encumbranceAmount);

        // alice's nonce is incremented
        assertEq(wrappedToken.nonces(alice), nonce + 1);

        // bob uses some of the encumbrance to transfer to himself
        wrappedToken.transferFrom(alice, bob, transferAmount);

        assertEq(wrappedToken.balanceOf(alice), aliceBalance - transferAmount);
        assertEq(wrappedToken.availableBalanceOf(alice), aliceBalance - encumbranceAmount);
        assertEq(wrappedToken.encumberedBalanceOf(alice), encumbranceAmount - transferAmount);
        assertEq(wrappedToken.encumbrances(alice, bob), encumbranceAmount - transferAmount);

        // bob tries to reuse the same signature twice
        vm.expectRevert("Bad signatory");
        wrappedToken.encumberBySig(alice, bob, encumbranceAmount, expiry, v, r, s);

        // no new encumbrance is created
        assertEq(wrappedToken.balanceOf(alice), aliceBalance - transferAmount);
        assertEq(wrappedToken.availableBalanceOf(alice), aliceBalance - encumbranceAmount);
        assertEq(wrappedToken.encumberedBalanceOf(alice), encumbranceAmount - transferAmount);
        assertEq(wrappedToken.encumbrances(alice, bob), encumbranceAmount - transferAmount);

        // alice's nonce is not incremented a second time
        assertEq(wrappedToken.nonces(alice), nonce + 1);

        vm.stopPrank();
    }

    function testEncumberBySigRevertsForExpiredSignature() public {
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice has 100 wrapped tokens
        deal(address(wrappedToken), alice, aliceBalance);

        assertEq(wrappedToken.balanceOf(alice), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(alice), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 0);
        assertEq(wrappedToken.encumbrances(alice, bob), 0);

        uint256 nonce = wrappedToken.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceAuthorization(encumbranceAmount, nonce, expiry);

        // the expiry block arrives
        vm.warp(expiry);

        // bob calls encumberBySig with the signature after the expiry
        vm.prank(bob);
        vm.expectRevert("Signature expired");
        wrappedToken.encumberBySig(alice, bob, encumbranceAmount, expiry, v, r, s);

        // no encumbrance is created
        assertEq(wrappedToken.balanceOf(alice), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(alice), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 0);
        assertEq(wrappedToken.encumbrances(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(wrappedToken.nonces(alice), nonce);
    }

    function testEncumberBySigRevertsInvalidV() public {
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice has 100 wrapped tokens
        deal(address(wrappedToken), alice, aliceBalance);

        assertEq(wrappedToken.balanceOf(alice), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(alice), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 0);
        assertEq(wrappedToken.encumbrances(alice, bob), 0);

        uint256 nonce = wrappedToken.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

        (, bytes32 r, bytes32 s) = aliceAuthorization(encumbranceAmount, nonce, expiry);
        uint8 invalidV = 26;

        // bob calls encumberBySig with the signature with an invalid `v` value
        vm.prank(bob);
        vm.expectRevert("Invalid value v");
        wrappedToken.encumberBySig(alice, bob, encumbranceAmount, expiry, invalidV, r, s);

        // no encumbrance is created
        assertEq(wrappedToken.balanceOf(alice), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(alice), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 0);
        assertEq(wrappedToken.encumbrances(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(wrappedToken.nonces(alice), nonce);
    }

    function testEncumberBySigRevertsInvalidS() public {
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice has 100 wrapped tokens
        deal(address(wrappedToken), alice, aliceBalance);

        assertEq(wrappedToken.balanceOf(alice), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(alice), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 0);
        assertEq(wrappedToken.encumbrances(alice, bob), 0);

        uint256 nonce = wrappedToken.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, ) = aliceAuthorization(encumbranceAmount, nonce, expiry);

        // 1 greater than the max value of s
        bytes32 invalidS = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A1;

        // bob calls encumberBySig with the signature, but he manipulates the expiry
        vm.prank(bob);
        vm.expectRevert("Invalid value s");
        wrappedToken.encumberBySig(alice, bob, encumbranceAmount, expiry, v, r, invalidS);

        // no encumbrance is created
        assertEq(wrappedToken.balanceOf(alice), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(alice), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(alice), 0);
        assertEq(wrappedToken.encumbrances(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(wrappedToken.nonces(alice), nonce);
    }

    /* ===== EIP1271 Tests ===== */

    function testEncumberBySigEIP1271() public {
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice's contract has 100 wrapped tokens
        deal(address(wrappedToken), aliceContract, aliceBalance);

        assertEq(wrappedToken.balanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(aliceContract), 0);
        assertEq(wrappedToken.encumbrances(aliceContract, bob), 0);

        uint256 nonce = wrappedToken.nonces(aliceContract);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceContractAuthorization(encumbranceAmount, nonce, expiry);

        // bob calls encumberBySig with the signature
        vm.prank(bob);
        wrappedToken.encumberBySig(aliceContract, bob, encumbranceAmount, expiry, v, r, s);

        assertEq(wrappedToken.balanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(aliceContract), aliceBalance - encumbranceAmount);
        assertEq(wrappedToken.encumberedBalanceOf(aliceContract), encumbranceAmount);
        assertEq(wrappedToken.encumbrances(aliceContract, bob), encumbranceAmount);

        // alice's contract's nonce is incremented
        assertEq(wrappedToken.nonces(aliceContract), nonce + 1);
    }

    function testEncumberBySigRevertsForBadSpenderEIP1271() public {
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice's contract has 100 wrapped tokens
        deal(address(wrappedToken), aliceContract, aliceBalance);

        assertEq(wrappedToken.balanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(aliceContract), 0);
        assertEq(wrappedToken.encumbrances(aliceContract, bob), 0);

        uint256 nonce = wrappedToken.nonces(aliceContract);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceContractAuthorization(encumbranceAmount, nonce, expiry);

        // bob calls encumberBySig with the signature, but he manipulates the spender
        vm.prank(bob);
        vm.expectRevert("Bad signatory");
        wrappedToken.encumberBySig(aliceContract, charlie, encumbranceAmount, expiry, v, r, s);

        // no encumbrance is created
        assertEq(wrappedToken.balanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(aliceContract), 0);
        assertEq(wrappedToken.encumbrances(aliceContract, bob), 0);

        // alice's contract's nonce is not incremented
        assertEq(wrappedToken.nonces(aliceContract), nonce);
    }

    function testEncumberBySigRevertsForBadAmountEIP1271() public {
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice's contract has 100 wrapped tokens
        deal(address(wrappedToken), aliceContract, aliceBalance);

        assertEq(wrappedToken.balanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(aliceContract), 0);
        assertEq(wrappedToken.encumbrances(aliceContract, bob), 0);

        uint256 nonce = wrappedToken.nonces(aliceContract);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceContractAuthorization(encumbranceAmount, nonce, expiry);

        // bob calls encumberBySig with the signature, but he manipulates the encumbranceAmount
        vm.prank(bob);
        vm.expectRevert("Bad signatory");
        wrappedToken.encumberBySig(aliceContract, bob, encumbranceAmount + 1 wei, expiry, v, r, s);

        // no encumbrance is created
        assertEq(wrappedToken.balanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(aliceContract), 0);
        assertEq(wrappedToken.encumbrances(aliceContract, bob), 0);

        // alice's contract's nonce is not incremented
        assertEq(wrappedToken.nonces(aliceContract), nonce);
    }

    function testEncumberBySigRevertsForBadExpiryEIP1271() public {
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice's contract has 100 wrapped tokens
        deal(address(wrappedToken), aliceContract, aliceBalance);

        assertEq(wrappedToken.balanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(aliceContract), 0);
        assertEq(wrappedToken.encumbrances(aliceContract, bob), 0);

        uint256 nonce = wrappedToken.nonces(aliceContract);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceContractAuthorization(encumbranceAmount, nonce, expiry);

        // bob calls encumberBySig with the signature, but he manipulates the expiry
        vm.prank(bob);
        vm.expectRevert("Bad signatory");
        wrappedToken.encumberBySig(aliceContract, bob, encumbranceAmount, expiry + 1, v, r, s);

        // no encumbrance is created
        assertEq(wrappedToken.balanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(aliceContract), 0);
        assertEq(wrappedToken.encumbrances(aliceContract, bob), 0);

        // alice's contract's nonce is not incremented
        assertEq(wrappedToken.nonces(aliceContract), nonce);
    }

    function testEncumberBySigRevertsForBadNonceEIP1271() public {
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice's contract has 100 wrapped tokens
        deal(address(wrappedToken), aliceContract, aliceBalance);

        assertEq(wrappedToken.balanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(aliceContract), 0);
        assertEq(wrappedToken.encumbrances(aliceContract, bob), 0);

        // alice signs an authorization with an invalid nonce
        uint256 nonce = wrappedToken.nonces(aliceContract);
        uint256 badNonce = nonce + 1;
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceContractAuthorization(encumbranceAmount, badNonce, expiry);

        // bob calls encumberBySig with the signature with an invalid nonce
        vm.prank(bob);
        vm.expectRevert("Bad signatory");
        wrappedToken.encumberBySig(aliceContract, bob, encumbranceAmount, expiry, v, r, s);

        // no encumbrance is created
        assertEq(wrappedToken.balanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(aliceContract), 0);
        assertEq(wrappedToken.encumbrances(aliceContract, bob), 0);

        // alice's contract's nonce is not incremented
        assertEq(wrappedToken.nonces(aliceContract), nonce);
    }

    function testEncumberBySigRevertsOnRepeatedCallEIP1271() public {
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;
        uint256 transferAmount = 30e18;

        // alice's contract has 100 wrapped tokens
        deal(address(wrappedToken), aliceContract, aliceBalance);

        assertEq(wrappedToken.balanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(aliceContract), 0);
        assertEq(wrappedToken.encumbrances(aliceContract, bob), 0);

        uint256 nonce = wrappedToken.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceContractAuthorization(encumbranceAmount, nonce, expiry);

        // bob calls encumberBySig with the signature
        vm.startPrank(bob);
        wrappedToken.encumberBySig(aliceContract, bob, encumbranceAmount, expiry, v, r, s);

        // the encumbrance is created
        assertEq(wrappedToken.balanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(aliceContract), aliceBalance - encumbranceAmount);
        assertEq(wrappedToken.encumberedBalanceOf(aliceContract), encumbranceAmount);
        assertEq(wrappedToken.encumbrances(aliceContract, bob), encumbranceAmount);

        // alice's contract's nonce is incremented
        assertEq(wrappedToken.nonces(aliceContract), nonce + 1);

        // bob uses some of the encumbrance to transfer to himself
        wrappedToken.transferFrom(aliceContract, bob, transferAmount);

        assertEq(wrappedToken.balanceOf(aliceContract), aliceBalance - transferAmount);
        assertEq(wrappedToken.availableBalanceOf(aliceContract), aliceBalance - encumbranceAmount);
        assertEq(wrappedToken.encumberedBalanceOf(aliceContract), encumbranceAmount - transferAmount);
        assertEq(wrappedToken.encumbrances(aliceContract, bob), encumbranceAmount - transferAmount);

        // bob tries to reuse the same signature twice
        vm.expectRevert("Bad signatory");
        wrappedToken.encumberBySig(aliceContract, bob, encumbranceAmount, expiry, v, r, s);

        // no new encumbrance is created
        assertEq(wrappedToken.balanceOf(aliceContract), aliceBalance - transferAmount);
        assertEq(wrappedToken.availableBalanceOf(aliceContract), aliceBalance - encumbranceAmount);
        assertEq(wrappedToken.encumberedBalanceOf(aliceContract), encumbranceAmount - transferAmount);
        assertEq(wrappedToken.encumbrances(aliceContract, bob), encumbranceAmount - transferAmount);

        // alice's contract's nonce is not incremented a second time
        assertEq(wrappedToken.nonces(aliceContract), nonce + 1);

        vm.stopPrank();
    }

    function testEncumberBySigRevertsForExpiredSignatureEIP1271() public {
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice's contract has 100 wrapped tokens
        deal(address(wrappedToken), aliceContract, aliceBalance);

        assertEq(wrappedToken.balanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(aliceContract), 0);
        assertEq(wrappedToken.encumbrances(aliceContract, bob), 0);

        uint256 nonce = wrappedToken.nonces(aliceContract);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceContractAuthorization(encumbranceAmount, nonce, expiry);

        // the expiry block arrives
        vm.warp(expiry);

        // bob calls encumberBySig with the signature after the expiry
        vm.prank(bob);
        vm.expectRevert("Signature expired");
        wrappedToken.encumberBySig(aliceContract, bob, encumbranceAmount, expiry, v, r, s);

        // no encumbrance is created
        assertEq(wrappedToken.balanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(aliceContract), 0);
        assertEq(wrappedToken.encumbrances(aliceContract, bob), 0);

        // alice's contract's nonce is not incremented
        assertEq(wrappedToken.nonces(aliceContract), nonce);
    }

    function testEncumberBySigRevertsInvalidVEIP1271() public {
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice's contract has 100 wrapped tokens
        deal(address(wrappedToken), aliceContract, aliceBalance);

        assertEq(wrappedToken.balanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(aliceContract), 0);
        assertEq(wrappedToken.encumbrances(aliceContract, bob), 0);

        uint256 nonce = wrappedToken.nonces(aliceContract);
        uint256 expiry = block.timestamp + 1000;

        (, bytes32 r, bytes32 s) = aliceContractAuthorization(encumbranceAmount, nonce, expiry);
        uint8 invalidV = 26;

        // bob calls encumberBySig with the signature with an invalid `v` value
        vm.prank(bob);
        vm.expectRevert("Call to verify EIP1271 signature failed");
        wrappedToken.encumberBySig(aliceContract, bob, encumbranceAmount, expiry, invalidV, r, s);

        // no encumbrance is created
        assertEq(wrappedToken.balanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(aliceContract), 0);
        assertEq(wrappedToken.encumbrances(aliceContract, bob), 0);

        // alice's contract's nonce is not incremented
        assertEq(wrappedToken.nonces(aliceContract), nonce);
    }

    function testEncumberBySigRevertsInvalidSEIP1271() public {
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice's contract has 100 wrapped tokens
        deal(address(wrappedToken), aliceContract, aliceBalance);

        assertEq(wrappedToken.balanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(aliceContract), 0);
        assertEq(wrappedToken.encumbrances(aliceContract, bob), 0);

        uint256 nonce = wrappedToken.nonces(aliceContract);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, ) = aliceContractAuthorization(encumbranceAmount, nonce, expiry);

        // 1 greater than the max value of s
        bytes32 invalidS = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A1;

        // bob calls encumberBySig with the signature, but he manipulates the expiry
        vm.prank(bob);
        vm.expectRevert("Call to verify EIP1271 signature failed");
        wrappedToken.encumberBySig(aliceContract, bob, encumbranceAmount, expiry, v, r, invalidS);

        // no encumbrance is created
        assertEq(wrappedToken.balanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.availableBalanceOf(aliceContract), aliceBalance);
        assertEq(wrappedToken.encumberedBalanceOf(aliceContract), 0);
        assertEq(wrappedToken.encumbrances(aliceContract, bob), 0);

        // alice's contract's nonce is not incremented
        assertEq(wrappedToken.nonces(aliceContract), nonce);
    }
}
