// SPDX-License-Identifier: MIT
//This contract is deprecated
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/ICurvePolygon.sol";
import "../interfaces/IStETH.sol";
import "../interfaces/IExchange.sol";
import "../interfaces/IWeth.sol";

contract ETHLeverExchangePolygon is IExchange {
    using SafeERC20 for IERC20;
    address public leverSS;

    address public weth;

    address public curvePool;

    address public stETH;

    constructor(
        address _weth,
        address _leverSS,
        address _curvePool,
        address _stETH
    ) {
        weth = _weth;
        stETH = _stETH;
        leverSS = _leverSS;
        curvePool = _curvePool;
        IERC20(stETH).safeApprove(_curvePool, type(uint256).max);
    }

    receive() external payable {}

    modifier onlyLeverSS() {
        require(msg.sender == leverSS, "ONLY_LEVER_VAULT_CALL");
        _;
    }
    function swap(address tokenIn,address tokenOut,uint256 amount,uint256 minAmount) external override onlyLeverSS returns(uint256) {
        IERC20(tokenIn).safeTransferFrom(leverSS,address(this),amount);
        if (tokenIn == weth){
            if (tokenOut ==  stETH){
                uint256 balance = swapEthToStEth(amount,minAmount);
                IERC20(tokenOut).safeTransfer(leverSS, balance);
                return balance;
            }else{
                require(false,"INVALID_SWAP");
            }
        }else if (tokenOut == weth){
            if (tokenIn ==  stETH){
                uint256 balance = swapSTEthToEth(amount,minAmount);
                IERC20(tokenOut).safeTransfer(leverSS, balance);
                return balance;
            }
        }else{
            require(false,"INVALID_SWAP");
        }
        
    }
    function swapEthToStEth(uint256 amount,uint256 minAmount) internal returns(uint256) {
        IWeth(weth).withdraw(amount);
        /*
        0 : stMatic
        1 : matic
        */
        return ICurvePolygon(curvePool).exchange{value: amount}(
            1,
            0,
            amount,
            minAmount,
            true
        );
    }
    function swapSTEthToEth(uint256 amount,uint256 minAmount) internal returns(uint256){
        uint256 balance = ICurvePolygon(curvePool).exchange(0, 1, amount, minAmount,true);
        IWeth(weth).deposit{value: balance}();
        return balance;
    }
    function getCurve_dy(address tokenIn,address tokenOut,uint256 amount)external view returns (uint256){
        if(tokenIn == weth && tokenOut == stETH){
            return ICurvePolygon(curvePool).get_dy(1, 0, amount);
        }else if(tokenIn == stETH && tokenOut == weth){
            return ICurvePolygon(curvePool).get_dy(0, 1, amount);
        }else{
            require(false,"INVALID_SWAP");
        }
    }
    function getCurveInputValue(address tokenIn,address tokenOut,uint256 outAmount,uint256 maxInput)external view override onlyLeverSS returns (uint256){
        if(tokenIn == stETH && tokenOut == weth){
            uint256 curveOut = ICurvePolygon(curvePool).get_dy(0, 1, maxInput);
            return outAmount*maxInput/curveOut+1;
        }else{
            require(false,"INVALID_SWAP");
        }
    }
}