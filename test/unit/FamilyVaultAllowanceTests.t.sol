// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {FamilyVault} from "../../src/contracts/FamilyVault.sol";
import {FamilyVaultBase} from "../../src/contracts/base/FamilyVaultBase.sol";
import {FamilyVaultTestHelper} from "../helpers/FamilyVaultTestHelper.sol";
import {MockERC20} from "../mock/MockERC20.sol";

import {IFamilyVaultAllowance} from "../interfaces/IFamilyVaultAllowance.sol";
import {IFamilyVaultCategory} from "../interfaces/IFamilyVaultCategory.sol";
import {IFamilyVaultMember} from "../interfaces/IFamilyVaultMember.sol";
import {IFamilyVaultToken} from "../interfaces/IFamilyVaultToken.sol";
import {IFamilyVaultTestHelper} from "../interfaces/IFamilyVaultTestHelper.sol";

contract FamilyVaultAllowanceTests is Test, FamilyVaultTestHelper {
    FamilyVault public vault;

    MockERC20 token;
    address owner;
    address member;
    uint64 categoryId;

    event AllowanceSet(
        address indexed member,
        uint64 categoryId,
        uint128 amount,
        address token
    );
    event AllowanceAdjusted(
        address indexed member,
        uint64 categoryId,
        uint128 amount,
        address token
    );

    function setUp() public {
        owner = address(0x1);
        member = address(0x2);

        vm.startPrank(owner);
        vault = deployFamilyVaultWithProxy(owner);
        token = new MockERC20();

        // Configura token permitido
        IFamilyVaultToken(address(vault)).setToken(address(token), true);

        // Cria categoria usando token nativo (token = address(0))
        IFamilyVaultCategory(address(vault)).createCategory(
            unicode"Alimentação",
            1000 ether,
            address(0)
        );

        (categoryId, , , , , , ) = IFamilyVaultCategory(address(vault))
            .getCategoryById(1);

        // Adiciona membro
        IFamilyVaultMember(address(vault)).addMember(
            member,
            vault.SPENDER_ROLE()
        );

        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------------------------------- */
    /*                                    1. setAllowance()                                          */
    /* ---------------------------------------------------------------------------------------------- */

    // ✅ Define allowance corretamente
    function test_SetAllowance_Success() public {
        vm.startPrank(owner);

        vm.expectEmit(true, true, false, true);
        emit AllowanceSet(member, 1, 100 ether, address(0));

        IFamilyVaultAllowance(address(vault)).setAllowance(
            member,
            1,
            100 ether
        );

        (uint128 total, uint128 available) = IFamilyVaultAllowance(
            address(vault)
        ).getAllowance(member, 1);
        assertEq(total, 100 ether);
        assertEq(available, 100 ether);

        vm.stopPrank();
    }

    // ❗ Revert: Membro inexistente
    function test_Revert_SetAllowance_NotMember() public {
        address nonMember = address(0x5);

        vm.startPrank(owner);
        vm.expectRevert(FamilyVaultBase.NotMember.selector);

        IFamilyVaultAllowance(address(vault)).setAllowance(
            nonMember,
            1,
            50 ether
        );
        vm.stopPrank();
    }

    // ❗ Revert: Categoria inexistente
    function test_Revert_SetAllowance_CategoryNotSet() public {
        vm.startPrank(owner);
        vm.expectRevert(FamilyVaultBase.CategoryNotSet.selector);

        IFamilyVaultAllowance(address(vault)).setAllowance(
            member,
            99,
            50 ether
        );
        vm.stopPrank();
    }

    // ❗ Revert: Membro pausado
    function test_Revert_SetAllowance_MemberPaused() public {
        vm.startPrank(owner);
        IFamilyVaultMember(address(vault)).pauseMember(member);

        vm.expectRevert(FamilyVaultBase.MemberIsPaused.selector);
        IFamilyVaultAllowance(address(vault)).setAllowance(member, 1, 50 ether);

        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------------------------------- */
    /*                                    2. getAllowance()                                          */
    /* ---------------------------------------------------------------------------------------------- */

    // ✅ Deve retornar totalAllowance e availableAllowance corretamente
    function test_GetAllowance_BasicScenario() public {
        vm.startPrank(owner);

        IFamilyVaultAllowance(address(vault)).setAllowance(
            member,
            1,
            100 ether
        );

        (uint128 total, uint128 available) = IFamilyVaultAllowance(
            address(vault)
        ).getAllowance(member, 1);

        assertEq(total, 100 ether);
        assertEq(available, 100 ether);

        vm.stopPrank();
    }

    // ❗ Novo período deve resetar automaticamente o spent sem alterar storage
    function test_GetAllowance_ResetPeriodLogic() public {
        vm.startPrank(owner);

        IFamilyVaultAllowance(address(vault)).setAllowance(
            member,
            1,
            100 ether
        );

        // Simula gasto da categoria
        IFamilyVaultTestHelper(address(vault)).setCategorySpentForTest(
            1,
            50 ether
        );

        // Avança o tempo em 31 dias (período > 30 dias)
        vm.warp(block.timestamp + 31 days);

        (uint128 total, uint128 available) = IFamilyVaultAllowance(
            address(vault)
        ).getAllowance(member, 1);

        // Como período foi resetado, spent deve ser considerado 0
        assertEq(total, 100 ether);
        assertEq(available, 100 ether);

        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------------------------------- */
    /*                                    3. adjustAllowance()                                       */
    /* ---------------------------------------------------------------------------------------------- */

    // ✅ Ajuste positivo (aumentar allowance)
    function test_AdjustAllowance_Positive() public {
        vm.startPrank(owner);

        IFamilyVaultAllowance(address(vault)).setAllowance(member, 1, 50 ether);

        vm.expectEmit(true, true, false, true);
        emit AllowanceAdjusted(member, 1, 70 ether, address(0));

        IFamilyVaultAllowance(address(vault)).adjustAllowance(
            member,
            1,
            int128(20 ether)
        );

        (uint128 total, ) = IFamilyVaultAllowance(address(vault)).getAllowance(
            member,
            1
        );
        assertEq(total, 70 ether);

        vm.stopPrank();
    }

    // ✅ Ajuste negativo (reduzir allowance)
    function test_AdjustAllowance_Negative() public {
        vm.startPrank(owner);

        IFamilyVaultAllowance(address(vault)).setAllowance(member, 1, 50 ether);

        vm.expectEmit(true, true, false, true);
        emit AllowanceAdjusted(member, 1, 30 ether, address(0));

        IFamilyVaultAllowance(address(vault)).adjustAllowance(
            member,
            1,
            -int128(20 ether)
        );

        (uint128 total, ) = IFamilyVaultAllowance(address(vault)).getAllowance(
            member,
            1
        );
        assertEq(total, 30 ether);

        vm.stopPrank();
    }

    // ❗ Revert: Reduzir abaixo de 0
    function test_Revert_AdjustAllowance_NegativeBelowZero() public {
        vm.startPrank(owner);

        IFamilyVaultAllowance(address(vault)).setAllowance(member, 1, 10 ether);

        vm.expectRevert(FamilyVaultBase.AllowanceCannotBeNegative.selector);

        IFamilyVaultAllowance(address(vault)).adjustAllowance(
            member,
            1,
            -int128(20 ether)
        );

        vm.stopPrank();
    }

    // ❗ Revert: Membro pausado
    function test_Revert_AdjustAllowance_MemberPaused() public {
        vm.startPrank(owner);

        IFamilyVaultAllowance(address(vault)).setAllowance(member, 1, 50 ether);
        IFamilyVaultMember(address(vault)).pauseMember(member);

        vm.expectRevert(FamilyVaultBase.MemberIsPaused.selector);

        IFamilyVaultAllowance(address(vault)).adjustAllowance(
            member,
            1,
            int128(10 ether)
        );

        vm.stopPrank();
    }

    function test_AdjustAllowance_NegativeToExactZero() public {
        vm.startPrank(owner);
        // Define allowance inicial
        IFamilyVaultAllowance(address(vault)).setAllowance(
            member,
            categoryId,
            10 ether
        );

        // Ajusta exatamente -10 ether → total deve ser 0
        IFamilyVaultAllowance(address(vault)).adjustAllowance(
            member,
            categoryId,
            -int128(10 ether)
        );

        (uint128 total, uint128 available) = IFamilyVaultAllowance(
            address(vault)
        ).getAllowance(member, categoryId);
        assertEq(total, 0, "Total allowance deve ser 0");
        assertEq(available, 0, "Available allowance deve ser 0");
        vm.stopPrank();
    }
}
