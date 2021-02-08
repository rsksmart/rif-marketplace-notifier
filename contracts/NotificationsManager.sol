// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/Pausable.sol";

/// @title NotificationsManager
/// @author Nazar Duchak <nazar@iovlabs.org>
contract NotificationsManager is OwnableUpgradeSafe, PausableUpgradeSafe {

    using SafeMath for uint256;
    using SafeMath for uint128;
    using SafeMath for uint64;

    // maps the tokenAddresses which can be used with this contract. By convention, address(0) is the native token.
    mapping(address => bool) public isWhitelistedToken;

    // maps the provider addresses which can be used for providing notificaitons
    mapping(address => bool) public isWhitelistedProvider;

    // maps of provider
    mapping(address => Provider) public providerRegistry;

    // Provider struct
    struct Provider {
        string url;
        mapping (bytes => Subscription) subscriptions;
    }

    // Notification subscription plan struct
    struct Subscription {
        bytes hash;
        bytes ProviderSignature;
        uint256 balance;
    }

    event ProviderRegistered(address provider, string url);

    function initialize() public initializer {
      __Ownable_init();
      __Pausable_init();
    }

    /**
     * @notice Check if provider has an active subscriptions
     * @param provider Address of provider
     */
    function hasActiveSubscriptions(address provider) public pure returns (bool) {
        return false;
    }

    /**
     * @notice whitelist a token or remove the token from whitelist
     * @param token the token from whom you want to set the whitelisted
     * @param isWhiteListed whether you want to whitelist the token or put it from the whitelist.
     */
    function setWhitelistedTokens(address token, bool isWhiteListed) public onlyOwner {
        isWhitelistedToken[token] = isWhiteListed;
    }

    /**
     * @notice whitelist a provider or remove the provider from whitelist
     * @param providerAddress the providerAddress from whom you want to set the whitelisted
     * @param isWhiteListed whether you want to whitelist the provider or put it from the whitelist.
     */
    function setWhitelistedProvider(address providerAddress, bool isWhiteListed) public onlyOwner {
        isWhitelistedProvider[providerAddress] = isWhiteListed;
    }

    /**
     * @dev Called by a pauser to pause, triggers stopped state.
     */
    function pause() public onlyOwner whenNotPaused {
        _pause();
    }

    /**
     * @dev Called by a pauser to unpause, returns to normal state.
     */
    function unpause() public onlyOwner whenPaused {
        _unpause();
    }

    /**
     * @dev Called by provider to register
     * @param url Url to the provider notifier service
     */
    function registerProvider (string memory url) public whenNotPaused {
        require(isWhitelistedProvider[msg.sender], 'NotificationsManager: provider is not whitelisted');
        Provider storage provider = providerRegistry[msg.sender];
        provider.url = url;
        emit ProviderRegistered(msg.sender, url);
    }
}
