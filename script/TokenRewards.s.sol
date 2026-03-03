// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {TokenRewards} from "../src/TokenRewards.sol";

contract TokenRewardsScript is Script {
    function run() public {
        address admin = vm.envAddress("ADMIN_ADDRESS");
        string memory tokenURI = vm.envString("TOKEN_URI");

        vm.startBroadcast();
        new TokenRewards(admin, tokenURI);
        vm.stopBroadcast();
    }
}
