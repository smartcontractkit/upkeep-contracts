import { ethers } from 'hardhat'
import { assert, expect } from 'chai'
import { CronUpkeepFactory } from '../typechain/CronUpkeepFactory'
import { CronUtilityExternal } from '../typechain/CronUtilityExternal'
import { CronUtilityExternal__factory as CronUtilityExternalFactory } from '../typechain/factories/CronUtilityExternal__factory'
import type { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'

let cronUtilityExternalLib: CronUtilityExternal
let factory: CronUpkeepFactory

let admin: SignerWithAddress
let owner: SignerWithAddress

describe('CronUpkeepFactory', () => {
  beforeEach(async () => {
    const accounts = await ethers.getSigners()
    admin = accounts[0]
    owner = accounts[1]
    const cronUtilityExternalFactory = new CronUtilityExternalFactory(admin)
    cronUtilityExternalLib = await cronUtilityExternalFactory.deploy()
    const cronUpkeepFactoryFactory = await ethers.getContractFactory(
      'CronUpkeepFactory',
      {
        signer: admin,
        libraries: {
          CronUtility_External: cronUtilityExternalLib.address,
        },
      },
    )
    factory = await cronUpkeepFactoryFactory.deploy()
  })

  describe('constructor()', () => {
    it('deploys a delegate contract', async () => {
      assert.notEqual(
        await factory.cronDelegateAddress(),
        ethers.constants.AddressZero,
      )
    })
  })

  describe('newCronUpkeep()', () => {
    it('emits an event', async () => {
      await expect(factory.connect(owner).newCronUpkeep()).to.emit(
        factory,
        'NewCronUpkeepCreated',
      )
    })
    it('sets the deployer as the owner', async () => {
      const response = await factory.connect(owner).newCronUpkeep()
      const { events } = await response.wait()
      if (!events) {
        assert.fail('no events emitted')
      }
      const upkeepAddress = events[0].args?.upkeep
      const cronUpkeepFactory = await ethers.getContractFactory('CronUpkeep', {
        libraries: { CronUtility_External: cronUtilityExternalLib.address },
      })
      assert(
        await cronUpkeepFactory.attach(upkeepAddress).owner(),
        owner.address,
      )
    })
  })
})
