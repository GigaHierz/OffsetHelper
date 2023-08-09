# Solidity API

## OffsetHelper

Helper functions that simplify the carbon offsetting (retirement)
process.

Retiring carbon tokens requires multiple steps and interactions with
Toucan Protocol's main contracts:
1. Obtain a Toucan pool token e.g., NCT or BCT (by performing a token
   swap on a DEX).
2. Redeem the pool token for a TCO2 token.
3. Retire the TCO2 token.

These steps are combined in each of the following "auto offset" methods
implemented in `OffsetHelper` to allow a retirement within one transaction:
- `autoOffsetPoolToken()` if the user already owns a Toucan pool
  token e.g., NCT or BCT,
- `autoOffsetExactOutETH()` if the user would like to perform a retirement
  using native tokens e.g., MATIC, specifying the exact amount of TCO2s to retire,
- `autoOffsetExactInETH()` if the user would like to perform a retirement
  using native tokens, swapping all sent native tokens into TCO2s,
- `autoOffsetExactOutToken()` if the user would like to perform a retirement
  using an ERC20 token (cUSD, USDC, WETH or WMATIC), specifying the exact amount
  of TCO2s to retire,
- `autoOffsetExactInToken()` if the user would like to perform a retirement
  using an ERC20 token (cUSD, USDC, WETH or WMATIC), specifying the exact amount
  of token to swap into TCO2s.

In these methods, "auto" refers to the fact that these methods use
`autoRedeem()` in order to automatically choose a TCO2 token corresponding
to the oldest tokenized carbon project in the specfified token pool.
There are no fees incurred by the user when using `autoRedeem()`, i.e., the
user receives 1 TCO2 token for each pool token (BCT/NCT) redeemed.

There are two `view` helper functions `calculateNeededETHAmount()` and
`calculateNeededTokenAmount()` that should be called before using
`autoOffsetExactOutETH()` and `autoOffsetExactOutToken()`, to determine how
much native tokens e.g., MATIC, respectively how much of the ERC20 token must be sent to the
`OffsetHelper` contract in order to retire the specified amount of carbon.

The two `view` helper functions `calculateExpectedPoolTokenForETH()` and
`calculateExpectedPoolTokenForToken()` can be used to calculate the
expected amount of TCO2s that will be offset using functions
`autoOffsetExactInETH()` and `autoOffsetExactInToken()`.

### poolAddresses

```solidity
address[] poolAddresses
```

### tokenSymbolsForPaths

```solidity
string[] tokenSymbolsForPaths
```

### paths

```solidity
address[][] paths
```

### constructor

```solidity
constructor(address[] _poolAddresses, string[] _tokenSymbolsForPaths, address[][] _paths) public
```

Contract constructor. Should specify arrays of ERC20 symbols and
addresses that can used by the contract.

_See `isEligible()` for a list of tokens that can be used in the
contract. These can be modified after deployment by the contract owner
using `setEligibleTokenAddress()` and `deleteEligibleTokenAddress()`._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _poolAddresses | address[] | A list of pool token addresses. |
| _tokenSymbolsForPaths | string[] | An array of symbols of the token the user want to retire carbon credits for |
| _paths | address[][] | An array of arrays of addresses to describe the path needed to swap form the baseToken to the pool Token to the provided token symbols. |

### Redeemed

```solidity
event Redeemed(address sender, address poolToken, address[] tco2s, uint256[] amounts)
```

Emitted upon successful redemption of TCO2 tokens from a Toucan
pool token e.g., NCT or BCT.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| sender | address | The sender of the transaction |
| poolToken | address | The address of the Toucan pool token used in the redemption,  e.g., NCT or BCT |
| tco2s | address[] | An array of the TCO2 addresses that were redeemed |
| amounts | uint256[] | An array of the amounts of each TCO2 that were redeemed |

### onlyRedeemable

```solidity
modifier onlyRedeemable(address _token)
```

### onlySwappable

```solidity
modifier onlySwappable(address _token)
```

### autoOffsetExactOutToken

```solidity
function autoOffsetExactOutToken(address _fromToken, address _poolToken, uint256 _amountToOffset) public returns (address[] tco2s, uint256[] amounts)
```

Retire carbon credits using the lowest quality (oldest) TCO2
tokens available from the specified Toucan token pool by sending ERC20
tokens (cUSD, USDC, WETH, WMATIC). Use `calculateNeededTokenAmount` first in
order to find out how much of the ERC20 token is required to retire the
specified quantity of TCO2.

This function:
1. Swaps the ERC20 token sent to the contract for the specified pool token.
2. Redeems the pool token for the poorest quality TCO2 tokens available.
3. Retires the TCO2 tokens.

Note: The client must approve the ERC20 token that is sent to the contract.

_When automatically redeeming pool tokens for the lowest quality
TCO2s there are no fees and you receive exactly 1 TCO2 token for 1 pool
token._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _fromToken | address | The address of the ERC20 token that the user sends (e.g., cUSD, cUSD, USDC, WETH, WMATIC) |
| _poolToken | address | The address of the Toucan pool token that the user wants to use,  e.g., NCT or BCT |
| _amountToOffset | uint256 | The amount of TCO2 to offset |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| tco2s | address[] | An array of the TCO2 addresses that were redeemed |
| amounts | uint256[] | An array of the amounts of each TCO2 that were redeemed |

### autoOffsetExactInToken

```solidity
function autoOffsetExactInToken(address _fromToken, address _poolToken, uint256 _amountToSwap) public returns (address[] tco2s, uint256[] amounts)
```

Retire carbon credits using the lowest quality (oldest) TCO2
tokens available from the specified Toucan token pool by sending ERC20
tokens (cUSD, USDC, WETH, WMATIC). All provided token is consumed for
offsetting.

This function:
1. Swaps the ERC20 token sent to the contract for the specified pool token.
2. Redeems the pool token for the poorest quality TCO2 tokens available.
3. Retires the TCO2 tokens.

Note: The client must approve the ERC20 token that is sent to the contract.

_When automatically redeeming pool tokens for the lowest quality
TCO2s there are no fees and you receive exactly 1 TCO2 token for 1 pool
token._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _fromToken | address | The address of the ERC20 token that the user sends (e.g., cUSD, cUSD, USDC, WETH, WMATIC) |
| _poolToken | address | The address of the Toucan pool token that the user wants to use,  e.g., NCT or BCT |
| _amountToSwap | uint256 | The amount of ERC20 token to swap into Toucan pool token. Full amount will be used for offsetting. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| tco2s | address[] | An array of the TCO2 addresses that were redeemed |
| amounts | uint256[] | An array of the amounts of each TCO2 that were redeemed |

### autoOffsetExactOutETH

```solidity
function autoOffsetExactOutETH(address _poolToken, uint256 _amountToOffset) public payable returns (address[] tco2s, uint256[] amounts)
```

Retire carbon credits using the lowest quality (oldest) TCO2
tokens available from the specified Toucan token pool by sending native tokens e.g., MATIC.
Use `calculateNeededETHAmount()` first in order to find out how much
native tokens are required to retire the specified quantity of TCO2.

This function:
1. Swaps the Matic sent to the contract for the specified pool token.
2. Redeems the pool token for the poorest quality TCO2 tokens available.
3. Retires the TCO2 tokens.

_If the user sends too much native tokens , the leftover amount will be sent back
to the user._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _poolToken | address | The address of the pool token to swap for,  e.g., NCT or BCT |
| _amountToOffset | uint256 | The amount of TCO2 to offset. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| tco2s | address[] | An array of the TCO2 addresses that were redeemed |
| amounts | uint256[] | An array of the amounts of each TCO2 that were redeemed |

### autoOffsetExactInETH

```solidity
function autoOffsetExactInETH(address _poolToken) public payable returns (address[] tco2s, uint256[] amounts)
```

Retire carbon credits using the lowest quality (oldest) TCO2
tokens available from the specified Toucan token pool by sending native tokens e.g., MATIC.
All provided native tokens  is consumed for offsetting.

This function:
1. Swaps the Matic sent to the contract for the specified pool token.
2. Redeems the pool token for the poorest quality TCO2 tokens available.
3. Retires the TCO2 tokens.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _poolToken | address | The address of the pool token to swap for,  e.g., NCT or BCT |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| tco2s | address[] | An array of the TCO2 addresses that were redeemed |
| amounts | uint256[] | An array of the amounts of each TCO2 that were redeemed |

### autoOffsetPoolToken

```solidity
function autoOffsetPoolToken(address _poolToken, uint256 _amountToOffset) public returns (address[] tco2s, uint256[] amounts)
```

Retire carbon credits using the lowest quality (oldest) TCO2
tokens available by sending Toucan pool tokens,  e.g., NCT or BCT.

This function:
1. Redeems the pool token for the poorest quality TCO2 tokens available.
2. Retires the TCO2 tokens.

Note: The client must approve the pool token that is sent.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _poolToken | address | The address of the pool token to swap for,  e.g., NCT or BCT |
| _amountToOffset | uint256 | The amount of TCO2 to offset. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| tco2s | address[] | An array of the TCO2 addresses that were redeemed |
| amounts | uint256[] | An array of the amounts of each TCO2 that were redeemed |

### calculateNeededTokenAmount

```solidity
function calculateNeededTokenAmount(address _fromToken, address _poolToken, uint256 _toAmount) public view returns (uint256)
```

Return how much of the specified ERC20 token is required in
order to swap for the desired amount of a Toucan pool token, for
example,  e.g., NCT or BCT.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _fromToken | address | The address of the ERC20 token used for the swap |
| _poolToken | address | The address of the pool token to swap for,  e.g., NCT or BCT |
| _toAmount | uint256 | The desired amount of pool token to receive |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | amountsIn The amount of the ERC20 token required in order to swap for the specified amount of the pool token |

### calculateExpectedPoolTokenForToken

```solidity
function calculateExpectedPoolTokenForToken(address _fromToken, address _poolToken, uint256 _fromAmount) public view returns (uint256)
```

Calculates the expected amount of Toucan Pool token that can be
acquired by swapping the provided amount of ERC20 token.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _fromToken | address | The address of the ERC20 token used for the swap |
| _poolToken | address | The address of the pool token to swap for,  e.g., NCT or BCT |
| _fromAmount | uint256 | The amount of ERC20 token to swap |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | The expected amount of Pool token that can be acquired |

### swapExactOutToken

```solidity
function swapExactOutToken(address _fromToken, address _poolToken, uint256 _toAmount) public
```

Swap eligible ERC20 tokens for Toucan pool tokens (BCT/NCT) on SushiSwap

_Needs to be approved on the client side_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _fromToken | address | The address of the ERC20 token used for the swap |
| _poolToken | address | The address of the pool token to swap for,  e.g., NCT or BCT |
| _toAmount | uint256 | The required amount of the Toucan pool token (NCT/BCT) |

### swapExactInToken

```solidity
function swapExactInToken(address _fromToken, address _poolToken, uint256 _fromAmount) public returns (uint256)
```

Swap eligible ERC20 tokens for Toucan pool tokens (BCT/NCT) on
SushiSwap. All provided ERC20 tokens will be swapped.

_Needs to be approved on the client side._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _fromToken | address | The address of the ERC20 token used for the swap |
| _poolToken | address | The address of the pool token to swap for, |
| _fromAmount | uint256 | The amount of ERC20 token to swap  e.g., NCT or BCT |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | Resulting amount of Toucan pool token that got acquired for the swapped ERC20 tokens. |

### fallback

```solidity
fallback() external payable
```

### receive

```solidity
receive() external payable
```

### calculateNeededETHAmount

```solidity
function calculateNeededETHAmount(address _poolToken, uint256 _toAmount) public view returns (uint256)
```

Return how much native tokens e.g, MATIC is required in order to swap for the
desired amount of a Toucan pool token,  e.g., NCT or BCT.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _poolToken | address | The address of the pool token to swap for, for example, NCT or BCT |
| _toAmount | uint256 | The desired amount of pool token to receive |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | amounts The amount of native tokens  required in order to swap for the specified amount of the pool token |

### calculateExpectedPoolTokenForETH

```solidity
function calculateExpectedPoolTokenForETH(address _poolToken, uint256 _fromTokenAmount) public view returns (uint256)
```

Calculates the expected amount of Toucan Pool token that can be
acquired by swapping the provided amount of native tokens e.g., MATIC.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _poolToken | address | The address of the pool token to swap for,  e.g., NCT or BCT |
| _fromTokenAmount | uint256 | The amount of native tokens  to swap |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | The expected amount of Pool token that can be acquired |

### swapExactOutETH

```solidity
function swapExactOutETH(address _poolToken, uint256 _toAmount) public payable
```

Swap native tokens e.g., MATIC for Toucan pool tokens (BCT/NCT) on SushiSwap.
Remaining native tokens  that was not consumed by the swap is returned.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _poolToken | address | The address of the pool token to swap for,  e.g., NCT or BCT |
| _toAmount | uint256 | The required amount of the Toucan pool token (NCT/BCT) |

### swapExactInETH

```solidity
function swapExactInETH(address _poolToken) public payable returns (uint256)
```

Swap native tokens e.g., MATIC for Toucan pool tokens (BCT/NCT) on SushiSwap. All
provided native tokens  will be swapped.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _poolToken | address | The address of the pool token to swap for,  e.g., NCT or BCT |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | Resulting amount of Toucan pool token that got acquired for the swapped native tokens . |

### withdraw

```solidity
function withdraw(address _erc20Addr, uint256 _amount) public
```

Allow users to withdraw tokens they have deposited.

### deposit

```solidity
function deposit(address _erc20Addr, uint256 _amount) public
```

Allow users to deposit BCT / NCT.

_Needs to be approved_

### autoRedeem

```solidity
function autoRedeem(address _fromToken, uint256 _amount) public returns (address[] tco2s, uint256[] amounts)
```

Redeems the specified amount of NCT / BCT for TCO2.

_Needs to be approved on the client side_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _fromToken | address | Could be the address of NCT or BCT |
| _amount | uint256 | Amount to redeem |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| tco2s | address[] | An array of the TCO2 addresses that were redeemed |
| amounts | uint256[] | An array of the amounts of each TCO2 that were redeemed |

### autoRetire

```solidity
function autoRetire(address[] _tco2s, uint256[] _amounts) public
```

Retire the specified TCO2 tokens.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _tco2s | address[] | The addresses of the TCO2s to retire |
| _amounts | uint256[] | The amounts to retire from each of the corresponding TCO2 addresses |

### calculateExactOutSwap

```solidity
function calculateExactOutSwap(address _fromToken, address _poolToken, uint256 _toAmount) internal view returns (uint256[] amounts)
```

### calculateExactInSwap

```solidity
function calculateExactInSwap(address _fromToken, address _poolToken, uint256 _fromAmount) internal view returns (uint256[] amounts)
```

### showEligibleTokens

```solidity
function showEligibleTokens() public view returns (string[] _tokens)
```

Show all tokens that can be used to Offset.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |

### showEligiblePoolTokens

```solidity
function showEligiblePoolTokens() public view returns (address[] _poolTokens)
```

Show all pool token addresses that can be used to retire.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |

### generatePath

```solidity
function generatePath(address _fromToken, address _toToken) internal view returns (address[] path)
```

Show all pool token addresses that can be used to retired.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _fromToken | address | a list of token symbols that can be retired. |
| _toToken | address | a list of token symbols that can be retired. |

### dexRouter

```solidity
function dexRouter() internal view returns (contract IUniswapV2Router02)
```

### isERC20AddressEligible

```solidity
function isERC20AddressEligible(address _erc20Address) public view returns (bool _isEligible)
```

Checks if ERC20 Token is eligible for Offsetting.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _erc20Address | address | The address of the ERC20 token that the user sends (e.g., cUSD, cUSD, USDC, WETH, WMATIC) |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| _isEligible | bool | Returns if token can be redeemed |

### addPath

```solidity
function addPath(string _tokenSymbol, address[] _path) public virtual
```

Change or add eligible paths and their addresses.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _tokenSymbol | string | The symbol of the token to add |
| _path | address[] | The path of the path to add |

### removePath

```solidity
function removePath(string _tokenSymbol) public virtual
```

Delete eligible tokens stored in the contract.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _tokenSymbol | string | The symbol of the path to remove |

### isPoolAddressEligible

```solidity
function isPoolAddressEligible(address _poolToken) public view returns (bool _isEligible)
```

Cheks if Pool Token is eligible for Offsetting.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _poolToken | address | The addresses of the pool token to redeem |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| _isEligible | bool | Returns if token can be redeemed |

### addPoolToken

```solidity
function addPoolToken(address _poolToken) public virtual
```

Change or add pool token addresses.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _poolToken | address | The address of the pool token to add |

### removePoolToken

```solidity
function removePoolToken(address _poolToken) public virtual
```

Delete eligible pool token addresses stored in the contract.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _poolToken | address | The address of the pool token to remove |

### setToucanContractRegistry

```solidity
function setToucanContractRegistry(address _address) public virtual
```

Change the TCO2 contracts registry.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _address | address | The address of the Toucan contract registry to use |

