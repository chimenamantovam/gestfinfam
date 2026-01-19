// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {FamilyVault} from "../../src/contracts/FamilyVault.sol";
import {FamilyVaultBase} from "../../src/contracts/base/FamilyVaultBase.sol";
import {FamilyVaultTestHelper} from "../helpers/FamilyVaultTestHelper.sol";
import {MockERC20} from "../mock/MockERC20.sol";

import {IFamilyVaultCategory} from "../interfaces/IFamilyVaultCategory.sol";
import {IFamilyVaultToken} from "../interfaces/IFamilyVaultToken.sol";
import {IFamilyVaultTestHelper} from "../interfaces/IFamilyVaultTestHelper.sol";

import {FamilyVaultTypes} from "../../src/contracts/types/FamilyVaultTypes.sol";

contract FamilyVaultCategoryTests is Test, FamilyVaultTestHelper {
    FamilyVault vault;
    MockERC20 public token;

    address public owner;
    address public user;
    address public user2;

    event CategoryReset(uint64 indexed id, uint256 timestamp);

    function setUp() public {
        owner = address(0x1);
        user = address(0x2);
        user2 = address(0x3);

        vm.startPrank(owner);
        vault = deployFamilyVaultWithProxy(owner);

        token = new MockERC20();

        // Ativar token de teste por padrão
        IFamilyVaultToken(address(vault)).setToken(address(token), true);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                CREATE CATEGORY
    //////////////////////////////////////////////////////////////*/

    function test_CreateCategory_WithETH() public {
        vm.startPrank(owner);

        IFamilyVaultCategory(address(vault)).createCategory(
            unicode"Alimentação",
            1000 ether,
            address(0)
        );

        (
            ,
            string memory categoryName,
            uint128 categoryMonthlyLimit,
            uint128 categorySpent,
            ,
            address categoryToken,
            bool categoryActive
        ) = IFamilyVaultCategory(address(vault)).getCategoryById(1);

        assertEq(categoryName, unicode"Alimentação");
        assertEq(categoryMonthlyLimit, 1000 ether);
        assertEq(categoryToken, address(0));
        assertTrue(categoryActive);
        assertEq(categorySpent, 0);

        vm.stopPrank();
    }

    function test_CreateCategory_WithERC20Token() public {
        vm.startPrank(owner);

        IFamilyVaultCategory(address(vault)).createCategory(
            unicode"Educação",
            500 ether,
            address(token)
        );

        (, , , , , address categoryToken, ) = IFamilyVaultCategory(
            address(vault)
        ).getCategoryById(1);
        assertEq(categoryToken, address(token));

        vm.stopPrank();
    }

    function test_Revert_CreateCategory_NameRequired() public {
        vm.startPrank(owner);

        vm.expectRevert(FamilyVaultBase.CategoryNameRequired.selector);
        IFamilyVaultCategory(address(vault)).createCategory(
            "",
            1000 ether,
            address(0)
        );

        vm.stopPrank();
    }

    function test_Revert_CreateCategory_LimitRequired() public {
        vm.startPrank(owner);

        vm.expectRevert(FamilyVaultBase.CategoryLimitRequired.selector);
        IFamilyVaultCategory(address(vault)).createCategory(
            "Aluguel",
            0,
            address(0)
        );

        vm.stopPrank();
    }

    function test_Revert_CreateCategory_TokenNotAllowed() public {
        vm.startPrank(owner);

        // Desativa o token para simular erro
        IFamilyVaultToken(address(vault)).setToken(address(token), false);

        vm.expectRevert(FamilyVaultBase.TokenNotAllowed.selector);
        IFamilyVaultCategory(address(vault)).createCategory(
            "Transporte",
            100 ether,
            address(token)
        );

        vm.stopPrank();
    }

    function test_Revert_CreateCategory_NotAuthorized() public {
        vm.startPrank(user);

        vm.expectRevert(FamilyVaultBase.NotAuthorized.selector);
        IFamilyVaultCategory(address(vault)).createCategory(
            unicode"Saúde",
            200 ether,
            address(0)
        );

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                UPDATE CATEGORY
    //////////////////////////////////////////////////////////////*/

    function test_UpdateCategory_Normal() public {
        vm.startPrank(owner);

        IFamilyVaultCategory(address(vault)).createCategory(
            unicode"Alimentação",
            100 ether,
            address(0)
        );

        IFamilyVaultCategory(address(vault)).updateCategory(
            1,
            unicode"Alimentação Atualizada",
            200 ether,
            address(token)
        );

        (
            ,
            string memory categoryName,
            uint128 categoryMonthlyLimit,
            ,
            ,
            address categoryToken,

        ) = IFamilyVaultCategory(address(vault)).getCategoryById(1);
        assertEq(categoryName, unicode"Alimentação Atualizada");
        assertEq(categoryMonthlyLimit, 200 ether);
        assertEq(categoryToken, address(token));

        vm.stopPrank();
    }

    function test_Revert_UpdateCategory_NotSet() public {
        vm.startPrank(owner);

        vm.expectRevert(FamilyVaultBase.CategoryNotSet.selector);
        IFamilyVaultCategory(address(vault)).updateCategory(
            99,
            "Inexistente",
            100 ether,
            address(0)
        );

        vm.stopPrank();
    }

    function test_Revert_UpdateCategory_Inactive() public {
        vm.startPrank(owner);

        IFamilyVaultCategory(address(vault)).createCategory(
            "Transporte",
            100 ether,
            address(0)
        );
        IFamilyVaultCategory(address(vault)).deactivateCategory(1);

        vm.expectRevert(FamilyVaultBase.CategoryInactive.selector);
        IFamilyVaultCategory(address(vault)).updateCategory(
            1,
            "Novo nome",
            200 ether,
            address(0)
        );

        vm.stopPrank();
    }

    function test_Revert_UpdateCategory_TokenNotAllowed() public {
        vm.startPrank(owner);

        // Cria a categoria com token nativo da rede
        IFamilyVaultCategory(address(vault)).createCategory(
            unicode"Saúde",
            100 ether,
            address(0)
        );

        // Desativa o token antes de tentar usar
        IFamilyVaultToken(address(vault)).setToken(address(token), false);

        vm.expectRevert(FamilyVaultBase.TokenNotAllowed.selector);
        IFamilyVaultCategory(address(vault)).updateCategory(
            1,
            unicode"Saúde",
            150 ether,
            address(token)
        );

        vm.stopPrank();
    }

    function test_Revert_UpdateCategory_NotAuthorized() public {
        vm.startPrank(owner);
        IFamilyVaultCategory(address(vault)).createCategory(
            unicode"Educação",
            100 ether,
            address(0)
        );
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert(FamilyVaultBase.NotAuthorized.selector);
        IFamilyVaultCategory(address(vault)).updateCategory(
            1,
            unicode"Educação",
            150 ether,
            address(0)
        );
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                     DEACTIVATE / REACTIVATE CATEGORY
    //////////////////////////////////////////////////////////////*/

    function test_Deactivate_Reactivate_Category() public {
        vm.startPrank(owner);

        IFamilyVaultCategory(address(vault)).createCategory(
            "Lazer",
            100 ether,
            address(0)
        );

        IFamilyVaultCategory(address(vault)).deactivateCategory(1);
        (, , , , , , bool categoryActive) = IFamilyVaultCategory(address(vault))
            .getCategoryById(1);
        assertFalse(categoryActive);

        IFamilyVaultCategory(address(vault)).reactivateCategory(1);
        (, , , , , , categoryActive) = IFamilyVaultCategory(address(vault))
            .getCategoryById(1);
        assertTrue(categoryActive);

        vm.stopPrank();
    }

    function test_Revert_DeactivateCategory_NotSet() public {
        vm.startPrank(owner);

        vm.expectRevert(FamilyVaultBase.CategoryNotSet.selector);
        IFamilyVaultCategory(address(vault)).deactivateCategory(99);

        vm.stopPrank();
    }

    function test_Revert_DeactivateCategory_NotAuthorized() public {
        vm.startPrank(owner);
        IFamilyVaultCategory(address(vault)).createCategory(
            unicode"Saúde",
            100 ether,
            address(0)
        );
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert(FamilyVaultBase.NotAuthorized.selector);
        IFamilyVaultCategory(address(vault)).deactivateCategory(1);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                           RESET CATEGORY PERIOD
    //////////////////////////////////////////////////////////////*/

    function test_ResetCategoryPeriod() public {
        vm.startPrank(owner);

        IFamilyVaultCategory(address(vault)).createCategory(
            unicode"Alimentação",
            100 ether,
            address(0)
        );

        // Simula gasto manualmente
        //  IFamilyVaultCategory(address(vault)).setCategorySpentForTest(1, 50 ether);

        vm.expectEmit(true, true, false, true);
        emit CategoryReset(1, block.timestamp);

        IFamilyVaultCategory(address(vault)).resetCategoryPeriod(1);

        (
            ,
            ,
            ,
            uint128 categorySpent,
            uint64 categoryPeriodStart,
            ,

        ) = IFamilyVaultCategory(address(vault)).getCategoryById(1);

        assertEq(categorySpent, 0);
        assertEq(categoryPeriodStart, block.timestamp);

        vm.stopPrank();
    }

    function test_SetCategorySpentForTest() public {
        uint128 monthly = 100e18;
        vm.prank(owner);
        IFamilyVaultCategory(address(vault)).createCategory(
            unicode"Alimentação",
            monthly,
            address(0)
        );

        // forçar spent
        vm.prank(owner);
        IFamilyVaultTestHelper(address(vault)).setCategorySpentForTest(
            1,
            50e18
        );

        (, , , uint128 spent, , , ) = IFamilyVaultCategory(address(vault))
            .getCategoryById(1);

        assertEq(spent, 50e18);
    }

    /*//////////////////////////////////////////////////////////////
                           GET CATEGORY BY ID
    //////////////////////////////////////////////////////////////*/

    function test_GetCategoryById_Success() public {
        vm.startPrank(owner);

        IFamilyVaultCategory(address(vault)).createCategory(
            unicode"Educação",
            200 ether,
            address(0)
        );

        (
            ,
            string memory categoryName,
            uint128 categoryMonthlyLimit,
            ,
            ,
            address categoryToken,
            bool categoryActive
        ) = IFamilyVaultCategory(address(vault)).getCategoryById(1);

        assertEq(categoryName, unicode"Educação");
        assertEq(categoryMonthlyLimit, 200 ether);
        assertEq(categoryToken, address(0));
        assertTrue(categoryActive);

        vm.stopPrank();
    }

    function test_Revert_GetCategoryById_NotSet() public {
        vm.startPrank(owner);

        vm.expectRevert(FamilyVaultBase.CategoryNotSet.selector);
        IFamilyVaultCategory(address(vault)).getCategoryById(99);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                           GET ALL CATEGORIES
    //////////////////////////////////////////////////////////////*/

    function test_GetAllCategories_WithData() public {
        vm.startPrank(owner);

        IFamilyVaultCategory(address(vault)).createCategory(
            unicode"Alimentação",
            100 ether,
            address(0)
        );
        IFamilyVaultCategory(address(vault)).createCategory(
            "Transporte",
            50 ether,
            address(0)
        );

        FamilyVaultTypes.Category[] memory categories = IFamilyVaultCategory(
            address(vault)
        ).getAllCategories();
        assertEq(categories.length, 2);
        assertEq(categories[0].name, unicode"Alimentação");
        assertEq(categories[1].name, "Transporte");

        vm.stopPrank();
    }

    function test_GetAllCategories_Empty() public view {
        FamilyVaultTypes.Category[] memory categories = IFamilyVaultCategory(
            address(vault)
        ).getAllCategories();
        assertEq(categories.length, 0);
    }
}
