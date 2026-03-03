// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TokenRewards} from "../src/TokenRewards.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract TokenRewardsTest is Test {
    TokenRewards public token;

    address public admin = makeAddr("admin");
    address public alice = makeAddr("alice");

    string constant URI = "https://example.com/metadata/{id}.json";

    function setUp() public {
        token = new TokenRewards(admin, URI);
    }

    // ===================== F1: Constructor + Constants + AccessControl =====================

    function test_Constants() public view {
        assertEq(token.TOKEN_A(), 0);
        assertEq(token.TOKEN_B(), 1);
    }

    function test_URI() public view {
        assertEq(token.uri(0), URI);
    }

    function test_AdminHasAllRoles() public view {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(token.hasRole(token.MINTER_ROLE(), admin));
        assertTrue(token.hasRole(token.DISTRIBUTOR_ROLE(), admin));
    }

    function test_NonAdminHasNoRoles() public view {
        assertFalse(token.hasRole(token.DEFAULT_ADMIN_ROLE(), alice));
        assertFalse(token.hasRole(token.MINTER_ROLE(), alice));
        assertFalse(token.hasRole(token.DISTRIBUTOR_ROLE(), alice));
    }

    function test_SupportsERC1155Interface() public view {
        assertTrue(token.supportsInterface(type(IERC1155).interfaceId));
    }

    function test_SupportsAccessControlInterface() public view {
        assertTrue(token.supportsInterface(type(IAccessControl).interfaceId));
    }

    function test_InitialSupplyIsZero() public view {
        assertEq(token.totalSupply(token.TOKEN_A()), 0);
        assertEq(token.totalSupply(token.TOKEN_B()), 0);
    }

    function test_AdminCanGrantRole() public {
        bytes32 minterRole = token.MINTER_ROLE();

        vm.prank(admin);
        token.grantRole(minterRole, alice);

        assertTrue(token.hasRole(minterRole, alice));
    }

    function test_NonAdminCannotGrantRole() public {
        bytes32 minterRole = token.MINTER_ROLE();
        bytes32 adminRole = token.DEFAULT_ADMIN_ROLE();

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                alice,
                adminRole
            )
        );
        token.grantRole(minterRole, alice);
    }

    function test_AdminCanRevokeRole() public {
        vm.startPrank(admin);
        token.grantRole(token.MINTER_ROLE(), alice);
        token.revokeRole(token.MINTER_ROLE(), alice);
        vm.stopPrank();

        assertFalse(token.hasRole(token.MINTER_ROLE(), alice));
    }
}
