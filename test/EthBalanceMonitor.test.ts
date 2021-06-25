import { ethers, network } from 'hardhat'
import { assert, expect } from 'chai'
import type { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { EthBalanceMonitorExposed } from '../typechain/EthBalanceMonitorExposed'
import { ReceiveReverter } from '../typechain/ReceiveReverter'
import { EthBalanceMonitorExposed__factory as EthBalanceMonitorFactory } from '../typechain/factories/EthBalanceMonitorExposed__factory'
import { ReceiveReverter__factory as ReceiveReverterFactory } from '../typechain/factories/ReceiveReverter__factory'
import { BigNumberish, BigNumber } from 'ethers'

const oneEth = ethers.utils.parseEther('1')
const twoEth = ethers.utils.parseEther('2')
const threeEth = ethers.utils.parseEther('3')
const fiveEth = ethers.utils.parseEther('5')
const sixEth = ethers.utils.parseEther('6')
const tenEth = ethers.utils.parseEther('10')

const watchAddress1 = ethers.Wallet.createRandom().address
const watchAddress2 = ethers.Wallet.createRandom().address
const watchAddress3 = ethers.Wallet.createRandom().address
const watchAddress4 = ethers.Wallet.createRandom().address
let watchAddress5: string
let watchAddress6: string

let bm: EthBalanceMonitorExposed
let receiveReverter: ReceiveReverter
let owner: SignerWithAddress
let stranger: SignerWithAddress
let keeperRegistry: SignerWithAddress

async function assertBalance(
  address: string,
  balance: BigNumberish,
  msg?: string,
) {
  expect(await ethers.provider.getBalance(address)).equal(balance, msg)
}

async function assertWatchlistBalances(
  balance1: number,
  balance2: number,
  balance3: number,
  balance4: number,
  balance5: number,
  balance6: number,
) {
  const toEth = (n: number) => ethers.utils.parseUnits(n.toString(), 'ether')
  await assertBalance(watchAddress1, toEth(balance1), 'address 1')
  await assertBalance(watchAddress2, toEth(balance2), 'address 2')
  await assertBalance(watchAddress3, toEth(balance3), 'address 3')
  await assertBalance(watchAddress4, toEth(balance4), 'address 4')
  await assertBalance(watchAddress5, toEth(balance5), 'address 5')
  await assertBalance(watchAddress6, toEth(balance6), 'address 6')
}

const OWNABLE_ERR = 'Ownable: caller is not the owner'

beforeEach(async () => {
  const accounts = await ethers.getSigners()
  owner = accounts[0]
  stranger = accounts[1]
  keeperRegistry = accounts[2]
  watchAddress5 = accounts[3].address
  watchAddress6 = accounts[4].address
  const bmFactory = new EthBalanceMonitorFactory(owner)
  const rrFactory = new ReceiveReverterFactory(owner)
  bm = await bmFactory.deploy(keeperRegistry.address, 0)
  receiveReverter = await rrFactory.deploy()
  receiveReverter = await rrFactory.deploy()
  await bm.deployed()
  await receiveReverter.deployed()
})

afterEach(async () => {
  await network.provider.request({
    method: 'hardhat_reset',
    params: [],
  })
})

describe('EthBalanceMonitor', () => {
  describe('receive()', () => {
    it('Should allow anyone to add funds', async () => {
      const tx = await owner.sendTransaction({
        to: bm.address,
        value: oneEth,
      })
      await tx.wait()
      const tx2 = await stranger.sendTransaction({
        to: bm.address,
        value: oneEth,
      })
      await tx2.wait()
    })

    it('Should emit an event', async () => {
      const tx = await owner.sendTransaction({
        to: bm.address,
        value: oneEth,
      })
      expect(tx).to.emit(bm, 'FundsAdded').withArgs(oneEth)
    })
  })

  describe('withdraw()', () => {
    beforeEach(async () => {
      const tx = await owner.sendTransaction({
        to: bm.address,
        value: oneEth,
      })
      await tx.wait()
    })

    it('Should allow the owner to withdraw', async () => {
      const beforeBalance = await owner.getBalance()
      const withdrawTxOwner = await bm
        .connect(owner)
        .withdraw(oneEth, owner.address)
      await withdrawTxOwner.wait()
      const afterBalance = await owner.getBalance()
      assert.isTrue(
        afterBalance.gt(beforeBalance),
        'balance did not increase after withdraw',
      )
    })

    it('Should allow the owner to withdraw to anyone', async () => {
      const beforeBalance = await stranger.getBalance()
      const withdrawTxOwner = await bm
        .connect(owner)
        .withdraw(oneEth, stranger.address)
      await withdrawTxOwner.wait()
      const afterBalance = await stranger.getBalance()
      assert.isTrue(
        beforeBalance.add(oneEth).eq(afterBalance),
        'balance did not increase after withdraw',
      )
    })

    it('Should not allow strangers to withdraw', async () => {
      const withdrawTxStranger = bm
        .connect(stranger)
        .withdraw(oneEth, owner.address)
      await expect(withdrawTxStranger).to.be.revertedWith(OWNABLE_ERR)
    })
  })

  describe('pause() / unpause()', () => {
    it('Should allow owner to pause / unpause', async () => {
      const pauseTx = await bm.connect(owner).pause()
      await pauseTx.wait()
      const unpauseTx = await bm.connect(owner).unpause()
      await unpauseTx.wait()
    })

    it('Should not allow strangers to pause / unpause', async () => {
      const pauseTxStranger = bm.connect(stranger).pause()
      await expect(pauseTxStranger).to.be.revertedWith(OWNABLE_ERR)
      const pauseTxOwner = await bm.connect(owner).pause()
      await pauseTxOwner.wait()
      const unpauseTxStranger = bm.connect(stranger).unpause()
      await expect(unpauseTxStranger).to.be.revertedWith(OWNABLE_ERR)
    })
  })

  describe('setWatchList() / getWatchList() / getAccountInfo()', () => {
    it('Should allow owner to set the watchlist', async () => {
      // should start unactive
      assert.isFalse((await bm.getAccountInfo(watchAddress1)).isActive)
      // add first watchlist
      let setTx = await bm
        .connect(owner)
        .setWatchList([watchAddress1], [oneEth], [twoEth])
      await setTx.wait()
      let watchList = await bm.getWatchList()
      assert.deepEqual(watchList, [watchAddress1])
      const accountInfo = await bm.getAccountInfo(watchAddress1)
      assert.isTrue(accountInfo.isActive)
      expect(accountInfo.minBalanceWei).to.equal(oneEth)
      expect(accountInfo.topUpAmountWei).to.equal(twoEth)
      // add more to watchlist
      setTx = await bm
        .connect(owner)
        .setWatchList(
          [watchAddress1, watchAddress2, watchAddress3],
          [oneEth, twoEth, threeEth],
          [oneEth, twoEth, threeEth],
        )
      await setTx.wait()
      watchList = await bm.getWatchList()
      assert.deepEqual(watchList, [watchAddress1, watchAddress2, watchAddress3])
      let accountInfo1 = await bm.getAccountInfo(watchAddress1)
      let accountInfo2 = await bm.getAccountInfo(watchAddress2)
      let accountInfo3 = await bm.getAccountInfo(watchAddress3)
      expect(accountInfo1.isActive).to.be.true
      expect(accountInfo1.minBalanceWei).to.equal(oneEth)
      expect(accountInfo1.topUpAmountWei).to.equal(oneEth)
      expect(accountInfo2.isActive).to.be.true
      expect(accountInfo2.minBalanceWei).to.equal(twoEth)
      expect(accountInfo2.topUpAmountWei).to.equal(twoEth)
      expect(accountInfo3.isActive).to.be.true
      expect(accountInfo3.minBalanceWei).to.equal(threeEth)
      expect(accountInfo3.topUpAmountWei).to.equal(threeEth)
      // remove some from watchlist
      setTx = await bm
        .connect(owner)
        .setWatchList(
          [watchAddress3, watchAddress1],
          [threeEth, oneEth],
          [threeEth, oneEth],
        )
      await setTx.wait()
      watchList = await bm.getWatchList()
      assert.deepEqual(watchList, [watchAddress3, watchAddress1])
      accountInfo1 = await bm.getAccountInfo(watchAddress1)
      accountInfo2 = await bm.getAccountInfo(watchAddress2)
      accountInfo3 = await bm.getAccountInfo(watchAddress3)
      expect(accountInfo1.isActive).to.be.true
      expect(accountInfo2.isActive).to.be.false
      expect(accountInfo3.isActive).to.be.true
    })

    it('Should not allow strangers to set the watchlist', async () => {
      const setTxStranger = bm
        .connect(stranger)
        .setWatchList([watchAddress1], [oneEth], [twoEth])
      await expect(setTxStranger).to.be.revertedWith(OWNABLE_ERR)
    })
  })

  describe('getKeeperRegistryAddress() / setKeeperRegistryAddress()', () => {
    const newAddress = ethers.Wallet.createRandom().address

    it('Should initialize with the registry address provided to the constructor', async () => {
      const address = await bm.getKeeperRegistryAddress()
      assert.equal(address, keeperRegistry.address)
    })

    it('Should allow owner to set the registry address', async () => {
      const setTx = await bm.connect(owner).setKeeperRegistryAddress(newAddress)
      await setTx.wait()
      const address = await bm.getKeeperRegistryAddress()
      assert.equal(address, newAddress)
    })

    it('Should not allow strangers to set the registry address', async () => {
      const setTx = bm.connect(stranger).setKeeperRegistryAddress(newAddress)
      await expect(setTx).to.be.revertedWith(OWNABLE_ERR)
    })
  })

  describe('getMinWaitPeriod / setMinWaitPeriod()', () => {
    const newWaitPeriod = BigNumber.from(1)

    it('Should initialize with the wait period provided to the constructor', async () => {
      const minWaitPeriod = await bm.getMinWaitPeriod()
      expect(minWaitPeriod).to.equal(0)
    })

    it('Should allow owner to set the wait period', async () => {
      const setTx = await bm.connect(owner).setMinWaitPeriod(newWaitPeriod)
      await setTx.wait()
      const minWaitPeriod = await bm.getMinWaitPeriod()
      expect(minWaitPeriod).to.equal(newWaitPeriod)
    })

    it('Should not allow strangers to set the wait period', async () => {
      const setTx = bm.connect(stranger).setMinWaitPeriod(newWaitPeriod)
      await expect(setTx).to.be.revertedWith(OWNABLE_ERR)
    })
  })

  describe('checkUpkeep()', () => {
    beforeEach(async () => {
      const setTx = await bm.connect(owner).setWatchList(
        [
          watchAddress1, // needs funds
          watchAddress5, // funded
          watchAddress2, // needs funds
          watchAddress6, // funded
          watchAddress3, // needs funds
        ],
        new Array(5).fill(oneEth),
        new Array(5).fill(twoEth),
      )
      await setTx.wait()
    })

    it('Should return no results if contract lacks sufficient funds', async () => {
      const fundTx = await owner.sendTransaction({
        to: bm.address,
        value: fiveEth, // needs 6 total
      })
      await fundTx.wait()
      const [should, _] = await bm.checkUpkeep('0x')
      assert.isFalse(should)
    })

    it('Should return list of address that are underfunded', async () => {
      const fundTx = await owner.sendTransaction({
        to: bm.address,
        value: sixEth, // needs 6 total
      })
      await fundTx.wait()
      const [should, payload] = await bm.checkUpkeep('0x')
      assert.isTrue(should)
      const [addresses] = ethers.utils.defaultAbiCoder.decode(
        ['address[]'],
        payload,
      )
      assert.deepEqual(addresses, [watchAddress1, watchAddress2, watchAddress3])
    })

    it('Should omit addresses that have been funded recently', async () => {
      const setWaitPdTx = await bm.setMinWaitPeriod(5)
      const fundTx = await owner.sendTransaction({
        to: bm.address,
        value: sixEth,
      })
      await Promise.all([setWaitPdTx.wait(), fundTx.wait()])
      const blockNum = await ethers.provider.getBlockNumber()
      const setTopUpTx = await bm.setLastTopUpXXXTestOnly(
        watchAddress2,
        blockNum - 1,
      )
      await setTopUpTx.wait()
      const [should, payload] = await bm.checkUpkeep('0x')
      assert.isTrue(should)
      const [addresses] = ethers.utils.defaultAbiCoder.decode(
        ['address[]'],
        payload,
      )
      assert.deepEqual(addresses, [watchAddress1, watchAddress3])
    })
  })

  describe('performUpkeep()', () => {
    let validPayload: string
    let invalidPayload: string

    beforeEach(async () => {
      validPayload = ethers.utils.defaultAbiCoder.encode(
        ['address[]'],
        [[watchAddress1, watchAddress2, watchAddress3]],
      )
      invalidPayload = ethers.utils.defaultAbiCoder.encode(
        ['address[]'],
        [[watchAddress1, watchAddress2, watchAddress4, watchAddress5]],
      )
      const setTx = await bm.connect(owner).setWatchList(
        [
          watchAddress1, // needs funds
          watchAddress5, // funded
          watchAddress2, // needs funds
          watchAddress6, // funded
          watchAddress3, // needs funds
          // watchAddress4 - omitted
        ],
        new Array(5).fill(oneEth),
        new Array(5).fill(twoEth),
      )
      await setTx.wait()
    })

    context('when funded', () => {
      beforeEach(async () => {
        const fundTx = await owner.sendTransaction({
          to: bm.address,
          value: tenEth,
        })
        await fundTx.wait()
      })

      it('Should fund the appropriate addresses', async () => {
        await assertWatchlistBalances(0, 0, 0, 0, 10_000, 10_000)
        const performTx = await bm
          .connect(keeperRegistry)
          .performUpkeep(validPayload)
        await performTx.wait()
        await assertWatchlistBalances(2, 2, 2, 0, 10_000, 10_000)
      })

      it('Should only fund active, underfunded addresses', async () => {
        await assertWatchlistBalances(0, 0, 0, 0, 10_000, 10_000)
        const performTx = await bm
          .connect(keeperRegistry)
          .performUpkeep(invalidPayload)
        await performTx.wait()
        await assertWatchlistBalances(2, 2, 0, 0, 10_000, 10_000)
      })

      it('Should continue funding addresses even if one reverts', async () => {
        await assertWatchlistBalances(0, 0, 0, 0, 10_000, 10_000)
        const addresses = [
          watchAddress1,
          receiveReverter.address,
          watchAddress2,
        ]
        const setTx = await bm
          .connect(owner)
          .setWatchList(
            addresses,
            new Array(3).fill(oneEth),
            new Array(3).fill(twoEth),
          )
        await setTx.wait()
        const payload = ethers.utils.defaultAbiCoder.encode(
          ['address[]'],
          [addresses],
        )
        const performTx = await bm
          .connect(keeperRegistry)
          .performUpkeep(payload)
        await performTx.wait()
        await assertWatchlistBalances(2, 2, 0, 0, 10_000, 10_000)
        await assertBalance(receiveReverter.address, 0)
        expect(performTx).to.emit(bm, 'TopUpSucceeded').withArgs(watchAddress1)
        expect(performTx).to.emit(bm, 'TopUpSucceeded').withArgs(watchAddress2)
        expect(performTx)
          .to.emit(bm, 'TopUpFailed')
          .withArgs(receiveReverter.address)
      })

      it('Should not fund addresses that have been funded recently', async () => {
        const setWaitPdTx = await bm.setMinWaitPeriod(5)
        await setWaitPdTx.wait()
        const blockNum = await ethers.provider.getBlockNumber()
        const setTopUpTx = await bm.setLastTopUpXXXTestOnly(
          watchAddress2,
          blockNum - 1,
        )
        await setTopUpTx.wait()
        await assertWatchlistBalances(0, 0, 0, 0, 10_000, 10_000)
        const performTx = await bm
          .connect(keeperRegistry)
          .performUpkeep(validPayload)
        await performTx.wait()
        await assertWatchlistBalances(2, 0, 2, 0, 10_000, 10_000)
      })

      it('Should only be callable by the keeper registry contract', async () => {
        const revertReason = 'only callable by keeper'
        let performTx = bm.connect(owner).performUpkeep(validPayload)
        await expect(performTx).to.be.revertedWith(revertReason)
        performTx = bm.connect(stranger).performUpkeep(validPayload)
        await expect(performTx).to.be.revertedWith(revertReason)
      })
    })

    // it('Should revert if there is not enough eth', async () => {
    //   const revertReason = 'not enough eth to fund all addresses'
    //   const performTx = bm.connect(keeperRegistry).performUpkeep(validPayload)
    //   await expect(performTx).to.be.revertedWith(revertReason)
    // })
  })
})
