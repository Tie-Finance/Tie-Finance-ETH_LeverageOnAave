// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./farmClaim.sol";
import "./interfaces/IRewardsController.sol";

abstract contract farmSpark is farmClaim{
    address public rewardsController;
    address[] public rewardsAssets;
    event SetRawardsInfo(address caller,address rewardsController,address[] rewardsAssets);

    constructor(
    ) {

    }
    function setRawardsInfo(address _rewardsController,address[] calldata _rewardsAssets) external onlyOwner{
        rewardsController = _rewardsController;
        rewardsAssets = _rewardsAssets;
        emit SetRawardsInfo(msg.sender,_rewardsController,_rewardsAssets);
    }
    function claimRewards(uint256 slippage)internal override{
        (address[] memory rewardsList, uint256[] memory claimedAmounts) = 
            IRewardsController(rewardsController).claimAllRewards(rewardsAssets,address(this));
        address _depositAsset = getDepositAsset();
        for (uint256 i=0;i<rewardsList.length;i++){
            address rewardToken = rewardsList[i];
            if (rewardToken == _depositAsset){
                continue;
            }
            uint256 balance = claimedAmounts[i];
            if (balance > 0){
                uint256 _minOut = getMinOut(rewardToken,_depositAsset,balance,slippage); 
                rewardsSwap(rewardToken, _depositAsset, balance, _minOut);
            }
        }
    }
    function rewardsSwap(address tokenIn,address tokenOut,uint256 amount,uint256 minAmount) internal virtual returns (uint256);
}