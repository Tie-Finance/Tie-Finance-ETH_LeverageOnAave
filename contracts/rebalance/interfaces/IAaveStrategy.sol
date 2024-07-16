// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAaveStrategy {
    function setMLR(uint256 _mlr,uint256 slippage) external;
}
