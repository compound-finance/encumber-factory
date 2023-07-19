# EncumberableToken Factory

```
                        ////////////////////////
                        /////// Warning! ///////
                        ////////////////////////

This code is unaudited and in active development. Do not use in production.
```

Compound Labs recently released the spec for
[ERC7246](https://github.com/ethereum/EIPs/pull/7246), an addition to the ERC20
standard that allows token holders to "encumber" a portion of their token
balance to another address. Encumbering tokens lets the token holder guarantee
that a portion of their tokens are not transferable, allowing them to use their
tokens as collateral without having to transfer custody.

In order to take advantage of this new capability, tokens can implement the
ERC7246 interface. However, many tokens will never implement this interface,
either because their contracts are immutable or because the development team is
unaware of ERC7246 or uninterested in incorporating it into their contract.

This repo defines an EncumberableTokenFactory. The EncumberableTokenFactory
takes in the address of an ERC20 token and creates a wrapper token that
adds the ERC7246 interface.

This wrapped token is exchangeable one-to-one for the underlying token. The
wrapped token can then be used in any situation that requires an encumberable
token, and can later be burned in order to redeem it for the underyling token.

It is comparable to the way that Wrapped Ether (WETH) acts as a wrapper around
ETH, providing users with the ability to make use of ETH in any context that
requires an ERC20-compatible token.

The wrapper token comes with [EIP-2612](https://eips.ethereum.org/EIPS/eip-2612)
and [EIP-1271](https://eips.ethereum.org/EIPS/eip-1271) support to allow both EOAs
and smart contracts to approve and encumber gaslessly using off-chain signatures.

## Limitations

### Rebasing tokens

One major limitation of the EncumberableTokenFactory is that it does not support
rebasing tokens.

If you wrap a rebasing token and then mint the wrapped token, your rebasing
interest will accumulate to the wrapper token.

### Fee tokens

Additionally, the EncumberableTokenFactory does not support fee tokens.

The `doTransferIn` and `doTransferOut` functions assume that a succesful call of
`ERC2(token).transferFrom(src, dst, amount)` will result in `amount` tokens
being transferred to `dst`. Those functions do not verify the amount that has
been transferred.

If a token breaks this assumption (by having a fee on transfer, for example),
then it is possible that a user would be able to drain the wrapper contract's
balance of the underlying token by minting a greater amount of the wrapper token
than they have actually transferred in, and then burning that greater amount for
more of the underlying token than they transferred in.

### ERC20 approve double-spend

The EncumberableToken contract is built on top of the standard ERC20 token, and
therefore it inherits a [well-known flaw in the ERC20
allowance](https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729)
mechanism that can potentially allow someone to double-spend an allowance in `transferFrom` and `encumberFrom`.

The flaw works [like this](https://docs.google.com/document/d/1YLPtQxZu1UAvO9cZ1O2RPXBbT0mooh4DYKjA_jp-RLM/edit):

- Alice grants an approval to Bob for X tokens by calling `token.approve(Bob, X)`
- Alice decides to reduce Bob's allowance to a smaller number Y, and submits a
transaction calling `token.approve(Bob, Y)`
- Bob sees Alice's pending transaction before it is mined and quickly sends a
transaction to transfer X tokens to himself, spending his existing allowance
- Alice's transaction is mined, granting Bob the new allowance of Y
- Bob sends a second transaction, transferring Y tokens to himself

To mitigate this issue, users that wish to reduce an allowance can first set
that allowance to 0, and then set the allowance to the desired new allowance.

Alternatively, they can use the non-standard `increaseAllowance` and
`decreaseAllowance` functions that are part of OpenZeppelin's ERC20
implementation and are included in the EncumberableToken.

## Considerations when integrating with encumberable tokens

Tokens that implement the Encumbrance spec are ERC20 compatible, but they behave
in slightly different ways than other ERC20s. These differences may be important
to consider when writing a protocol or application that interacts with
encumberable tokens.

For example, an owner address might have a balance of an encumberable token and
might grant an allowance to a spender address. But if that spender address
attempts to transfer some of the owner's balance while the owner has an
encumbrance on it, the transfer will fail.

In this scenario, it is important to read the `availableBalanceOf` for the owner
address; reading the owner's balance and the spender's allowance does not give
a complete idea of how many tokens can be transferred.

# Deployed addresses

XXX coming soon

# Deploying new wrapped tokens

XXX coming soon

# Using the wrapped token

The EncumberableToken contract inherits all the functionality of the [IERC7246
interface](./src/interfaces/IERC7246.sol).

Additionally, each token includes `mint` and `burn` functions.

```
/**
 * @notice Creates `amount` tokens and assigns them to `recipient` in exchange
 * for an equal amount of the underlying token
 */
function mint(address recipient, uint amount) external returns (bool);


/**
 * @notice Destroys `amount` tokens and transfers the same amount of the
 * underlying token to `recipient`
 */
function burn(address recipient, uint amount) public returns (bool);
```

# Developing

## Building

``` forge build ```

## Testing

``` forge test ```

## Deploying

XXX coming soon