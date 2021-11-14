import moment from 'moment'
import { ethers } from 'hardhat'
import { assert, expect } from 'chai'
import { CronUtilityInternalTestHelper } from '../typechain/CronUtilityInternalTestHelper'
import { CronUtilityExternalTestHelper } from '../typechain/CronUtilityExternalTestHelper'
import { CronUtilityExternal__factory as CronUtilityExternalFactory } from '../typechain/factories/CronUtilityExternal__factory'
import { validCrons, invalidCrons } from './fixtures'
import * as h from './helpers'

let cronUtility: CronUtilityInternalTestHelper | CronUtilityExternalTestHelper
let cronUtilityInternal: CronUtilityInternalTestHelper
let cronUtilityExternal: CronUtilityExternalTestHelper

const timeStamp = 32503680000 // Jan 1, 3000 12:00AM

describe('CronUtility', () => {
  beforeEach(async () => {
    const accounts = await ethers.getSigners()
    const admin = accounts[1]
    const cronUtilityInternalTestHelperFactory =
      await ethers.getContractFactory('CronUtilityInternalTestHelper')
    cronUtilityInternal = await cronUtilityInternalTestHelperFactory.deploy()
    const cronUtilityExternalFactory = new CronUtilityExternalFactory(admin)
    const cronUtilityExternalLib = await cronUtilityExternalFactory.deploy()
    const cronUtilityExternalTestHelperFactory =
      await ethers.getContractFactory('CronUtilityExternalTestHelper', {
        libraries: {
          CronUtility_External: cronUtilityExternalLib.address,
        },
      })
    cronUtilityExternal = await cronUtilityExternalTestHelperFactory.deploy()
  })

  for (let libType of ['Internal', 'External']) {
    describe(libType, () => {
      beforeEach(() => {
        cronUtility =
          libType === 'Internal' ? cronUtilityInternal : cronUtilityExternal
      })

      describe('encodeCronString() / encodedSpecToString()', () => {
        it('converts all valid cron strings to structs and back', async () => {
          const tests = validCrons.map(async (input) => {
            const spec = await cronUtility.encodeCronString(input)
            const output = await cronUtility.encodedSpecToString(spec)
            assert.equal(output, input)
          })
          await Promise.all(tests)
        })

        it('errors while parsing invalid cron strings', async () => {
          for (let idx = 0; idx < invalidCrons.length; idx++) {
            const input = invalidCrons[idx]
            await expect(
              cronUtility.encodeCronString(input),
              `expected ${input} to be invalid`,
            ).to.be.revertedWith('')
          }
        })
      })

      describe('calculateNextTick() / calculateLastTick()', () => {
        it('correctly identifies the next & last ticks for cron jobs', async () => {
          await h.setTimestamp(timeStamp)
          const now = () => moment.unix(timeStamp)
          const tests = [
            {
              cron: '0 0 31 * *', // every 31st day at midnight
              nextTick: now().add(30, 'days').unix(),
              lastTick: now().subtract(1, 'day').unix(),
            },
            {
              cron: '0 12 * * *', // every day at noon
              nextTick: now().add(12, 'hours').unix(),
              lastTick: now().subtract(12, 'hours').unix(),
            },
            {
              cron: '10 2,4,6 * * *', // at 2:10, 4:10 and 6:10
              nextTick: now().add(2, 'hours').add(10, 'minutes').unix(),
              lastTick: now()
                .subtract(17, 'hours')
                .subtract(50, 'minutes')
                .unix(),
            },
            {
              cron: '0 0 1 */3 *', // every 3rd month at midnight
              nextTick: now().add(2, 'months').unix(),
              lastTick: now().subtract(1, 'months').unix(),
            },
            {
              cron: '30 12 29 2 *', // 12:30 on leap days
              nextTick: 32634966600, // February 29, 3004 12:30 PM
              lastTick: 32382592200, // February 29, 2996 12:30 PM
            },
          ]
          for (let idx = 0; idx < tests.length; idx++) {
            const test = tests[idx]
            const nextTick = (
              await cronUtility.calculateNextTick(test.cron)
            ).toNumber()
            const lastTick = (
              await cronUtility.calculateLastTick(test.cron)
            ).toNumber()
            assert.equal(
              nextTick,
              test.nextTick,
              `got wrong next tick for "${test.cron}"`,
            )
            assert.equal(
              lastTick,
              test.lastTick,
              `got wrong next tick for "${test.cron}"`,
            )
          }
        })
      })
    })
  }
})
