// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/cryptography/ECDSA.sol";

/// @title NotificationsManager
/// @author Nazar Duchak <nazar@iovlabs.org>
contract NotificationsManager is OwnableUpgradeSafe, PausableUpgradeSafe {

    using ECDSA for bytes32;
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
        mapping (bytes32 => Subscription) subscriptions;
    }

    // Notification subscription plan struct
    struct Subscription {
        bytes providerSignature;
        uint256 balance;
    }

    event ProviderRegistered(address provider, string url);
    event SubscriptionCreated(bytes32 hash, address provider, address token, uint256 amount);
    event FundsWithdrawn(bytes32 hash, uint256 amount, address token);
    event ReturnFunds(bytes32 hash, uint256 amount, address token);

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
     * @dev Called by PROVIDER to register
     * @param url Url to the provider notifier service
     */
    function registerProvider (string memory url) public whenNotPaused {
        require(isWhitelistedProvider[msg.sender], 'NotificationsManager: provider is not whitelisted');
        Provider storage provider = providerRegistry[msg.sender];
        provider.url = url;
        emit ProviderRegistered(msg.sender, url);
    }

    /**
     * @notice new Subscription for given Provider
     * @dev Called by CONSUMER to register
     * @param hash Hash of subscription SLA
     * @param providerAddress Address of provider
     * @param sig Signature of provider
     * @param token The token in which you want to make the subscription. By convention: address(0) is the native currency
     * @param amount If token is set, this is the amount of tokens that is transferred
     */
    function createSubscription (
        bytes32 hash,
        address providerAddress,
        bytes memory sig,
        address token,
        uint256 amount
    ) public payable whenNotPaused {
        require(isWhitelistedProvider[providerAddress], "NotificationsManager: provider is not whitelisted");
        require(isWhitelistedToken[token], "NotificationsManager: not possible to interact with this token");
        require(amount > 0 || msg.value > 0, "NotificationsManager: You should deposit funds to be able to create subscription");
        Provider storage provider = providerRegistry[providerAddress];
        require(bytes(provider.url).length != 0, "NotificationsManager: Provider is not registered");
        require(_recoverSigner(hash, sig) == providerAddress, 'NotificationsManager: Invalid signature');
        Subscription storage subscription = provider.subscriptions[hash];

        if(token == address(0)) {
            subscription.balance = subscription.balance.add(msg.value);
        } else {
            require(IERC20(token).transferFrom(msg.sender, address(this), amount), "NotificationsManager: not allowed to deposit tokens from token contract");
            subscription.balance = subscription.balance.add(amount);
        }

        subscription.providerSignature = sig;

        emit SubscriptionCreated(hash, providerAddress, token, amount);
    }

    /**
     * @notice Internal helper function to recover address from signature
     * @param _messageHash Message
     * @param _signature Message signature
     * @return address Address of signer
     */
    function _recoverSigner(bytes32 _messageHash, bytes memory _signature) internal pure returns (address) {
        // This recreates the message hash that was signed on the client.
        bytes32 ethMessageHash = _messageHash.toEthSignedMessageHash();

        return ethMessageHash.recover(_signature);
    }
}
