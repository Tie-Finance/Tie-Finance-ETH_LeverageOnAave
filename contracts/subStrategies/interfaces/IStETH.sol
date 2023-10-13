// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStETH {
    function submit(address) external payable;
    function getSharesByPooledEth(uint256 _ethAmount) external view returns(uint256);

}
