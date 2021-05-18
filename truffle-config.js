const HDWalletProvider = require('@truffle/hdwallet-provider');

const fs = require('fs');
// const mnemonic = fs.readFileSync(".secret").toString().trim();
// const HDWalletProvider = require('truffle-hdwallet-provider-privkey');
const mnemonic = process.env.MNEMONIC || ""

module.exports = {
  networks: {
    heco: {
      provider: () => new HDWalletProvider(mnemonic, 'https://http-mainnet.hecochain.com'),
      network_id: 128
    },
    hecotest: {
      provider: () => new HDWalletProvider(mnemonic, 'https://http-testnet.hecochain.com'),
      network_id: 256
    }

  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    timeout: 100000
  },

  // Configure your compilers
  compilers: {
    solc: {
      version: ">=0.5.12",    // Fetch exact version from solc-bin (default: truffle's version)
      docker: false,        // Use "0.5.1" you've installed locally with docker (default: false)
      settings: {          // See the solidity docs for advice about optimization and evmVersion
       optimizer: {
         enabled: false,
         runs: 200
       },
       evmVersion: "byzantium"
      }
    },
  }
}
