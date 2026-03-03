// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Base} from "./Base.t.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/// @notice Tests for deploy, constants, role assignment and interface support.
contract ConstructorTest is Base {
    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    function test_Should_SetTokenAIdToZero() public view {
        assertEq(token.TOKEN_A(), 0, "TOKEN_A should be 0");
    }

    function test_Should_SetTokenBIdToOne() public view {
        assertEq(token.TOKEN_B(), 1, "TOKEN_B should be 1");
    }

    function test_Should_SetURIForAllTokenIds() public view {
        assertEq(token.uri(0), URI, "URI for token 0 should match");
        assertEq(token.uri(1), URI, "URI for token 1 should match");
    }

    /*//////////////////////////////////////////////////////////////
                            INITIAL STATE
    //////////////////////////////////////////////////////////////*/

    function test_Should_HaveZeroSupplyForTokenA_AfterDeploy() public view {
        assertEq(token.totalSupply(token.TOKEN_A()), 0, "Token A supply should start at 0");
    }

    function test_Should_HaveZeroSupplyForTokenB_AfterDeploy() public view {
        assertEq(token.totalSupply(token.TOKEN_B()), 0, "Token B supply should start at 0");
    }

    /*//////////////////////////////////////////////////////////////
                      ROLE ASSIGNMENT ON DEPLOY
    //////////////////////////////////////////////////////////////*/

    function test_Should_GrantAdminRole_ToDeployerSpecifiedAddress() public view {
        assertTrue(token.hasRole(adminRole, admin), "Admin should have DEFAULT_ADMIN_ROLE");
    }

    function test_Should_GrantMinterRole_ToAdminOnDeploy() public view {
        assertTrue(token.hasRole(minterRole, admin), "Admin should have MINTER_ROLE");
    }

    function test_Should_GrantDistributorRole_ToAdminOnDeploy() public view {
        assertTrue(token.hasRole(distributorRole, admin), "Admin should have DISTRIBUTOR_ROLE");
    }

    function test_Should_IsolateMinterRole_FromOtherPrivileges() public view {
        assertTrue(token.hasRole(minterRole, minter), "Minter should have MINTER_ROLE");
        assertFalse(token.hasRole(distributorRole, minter), "Minter should NOT have DISTRIBUTOR_ROLE");
        assertFalse(token.hasRole(adminRole, minter), "Minter should NOT have DEFAULT_ADMIN_ROLE");
    }

    function test_Should_IsolateDistributorRole_FromOtherPrivileges() public view {
        assertTrue(token.hasRole(distributorRole, distributor), "Distributor should have DISTRIBUTOR_ROLE");
        assertFalse(token.hasRole(minterRole, distributor), "Distributor should NOT have MINTER_ROLE");
        assertFalse(token.hasRole(adminRole, distributor), "Distributor should NOT have DEFAULT_ADMIN_ROLE");
    }

    function test_Should_NotAssignAnyRole_ToUnauthorizedAddress() public view {
        assertFalse(token.hasRole(adminRole, unauthorized), "Unauthorized should NOT have admin");
        assertFalse(token.hasRole(minterRole, unauthorized), "Unauthorized should NOT have minter");
        assertFalse(token.hasRole(distributorRole, unauthorized), "Unauthorized should NOT have distributor");
    }

    /*//////////////////////////////////////////////////////////////
                          ROLE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function test_Should_AllowAdmin_ToGrantMinterRole() public {
        vm.prank(admin);
        token.grantRole(minterRole, alice);

        assertTrue(token.hasRole(minterRole, alice), "Alice should have MINTER_ROLE after grant");
    }

    function test_Should_AllowAdmin_ToRevokeGrantedRole() public {
        // Arrange: grant role first
        vm.startPrank(admin);
        token.grantRole(minterRole, alice);

        // Act: revoke it
        token.revokeRole(minterRole, alice);
        vm.stopPrank();

        // Assert: role should be removed
        assertFalse(token.hasRole(minterRole, alice), "Alice should NOT have MINTER_ROLE after revoke");
    }

    function test_RevertWhen_UnauthorizedAddress_TriesToGrantRole() public {
        vm.prank(unauthorized);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                adminRole
            )
        );
        token.grantRole(minterRole, unauthorized);
    }

    function test_RevertWhen_MinterAddress_TriesToGrantRole() public {
        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                minter,
                adminRole
            )
        );
        token.grantRole(minterRole, alice);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERFACE SUPPORT
    //////////////////////////////////////////////////////////////*/

    function test_Should_SupportERC1155Interface() public view {
        assertTrue(
            token.supportsInterface(type(IERC1155).interfaceId),
            "Should support IERC1155"
        );
    }

    function test_Should_SupportAccessControlInterface() public view {
        assertTrue(
            token.supportsInterface(type(IAccessControl).interfaceId),
            "Should support IAccessControl"
        );
    }

    function test_Should_ReturnFalse_ForUnsupportedInterface() public view {
        assertFalse(
            token.supportsInterface(0xdeadbeef),
            "Should NOT support arbitrary interface"
        );
    }
}
