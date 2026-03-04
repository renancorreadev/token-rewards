// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ITokenRewards
/// @notice Interface for the TokenRewards ERC-1155 contract with membership (Token A)
///         and proportional reward distribution (Token B).
interface ITokenRewards {
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
    event TokenBDistributed(uint256 totalAmount, uint256 totalMinted, uint256 holdersCount);

    /// @notice Emitted when the base URI is updated by admin.
    event URIUpdated(string newURI);

    // ===================== External Functions =====================

    /// @notice Pauses all token transfers, mints and burns.
    function pause() external;

    /// @notice Unpauses all token transfers, mints and burns.
    function unpause() external;

    /// @notice Updates the base URI for all token types.
    /// @param newURI New base URI string.
    function setURI(string calldata newURI) external;

    /// @notice Mints Token A to a single recipient.
    /// @param to Recipient address.
    /// @param amount Amount of Token A to mint. Must be > 0.
    function mintTokenA(address to, uint256 amount) external;

    /// @notice Mints Token A to multiple recipients in a single transaction.
    /// @param recipients Array of recipient addresses.
    /// @param amounts Array of amounts to mint. Must match recipients length.
    function batchMintTokenA(address[] calldata recipients, uint256[] calldata amounts) external;

    /// @notice Distributes Token B proportionally to all current Token A holders.
    ///         Reward per holder = floor(totalAmount * holderBalance / totalSupply).
    ///         Uses Math.mulDiv to avoid intermediate overflow.
    /// @param totalAmount Total amount of Token B to distribute.
    function distributeTokenB(uint256 totalAmount) external;

    // ===================== View Functions =====================

    /// @notice Returns the MINTER_ROLE hash.
    function MINTER_ROLE() external view returns (bytes32);

    /// @notice Returns the DISTRIBUTOR_ROLE hash.
    function DISTRIBUTOR_ROLE() external view returns (bytes32);

    /// @notice Returns the Token A ID.
    function TOKEN_A() external view returns (uint256);

    /// @notice Returns the Token B ID.
    function TOKEN_B() external view returns (uint256);

    /// @notice Returns all current Token A holders.
    function getHolders() external view returns (address[] memory);

    /// @notice Returns the number of current Token A holders.
    function getHoldersCount() external view returns (uint256);

    /// @notice Checks if an address is a current Token A holder.
    /// @param account The address to check.
    /// @return True if the address holds Token A.
    function isTokenAHolder(address account) external view returns (bool);
}
