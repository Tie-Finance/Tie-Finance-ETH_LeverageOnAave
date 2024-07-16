// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/ICurveRoute.sol";
import "../interfaces/ICurveAll.sol";
import "../interfaces/IExchange.sol";
import "../interfaces/IWeth.sol";
import "../operator.sol";
import "../saveApprove.sol";

contract curveExchange is IExchange,saveApprove,operatorMap {
    using SafeERC20 for IERC20;
    //address public weth;
    /* *
       *Pool type
       * 0 : normal, use exchange(int128,int128) get_dy(int128,int128)
       * 1 : underlying use exchange_underlying(int128,int128) get_dy_underlying(int128,int128)
       * 2 : polygon matic use exchange(uint256,uint256) get_dy(uint256,uint256)
     */
    struct poolInfo {
        uint8 poolType;
        address curveRoute;
        address pool;
        address token0;
        address token1;
        int128 index0;
        int128 index1;
    }
    mapping(uint256=>poolInfo) public curvePoolInfo;
    mapping(uint256=>address[]) public routeInfo;

    constructor(/*address _weth*/) {
        //weth = _weth;
    }
    receive() external payable {}
    function setCurvePair(uint8 poolType,address route,address pool,address token0,int128 index0,address token1,int128 index1) external onlyOwner{
        uint256 index = getIndex(token0,token1);
        curvePoolInfo[index] = poolInfo({poolType:poolType,curveRoute:route,pool: pool, token0: token0, token1: token1, index0: index0, index1: index1});
    }
    function setCurveRoute(address[]memory routePath) external onlyOwner{
        uint256 len = routePath.length;
        require(len > 1,"ROUTE_EMPTY!");
        uint256 index = getIndex(routePath[0],routePath[len-1]);
        routeInfo[index] = routePath;
    }
    function swap(address tokenIn,address tokenOut,uint256 amount,uint256 minAmount) external override onlyOperator returns(uint256){
        IERC20(tokenIn).safeTransferFrom(msg.sender,address(this),amount);
//        if (tokenIn == weth){
//            tokenIn = address(0);
//            IWeth(weth).withdraw(amount);
//        }
//        bool wethOut = tokenOut == weth;
//        if(wethOut){
//            tokenOut = address(0);
//        }
        uint256 outAmount = mainswap(tokenIn,tokenOut,amount,minAmount);
//        if(wethOut){
//            IWeth(weth).deposit{value: outAmount}();
//            tokenOut = weth;
//        }
        IERC20(tokenOut).safeTransfer(msg.sender, outAmount);
        return outAmount;
    }
    function mainswap(address tokenIn,address tokenOut,uint256 amount,uint256 minAmount) internal returns(uint256){
        (bool havePool,uint256 outAmount) = singleSwap(tokenIn,tokenOut,amount,minAmount);
        if(havePool){
            return outAmount;
        }
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
        return routeSwap(curRoute,amount,minAmount);
        
    }
    function singleSwap(address tokenIn,address tokenOut,uint256 amount,uint256 minAmount) internal returns(bool havePool, uint256 outAmount){
        //if(tokenIn == address(0)){
        //    return singleSwapEth(tokenIn,tokenOut,amount,minAmount);
        //}
        uint256 index = getIndex(tokenIn,tokenOut);
        poolInfo memory curPool = curvePoolInfo[index];
        if (curPool.pool == address(0)){
            return (false,0);
        }
        havePool = true;
        approve(tokenIn,curPool.pool);
        if (curPool.curveRoute != address(0)){
            approve(tokenIn,curPool.curveRoute);
        }
        int128 i = 0;
        int128 j = 0;
        if (tokenIn == curPool.token0){
            require(tokenOut == curPool.token1, "PAIR_ERROR!");
            i = curPool.index0;
            j = curPool.index1;
        }else{
            require(tokenIn == curPool.token1 && tokenOut == curPool.token0, "PAIR_ERROR!"); 
            i = curPool.index1;
            j = curPool.index0;
        }
        if (curPool.poolType == 0){
            outAmount = ICurveAll(curPool.pool).exchange(i,j,amount,minAmount);
        }else if(curPool.poolType == 1){
            outAmount = ICurveAll(curPool.pool).exchange_underlying(i,j,amount,minAmount);
        }else if(curPool.poolType == 2){
            outAmount = ICurveAll(curPool.pool).exchange(uint256(uint128(i)),uint256(uint128(j)),amount,minAmount,false);
        }else  if (curPool.poolType == 3){
            outAmount = ICurveRoute(curPool.curveRoute).exchange(curPool.pool,i,j,amount,minAmount);
        }else if(curPool.poolType == 4){
            outAmount = ICurveRoute(curPool.curveRoute).exchange_underlying(curPool.pool,i,j,amount,minAmount);
        }else if(curPool.poolType == 5){
            outAmount = ICurveRoute(curPool.curveRoute).exchange(curPool.pool,uint256(uint128(i)),uint256(uint128(j)),amount,minAmount,false);
        }else{
            require(false, "POOL_ERROR!");
        }
    }
    /*
    function singleSwapEth(address tokenIn,address tokenOut,uint256 amount,uint256 minAmount) internal returns(bool havePool, uint256 outAmount){
        require(tokenIn == address(0), "ADDRESS_ERROR!");
        uint256 index = getIndex(tokenIn,tokenOut);
        poolInfo memory curPool = curvePoolInfo[index];
        if (curPool.pool == address(0)){
            return (false,0);
        }
        havePool = true;
        int128 i = 0;
        int128 j = 0;
        if (tokenIn == curPool.token0){
            require(tokenOut == curPool.token1, "PAIR_ERROR!");
            i = curPool.index0;
            j = curPool.index1;
        }else{
            require(tokenIn == curPool.token1 && tokenOut == curPool.token0, "PAIR_ERROR!"); 
            i = curPool.index1;
            j = curPool.index0;
        }
        if (curPool.poolType == 0){
            outAmount = ICurveAll(curPool.pool).exchange{value: amount}(i,j,amount,minAmount);
        }else if(curPool.poolType == 1){
            outAmount = ICurveAll(curPool.pool).exchange_underlying{value: amount}(i,j,amount,minAmount);
        }else if(curPool.poolType == 2){
            outAmount = ICurveAll(curPool.pool).exchange{value: amount}(uint256(uint128(i)),uint256(uint128(j)),amount,minAmount,true);
        }else  if (curPool.poolType == 3){
            outAmount = ICurveRoute(curPool.curveRoute).exchange{value: amount}(curPool.pool,i,j,amount,minAmount);
        }else if(curPool.poolType == 4){
            outAmount = ICurveRoute(curPool.curveRoute).exchange_underlying{value: amount}(curPool.pool,i,j,amount,minAmount);
        }else if(curPool.poolType == 5){
            outAmount = ICurveRoute(curPool.curveRoute).exchange{value: amount}(curPool.pool,uint256(uint128(i)),uint256(uint128(j)),amount,minAmount,true);
        }else{
            require(false, "POOL_ERROR!");
        }
    }
    */
    function routeSwap(address[] memory curRoute,uint256 amount,uint256 minAmount)internal returns(uint256){
        uint256 len = curRoute.length; 
        uint256 AmountIn = amount;
        bool havePool;
        for (uint256 i=0;i<len-2;i++){
            (havePool,AmountIn) = singleSwap(curRoute[i],curRoute[i+1],AmountIn,0);
            require(havePool,"PAIR_ERROR!");
        }
        (havePool,AmountIn) = singleSwap(curRoute[len-2],curRoute[len-1],AmountIn,minAmount);
        require(havePool,"PAIR_ERROR!");
        return AmountIn;
    }
    function getIndex(address tokenIn,address tokenOut)internal pure returns(uint256){
        return uint256(uint160(tokenIn)) + uint256(uint160(tokenOut));
    }
    function getCurveInputValue(address tokenIn,address tokenOut,uint256 outAmount,uint256 maxInput)external view override returns (uint256){
        /*
        if (tokenIn == weth){
            tokenIn = address(0);
        }
        if(tokenOut == weth){
            tokenOut = address(0);
        }
        */
        uint256 curveOut = curveGet_dy(tokenIn, tokenOut, maxInput);
        return outAmount*maxInput/curveOut+1;
    }
    function getCurve_dy(address tokenIn,address tokenOut,uint256 amount)external view returns (uint256){
        /*
        if (tokenIn == weth){
            tokenIn = address(0);
        }
        if(tokenOut == weth){
            tokenOut = address(0);
        }
        */
        return curveGet_dy(tokenIn,tokenOut,amount);
    }
    function curveGet_dy(address tokenIn,address tokenOut,uint256 amount) internal view returns(uint256){
        (bool havePool,uint256 outAmount) = singleGet_dy(tokenIn,tokenOut,amount);
        if(havePool){
            return outAmount;
        }
        uint256 index = getIndex(tokenIn,tokenOut);
        address[] memory curRoute = routeInfo[index];
        uint256 len = curRoute.length;
        require(len > 0,"ROUTE_EMPTY!");
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
        return routeGet_dy(curRoute,amount);
        
    }
    function singleGet_dy(address tokenIn,address tokenOut,uint256 inAmount) internal view returns(bool havePool, uint256 outAmount){
        uint256 index = getIndex(tokenIn,tokenOut);
        poolInfo memory curPool = curvePoolInfo[index];
        if (curPool.pool == address(0)){
            return (false,0);
        }
        havePool = true;
        int128 i = 0;
        int128 j = 0;
        if (tokenIn == curPool.token0){
            require(tokenOut == curPool.token1, "PAIR_ERROR!");
            i = curPool.index0;
            j = curPool.index1;
        }else{
            require(tokenIn == curPool.token1 && tokenOut == curPool.token0, "PAIR_ERROR!"); 
            i = curPool.index1;
            j = curPool.index0;
        }
        if (curPool.poolType == 0){
            outAmount = ICurveAll(curPool.pool).get_dy(i,j,inAmount);
        }else if(curPool.poolType == 1){
            outAmount = ICurveAll(curPool.pool).get_dy_underlying(i,j,inAmount);
        }else if(curPool.poolType == 2){
            outAmount = ICurveAll(curPool.pool).get_dy(uint256(uint128(i)),uint256(uint128(j)),inAmount);
        }else if(curPool.poolType == 3){
            outAmount = ICurveRoute(curPool.curveRoute).get_dy(curPool.pool,i,j,inAmount);
        }else if(curPool.poolType == 4){
            outAmount = ICurveRoute(curPool.curveRoute).get_dy_underlying(curPool.pool,i,j,inAmount);
        }else if(curPool.poolType == 5){
            outAmount = ICurveRoute(curPool.curveRoute).get_dy(curPool.pool,uint256(uint128(i)),uint256(uint128(j)),inAmount);
        }else{
            require(false, "POOL_ERROR!");
        }
    }
    function routeGet_dy(address[] memory curRoute,uint256 inAmount)internal view returns(uint256){
        uint256 len = curRoute.length; 
        uint256 AmountIn = inAmount;
        bool havePool;
        for (uint256 i=0;i<len-1;i++){
            (havePool,AmountIn) = singleGet_dy(curRoute[i],curRoute[i+1],AmountIn);
            require(havePool,"PAIR_ERROR!");
        }
        return AmountIn;
    }
}