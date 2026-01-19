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
import {IFamilyVaultRequest} from "../interfaces/IFamilyVaultRequest.sol";
import {IFamilyVaultToken} from "../interfaces/IFamilyVaultToken.sol";

contract FamilyVaultPauseTests is Test, FamilyVaultTestHelper {
    using SafeERC20 for MockERC20;

    FamilyVault vault;
    MockERC20 token;

    address owner = address(0x1);
    address guardian = address(0x2);
    address spender = address(0x3);
    address recipient = address(0x4);

    uint64 constant CATEGORY_ID = 1;

    function setUp() public {
        // Inicia prank como owner para deploy
        vm.startPrank(owner);
        vault = deployFamilyVaultWithProxy(owner);

        // Configura roles iniciais
        IFamilyVaultMember(address(vault)).addMember(owner, vault.OWNER_ROLE());
        IFamilyVaultMember(address(vault)).addMember(
            guardian,
            vault.GUARDIAN_ROLE()
        );
        IFamilyVaultMember(address(vault)).addMember(
            spender,
            vault.SPENDER_ROLE()
        );

        // Cria token mock e adiciona à lista de tokens permitidos
        token = new MockERC20();
        IFamilyVaultToken(address(vault)).setToken(address(token), true);

        // Cria uma categoria ativa
        IFamilyVaultCategory(address(vault)).createCategory(
            unicode"Alimentação",
            100 ether,
            address(token)
        );

        // Faz um depósito no contrato
        token.safeTransfer(owner, 100 ether);
        token.approve(address(vault), 100 ether);
        IFamilyVaultFund(address(vault)).depositERC20(
            address(token),
            100 ether
        );

        // Define allowance para o spender
        IFamilyVaultAllowance(address(vault)).adjustAllowance(
            spender,
            CATEGORY_ID,
            50 ether
        );

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                SUCCESS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deve permitir que OWNER pause o contrato
    function test_Pause_ByOwner_Success() public {
        vm.startPrank(owner);
        vault.pause();
        vm.stopPrank();

        assertTrue(vault.paused(), "Contrato deveria estar pausado");
    }

    /// @notice Deve permitir que GUARDIAN pause o contrato
    function test_Pause_ByGuardian_Success() public {
        vm.startPrank(guardian);
        vault.pause();
        vm.stopPrank();

        assertTrue(vault.paused(), "Contrato deveria estar pausado");
    }

    /// @notice Deve permitir que OWNER despause o contrato
    function test_Unpause_ByOwner_Success() public {
        vm.startPrank(owner);
        vault.pause();
        vault.unpause();
        vm.stopPrank();

        assertFalse(vault.paused(), "Contrato deveria estar ativo");
    }

    /// @notice pause() deve travar spend() e approveRequest()
    function test_Pause_Blocks_Spend_And_ApproveRequest() public {
        vm.startPrank(owner);
        vault.pause();
        vm.stopPrank();

        vm.startPrank(spender);
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("EnforcedPause()")))
        );
        IFamilyVaultFund(address(vault)).spend(CATEGORY_ID, 1 ether, recipient);
        vm.stopPrank();

        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("EnforcedPause()")))
        );
        IFamilyVaultRequest(address(vault)).approveRequest(1, owner); // ID fictício só para validar revert
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                REVERTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Não deve permitir que endereço sem OWNER ou GUARDIAN pause
    function test_Revert_Pause_NotAuthorized() public {
        address randomUser = address(0x99);

        vm.startPrank(randomUser);
        vm.expectRevert(FamilyVaultBase.NotAuthorized.selector);
        vault.pause();
        vm.stopPrank();
    }

    /// @notice Não deve permitir que GUARDIAN despause
    function test_Revert_Unpause_NotAuthorized() public {
        // Primeiro pausa como GUARDIAN
        vm.startPrank(guardian);
        vault.pause();
        vm.stopPrank();

        // Depois tenta despausar como GUARDIAN (não permitido)
        vm.startPrank(guardian);
        vm.expectRevert(FamilyVaultBase.NotAuthorized.selector);
        vault.unpause();
        vm.stopPrank();
    }
}
