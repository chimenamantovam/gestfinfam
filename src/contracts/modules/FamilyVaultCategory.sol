//SPDX-License-Identifier:MIT
pragma solidity ^0.8.27;

import {FamilyVaultBase} from "../base/FamilyVaultBase.sol";
import {FamilyVaultTypes} from "../types/FamilyVaultTypes.sol";

contract FamilyVaultCategory is FamilyVaultBase {
    /** @notice Emite quando uma categoria é criada */
    event CategoryCreated(
        uint64 indexed id,
        string name,
        uint128 monthlyLimit,
        address token
    );
    /** @notice Emite quando uma categoria é atualizada */
    event CategoryUpdated(
        uint64 indexed id,
        string name,
        uint128 monthlyLimit,
        address token
    );
    /** @notice Emite quando uma categoria é desativada */
    event CategoryDeactivated(uint64 indexed id);
    /** @notice Emite quando uma categoria é reativada */
    event CategoryReactivated(uint64 indexed id);

    /** @notice Emite quando uma allowance é configurada */

    // -----------------------------------------
    // Categories
    // -----------------------------------------
    /**
     * @notice Valida dados básicos de categoria
     */
    function _validateCategoryData(
        string calldata name,
        uint128 monthlyLimit,
        address token
    ) internal view {
        require(bytes(name).length > 0, CategoryNameRequired());
        require(monthlyLimit > 0, CategoryLimitRequired());
        require(
            token == address(0) || _isAllowedToken(token),
            TokenNotAllowed()
        );
    }

    /**
     * @notice Cria uma nova categoria
     * @param name Nome da categoria
     * @param monthlyLimit Limite mensal da categoria
     * @param token Endereço do token natio associado address(0) representa o token nativo da rede (ETH, MATIC, BNB, etc.)
     */
    function createCategory(
        string calldata name,
        uint128 monthlyLimit,
        address token // address(0) = ex.: ETH, outro = ERC20
    ) external onlyOwner {
        _validateCategoryData(name, monthlyLimit, token);
        _lastCategoryId += 1; // incrementa ID automaticamente
        uint64 newId = _lastCategoryId;
        _categories[newId] = FamilyVaultTypes.Category({
            id: newId,
            name: name,
            monthlyLimit: monthlyLimit,
            spent: 0,
            periodStart: uint64(block.timestamp),
            token: token,
            active: true
        });
        emit CategoryCreated(newId, name, monthlyLimit, token);
    }

    /**
     * @notice Atualiza informações de uma categoria existente
     * @param id ID da categoria
     * @param newName Novo nome
     * @param newLimit Novo limite
     * @param newToken Novo token
     */
    function updateCategory(
        uint64 id,
        string calldata newName,
        uint128 newLimit,
        address newToken
    ) external onlyOwner categoryExists(id) {
        _validateCategoryData(newName, newLimit, newToken);

        FamilyVaultTypes.Category storage category = _categories[id];
        require(category.active, CategoryInactive());

        category.name = newName;
        category.monthlyLimit = newLimit;
        category.token = newToken;

        emit CategoryUpdated(id, newName, newLimit, newToken);
    }

    /**
     * @notice Desativa uma categoria (soft delete)
     */
    function deactivateCategory(
        uint64 id
    ) external onlyOwner categoryExists(id) {
        FamilyVaultTypes.Category storage category = _categories[id];
        category.active = false;
        emit CategoryDeactivated(id);
    }

    /**
     * @notice Reativa uma categoria desativada
     */
    function reactivateCategory(
        uint64 id
    ) external onlyOwner categoryExists(id) {
        FamilyVaultTypes.Category storage category = _categories[id];
        category.active = true;
        emit CategoryReactivated(id);
    }

    /**
     * @notice Reseta manualmente o ciclo de uma categoria
     */
    function resetCategoryPeriod(
        uint64 id
    ) external onlyOwner categoryExists(id) {
        FamilyVaultTypes.Category storage category = _categories[id];
        category.spent = 0;
        category.periodStart = uint64(block.timestamp);
        emit CategoryReset(id, block.timestamp);
    }

    /**
     * @notice Retorna os detalhes de uma categoria
     * @param categoryId  Id da categoria
     * @return id
     * @return name
     * @return monthlyLimit
     * @return spent
     * @return periodStart
     * @return token
     * @return active
     */
    function getCategoryById(
        uint64 categoryId
    )
        external
        view
        categoryExists(categoryId)
        returns (
            uint64 id,
            string memory name,
            uint128 monthlyLimit,
            uint128 spent,
            uint64 periodStart,
            address token,
            bool active
        )
    {
        FamilyVaultTypes.Category storage category = _categories[categoryId];

        return (
            category.id,
            category.name,
            category.monthlyLimit,
            category.spent,
            category.periodStart,
            category.token,
            category.active
        );
    }

    /**
     * @dev Essa função será migrada depois para indexador off-chain
     */
    function getAllCategories()
        external
        view
        returns (FamilyVaultTypes.Category[] memory)
    {
        FamilyVaultTypes.Category[]
            memory list = new FamilyVaultTypes.Category[](_lastCategoryId);

        for (uint64 i = 1; i <= _lastCategoryId; i++) {
            list[i - 1] = _categories[i];
        }

        return list;
    }

    function getLastCategoryId() external view returns (uint64) {
        return _lastCategoryId;
    }
}
