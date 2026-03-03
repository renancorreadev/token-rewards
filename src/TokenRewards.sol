// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title TokenRewards
/// @notice ERC-1155 com dois tokens: Token A (membership) e Token B (reward proporcional).
/// @dev Segue building-secure-contracts: AccessControl com roles separadas, NatSpec, custom errors.
contract TokenRewards is ERC1155Supply, AccessControl {
    /// @notice Role para mintar Token A
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Role para distribuir Token B
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");

    /// @notice ID do Token A (membership)
    uint256 public constant TOKEN_A = 0;

    /// @notice ID do Token B (reward)
    uint256 public constant TOKEN_B = 1;

    /// @param admin Endereco que recebe DEFAULT_ADMIN_ROLE (gerencia roles)
    /// @param uri_ URI base para metadados ERC-1155
    constructor(address admin, string memory uri_) ERC1155(uri_) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(DISTRIBUTOR_ROLE, admin);
    }

    /// @dev Resolve conflito de heranca entre ERC1155Supply e AccessControl.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /// @dev Override necessario para ERC1155Supply rastrear totalSupply.
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155Supply)
    {
        super._update(from, to, ids, values);
    }
}
