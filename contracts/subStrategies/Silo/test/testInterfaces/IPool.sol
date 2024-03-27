// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
interface IPool{
    function amountLPtoLD(uint256 _amountLP) external view returns (uint256);
}
