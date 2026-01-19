// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {FamilyVault} from "../../src/contracts/FamilyVault.sol";
import {FamilyVaultBase} from "../../src/contracts/base/FamilyVaultBase.sol";
import {MockERC20} from "../mock/MockERC20.sol";
import {FamilyVaultTestHelper} from "../helpers/FamilyVaultTestHelper.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IFamilyVaultAllowance} from "../interfaces/IFamilyVaultAllowance.sol";
import {IFamilyVaultCategory} from "../interfaces/IFamilyVaultCategory.sol";
import {IFamilyVaultFund} from "../interfaces/IFamilyVaultFund.sol";
import {IFamilyVaultMember} from "../interfaces/IFamilyVaultMember.sol";
import {IFamilyVaultRequest} from "../interfaces/IFamilyVaultRequest.sol";
import {IFamilyVaultToken} from "../interfaces/IFamilyVaultToken.sol";

import {FamilyVaultTypes} from "../../src/contracts/types/FamilyVaultTypes.sol";

contract FamilyVaultFuzzTest is Test, FamilyVaultTestHelper {
    using SafeERC20 for MockERC20;

    FamilyVault vault;
    MockERC20 token;

    address owner = address(0x1);
    address spender = address(0x2);
    address guardian = address(0x3);
    address recipient = address(0x4);

    uint64 constant CATEGORY_ID = 1;

    function setUp() public {
        vm.startPrank(owner);
        // Instancia o contrato principal
        vault = deployFamilyVaultWithProxy(owner);

        // Cria token mock
        token = new MockERC20();
        vm.stopPrank();

        // Fornece token inicial, nativo da rede,  para usuários
        vm.deal(owner, 1000 ether);
        vm.deal(spender, 1000 ether);

        // Configura membro com SPENDER_ROLE
        vm.startPrank(owner);
        IFamilyVaultMember(address(vault)).addMember(
            spender,
            vault.SPENDER_ROLE()
        );
        vm.stopPrank();
    }

    // =========================================================================
    // 1. FUZZ PARA CATEGORIAS
    // =========================================================================

    function testFuzz_CreateCategory(
        string memory name,
        uint128 monthlyLimit
    ) public {
        vm.startPrank(owner);

        // Garante que nome não é vazio
        vm.assume(bytes(name).length > 0);

        // Limita o valor para evitar overflow
        monthlyLimit = uint128(bound(monthlyLimit, 1, type(uint128).max / 2));

        IFamilyVaultCategory(address(vault)).createCategory(
            name,
            monthlyLimit,
            address(0)
        );

        // Valida que foi criada corretamente
        (uint64 id, , uint128 limit, , , , ) = IFamilyVaultCategory(
            address(vault)
        ).getCategoryById(1);

        assertEq(limit, monthlyLimit);
        assertEq(id, 1);

        vm.stopPrank();
    }

    // =========================================================================
    // 2. FUZZ PARA ALLOWANCES
    // =========================================================================

    function testFuzz_AdjustAllowance(int128 delta) public {
        vm.startPrank(owner);

        // Cria categoria
        IFamilyVaultCategory(address(vault)).createCategory(
            "Mercado",
            100 ether,
            address(0)
        );

        // Inicializa allowance em 50 ether
        IFamilyVaultAllowance(address(vault)).setAllowance(
            spender,
            CATEGORY_ID,
            50 ether
        );

        // Limita o delta
        delta = int128(bound(delta, -50 ether, 50 ether));

        // Se negativo, não pode reduzir além do saldo
        if (delta < 0) {
            vm.assume(uint128(-delta) <= 50 ether);
        }

        IFamilyVaultAllowance(address(vault)).adjustAllowance(
            spender,
            CATEGORY_ID,
            delta
        );

        vm.stopPrank();
    }

    // =========================================================================
    // 3. FUZZ PARA DEPÓSITO DE TOKEN NATIVO DA REDE
    // =========================================================================

    function testFuzz_DepositETH(uint256 amount) public {
        vm.assume(amount > 0); // evita zero deposit

        vm.deal(spender, amount);

        vm.prank(spender);
        IFamilyVaultFund(address(vault)).depositNative{value: amount}();

        assertEq(address(vault).balance, amount);
    }

    // =========================================================================
    // 4. FUZZ PARA GASTOS (SPEND)
    // =========================================================================

    function testFuzz_Spend(uint128 amount) public {
        // Configuração inicial
        vm.startPrank(owner);
        IFamilyVaultCategory(address(vault)).createCategory(
            unicode"Educação",
            100 ether,
            address(0)
        );
        IFamilyVaultAllowance(address(vault)).setAllowance(
            spender,
            CATEGORY_ID,
            50 ether
        );
        vm.stopPrank();
        // Limita o amount
        amount = uint128(bound(amount, 1, 200 ether));

        // Fornece saldo para o contrato
        vm.deal(address(vault), 200 ether);

        vm.startPrank(spender);

        if (amount > 100 ether) {
            vm.expectRevert(FamilyVaultBase.OverCategoryLimit.selector);
            IFamilyVaultFund(address(vault)).spend(
                CATEGORY_ID,
                amount,
                recipient
            );
        } else if (amount > 50 ether) {
            vm.expectRevert(FamilyVaultBase.InsufficientAllowance.selector);
            IFamilyVaultFund(address(vault)).spend(
                CATEGORY_ID,
                amount,
                recipient
            );
        } else {
            IFamilyVaultFund(address(vault)).spend(
                CATEGORY_ID,
                amount,
                recipient
            );
        }

        vm.stopPrank();
    }

    // =========================================================================
    // 5. FUZZ PARA REQUESTS
    // =========================================================================

    function testFuzz_CreateAndApproveRequest(uint128 amount) public {
        vm.assume(amount > 0);

        uint256 maxLimit = 100 ether;
        vm.assume(amount <= maxLimit);

        // Cria categoria
        vm.startPrank(owner);
        IFamilyVaultCategory(address(vault)).createCategory(
            "Viagem",
            100 ether,
            address(0)
        );
        vm.stopPrank();

        // Spender cria request
        vm.startPrank(spender);
        uint256 requestId = IFamilyVaultRequest(address(vault)).createRequest(
            CATEGORY_ID,
            amount,
            "fuzz test"
        );
        vm.stopPrank();

        // Owner aprova request
        vm.startPrank(owner);
        vm.deal(address(vault), amount);
        IFamilyVaultRequest(address(vault)).approveRequest(
            requestId,
            payable(recipient)
        );
        vm.stopPrank();

        // Valida que foi aprovada
        (, , , FamilyVaultTypes.RequestStatus status, ) = IFamilyVaultRequest(
            address(vault)
        ).getRequestById(requestId);

        assertEq(uint(status), uint(FamilyVaultTypes.RequestStatus.APPROVED));
    }

    // =========================================================================
    // 6. FUZZ PARA DEPÓSITOS ERC20
    // =========================================================================

    function testFuzz_DepositERC20(uint256 amount) public {
        vm.assume(amount > 0);
        uint256 maxLimit = 1000 ether;
        vm.assume(amount <= maxLimit);
        vm.startPrank(owner);
        IFamilyVaultToken(address(vault)).setToken(address(token), true);

        // Fornece tokens ao spender
        token.safeTransfer(spender, amount);
        vm.stopPrank();

        vm.startPrank(spender);
        token.approve(address(vault), amount);
        IFamilyVaultFund(address(vault)).depositERC20(address(token), amount);
        vm.stopPrank();

        assertEq(token.balanceOf(address(vault)), amount);
    }

    // =========================================================================
    // 7. FUZZ PARA WITHDRAW ERC20
    // =========================================================================

    function testFuzz_WithdrawERC20(uint256 amount) public {
        uint256 initialBalance = token.balanceOf(owner);

        // Garante que amount seja > 0 e <= saldo inicial
        vm.assume(amount > 0 && amount <= initialBalance);

        // Habilita token
        vm.startPrank(owner);
        IFamilyVaultToken(address(vault)).setToken(address(token), true);

        // Deposita tokens no contrato
        token.approve(address(vault), amount);
        IFamilyVaultFund(address(vault)).depositERC20(address(token), amount);

        // Saque
        IFamilyVaultFund(address(vault)).withdrawERC20(
            address(token),
            recipient,
            amount
        );
        vm.stopPrank();

        assertEq(token.balanceOf(recipient), amount);
    }

    // =========================================================================
    // 8. FUZZ PARA WITHDRAW DE TOKEN NATIVO DA REDE
    // =========================================================================

    function testFuzz_WithdrawETH(uint256 amount) public {
        vm.assume(amount > 0);
        vm.deal(address(vault), amount);

        vm.startPrank(owner);
        IFamilyVaultFund(address(vault)).withdraw(payable(recipient), amount);
        vm.stopPrank();

        assertEq(address(recipient).balance, amount);
    }

    // =========================================================================
    // 9. FUZZ PARA FALLBACK E RECEIVE
    // =========================================================================

    function testFuzz_ReceiveETH(uint256 amount) public {
        uint256 initialBalance = 1e21; // 1000 ETH fictícios

        // Garante que amount seja > 0 e <= saldo disponível
        vm.assume(amount > 0 && amount <= initialBalance);

        // Define saldo para o endereço que está enviando
        vm.deal(address(this), initialBalance);

        // LOG antes de enviar
        console.log("Teste com amount:", amount);
        console.log(unicode"Saldo disponível:", initialBalance);

        (bool success, ) = address(vault).call{value: amount}("");
        assertTrue(success);
        assertEq(address(vault).balance, amount);
    }
}
