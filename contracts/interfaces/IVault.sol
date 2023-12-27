// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVault {
    function deposit(uint256 amount,uint256 minShares,address receiver) external returns (uint256 shares);
    function withdraw(uint256 assets,uint256 minWithdraw,address receiver)external returns (uint256 shares);
    function convertToShares(uint256 assets) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function mint(uint256 amount, address account) external;
}
