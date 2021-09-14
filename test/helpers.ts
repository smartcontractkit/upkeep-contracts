import { ethers } from 'hardhat'
import { expect, assert } from 'chai'
import { BigNumberish } from 'ethers'
import { network } from 'hardhat'
import { Contract } from 'ethers'

export async function assertBalance(
  address: string,
  balance: BigNumberish,
  msg?: string,
) {
  expect(await ethers.provider.getBalance(address)).equal(balance, msg)
}

export type ThenArg<T> = T extends PromiseLike<infer U> ? U : T

export async function setTimestamp(timestamp: number) {
  await network.provider.request({
    method: 'evm_setNextBlockTimestamp',
    params: [timestamp],
  })
  await network.provider.request({
    method: 'evm_mine',
    params: [],
  })
}

export async function fastForward(duration: number) {
  await network.provider.request({
    method: 'evm_increaseTime',
    params: [duration],
  })
  await network.provider.request({
    method: 'evm_mine',
    params: [],
  })
}

export async function mineBlock() {
  await network.provider.request({
    method: 'evm_mine',
    params: [],
  })
}

export async function reset() {
  await network.provider.request({
    method: 'hardhat_reset',
    params: [],
  })
}

/**
 * Check that a contract's abi exposes the expected interface.
 *
 * @param contract The contract with the actual abi to check the expected exposed methods and getters against.
 * @param expectedPublic The expected public exposed methods and getters to match against the actual abi.
 */
export function assertPublicABI(contract: Contract, expectedPublic: string[]) {
  const expectedSet = new Set(expectedPublic)
  const actualSet = new Set<string>()
  for (const m in contract.functions) {
    if (!m.includes('(')) {
      actualSet.add(m)
    }
  }
  actualSet.forEach((method) => {
    expect(expectedSet).includes(
      method,
      `#${method} is NOT expected to be public`,
    )
  })
  actualSet.forEach((method) => {
    expect(actualSet).includes(method, `#${method} is expected to be public`)
  })
}
