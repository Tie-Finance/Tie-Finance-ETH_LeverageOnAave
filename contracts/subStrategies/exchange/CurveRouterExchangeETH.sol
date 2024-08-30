// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./CurveRouterExchange.sol";


contract CurveRouterExchangeETH is CurveRouterExchange {
    using SafeERC20 for IERC20;
    address public immutable stETH;
    constructor(address _curveRouter,address _stETH)
    CurveRouterExchange(_curveRouter){
        stETH = _stETH;
    }
    function getSwapPathETH(address tokenIn,address tokenOut)internal view 
        returns (address[] memory curRoute,address[] memory curRoute1,bool haveETHToSTETH){
        curRoute = getSwapPath(tokenIn, tokenOut);
        uint256 len = curRoute.length;
        curRoute1 = new address[](len);
        for (uint i=0;i<len-1;i++){
            curRoute1[i] = curRoute[i] != address(0) ? curRoute[i] : ethAddress;
            if (curRoute[i] == address(0) && curRoute[i+1] == stETH){
                haveETHToSTETH = true;
            }
        }
        curRoute1[len-1] = curRoute[len-1];
    }
    function exchangeByPath(address[] memory curRoute,uint256 amount,uint256 minAmount)internal returns(uint256){
        (address[11] memory _routes,uint256[5][5] memory _swap_params,address[5] memory _pools) = getSwapParams(curRoute);
        return ICurveRouter(curveRouter).exchange(_routes, _swap_params, amount, minAmount,_pools,msg.sender);
    }
    function swap(address tokenIn,address tokenOut,uint256 amount,uint256 minAmount) external override onlyOperator returns (uint256){
        IERC20(tokenIn).safeTransferFrom(msg.sender,address(this),amount);
        approve(tokenIn, curveRouter);
        (address[] memory curRoute,address[] memory curRoute1,bool haveETHToSTETH) = getSwapPathETH(tokenIn, tokenOut);
        if(haveETHToSTETH) {
            uint256 dy1 = get_dy_byPath(curRoute,amount);
            uint256 dy2 = get_dy_byPath(curRoute1,amount);
            if (dy1 < dy2){
                return exchangeByPath(curRoute1,amount,minAmount);
            }
        }
        return exchangeByPath(curRoute,amount,minAmount);
    }
    function getCurve_dy(address tokenIn,address tokenOut,uint256 amount)external  view override returns (uint256){
        (address[] memory curRoute,address[] memory curRoute1,bool haveETHToSTETH) = getSwapPathETH(tokenIn, tokenOut);
        uint256 dy1 = get_dy_byPath(curRoute,amount);
        if(haveETHToSTETH) {
            uint256 dy2 = get_dy_byPath(curRoute1,amount);
            return dy1 > dy2 ? dy1 : dy2;
        }
        return dy1;
    }
    function get_dy_byPath(address[] memory curRoute,uint256 amount)internal view returns(uint256){
        (address[11] memory _routes,uint256[5][5] memory _swap_params,address[5] memory _pools) = getSwapParams(curRoute);
        return ICurveRouter(curveRouter).get_dy(_routes, _swap_params, amount,_pools);
    }
    function getCurve_dx(address tokenIn,address tokenOut,uint256 outAmount)public view override returns (uint256){
        (address[] memory curRoute,address[] memory curRoute1,bool haveETHToSTETH) = getSwapPathETH(tokenIn, tokenOut);
        uint256 dx1 = get_dx_byPath(curRoute,outAmount);
        if(haveETHToSTETH) {
            uint256 dx2 = get_dx_byPath(curRoute1,outAmount);
            return dx1 < dx2 ? dx1 : dx2;
        }
        return dx1;
    }
    function get_dx_byPath(address[] memory curRoute,uint256 outAmount)internal view returns(uint256){
        (address[11] memory _routes,uint256[5][5] memory _swap_params,address[5] memory _pools) = getSwapParams(curRoute);
        return ICurveRouter(curveRouter).get_dx(_routes, _swap_params, outAmount,_pools);
    }
    function getRouteInfo(address token0,address token1)internal override view 
        returns (address _route,address tokenOut,uint256[5] memory _swap_params,address _pool){
        if(token0== ethAddress && token1 == stETH){
            _route = stETH;
            tokenOut = stETH;
            _swap_params[2] = 8;
        }else{
            return CurveRouterExchange.getRouteInfo(token0 == ethAddress ? address(0) : token0,
                token1 == ethAddress ? address(0) : token1);
        }
    }
}