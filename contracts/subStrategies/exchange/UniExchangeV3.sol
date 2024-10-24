// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/IUniswapV3Router.sol";
import "../interfaces/IQuoter.sol";
import "../interfaces/IWeth.sol";
import "../interfaces/IUniExchange.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../saveApprove.sol";
import "../operator.sol";

contract UniExchangeV3 is IUniExchange,saveApprove,operatorMap {
    using SafeERC20 for IERC20;

    address immutable public univ3Router;
    address immutable public univ3Quoter;

    mapping(uint256=>uint24) public uniswapFee;
    mapping(uint256=>address[]) public routeInfo;
    // UniV3 Fee

    // WETH Address
    //address immutable public weth;
    constructor(address _univ3Router, address _univ3Quoter) {
        require(_univ3Router != address(0), "INVALID_ADDRESS");
        require(_univ3Quoter != address(0), "INVALID_ADDRESS");
        univ3Router = _univ3Router;
        univ3Quoter = _univ3Quoter;
    }

    event SetSwapInfo(address router, uint24 fee);

    function setUniswapFee(address token0,address token1,uint24 poolFee) external onlyOwner{
        uint256 index = getIndex(token0,token1);
        uniswapFee[index] = poolFee;
        address[]memory routePath = new address[](2);
        routePath[0] = token0;
        routePath[1] = token1;
        routeInfo[index] = routePath;
    }
    function setUniswapRoute(address[]memory routePath) external onlyOwner{
        uint256 len = routePath.length;
        require(len > 1,"ROUTE_EMPTY!");
        uint256 index = getIndex(routePath[0],routePath[len-1]);
        routeInfo[index] = routePath;
    }
    function getIndex(address tokenIn,address tokenOut)internal pure returns(uint256){
        return uint256(uint160(tokenIn)) + uint256(uint160(tokenOut));
    }

    function getSwapPath(address tokenIn,address tokenOut)public view returns (bytes memory){
        uint256 index = getIndex(tokenIn,tokenOut);
        address[] memory curRoute = routeInfo[index];
        uint256 len = curRoute.length;
        require(len > 1,"ROUTE_EMPTY!");
        if (curRoute[0] == tokenIn){
            require(curRoute[len-1] == tokenOut,"ROUTE_ERROR!");
        }else{
            require(curRoute[len-1] == tokenIn && curRoute[0] == tokenOut,"ROUTE_ERROR!");
            for (uint256 i=0;i<len/2;i++){
                address temp = curRoute[i];
                curRoute[i] = curRoute[len-1-i];
                curRoute[len-1-i] = temp;
            }
        }
        bytes memory path;
        for (uint256 i=0;i<len-1;i++){
            address token0 = curRoute[i];
            address token1 = curRoute[i+1];
            index = getIndex(token0,token1);
            uint24 fee = uniswapFee[index];
            path = abi.encodePacked(path, token0, fee);
        }
        return abi.encodePacked(path, tokenOut);
    }

    function swapExactInput(address tokenIn,address tokenOut,
        uint256 _amount, uint256 _minOut) external onlyOperator returns (uint256 amountOut){
        IERC20(tokenIn).safeTransferFrom(msg.sender,address(this),_amount);
        bytes memory path = getSwapPath(tokenIn,tokenOut);
        ISwapRouter.ExactInputParams memory params = ISwapRouter
            .ExactInputParams({
                path : path,
                recipient: msg.sender,
                deadline:block.timestamp+1000,
                amountIn: _amount,
                amountOutMinimum: _minOut
            });
        approve(tokenIn,univ3Router);
        amountOut = ISwapRouter(univ3Router).exactInput(params);
    }

    function swapExactOutput(address tokenIn,address tokenOut,
        uint256 _amountOut,uint256 _amountInMax) external onlyOperator returns (uint256 amountIn){
        IERC20(tokenIn).safeTransferFrom(msg.sender,address(this),_amountInMax);
        bytes memory path = getSwapPath(tokenOut,tokenIn);
        ISwapRouter.ExactOutputParams memory params = ISwapRouter
            .ExactOutputParams({
                path : path,
                recipient: msg.sender,
                deadline:block.timestamp+1000,
                amountOut: _amountOut,
                amountInMaximum: _amountInMax
            });
        approve(tokenIn,univ3Router);
        amountIn = ISwapRouter(univ3Router).exactOutput(params);
        if (_amountInMax>amountIn){
            IERC20(tokenIn).safeTransfer(msg.sender,_amountInMax-amountIn);
        }
    }
    function getSwapOut(address tokenIn,address tokenOut,uint256 amountIn)external onlyOperator returns (uint256 amountOut){
        bytes memory path = getSwapPath(tokenOut,tokenIn);
        return IQuoter(univ3Quoter).quoteExactInput(path,amountIn);
    }
    function getSwapIn(address tokenIn,address tokenOut, uint256 amountOut) external onlyOperator returns (uint256 amountIn){
        bytes memory path = getSwapPath(tokenIn,tokenOut);
        return IQuoter(univ3Quoter).quoteExactOutput(path,amountOut);
    }
}
