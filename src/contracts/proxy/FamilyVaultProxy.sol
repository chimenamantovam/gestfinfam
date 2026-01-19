// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title FamilyVaultProxy
 * @notice Proxy minimalista usando ERC1967 (OpenZeppelin)
 */
contract FamilyVaultProxy is ERC1967Proxy {
    constructor(
        address implementation,
        bytes memory initData
    ) ERC1967Proxy(implementation, initData) {}
}
