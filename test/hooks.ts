import { network } from 'hardhat'

afterEach(async () => {
  await network.provider.request({
    method: 'hardhat_reset',
    params: [],
  })
})
