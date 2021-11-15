import '@nomiclabs/hardhat-waffle'
import '@typechain/hardhat'
import 'hardhat-gas-reporter'
import deepmerge from 'deepmerge'
import config from './hardhat.config'

const overrides = {
  mocha: {
    invert: false,
    timeout: 300_000,
  },
  gasReporter: {
    enabled: true,
    currency: 'USD',
    coinmarketcap: process.env.CMC_KEY,
  },
}

export default deepmerge(config, overrides)
