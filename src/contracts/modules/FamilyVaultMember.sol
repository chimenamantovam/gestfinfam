//SPDX-License-Identifier:MIT
pragma solidity ^0.8.27;

import {FamilyVaultBase} from "../base/FamilyVaultBase.sol";

contract FamilyVaultMember is FamilyVaultBase {
    // ----------- Events ----------- //
    /** @notice Emite quando um membro é adicionado */
    event MemberAdded(address indexed member, bytes32 role);
    /** @notice Emite quando um membro é removido */
    event MemberRemoved(address indexed member);
    /** @notice Emite quando um membro recebe uma nova role*/
    event MemberUpdated(address indexed member, bytes32 newRole);
    /** @notice Emite quando um membro é bloqueado */
    event MemberPaused(address indexed member);
    /** @notice Emite quando um membro é desbloqueado */
    event MemberUnpaused(address indexed member);

    // -----------------------------------------
    // Member Management
    // -----------------------------------------
    /**
     * @notice Adiciona um membro ao contrato
     * @param member Endereço do membro
     * @param role Role a ser atribuída (OWNER_ROLE, SPENDER_ROLE, GUARDIAN_ROLE)
     */
    function addMember(address member, bytes32 role) external onlyOwner {
        require(member != address(0), ZeroAddress());
        require(
            role == OWNER_ROLE || role == SPENDER_ROLE || role == GUARDIAN_ROLE,
            InvalidRole()
        );
        isMember[member] = true;
        _grantRole(role, member);
        emit MemberAdded(member, role);
    }

    /**
     * @notice Remove um membro do contrato
     * @param member Endereço do membro a ser removido
     */
    function removeMember(address member) external onlyOwner {
        require(isMember[member], NotMember());
        if (hasRole(OWNER_ROLE, member)) {
            uint256 ownerCount = getRoleMemberCount(OWNER_ROLE);
            require(ownerCount > 1, CannotRemoveLastOwner());
        }
        isMember[member] = false;
        pausedMembers[member] = false;
        /*Mesmo que o membro não tenha todas as roles é mais barato revogar as 3 roles. 
          Só compensa utilizar AccessControlEnumerable para verificar se o membro tem a role
          para revogar quando tivermos aproximadamente 10 roles. */
        _revokeRole(OWNER_ROLE, member);
        _revokeRole(SPENDER_ROLE, member);
        _revokeRole(GUARDIAN_ROLE, member);
        emit MemberRemoved(member);
    }

    /**
     * @notice Atualiza a permissão de um membro do contrato
     * @param member Endereço do membro a ser alterado
     * @param newRole Nova role a ser atribuida ao membro
     */
    function updateMemberRole(
        address member,
        bytes32 newRole
    ) external onlyOwner memberExists(member) {
        require(
            newRole == OWNER_ROLE ||
                newRole == SPENDER_ROLE ||
                newRole == GUARDIAN_ROLE,
            InvalidRole()
        );

        // Se for alterar um OWNER, garantir que não é o último
        if (hasRole(OWNER_ROLE, member) && newRole != OWNER_ROLE) {
            uint256 ownerCount = getRoleMemberCount(OWNER_ROLE);
            require(ownerCount > 1, CannotDowngradeLastOwner());
        }

        // Revoga todas as roles atuais
        _revokeRole(OWNER_ROLE, member);
        _revokeRole(SPENDER_ROLE, member);
        _revokeRole(GUARDIAN_ROLE, member);

        // Concede a nova role
        _grantRole(newRole, member);
        emit MemberUpdated(member, newRole);
    }

    /**
     * @notice Pausa um membro específico, impedindo-o de executar ações
     * @dev Apenas OWNER ou GUARDIAN podem pausar
     */
    function pauseMember(
        address member
    ) external onlyOwnerOrGuardian memberExists(member) {
        require(!pausedMembers[member], MemberAlreadyPaused());
        pausedMembers[member] = true;
        emit MemberPaused(member);
    }

    /**
     * @notice Retira o pause de um membro
     * @dev Apenas OWNER ou GUARDIAN podem despausar
     */
    function unpauseMember(
        address member
    ) external onlyOwnerOrGuardian memberExists(member) {
        require(pausedMembers[member], MemberNotPaused());
        pausedMembers[member] = false;
        emit MemberUnpaused(member);
    }

    /**
     * @notice Consulta se o membro está pausado
     */
    function isMemberPaused(address member) external view returns (bool) {
        return pausedMembers[member];
    }

    /**
     * @notice Lista membros por roles
     * @param role Role escolhida para listar
     */
    function listMembersByRole(
        bytes32 role
    ) external view returns (address[] memory) {
        uint256 count = getRoleMemberCount(role);
        address[] memory members = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            members[i] = getRoleMember(role, i);
        }
        return members;
    }

    /**
     * @notice Checa o status, retornando se o membro ainda esta ativo e qual role ele possui.
     * @param member Member
     * @return active
     * @return roles
     * @return paused
     */
    function isMemberActive(
        address member
    ) external view returns (bool active, bytes32[] memory roles, bool paused) {
        active = isMember[member];
        paused = pausedMembers[member];

        // Contar quantas roles o membro possui
        uint256 count = 0;
        if (hasRole(OWNER_ROLE, member)) count++;
        if (hasRole(SPENDER_ROLE, member)) count++;
        if (hasRole(GUARDIAN_ROLE, member)) count++;

        // Criar array com tamanho exato
        roles = new bytes32[](count);
        uint256 index = 0;

        if (hasRole(OWNER_ROLE, member)) {
            roles[index] = OWNER_ROLE;
            index++;
        }
        if (hasRole(SPENDER_ROLE, member)) {
            roles[index] = SPENDER_ROLE;
            index++;
        }
        if (hasRole(GUARDIAN_ROLE, member)) {
            roles[index] = GUARDIAN_ROLE;
            index++;
        }
    }
}
