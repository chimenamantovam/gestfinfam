// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {FamilyVault} from "../../src/contracts/FamilyVault.sol";
import {FamilyVaultBase} from "../../src/contracts/base/FamilyVaultBase.sol";
import {FamilyVaultTestHelper} from "../helpers/FamilyVaultTestHelper.sol";
import {MockERC20} from "../mock/MockERC20.sol";

import {IFamilyVaultAllowance} from "../interfaces/IFamilyVaultAllowance.sol";
import {IFamilyVaultCategory} from "../interfaces/IFamilyVaultCategory.sol";
import {IFamilyVaultFund} from "../interfaces/IFamilyVaultFund.sol";
import {IFamilyVaultMember} from "../interfaces/IFamilyVaultMember.sol";
import {IFamilyVaultRequest} from "../interfaces/IFamilyVaultRequest.sol";

import {FamilyVaultTypes} from "../../src/contracts/types/FamilyVaultTypes.sol";

contract FamilyVaultRequestTests is Test, FamilyVaultTestHelper {
    FamilyVault public vault;
    MockERC20 public token;

    address public owner;
    address public user;
    address public guardian;

    function setUp() public {
        owner = address(0x1);
        user = address(0x2);
        guardian = address(0x3);

        vm.startPrank(owner);
        vault = deployFamilyVaultWithProxy(owner);
        token = new MockERC20();

        // Cria membros
        _addMember(owner, vault.OWNER_ROLE());
        _addMember(user, vault.SPENDER_ROLE());
        _addMember(guardian, vault.GUARDIAN_ROLE());

        //Adicionando valor no contrato
        IFamilyVaultFund(address(vault)).depositNative{value: 200 ether}();

        // Cria categoria e allowance
        _createCategory(unicode"Alimentação", 100 ether);
        _setAllowance(user, 1, 50 ether);

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

    function _createCategory(string memory name, uint128 limit) internal {
        vm.startPrank(owner);
        IFamilyVaultCategory(address(vault)).createCategory(
            name,
            limit,
            address(0)
        );
        vm.stopPrank();
    }

    function _setAllowance(
        address member,
        uint64 categoryId,
        uint128 amount
    ) internal {
        vm.startPrank(owner);
        IFamilyVaultAllowance(address(vault)).setAllowance(
            member,
            categoryId,
            amount
        );
        vm.stopPrank();
    }

    function _createRequest(
        address spender,
        uint64 categoryId,
        uint128 amount
    ) internal returns (uint256) {
        vm.startPrank(spender);
        uint256 requestId = IFamilyVaultRequest(address(vault)).createRequest(
            categoryId,
            amount,
            "motivo"
        );
        vm.stopPrank();
        return requestId;
    }

    function _approveRequest(uint256 requestId, address aprovador) internal {
        vm.startPrank(aprovador);
        IFamilyVaultRequest(address(vault)).approveRequest(
            requestId,
            aprovador
        );
        vm.stopPrank();
    }

    function _denyRequest(uint256 requestId, string memory reason) internal {
        vm.startPrank(owner);
        IFamilyVaultRequest(address(vault)).denyRequest(requestId, reason);
        vm.stopPrank();
    }

    function _cancelRequest(address spender, uint256 requestId) internal {
        vm.startPrank(spender);
        IFamilyVaultRequest(address(vault)).cancelRequest(requestId);
        vm.stopPrank();
    }

    // --------------------
    // Tests: createRequest
    // --------------------
    function test_CreateRequest_Success() public {
        uint256 requestId = _createRequest(user, 1, 10 ether);

        (
            ,
            ,
            uint128 amount,
            FamilyVaultTypes.RequestStatus status,

        ) = IFamilyVaultRequest(address(vault)).getRequestById(requestId);
        assertEq(amount, 10 ether);
        assertEq(uint8(status), uint8(FamilyVaultTypes.RequestStatus.PENDING));
    }

    function test_Revert_CreateRequest_CategoryNotSet() public {
        vm.startPrank(user);
        vm.expectRevert(FamilyVaultBase.CategoryNotSet.selector);
        IFamilyVaultRequest(address(vault)).createRequest(
            999,
            10 ether,
            "motivo"
        );
        vm.stopPrank();
    }

    function test_Revert_CreateRequest_ZeroAmount() public {
        vm.startPrank(user);
        vm.expectRevert(FamilyVaultBase.ZeroAmountNotAllowed.selector);
        IFamilyVaultRequest(address(vault)).createRequest(1, 0, "motivo");
        vm.stopPrank();
    }

    function test_Revert_CreateRequest_NotAuthorized() public {
        vm.startPrank(guardian);
        vm.expectRevert(FamilyVaultBase.NotAuthorized.selector);
        IFamilyVaultRequest(address(vault)).createRequest(
            1,
            10 ether,
            "motivo"
        );
        vm.stopPrank();
    }

    // --------------------
    // Tests: approveRequest
    // --------------------
    function test_ApproveRequest_Success() public {
        uint256 requestId = _createRequest(user, 1, 10 ether);
        _approveRequest(requestId, owner);

        (, , , FamilyVaultTypes.RequestStatus status, ) = IFamilyVaultRequest(
            address(vault)
        ).getRequestById(requestId);
        assertEq(uint8(status), uint8(FamilyVaultTypes.RequestStatus.APPROVED));
    }

    function test_Revert_ApproveRequest_AlreadyDecided() public {
        uint256 requestId = _createRequest(user, 1, 10 ether);
        _approveRequest(requestId, owner);
        vm.expectRevert(FamilyVaultBase.AlreadyDecided.selector);
        _approveRequest(requestId, owner);
    }

    function test_Revert_ApproveRequest_NotAuthorized() public {
        uint256 requestId = _createRequest(user, 1, 10 ether);
        vm.expectRevert(FamilyVaultBase.NotAuthorized.selector);
        _approveRequest(requestId, user);
    }

    // --------------------
    // Tests: denyRequest
    // --------------------
    function test_DenyRequest_Success() public {
        uint256 requestId = _createRequest(user, 1, 10 ether);
        _denyRequest(requestId, "reason");

        (, , , FamilyVaultTypes.RequestStatus status, ) = IFamilyVaultRequest(
            address(vault)
        ).getRequestById(requestId);
        assertEq(uint8(status), uint8(FamilyVaultTypes.RequestStatus.DENIED));
    }

    function test_Revert_DenyRequest_AlreadyDecided() public {
        uint256 requestId = _createRequest(user, 1, 10 ether);
        _denyRequest(requestId, "reson");
        vm.startPrank(owner);
        vm.expectRevert(FamilyVaultBase.AlreadyDecided.selector);
        IFamilyVaultRequest(address(vault)).denyRequest(requestId, "reson");
        vm.stopPrank();
    }

    // --------------------
    // Tests: cancelRequest
    // --------------------
    function test_CancelRequest_Success() public {
        uint256 requestId = _createRequest(user, 1, 10 ether);
        _cancelRequest(user, requestId);
        (, , , FamilyVaultTypes.RequestStatus status, ) = IFamilyVaultRequest(
            address(vault)
        ).getRequestById(requestId);
        assertEq(uint8(status), uint8(FamilyVaultTypes.RequestStatus.CANCELED));
    }

    function test_Revert_CancelRequest_NotYourRequest() public {
        uint256 requestId = _createRequest(user, 1, 10 ether);
        vm.startPrank(guardian);
        vm.expectRevert(FamilyVaultBase.NotYourRequest.selector);
        IFamilyVaultRequest(address(vault)).cancelRequest(requestId);
        vm.stopPrank();
    }

    function test_Revert_CancelRequest_RequestCannotBeCanceled() public {
        uint256 requestId = _createRequest(user, 1, 10 ether);
        _approveRequest(requestId, owner);
        vm.startPrank(user);
        vm.expectRevert(FamilyVaultBase.RequestCannotBeCanceled.selector);
        IFamilyVaultRequest(address(vault)).cancelRequest(requestId);
        vm.stopPrank();
    }

    // --------------------
    // Tests: getRequestsByStatus
    // --------------------
    function test_GetRequestsByStatus() public {
        uint256 r1 = _createRequest(user, 1, 10 ether);
        uint256 r2 = _createRequest(user, 1, 5 ether);

        _approveRequest(r1, owner);
        _denyRequest(r2, "reason");

        FamilyVaultTypes.Request[] memory approved = IFamilyVaultRequest(
            address(vault)
        ).getRequestsByStatus(FamilyVaultTypes.RequestStatus.APPROVED);

        FamilyVaultTypes.Request[] memory denied = IFamilyVaultRequest(
            address(vault)
        ).getRequestsByStatus(FamilyVaultTypes.RequestStatus.DENIED);

        assertEq(approved.length, 1);
        assertEq(denied.length, 1);
        assertEq(approved[0].id, r1);
        assertEq(denied[0].id, r2);
    }
}
