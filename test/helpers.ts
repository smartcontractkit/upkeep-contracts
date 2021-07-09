import { ethers } from 'hardhat'
import { expect } from 'chai'
import { BigNumberish } from 'ethers'

export async function assertBalance(
  address: string,
  balance: BigNumberish,
  msg?: string,
) {
  expect(await ethers.provider.getBalance(address)).equal(balance, msg)
}
