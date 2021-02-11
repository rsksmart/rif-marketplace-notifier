// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;
import "../NotificationsManager.sol";

contract NotificationsManagerV2 is NotificationsManager {
    function getVersion() public pure returns (string memory) {
        return "V2";
    }
}
