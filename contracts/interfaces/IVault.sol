// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVault {
    function deposit(address receiver) external payable returns (uint256 shares);

    function mint(uint256 amount, address account) external;
}
