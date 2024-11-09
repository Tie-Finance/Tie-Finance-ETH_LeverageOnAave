// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./lendingStrategy.sol";
import "./farmSpark.sol";

contract lendingStrategySpark is lendingStrategy,farmSpark{
    using SafeERC20 for IERC20;
    address public oracle;
    event SetOracle(address oracle);
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
    function _beforeCompound() collectFee internal override{

    }
    function _totalDeposit() internal view override returns (uint256){
        return _totalAssets();
    }
    function depositFunds(uint256 amount) internal override returns (uint256){
        return _deposit(amount);
    }
    function getVault() internal view override returns(address){
        return vault;
    }
    function getDepositAsset() internal view override returns(address){
        return address(depositAsset);
    }
    function getFeePool() internal view override returns(address){
        return feePool;
    }
    function getOracle() internal view override returns(address){
        return oracle;
    }
    function rewardsSwap(address tokenIn,address tokenOut,uint256 amount,uint256 minAmount) internal override returns (uint256){
        if (IERC20(tokenIn).allowance(address(this),exchange)<amount){
            IERC20(tokenIn).safeApprove(exchange, type(uint256).max);
        }
        return IUniExchange(exchange).swapExactInput(tokenIn,tokenOut,amount,minAmount);
    }
    function setOracle(address _oracle) public onlyOwner {
        require(_oracle != address(0), "INVALID_ADDRESS");
        oracle = _oracle;

        emit SetOracle(_oracle);
    }
}