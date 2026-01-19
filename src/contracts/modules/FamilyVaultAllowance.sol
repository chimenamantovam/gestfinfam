//SPDX-License-Identifier:MIT
pragma solidity ^0.8.27;

import {FamilyVaultBase} from "../base/FamilyVaultBase.sol";
import {FamilyVaultTypes} from "../types/FamilyVaultTypes.sol";

contract FamilyVaultAllowance is FamilyVaultBase {
    // ----------- Events ----------- //

    event AllowanceSet(
        address indexed member,
        uint64 categoryId,
        uint128 amount,
        address token
    );
    /** @notice Emite quando uma allowance é ajustado */
    event AllowanceAdjusted(
        address indexed member,
        uint64 categoryId,
        uint128 amount,
        address token
    );

    // -----------------------------------------
    // Allowances
    // -----------------------------------------

    /**
     * @notice Define allowance de um membro para uma categoria
     * @param member Endereço do membro
     * @param categoryId ID da categoria
     * @param amount Quantidade máxima que o membro pode gastar
     */
    function setAllowance(
        address member,
        uint64 categoryId,
        uint128 amount
    ) external onlyOwner memberExists(member) categoryExists(categoryId) {
        require(!pausedMembers[member], MemberIsPaused());
        FamilyVaultTypes.Category storage category = _categories[categoryId];
        allowance[member][categoryId][category.token] = amount;
        allowanceSet[member][categoryId][category.token] = true;
        emit AllowanceSet(member, categoryId, amount, category.token);
    }

    /**
     * @notice Retorna a allowance de um membro em uma categoria, total e disponível
     * @param member Endereço do membro
     * @param categoryId ID da categoria
     * @return totalAllowance Valor total definido para o membro na categoria
     * @return availableAllowance Valor disponível considerando o gasto atual
     */
    function getAllowance(
        address member,
        uint64 categoryId
    )
        external
        view
        memberExists(member)
        categoryExists(categoryId)
        returns (uint128 totalAllowance, uint128 availableAllowance)
    {
        FamilyVaultTypes.Category storage category = _categories[categoryId];
        require(category.active, CategoryInactive());

        // saldo atual do membro para essa categoria/token
        address token = category.token;
        totalAllowance = allowance[member][categoryId][token];

        // Spend efetivo (considera reset do período sem alterar estado)
        uint128 spent = category.spent;
        if (block.timestamp >= category.periodStart + 30 days) {
            spent = 0;
        }

        // Quanto resta do limite da categoria neste período
        uint128 remainingCategory;
        if (category.monthlyLimit > spent) {
            remainingCategory = category.monthlyLimit - spent;
        } else {
            remainingCategory = 0;
        }

        // Disponível é o mínimo entre o saldo do membro e o que resta da categoria
        if (totalAllowance < remainingCategory) {
            availableAllowance = totalAllowance;
        } else {
            availableAllowance = remainingCategory;
        }
    }

    /**
     * @notice Ajusta allowance de um membro para uma categoria
     * @param member Endereço do membro
     * @param categoryId ID da categoria
     * @param newValue Valor a adicionar ou remover da allowance (positivo = adicionar, negativo = reduzir)
     */
    function adjustAllowance(
        address member,
        uint64 categoryId,
        int128 newValue
    ) external onlyOwner memberExists(member) categoryExists(categoryId) {
        require(!pausedMembers[member], MemberIsPaused());

        FamilyVaultTypes.Category storage category = _categories[categoryId];

        uint128 current = allowance[member][categoryId][category.token];
        uint128 newAllowance;

        if (newValue >= 0) {
            newAllowance = current + uint128(newValue);
        } else {
            // newValue negativo, garantir que não vai ficar abaixo de 0
            uint128 absNewValue = uint128(-newValue);
            require(current >= absNewValue, AllowanceCannotBeNegative());
            newAllowance = current - absNewValue;
        }

        allowance[member][categoryId][category.token] = newAllowance;
        allowanceSet[member][categoryId][category.token] = true;

        emit AllowanceAdjusted(
            member,
            categoryId,
            newAllowance,
            category.token
        );
    }

    /**
     * @notice Retorna se o allowance de um membro para uma categoria já foi definido
     */
    function hasAllowanceSet(
        address member,
        uint64 categoryId
    ) external view returns (bool) {
        FamilyVaultTypes.Category storage category = _categories[categoryId];
        return allowanceSet[member][categoryId][category.token];
    }
}
