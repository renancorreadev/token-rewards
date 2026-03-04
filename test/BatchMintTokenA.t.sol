// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Base} from "./Base.t.sol";
import {TokenRewards} from "../src/TokenRewards.sol";
import {ITokenRewards} from "../src/ITokenRewards.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/// @notice Tests for batchMintTokenA: happy path, holder tracking, events, access control, validation, paused.
contract BatchMintTokenATest is Base {
    uint256 internal tokenA;

    function setUp() public override {
        super.setUp();
        tokenA = token.TOKEN_A();
    }

    /*//////////////////////////////////////////////////////////////
                           HAPPY PATH
    //////////////////////////////////////////////////////////////*/

    function test_Should_BatchMint_ToMultipleRecipients() public {
        address[] memory recipients = new address[](3);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = carol;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100;
        amounts[1] = 200;
        amounts[2] = 300;

        vm.prank(minter);
        token.batchMintTokenA(recipients, amounts);

        assertEq(token.balanceOf(alice, tokenA), 100, "Alice should have 100");
        assertEq(token.balanceOf(bob, tokenA), 200, "Bob should have 200");
        assertEq(token.balanceOf(carol, tokenA), 300, "Carol should have 300");
        assertEq(token.totalSupply(tokenA), 600, "Total supply should be 600");
    }

    function test_Should_BatchMint_ToSingleRecipient() public {
        address[] memory recipients = new address[](1);
        recipients[0] = alice;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 500;

        vm.prank(minter);
        token.batchMintTokenA(recipients, amounts);

        assertEq(token.balanceOf(alice, tokenA), 500, "Alice should have 500");
    }

    function test_Should_AccumulateBalance_WhenSameRecipientRepeated() public {
        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = alice;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;

        vm.prank(minter);
        token.batchMintTokenA(recipients, amounts);

        assertEq(token.balanceOf(alice, tokenA), 300, "Alice should have 300 accumulated");
    }

    /*//////////////////////////////////////////////////////////////
                        HOLDER TRACKING
    //////////////////////////////////////////////////////////////*/

    function test_Should_AddAllRecipients_AsHolders() public {
        address[] memory recipients = new address[](3);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = carol;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100;
        amounts[1] = 200;
        amounts[2] = 300;

        vm.prank(minter);
        token.batchMintTokenA(recipients, amounts);

        assertTrue(token.isTokenAHolder(alice), "Alice should be holder");
        assertTrue(token.isTokenAHolder(bob), "Bob should be holder");
        assertTrue(token.isTokenAHolder(carol), "Carol should be holder");
        assertEq(token.getHoldersCount(), 3, "Should have 3 holders");
    }

    function test_Should_NotDuplicateHolder_WhenSameRecipientRepeated() public {
        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = alice;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;

        vm.prank(minter);
        token.batchMintTokenA(recipients, amounts);

        assertEq(token.getHoldersCount(), 1, "Should have 1 holder, no duplication");
        assertTrue(token.isTokenAHolder(alice), "Alice should be holder");
    }

    /*//////////////////////////////////////////////////////////////
                          EVENT EMISSION
    //////////////////////////////////////////////////////////////*/

    function test_Should_EmitTokenAMinted_ForEachRecipient() public {
        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = bob;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;

        vm.prank(minter);

        vm.expectEmit(true, false, false, true, address(token));
        emit ITokenRewards.TokenAMinted(alice, 100);

        vm.expectEmit(true, false, false, true, address(token));
        emit ITokenRewards.TokenAMinted(bob, 200);

        token.batchMintTokenA(recipients, amounts);
    }

    /*//////////////////////////////////////////////////////////////
                         ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhen_UnauthorizedAddress_CallsBatchMint() public {
        address[] memory recipients = new address[](1);
        recipients[0] = alice;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;

        vm.prank(unauthorized);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                minterRole
            )
        );
        token.batchMintTokenA(recipients, amounts);
    }

    function test_Should_AllowMinterRole_ToBatchMint() public {
        address[] memory recipients = new address[](1);
        recipients[0] = alice;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;

        vm.prank(minter);
        token.batchMintTokenA(recipients, amounts);

        assertEq(token.balanceOf(alice, tokenA), 100, "Minter should be able to batch mint");
    }

    /*//////////////////////////////////////////////////////////////
                          VALIDATION
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhen_ArrayLengthsMismatch() public {
        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = bob;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;

        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(ITokenRewards.BatchLengthMismatch.selector, 2, 1)
        );
        token.batchMintTokenA(recipients, amounts);
    }

    function test_RevertWhen_ArraysAreEmpty() public {
        address[] memory recipients = new address[](0);
        uint256[] memory amounts = new uint256[](0);

        vm.prank(minter);
        vm.expectRevert(ITokenRewards.BatchEmpty.selector);
        token.batchMintTokenA(recipients, amounts);
    }

    function test_RevertWhen_RecipientIsZeroAddress() public {
        address[] memory recipients = new address[](1);
        recipients[0] = address(0);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;

        vm.prank(minter);
        vm.expectRevert(ITokenRewards.MintToZeroAddress.selector);
        token.batchMintTokenA(recipients, amounts);
    }

    function test_RevertWhen_AmountIsZero() public {
        address[] memory recipients = new address[](1);
        recipients[0] = alice;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;

        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(ITokenRewards.MintAmountZero.selector, alice)
        );
        token.batchMintTokenA(recipients, amounts);
    }

    /*//////////////////////////////////////////////////////////////
                           PAUSED
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhen_BatchMint_WhilePaused() public {
        address[] memory recipients = new address[](1);
        recipients[0] = alice;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;

        vm.prank(admin);
        token.pause();

        vm.prank(minter);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        token.batchMintTokenA(recipients, amounts);
    }
}
