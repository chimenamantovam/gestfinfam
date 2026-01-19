// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {FamilyVaultTypes} from "../../src/contracts/types/FamilyVaultTypes.sol";

interface IFamilyVaultRequest {
    function createRequest(
        uint64 categoryId,
        uint128 amount,
        string calldata note
    ) external returns (uint256 requestId);

    function approveRequest(uint256 requestId, address to) external;

    function denyRequest(uint256 requestId, string calldata reason) external;

    function cancelRequest(uint256 requestId) external;

    function getRequestsByStatus(
        FamilyVaultTypes.RequestStatus status
    ) external view returns (FamilyVaultTypes.Request[] memory);

    function getLastRequestId() external view returns (uint256);

    function getRequestById(
        uint256 requestId
    )
        external
        view
        returns (
            address requester,
            uint64 categoryId,
            uint128 amount,
            FamilyVaultTypes.RequestStatus status,
            uint256 createdAt
        );
}
