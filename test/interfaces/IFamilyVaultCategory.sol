// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {FamilyVaultTypes} from "../../src/contracts/types/FamilyVaultTypes.sol";

interface IFamilyVaultCategory {
    function createCategory(
        string calldata name,
        uint128 monthlyLimit,
        address token // address(0) = ex.: ETH, outro = ERC20
    ) external;

    function updateCategory(
        uint64 id,
        string calldata newName,
        uint128 newLimit,
        address newToken
    ) external;

    function deactivateCategory(uint64 id) external;

    function reactivateCategory(uint64 id) external;

    function resetCategoryPeriod(uint64 id) external;

    function getCategoryById(
        uint64 categoryId
    )
        external
        view
        returns (
            uint64 id,
            string memory name,
            uint128 monthlyLimit,
            uint128 spent,
            uint64 periodStart,
            address token,
            bool active
        );

    function getAllCategories()
        external
        view
        returns (FamilyVaultTypes.Category[] memory);

    function getLastCategoryId() external view returns (uint64);
}
