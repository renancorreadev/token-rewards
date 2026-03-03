// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TokenRewards} from "../src/TokenRewards.sol";

/// @dev Shared test base with common setUp, actors and cached roles.
abstract contract Base is Test {
    TokenRewards internal token;

    address internal admin = makeAddr("admin");
    address internal minter = makeAddr("minter");
    address internal distributor = makeAddr("distributor");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");
    address internal unauthorized = makeAddr("unauthorized");

    string internal constant URI = "https://example.com/metadata/{id}.json";

    bytes32 internal minterRole;
    bytes32 internal distributorRole;
    bytes32 internal adminRole;

    function setUp() public virtual {
        token = new TokenRewards(admin, URI);

        minterRole = token.MINTER_ROLE();
        distributorRole = token.DISTRIBUTOR_ROLE();
        adminRole = token.DEFAULT_ADMIN_ROLE();

        // Grant dedicated roles to separate actors (least privilege)
        vm.startPrank(admin);
        token.grantRole(minterRole, minter);
        token.grantRole(distributorRole, distributor);
        vm.stopPrank();
    }
}
