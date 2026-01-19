// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IFamilyVaultAllowance {
    function setAllowance(
        address member,
        uint64 categoryId,
        uint128 amount
    ) external;

    function getAllowance(
        address member,
        uint64 categoryId
    )
        external
        view
        returns (uint128 totalAllowance, uint128 availableAllowance);

    function adjustAllowance(
        address member,
        uint64 categoryId,
        int128 newValue
    ) external;

    function hasAllowanceSet(
        address member,
        uint64 categoryId
    ) external view returns (bool);
}
