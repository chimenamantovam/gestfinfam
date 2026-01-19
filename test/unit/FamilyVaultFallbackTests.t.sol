// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {FamilyVault} from "../../src/contracts/FamilyVault.sol";
import {FamilyVaultBase} from "../../src/contracts/base/FamilyVaultBase.sol";
import {FamilyVaultTestHelper} from "../helpers/FamilyVaultTestHelper.sol";

contract FamilyVaultFallbackTests is Test, FamilyVaultTestHelper {
    FamilyVault vault;
    address owner = address(0x1);
    address sender = address(0x2);

    function setUp() public {
        vm.startPrank(owner);
        vault = deployFamilyVaultWithProxy(owner);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            SUCCESSFUL DEPOSITS
    //////////////////////////////////////////////////////////////*/

    /// @notice Recebe token nativo via receive()
    function test_Receive_ETH_Success() public {
        uint256 depositAmount = 1 ether;

        // Envia token nativo para o contrato (receive() será chamado)
        vm.deal(sender, depositAmount);
        vm.prank(sender);
        (bool ok, ) = address(vault).call{value: depositAmount}("");
        require(ok, "Fallback call failed");

        // Confirma saldo do contrato
        assertEq(address(vault).balance, depositAmount);
    }

    /// @notice Recebe token nativo via fallback() (chamada com dados não reconhecidos)
    function test_Fallback_ETH_Success() public {
        uint256 depositAmount = 2 ether;

        bytes memory data = abi.encodeWithSignature("unknownFunction()");
        vm.deal(sender, depositAmount);
        vm.prank(sender);
        (bool ok, ) = address(vault).call{value: depositAmount}(data);
        require(ok, "Fallback call failed");

        // Confirma saldo do contrato
        assertEq(address(vault).balance, depositAmount);
    }

    /*//////////////////////////////////////////////////////////////
                            REVERTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Reverte se msg.value = 0 (receive)
    function test_Revert_Receive_ZeroValue() public {
        vm.prank(sender);
        vm.expectRevert(FamilyVaultBase.ZeroDepositNotAllowed.selector);
        (bool ok, ) = address(vault).call{value: 0}("");
        require(ok, "Fallback call should have reverted");
    }

    /// @notice Reverte se signature not exist and msg.value = 0 (fallback)
    function test_Revert_Fallback_UnknowFunctionAndZeroValue() public {
        bytes memory data = abi.encodeWithSignature("unknownFunction()");
        vm.prank(sender);
        vm.expectRevert("Logic module not set");
        (bool ok, ) = address(vault).call{value: 0}(data);
        require(ok, "Fallback call should have reverted");
    }
}
