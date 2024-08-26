contract Exchange {
    function swap(address tokenIn,address tokenOut,uint256 amount,uint256 minAmount) external returns (uint256) {
        return amount;
    }

    function getCurveInputValue(address tokenIn,address tokenOut,uint256 outAmount,uint256 maxInput)external view returns (uint256) {
        return outAmount;
    }
}