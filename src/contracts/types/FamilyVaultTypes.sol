// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

library FamilyVaultTypes {
    enum RequestStatus {
        NONE,
        PENDING,
        APPROVED,
        DENIED,
        CANCELED
    }

    struct Request {
        uint256 id;
        address requester;
        uint64 categoryId;
        uint128 amount;
        RequestStatus status;
        uint256 createdAt;
        string note;
    }

    struct Category {
        uint64 id;
        string name;
        uint128 monthlyLimit;
        uint128 spent;
        uint64 periodStart;
        address token;
        bool active;
    }

    struct TokenInfo {
        string symbol;
        bool active;
    }
}
