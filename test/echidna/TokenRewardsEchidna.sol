// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TokenRewards} from "../../src/TokenRewards.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/// @notice Actor proxy that approves the test contract as operator on the token.
///         Burns and transfers route through the proxy so msg.sender at the token
///         level is the proxy (which IS the token holder).
contract ActorProxy {
    TokenRewards public token;
    address public owner;

    constructor(TokenRewards _token, address _owner) {
        token = _token;
        owner = _owner;
    }

    function approve(address operator) external {
        token.setApprovalForAll(operator, true);
    }

    function burn(uint256 id, uint256 amount) external {
        token.burn(address(this), id, amount);
    }

    function burnBatch(uint256[] calldata ids, uint256[] calldata values) external {
        token.burnBatch(address(this), ids, values);
    }

    function transfer(address to, uint256 id, uint256 amount) external {
        token.safeTransferFrom(address(this), to, id, amount, "");
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}

/// @notice Echidna property-based fuzzing contract for TokenRewards.
///         Tests invariants that must hold regardless of transaction sequence.
///         All functions are callable by Echidna senders (0x10000, 0x20000, 0x30000).
///         The deployer (address(this)) holds all roles (admin, minter, distributor).
///
///         Uses ActorProxy contracts so burn/transfer operations have the correct
///         msg.sender at the token level (the proxy IS the holder, not an EOA).
contract TokenRewardsEchidna {
    TokenRewards internal token;

    ActorProxy internal aliceProxy;
    ActorProxy internal bobProxy;
    ActorProxy internal carolProxy;

    address internal alice;
    address internal bob;
    address internal carol;

    uint256 internal constant TOKEN_A = 0;
    uint256 internal constant TOKEN_B = 1;

    constructor() {
        token = new TokenRewards(address(this), "https://example.com/{id}.json");

        aliceProxy = new ActorProxy(token, address(this));
        bobProxy = new ActorProxy(token, address(this));
        carolProxy = new ActorProxy(token, address(this));

        alice = address(aliceProxy);
        bob = address(bobProxy);
        carol = address(carolProxy);
    }

    // ===================== Action: Mint =====================

    function mintToAlice(uint256 amount) public {
        amount = (amount % 1000) + 1;
        token.mintTokenA(alice, amount);
    }

    function mintToBob(uint256 amount) public {
        amount = (amount % 1000) + 1;
        token.mintTokenA(bob, amount);
    }

    function mintToCarol(uint256 amount) public {
        amount = (amount % 1000) + 1;
        token.mintTokenA(carol, amount);
    }

    // ===================== Action: Batch Mint =====================

    function batchMintTwo(uint256 amountA, uint256 amountB) public {
        amountA = (amountA % 1000) + 1;
        amountB = (amountB % 1000) + 1;

        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = bob;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amountA;
        amounts[1] = amountB;

        token.batchMintTokenA(recipients, amounts);
    }

    function batchMintThree(uint256 a, uint256 b, uint256 c) public {
        a = (a % 500) + 1;
        b = (b % 500) + 1;
        c = (c % 500) + 1;

        address[] memory recipients = new address[](3);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = carol;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = a;
        amounts[1] = b;
        amounts[2] = c;

        token.batchMintTokenA(recipients, amounts);
    }

    // ===================== Action: Distribute =====================

    function distribute(uint256 amount) public {
        amount = (amount % 10000) + 1;
        if (token.getHoldersCount() > 0 && token.totalSupply(TOKEN_A) > 0) {
            token.distributeTokenB(amount);
        }
    }

    // ===================== Action: Burn (via proxy — correct msg.sender) =====================

    function burnAliceTokenA(uint256 amount) public {
        uint256 bal = token.balanceOf(alice, TOKEN_A);
        if (bal > 0) {
            amount = (amount % bal) + 1;
            aliceProxy.burn(TOKEN_A, amount);
        }
    }

    function burnBobTokenA(uint256 amount) public {
        uint256 bal = token.balanceOf(bob, TOKEN_A);
        if (bal > 0) {
            amount = (amount % bal) + 1;
            bobProxy.burn(TOKEN_A, amount);
        }
    }

    function burnAllAliceTokenA() public {
        uint256 bal = token.balanceOf(alice, TOKEN_A);
        if (bal > 0) {
            aliceProxy.burn(TOKEN_A, bal);
        }
    }

    function burnAllBobTokenA() public {
        uint256 bal = token.balanceOf(bob, TOKEN_A);
        if (bal > 0) {
            bobProxy.burn(TOKEN_A, bal);
        }
    }

    function burnAliceTokenB(uint256 amount) public {
        uint256 bal = token.balanceOf(alice, TOKEN_B);
        if (bal > 0) {
            amount = (amount % bal) + 1;
            aliceProxy.burn(TOKEN_B, amount);
        }
    }

    function burnBatchAlice(uint256 amtA, uint256 amtB) public {
        uint256 balA = token.balanceOf(alice, TOKEN_A);
        uint256 balB = token.balanceOf(alice, TOKEN_B);
        if (balA > 0 && balB > 0) {
            amtA = (amtA % balA) + 1;
            amtB = (amtB % balB) + 1;

            uint256[] memory ids = new uint256[](2);
            ids[0] = TOKEN_A;
            ids[1] = TOKEN_B;

            uint256[] memory values = new uint256[](2);
            values[0] = amtA;
            values[1] = amtB;

            aliceProxy.burnBatch(ids, values);
        }
    }

    // ===================== Action: Transfer (via proxy — correct msg.sender) =====================

    function transferAliceToBob(uint256 amount) public {
        uint256 bal = token.balanceOf(alice, TOKEN_A);
        if (bal > 0) {
            amount = (amount % bal) + 1;
            aliceProxy.transfer(bob, TOKEN_A, amount);
        }
    }

    function transferBobToAlice(uint256 amount) public {
        uint256 bal = token.balanceOf(bob, TOKEN_A);
        if (bal > 0) {
            amount = (amount % bal) + 1;
            bobProxy.transfer(alice, TOKEN_A, amount);
        }
    }

    function transferAliceToCarol(uint256 amount) public {
        uint256 bal = token.balanceOf(alice, TOKEN_A);
        if (bal > 0) {
            amount = (amount % bal) + 1;
            aliceProxy.transfer(carol, TOKEN_A, amount);
        }
    }

    function transferTokenBAliceToBob(uint256 amount) public {
        uint256 bal = token.balanceOf(alice, TOKEN_B);
        if (bal > 0) {
            amount = (amount % bal) + 1;
            aliceProxy.transfer(bob, TOKEN_B, amount);
        }
    }

    function transferAllAliceToBob() public {
        uint256 bal = token.balanceOf(alice, TOKEN_A);
        if (bal > 0) {
            aliceProxy.transfer(bob, TOKEN_A, bal);
        }
    }

    function transferAllBobToCarol() public {
        uint256 bal = token.balanceOf(bob, TOKEN_A);
        if (bal > 0) {
            bobProxy.transfer(carol, TOKEN_A, bal);
        }
    }

    // ===================== Action: Batch Mint (mismatched — triggers revert) =====================

    function batchMintMismatched() public {
        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = bob;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;

        // This should revert with BatchLengthMismatch — exercising that code path
        try token.batchMintTokenA(recipients, amounts) {} catch {}
    }

    // ===================== Action: View functions (coverage) =====================

    function callViews() public view {
        token.getHolders();
        token.getHoldersCount();
        token.isTokenAHolder(alice);
        token.isTokenAHolder(bob);
        token.isTokenAHolder(carol);
        token.supportsInterface(0x01ffc9a7); // ERC165
    }

    // ===================== Action: Pause / Unpause =====================

    function doPause() public {
        if (!token.paused()) {
            token.pause();
        }
    }

    function doUnpause() public {
        if (token.paused()) {
            token.unpause();
        }
    }

    // ===================== Invariants =====================

    /// @notice holdersCount == actual count of addresses with Token A balance > 0.
    function echidna_holdersCount_matches_actual() public view returns (bool) {
        uint256 count = token.getHoldersCount();
        uint256 actual = 0;
        if (token.balanceOf(alice, TOKEN_A) > 0) actual++;
        if (token.balanceOf(bob, TOKEN_A) > 0) actual++;
        if (token.balanceOf(carol, TOKEN_A) > 0) actual++;
        return count == actual;
    }

    /// @notice isTokenAHolder must be consistent with balanceOf for all tracked addresses.
    function echidna_isHolder_consistent_with_balance() public view returns (bool) {
        if (token.isTokenAHolder(alice) != (token.balanceOf(alice, TOKEN_A) > 0)) return false;
        if (token.isTokenAHolder(bob) != (token.balanceOf(bob, TOKEN_A) > 0)) return false;
        if (token.isTokenAHolder(carol) != (token.balanceOf(carol, TOKEN_A) > 0)) return false;
        return true;
    }

    /// @notice Token A totalSupply must equal sum of all Token A balances.
    function echidna_totalSupplyA_equals_sum_of_balances() public view returns (bool) {
        uint256 supply = token.totalSupply(TOKEN_A);
        uint256 sum = token.balanceOf(alice, TOKEN_A)
            + token.balanceOf(bob, TOKEN_A)
            + token.balanceOf(carol, TOKEN_A);
        return supply == sum;
    }

    /// @notice Token B totalSupply must equal sum of all Token B balances.
    function echidna_totalSupplyB_equals_sum_of_balances() public view returns (bool) {
        uint256 supply = token.totalSupply(TOKEN_B);
        uint256 sum = token.balanceOf(alice, TOKEN_B)
            + token.balanceOf(bob, TOKEN_B)
            + token.balanceOf(carol, TOKEN_B);
        return supply == sum;
    }

    /// @notice getHolders().length must equal getHoldersCount().
    function echidna_holders_array_length_matches_count() public view returns (bool) {
        return token.getHolders().length == token.getHoldersCount();
    }

    /// @notice Address with zero Token A balance must never be marked as holder.
    function echidna_zero_balance_not_holder() public view returns (bool) {
        if (token.balanceOf(alice, TOKEN_A) == 0 && token.isTokenAHolder(alice)) return false;
        if (token.balanceOf(bob, TOKEN_A) == 0 && token.isTokenAHolder(bob)) return false;
        if (token.balanceOf(carol, TOKEN_A) == 0 && token.isTokenAHolder(carol)) return false;
        return true;
    }

    /// @notice holdersCount must never exceed 3 (only alice, bob, carol receive tokens).
    function echidna_holdersCount_bounded() public view returns (bool) {
        return token.getHoldersCount() <= 3;
    }

    // ===================== ERC1155 Receiver (for token transfers to this contract) =====================

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}
