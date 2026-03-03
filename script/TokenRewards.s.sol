// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {TokenRewards} from "../src/TokenRewards.sol";

contract CounterScript is Script {
    TokenRewards public tokenRewards;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        tokenRewards = new TokenRewards();

        vm.stopBroadcast();
    }
}
