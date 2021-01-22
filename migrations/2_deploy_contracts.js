const { deployProxy } = require('@openzeppelin/truffle-upgrades');

const NotificationsManager = artifacts.require("NotificationsManager");
const Staking = artifacts.require("Staking");

module.exports = async function(deployer) {
   const notificationsManager = await deployProxy(NotificationsManager, [], { deployer, unsafeAllowCustomTypes: true });
   await deployer.deploy(Staking, notificationsManager.address);
}
