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
    address public pool;
    // Sub Strategy name
    string public constant poolName = "Silo Strategy V1.0";

        // Exchange Address
    address public exchange;
    address public uniExchange;

    event SetExchange(address exchange,address uniExchange);


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
    function setExchange(address _exchange,address _uniExchange) external onlyOwner {
        require(_exchange != address(0) && _uniExchange!= address(0), "INVALID_ADDRESS");
        exchange = _exchange;
        uniExchange = _uniExchange;
        emit SetExchange(_exchange,_uniExchange);
    }
    function convertLPToUnderlying(uint256 lpAmount) internal view returns (uint256){
        uint256 totalSupply = IERC20(shareToken).totalSupply();
        if (totalSupply == 0){
            return lpAmount;
        }
        ISilo.AssetStorage memory assetInfo = ISilo(depositPool).assetStorage(depositAsset);
        return lpAmount*assetInfo.totalDeposits/totalSupply;
    }
    function convertUnderlyingToLp(uint256 _amount) internal view returns (uint256){
        uint256 totalSupply = IERC20(shareToken).totalSupply();
        if (totalSupply == 0){
            return _amount;
        }
        ISilo.AssetStorage memory assetInfo = ISilo(depositPool).assetStorage(depositAsset);
        return _amount*totalSupply/assetInfo.totalDeposits;
    }
    function depositToken(uint256 amount) internal override{
        approve(depositAsset, depositPool);
        ISilo(depositPool).depositFor(depositAsset,address(this), amount, false);
    }
    function withdrawToken(uint256 amount)internal override{
        ISilo(farmPool).withdrawFor(depositAsset,address(this), address(this),amount, false);
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
    function _totalAssets() internal view override returns (uint256){
        uint256 shareBalance = IERC20(shareToken).balanceOf(address(this));
        uint256 amount = convertLPToUnderlying(shareBalance);
        return getMinOut(depositAsset,baseAsset,amount,0);
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
                uint256 _minOut = getMinOut(reward,baseAsset,balance,slipPage); 
                approve(reward,uniExchange);
                balance = IUniExchange(uniExchange).swapExactInput(reward,baseAsset,
                balance , _minOut);
                _minOut = getMinOut(baseAsset,depositAsset,balance,slipPage); 
                swapBaseAssetToDepositAsset(balance,_minOut);
            }
        }

    }
}
