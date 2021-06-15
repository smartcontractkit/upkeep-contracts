import { ethers } from 'hardhat'

describe('BalanceMonitor', () => {
  it('Should be deployable', async function () {
    const Greeter = await ethers.getContractFactory('BalanceMonitor')
    const greeter = await Greeter.deploy()
    await greeter.deployed()
  })
})
