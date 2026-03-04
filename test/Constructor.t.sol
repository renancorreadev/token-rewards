// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Base} from "./Base.t.sol";
import {TokenRewards} from "../src/TokenRewards.sol";
import {ITokenRewards} from "../src/ITokenRewards.sol";
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
                            SET URI
    //////////////////////////////////////////////////////////////*/

    function test_Should_AllowAdmin_ToUpdateURI() public {
        string memory newURI = "https://new.example.com/metadata/{id}.json";

        vm.prank(admin);
        token.setURI(newURI);

        assertEq(token.uri(0), newURI, "URI for token 0 should be updated");
        assertEq(token.uri(1), newURI, "URI for token 1 should be updated");
    }

    function test_Should_EmitURIUpdated_OnSetURI() public {
        string memory newURI = "https://new.example.com/metadata/{id}.json";

        vm.prank(admin);

        vm.expectEmit(false, false, false, true, address(token));
        emit ITokenRewards.URIUpdated(newURI);

        token.setURI(newURI);
    }

    function test_RevertWhen_UnauthorizedAddress_CallsSetURI() public {
        vm.prank(unauthorized);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                adminRole
            )
        );
        token.setURI("https://malicious.com/{id}.json");
    }

    function test_RevertWhen_MinterRole_CallsSetURI() public {
        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                minter,
                adminRole
            )
        );
        token.setURI("https://malicious.com/{id}.json");
    }

    function test_RevertWhen_DistributorRole_CallsSetURI() public {
        vm.prank(distributor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                distributor,
                adminRole
            )
        );
        token.setURI("https://malicious.com/{id}.json");
    }

    function test_Should_AllowAdmin_ToSetEmptyURI() public {
        vm.prank(admin);
        token.setURI("");

        assertEq(token.uri(0), "", "URI for token 0 should be empty");
        assertEq(token.uri(1), "", "URI for token 1 should be empty");
    }

    function test_Should_AllowAdmin_ToUpdateURI_MultipleTimes() public {
        string memory firstURI = "https://first.example.com/{id}.json";
        string memory secondURI = "https://second.example.com/{id}.json";

        vm.startPrank(admin);
        token.setURI(firstURI);
        assertEq(token.uri(0), firstURI, "URI should match first update");

        token.setURI(secondURI);
        assertEq(token.uri(0), secondURI, "URI should match second update");
        vm.stopPrank();
    }

    function test_Should_AllowAdmin_ToSetURI_WhilePaused() public {
        vm.startPrank(admin);
        token.pause();
        token.setURI("https://paused.example.com/{id}.json");
        vm.stopPrank();

        assertEq(
            token.uri(0),
            "https://paused.example.com/{id}.json",
            "URI should be updated even while paused"
        );
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
