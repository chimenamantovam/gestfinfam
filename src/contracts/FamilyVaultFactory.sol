// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {FamilyVault} from "./FamilyVault.sol";

/**
 * @title FamilyVaultFactory
 * @notice Fábrica que cria cofres familiares completos com módulos configurados.
 * @dev Cada família é um proxy isolado com módulos registrados automaticamente.
 */
contract FamilyVaultFactory is Ownable {
    /// @notice Implementação base do FamilyVault
    address public immutable vaultImplementation;

    /// @notice Endereços das implementações dos módulos
    struct ModuleImpl {
        address allowance;
        address category;
        address fund;
        address member;
        address request;
        address token;
    }

    ModuleImpl public moduleImpl;

    /// @notice Lista de todas as famílias criadas
    address[] public allFamilies;

    /// @notice owner → lista de cofres criados
    mapping(address => address[]) public familiesByOwner;

    // Evento atualizado
    event FamilyCreated(
        address indexed owner,
        address indexed proxy,
        address indexed implementation,
        address allowanceModule,
        address categoryModule,
        address fundModule,
        address memberModule,
        address requestModule,
        address tokenModule
    );

    constructor(
        address _vaultImplementation,
        address _allowanceImpl,
        address _categoryImpl,
        address _fundImpl,
        address _memberImpl,
        address _requestImpl,
        address _tokenImpl
    ) Ownable(msg.sender) {
        require(_vaultImplementation != address(0), "Invalid vault impl");
        vaultImplementation = _vaultImplementation;

        moduleImpl = ModuleImpl({
            allowance: _allowanceImpl,
            category: _categoryImpl,
            fund: _fundImpl,
            member: _memberImpl,
            request: _requestImpl,
            token: _tokenImpl
        });
    }

    /**
     * @notice Cria uma nova família com módulos configurados
     * @return proxy Endereço do novo cofre familiar
     */
    function createFamily() external returns (address proxy) {
        address owner = msg.sender;

        // Inicializa FamilyVault (chama initialize(owner))
        bytes memory initData = abi.encodeWithSelector(
            FamilyVault.initialize.selector,
            owner,
            moduleImpl.allowance,
            moduleImpl.category,
            moduleImpl.fund,
            moduleImpl.member,
            moduleImpl.request,
            moduleImpl.token
        );

        // Deploy do proxy
        proxy = address(new ERC1967Proxy(vaultImplementation, initData));

        // Salva registros
        allFamilies.push(proxy);
        familiesByOwner[owner].push(proxy);

        emit FamilyCreated(
            owner,
            proxy,
            vaultImplementation,
            moduleImpl.allowance,
            moduleImpl.category,
            moduleImpl.fund,
            moduleImpl.member,
            moduleImpl.request,
            moduleImpl.token
        );
    }

    // ------------------ VIEWS ------------------ //

    function getAllFamilies() external view returns (address[] memory) {
        return allFamilies;
    }

    function getFamiliesByOwner(
        address owner
    ) external view returns (address[] memory) {
        return familiesByOwner[owner];
    }

    function totalFamilies() external view returns (uint256) {
        return allFamilies.length;
    }
}
