// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {TokenRewards} from "../src/TokenRewards.sol";

contract TokenRewardsScript is Script {
    function run() public {
        vm.startBroadcast();
        new TokenRewards(msg.sender, "");
        vm.stopBroadcast();
    }
}
