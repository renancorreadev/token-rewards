// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {
    ERC1155Pausable
} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import {
    ERC1155Supply
} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {
    ERC1155Burnable
} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title TokenRewards
/// @notice ERC-1155 with two token types: Token A (membership) and Token B (proportional reward).
///         Uses a push-based distribution pattern: the distributor triggers Token B minting
///         directly to all Token A holders in a single transaction.
/// @dev Follows building-secure-contracts: AccessControl with separated roles, NatSpec, custom errors,
///      Math.mulDiv for safe proportional arithmetic, on-chain holder tracking for push distribution.
contract TokenRewards is
    ERC1155Burnable,
    ERC1155Pausable,
    ERC1155Supply,
    AccessControl
{
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

    /// @dev distributeTokenB called but Token A totalSupply is zero.
    error NoTokenASupply();

    /// @dev distributeTokenB called but no Token A holders exist.
    error NoHolders();

    // ===================== Events =====================

    /// @notice Emitted when Token A is minted to a single recipient.
    event TokenAMinted(address indexed to, uint256 amount);

    /// @notice Emitted when Token B is distributed to all holders.
    event TokenBDistributed(uint256 totalAmount, uint256 holdersCount);

    // ===================== Constants & Roles =====================

    /// @notice Role required to mint Token A.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Role required to distribute Token B.
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");

    /// @notice Token ID for Token A (membership).
    uint256 public constant TOKEN_A = 0;

    /// @notice Token ID for Token B (reward).
    uint256 public constant TOKEN_B = 1;

    // ===================== State =====================

    /// @dev Ordered list of Token A holders (addresses with balance > 0).
    address[] private _holders;

    /// @dev Tracks whether an address is currently a Token A holder.
    mapping(address => bool) private _isHolder;

    /// @dev Maps holder address to its index in the _holders array (for O(1) removal).
    mapping(address => uint256) private _holderIndex;

    // ===================== Constructor =====================

    /// @param admin Address that receives DEFAULT_ADMIN_ROLE (manages roles).
    /// @param uri_ Base URI for ERC-1155 metadata.
    constructor(address admin, string memory uri_) ERC1155(uri_) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(DISTRIBUTOR_ROLE, admin);
    }

    // ===================== Pausability =====================

    /// @notice Pauses all token transfers, mints and burns.
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /// @notice Unpauses all token transfers, mints and burns.
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // ===================== External Functions =====================

    /// @notice Mints Token A to a single recipient.
    /// @param to Recipient address.
    /// @param amount Amount of Token A to mint. Must be > 0.
    function mintTokenA(
        address to,
        uint256 amount
    ) external onlyRole(MINTER_ROLE) {
        if (to == address(0)) revert MintToZeroAddress();
        if (amount == 0) revert MintAmountZero(to);

        _mint(to, TOKEN_A, amount, "");

        emit TokenAMinted(to, amount);
    }

    /// @notice Mints Token A to multiple recipients in a single transaction.
    /// @param recipients Array of recipient addresses.
    /// @param amounts Array of amounts to mint. Must match recipients length.
    function batchMintTokenA(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external onlyRole(MINTER_ROLE) {
        uint256 length = recipients.length;
        if (length == 0) revert BatchEmpty();
        if (length != amounts.length)
            revert BatchLengthMismatch(length, amounts.length);

        for (uint256 i = 0; i < length; i++) {
            address to = recipients[i];
            uint256 amount = amounts[i];
            if (to == address(0)) revert MintToZeroAddress();
            if (amount == 0) revert MintAmountZero(to);
            _mint(to, TOKEN_A, amount, "");
            emit TokenAMinted(to, amount);
        }
    }

    /// @notice Distributes Token B proportionally to all current Token A holders.
    ///         Reward per holder = floor(totalAmount * holderBalance / totalSupply).
    ///         Uses Math.mulDiv to avoid intermediate overflow.
    /// @param totalAmount Total amount of Token B to distribute.
    function distributeTokenB(
        uint256 totalAmount
    ) external onlyRole(DISTRIBUTOR_ROLE) {
        _requireNotPaused();
        if (totalAmount == 0) revert ZeroDistributionAmount();

        uint256 holdersCount = _holders.length;
        if (holdersCount == 0) revert NoHolders();

        uint256 supply = totalSupply(TOKEN_A);
        if (supply == 0) revert NoTokenASupply();

        for (uint256 i = 0; i < holdersCount; i++) {
            address holder = _holders[i];
            uint256 holderBalance = balanceOf(holder, TOKEN_A);
            uint256 reward = Math.mulDiv(totalAmount, holderBalance, supply);

            if (reward > 0) {
                _mint(holder, TOKEN_B, reward, "");
            }
        }

        emit TokenBDistributed(totalAmount, holdersCount);
    }

    // ===================== View Functions =====================

    /// @notice Returns all current Token A holders.
    function getHolders() external view returns (address[] memory) {
        return _holders;
    }

    /// @notice Returns the number of current Token A holders.
    function getHoldersCount() external view returns (uint256) {
        return _holders.length;
    }

    /// @notice Checks if an address is a current Token A holder.
    /// @param account The address to check.
    /// @return True if the address holds Token A.
    function isTokenAHolder(address account) external view returns (bool) {
        return _isHolder[account];
    }

    // ===================== Overrides =====================

    /// @dev Resolves inheritance conflict between ERC1155Supply and AccessControl.
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /// @dev Required override for ERC1155Supply to track totalSupply.
    ///      Also tracks Token A holders: adds new holders and removes those with zero balance.
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override(ERC1155, ERC1155Pausable, ERC1155Supply) {
        super._update(from, to, ids, values);

        for (uint256 i = 0; i < ids.length; i++) {
            if (ids[i] == TOKEN_A) {
                if (from != address(0) && balanceOf(from, TOKEN_A) == 0) {
                    _removeHolder(from);
                }
                if (to != address(0) && !_isHolder[to]) {
                    _addHolder(to);
                }
            }
        }
    }

    // ===================== Private Functions =====================

    /// @dev Adds a new holder to the tracking array.
    function _addHolder(address account) private {
        _isHolder[account] = true;
        _holderIndex[account] = _holders.length;
        _holders.push(account);
    }

    /// @dev Removes a holder using swap-and-pop for O(1) removal.
    function _removeHolder(address account) private {
        if (!_isHolder[account]) return;

        uint256 index = _holderIndex[account];
        uint256 lastIndex = _holders.length - 1;

        if (index != lastIndex) {
            address lastHolder = _holders[lastIndex];
            _holders[index] = lastHolder;
            _holderIndex[lastHolder] = index;
        }

        _holders.pop();
        delete _isHolder[account];
        delete _holderIndex[account];
    }
}
