// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
interface  IRewardsController{
  function claimAllRewards(address[] calldata assets, address to)
    external
    returns (address[] memory rewardsList, uint256[] memory claimedAmounts);
      /**
   * @dev Returns a list all rewards of a user, including already accrued and unrealized claimable rewards
   * @param assets List of incentivized assets to check eligible distributions
   * @param user The address of the user
   * @return The list of reward addresses
   * @return The list of unclaimed amount of rewards
   **/
  function getAllUserRewards(address[] calldata assets, address user)
    external
    view
    returns (address[] memory, uint256[] memory);
}
