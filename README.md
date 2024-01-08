# Quarry Draw Validator Contracts

The Validator is the key of QuarryDraw ecosystem. The validator represent an Avalache Mainnet Validator Node, it is a contract that sells stakes of the validator, which is then run by the QuarryDraw team. Rewards are then distributed to active users based on their holdings without any stake needed, thus shares are completely liquid.

This project uses a gas-optimized reference implementation for [EIP-2535 Diamonds](https://github.com/ethereum/EIPs/issues/2535). To learn more about this and other implementations go here: https://github.com/mudgen/diamond

This implementation uses Hardhat and Solidity 0.8.*

## Installation

1. Clone this repo:
```sh
git clone git@github.com:Puddi1/QD-Validator-Contracts.git
```

2. Install NPM packages:
```sh
cd QD-Validator-Contracts
npm i
```

## Compile

To compile the contracts in `./contract` run:

```sh
npx hardhat compile
```

Their artifacts will be placed in `./artifacts/contracts`

## Tests

To run test, which are stored in `./test` run:

```sh
npx hardhat test
```

## Tests Coverage

To see tests coverage run:

```sh
npx hardhat coverage
```

## Deployment

Before deployment you should enter necessary environment variables, such as:

- `FUJI_URL` is the Fuji RPC url
- `AVAXMAINNET_URL` is the Avalanche (C-Chain) RPC url
- `PRIVATE_KEY` is the private key of the wallet you wish to deploy contracts with

See .env.example for syntax examples.

Deployments scripts are handled in `./scripts`, to deploy in Fuji testnet:

```sh
npx hardhat run scripts/deployTestnet.js --network Fuji
```

To deploy in Avalanche mainnet:

```sh
npx hardhat run scripts/deployTestnet.js --network AvalancheMainnet
```