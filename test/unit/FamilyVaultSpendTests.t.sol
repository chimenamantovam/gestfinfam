// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {FamilyVault} from "../../src/contracts/FamilyVault.sol";
import {FamilyVaultBase} from "../../src/contracts/base/FamilyVaultBase.sol";
import {FamilyVaultTestHelper} from "../helpers/FamilyVaultTestHelper.sol";
import {MockERC20} from "../mock/MockERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IFamilyVaultAllowance} from "../interfaces/IFamilyVaultAllowance.sol";
import {IFamilyVaultCategory} from "../interfaces/IFamilyVaultCategory.sol";
import {IFamilyVaultFund} from "../interfaces/IFamilyVaultFund.sol";
import {IFamilyVaultMember} from "../interfaces/IFamilyVaultMember.sol";
import {IFamilyVaultToken} from "../interfaces/IFamilyVaultToken.sol";

contract FamilyVaultSpendTests is Test, FamilyVaultTestHelper {
    using SafeERC20 for MockERC20;

    FamilyVault vault;
    MockERC20 token;

    address public owner;
    address public user;
    address public spender;
    address public recipient;

    uint64 constant CATEGORY_ID = 1;

    function setUp() public {
        owner = address(0x1);
        user = address(0x2);
        spender = address(0x3);
        recipient = address(0x4);

        vm.startPrank(owner);
        // Deploy contratos
        vault = deployFamilyVaultWithProxy(owner);
        token = new MockERC20();

        // Adiciona owner como membro

        IFamilyVaultMember(address(vault)).addMember(owner, vault.OWNER_ROLE());

        // Adiciona spender
        IFamilyVaultMember(address(vault)).addMember(
            spender,
            vault.SPENDER_ROLE()
        );

        // Habilita token permitido
        IFamilyVaultToken(address(vault)).setToken(address(token), true);

        // Cria categoria com token ERC20
        IFamilyVaultCategory(address(vault)).createCategory(
            unicode"Alimentação",
            100 ether,
            address(token)
        );

        // Ajusta allowance do spender
        IFamilyVaultAllowance(address(vault)).setAllowance(
            spender,
            CATEGORY_ID,
            50 ether
        );

        // Transferência inicial para o Vault ter saldo
        token.safeTransfer(address(vault), 100 ether);

        vm.stopPrank();
    }

    function test_Spend_Success() public {
        vm.startPrank(spender);

        IFamilyVaultFund(address(vault)).spend(
            CATEGORY_ID,
            10 ether,
            recipient
        );

        vm.stopPrank();

        // Verifica saldo do recipient
        assertEq(token.balanceOf(recipient), 10 ether);

        // Allowance deve ter sido reduzido
        (
            uint128 totalAllowance,
            uint128 availableAllowance
        ) = IFamilyVaultAllowance(address(vault)).getAllowance(
                spender,
                CATEGORY_ID
            );
        assertEq(totalAllowance, 40 ether); // começou com 50, gastou 10
        assertEq(availableAllowance, 40 ether);

        // Gasto da categoria deve aumentar
        (, , , uint128 spent, , , ) = IFamilyVaultCategory(address(vault))
            .getCategoryById(CATEGORY_ID);
        assertEq(spent, 10 ether);
    }

    function test_Revert_Spend_ZeroAmount() public {
        vm.startPrank(spender);
        vm.expectRevert(FamilyVaultBase.ZeroAmountNotAllowed.selector);

        IFamilyVaultFund(address(vault)).spend(CATEGORY_ID, 0, recipient);

        vm.stopPrank();
    }

    function test_Revert_Spend_InvalidRecipient() public {
        vm.startPrank(spender);
        vm.expectRevert(FamilyVaultBase.InvalidRecipientAddress.selector);

        IFamilyVaultFund(address(vault)).spend(
            CATEGORY_ID,
            5 ether,
            address(0)
        );

        vm.stopPrank();
    }

    function test_Revert_Spend_CategoryNotSet() public {
        vm.startPrank(spender);
        vm.expectRevert(FamilyVaultBase.CategoryNotSet.selector);

        IFamilyVaultFund(address(vault)).spend(999, 5 ether, recipient); // ID que não existe

        vm.stopPrank();
    }

    function test_Revert_Spend_CategoryInactive() public {
        vm.startPrank(owner);
        IFamilyVaultCategory(address(vault)).deactivateCategory(CATEGORY_ID);
        vm.stopPrank();

        vm.startPrank(spender);
        vm.expectRevert(FamilyVaultBase.CategoryInactive.selector);

        IFamilyVaultFund(address(vault)).spend(CATEGORY_ID, 5 ether, recipient);

        vm.stopPrank();
    }

    function test_Revert_Spend_InsufficientAllowance() public {
        vm.startPrank(spender);
        vm.expectRevert(FamilyVaultBase.InsufficientAllowance.selector);

        IFamilyVaultFund(address(vault)).spend(
            CATEGORY_ID,
            60 ether,
            recipient
        ); // allowance = 50

        vm.stopPrank();
    }

    function test_Revert_Spend_MemberPaused() public {
        vm.startPrank(owner);
        IFamilyVaultMember(address(vault)).pauseMember(spender);
        vm.stopPrank();

        vm.startPrank(spender);
        vm.expectRevert(FamilyVaultBase.MemberIsPaused.selector);

        IFamilyVaultFund(address(vault)).spend(CATEGORY_ID, 5 ether, recipient);

        vm.stopPrank();
    }

    function test_Revert_Spend_ContractPaused() public {
        vm.startPrank(owner);
        vault.pause(); // Pausa o contrato
        vm.stopPrank();

        vm.startPrank(spender);
        vm.expectRevert();
        IFamilyVaultFund(address(vault)).spend(CATEGORY_ID, 5 ether, recipient);
        vm.stopPrank();
    }

    function test_Spend_ExactAllowance() public {
        vm.startPrank(spender);

        // allowance do spender = 50
        IFamilyVaultFund(address(vault)).spend(
            CATEGORY_ID,
            50 ether,
            recipient
        );

        vm.stopPrank();

        // saldo do recipient
        assertEq(token.balanceOf(recipient), 50 ether);

        // allowance deve zerar
        (
            uint128 totalAllowance,
            uint128 availableAllowance
        ) = IFamilyVaultAllowance(address(vault)).getAllowance(
                spender,
                CATEGORY_ID
            );
        assertEq(totalAllowance, 0);
        assertEq(availableAllowance, 0);
    }

    function test_Revert_Spend_ExceedsVaultBalance() public {
        // Reduz saldo do Vault para 20
        vm.startPrank(owner);
        token.safeTransfer(address(0xdead), 900 ether); // sobra 20
        vm.stopPrank();

        vm.startPrank(spender);
        vm.expectRevert(); // revert esperado se gastar mais do que saldo do Vault
        IFamilyVaultFund(address(vault)).spend(
            CATEGORY_ID,
            100 ether,
            recipient
        );
        vm.stopPrank();
    }
}
