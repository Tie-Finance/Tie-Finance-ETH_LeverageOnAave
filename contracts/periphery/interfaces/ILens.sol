// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILens {
    function getDepositOut(uint256 assets) external view returns (uint256);
    function getRedeemOut(uint256 shares) external view returns (uint256);
}
