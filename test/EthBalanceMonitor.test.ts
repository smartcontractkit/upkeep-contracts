import { ethers, network } from 'hardhat'
import { assert, expect } from 'chai'
import type { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { EthBalanceMonitor } from '../typechain/EthBalanceMonitor'
import { EthBalanceMonitor__factory as EthBalanceMonitorFactory } from '../typechain/factories/EthBalanceMonitor__factory'

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

let bm: EthBalanceMonitor
let owner: SignerWithAddress
let stranger: SignerWithAddress
let keeperRegistry: SignerWithAddress

async function assertBalances(
  b1: number,
  b2: number,
  b3: number,
  b4: number,
  b5: number,
  b6: number,
) {
  const getBalance = ethers.provider.getBalance
  const toEth = (n: number) => ethers.utils.parseUnits(n.toString(), 'ether')
  assert.isTrue((await getBalance(watchAddress1)).eq(toEth(b1)), 'address 1')
  assert.isTrue((await getBalance(watchAddress2)).eq(toEth(b2)), 'address 2')
  assert.isTrue((await getBalance(watchAddress3)).eq(toEth(b3)), 'address 3')
  assert.isTrue((await getBalance(watchAddress4)).eq(toEth(b4)), 'address 4')
  assert.isTrue((await getBalance(watchAddress5)).eq(toEth(b5)), 'address 5')
  assert.isTrue((await getBalance(watchAddress6)).eq(toEth(b6)), 'address 6')
}

beforeEach(async () => {
  const accounts = await ethers.getSigners()
  owner = accounts[0]
  stranger = accounts[1]
  keeperRegistry = accounts[2]
  watchAddress5 = accounts[3].address
  watchAddress6 = accounts[4].address
  const bmFactory = new EthBalanceMonitorFactory(owner)
  bm = await bmFactory.deploy(keeperRegistry.address, oneEth, twoEth)
  await bm.deployed()
})

afterEach(async () => {
  await network.provider.request({
    method: 'hardhat_reset',
    params: [],
  })
})

describe('EthBalanceMonitor', () => {
  describe('keeperRegistryAddress()', () => {
    it('Should initialize with the address provided to the constructor', async () => {
      const address = await bm.keeperRegistryAddress()
      assert.equal(keeperRegistry.address, address)
    })
  })

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
      expect(withdrawTxStranger).to.be.revertedWith('')
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
      expect(pauseTxStranger).to.be.revertedWith('')
      const pauseTxOwner = await bm.connect(owner).pause()
      await pauseTxOwner.wait()
      const unpauseTxStranger = bm.connect(stranger).unpause()
      expect(unpauseTxStranger).to.be.revertedWith('')
    })
  })

  describe('setWatchList() / getWatchList() / isActive()', () => {
    it('Should allow owner to set the watchlist', async () => {
      // add first watchlist
      let setTx = await bm.connect(owner).setWatchList([watchAddress1])
      await setTx.wait()
      let watchList = await bm.getWatchList()
      assert.deepEqual([watchAddress1], watchList)
      assert.isTrue(await bm.isActive(watchAddress1))
      assert.isFalse(await bm.isActive(watchAddress2))
      assert.isFalse(await bm.isActive(watchAddress3))
      // add more to watchlist
      setTx = await bm
        .connect(owner)
        .setWatchList([watchAddress1, watchAddress2, watchAddress3])
      await setTx.wait()
      watchList = await bm.getWatchList()
      assert.deepEqual([watchAddress1, watchAddress2, watchAddress3], watchList)
      assert.isTrue(await bm.isActive(watchAddress1))
      assert.isTrue(await bm.isActive(watchAddress2))
      assert.isTrue(await bm.isActive(watchAddress3))
      // remove some from watchlist
      setTx = await bm
        .connect(owner)
        .setWatchList([watchAddress3, watchAddress1])
      await setTx.wait()
      watchList = await bm.getWatchList()
      assert.deepEqual([watchAddress3, watchAddress1], watchList)
      assert.isTrue(await bm.isActive(watchAddress1))
      assert.isFalse(await bm.isActive(watchAddress2))
      assert.isTrue(await bm.isActive(watchAddress3))
    })

    it('Should not allow strangers to set the watchlist', async () => {
      const setTxStranger = bm.connect(stranger).setWatchList([watchAddress1])
      expect(setTxStranger).to.be.revertedWith('')
    })
  })

  describe('setConfig() / getConfig()', () => {
    it('Should initialize with the config provided to the constructor', async () => {
      const [minBalanceWei, topUpAmountWei] = await bm.getConfig()
      assert.isTrue(minBalanceWei.eq(oneEth))
      assert.isTrue(topUpAmountWei.eq(twoEth))
    })

    it('Should allow owner to set the watchlist', async () => {
      const setTx = await bm.connect(owner).setConfig(twoEth, threeEth)
      await setTx.wait()
      const [minBalanceWei, topUpAmountWei] = await bm.getConfig()
      assert.isTrue(minBalanceWei.eq(twoEth))
      assert.isTrue(topUpAmountWei.eq(threeEth))
    })

    it('Should not allow strangers to set the watchlist', async () => {
      const setTxStranger = bm.connect(stranger).setConfig(twoEth, threeEth)
      expect(setTxStranger).to.be.revertedWith('')
    })
  })

  describe('checkUpkeep()', () => {
    beforeEach(async () => {
      const setTx = await bm.connect(owner).setWatchList([
        watchAddress1, // needs funds
        watchAddress5, // funded
        watchAddress2, // needs funds
        watchAddress6, // funded
        watchAddress3, // needs funds
      ])
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

    it('Should list of address that are underfunded', async () => {
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
      assert.deepEqual([watchAddress1, watchAddress2, watchAddress3], addresses)
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
      const setTx = await bm.connect(owner).setWatchList([
        watchAddress1, // needs funds
        watchAddress5, // funded
        watchAddress2, // needs funds
        watchAddress6, // funded
        watchAddress3, // needs funds
        // watchAddress4 - omitted
      ])
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
        await assertBalances(0, 0, 0, 0, 10_000, 10_000)
        const performTx = await bm
          .connect(keeperRegistry)
          .performUpkeep(validPayload)
        await performTx.wait()
        await assertBalances(2, 2, 2, 0, 10_000, 10_000)
      })

      it('Should only fund active, underfunded addresses', async () => {
        await assertBalances(0, 0, 0, 0, 10_000, 10_000)
        const performTx = await bm
          .connect(keeperRegistry)
          .performUpkeep(invalidPayload)
        await performTx.wait()
        await assertBalances(2, 2, 0, 0, 10_000, 10_000)
      })

      it('Should only be callable by the keeper registry contract', async () => {
        let performTx = bm.connect(owner).performUpkeep(validPayload)
        expect(performTx).to.be.revertedWith('')
        performTx = bm.connect(stranger).performUpkeep(validPayload)
        expect(performTx).to.be.revertedWith('')
      })
    })

    it('Should revert if there is not enough eth', async () => {
      const performTx = bm.connect(keeperRegistry).performUpkeep(validPayload)
      expect(performTx).to.be.revertedWith('')
    })
  })
})
