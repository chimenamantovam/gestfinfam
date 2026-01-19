// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IFamilyVaultMember {
    function addMember(address account, bytes32 role) external;

    function removeMember(address account) external;

    function updateMemberRole(address member, bytes32 newRole) external;

    function pauseMember(address member) external;

    function unpauseMember(address member) external;

    function isMemberPaused(address member) external view returns (bool);

    function listMembersByRole(
        bytes32 role
    ) external view returns (address[] memory);

    function isMemberActive(
        address member
    ) external view returns (bool active, bytes32[] memory roles, bool paused);
}
