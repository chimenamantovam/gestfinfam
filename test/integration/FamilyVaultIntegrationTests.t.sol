// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {FamilyVault} from "../../src/contracts/FamilyVault.sol";
import {MockERC20} from "../mock/MockERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {FamilyVaultTestHelper} from "../helpers/FamilyVaultTestHelper.sol";

import {IFamilyVaultAllowance} from "../interfaces/IFamilyVaultAllowance.sol";
import {IFamilyVaultCategory} from "../interfaces/IFamilyVaultCategory.sol";
import {IFamilyVaultFund} from "../interfaces/IFamilyVaultFund.sol";
import {IFamilyVaultMember} from "../interfaces/IFamilyVaultMember.sol";
import {IFamilyVaultRequest} from "../interfaces/IFamilyVaultRequest.sol";
import {IFamilyVaultToken} from "../interfaces/IFamilyVaultToken.sol";

import {FamilyVaultTypes} from "../../src/contracts/types/FamilyVaultTypes.sol";

contract FamilyVaultIntegrationTests is Test, FamilyVaultTestHelper {
    using SafeERC20 for MockERC20;

    FamilyVault vault;
    MockERC20 token;

    address owner = address(0x1);
    address spender = address(0x2);
    address guardian = address(0x3);
    address receiver = address(0x4);

    uint64 ethCategoryId;
    uint64 tokenCategoryId;

    function setUp() public {
        vm.startPrank(owner);
        vault = deployFamilyVaultWithProxy(owner);

        token = new MockERC20();
        IFamilyVaultToken(address(vault)).setToken(address(token), true);

        IFamilyVaultMember(address(vault)).addMember(
            spender,
            vault.SPENDER_ROLE()
        );
        IFamilyVaultMember(address(vault)).addMember(
            guardian,
            vault.GUARDIAN_ROLE()
        );

        IFamilyVaultCategory(address(vault)).createCategory(
            "Token Nativo Category",
            1e18,
            address(0)
        );

        IFamilyVaultCategory(address(vault)).createCategory(
            "Token ERC20 Category",
            1e18,
            address(token)
        );

        ethCategoryId =
            IFamilyVaultCategory(address(vault)).getLastCategoryId() -
            1;
        tokenCategoryId = IFamilyVaultCategory(address(vault))
            .getLastCategoryId();

        token.safeTransfer(owner, 2e18);
        vm.stopPrank();

        // Distribui token nativo e tokens ERC20 para spender
        vm.deal(spender, 5e17); // 0.5 ETH

        vm.startPrank(owner);
        token.safeTransfer(spender, 2e18);
        vm.stopPrank();
    }

    function testInitialOwner() public view {
        assertTrue(
            vault.hasRole(vault.OWNER_ROLE(), owner),
            "Owner inicial incorreto"
        );
    }

    function testETHDepositAndSpendFlow() public {
        // Spender deposita token nativo na vault
        vm.prank(spender);
        IFamilyVaultFund(address(vault)).depositNative{value: 1e17}(); // 0.1 ETH

        assertEq(
            IFamilyVaultFund(address(vault)).contractBalance(address(0)),
            1e17
        );

        // Owner define allowance
        vm.prank(owner);
        IFamilyVaultAllowance(address(vault)).setAllowance(
            spender,
            ethCategoryId,
            5e16
        ); // 0.05 ETH

        (uint128 total, uint128 available) = IFamilyVaultAllowance(
            address(vault)
        ).getAllowance(spender, ethCategoryId);
        assertEq(total, 5e16);
        assertEq(available, 5e16);

        // Spender gasta token nativo
        vm.prank(spender);
        IFamilyVaultFund(address(vault)).spend(ethCategoryId, 5e16, receiver);

        assertEq(address(receiver).balance, 5e16);

        // Allowance deve diminuir
        (, uint128 availableAfter) = IFamilyVaultAllowance(address(vault))
            .getAllowance(spender, ethCategoryId);
        assertEq(availableAfter, 0);
    }

    function testERC20DepositAndSpendFlow() public {
        vm.startPrank(spender);
        token.approve(address(vault), 1e18);
        IFamilyVaultFund(address(vault)).depositERC20(address(token), 1e18);
        vm.stopPrank();

        assertEq(
            IFamilyVaultFund(address(vault)).contractBalance(address(token)),
            1e18
        );

        // Owner define allowance
        vm.prank(owner);
        IFamilyVaultAllowance(address(vault)).setAllowance(
            spender,
            tokenCategoryId,
            5e17
        ); // 0.5

        (uint128 total, uint128 available) = IFamilyVaultAllowance(
            address(vault)
        ).getAllowance(spender, tokenCategoryId);
        assertEq(total, 5e17);
        assertEq(available, 5e17);

        // Spender gasta ERC20
        vm.prank(spender);
        IFamilyVaultFund(address(vault)).spend(tokenCategoryId, 5e17, receiver);

        assertEq(token.balanceOf(receiver), 5e17);

        // Allowance deve zerar
        (, uint128 availableAfter) = IFamilyVaultAllowance(address(vault))
            .getAllowance(spender, tokenCategoryId);
        assertEq(availableAfter, 0);
    }

    function testRequestApprovalFlow() public {
        // Owner define allowance e deposita token nativo
        vm.prank(owner);
        IFamilyVaultAllowance(address(vault)).setAllowance(
            spender,
            ethCategoryId,
            1e17
        );
        vm.prank(spender);
        IFamilyVaultFund(address(vault)).depositNative{value: 1e17}();

        // Spender cria request
        vm.prank(spender);
        uint256 requestId = IFamilyVaultRequest(address(vault)).createRequest(
            ethCategoryId,
            5e16,
            "Dinner"
        );

        (
            address requester,
            ,
            uint128 amount,
            FamilyVaultTypes.RequestStatus status,

        ) = IFamilyVaultRequest(address(vault)).getRequestById(requestId);
        assertEq(requester, spender);
        assertEq(amount, 5e16);
        assertEq(uint(status), uint(FamilyVaultTypes.RequestStatus.PENDING));

        // Owner aprova request
        vm.prank(owner);
        IFamilyVaultRequest(address(vault)).approveRequest(requestId, receiver);

        // Status atualizado
        (, , , status, ) = IFamilyVaultRequest(address(vault)).getRequestById(
            requestId
        );
        assertEq(uint(status), uint(FamilyVaultTypes.RequestStatus.APPROVED));

        // token nativo transferido
        assertEq(address(receiver).balance, 5e16);
    }

    function testPauseAndUnpauseFlow() public {
        // Owner pausa contrato
        vm.prank(owner);
        vault.pause();

        vm.prank(spender);
        vm.expectRevert();
        IFamilyVaultFund(address(vault)).spend(ethCategoryId, 1e16, receiver);

        // Owner despausa
        vm.prank(owner);
        vault.unpause();

        // Adiciona saldo em token nativo para o contrato
        IFamilyVaultFund(address(vault)).depositNative{value: 1e18}();

        // Define allowance para o spender
        vm.prank(owner);
        IFamilyVaultAllowance(address(vault)).setAllowance(
            spender,
            ethCategoryId,
            1e16
        );

        // Agora o spender pode gastar
        vm.prank(spender);
        IFamilyVaultFund(address(vault)).spend(ethCategoryId, 1e16, receiver);

        assertEq(address(receiver).balance, 1e16);
    }
}
