// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./lendingStrategy.sol";
import "./farmSpark.sol";

contract lendingStrategySpark is lendingStrategy,farmSpark{
    constructor(
        IERC20 _depositAsset,
        address _weth,
        uint256 _mlr,
        address _IaavePool,
        address _vault,
        address _ethLeverage,
        address _feePool
    ) lendingStrategy(_depositAsset,_weth,_mlr,_IaavePool,_vault,_ethLeverage,_feePool){

    }
    function _totalDeposit() internal view override returns (uint256){
        return _totalAssets();
    }
    function depositToken(uint256 amount) internal override returns (uint256){
        return _deposit(amount);
    }
    function getVault() internal override returns(address){
        return vault;
    }
    function getDepositAsset() internal override returns(address){
        return address(depositAsset);
    }
    function getFeePool() internal override returns(address){
        return feePool;
    } 
    function rewardsSwap(address tokenIn,address tokenOut,uint256 amount,uint256 minAmount) internal override returns (uint256){
        return IUniExchange(exchange).swapExactInput(tokenIn,tokenOut,amount,minAmount);
    }
}