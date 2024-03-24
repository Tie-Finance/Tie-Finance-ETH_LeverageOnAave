// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUniExchange {
    function swapExactInput(
        address tokenIn,
        address tokenOut,
        uint256 _amount,
        uint256 _minOut
    ) external  returns (uint256 amountOut);

    function swapExactOutput(
        address tokenIn,
        address tokenOut,
        uint256 _amountOut,
        uint256 _amountInMax
    ) external returns (uint256 amountIn);
}
