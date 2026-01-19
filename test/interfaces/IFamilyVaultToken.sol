// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {FamilyVaultTypes} from "../../src/contracts/types/FamilyVaultTypes.sol";

interface IFamilyVaultToken {
    function setToken(address token, bool active) external;

    function getToken(
        address token
    ) external view returns (FamilyVaultTypes.TokenInfo memory);

    function getAllTokens() external view returns (address[] memory);
}
