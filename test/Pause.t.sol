// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Base} from "./Base.t.sol";
import {TokenRewards} from "../src/TokenRewards.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/// @notice Tests for pausability: pause/unpause, access control, blocked operations, edge cases.
contract PauseTest is Base {
    /*//////////////////////////////////////////////////////////////
                        PAUSE / UNPAUSE STATE
    //////////////////////////////////////////////////////////////*/

    function test_Should_NotBePaused_AfterDeploy() public view {
        assertFalse(token.paused(), "Should not be paused initially");
    }

    function test_Should_BePaused_AfterAdminPauses() public {
        vm.prank(admin);
        token.pause();

        assertTrue(token.paused(), "Should be paused after admin pauses");
    }

    function test_Should_NotBePaused_AfterAdminUnpauses() public {
        vm.startPrank(admin);
        token.pause();
        token.unpause();
        vm.stopPrank();

        assertFalse(token.paused(), "Should not be paused after unpause");
    }

    /*//////////////////////////////////////////////////////////////
                          EVENT EMISSION
    //////////////////////////////////////////////////////////////*/

    function test_Should_EmitPausedEvent_WhenPaused() public {
        vm.prank(admin);

        vm.expectEmit(true, false, false, false, address(token));
        emit Pausable.Paused(admin);

        token.pause();
    }

    function test_Should_EmitUnpausedEvent_WhenUnpaused() public {
        vm.startPrank(admin);
        token.pause();

        vm.expectEmit(true, false, false, false, address(token));
        emit Pausable.Unpaused(admin);

        token.unpause();
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                         ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhen_UnauthorizedAddress_CallsPause() public {
        vm.prank(unauthorized);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                adminRole
            )
        );
        token.pause();
    }

    function test_RevertWhen_MinterRole_CallsPause() public {
        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                minter,
                adminRole
            )
        );
        token.pause();
    }

    function test_RevertWhen_DistributorRole_CallsPause() public {
        vm.prank(distributor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                distributor,
                adminRole
            )
        );
        token.pause();
    }

    function test_RevertWhen_UnauthorizedAddress_CallsUnpause() public {
        vm.prank(admin);
        token.pause();

        vm.prank(unauthorized);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                adminRole
            )
        );
        token.unpause();
    }

    /*//////////////////////////////////////////////////////////////
                    PAUSED BLOCKS OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhen_MintTokenA_WhilePaused() public {
        vm.prank(admin);
        token.pause();

        vm.prank(minter);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        token.mintTokenA(alice, 100);
    }

    function test_RevertWhen_DistributeTokenB_WhilePaused() public {
        // Setup: mint first, then pause
        vm.prank(minter);
        token.mintTokenA(alice, 100);

        vm.prank(admin);
        token.pause();

        vm.prank(distributor);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        token.distributeTokenB(1000);
    }

    function test_RevertWhen_SafeTransferFrom_WhilePaused() public {
        uint256 tokenA = token.TOKEN_A();

        vm.prank(minter);
        token.mintTokenA(alice, 100);

        vm.prank(admin);
        token.pause();

        vm.startPrank(alice);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        token.safeTransferFrom(alice, bob, tokenA, 50, "");
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    UNPAUSE RESTORES OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function test_Should_AllowMintTokenA_AfterUnpause() public {
        vm.startPrank(admin);
        token.pause();
        token.unpause();
        vm.stopPrank();

        vm.prank(minter);
        token.mintTokenA(alice, 100);

        assertEq(token.balanceOf(alice, token.TOKEN_A()), 100, "Mint should work after unpause");
    }

    function test_Should_AllowDistributeTokenB_AfterUnpause() public {
        vm.prank(minter);
        token.mintTokenA(alice, 100);

        vm.startPrank(admin);
        token.pause();
        token.unpause();
        vm.stopPrank();

        vm.prank(distributor);
        token.distributeTokenB(500);

        assertEq(token.balanceOf(alice, token.TOKEN_B()), 500, "Distribute should work after unpause");
    }

    function test_Should_AllowTransfer_AfterUnpause() public {
        uint256 tokenA = token.TOKEN_A();

        vm.prank(minter);
        token.mintTokenA(alice, 100);

        vm.startPrank(admin);
        token.pause();
        token.unpause();
        vm.stopPrank();

        vm.prank(alice);
        token.safeTransferFrom(alice, bob, tokenA, 50, "");

        assertEq(token.balanceOf(alice, tokenA), 50, "Alice should have 50 remaining");
        assertEq(token.balanceOf(bob, tokenA), 50, "Transfer should work after unpause");
    }

    /*//////////////////////////////////////////////////////////////
                          EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhen_PausingAlreadyPausedContract() public {
        vm.startPrank(admin);
        token.pause();

        vm.expectRevert(Pausable.EnforcedPause.selector);
        token.pause();
        vm.stopPrank();
    }

    function test_RevertWhen_UnpausingNotPausedContract() public {
        vm.prank(admin);
        vm.expectRevert(Pausable.ExpectedPause.selector);
        token.unpause();
    }
}
