// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;
import "../NotifierManager.sol";

contract NotifierManagerV2 is NotifierManager {
    function getVersion() public pure returns (string memory) {
        return "V2";
    }
}
