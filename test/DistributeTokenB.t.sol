// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Base} from "./Base.t.sol";
import {TokenRewards} from "../src/TokenRewards.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @notice Tests for distributeTokenB: happy path, rounding, events, access control and input validation.
contract DistributeTokenBTest is Base {
    /*//////////////////////////////////////////////////////////////
                           HAPPY PATH
    //////////////////////////////////////////////////////////////*/

    function test_Should_DistributeProportionally_ToAllHolders() public {
        // Mint Token A: alice=30, bob=50, carol=20 → total=100
        vm.startPrank(minter);
        token.mintTokenA(alice, 30);
        token.mintTokenA(bob, 50);
        token.mintTokenA(carol, 20);
        vm.stopPrank();

        // Distribute 1000 Token B
        vm.prank(distributor);
        token.distributeTokenB(1000);

        // Expected: alice=300, bob=500, carol=200
        assertEq(
            token.balanceOf(alice, token.TOKEN_B()),
            300,
            "Alice should get 30% of 1000 = 300"
        );
        assertEq(
            token.balanceOf(bob, token.TOKEN_B()),
            500,
            "Bob should get 50% of 1000 = 500"
        );
        assertEq(
            token.balanceOf(carol, token.TOKEN_B()),
            200,
            "Carol should get 20% of 1000 = 200"
        );
    }

    function test_Should_GiveFullReward_ToSingleHolder() public {
        vm.prank(minter);
        token.mintTokenA(alice, 100);

        vm.prank(distributor);
        token.distributeTokenB(500);

        assertEq(
            token.balanceOf(alice, token.TOKEN_B()),
            500,
            "Single holder should get 100% of reward"
        );
    }

    function test_Should_HandleMultipleDistributions_Independently() public {
        vm.startPrank(minter);
        token.mintTokenA(alice, 50);
        token.mintTokenA(bob, 50);
        vm.stopPrank();

        // First distribution: 1000 Token B
        vm.startPrank(distributor);
        token.distributeTokenB(1000);

        // Second distribution: 2000 Token B
        token.distributeTokenB(2000);
        vm.stopPrank();

        // alice: 500 + 1000 = 1500, bob: 500 + 1000 = 1500
        assertEq(
            token.balanceOf(alice, token.TOKEN_B()),
            1500,
            "Alice should accumulate rewards from both distributions"
        );
        assertEq(
            token.balanceOf(bob, token.TOKEN_B()),
            1500,
            "Bob should accumulate rewards from both distributions"
        );
    }

    /*//////////////////////////////////////////////////////////////
                            ROUNDING
    //////////////////////////////////////////////////////////////*/

    function test_Should_FloorDivide_WhenNotEvenlyDivisible() public {
        // Mint Token A: alice=1, bob=1, carol=1 → total=3
        vm.startPrank(minter);
        token.mintTokenA(alice, 1);
        token.mintTokenA(bob, 1);
        token.mintTokenA(carol, 1);
        vm.stopPrank();

        // Distribute 10 Token B → 10/3 = 3 each (floor), 1 dust not minted
        vm.prank(distributor);
        token.distributeTokenB(10);

        uint256 aliceReward = token.balanceOf(alice, token.TOKEN_B());
        uint256 bobReward = token.balanceOf(bob, token.TOKEN_B());
        uint256 carolReward = token.balanceOf(carol, token.TOKEN_B());

        assertEq(aliceReward, 3, "Alice should get floor(10/3) = 3");
        assertEq(bobReward, 3, "Bob should get floor(10/3) = 3");
        assertEq(carolReward, 3, "Carol should get floor(10/3) = 3");

        // Total minted (9) < totalAmount (10) — dust is not minted
        uint256 totalMinted = aliceReward + bobReward + carolReward;
        assertLt(
            totalMinted,
            10,
            "Total minted should be less than totalAmount due to floor division"
        );
        assertEq(totalMinted, 9, "Total minted should be 9 (1 dust not minted)");
    }

    /*//////////////////////////////////////////////////////////////
                          EVENT EMISSION
    //////////////////////////////////////////////////////////////*/

    function test_Should_EmitTokenBDistributed_OnDistribution() public {
        vm.startPrank(minter);
        token.mintTokenA(alice, 50);
        token.mintTokenA(bob, 50);
        vm.stopPrank();

        vm.prank(distributor);

        vm.expectEmit(false, false, false, true, address(token));
        emit TokenRewards.TokenBDistributed(1000, 1000, 2);

        token.distributeTokenB(1000);
    }

    function test_Should_EmitTotalMinted_LessThanTotalAmount_WhenDustExists()
        public
    {
        // alice=1, bob=1, carol=1 → total=3, distribute 10 → 3 each = 9 minted
        vm.startPrank(minter);
        token.mintTokenA(alice, 1);
        token.mintTokenA(bob, 1);
        token.mintTokenA(carol, 1);
        vm.stopPrank();

        vm.prank(distributor);

        vm.expectEmit(false, false, false, true, address(token));
        emit TokenRewards.TokenBDistributed(10, 9, 3);

        token.distributeTokenB(10);
    }

    function test_Should_EmitTotalMinted_EqualTotalAmount_WhenNoDust() public {
        // alice=50, bob=50 → total=100, distribute 1000 → 500 each = 1000 minted
        vm.startPrank(minter);
        token.mintTokenA(alice, 50);
        token.mintTokenA(bob, 50);
        vm.stopPrank();

        vm.prank(distributor);

        vm.expectEmit(false, false, false, true, address(token));
        emit TokenRewards.TokenBDistributed(1000, 1000, 2);

        token.distributeTokenB(1000);
    }

    function test_Should_EmitTotalMinted_EqualTotalAmount_ForSingleHolder()
        public
    {
        vm.prank(minter);
        token.mintTokenA(alice, 100);

        vm.prank(distributor);

        vm.expectEmit(false, false, false, true, address(token));
        emit TokenRewards.TokenBDistributed(500, 500, 1);

        token.distributeTokenB(500);
    }

    function test_Should_EmitCorrectTotalMinted_WithUnequalShares() public {
        // alice=30, bob=50, carol=20 → total=100, distribute 1000
        // alice=300, bob=500, carol=200 → totalMinted=1000
        vm.startPrank(minter);
        token.mintTokenA(alice, 30);
        token.mintTokenA(bob, 50);
        token.mintTokenA(carol, 20);
        vm.stopPrank();

        vm.prank(distributor);

        vm.expectEmit(false, false, false, true, address(token));
        emit TokenRewards.TokenBDistributed(1000, 1000, 3);

        token.distributeTokenB(1000);
    }

    function test_Should_EmitTotalMinted_WithMaxDust() public {
        // 3 holders with equal share, distribute 2 → floor(2*1/3)=0 each → totalMinted=0
        // But reward=0 is skipped, so totalMinted=0
        // Actually: distribute 5 → floor(5*1/3)=1 each → totalMinted=3, dust=2
        vm.startPrank(minter);
        token.mintTokenA(alice, 1);
        token.mintTokenA(bob, 1);
        token.mintTokenA(carol, 1);
        vm.stopPrank();

        vm.prank(distributor);

        vm.expectEmit(false, false, false, true, address(token));
        emit TokenRewards.TokenBDistributed(5, 3, 3);

        token.distributeTokenB(5);
    }

    /*//////////////////////////////////////////////////////////////
                         ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhen_UnauthorizedAddress_CallsDistributeTokenB() public {
        vm.prank(minter);
        token.mintTokenA(alice, 100);

        vm.prank(unauthorized);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                distributorRole
            )
        );
        token.distributeTokenB(1000);
    }

    function test_RevertWhen_MinterRole_CallsDistributeTokenB() public {
        vm.prank(minter);
        token.mintTokenA(alice, 100);

        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                minter,
                distributorRole
            )
        );
        token.distributeTokenB(1000);
    }

    function test_Should_AllowAdmin_ToDistribute_WhenAdminHasDistributorRole()
        public
    {
        vm.prank(minter);
        token.mintTokenA(alice, 100);

        vm.prank(admin);
        token.distributeTokenB(500);

        assertEq(
            token.balanceOf(alice, token.TOKEN_B()),
            500,
            "Admin with distributor role should be able to distribute"
        );
    }

    /*//////////////////////////////////////////////////////////////
                        INPUT VALIDATION
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhen_DistributionAmount_IsZero() public {
        vm.prank(minter);
        token.mintTokenA(alice, 100);

        vm.prank(distributor);
        vm.expectRevert(TokenRewards.ZeroDistributionAmount.selector);
        token.distributeTokenB(0);
    }

    function test_RevertWhen_NoHolders_Exist() public {
        vm.prank(distributor);
        vm.expectRevert(TokenRewards.NoHolders.selector);
        token.distributeTokenB(1000);
    }
}
