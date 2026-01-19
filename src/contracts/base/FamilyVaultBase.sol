// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {FamilyVaultStorage} from "../storage/FamilyVaultStorage.sol";
import {FamilyVaultTypes} from "../types/FamilyVaultTypes.sol";

/// @title FamilyVaultBase
/// @notice Base contract with shared modifiers, errors, and internal utils for FamilyVault modules
abstract contract FamilyVaultBase is
    AccessControlEnumerableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    FamilyVaultStorage
{
    using SafeERC20 for IERC20;

    // ----------- Events ----------- //
    /** @notice Emite quando o periodo de uma categoria é resetada */
    event CategoryReset(uint64 indexed id, uint256 timestamp);
    /** @notice Emite quando um gasto é executado */
    event ExpenseExecuted(
        address indexed by,
        uint64 indexed categoryId,
        uint128 amount,
        address to
    );
    event AllowanceDebited(
        address indexed member,
        uint64 indexed categoryId,
        uint128 amount,
        uint128 newBalance,
        address token
    );
    /** @notice Emite quando token nativo da rede é depositado */
    event NativeDeposited(address indexed sender, uint256 amount);

    // ----------- Errors ----------- //
    error NotAuthorized();
    error CategoryNotSet();
    error CategoryNameRequired();
    error CategoryLimitRequired();
    error CategoryInactive();
    error InsufficientAllowance();
    error OverCategoryLimit();
    error ZeroAddress();
    error NotMember();
    error TransferFailed();
    error AlreadyDecided();
    error InsufficientBalance();
    error ZeroDepositNotAllowed();
    error InvalidRecipientAddress();
    error InvalidTokenAddress();
    error ZeroWithdrawNotAllowed();
    error TokenNotAllowed();
    error CannotRemoveLastOwner();
    error InvalidRole();
    error CannotDowngradeLastOwner();
    error NotYourRequest();
    error RequestCannotBeCanceled();
    error ZeroAllowanceNotAllowed();
    error AllowanceCannotBeNegative();
    error ZeroAmountNotAllowed();
    error MemberIsPaused();
    error RequestNotFound(uint256 requestId);
    error MemberAlreadyPaused();
    error MemberNotPaused();

    // ----------- Modifiers ----------- //
    modifier onlyOwner() {
        require(hasRole(OWNER_ROLE, msg.sender), NotAuthorized());
        _;
    }
    modifier onlySpender() {
        require(hasRole(SPENDER_ROLE, msg.sender), NotAuthorized());
        _;
    }

    modifier onlyOwnerOrGuardian() {
        require(
            hasRole(OWNER_ROLE, msg.sender) ||
                hasRole(GUARDIAN_ROLE, msg.sender),
            NotAuthorized()
        );
        _;
    }
    modifier memberExists(address member) {
        require(isMember[member], NotMember());
        _;
    }
    modifier categoryExists(uint64 id) {
        require(_categories[id].periodStart != 0, CategoryNotSet());
        _;
    }

    // ----------- Internal Utility Functions ----------- //

    /**
     * @notice Reseta o gasto se um novo período começou
     */
    function _resetIfNewPeriod(
        FamilyVaultTypes.Category storage category
    ) internal {
        if (block.timestamp >= category.periodStart + 30 days) {
            category.spent = 0;
            category.periodStart = uint64(block.timestamp);
            emit CategoryReset(category.id, block.timestamp);
        }
    }

    /**
     * @notice Aplica o gasto em uma categoria, tratando rollover e validações
     * @param categoryId Id da Categoria em que o gasto será aplicado
     * @param amount Valor do gasto
     */
    function _applySpend(
        uint64 categoryId,
        uint128 amount
    ) internal categoryExists(categoryId) {
        FamilyVaultTypes.Category storage category = _categories[categoryId];
        require(category.active, CategoryInactive());

        _resetIfNewPeriod(category);

        require(
            category.spent + amount <= category.monthlyLimit,
            OverCategoryLimit()
        );

        category.spent += amount;
    }

    /**
     * @notice Transfere token nativo da rede ou ERC20 de forma segura
     * @dev Lança erro caso saldo insuficiente ou falha na transferência
     * @param token Endereço do token address(0) representa o token nativo da rede (ETH, MATIC, BNB, etc.)
     * @param to Endereço do destinatário
     * @param amount Quantidade a transferir
     */
    function _transferFunds(
        address token,
        address payable to,
        uint256 amount
    ) internal {
        if (token == address(0)) {
            //token nativo da rede
            require(address(this).balance >= amount, InsufficientBalance());
            (bool ok, ) = to.call{value: amount}("");
            require(ok, TransferFailed());
        } else {
            //ERC20
            uint256 vaultBalance = IERC20(token).balanceOf(address(this));
            require(vaultBalance >= amount, InsufficientBalance());
            IERC20(token).safeTransfer(to, amount);
        }
    }

    /**
     * @dev Função interna que centraliza a execução de um gasto
     * @param categoryId Categoria onde será debitado o valor
     * @param member Endereço do membro responsável pelo gasto
     * @param to Destinatário do pagamento
     * @param amount Valor a ser gasto
     * @param requireAllowance Se verdadeiro, valida e atualiza allowance do membro
     */
    function _executeExpense(
        uint64 categoryId,
        address member,
        address to,
        uint128 amount,
        bool requireAllowance
    ) internal {
        // 1. Validar valor
        require(amount != 0, ZeroAmountNotAllowed());
        require(to != address(0), InvalidRecipientAddress());
        FamilyVaultTypes.Category storage category = _categories[categoryId];
        // 2. Validar limite mensal e atualizar gasto da categoria
        _applySpend(categoryId, amount);

        // 3. Se necessário, validar e atualizar allowance do membro

        if (requireAllowance) {
            uint128 available = allowance[member][categoryId][category.token];

            require(amount <= available, InsufficientAllowance());

            unchecked {
                allowance[member][categoryId][category.token] =
                    available -
                    amount;
            }

            emit AllowanceDebited(
                member,
                categoryId,
                amount,
                allowance[member][categoryId][category.token],
                category.token
            );
        }

        // 4. Transferir fundos
        _transferFunds(category.token, payable(to), amount);

        // 5. Emitir evento de gasto
        emit ExpenseExecuted(member, categoryId, amount, to);
    }

    /**
     * @notice Verifica se o token é permitido (registrado e ativo)
     * @param token Endereço do token
     * @return bool true se for permitido
     */
    function _isAllowedToken(address token) internal view returns (bool) {
        return token != address(0) && _tokens[token].active;
    }
}
