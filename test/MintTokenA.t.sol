// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Base} from "./Base.t.sol";
import {TokenRewards} from "../src/TokenRewards.sol";
import {ITokenRewards} from "../src/ITokenRewards.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

/// @notice Tests for mintTokenA: happy path, events, access control and input validation.
contract MintTokenATest is Base {
    /*//////////////////////////////////////////////////////////////
                           HAPPY PATH
    //////////////////////////////////////////////////////////////*/

    function test_Should_MintTokenA_ToRecipient() public {
        vm.prank(minter);
        token.mintTokenA(alice, 100);

        assertEq(
            token.balanceOf(alice, token.TOKEN_A()),
            100,
            "Alice should have 100 Token A"
        );
    }

    function test_Should_IncreaseTotalSupply_AfterMint() public {
        vm.prank(minter);
        token.mintTokenA(alice, 50);

        assertEq(
            token.totalSupply(token.TOKEN_A()),
            50,
            "Total supply should be 50"
        );
    }

    function test_Should_AccumulateBalance_OnMultipleMints() public {
        vm.startPrank(minter);
        token.mintTokenA(alice, 100);
        token.mintTokenA(alice, 200);
        vm.stopPrank();

        assertEq(
            token.balanceOf(alice, token.TOKEN_A()),
            300,
            "Alice should have 300 after two mints"
        );
        assertEq(
            token.totalSupply(token.TOKEN_A()),
            300,
            "Total supply should be 300"
        );
    }

    function test_Should_MintToMultipleRecipients_Independently() public {
        vm.startPrank(minter);
        token.mintTokenA(alice, 100);
        token.mintTokenA(bob, 200);
        vm.stopPrank();

        assertEq(
            token.balanceOf(alice, token.TOKEN_A()),
            100,
            "Alice should have 100"
        );
        assertEq(
            token.balanceOf(bob, token.TOKEN_A()),
            200,
            "Bob should have 200"
        );
        assertEq(
            token.totalSupply(token.TOKEN_A()),
            300,
            "Total supply should be 300"
        );
    }

    /*//////////////////////////////////////////////////////////////
                          EVENT EMISSION
    //////////////////////////////////////////////////////////////*/

    function test_Should_EmitTokenAMinted_OnMint() public {
        vm.prank(minter);

        vm.expectEmit(true, false, false, true, address(token));
        emit ITokenRewards.TokenAMinted(alice, 100);

        token.mintTokenA(alice, 100);
    }

    /*//////////////////////////////////////////////////////////////
                         ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    function test_Should_AllowMinterRole_ToMint() public {
        vm.prank(minter);
        token.mintTokenA(alice, 100);

        assertEq(
            token.balanceOf(alice, token.TOKEN_A()),
            100,
            "Minter should be able to mint"
        );
    }

    function test_Should_AllowAdmin_ToMint_WhenAdminHasMinterRole() public {
        vm.prank(admin);
        token.mintTokenA(alice, 100);

        assertEq(
            token.balanceOf(alice, token.TOKEN_A()),
            100,
            "Admin with minter role should mint"
        );
    }

    function test_RevertWhen_UnauthorizedAddress_CallsMintTokenA() public {
        vm.prank(unauthorized);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                minterRole
            )
        );
        token.mintTokenA(alice, 100);
    }

    function test_RevertWhen_Distributor_CallsMintTokenA() public {
        vm.prank(distributor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                distributor,
                minterRole
            )
        );
        token.mintTokenA(alice, 100);
    }

    /*//////////////////////////////////////////////////////////////
                        INPUT VALIDATION
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhen_MintAmount_IsZero() public {
        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(ITokenRewards.MintAmountZero.selector, alice)
        );
        token.mintTokenA(alice, 0);
    }

    function test_RevertWhen_MintTo_ZeroAddress() public {
        vm.prank(minter);
        vm.expectRevert(ITokenRewards.MintToZeroAddress.selector);
        token.mintTokenA(address(0), 100);
    }

    /*//////////////////////////////////////////////////////////////
                        HOLDER TRACKING
    //////////////////////////////////////////////////////////////*/

    function test_Should_AddRecipient_AsHolder_AfterMint() public {
        vm.prank(minter);
        token.mintTokenA(alice, 100);

        assertTrue(
            token.isTokenAHolder(alice),
            "Alice should be a holder after mint"
        );
        assertEq(
            token.getHoldersCount(),
            1,
            "Should have exactly 1 holder"
        );
    }

    function test_Should_ReturnCorrectHoldersList_AfterMultipleMints() public {
        vm.startPrank(minter);
        token.mintTokenA(alice, 100);
        token.mintTokenA(bob, 200);
        token.mintTokenA(carol, 300);
        vm.stopPrank();

        address[] memory holders = token.getHolders();
        assertEq(holders.length, 3, "Should have 3 holders");
        assertEq(holders[0], alice, "First holder should be alice");
        assertEq(holders[1], bob, "Second holder should be bob");
        assertEq(holders[2], carol, "Third holder should be carol");
    }

    function test_Should_NotDuplicate_Holder_OnMultipleMints() public {
        vm.startPrank(minter);
        token.mintTokenA(alice, 100);
        token.mintTokenA(alice, 200);
        vm.stopPrank();

        assertEq(
            token.getHoldersCount(),
            1,
            "Should still have 1 holder after multiple mints to same address"
        );
        assertTrue(
            token.isTokenAHolder(alice),
            "Alice should be a holder"
        );
    }

    function test_Should_HaveZeroHolders_Initially() public view {
        assertEq(
            token.getHoldersCount(),
            0,
            "Should have zero holders initially"
        );

        address[] memory holders = token.getHolders();
        assertEq(holders.length, 0, "Holders array should be empty");
    }
}
