/* eslint-disable @typescript-eslint/no-var-requires,no-undef */
const upgrades = require('@openzeppelin/truffle-upgrades')
const {
  expectEvent,
  expectRevert,
  constants
} = require('@openzeppelin/test-helpers')
const expect = require('chai').expect

const NotificationManager = artifacts.require('NotificationsManager')
const NotificationManagerV2 = artifacts.require('NotificationsManagerV2')

const ERC20 = artifacts.require('MockERC20')

contract.only('NotificationManager', ([Owner, Consumer, Provider, Provider2]) => {
  let notificationManager
  let token

  beforeEach(async function () {
    notificationManager = await upgrades.deployProxy(NotificationManager, [], { unsafeAllowCustomTypes: true })

    token = await ERC20.new('myToken', 'mT', Owner, 100000, { from: Owner })

    await notificationManager.setWhitelistedTokens(constants.ZERO_ADDRESS, true, { from: Owner })
    await notificationManager.setWhitelistedTokens(token.address, true, { from: Owner })

    await notificationManager.setWhitelistedProvider(Provider, true, { from: Owner })

    await token.transfer(Consumer, 10000, { from: Owner })
  })

  describe('White list of providers', () => {
    it('should not be able to register provider if not whitelisted', async () => {
      await expectRevert(notificationManager.registerProvider('testUrl', { from: Provider2 }),
        'NotificationsManager: provider is not whitelisted'
      )
    })
    it('should not be able to whitelist provider by not owner', async () => {
      await expectRevert(notificationManager.setWhitelistedProvider(Provider2, true, { from: Provider2 }), 'Ownable: caller is not the owner')
    })
    it('should be able to register provider by whitelisted provider', async () => {
      await notificationManager.setWhitelistedProvider(Provider2, true, { from: Owner })

      const url = 'testUrl'
      const receipt = await notificationManager.registerProvider(url, { from: Provider2 })

      expectEvent(receipt, 'ProviderRegistered', {
        provider: Provider2,
        url
      })

      await notificationManager.setWhitelistedProvider(Provider2, false, { from: Owner })
    })
  })

  describe('registerProvider', () => {
    it('should be able to register provider', async () => {
      const url = 'testUrl'
      const receipt = await notificationManager.registerProvider(url, { from: Provider })

      expectEvent(receipt, 'ProviderRegistered', {
        provider: Provider,
        url
      })
    })
  })

  describe('Pausable', () => {
    it('should not be able to register provider when paused', async () => {
      await notificationManager.pause({ from: Owner })
      expect(await notificationManager.paused()).to.be.eql(true)
      await expectRevert(
        notificationManager.registerProvider('testUrl', { from: Provider }),
        'Pausable: paused'
      )
    })
  })

  describe('Upgrades', () => {
    it('should allow owner to upgrade', async () => {
      const notificationManagerUpg = await upgrades.upgradeProxy(notificationManager.address, NotificationManagerV2, { unsafeAllowCustomTypes: true })
      const version = await notificationManagerUpg.getVersion()
      expect(notificationManagerUpg.address).to.be.eq(notificationManager.address)
      expect(version).to.be.eq('V2')
    })

    it('should not allow non-owner to upgrade', async () => {
      await upgrades.admin.transferProxyAdminOwnership(Provider)
      await expectRevert.unspecified(
        upgrades.upgradeProxy(notificationManager.address, NotificationManagerV2, { unsafeAllowCustomTypes: true })
      )
    })
  })
})
