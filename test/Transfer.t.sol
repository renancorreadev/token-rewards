// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Base} from "./Base.t.sol";
import {IERC1155Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/// @notice Tests for safeTransferFrom: balances, holder tracking, approval, validation, paused.
contract TransferTest is Base {
    uint256 internal tokenA;
    uint256 internal tokenB;

    function setUp() public override {
        super.setUp();
        tokenA = token.TOKEN_A();
        tokenB = token.TOKEN_B();
    }

    /*//////////////////////////////////////////////////////////////
                        TOKEN A TRANSFER
    //////////////////////////////////////////////////////////////*/

    function test_Should_TransferPartialTokenA_BetweenAccounts() public {
        vm.prank(minter);
        token.mintTokenA(alice, 100);

        vm.prank(alice);
        token.safeTransferFrom(alice, bob, tokenA, 40, "");

        assertEq(token.balanceOf(alice, tokenA), 60, "Alice should have 60 remaining");
        assertEq(token.balanceOf(bob, tokenA), 40, "Bob should have 40");
    }

    function test_Should_TransferTotalTokenA_BetweenAccounts() public {
        vm.prank(minter);
        token.mintTokenA(alice, 100);

        vm.prank(alice);
        token.safeTransferFrom(alice, bob, tokenA, 100, "");

        assertEq(token.balanceOf(alice, tokenA), 0, "Alice should have 0");
        assertEq(token.balanceOf(bob, tokenA), 100, "Bob should have 100");
    }

    /*//////////////////////////////////////////////////////////////
                        TOKEN B TRANSFER
    //////////////////////////////////////////////////////////////*/

    function test_Should_TransferTokenB_BetweenAccounts() public {
        vm.prank(minter);
        token.mintTokenA(alice, 100);

        vm.prank(distributor);
        token.distributeTokenB(500);

        vm.prank(alice);
        token.safeTransferFrom(alice, bob, tokenB, 200, "");

        assertEq(token.balanceOf(alice, tokenB), 300, "Alice should have 300 Token B remaining");
        assertEq(token.balanceOf(bob, tokenB), 200, "Bob should have 200 Token B");
    }

    /*//////////////////////////////////////////////////////////////
                        HOLDER TRACKING
    //////////////////////////////////////////////////////////////*/

    function test_Should_AddReceiver_AsHolder_AfterTransfer() public {
        vm.prank(minter);
        token.mintTokenA(alice, 100);

        assertFalse(token.isTokenAHolder(bob), "Bob should not be holder before transfer");

        vm.prank(alice);
        token.safeTransferFrom(alice, bob, tokenA, 50, "");

        assertTrue(token.isTokenAHolder(bob), "Bob should be holder after receiving Token A");
    }

    function test_Should_RemoveSender_AsHolder_WhenBalanceReachesZero() public {
        vm.prank(minter);
        token.mintTokenA(alice, 100);

        vm.prank(alice);
        token.safeTransferFrom(alice, bob, tokenA, 100, "");

        assertFalse(token.isTokenAHolder(alice), "Alice should not be holder after transferring all");
        assertTrue(token.isTokenAHolder(bob), "Bob should be holder");
        assertEq(token.getHoldersCount(), 1, "Should have exactly 1 holder");
    }

    function test_Should_KeepSender_AsHolder_AfterPartialTransfer() public {
        vm.prank(minter);
        token.mintTokenA(alice, 100);

        vm.prank(alice);
        token.safeTransferFrom(alice, bob, tokenA, 50, "");

        assertTrue(token.isTokenAHolder(alice), "Alice should still be holder after partial transfer");
        assertTrue(token.isTokenAHolder(bob), "Bob should be holder");
        assertEq(token.getHoldersCount(), 2, "Should have 2 holders");
    }

    function test_Should_UpdateHoldersCount_AfterMultipleTransfers() public {
        vm.startPrank(minter);
        token.mintTokenA(alice, 100);
        token.mintTokenA(bob, 100);
        vm.stopPrank();

        assertEq(token.getHoldersCount(), 2, "Should start with 2 holders");

        // Alice transfers all to carol
        vm.prank(alice);
        token.safeTransferFrom(alice, carol, tokenA, 100, "");

        assertEq(token.getHoldersCount(), 2, "Should still have 2 holders (alice removed, carol added)");
        assertFalse(token.isTokenAHolder(alice), "Alice removed");
        assertTrue(token.isTokenAHolder(carol), "Carol added");
    }

    function test_Should_NotDuplicateHolder_WhenTransferringToExistingHolder() public {
        vm.startPrank(minter);
        token.mintTokenA(alice, 100);
        token.mintTokenA(bob, 100);
        vm.stopPrank();

        // Alice transfers to bob (already a holder)
        vm.prank(alice);
        token.safeTransferFrom(alice, bob, tokenA, 100, "");

        assertEq(token.getHoldersCount(), 1, "Should have 1 holder (no duplication)");
        assertTrue(token.isTokenAHolder(bob), "Bob should be holder");
        assertFalse(token.isTokenAHolder(alice), "Alice should not be holder");
    }

    /*//////////////////////////////////////////////////////////////
                          APPROVAL
    //////////////////////////////////////////////////////////////*/

    function test_Should_AllowApprovedOperator_ToTransfer() public {
        vm.prank(minter);
        token.mintTokenA(alice, 100);

        vm.prank(alice);
        token.setApprovalForAll(bob, true);

        vm.prank(bob);
        token.safeTransferFrom(alice, carol, tokenA, 50, "");

        assertEq(token.balanceOf(alice, tokenA), 50, "Alice should have 50 remaining");
        assertEq(token.balanceOf(carol, tokenA), 50, "Carol should have 50");
    }

    function test_RevertWhen_UnapprovedOperator_TriesToTransfer() public {
        vm.prank(minter);
        token.mintTokenA(alice, 100);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC1155Errors.ERC1155MissingApprovalForAll.selector,
                bob,
                alice
            )
        );
        token.safeTransferFrom(alice, carol, tokenA, 50, "");
    }

    /*//////////////////////////////////////////////////////////////
                          VALIDATION
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhen_TransferExceedsBalance() public {
        vm.prank(minter);
        token.mintTokenA(alice, 100);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC1155Errors.ERC1155InsufficientBalance.selector,
                alice,
                100,
                200,
                tokenA
            )
        );
        token.safeTransferFrom(alice, bob, tokenA, 200, "");
    }

    function test_RevertWhen_TransferToZeroAddress() public {
        vm.prank(minter);
        token.mintTokenA(alice, 100);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC1155Errors.ERC1155InvalidReceiver.selector,
                address(0)
            )
        );
        token.safeTransferFrom(alice, address(0), tokenA, 50, "");
    }

    /*//////////////////////////////////////////////////////////////
                           PAUSED
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhen_Transfer_WhilePaused() public {
        vm.prank(minter);
        token.mintTokenA(alice, 100);

        vm.prank(admin);
        token.pause();

        vm.prank(alice);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        token.safeTransferFrom(alice, bob, tokenA, 50, "");
    }
}
