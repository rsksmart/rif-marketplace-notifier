// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/cryptography/ECDSAUpgradeable.sol";

/// @title NotificationsManager
/// @author Nazar Duchak <nazar@iovlabs.org>
contract NotificationsManager is OwnableUpgradeable, PausableUpgradeable {

    using ECDSAUpgradeable for bytes32;
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
        address token;
        address consumer;
        bytes providerSignature;
        uint256 balance;
    }

    event ProviderRegistered(address provider, string url);
    event SubscriptionCreated(bytes32 hash, address provider, address token, uint256 amount);
    event FundsWithdrawn(bytes32 hash, uint256 amount, address token);
    event FundsRefund(bytes32 hash, uint256 amount, address token);
    event FundsDeposit(bytes32 hash, uint256 amount, address token);

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
    function registerProvider (
        string memory url
    ) public whenNotPaused {
        require(isWhitelistedProvider[msg.sender], 'NotificationsManager: provider is not whitelisted');
        require(bytes(url).length != 0, 'NotificationsManager: URL can not be empty');
        Provider storage provider = providerRegistry[msg.sender];
        provider.url = url;
        emit ProviderRegistered(msg.sender, url);
    }

    /**
     * @notice withdrawal funds for subscription
     * @dev Called by Provider
     * @param hash Hash of subscription SLA
     * @param token The token from which you want withdraw. By convention: address(0) is the native currency
     * @param amount The amount of tokens
     */
    function withdrawalFunds (
        bytes32 hash,
        address token,
        uint256 amount
    ) public whenNotPaused {
        require(amount > 0, "NotificationsManager: Nothing to withdraw");
        Provider storage provider = providerRegistry[msg.sender];
        require(bytes(provider.url).length != 0, "NotificationsManager: Provider is not registered");
        Subscription storage subscription = provider.subscriptions[hash];
        require(subscription.providerSignature.length != 0, "NotificationsManager: Subscription is not exist");
        require(token == subscription.token, "NotificationsManager: Invalid token for subscription");
        require(amount <= subscription.balance, "NotificationsManager: Amount is too big");

        if(token == address(0)) {
            (bool success,) = msg.sender.call{value: amount}("");
            require(success, "Transfer failed.");
        } else {
            require(IERC20(token).transfer(msg.sender, amount), "NotificationsManager: Token transfer failed");
        }
        subscription.balance = subscription.balance.sub(amount);
        emit FundsWithdrawn(hash, amount, token);
    }

    /**
     * @notice refund funds to consumer
     * @dev Called by Provider
     * @param hash Hash of subscription SLA
     * @param token The token from which you want refund. By convention: address(0) is the native currency
     * @param amount The amount of tokens
     */
    function refundFunds (
        bytes32 hash,
        address token,
        uint256 amount
    ) public whenNotPaused {
        require(amount > 0, "NotificationsManager: Nothing to refund");
        Provider storage provider = providerRegistry[msg.sender];
        require(bytes(provider.url).length != 0, "NotificationsManager: Provider is not registered");
        Subscription storage subscription = provider.subscriptions[hash];
        require(subscription.providerSignature.length != 0, "NotificationsManager: Subscription is not exist");
        require(token == subscription.token, "NotificationsManager: Invalid token for subscription");
        require(amount <= subscription.balance, "NotificationsManager: Amount is too big");

        if(token == address(0)) {
            (bool success,) = subscription.consumer.call{value: amount}("");
            require(success, "Transfer failed.");
        } else {
            require(IERC20(token).transfer(subscription.consumer, amount), "NotificationsManager: Token transfer failed");
        }
        subscription.balance = subscription.balance.sub(amount);
        emit FundsRefund(hash, amount, token);
    }

    /**
     * @notice new Subscription for given Provider
     * @dev Called by CONSUMER to register
     * @param providerAddress Address of provider
     * @param hash Hash of subscription SLA
     * @param sig Signature of provider
     * @param token The token in which you want to make the subscription. By convention: address(0) is the native currency
     * @param amount If token is set, this is the amount of tokens that is transferred
     */
    function createSubscription (
        address providerAddress,
        bytes32 hash,
        bytes memory sig,
        address token,
        uint256 amount
    ) public payable whenNotPaused {
        require(isWhitelistedProvider[providerAddress], "NotificationsManager: provider is not whitelisted");
        require(isWhitelistedToken[token], "NotificationsManager: not possible to interact with this token");
        require(amount > 0 && token != address(0) || token == address(0) && msg.value > 0, "NotificationsManager: You should deposit funds to be able to create subscription");
        Provider storage provider = providerRegistry[providerAddress];
        require(bytes(provider.url).length != 0, "NotificationsManager: Provider is not registered");
        Subscription storage subscription = provider.subscriptions[hash];
        require(subscription.consumer == address(0), "NotificationsManager: Subscription already exist");
        require(_recoverSigner(hash, sig) == providerAddress, 'NotificationsManager: Invalid signature');

        if(token == address(0)) {
            subscription.balance = subscription.balance.add(msg.value);
        } else {
            require(IERC20(token).transferFrom(msg.sender, address(this), amount), "NotificationsManager: not allowed to deposit tokens from token contract");
            subscription.balance = subscription.balance.add(amount);
        }

        subscription.providerSignature = sig;
        subscription.consumer = msg.sender;
        subscription.token = token;

        emit SubscriptionCreated(hash, providerAddress, token, amount);
    }

    /**
     * @notice deposit funds for subscription
     * @dev Called by CONSUMER
     * @param providerAddress Address of provider
     * @param hash Hash of subscription SLA
     * @param token The token from which you want deposit. By convention: address(0) is the native currency
     * @param amount The amount of tokens
     */
    function depositFunds (
        address providerAddress,
        bytes32 hash,
        address token,
        uint256 amount
    ) public payable whenNotPaused {
        require(isWhitelistedProvider[providerAddress], "NotificationsManager: provider is not whitelisted");
        require(isWhitelistedToken[token], "NotificationsManager: not possible to interact with this token");
        require(amount > 0 && token != address(0) || token == address(0) && msg.value > 0, "NotificationsManager: Nothing to deposit");
        Provider storage provider = providerRegistry[providerAddress];
        require(bytes(provider.url).length != 0, "NotificationsManager: Provider is not registered");
        Subscription storage subscription = provider.subscriptions[hash];
        require(subscription.providerSignature.length != 0, "NotificationsManager: Subscription is not exist");
        require(token == subscription.token, "NotificationsManager: Invalid token for subscription");

        if(token == address(0)) {
            subscription.balance = subscription.balance.add(msg.value);
        } else {
            require(IERC20(token).transferFrom(msg.sender, address(this), amount), "NotificationsManager: not allowed to deposit tokens from token contract");
            subscription.balance = subscription.balance.add(amount);
        }
        emit FundsDeposit(hash, amount, token);
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
