// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Base} from "./Base.t.sol";
import {TokenRewards} from "../src/TokenRewards.sol";
import {IERC1155Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/// @notice Tests for burn and burnBatch: happy path, holder tracking, operator, validation, paused.
contract BurnTest is Base {
    uint256 internal tokenA;
    uint256 internal tokenB;

    function setUp() public override {
        super.setUp();
        tokenA = token.TOKEN_A();
        tokenB = token.TOKEN_B();
    }

    /*//////////////////////////////////////////////////////////////
                           HAPPY PATH
    //////////////////////////////////////////////////////////////*/

    function test_Should_BurnPartialTokenA() public {
        vm.prank(minter);
        token.mintTokenA(alice, 100);

        vm.prank(alice);
        token.burn(alice, tokenA, 40);

        assertEq(token.balanceOf(alice, tokenA), 60, "Alice should have 60 after burning 40");
        assertEq(token.totalSupply(tokenA), 60, "Total supply should decrease to 60");
    }

    function test_Should_BurnTotalTokenA() public {
        vm.prank(minter);
        token.mintTokenA(alice, 100);

        vm.prank(alice);
        token.burn(alice, tokenA, 100);

        assertEq(token.balanceOf(alice, tokenA), 0, "Alice should have 0 after full burn");
        assertEq(token.totalSupply(tokenA), 0, "Total supply should be 0");
    }

    function test_Should_BurnTokenB() public {
        // Setup: mint Token A then distribute Token B
        vm.prank(minter);
        token.mintTokenA(alice, 100);

        vm.prank(distributor);
        token.distributeTokenB(500);

        vm.prank(alice);
        token.burn(alice, tokenB, 200);

        assertEq(token.balanceOf(alice, tokenB), 300, "Alice should have 300 Token B remaining");
    }

    function test_Should_BurnBatch_TokenAAndTokenB() public {
        vm.prank(minter);
        token.mintTokenA(alice, 100);

        vm.prank(distributor);
        token.distributeTokenB(500);

        uint256[] memory ids = new uint256[](2);
        ids[0] = tokenA;
        ids[1] = tokenB;

        uint256[] memory values = new uint256[](2);
        values[0] = 50;
        values[1] = 200;

        vm.prank(alice);
        token.burnBatch(alice, ids, values);

        assertEq(token.balanceOf(alice, tokenA), 50, "Alice should have 50 Token A remaining");
        assertEq(token.balanceOf(alice, tokenB), 300, "Alice should have 300 Token B remaining");
    }

    /*//////////////////////////////////////////////////////////////
                        HOLDER TRACKING
    //////////////////////////////////////////////////////////////*/

    function test_Should_RemoveHolder_AfterBurningAllTokenA() public {
        vm.prank(minter);
        token.mintTokenA(alice, 100);

        assertTrue(token.isTokenAHolder(alice), "Alice should be holder before burn");

        vm.prank(alice);
        token.burn(alice, tokenA, 100);

        assertFalse(token.isTokenAHolder(alice), "Alice should NOT be holder after full burn");
        assertEq(token.getHoldersCount(), 0, "Holders count should be 0");
    }

    function test_Should_KeepHolder_AfterPartialBurnTokenA() public {
        vm.prank(minter);
        token.mintTokenA(alice, 100);

        vm.prank(alice);
        token.burn(alice, tokenA, 50);

        assertTrue(token.isTokenAHolder(alice), "Alice should still be holder after partial burn");
        assertEq(token.getHoldersCount(), 1, "Holders count should still be 1");
    }

    function test_Should_NotAffectHolderStatus_WhenBurningTokenB() public {
        vm.prank(minter);
        token.mintTokenA(alice, 100);

        vm.prank(distributor);
        token.distributeTokenB(500);

        vm.prank(alice);
        token.burn(alice, tokenB, 500);

        assertTrue(token.isTokenAHolder(alice), "Alice should still be Token A holder after burning all Token B");
    }

    /*//////////////////////////////////////////////////////////////
                          OPERATOR
    //////////////////////////////////////////////////////////////*/

    function test_Should_AllowApprovedOperator_ToBurn() public {
        vm.prank(minter);
        token.mintTokenA(alice, 100);

        vm.prank(alice);
        token.setApprovalForAll(bob, true);

        vm.prank(bob);
        token.burn(alice, tokenA, 50);

        assertEq(token.balanceOf(alice, tokenA), 50, "Operator should be able to burn");
    }

    function test_RevertWhen_UnapprovedOperator_TriesToBurn() public {
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
        token.burn(alice, tokenA, 50);
    }

    /*//////////////////////////////////////////////////////////////
                          VALIDATION
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhen_BurnExceedsBalance() public {
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
        token.burn(alice, tokenA, 200);
    }

    /*//////////////////////////////////////////////////////////////
                           PAUSED
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhen_Burn_WhilePaused() public {
        vm.prank(minter);
        token.mintTokenA(alice, 100);

        vm.prank(admin);
        token.pause();

        vm.prank(alice);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        token.burn(alice, tokenA, 50);
    }

    function test_RevertWhen_BurnBatch_WhilePaused() public {
        vm.prank(minter);
        token.mintTokenA(alice, 100);

        vm.prank(admin);
        token.pause();

        uint256[] memory ids = new uint256[](1);
        ids[0] = tokenA;

        uint256[] memory values = new uint256[](1);
        values[0] = 50;

        vm.prank(alice);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        token.burnBatch(alice, ids, values);
    }
}
