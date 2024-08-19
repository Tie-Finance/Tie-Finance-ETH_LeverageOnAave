// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./ETHStrategy.sol";
import "./farmSpark.sol";

contract ETHStrategySpark is ETHStrategy,farmSpark{
    using SafeERC20 for IERC20;
    constructor(
        IERC20 _baseAsset,
        IERC20 _depositAsset,
        IERC20 _aDepositAsset,
        uint256 _mlr,
        address _IaavePool,
        address _vault,
        address _feePool,
        uint8 _emode
    ) ETHStrategy(_baseAsset,_depositAsset,_aDepositAsset,_mlr,_IaavePool,_vault,_feePool,_emode){

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
        if (IERC20(tokenIn).allowance(address(this),exchange)<amount){
            IERC20(tokenIn).safeApprove(exchange, type(uint256).max);
        }
        return IExchange(exchange).swap(tokenIn,tokenOut,amount,minAmount);
    }
}