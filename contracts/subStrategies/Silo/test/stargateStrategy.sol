// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "../farmStrategy.sol";
import "./testInterfaces/IStargateRouter.sol";
import "./testInterfaces/ILPStaking.sol";
import "./testInterfaces/IPool.sol";
import "../../interfaces/IExchange.sol";
import "../../interfaces/IUniExchange.sol";
contract stargateStrategy is farmStrategy {
    using SafeERC20 for IERC20;
    uint256 constant calDecimals = 1e18;
    address public lpToken;
    address public pool;
    // Sub Strategy name
    string public constant poolName = "stargate Strategy V1.0";

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
        address _feePool,
        address _lpToken
    )
        farmStrategy(_baseAsset,_depoistAsset,_vault,_depositPool,_farmPool,_feePool){
        require(_lpToken != address(0), "INVALID_ADDRESS");
        lpToken = _lpToken;
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
    function convertLPToDeposit(uint256 lpAmount) internal view returns (uint256){
        return IPool(lpToken).amountLPtoLD(lpAmount);
    }
    function convertDepositToLp(uint256 _amount) internal view returns (uint256){
        uint256 temp = IPool(lpToken).amountLPtoLD(_amount);
        return _amount*_amount/temp;
    }
    function depositToken(uint256 amount) internal override{
        approve(depositAsset, depositPool);
        IStargateRouter(depositPool).addLiquidity(2, amount, address(this));
        approve(lpToken, farmPool);
        ILPStaking(farmPool).deposit(1, IERC20(lpToken).balanceOf(address(this)));
    }
    function withdrawToken(uint256 amount)internal override{
        uint256 lp = convertDepositToLp(amount);
        ILPStaking(farmPool).withdraw(1, lp);
        IStargateRouter(depositPool).instantRedeemLocal(2, lp, address(this));
    }
    function claimRewards(uint256 slippage)internal override{
        uint256 reward = ILPStaking(farmPool).pendingStargate(1, address(this));
        uint256 minOut = getMinOut(rewardTokens[0],depositAsset,reward,slippage == magnifier ? 5000 : slippage);
        if(minOut>0){
            ILPStaking(farmPool).deposit(1, 0);
            swapRewardsToDepositAsset(slippage);
        }
    }
    function getRewardBalance() external view returns (uint256){
        uint256 reward = ILPStaking(farmPool).pendingStargate(1, address(this));
        return getMinOut(rewardTokens[0],baseAsset,reward,0);
    }
    function getRebalanceRepay()external view returns (uint256){
        uint256 reward = ILPStaking(farmPool).pendingStargate(1, address(this));
        return getMinOut(rewardTokens[0],depositAsset,reward,magnifier-rebalanceFee);
    }
    function _totalDeposit() internal view override returns (uint256){
        (uint256 lp,) = ILPStaking(farmPool).userInfo(1, address(this));
        return convertLPToDeposit(lp);
    }
    function swapDepositAssetTobaseAsset(uint256 amount,uint256 minAmount) internal override returns(uint256){
        approve(depositAsset, exchange);
        return IExchange(exchange).swap(depositAsset, baseAsset, amount, minAmount);
    }
    function swapBaseAssetToDepositAsset(uint256 amount,uint256 minAmount) internal override returns(uint256){
        approve(baseAsset, exchange);
        return IExchange(exchange).swap( baseAsset,depositAsset, amount, minAmount);
    }
    function swapRewardsToDepositAsset(uint256 slippage) internal{
        uint256 balance =0;
        for (uint256 i=0;i<rewardTokens.length;i++){
            address reward = rewardTokens[i];
            balance = IERC20(reward).balanceOf(address(this));
            if (balance > 0){
                uint256 _minOut = getMinOut(reward,baseAsset,balance,slippage); 
                approve(reward,uniExchange);
                balance = IUniExchange(uniExchange).swapExactInput(reward,baseAsset,
                balance , _minOut);
                _minOut = getMinOut(baseAsset,depositAsset,balance,slippage); 
                swapBaseAssetToDepositAsset(balance,_minOut);
            }
        }

    }
}
