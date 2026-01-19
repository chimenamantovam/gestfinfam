//SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {FamilyVaultBase} from "../contracts/base/FamilyVaultBase.sol";

/**
 * @title FamilyVault (Proxy coordinator using delegatecall to modules)
 * @notice Central storage + delegation router. Modules implement logic and use proxy storage via delegatecall.
 */
contract FamilyVault is Initializable, FamilyVaultBase {
    /// @notice Mapping selector -> module address (flexível)
    mapping(bytes4 => address) public selectorToModule;

    /// @notice Emitted when a selector is bound to a module
    event SelectorSet(bytes4 indexed selector, address indexed module);

    /// @notice Emitted when many selectors are bound in batch
    event SelectorsSet(address indexed module, bytes4[] selectors);

    /// @notice Emitted when a selector is removed
    event SelectorRemoved(bytes4 indexed selector);

    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Inicializa o contrato, concedendo roles ao owner e registrando módulos
     * @param owner Endereço do proprietário inicial
     */
    function initialize(
        address owner,
        address allowanceModule,
        address categoryModule,
        address fundModule,
        address memberModule,
        address requestModule,
        address tokenModule
    ) external initializer {
        require(owner != address(0), "Invalid owner");

        // Inicializa contratos OpenZeppelin
        __AccessControlEnumerable_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        // Concede roles
        _grantRole(OWNER_ROLE, owner);
        _grantRole(GUARDIAN_ROLE, owner);
        _setRoleAdmin(SPENDER_ROLE, OWNER_ROLE);
        _setRoleAdmin(GUARDIAN_ROLE, OWNER_ROLE);

        isMember[owner] = true;

        // Registra módulos iniciais
        _registerDefaultModules(
            allowanceModule,
            categoryModule,
            fundModule,
            memberModule,
            requestModule,
            tokenModule
        );
    }

    // Função auxiliar para registrar todos os módulos
    function _registerDefaultModules(
        address allowance,
        address category,
        address fund,
        address member,
        address request,
        address token
    ) internal {
        // Valida módulos
        require(_isContract(allowance), "Allowance not contract");
        require(_isContract(category), "Category not contract");
        require(_isContract(fund), "Fund not contract");
        require(_isContract(member), "Member not contract");
        require(_isContract(request), "Request not contract");
        require(_isContract(token), "Token not contract");

        string[] memory allowanceSigs = new string[](4);
        allowanceSigs[0] = "setAllowance(address,uint64,uint128)";
        allowanceSigs[1] = "getAllowance(address,uint64)";
        allowanceSigs[2] = "adjustAllowance(address,uint64,int128)";
        allowanceSigs[3] = "hasAllowanceSet(address,uint64)";
        _setSelectorsBySignatures(allowanceSigs, allowance);

        string[] memory categorySigs = new string[](8);
        categorySigs[0] = "createCategory(string,uint128,address)";
        categorySigs[1] = "updateCategory(uint64,string,uint128,address)";
        categorySigs[2] = "deactivateCategory(uint64)";
        categorySigs[3] = "reactivateCategory(uint64)";
        categorySigs[4] = "resetCategoryPeriod(uint64)";
        categorySigs[5] = "getCategoryById(uint64)";
        categorySigs[6] = "getAllCategories()";
        categorySigs[7] = "getLastCategoryId()";
        _setSelectorsBySignatures(categorySigs, category);

        string[] memory fundSigs = new string[](6);
        fundSigs[0] = "spend(uint64,uint128,address)";
        fundSigs[1] = "depositNative()";
        fundSigs[2] = "withdraw(address,uint256)";
        fundSigs[3] = "depositERC20(address,uint256)";
        fundSigs[4] = "withdrawERC20(address,address,uint256)";
        fundSigs[5] = "contractBalance(address)";
        _setSelectorsBySignatures(fundSigs, fund);

        string[] memory memberSigs = new string[](8);
        memberSigs[0] = "addMember(address,bytes32)";
        memberSigs[1] = "removeMember(address)";
        memberSigs[2] = "updateMemberRole(address,bytes32)";
        memberSigs[3] = "pauseMember(address)";
        memberSigs[4] = "unpauseMember(address)";
        memberSigs[5] = "isMemberPaused(address)";
        memberSigs[6] = "listMembersByRole(bytes32)";
        memberSigs[7] = "isMemberActive(address)";
        _setSelectorsBySignatures(memberSigs, member);

        string[] memory requestSigs = new string[](7);
        requestSigs[0] = "createRequest(uint64,uint128,string)";
        requestSigs[1] = "approveRequest(uint256,address)";
        requestSigs[2] = "denyRequest(uint256,string)";
        requestSigs[3] = "cancelRequest(uint256)";
        requestSigs[4] = "getRequestsByStatus(uint8)";
        requestSigs[5] = "getLastRequestId()";
        requestSigs[6] = "getRequestById(uint256)";
        _setSelectorsBySignatures(requestSigs, request);

        string[] memory tokenSigs = new string[](3);
        tokenSigs[0] = "setToken(address,bool)";
        tokenSigs[1] = "getToken(address)";
        tokenSigs[2] = "getAllTokens()";
        _setSelectorsBySignatures(tokenSigs, token);
    }

    /// @notice Internal helper: verifica se é contrato
    function _isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    /// @notice Internal helper para registrar selectors de um módulo
    function _setSelectorsByModule(
        address module,
        bytes4[] memory selectors
    ) internal {
        require(_isContract(module), "Module not contract");
        _setSelectorsBatch(selectors, module);
    }

    function setSelectorModule(
        bytes4 selector,
        address module
    ) public onlyOwner {
        require(_isContract(module), "Module not contract");
        selectorToModule[selector] = module;
        emit SelectorSet(selector, module);
    }

    /// @notice Define vários selectors apontando para o mesmo módulo (batch)
    function _setSelectorsBatch(
        bytes4[] memory selectors,
        address module
    ) internal {
        require(_isContract(module), "Module not contract");
        for (uint256 i = 0; i < selectors.length; i++) {
            selectorToModule[selectors[i]] = module;
        }
        emit SelectorsSet(module, selectors);
    }

    function setSelectorsBatch(
        bytes4[] calldata selectors,
        address module
    ) external onlyOwner {
        _setSelectorsBatch(selectors, module);
    }

    function removeSelector(bytes4 selector) external onlyOwner {
        require(selectorToModule[selector] != address(0), "Not set");
        delete selectorToModule[selector];
        emit SelectorRemoved(selector);
    }

    function removeSelectorsBatch(
        bytes4[] calldata selectors
    ) external onlyOwner {
        for (uint256 i = 0; i < selectors.length; i++) {
            delete selectorToModule[selectors[i]];
            emit SelectorRemoved(selectors[i]);
        }
    }

    function _setSelectorsBySignatures(
        string[] memory signatures,
        address module
    ) internal {
        bytes4[] memory selectors = new bytes4[](signatures.length);
        for (uint256 i = 0; i < signatures.length; i++) {
            selectors[i] = bytes4(keccak256(bytes(signatures[i])));
        }
        _setSelectorsBatch(selectors, module);
    }

    function setSelectorsBySignatures(
        string[] calldata signatures,
        address module
    ) external onlyOwner {
        require(_isContract(module), "Module not contract");

        bytes4[] memory selectors = new bytes4[](signatures.length);
        for (uint256 i = 0; i < signatures.length; i++) {
            selectors[i] = bytes4(keccak256(bytes(signatures[i])));
        }
        _setSelectorsBatch(selectors, module);
    }

    function getModuleForSelector(
        bytes4 selector
    ) external view returns (address) {
        return selectorToModule[selector];
    }

    /// @notice Delegates calls to the specified module
    fallback() external payable {
        if (msg.data.length == 0) {
            require(msg.value > 0, ZeroDepositNotAllowed());
            emit NativeDeposited(msg.sender, msg.value);
            return;
        }

        address impl = selectorToModule[msg.sig];
        if (impl == address(0)) {
            if (msg.value > 0) {
                emit NativeDeposited(msg.sender, msg.value);
                return;
            }
            revert("Logic module not set");
        }

        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(0, 0, size)
            switch result
            case 0 {
                revert(0, size)
            }
            default {
                return(0, size)
            }
        }
    }

    /// @notice Recebe token nativo
    receive() external payable {
        require(msg.value > 0, ZeroDepositNotAllowed());
        emit NativeDeposited(msg.sender, msg.value);
    }

    // -----------------------------------------
    // Pause / Unpause
    // -----------------------------------------
    /**
     * @notice Pausa o contrato
     */
    function pause() external onlyOwnerOrGuardian {
        _pause();
    }

    /**
     * @notice Despausa o contrato
     */
    function unpause() external onlyOwner {
        _unpause();
    }
}
