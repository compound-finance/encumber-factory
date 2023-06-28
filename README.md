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