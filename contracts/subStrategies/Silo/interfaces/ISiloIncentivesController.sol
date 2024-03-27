// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;


interface ISiloIncentivesController {
    function getRewardsBalance(address[] calldata assets, address user) external view returns (uint256);
    function claimRewards(address[] calldata assets,uint256 amount,address to) external returns (uint256);
}