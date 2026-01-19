// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {FamilyVault} from "../../src/contracts/FamilyVault.sol";
import {FamilyVaultBase} from "../../src/contracts/base/FamilyVaultBase.sol";
import {FamilyVaultTestHelper} from "../helpers/FamilyVaultTestHelper.sol";
import {MockERC20} from "../mock/MockERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IFamilyVaultFund} from "../interfaces/IFamilyVaultFund.sol";
import {IFamilyVaultMember} from "../interfaces/IFamilyVaultMember.sol";
import {IFamilyVaultToken} from "../interfaces/IFamilyVaultToken.sol";

contract FamilyVaultTokensTest is Test, FamilyVaultTestHelper {
    using SafeERC20 for MockERC20;

    FamilyVault public vault;
    MockERC20 public token;
    address public owner;
    address public user;
    address public recipient;

    function setUp() public {
        owner = address(0x1);
        user = address(0x2);
        recipient = address(0x3);

        vm.startPrank(owner);
        vault = deployFamilyVaultWithProxy(owner);

        token = new MockERC20();
        token.safeTransfer(owner, 100 ether);

        _addMember(owner, vault.OWNER_ROLE());
        _addMember(user, vault.SPENDER_ROLE());

        vm.stopPrank();
    }

    // --------------------
    // Helpers
    // --------------------

    function _addMember(address member, bytes32 role) internal {
        vm.startPrank(owner);
        IFamilyVaultMember(address(vault)).addMember(member, role);
        vm.stopPrank();
    }

    // ----------------------------
    // depositNative()
    // ----------------------------
    function test_DepositNative_Success() public {
        vm.deal(user, 1 ether);

        vm.startPrank(user);
        IFamilyVaultFund(address(vault)).depositNative{value: 1 ether}();

        // Verifica saldo do contrato
        assertEq(address(vault).balance, 1 ether);
        vm.stopPrank();
    }

    function test_DepositNative_RevertIfZeroValue() public {
        vm.startPrank(user);
        vm.expectRevert(FamilyVaultBase.ZeroDepositNotAllowed.selector);
        IFamilyVaultFund(address(vault)).depositNative{value: 0}();
        vm.stopPrank();
    }

    // ----------------------------
    // withdraw()
    // ----------------------------
    function test_WithdrawNative_Success() public {
        // Primeiro deposita no contrato
        vm.deal(user, 1 ether);
        vm.startPrank(user);
        IFamilyVaultFund(address(vault)).depositNative{value: 1 ether}();
        vm.stopPrank();

        uint256 initialBalance = address(recipient).balance;

        vm.startPrank(owner);
        IFamilyVaultFund(address(vault)).withdraw(payable(recipient), 1 ether);

        // Valida que o recipient recebeu o valor
        assertEq(address(recipient).balance, initialBalance + 1 ether);
        vm.stopPrank();
    }

    function test_WithdrawNative_RevertIfRecipientZero() public {
        vm.startPrank(owner);
        vm.expectRevert(FamilyVaultBase.InvalidRecipientAddress.selector);
        IFamilyVaultFund(address(vault)).withdraw(payable(address(0)), 1 ether);
        vm.stopPrank();
    }

    function test_WithdrawNative_RevertIfAmountZero() public {
        vm.startPrank(owner);
        vm.expectRevert(FamilyVaultBase.ZeroWithdrawNotAllowed.selector);
        IFamilyVaultFund(address(vault)).withdraw(payable(recipient), 0);
        vm.stopPrank();
    }

    function test_WithdrawNative_RevertIfInsufficientBalance() public {
        vm.startPrank(owner);
        vm.expectRevert(FamilyVaultBase.InsufficientBalance.selector);
        IFamilyVaultFund(address(vault)).withdraw(payable(recipient), 1 ether);
        vm.stopPrank();
    }

    // ----------------------------
    // depositERC20()
    // ----------------------------
    function test_DepositERC20_Success() public {
        vm.startPrank(owner);
        IFamilyVaultToken(address(vault)).setToken(address(token), true);

        // Aprova tokens para o vault
        token.approve(address(vault), 100 ether);
        IFamilyVaultFund(address(vault)).depositERC20(address(token), 2 ether);
        vm.stopPrank();

        // Valida saldo do contrato
        assertEq(token.balanceOf(address(vault)), 2 ether);
    }

    function test_DepositERC20_RevertIfTokenNotAllowed() public {
        vm.startPrank(user);
        token.approve(address(vault), 100 ether);

        vm.expectRevert(FamilyVaultBase.TokenNotAllowed.selector);
        IFamilyVaultFund(address(vault)).depositERC20(address(token), 50 ether);
        vm.stopPrank();
    }

    function test_DepositERC20_RevertIfZeroAmount() public {
        vm.prank(owner);
        IFamilyVaultToken(address(vault)).setToken(address(token), true);

        vm.startPrank(user);
        token.approve(address(vault), 100 ether);

        vm.expectRevert(FamilyVaultBase.ZeroDepositNotAllowed.selector);
        IFamilyVaultFund(address(vault)).depositERC20(address(token), 0);
        vm.stopPrank();
    }

    // ----------------------------
    // withdrawERC20()
    // ----------------------------
    function test_WithdrawERC20_Success() public {
        vm.startPrank(owner);
        IFamilyVaultToken(address(vault)).setToken(address(token), true);

        // Deposita primeiro
        token.approve(address(vault), 100 ether);
        IFamilyVaultFund(address(vault)).depositERC20(address(token), 50 ether);

        // Retira
        IFamilyVaultFund(address(vault)).withdrawERC20(
            address(token),
            recipient,
            20 ether
        );

        assertEq(token.balanceOf(recipient), 20 ether);
        vm.stopPrank();
    }

    function test_WithdrawERC20_RevertIfTokenAddressZero() public {
        vm.prank(owner);
        vm.expectRevert(FamilyVaultBase.InvalidTokenAddress.selector);
        IFamilyVaultFund(address(vault)).withdrawERC20(
            address(0),
            recipient,
            10 ether
        );
    }

    function test_WithdrawERC20_RevertIfRecipientZero() public {
        vm.startPrank(owner);
        vm.expectRevert(FamilyVaultBase.InvalidRecipientAddress.selector);
        IFamilyVaultFund(address(vault)).withdrawERC20(
            address(token),
            address(0),
            10 ether
        );
        vm.stopPrank();
    }

    function test_WithdrawERC20_RevertIfZeroAmount() public {
        vm.startPrank(owner);
        vm.expectRevert(FamilyVaultBase.ZeroWithdrawNotAllowed.selector);
        IFamilyVaultFund(address(vault)).withdrawERC20(
            address(token),
            recipient,
            0
        );
        vm.stopPrank();
    }

    function test_WithdrawERC20_RevertIfInsufficientBalance() public {
        vm.startPrank(owner);
        IFamilyVaultToken(address(vault)).setToken(address(token), true);
        token.approve(address(vault), 10 ether);
        IFamilyVaultFund(address(vault)).depositERC20(address(token), 5 ether);

        vm.expectRevert(FamilyVaultBase.InsufficientBalance.selector);
        IFamilyVaultFund(address(vault)).withdrawERC20(
            address(token),
            recipient,
            10 ether
        );
        vm.stopPrank();
    }
}
