import '@nomiclabs/hardhat-waffle'
import '@typechain/hardhat'
import 'hardhat-gas-reporter'

export default {
  solidity: {
    version: '0.8.6',
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000000,
      },
    },
  },
  typechain: {
    outDir: 'typechain',
    target: 'ethers-v5',
  },
  mocha: {
    // skip gas tests, run those with yarn test:gas
    grep: '/Gas Usage/',
    invert: true,
    file: 'test/hooks.ts',
  },
  gasReporter: {
    enabled: false,
  },
}
