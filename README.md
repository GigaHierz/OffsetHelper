# Offset Helper

This contract has the purpose to simplify the carbon offsetting process.

What it does in more exact terms is it abstracts the process of retiring TCO2, which normally looks like so:

- user exchanges USDC for BCT/NCT tokens at one of the DEXs (Uniswap, Sushiswap, etc. depending on network)
- user interacts with the BCT/NCT token contract to redeem the tokens for TCO2
- user interacts with the TCO2 token contract to retire the TCO2

With the OffsetHelper contract, the user only needs to interact with the OffsetHelper contract, which will take care of the rest in a single transaction.

## Deployments

For current deployments and ABIs, see the [`./deployments`](./deployments/) folder.
Find all other Toucan contract addresses check [here](https://app.toucan.earth/contracts)

## OffsetHelper

The `OffsetHelper` contract implements helper functions that simplify the carbon offsetting (retirement) process.

See [`./docs/OffsetHelper.md`](./docs/OffsetHelper.md) for detailed documentation.

### Development

## Preqrequisites

1. Install the required packages:
   ```
   yarn
   ```
2. Copy `.env.example` to `.env` and modify values of the required environment variables:
   1. `RPC_ENDPOINT` to specify custom RPC endpoints for Polygon Mainnet, respectively, the Mumbai Testnet.
   2. `PRIVATE_KEY` and `BLOCK_EXPLORER_API_KEY` in order to deploy contract and publish source code on [polygonscan](https://polygonscan.com). If you are developing make sure that you are using a special wallet only for development purposes that doesn't contain real life funds.

## Commands

```bash
# install dependencies
yarn install

# test the contract
yarn test

# generate documentation
yarn doc

# deploy the contract
yarn hardhat deploy --network <network>

# verify the contract
yarn hardhat verify:offsetHelper --network mumbai --address <address where Offset Helper was deployed>
```
