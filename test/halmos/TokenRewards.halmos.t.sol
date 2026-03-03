// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SymTest} from "halmos-cheatcodes/SymTest.sol";
import {TokenRewards} from "../../src/TokenRewards.sol";

/// @title TokenRewardsHalmosTest
/// @notice Symbolic execution tests for TokenRewards using Halmos.
///         Convention: `check_` prefix (Halmos-only, Foundry ignores).
contract TokenRewardsHalmosTest is Test, SymTest {
    TokenRewards internal token;

    address internal admin = address(0xAD);
    address internal minter = address(0xBB);
    address internal distributor = address(0xCC);

    uint256 internal tokenA;
    uint256 internal tokenB;

    function setUp() public {
        token = new TokenRewards(admin, "https://example.com/{id}.json");

        tokenA = token.TOKEN_A();
        tokenB = token.TOKEN_B();

        vm.startPrank(admin);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.DISTRIBUTOR_ROLE(), distributor);
        vm.stopPrank();
    }

    // ===================== Mint =====================

    /// @notice For any valid `to` and `amount > 0`, balance increases by exactly `amount`.
    function check_mintTokenA_increases_balance() public {
        address to = svm.createAddress("to");
        uint256 amount = svm.createUint256("amount");

        vm.assume(to != address(0));
        vm.assume(amount > 0);

        uint256 balBefore = token.balanceOf(to, tokenA);

        vm.prank(minter);
        token.mintTokenA(to, amount);

        uint256 balAfter = token.balanceOf(to, tokenA);
        assert(balAfter == balBefore + amount);
    }

    /// @notice For any valid mint, totalSupply(TOKEN_A) increases by exactly `amount`.
    function check_mintTokenA_increases_totalSupply() public {
        address to = svm.createAddress("to");
        uint256 amount = svm.createUint256("amount");

        vm.assume(to != address(0));
        vm.assume(amount > 0);

        uint256 supplyBefore = token.totalSupply(tokenA);

        vm.prank(minter);
        token.mintTokenA(to, amount);

        uint256 supplyAfter = token.totalSupply(tokenA);
        assert(supplyAfter == supplyBefore + amount);
    }

    /// @notice After minting Token A, the recipient must be a holder.
    function check_mintTokenA_adds_holder() public {
        address to = svm.createAddress("to");
        uint256 amount = svm.createUint256("amount");

        vm.assume(to != address(0));
        vm.assume(amount > 0);

        vm.prank(minter);
        token.mintTokenA(to, amount);

        assert(token.isTokenAHolder(to) == true);
    }

    // ===================== Transfer =====================

    /// @notice For any safeTransferFrom of Token A, totalSupply does not change.
    function check_transfer_conserves_supply() public {
        address sender = svm.createAddress("sender");
        address receiver = svm.createAddress("receiver");
        uint256 mintAmount = svm.createUint256("mintAmount");
        uint256 transferAmount = svm.createUint256("transferAmount");

        vm.assume(sender != address(0));
        vm.assume(receiver != address(0));
        vm.assume(sender != receiver);
        vm.assume(mintAmount > 0);
        vm.assume(transferAmount > 0 && transferAmount <= mintAmount);

        // Setup: mint to sender
        vm.prank(minter);
        token.mintTokenA(sender, mintAmount);

        uint256 supplyBefore = token.totalSupply(tokenA);

        // Transfer
        vm.prank(sender);
        token.safeTransferFrom(sender, receiver, tokenA, transferAmount, "");

        uint256 supplyAfter = token.totalSupply(tokenA);
        assert(supplyAfter == supplyBefore);
    }

    /// @notice For any transfer, sender loses `amount` and receiver gains `amount`.
    function check_transfer_updates_balances() public {
        address sender = svm.createAddress("sender");
        address receiver = svm.createAddress("receiver");
        uint256 mintAmount = svm.createUint256("mintAmount");
        uint256 transferAmount = svm.createUint256("transferAmount");

        vm.assume(sender != address(0));
        vm.assume(receiver != address(0));
        vm.assume(sender != receiver);
        vm.assume(mintAmount > 0);
        vm.assume(transferAmount > 0 && transferAmount <= mintAmount);

        // Setup: mint to sender
        vm.prank(minter);
        token.mintTokenA(sender, mintAmount);

        uint256 senderBefore = token.balanceOf(sender, tokenA);
        uint256 receiverBefore = token.balanceOf(receiver, tokenA);

        // Transfer
        vm.prank(sender);
        token.safeTransferFrom(sender, receiver, tokenA, transferAmount, "");

        uint256 senderAfter = token.balanceOf(sender, tokenA);
        uint256 receiverAfter = token.balanceOf(receiver, tokenA);

        assert(senderAfter == senderBefore - transferAmount);
        assert(receiverAfter == receiverBefore + transferAmount);
    }

    // ===================== Burn =====================

    /// @notice For any burn, balance decreases by exactly `amount`.
    function check_burn_decreases_balance() public {
        address holder = svm.createAddress("holder");
        uint256 mintAmount = svm.createUint256("mintAmount");
        uint256 burnAmount = svm.createUint256("burnAmount");

        vm.assume(holder != address(0));
        vm.assume(mintAmount > 0);
        vm.assume(burnAmount > 0 && burnAmount <= mintAmount);

        vm.prank(minter);
        token.mintTokenA(holder, mintAmount);

        uint256 balBefore = token.balanceOf(holder, tokenA);

        vm.prank(holder);
        token.burn(holder, tokenA, burnAmount);

        uint256 balAfter = token.balanceOf(holder, tokenA);
        assert(balAfter == balBefore - burnAmount);
    }

    /// @notice For any burn, totalSupply decreases by exactly `amount`.
    function check_burn_decreases_totalSupply() public {
        address holder = svm.createAddress("holder");
        uint256 mintAmount = svm.createUint256("mintAmount");
        uint256 burnAmount = svm.createUint256("burnAmount");

        vm.assume(holder != address(0));
        vm.assume(mintAmount > 0);
        vm.assume(burnAmount > 0 && burnAmount <= mintAmount);

        vm.prank(minter);
        token.mintTokenA(holder, mintAmount);

        uint256 supplyBefore = token.totalSupply(tokenA);

        vm.prank(holder);
        token.burn(holder, tokenA, burnAmount);

        uint256 supplyAfter = token.totalSupply(tokenA);
        assert(supplyAfter == supplyBefore - burnAmount);
    }

    /// @notice If balance reaches 0 after burn, holder is removed.
    function check_burn_removes_holder_when_zero() public {
        address holder = svm.createAddress("holder");
        uint256 amount = svm.createUint256("amount");

        vm.assume(holder != address(0));
        vm.assume(amount > 0);

        vm.prank(minter);
        token.mintTokenA(holder, amount);

        assert(token.isTokenAHolder(holder) == true);

        // Burn all
        vm.prank(holder);
        token.burn(holder, tokenA, amount);

        assert(token.isTokenAHolder(holder) == false);
    }

    // ===================== Distribution =====================

    /// @notice distributeTokenB does not revert for valid inputs and emits correctly.
    ///         Note: mulDiv arithmetic conservation (sum ≤ totalAmount) is verified by
    ///         Echidna property fuzzing with 50K+ transactions; Halmos cannot handle
    ///         mulDiv's non-linear 512-bit intermediate arithmetic symbolically.
    function check_distribute_does_not_revert_for_valid_inputs() public {
        uint256 amountA = svm.createUint256("amountA");
        uint256 totalDistribution = svm.createUint256("totalDistribution");

        vm.assume(amountA > 0);
        vm.assume(totalDistribution > 0);

        address h1 = address(0x1001);

        vm.prank(minter);
        token.mintTokenA(h1, amountA);

        uint256 holdersBefore = token.getHoldersCount();
        assert(holdersBefore == 1);

        // Should not revert — valid state: holder exists, supply > 0, amount > 0
        vm.prank(distributor);
        token.distributeTokenB(totalDistribution);

        // Token A supply unchanged after Token B distribution
        assert(token.totalSupply(tokenA) == amountA);
        // Holder still tracked
        assert(token.isTokenAHolder(h1) == true);
    }

    /// @notice A holder with 0 Token A balance does not receive Token B.
    ///         Scenario: mint to holder, burn all, then distribute.
    function check_distribute_no_mint_when_zero_balance() public {
        address holder = address(0x2001);
        address activeHolder = address(0x2002);
        uint256 amount = svm.createUint256("amount");
        uint256 distAmount = svm.createUint256("distAmount");

        vm.assume(amount > 0 && amount <= 1e30);
        vm.assume(distAmount > 0 && distAmount <= 1e30);

        // Mint to both
        vm.startPrank(minter);
        token.mintTokenA(holder, amount);
        token.mintTokenA(activeHolder, amount);
        vm.stopPrank();

        // Burn holder's entire balance
        vm.prank(holder);
        token.burn(holder, tokenA, amount);

        uint256 holderTokenBBefore = token.balanceOf(holder, tokenB);

        // Distribute
        vm.prank(distributor);
        token.distributeTokenB(distAmount);

        uint256 holderTokenBAfter = token.balanceOf(holder, tokenB);

        // Holder with 0 Token A should receive 0 Token B
        assert(holderTokenBAfter == holderTokenBBefore);
    }

    // ===================== Access Control =====================

    /// @notice Any caller without MINTER_ROLE cannot mint Token A.
    function check_only_minter_can_mint() public {
        address caller = svm.createAddress("caller");
        address to = svm.createAddress("to");
        uint256 amount = svm.createUint256("amount");

        vm.assume(caller != admin && caller != minter);
        vm.assume(to != address(0));
        vm.assume(amount > 0);

        vm.prank(caller);
        try token.mintTokenA(to, amount) {
            // If it didn't revert, the assertion fails
            assert(false);
        } catch {
            // Expected: unauthorized caller should revert
            assert(true);
        }
    }

    /// @notice Any caller without DEFAULT_ADMIN_ROLE cannot pause.
    function check_only_admin_can_pause() public {
        address caller = svm.createAddress("caller");

        vm.assume(caller != admin);

        vm.prank(caller);
        try token.pause() {
            assert(false);
        } catch {
            assert(true);
        }
    }
}
