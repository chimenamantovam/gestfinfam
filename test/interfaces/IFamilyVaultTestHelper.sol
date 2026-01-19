// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IFamilyVaultTestHelper {
    function setCategorySpentForTest(
        uint64 categoryId,
        uint128 amount
    ) external;
}
