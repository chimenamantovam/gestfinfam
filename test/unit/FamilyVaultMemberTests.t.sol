// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {FamilyVault} from "../../src/contracts/FamilyVault.sol";
import {FamilyVaultBase} from "../../src/contracts/base/FamilyVaultBase.sol";
import {FamilyVaultTestHelper} from "../helpers/FamilyVaultTestHelper.sol";
import {MockERC20} from "../mock/MockERC20.sol";

import {IFamilyVaultMember} from "../interfaces/IFamilyVaultMember.sol";

contract FamilyVaultMemberTests is Test, FamilyVaultTestHelper {
    FamilyVault public vault;
    MockERC20 public token;

    address public owner;
    address public user;
    address public user2;
    address public guardian;

    bytes32[] roles;

    function setUp() public {
        owner = address(0x1);
        user = address(0x2);
        user2 = address(0x3);
        guardian = address(0x4);

        vm.startPrank(owner);
        vault = deployFamilyVaultWithProxy(owner);
        token = new MockERC20();

        roles.push(vault.OWNER_ROLE());
        roles.push(vault.SPENDER_ROLE());
        roles.push(vault.GUARDIAN_ROLE());
        vm.stopPrank();
    }

    //------------------------
    //------ MEMBRO ------
    //------------------------

    // --------------------
    // addMember()
    // --------------------
    function test_AddMember_AllRoles() public {
        vm.startPrank(owner);
        address[3] memory members;

        members[0] = user;
        members[1] = user2;
        members[2] = guardian;

        for (uint i = 0; i < roles.length; i++) {
            IFamilyVaultMember(address(vault)).addMember(members[i], roles[i]);
            assertTrue(
                vault.hasRole(roles[i], members[i]),
                "Membro deve ter a role correta"
            );
            assertTrue(vault.isMember(members[i]), "Membro deve estar ativo");
        }
        vm.stopPrank();
    }

    function test_Revert_AddMemberZeroAddress() public {
        vm.startPrank(owner);
        bytes32 spenderRole = vault.SPENDER_ROLE();
        vm.expectRevert(FamilyVaultBase.ZeroAddress.selector);
        IFamilyVaultMember(address(vault)).addMember(address(0), spenderRole);
        vm.stopPrank();
    }

    function test_Revert_AddMemberInvalidRole() public {
        vm.startPrank(owner);
        vm.expectRevert(FamilyVaultBase.InvalidRole.selector);
        IFamilyVaultMember(address(vault)).addMember(
            user,
            keccak256("FAKE_ROLE")
        );
        vm.stopPrank();
    }

    function test_Revert_AddMember_NotOwner() public {
        vm.startPrank(user);
        bytes32 spenderRole = vault.SPENDER_ROLE();
        vm.expectRevert(FamilyVaultBase.NotAuthorized.selector);
        IFamilyVaultMember(address(vault)).addMember(user2, spenderRole);
        vm.stopPrank();
    }

    function test_AddMember_Duplicate() public {
        vm.startPrank(owner);
        IFamilyVaultMember(address(vault)).addMember(
            user,
            vault.SPENDER_ROLE()
        );
        IFamilyVaultMember(address(vault)).addMember(
            user,
            vault.SPENDER_ROLE()
        ); // duplicado

        assertTrue(vault.isMember(user), "Membro deve continuar ativo");
        assertTrue(
            vault.hasRole(vault.SPENDER_ROLE(), user),
            "Membro deve manter a role"
        );
        vm.stopPrank();
    }

    // --------------------
    // removeMember()
    // --------------------
    function test_RemoveMember() public {
        vm.startPrank(owner);
        IFamilyVaultMember(address(vault)).addMember(
            user,
            vault.SPENDER_ROLE()
        );
        IFamilyVaultMember(address(vault)).removeMember(user);
        vm.stopPrank();

        assertFalse(vault.isMember(user), "User deve ter sido removido");
        assertFalse(
            vault.hasRole(vault.SPENDER_ROLE(), user),
            unicode"User não deve ter SPENDER_ROLE"
        );
    }

    function test_Revert_RemoveNonMember() public {
        vm.startPrank(owner);
        vm.expectRevert(FamilyVaultBase.NotMember.selector);
        IFamilyVaultMember(address(vault)).removeMember(user);
        vm.stopPrank();
    }

    function test_Revert_RemoveLastOwner() public {
        vm.startPrank(owner);
        vm.expectRevert(FamilyVaultBase.CannotRemoveLastOwner.selector);
        IFamilyVaultMember(address(vault)).removeMember(owner);
        vm.stopPrank();
    }

    function test_Revert_RemoveMember_NotOwner() public {
        vm.startPrank(owner);
        IFamilyVaultMember(address(vault)).addMember(
            user,
            vault.SPENDER_ROLE()
        );
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert(FamilyVaultBase.NotAuthorized.selector);
        IFamilyVaultMember(address(vault)).removeMember(user);
        vm.stopPrank();
    }

    function test_RemoveMember_WithMultipleRoles() public {
        vm.startPrank(owner);
        IFamilyVaultMember(address(vault)).addMember(
            user,
            vault.SPENDER_ROLE()
        );
        IFamilyVaultMember(address(vault)).updateMemberRole(
            user,
            vault.GUARDIAN_ROLE()
        );

        IFamilyVaultMember(address(vault)).removeMember(user);

        assertFalse(vault.isMember(user), "Membro deve ser removido");
        assertFalse(
            vault.hasRole(vault.SPENDER_ROLE(), user),
            "SPENDER deve ter sido revogado"
        );
        assertFalse(
            vault.hasRole(vault.GUARDIAN_ROLE(), user),
            "GUARDIAN deve ter sido revogado"
        );
        vm.stopPrank();
    }

    // --------------------
    // updateMemberRole()
    // --------------------
    function test_UpdateMemberRole() public {
        vm.startPrank(owner);
        IFamilyVaultMember(address(vault)).addMember(
            user,
            vault.SPENDER_ROLE()
        );
        IFamilyVaultMember(address(vault)).updateMemberRole(
            user,
            vault.GUARDIAN_ROLE()
        );
        vm.stopPrank();

        assertFalse(
            vault.hasRole(vault.SPENDER_ROLE(), user),
            unicode"User não deve ter SPENDER_ROLE"
        );
        assertTrue(
            vault.hasRole(vault.GUARDIAN_ROLE(), user),
            "User deve ter GUARDIAN_ROLE"
        );
    }

    function test_Revert_UpdateNonMember() public {
        vm.startPrank(owner);
        bytes32 guardianRole = vault.SPENDER_ROLE();
        vm.expectRevert(FamilyVaultBase.NotMember.selector);
        IFamilyVaultMember(address(vault)).updateMemberRole(user, guardianRole);
        vm.stopPrank();
    }

    function test_Revert_UpdateToInvalidRole() public {
        vm.startPrank(owner);
        IFamilyVaultMember(address(vault)).addMember(
            user,
            vault.SPENDER_ROLE()
        );
        vm.expectRevert(FamilyVaultBase.InvalidRole.selector);
        IFamilyVaultMember(address(vault)).updateMemberRole(
            user,
            keccak256("FAKE_ROLE")
        );
        vm.stopPrank();
    }

    function test_Revert_DowngradeLastOwner() public {
        vm.startPrank(owner);
        bytes32 spenderRole = vault.SPENDER_ROLE();
        vm.expectRevert(FamilyVaultBase.CannotDowngradeLastOwner.selector);
        IFamilyVaultMember(address(vault)).updateMemberRole(owner, spenderRole);
        vm.stopPrank();
    }

    function test_Revert_UpdateRole_NotOwner() public {
        vm.startPrank(owner);
        IFamilyVaultMember(address(vault)).addMember(
            user,
            vault.SPENDER_ROLE()
        );
        vm.stopPrank();

        vm.startPrank(user);
        bytes32 guardianRole = vault.SPENDER_ROLE();
        vm.expectRevert(FamilyVaultBase.NotAuthorized.selector);
        IFamilyVaultMember(address(vault)).updateMemberRole(user, guardianRole);
        vm.stopPrank();
    }

    // --------------------
    // pause/unpauseMember()
    // --------------------
    function test_PauseAndUnpause() public {
        vm.startPrank(owner);
        IFamilyVaultMember(address(vault)).addMember(
            user,
            vault.SPENDER_ROLE()
        );
        IFamilyVaultMember(address(vault)).pauseMember(user);
        assertTrue(
            IFamilyVaultMember(address(vault)).isMemberPaused(user),
            "User deve estar pausado"
        );

        IFamilyVaultMember(address(vault)).unpauseMember(user);
        assertFalse(
            IFamilyVaultMember(address(vault)).isMemberPaused(user),
            unicode"User não deve estar pausado"
        );
        vm.stopPrank();
    }

    function test_Revert_PauseNonMember() public {
        vm.startPrank(owner);
        vm.expectRevert(FamilyVaultBase.NotMember.selector);
        IFamilyVaultMember(address(vault)).pauseMember(user);
        vm.stopPrank();
    }

    function test_Revert_Pause_NotAuthorized() public {
        vm.startPrank(owner);
        IFamilyVaultMember(address(vault)).addMember(
            user,
            vault.SPENDER_ROLE()
        );
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert(FamilyVaultBase.NotAuthorized.selector);
        IFamilyVaultMember(address(vault)).pauseMember(user);
        vm.stopPrank();
    }

    // --------------------
    // listMembersByRole()
    // --------------------
    function test_ListMembersByRole() public {
        vm.startPrank(owner);
        IFamilyVaultMember(address(vault)).addMember(
            user,
            vault.SPENDER_ROLE()
        );
        IFamilyVaultMember(address(vault)).addMember(
            user2,
            vault.SPENDER_ROLE()
        );
        IFamilyVaultMember(address(vault)).addMember(
            guardian,
            vault.GUARDIAN_ROLE()
        );
        vm.stopPrank();

        address[] memory spenders = IFamilyVaultMember(address(vault))
            .listMembersByRole(vault.SPENDER_ROLE());
        address[] memory guardians = IFamilyVaultMember(address(vault))
            .listMembersByRole(vault.GUARDIAN_ROLE());

        assertEq(spenders.length, 2, "Deve ter 2 SPENDERS");
        assertEq(guardians.length, 2, "Deve ter 1 GUARDIAN"); //owner é guardiao tambem
    }

    function test_ListMembersByRole_Empty() public view {
        address[] memory spenders = IFamilyVaultMember(address(vault))
            .listMembersByRole(vault.SPENDER_ROLE());
        assertEq(spenders.length, 0, "Deve retornar array vazio");
    }

    // --------------------
    // isMemberActive()
    // --------------------
    function test_IsMemberActive() public {
        vm.startPrank(owner);
        IFamilyVaultMember(address(vault)).addMember(
            user,
            vault.SPENDER_ROLE()
        );

        (bool active, , bool paused) = IFamilyVaultMember(address(vault))
            .isMemberActive(user);
        assertTrue(active, "Membro deve estar ativo");
        assertFalse(paused, unicode"Membro não deve estar pausado");

        IFamilyVaultMember(address(vault)).pauseMember(user);
        (active, , paused) = IFamilyVaultMember(address(vault)).isMemberActive(
            user
        );
        assertTrue(active, unicode"Membro pausado deve estar ativo");
        assertTrue(paused, "Membro pausado deve ter paused=true");

        IFamilyVaultMember(address(vault)).unpauseMember(user);
        (active, , paused) = IFamilyVaultMember(address(vault)).isMemberActive(
            user
        );
        assertTrue(active, "Membro despausado deve estar ativo");
        assertFalse(paused, "Membro despausado deve ter paused=false");

        IFamilyVaultMember(address(vault)).removeMember(user);
        (active, , paused) = IFamilyVaultMember(address(vault)).isMemberActive(
            user
        );
        assertFalse(active, unicode"Membro removido não deve estar ativo");

        vm.stopPrank();
    }

    function test_IsMemberActive_ReturnRoles() public {
        vm.startPrank(owner);
        IFamilyVaultMember(address(vault)).addMember(
            user,
            vault.SPENDER_ROLE()
        );
        IFamilyVaultMember(address(vault)).updateMemberRole(
            user,
            vault.GUARDIAN_ROLE()
        );

        (
            bool active,
            bytes32[] memory rolesArray,
            bool paused
        ) = IFamilyVaultMember(address(vault)).isMemberActive(user);

        assertTrue(active, "Membro deve estar ativo");
        assertFalse(paused, unicode"Membro não deve estar pausado");
        assertEq(rolesArray.length, 1, "Deve ter 1 role");
        assertEq(
            rolesArray[0],
            vault.GUARDIAN_ROLE(),
            "Role deve ser GUARDIAN"
        );
        vm.stopPrank();
    }
}
