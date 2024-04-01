// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "./farmStrategy.sol";
import "./interfaces/ISilo.sol";
import "./interfaces/ISiloIncentivesController.sol";
import "../interfaces/IExchange.sol";
import "../interfaces/IUniExchange.sol";
contract SiloStrategy is farmStrategy {
    using SafeERC20 for IERC20;
    uint256 constant calDecimals = 1e18;
    address public shareToken;
    // Sub Strategy name
    string public constant poolName = "Silo Strategy V1.0";

        // Exchange Address
    address public exchange;

    event SetExchange(address exchange);


    constructor(
        address _baseAsset,
        address _depoistAsset,
        address _vault,
        address _depositPool,
        address _farmPool,
        address _feePool
    )
        farmStrategy(_baseAsset,_depoistAsset,_vault,_depositPool,_farmPool,_feePool){
        ISilo.AssetStorage memory assetInfo = ISilo(_depositPool).assetStorage(_depoistAsset);
        shareToken = assetInfo.collateralToken;
    }
        /**
        Set Exchange
     */
    function setExchange(address _exchange) external onlyOwner {
        require(_exchange != address(0), "INVALID_ADDRESS");
        exchange = _exchange;
        emit SetExchange(_exchange);
    }
    function convertLPToDeposit(uint256 lpAmount) internal view returns (uint256){
        uint256 totalSupply = IERC20(shareToken).totalSupply();
        if (totalSupply == 0){
            return lpAmount;
        }
        ISilo.AssetStorage memory assetInfo = ISilo(depositPool).assetStorage(depositAsset);
        return lpAmount*assetInfo.totalDeposits/totalSupply;
    }
    /*
    function convertDepositToLp(uint256 _amount) internal view returns (uint256){
        uint256 totalSupply = IERC20(shareToken).totalSupply();
        if (totalSupply == 0){
            return _amount;
        }
        ISilo.AssetStorage memory assetInfo = ISilo(depositPool).assetStorage(depositAsset);
        return _amount*totalSupply/assetInfo.totalDeposits;
    }
    */
    function depositToken(uint256 amount) internal override{
        approve(depositAsset, depositPool);
        ISilo(depositPool).depositFor(depositAsset,address(this), amount, false);
    }
    function withdrawToken(uint256 amount)internal override{
        ISilo(depositPool).withdraw(depositAsset,amount, false);
    }
    function claimRewards(uint256 slipPage)internal override{
        address[] memory assets = new address[](1);
        assets[0] = shareToken;
        uint256 reward = ISiloIncentivesController(farmPool).getRewardsBalance(assets, address(this));
        uint256 minOut = getMinOut(rewardTokens[0],depositAsset,reward,slipPage == magnifier ? 5000 : slipPage);
        if(minOut>0){
            ISiloIncentivesController(farmPool).claimRewards(assets,type(uint256).max, address(this));
            swapRewardsToDepositAsset(slipPage);
        }
    }
    function getRewardBalance() external view returns (uint256){
        address[] memory assets = new address[](1);
        assets[0] = shareToken;
        uint256 reward = ISiloIncentivesController(farmPool).getRewardsBalance(assets, address(this));
        return getMinOut(rewardTokens[0],baseAsset,reward,0);
    }
    function getRebalanceRepay()external view returns (uint256){
        address[] memory assets = new address[](1);
        assets[0] = shareToken;
        uint256 reward = ISiloIncentivesController(farmPool).getRewardsBalance(assets,address(this));
        return getMinOut(rewardTokens[0],depositAsset,reward,magnifier-rebalanceFee);
    }
    function _totalDeposit() internal view override returns (uint256){
        uint256 shareBalance = IERC20(shareToken).balanceOf(address(this));
        return convertLPToDeposit(shareBalance);
    }
    function swapDepositAssetTobaseAsset(uint256 amount,uint256 minAmount) internal override returns(uint256){
        approve(depositAsset, exchange);
        return IExchange(exchange).swap(depositAsset, baseAsset, amount, minAmount);
    }
    function swapBaseAssetToDepositAsset(uint256 amount,uint256 minAmount) internal override returns(uint256){
        approve(baseAsset, exchange);
        return IExchange(exchange).swap( baseAsset,depositAsset, amount, minAmount);
    }
    function swapRewardsToDepositAsset(uint256 slipPage) internal returns(uint256){
        uint256 balance =0;
        for (uint256 i=0;i<rewardTokens.length;i++){
            address reward = rewardTokens[i];
            balance = IERC20(reward).balanceOf(address(this));
            if (balance > 0){
                uint256 _minOut = getMinOut(reward,depositAsset,balance,slipPage); 
                approve(reward,exchange);
                IExchange(exchange).swap(reward, depositAsset, balance, _minOut);
            }
        }

    }
}
