# EncumberableToken Factory

```
                        ////////////////////////
                        /////// Warning! ///////
                        ////////////////////////

This code is unaudited and in active development. Do not use in production.
```

Compound Labs recently released the spec for [ERC999](), an addition to the
ERC20 standard that allows token holders to "encumber" a portion of their token
balance to another address. Encumbering tokens lets the token holder guarantee
that a portion of their tokens are not transferable, allowing them to use their
tokens as collateral without having to transfer custody.

In order to take advantage of this new capability, tokens can implement the
ERC999 interface. However, many tokens will never implement this interface,
either because their contracts are immutable or because the development team is
unaware of ERC999 or uninterested in incorporating it into their contract.

This repo defines an EncumberableTokenFactory. The EncumberableTokenFactory
takes in the address of an ERC20 token and creates a wrapper token that
adds the ERC999 interface.

This wrapped token is exchangeable one-to-one for the underlying token. The
wrapped token can then be used in any situation that requires an encumberable
token, and can later be burned in order to redeem it for the underyling token.

It is comparable to the way that Wrapped Ether (WETH) acts as a wrapper around
ETH, providing users with the ability to make use of ETH in any context that
requires an ERC20-compatible token.

## Limitations

The major limitation of the EncumberableTokenFactory is that it does not support
rebasing tokens.

If you wrap a rebasing token and then mint the wrapped token, your rebasing
interest will accumulate to the wrapper token.

# Deployed addresses

XXX coming soon

# Deploying new wrapped tokens

XXX coming soon

# Using the wrapped token

The EncumberableToken contract inherits all the functionality of the [IERC999
interface](./src/interfaces/IERC999.sol), along with the [IERC999Extended
interface](./src/interfaces/IERC999Extended.sol).

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