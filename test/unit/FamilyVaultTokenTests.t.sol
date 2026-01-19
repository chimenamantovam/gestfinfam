// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {FamilyVault} from "../../src/contracts/FamilyVault.sol";
import {FamilyVaultBase} from "../../src/contracts/base/FamilyVaultBase.sol";
import {FamilyVaultTestHelper} from "../helpers/FamilyVaultTestHelper.sol";
import {MockERC20} from "../mock/MockERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IFamilyVaultMember} from "../interfaces/IFamilyVaultMember.sol";
import {IFamilyVaultToken} from "../interfaces/IFamilyVaultToken.sol";

import {FamilyVaultTypes} from "../../src/contracts/types/FamilyVaultTypes.sol";

contract FamilyVaultTokensTest is Test, FamilyVaultTestHelper {
    using SafeERC20 for MockERC20;

    FamilyVault public vault;
    MockERC20 public token;
    address public owner;
    address public user;

    function setUp() public {
        owner = address(0x1);
        user = address(0x2);

        vm.startPrank(owner);
        vault = deployFamilyVaultWithProxy(owner);

        token = new MockERC20();
        token.safeTransfer(owner, 100 ether);

        _addMember(owner, vault.OWNER_ROLE());
        _addMember(user, vault.SPENDER_ROLE());

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

    // --------------------
    // Access Control Tests
    // --------------------
    function test_SetToken_RevertIfNotContract() public {
        address nonContract = address(0xABC123);
        vm.startPrank(owner);
        vm.expectRevert(FamilyVaultBase.InvalidTokenAddress.selector);
        IFamilyVaultToken(address(vault)).setToken(nonContract, true);
        vm.stopPrank();
    }

    function test_SetToken_RevertIfNotOwner() public {
        vm.startPrank(user);
        vm.expectRevert();
        IFamilyVaultToken(address(vault)).setToken(address(token), true);
        vm.stopPrank();
    }

    function test_SetToken_RevertIfZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(FamilyVaultBase.InvalidTokenAddress.selector);
        IFamilyVaultToken(address(vault)).setToken(address(0), true);
        vm.stopPrank();
    }

    // --------------------
    // Add / Update Token Tests
    // --------------------
    function test_SetToken_AddNewToken() public {
        vm.startPrank(owner);
        IFamilyVaultToken(address(vault)).setToken(address(token), true);

        FamilyVaultTypes.TokenInfo memory info = IFamilyVaultToken(
            address(vault)
        ).getToken(address(token));
        assertTrue(info.active, "Token deve estar ativo");
        assertEq(info.symbol, token.symbol(), unicode"Símbolo incorreto");

        address[] memory allTokens = IFamilyVaultToken(address(vault))
            .getAllTokens();
        assertEq(allTokens.length, 1, "Lista deve ter 1 token");
        assertEq(allTokens[0], address(token), unicode"Endereço incorreto");

        vm.stopPrank();
    }

    function test_SetToken_UpdateExisting() public {
        vm.startPrank(owner);

        IFamilyVaultToken(address(vault)).setToken(address(token), true);
        uint256 lengthBefore = IFamilyVaultToken(address(vault))
            .getAllTokens()
            .length;

        IFamilyVaultToken(address(vault)).setToken(address(token), false);
        uint256 lengthAfter = IFamilyVaultToken(address(vault))
            .getAllTokens()
            .length;

        assertEq(
            lengthBefore,
            lengthAfter,
            unicode"Lista de tokens não deve aumentar"
        );
        assertFalse(
            IFamilyVaultToken(address(vault)).getToken(address(token)).active,
            "Token deve estar inativo"
        );

        vm.stopPrank();
    }

    function test_SetToken_MultipleUpdates_NoDuplicates() public {
        vm.startPrank(owner);

        IFamilyVaultToken(address(vault)).setToken(address(token), true);
        IFamilyVaultToken(address(vault)).setToken(address(token), false);
        IFamilyVaultToken(address(vault)).setToken(address(token), true);

        address[] memory list = IFamilyVaultToken(address(vault))
            .getAllTokens();
        assertEq(
            list.length,
            1,
            unicode"Token não pode ser duplicado na lista"
        );

        vm.stopPrank();
    }

    function test_SetToken_InactiveStillAddedToList() public {
        vm.startPrank(owner);
        IFamilyVaultToken(address(vault)).setToken(address(token), false);
        vm.stopPrank();

        address[] memory list = IFamilyVaultToken(address(vault))
            .getAllTokens();
        assertEq(list.length, 1);
        assertEq(list[0], address(token));
    }

    // --------------------
    // Get Token Tests
    // --------------------
    function test_GetToken_ReturnsCorrectInfo() public {
        vm.startPrank(owner);
        IFamilyVaultToken(address(vault)).setToken(address(token), true);
        vm.stopPrank();

        FamilyVaultTypes.TokenInfo memory info = IFamilyVaultToken(
            address(vault)
        ).getToken(address(token));
        assertEq(
            info.symbol,
            token.symbol(),
            unicode"Símbolo do token incorreto"
        );
        assertTrue(info.active, "Token deve estar ativo");
    }

    function test_GetAllTokens_ReturnsCorrectList() public {
        MockERC20 token2 = new MockERC20();

        vm.startPrank(owner);
        IFamilyVaultToken(address(vault)).setToken(address(token), true);
        IFamilyVaultToken(address(vault)).setToken(address(token2), true);
        vm.stopPrank();

        address[] memory tokens = IFamilyVaultToken(address(vault))
            .getAllTokens();
        assertEq(tokens.length, 2, "Deve retornar 2 tokens");
        assertEq(tokens[0], address(token));
        assertEq(tokens[1], address(token2));
    }

    function test_GetToken_NotSet_ReturnsEmpty() public view {
        FamilyVaultTypes.TokenInfo memory info = IFamilyVaultToken(
            address(vault)
        ).getToken(address(0x999));
        assertEq(bytes(info.symbol).length, 0, "Symbol deve ser vazio");
        assertFalse(info.active, "Active deve ser false");
    }

    // --------------------
    // Symbol Fallback / Weird Symbols
    // --------------------
    function test_SetToken_FallbackSymbol() public {
        MockNoSymbolToken noSymbol = new MockNoSymbolToken();

        vm.startPrank(owner);
        IFamilyVaultToken(address(vault)).setToken(address(noSymbol), true);
        FamilyVaultTypes.TokenInfo memory info = IFamilyVaultToken(
            address(vault)
        ).getToken(address(noSymbol));
        assertEq(
            info.symbol,
            "UNKNOWN",
            "Token sem symbol deve retornar UNKNOWN"
        );
        vm.stopPrank();
    }

    function test_SetToken_WeirdSymbolAccepted() public {
        MockWeirdSymbolToken weird = new MockWeirdSymbolToken();

        vm.startPrank(owner);
        IFamilyVaultToken(address(vault)).setToken(address(weird), true);
        FamilyVaultTypes.TokenInfo memory info = IFamilyVaultToken(
            address(vault)
        ).getToken(address(weird));
        assertEq(info.symbol, "12345678901234567890_SYMBOL");
        vm.stopPrank();
    }
}

// --------------------
// Mocks
// --------------------
contract MockNoSymbolToken {
    function totalSupply() external pure returns (uint256) {}

    function balanceOf(address) external pure returns (uint256) {}

    function transfer(address, uint256) external pure returns (bool) {}

    function allowance(address, address) external pure returns (uint256) {}

    function approve(address, uint256) external pure returns (bool) {}

    function transferFrom(
        address,
        address,
        uint256
    ) external pure returns (bool) {}
}

contract MockWeirdSymbolToken {
    function symbol() external pure returns (string memory) {
        return "12345678901234567890_SYMBOL";
    }
}
