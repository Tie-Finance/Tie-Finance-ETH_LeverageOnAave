// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IExchange.sol";
import "../interfaces/ICurveRouter.sol";
import "../operator.sol";
import "../saveApprove.sol";
contract CurveRouterExchange is IExchange,saveApprove,operatorMap {
    using SafeERC20 for IERC20;

    struct poolInfo {
        address token0;
        address token1;
        address route;
        address pool;
        uint256[5] param;
    }
    mapping(uint256=>poolInfo) public curvePoolInfo;
    mapping(uint256=>address[]) public routeInfo;
    address public immutable curveRouter;
    address public constant ethAddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    constructor(address _curveRouter){
        require(_curveRouter != address(0), "ZERO_ADDRESS");
        curveRouter = _curveRouter;
    }
    function setSwapParams(address tokenIn,address tokenOut,
        address _route,uint256[5] calldata _swap_params,address _pool) external onlyOwner {
        uint256 index = getIndex(tokenIn,tokenOut);
        curvePoolInfo[index]  = poolInfo({token0:tokenIn,token1:tokenOut,
            route:_route,param:_swap_params,pool:_pool});
        address[]memory routePath = new address[](2);
        routePath[0] = tokenIn;
        routePath[1] = tokenOut;
        routeInfo[index] = routePath;
    }
    function setSwapRoute(address[]memory routePath) external onlyOwner{
        uint256 len = routePath.length;
        require(len > 1,"ROUTE_EMPTY!");
        uint256 index = getIndex(routePath[0],routePath[len-1]);
        routeInfo[index] = routePath;
    }
    function swap(address tokenIn,address tokenOut,uint256 amount,uint256 minAmount) external virtual onlyOperator returns (uint256){
        IERC20(tokenIn).safeTransferFrom(msg.sender,address(this),amount);
        (address[11] memory _routes,uint256[5][5] memory _swap_params,address[5] memory _pools) = getSwapParams(getSwapPath(tokenIn,tokenOut));
        approve(tokenIn, curveRouter);
        return ICurveRouter(curveRouter).exchange(_routes, _swap_params, amount, minAmount,_pools,msg.sender);
    }
    function getCurve_dy(address tokenIn,address tokenOut,uint256 amount)external  view virtual returns (uint256){
        (address[11] memory _routes,uint256[5][5] memory _swap_params,address[5] memory _pools) = getSwapParams(getSwapPath(tokenIn,tokenOut));
        return ICurveRouter(curveRouter).get_dy(_routes, _swap_params, amount,_pools);
    }
    function getCurve_dx(address tokenIn,address tokenOut,uint256 outAmount)public view virtual returns (uint256){
        (address[11] memory _routes,uint256[5][5] memory _swap_params,address[5] memory _pools) = getSwapParams(getSwapPath(tokenIn,tokenOut));
        return ICurveRouter(curveRouter).get_dx(_routes, _swap_params, outAmount,_pools);        
    }

    function getCurveInputValue(address tokenIn,address tokenOut,uint256 outAmount,uint256 /*maxInput*/)external view returns (uint256){
        return getCurve_dx(tokenIn,tokenOut,outAmount);
    }
    function getIndex(address tokenIn,address tokenOut)internal pure returns(uint256){
        return uint256(uint160(tokenIn)) + uint256(uint160(tokenOut));
    }
    
    function getSwapPath(address tokenIn,address tokenOut)internal view 
        returns (address[] memory curRoute){
        uint256 index = getIndex(tokenIn,tokenOut);
        curRoute = routeInfo[index];
        uint256 len = curRoute.length;
        require(len > 1,"ROUTE_EMPTY!");
        require(len <= 5,"ROUTE_OVERFLOW!");
        if (curRoute[0] == tokenIn){
            require(curRoute[len-1] == tokenOut,"ROUTE_ERROR!");
        }else{
            require(curRoute[len-1] == tokenIn && curRoute[0] == tokenOut,"ROUTE_ERROR!");
            for (uint256 i=0;i<len/2;i++){
                (curRoute[i],curRoute[len-1-i]) = (curRoute[len-1-i],curRoute[i]);
            }
        }
    }
    
    function getSwapParams(address[] memory curRoute)public view 
        returns (address[11] memory _routes,uint256[5][5] memory _swap_params,address[5] memory _pools){        
        _routes[0] = curRoute[0] != address(0) ? curRoute[0] : ethAddress;
        uint256 len = curRoute.length;
        for (uint256 i=0;i<len-1;i++){
            (address _route,address token1,uint256[5] memory _swap_param,address _pool) = getRouteInfo(curRoute[i],curRoute[i+1]);
            _routes[2*i+1] = _route;
            _routes[2*i+2] = token1;
            _swap_params[i] = _swap_param;
            _pools[i] = _pool;
        }
    }
    function getRouteInfo(address token0,address token1)internal virtual view 
        returns (address _route,address tokenOut,uint256[5] memory _swap_params,address _pool){
        uint256 index = getIndex(token0,token1);
        poolInfo memory curPool = curvePoolInfo[index];
        _route = curPool.route;
        tokenOut = token1 != address(0) ? token1 : ethAddress;
        if (token0 == curPool.token0){
            _swap_params[0] = curPool.param[0];
            _swap_params[1] = curPool.param[1];
        }else{
            _swap_params[0] = curPool.param[1];
            _swap_params[1] = curPool.param[0];
        }
        for (uint256 j=2;j<5;j++){
            _swap_params[j] = curPool.param[j];
        }
        _pool = curPool.pool;            
    }
}