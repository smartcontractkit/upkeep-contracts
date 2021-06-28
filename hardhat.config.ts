import '@nomiclabs/hardhat-waffle'
import '@typechain/hardhat'

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
export default {
  solidity: '0.8.6',
  typechain: {
    outDir: 'typechain',
    target: 'ethers-v5',
  },
}
