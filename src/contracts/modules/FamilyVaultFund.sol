//SPDX-License-Identifier:MIT
pragma solidity ^0.8.27;

import {FamilyVaultBase} from "../base/FamilyVaultBase.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract FamilyVaultFund is FamilyVaultBase {
    using SafeERC20 for IERC20;

    // ----------- Events ----------- //
    /** @notice Emite quando token nativo é retirado */
    event NativeWithdrawn(
        address indexed to,
        uint256 amount,
        address indexed by
    );
    /** @notice Emite quando ERC20 é depositado */
    event ERC20Deposited(
        address indexed sender,
        address indexed token,
        uint256 amount
    );
    /** @notice Emite quando ERC20 é retirado */
    event ERC20Withdrawn(
        address indexed to,
        address indexed token,
        uint256 amount,
        address indexed by
    );

    // -----------------------------------------
    // Gastos diretos
    // -----------------------------------------
    /**
     * @notice Executa um gasto direto por um spender
     * @param categoryId ID da categoria
     * @param amount Valor a ser gasto
     * @param to Endereço que receberá os fundos
     */
    function spend(
        uint64 categoryId,
        uint128 amount,
        address to
    )
        external
        onlySpender
        nonReentrant
        whenNotPaused
        categoryExists(categoryId)
    {
        require(!pausedMembers[msg.sender], MemberIsPaused());
        _executeExpense(categoryId, msg.sender, to, amount, true);
    }

    /**
     * @notice Deposita token nativo no contrato
     */
    function depositNative() external payable {
        require(msg.value > 0, ZeroDepositNotAllowed());
        emit NativeDeposited(msg.sender, msg.value);
    }

    /**
     * @notice Retira token nativo do contrato
     * @param to Endereço que receberá os fundos
     * @param amount Quantidade do token nativo
     */
    function withdraw(
        address payable to,
        uint256 amount
    ) external onlyOwner nonReentrant {
        require(to != address(0), InvalidRecipientAddress());
        require(amount > 0, ZeroWithdrawNotAllowed());
        require(address(this).balance >= amount, InsufficientBalance());
        (bool ok, ) = to.call{value: amount}("");
        require(ok, TransferFailed());
        emit NativeWithdrawn(to, amount, msg.sender);
    }

    /**
     * @notice Deposita tokens ERC20 no contrato
     * @param token Endereço do token
     * @param amount Quantidade de tokens
     */
    function depositERC20(address token, uint256 amount) external {
        require(_isAllowedToken(token), TokenNotAllowed());
        require(amount > 0, ZeroDepositNotAllowed());
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit ERC20Deposited(msg.sender, token, amount);
    }

    /**
     * @notice Retira tokens ERC20 do contrato
     * @param token Endereço do token
     * @param to Endereço que receberá os tokens
     * @param amount Quantidade de tokens
     */
    function withdrawERC20(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner nonReentrant {
        require(token != address(0), InvalidTokenAddress());
        require(to != address(0), InvalidRecipientAddress());
        require(amount > 0, ZeroWithdrawNotAllowed());
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance >= amount, InsufficientBalance());
        IERC20(token).safeTransfer(to, amount);
        emit ERC20Withdrawn(to, token, amount, msg.sender);
    }

    // -----------------------------------------
    // Saldo do Contrato
    // -----------------------------------------
    /**
     * @notice Saldo do contrato em token nativo ou ERC20
     * @param token Endereço do token address(0) representa o token nativo da rede (ETH, MATIC, BNB, etc.)
     * @return balance Quantidade disponível
     */
    function contractBalance(address token) external view returns (uint256) {
        if (token == address(0)) return address(this).balance;
        return IERC20(token).balanceOf(address(this));
    }
}
