// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILendingStrategy {
    function vault() external view returns (address);

    // ETH Leverage address
    function ethLeverage() external view returns (address);
        // WETH Address
    function weth() external view returns (address);

    // deposit asset into aave pool
    function depositAsset() external view returns (address);

    // aave address
    function IaavePool() external view returns (address);
    
    function exchange() external view returns (address);
}
