import '@nomiclabs/hardhat-waffle'
import '@typechain/hardhat'

export default {
  solidity: '0.8.6',
  typechain: {
    outDir: 'typechain',
    target: 'ethers-v5',
  },
  mocha: {
    file: 'test/hooks.ts',
  },
}
