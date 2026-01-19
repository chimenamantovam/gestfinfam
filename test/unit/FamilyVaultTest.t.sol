// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {FamilyVault} from "../../src/contracts/FamilyVault.sol";
import {FamilyVaultTestHelper} from "../helpers/FamilyVaultTestHelper.sol";
import {MockERC20} from "../mock/MockERC20.sol";

import {IFamilyVaultCategory} from "../interfaces/IFamilyVaultCategory.sol";
import {IFamilyVaultRequest} from "../interfaces/IFamilyVaultRequest.sol";
import {IFamilyVaultMember} from "../interfaces/IFamilyVaultMember.sol";

contract FamilyVaultTests is Test, FamilyVaultTestHelper {
    FamilyVault public vault;
    MockERC20 public token;

    address public owner;
    address public user;
    address public user2;
    address public guardian;

    bytes32[] roles;
    bytes4[] sels;
    string[] sigs;
    bytes4[] expectedSelectors;

    // ------------------------
    // Events usados em expectEmit
    // ------------------------
    event NativeDeposited(address indexed sender, uint256 amount);
    event SelectorSet(bytes4 indexed selector, address indexed module);
    event SelectorsSet(address indexed module, bytes4[] selectors);
    event SelectorRemoved(bytes4 indexed selector);

    function setUp() public {
        owner = address(0x1);
        guardian = address(0x2);

        vm.startPrank(owner);
        vault = deployFamilyVaultWithProxy(owner);
        roles.push(vault.OWNER_ROLE());
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

    //------------------------
    //------ DEPLOY ------
    //------------------------

    /// @dev Verifica se o deploy inicial do contrato está correto
    function test_DeployOwnerRoles() public view {
        // Owner deve ter OWNER_ROLE
        assertTrue(
            vault.hasRole(vault.OWNER_ROLE(), owner),
            "Owner deve ter OWNER_ROLE"
        );
        // Owner deve ter GUARDIAN_ROLE
        assertTrue(
            vault.hasRole(vault.GUARDIAN_ROLE(), owner),
            "Owner deve ter GUARDIAN_ROLE"
        );
    }

    function test_DeployOwnerIsMember() public view {
        // isMember[owner] deve ser true
        assertTrue(vault.isMember(owner), "Owner deve ser membro");
    }

    function test_DeployInitialIds() public view {
        // IDs de categoria e requisição devem iniciar como 0
        assertEq(
            IFamilyVaultCategory(address(vault)).getLastCategoryId(),
            0,
            "_lastCategoryId deve iniciar como 0"
        );

        assertEq(
            IFamilyVaultRequest(address(vault)).getLastRequestId(),
            0,
            "_lastRequestId deve iniciar como 0"
        );
    }

    function test_DeployPausedState() public view {
        // paused() deve iniciar como false
        assertFalse(
            vault.paused(),
            unicode"Contrato não deve estar pausado ao deploy"
        );
    }

    //------------------------
    //------ FALLBACK / RECEIVE ------
    //------------------------

    // helper para pegar selector de custom errors
    function selectorOf(string memory s) internal pure returns (bytes4) {
        return bytes4(keccak256(bytes(s)));
    }

    function test_Fallback_NonEmptyData_NoModuleRevertsWithLogicModuleNotSet()
        public
    {
        // call com calldata não vazio e sem módulo -> deve revert "Logic module not set"
        bytes memory callData = abi.encodeWithSelector(
            bytes4(keccak256("iDontExist()"))
        );
        vm.prank(user);
        vm.expectRevert(bytes("Logic module not set"));
        (bool ok, ) = address(vault).call(callData);
        ok;
    }

    function test_Fallback_NonEmptyData_WithValue_EmitsNativeDeposited()
        public
    {
        vm.deal(user, 1 ether);
        // call com calldata não vazio e msg.value > 0 -> fallback emite NativeDeposited e retorna
        bytes memory callData = abi.encodeWithSelector(
            bytes4(keccak256("iDontExist()"))
        );
        vm.prank(user);
        vm.expectEmit(true, false, false, true);
        emit NativeDeposited(user, 1);
        (bool ok, ) = address(vault).call{value: 1}(callData);
        assertTrue(
            ok,
            unicode"call com valor e sem módulo deve ter sucesso e emitir NativeDeposited"
        );
    }

    function test_Receive_Deposit_EmitsNativeDeposited() public {
        // envio direto de token nativo -> receive() deve aceitar >0 e emitir NativeDeposited
        vm.deal(user, 2 ether);
        vm.prank(user);
        vm.expectEmit(true, false, false, true);
        emit NativeDeposited(user, 2 ether);
        (bool ok, ) = address(vault).call{value: 2 ether}("");
        assertTrue(ok, "receive() deve aceitar token nativo e emitir evento");
    }

    function test_Fallback_EmptyData_ZeroValue_RevertsZeroDepositNotAllowed()
        public
    {
        // call com calldata vazio e 0 value -> deve reverter com ZeroDepositNotAllowed()
        bytes4 err = selectorOf("ZeroDepositNotAllowed()");
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(err));
        (bool ok, ) = address(vault).call("");
        ok;
    }

    //------------------------
    //------ SELECTOR MANAGEMENT ------
    //------------------------

    // mock module para testes de delegate
    MockModule module = new MockModule();

    function test_SetSelectorModule_AsOwner_Succeeds() public {
        vm.prank(owner);
        vm.mockCall(
            address(module),
            abi.encodeWithSelector(bytes4(0), ""),
            abi.encode()
        ); // dummy mock
        bytes4 sel = bytes4(keccak256("dummyFunction()"));
        vm.expectEmit(true, true, false, true);
        emit SelectorSet(sel, address(module));
        vault.setSelectorModule(sel, address(module));

        assertEq(
            vault.getModuleForSelector(sel),
            address(module),
            "selector deve apontar para mockModule"
        );
    }

    function test_SetSelectorModule_NotOwner_Reverts() public {
        bytes4 sel = bytes4(keccak256("dummyFunction()"));
        vm.prank(user);
        vm.expectRevert();
        vault.setSelectorModule(sel, address(module));
    }

    function test_SetSelectorModule_ModuleNotContract_Reverts() public {
        bytes4 sel = bytes4(keccak256("dummyFunction()"));
        vm.prank(owner);
        vm.expectRevert(bytes("Module not contract"));
        vault.setSelectorModule(sel, address(0x123));
    }

    function test_SetSelectorsBatch_AsOwner_Succeeds() public {
        sels.push(bytes4(keccak256("f1()")));
        sels.push(bytes4(keccak256("f2()")));
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit SelectorsSet(address(module), sels);
        vault.setSelectorsBatch(sels, address(module));

        assertEq(vault.getModuleForSelector(sels[0]), address(module));
        assertEq(vault.getModuleForSelector(sels[1]), address(module));
    }

    function test_RemoveSelector_AsOwner_Succeeds() public {
        bytes4 sel = bytes4(keccak256("fRemove()"));
        vm.prank(owner);
        vault.setSelectorModule(sel, address(module));
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit SelectorRemoved(sel);
        vault.removeSelector(sel);

        assertEq(
            vault.getModuleForSelector(sel),
            address(0),
            "selector deve ser removido"
        );
    }

    function test_RemoveSelector_NotSet_Reverts() public {
        bytes4 sel = bytes4(keccak256("fNotSet()"));
        vm.prank(owner);
        vm.expectRevert(bytes("Not set"));
        vault.removeSelector(sel);
    }

    function test_RemoveSelectorsBatch_AsOwner_Succeeds() public {
        sels.push(bytes4(keccak256("fBatch1()")));
        sels.push(bytes4(keccak256("fBatch2()")));
        vm.prank(owner);
        vault.setSelectorsBatch(sels, address(module));

        vm.prank(owner);
        for (uint256 i = 0; i < sels.length; i++) {
            vm.expectEmit(true, true, false, true);
            emit SelectorRemoved(sels[i]);
        }
        vault.removeSelectorsBatch(sels);

        assertEq(vault.getModuleForSelector(sels[0]), address(0));
        assertEq(vault.getModuleForSelector(sels[1]), address(0));
    }

    function test_SetSelectorsBySignatures_AsOwner_Succeeds() public {
        sigs.push("sig1()");
        sigs.push("sig2()");
        bytes4 sel0 = bytes4(keccak256(bytes(sigs[0])));
        bytes4 sel1 = bytes4(keccak256(bytes(sigs[1])));
        delete expectedSelectors;
        expectedSelectors.push(sel0);
        expectedSelectors.push(sel1);
        vm.prank(owner);

        vm.expectEmit(true, true, false, true);
        emit SelectorsSet(address(module), expectedSelectors);

        vault.setSelectorsBySignatures(sigs, address(module));
        assertEq(
            vault.getModuleForSelector(sel0),
            address(module),
            "selector 0 deve ter sido definido"
        );
        assertEq(
            vault.getModuleForSelector(sel1),
            address(module),
            "selector 1 deve ter sido definido"
        );
    }

    //------------------------
    //------ DELEGATECALL SUCCESS & REVERT ------
    //------------------------

    // Mock module para teste de delegatecall

    function test_DelegateCall_Success() public {
        // registra selector no vault
        bytes4 selector = module.mockCall.selector;
        vm.prank(owner);
        vault.setSelectorModule(selector, address(module));

        // call via fallback
        vm.prank(user);
        vm.expectEmit(true, false, false, true);
        emit MockModule.Called(user, 0);
        (bool ok, ) = address(vault).call(abi.encodeWithSelector(selector));
        assertTrue(ok, "delegatecall deve ter sucesso");
    }

    function test_DelegateCall_RevertPropagates() public {
        // registra selector no vault
        bytes4 sel = module.mockRevert.selector;
        vm.prank(owner);
        vault.setSelectorModule(sel, address(module));

        // call via fallback -> deve propagar revert
        vm.prank(user);
        vm.expectRevert(bytes("Module reverted"));
        (bool ok, ) = address(vault).call(abi.encodeWithSelector(sel));
        ok;
    }

    function test_DelegateCall_SelectorNotSet_Revert() public {
        // selector não registrado, calldata não vazio -> fallback deve reverter
        bytes4 sel = bytes4(keccak256("nonexistent()"));
        vm.prank(user);
        vm.expectRevert(bytes("Logic module not set"));
        (bool ok, ) = address(vault).call(abi.encodeWithSelector(sel));
        ok;
    }

    //------------------------
    //------ PAUSE / UNPAUSE ------
    //------------------------

    function test_Pause_AsOwner_Succeeds() public {
        // owner consegue pausar
        vm.prank(owner);
        vault.pause();
        assertTrue(vault.paused(), "Contrato deve estar pausado pelo owner");
    }

    function test_Pause_AsGuardian_Succeeds() public {
        // adiciona outro endereço como guardian
        vm.prank(owner);
        _addMember(guardian, vault.GUARDIAN_ROLE());

        vm.prank(guardian);
        vault.pause();
        assertTrue(vault.paused(), "Contrato deve estar pausado pelo guardian");
    }

    function test_Pause_NotOwnerOrGuardian_Reverts() public {
        vm.prank(user);
        vm.expectRevert();
        vault.pause();
    }

    function test_Unpause_AsOwner_Succeeds() public {
        // pausar primeiro
        vm.prank(owner);
        vault.pause();
        assertTrue(
            vault.paused(),
            "Contrato deve estar pausado antes de despausar"
        );

        // unpause
        vm.prank(owner);
        vault.unpause();
        assertFalse(
            vault.paused(),
            "Contrato deve estar despausado pelo owner"
        );
    }

    function test_Unpause_AsGuardian_Reverts() public {
        // pausar primeiro
        vm.prank(owner);
        vault.pause();

        // tentar despausar como guardian
        vm.prank(owner);
        _addMember(guardian, vault.GUARDIAN_ROLE());

        vm.prank(guardian);
        vm.expectRevert();
        vault.unpause();
    }
}

contract MockModule {
    event Called(address sender, uint256 value);

    function mockCall() external payable {
        emit Called(msg.sender, msg.value);
    }

    function mockRevert() external pure {
        revert("Module reverted");
    }
}
