// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {FamilyVault} from "../../src/contracts/FamilyVault.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {FamilyVaultAllowance} from "../../src/contracts/modules/FamilyVaultAllowance.sol";
import {FamilyVaultCategory} from "../../src/contracts/modules/FamilyVaultCategory.sol";
import {FamilyVaultFund} from "../../src/contracts/modules/FamilyVaultFund.sol";
import {FamilyVaultMember} from "../../src/contracts/modules/FamilyVaultMember.sol";
import {FamilyVaultRequest} from "../../src/contracts/modules/FamilyVaultRequest.sol";
import {FamilyVaultToken} from "../../src/contracts/modules/FamilyVaultToken.sol";

import {FamilyVaultTestSpecificHelper} from "../helpers/FamilyVaultTestSpecificHelper.sol";

contract FamilyVaultTestHelper is Test {
    /// @notice Cria um novo FamilyVault através de um Proxy
    /// @param owner O endereço inicial do owner
    /// @return familyVault A instância do contrato FamilyVault pronta para uso
    function deployFamilyVaultWithProxy(
        address owner
    ) internal returns (FamilyVault) {
        // 1. Deploy da implementação
        FamilyVault implementation = new FamilyVault();

        // 2. Deploy dos módulos (agora antes de criar o proxy)
        FamilyVaultAllowance allowanceModule = new FamilyVaultAllowance();
        FamilyVaultCategory categoryModule = new FamilyVaultCategory();
        FamilyVaultFund fundModule = new FamilyVaultFund();
        FamilyVaultMember memberModule = new FamilyVaultMember();
        FamilyVaultRequest requestModule = new FamilyVaultRequest();
        FamilyVaultToken tokenModule = new FamilyVaultToken();
        FamilyVaultTestSpecificHelper specificModule = new FamilyVaultTestSpecificHelper();

        // 3. Encode do initializer com TODOS os parâmetros (owner + módulos)
        bytes memory initData = abi.encodeWithSelector(
            FamilyVault.initialize.selector,
            owner,
            address(allowanceModule),
            address(categoryModule),
            address(fundModule),
            address(memberModule),
            address(requestModule),
            address(tokenModule)
        );

        // 3. Deploy do proxy apontando para a implementação
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        FamilyVault vault = FamilyVault(payable(address(proxy)));

        // 5. Registrar os módulos no vault
        _setVaultModules(
            vault,
            allowanceModule,
            categoryModule,
            fundModule,
            memberModule,
            requestModule,
            tokenModule,
            specificModule
        );

        return vault;
    }

    /// @notice Deploy de todos os módulos
    function _deployModules()
        internal
        returns (
            FamilyVaultAllowance allowanceModule,
            FamilyVaultCategory categoryModule,
            FamilyVaultFund fundModule,
            FamilyVaultMember memberModule,
            FamilyVaultRequest requestModule,
            FamilyVaultToken tokenModule,
            FamilyVaultTestSpecificHelper specificModule
        )
    {
        allowanceModule = new FamilyVaultAllowance();
        categoryModule = new FamilyVaultCategory();
        fundModule = new FamilyVaultFund();
        memberModule = new FamilyVaultMember();
        requestModule = new FamilyVaultRequest();
        tokenModule = new FamilyVaultToken();
        specificModule = new FamilyVaultTestSpecificHelper();
    }

    function _setVaultModules(
        FamilyVault vault,
        FamilyVaultAllowance allowanceModule,
        FamilyVaultCategory categoryModule,
        FamilyVaultFund fundModule,
        FamilyVaultMember memberModule,
        FamilyVaultRequest requestModule,
        FamilyVaultToken tokenModule,
        FamilyVaultTestSpecificHelper specificModule
    ) internal {
        string[] memory allowanceSigs = new string[](4);
        allowanceSigs[0] = "setAllowance(address,uint64,uint128)";
        allowanceSigs[1] = "getAllowance(address,uint64)";
        allowanceSigs[2] = "adjustAllowance(address,uint64,int128)";
        allowanceSigs[3] = "hasAllowanceSet(address,uint64)";

        vault.setSelectorsBySignatures(allowanceSigs, address(allowanceModule));

        string[] memory categorySigs = new string[](8);
        categorySigs[0] = "createCategory(string,uint128,address)";
        categorySigs[1] = "updateCategory(uint64,string,uint128,address)";
        categorySigs[2] = "deactivateCategory(uint64)";
        categorySigs[3] = "reactivateCategory(uint64)";
        categorySigs[4] = "resetCategoryPeriod(uint64)";
        categorySigs[5] = "getCategoryById(uint64)";
        categorySigs[6] = "getAllCategories()";
        categorySigs[7] = "getLastCategoryId()";
        vault.setSelectorsBySignatures(categorySigs, address(categoryModule));

        string[] memory fundSigs = new string[](6);
        fundSigs[0] = "spend(uint64,uint128,address)";
        fundSigs[1] = "depositNative()";
        fundSigs[2] = "withdraw(address,uint256)";
        fundSigs[3] = "depositERC20(address,uint256)";
        fundSigs[4] = "withdrawERC20(address,address,uint256)";
        fundSigs[5] = "contractBalance(address)";
        vault.setSelectorsBySignatures(fundSigs, address(fundModule));

        string[] memory memberSigs = new string[](8);
        memberSigs[0] = "addMember(address,bytes32)";
        memberSigs[1] = "removeMember(address)";
        memberSigs[2] = "updateMemberRole(address,bytes32)";
        memberSigs[3] = "pauseMember(address)";
        memberSigs[4] = "unpauseMember(address)";
        memberSigs[5] = "isMemberPaused(address)";
        memberSigs[6] = "listMembersByRole(bytes32)";
        memberSigs[7] = "isMemberActive(address)";
        vault.setSelectorsBySignatures(memberSigs, address(memberModule));

        string[] memory requestSigs = new string[](7);
        requestSigs[0] = "createRequest(uint64,uint128,string)";
        requestSigs[1] = "approveRequest(uint256,address)";
        requestSigs[2] = "denyRequest(uint256,string)";
        requestSigs[3] = "cancelRequest(uint256)";
        requestSigs[4] = "getRequestsByStatus(uint8)";
        requestSigs[5] = "getLastRequestId()";
        requestSigs[6] = "getRequestById(uint256)";
        vault.setSelectorsBySignatures(requestSigs, address(requestModule));

        string[] memory tokenSigs = new string[](3);
        tokenSigs[0] = "setToken(address,bool)";
        tokenSigs[1] = "getToken(address)";
        tokenSigs[2] = "getAllTokens()";
        vault.setSelectorsBySignatures(tokenSigs, address(tokenModule));

        string[] memory specificHelperSigs = new string[](1);
        specificHelperSigs[0] = "setCategorySpentForTest(uint64,uint128)";
        vault.setSelectorsBySignatures(
            specificHelperSigs,
            address(specificModule)
        );
    }

    /// @notice Helper interno para setSelectorsBySignatures
    function _setSelectors(
        FamilyVault vault,
        address module,
        string[] memory sigs
    ) internal {
        vault.setSelectorsBySignatures(sigs, module);
    }
}
