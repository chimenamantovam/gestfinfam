// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {FamilyVaultBase} from "../../src/contracts/base/FamilyVaultBase.sol";
import {FamilyVaultTypes} from "../../src/contracts/types/FamilyVaultTypes.sol";

contract FamilyVaultTestSpecificHelper is FamilyVaultBase {
    /**
     * @notice Internal helper to set category.spent (for tests)
     * @dev Internal so only descendants can call. Does not change external behaviour.
     */
    function _setCategorySpentInternal(
        uint64 categoryId,
        uint128 amount
    ) internal virtual {
        FamilyVaultTypes.Category storage category = _categories[categoryId];
        require(category.periodStart != 0, CategoryNotSet());
        category.spent = amount;
    }

    /// ⚠️ Função apenas para testes locais
    function setCategorySpentForTest(
        uint64 categoryId,
        uint128 amount
    ) external {
        require(block.chainid == 31337 || block.chainid == 1337, "TEST_ONLY");
        _setCategorySpentInternal(categoryId, amount);
    }
}
