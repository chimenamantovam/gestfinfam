// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IFamilyVaultFund {
    function spend(uint64 categoryId, uint128 amount, address to) external;

    function depositNative() external payable;

    function withdraw(address payable to, uint256 amount) external;

    function depositERC20(address token, uint256 amount) external;

    function withdrawERC20(address token, address to, uint256 amount) external;

    function contractBalance(address token) external view returns (uint256);
}
