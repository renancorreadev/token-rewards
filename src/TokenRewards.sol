// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {
    ERC1155Supply
} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title TokenRewards
/// @notice ERC-1155 with reward distribution
contract TokenRewards is ERC1155Supply, AccessControl {
    // ===================== Errors =====================

    /// @dev Mint called with zero amount.
    error MintAmountZero(address to);

    /// @dev Mint called with address(0) as recipient.
    error MintToZeroAddress();

    /// @dev Batch mint called with mismatched array lengths.
    error BatchLengthMismatch(uint256 recipientsLength, uint256 amountsLength);

    /// @dev Batch mint called with empty arrays.
    error BatchEmpty();

    /// @dev distributeTokenB called with zero amount.
    error ZeroDistributionAmount();

    /// @dev distributeTokenB called but no Token A holders exist.
    error NoHolders();

    /// @dev distributeTokenB called but Token A totalSupply is zero.
    error NoTokenASupply();

    // ===================== Constants & Roles =====================

    /// @notice Role required to mint Token A.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Role required to distribute Token B.
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");

    /// @notice Token ID for Token A (membership).
    uint256 public constant TOKEN_A = 0;

    /// @notice Token ID for Token B (reward).
    uint256 public constant TOKEN_B = 1;

    // ===================== Constructor =====================

    /// @param admin Address that receives DEFAULT_ADMIN_ROLE (manages roles).
    /// @param uri_ Base URI for ERC-1155 metadata.
    constructor(address admin, string memory uri_) ERC1155(uri_) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(DISTRIBUTOR_ROLE, admin);
    }

    // ===================== Overrides =====================

    /// @dev Resolves inheritance conflict between ERC1155Supply and AccessControl.
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /// @dev Required override for ERC1155Supply to track totalSupply.
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override(ERC1155Supply) {
        super._update(from, to, ids, values);
    }
}
