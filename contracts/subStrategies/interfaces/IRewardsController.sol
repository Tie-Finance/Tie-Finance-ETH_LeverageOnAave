// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
interface  IRewardsController{
  function claimAllRewards(address[] calldata assets, address to)
    external
    returns (address[] memory rewardsList, uint256[] memory claimedAmounts);
}
