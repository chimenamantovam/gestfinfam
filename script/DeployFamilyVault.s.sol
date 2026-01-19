// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {FamilyVault} from "../src/contracts/FamilyVault.sol";
import {FamilyVaultFactory} from "../src/contracts/FamilyVaultFactory.sol";

import {FamilyVaultAllowance} from "../src/contracts/modules/FamilyVaultAllowance.sol";
import {FamilyVaultCategory} from "../src/contracts/modules/FamilyVaultCategory.sol";
import {FamilyVaultFund} from "../src/contracts/modules/FamilyVaultFund.sol";
import {FamilyVaultMember} from "../src/contracts/modules/FamilyVaultMember.sol";
import {FamilyVaultRequest} from "../src/contracts/modules/FamilyVaultRequest.sol";
import {FamilyVaultToken} from "../src/contracts/modules/FamilyVaultToken.sol";

/// @title DeployFamilyVault
/// @notice Script modular para deploy do contrato FamilyVault.
/// @dev Compatível com qualquer rede usando `--account` e `--sender`.
contract DeployFamilyVault is Script {
    FamilyVaultFactory public factory;

    FamilyVaultAllowance public allowanceModule;
    FamilyVaultCategory public categoryModule;
    FamilyVaultFund public fundModule;
    FamilyVaultMember public memberModule;
    FamilyVaultRequest public requestModule;
    FamilyVaultToken public tokenModule;

    function run() public {
        vm.startBroadcast();

        // 1. Deploy da implementação base do FamilyVault
        FamilyVault implementation = new FamilyVault();

        // 2. Deploy dos módulos
        allowanceModule = new FamilyVaultAllowance();
        categoryModule = new FamilyVaultCategory();
        fundModule = new FamilyVaultFund();
        memberModule = new FamilyVaultMember();
        requestModule = new FamilyVaultRequest();
        tokenModule = new FamilyVaultToken();

        // 3. Deploy da Factory com implementação e módulos
        factory = new FamilyVaultFactory(
            address(implementation),
            address(allowanceModule),
            address(categoryModule),
            address(fundModule),
            address(memberModule),
            address(requestModule),
            address(tokenModule)
        );

        vm.stopBroadcast();

        // ✅ Logs finais
        console.log("======================================");
        console.log("FamilyVault deployment concluido!");
        console.log("Factory Address: ", address(factory));
        console.log("Implementation Address: ", address(implementation));
        console.log("Allowance Module: ", address(allowanceModule));
        console.log("Category Module: ", address(categoryModule));
        console.log("Fund Module: ", address(fundModule));
        console.log("Member Module: ", address(memberModule));
        console.log("Request Module: ", address(requestModule));
        console.log("Token Module: ", address(tokenModule));
        console.log("======================================");
    }
}
