// SPDX-License-Identifier: MIT
//This contract is deprecated
pragma solidity ^0.8.0;
import "./curveExchange.sol";
import "../interfaces/IStETH.sol";
import "../interfaces/IWstETH.sol";

contract curveExchangeETH is curveExchange {
    using SafeERC20 for IERC20;
    address public stETH;
    address public wstETH;
    constructor(
        address _weth,
        address _stETH,
        address _wstETH
    ) curveExchange(_weth){
        stETH = _stETH;
        wstETH = _wstETH;
        IERC20(stETH).safeApprove(_wstETH, type(uint256).max);
    }
    function swap(address tokenIn,address tokenOut,uint256 amount,uint256 minAmount) external virtual override onlyOperator returns(uint256){
        IERC20(tokenIn).safeTransferFrom(msg.sender,address(this),amount);
        address tokenOutBak = tokenOut;
        uint256 minAmountBak = minAmount;
        if(tokenOut ==  wstETH){
            tokenOut = stETH;
            minAmount = 0;
        }else if(tokenIn == wstETH){
            amount = IWstETH(tokenIn).unwrap(amount);
            tokenIn = stETH;
        }
        uint256 outAmount = _swap(tokenIn,tokenOut,amount,minAmount);
         if(tokenOutBak ==  wstETH){
            outAmount = IWstETH(tokenOutBak).wrap(outAmount);
            require(outAmount>=minAmountBak,"OVERFLOW_SLIPPAGE");
        }
        IERC20(tokenOutBak).safeTransfer(msg.sender, outAmount);
        return outAmount;
        
    }
    function _swap(address tokenIn,address tokenOut,uint256 amount,uint256 minAmount)internal returns(uint256){
        if (tokenIn == weth && tokenOut ==  stETH){
                return swapEthToStEth(amount,minAmount);
        }else{
            return mainswap(tokenIn, tokenOut,amount,minAmount);
        }

    }
    function swapEthToStEth(uint256 amount,uint256 minAmount) internal returns(uint256){
        uint256 outValue = curveGet_dy(weth, stETH, amount);
        if (outValue < amount) {
            require(amount>=minAmount,"ETH_STETH_SLIPPAGE");
            IWeth(weth).withdraw(amount);
            IStETH(stETH).submit{value: amount}(address(this));
            return amount;
        } else {
            require(outValue>=minAmount,"ETH_STETH_SLIPPAGE");
            return mainswap(weth, stETH,amount,minAmount);
        }
    }
    function curveGet_dy(address tokenIn,address tokenOut,uint256 amount) internal view virtual override returns(uint256){
        address tokenOutBak = tokenOut;
        if (tokenIn == wstETH){
            tokenIn = stETH;
            amount = IWstETH(tokenIn).getStETHByWstETH(amount);
        }else if (tokenOut == wstETH){
            tokenOut = stETH;
        }
        uint256 outValue = curveExchange.curveGet_dy(tokenIn, tokenOut, amount);
        if(tokenOutBak == wstETH){
            outValue = IWstETH(tokenOutBak).getWstETHByStETH(outValue);
        }
        return outValue;
    }
}