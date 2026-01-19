// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {FamilyVaultTypes} from "../types/FamilyVaultTypes.sol";

contract FamilyVaultStorage {
    // ========== Roles ==========
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant SPENDER_ROLE = keccak256("SPENDER_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    // ========== Membros ==========
    mapping(address => bool) public isMember;
    mapping(address => bool) internal pausedMembers;

    // ========== Categorias e Solicitações ==========
    mapping(uint64 => FamilyVaultTypes.Category) internal _categories;
    mapping(uint256 => FamilyVaultTypes.Request) internal _requests;

    // ========== Tokens e Allowances ==========
    mapping(address => FamilyVaultTypes.TokenInfo) internal _tokens;
    mapping(address => bool) internal _exists;
    address[] internal _tokenList;

    // Estrutura: allowance[owner][categoryId][spender] = amount
    mapping(address => mapping(uint64 => mapping(address => uint128)))
        internal allowance;

    // @notice Marca se um allowance já foi explicitamente definido
    mapping(address => mapping(uint64 => mapping(address => bool)))
        internal allowanceSet;

    // ========== Metadados ==========
    uint256 internal _lastRequestId;
    uint64 internal _lastCategoryId;

    // ========== Upgrade gap ==========
    uint256[50] private __gap;
}
