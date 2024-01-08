require("dotenv").config();
require("@nomicfoundation/hardhat-toolbox");
require("hardhat-tracer");
require("solidity-coverage");

const FUJI_URL = process.env.FUJI_URL;
const AVAXMAINNET_URL = process.env.AVAXMAINNET_URL;
const PRIVATE_KEY = process.env.PRIVATE_KEY;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    // Testnet
    Fuji: {
      url: FUJI_URL,
      accounts: [
        PRIVATE_KEY
      ],
      chainId: 43113,
    },
    // Mainnet
    // AvalancheMainnet: {
    //   url: AVMAINNET_URL,
    //   accounts: [
    //     PRIVATE_KEY
    //   ],
    //   chainId: 43114,
    // },
  },
  solidity: {
    version: "0.8.8",
    settings: {
      optimizer: {
        enabled: true,
        runs: 99999,
      },
    },
  },
  gasReporter: {
    currency: 'USD',
    gasPrice: 25,
    enabled: true
  }
};
