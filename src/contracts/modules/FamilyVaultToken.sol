// SPDX-License-Identifier:MIT
pragma solidity ^0.8.27;

import {FamilyVaultBase} from "../base/FamilyVaultBase.sol";
import {FamilyVaultTypes} from "../types/FamilyVaultTypes.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract FamilyVaultToken is FamilyVaultBase {
    event TokenSet(address indexed token, string symbol, bool active);

    /**
     * @notice Registra um token e status ativo/inativo
     * @param token Endereço do token
     * @param active Se o token está ativo
     */
    function setToken(address token, bool active) external onlyOwner {
        require(token != address(0), InvalidTokenAddress());

        // Verifica se o endereço tem código (ou seja, é um contrato)
        uint256 size;
        assembly {
            size := extcodesize(token)
        }
        require(size > 0, InvalidTokenAddress());

        // Tenta obter o símbolo do token de forma segura
        string memory symbol;
        try IERC20Metadata(token).symbol() returns (string memory s) {
            symbol = s;
        } catch {
            symbol = "UNKNOWN"; // fallback se não implementar symbol()
        }

        // Armazena as informações do token
        _tokens[token] = FamilyVaultTypes.TokenInfo({
            symbol: symbol,
            active: active
        });

        // Adiciona à lista se ainda não existir
        if (!_exists[token]) {
            _tokenList.push(token);
            _exists[token] = true;
        }

        emit TokenSet(token, symbol, active);
    }

    /**
     * @notice Retorna as informações de um token
     * @param token Endereço do token
     */
    function getToken(
        address token
    ) external view returns (FamilyVaultTypes.TokenInfo memory) {
        return _tokens[token];
    }

    /**
     * @notice Retorna todos os tokens cadastrados (histórico)
     */
    function getAllTokens() external view returns (address[] memory) {
        return _tokenList;
    }
}
