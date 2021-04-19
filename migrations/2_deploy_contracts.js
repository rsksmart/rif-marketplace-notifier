const { deployProxy } = require('@openzeppelin/truffle-upgrades')

const NotifierManager = artifacts.require('NotifierManager')
const Staking = artifacts.require('Staking')

module.exports = async function (deployer) {
  const notifierManager = await deployProxy(NotifierManager, [], { deployer })
  await deployer.deploy(Staking, notifierManager.address)
  await notifierManager.setWhitelistedProvider('0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1', true)
  await notifierManager.setWhitelistedProvider('0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0', true)
}
