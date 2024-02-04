// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/IUniswapV3Router.sol";
import "../interfaces/IWeth.sol";
import "../interfaces/IUniExchange.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract UniExchange is IUniExchange,Ownable {
    using SafeERC20 for IERC20;
    address immutable public leverSS;

    address public univ3Router;

    // UniV3 Fee
    uint24 public univ3Fee;

    // WETH Address
    address immutable public weth;

    constructor(address _weth, address _leverSS, address _univ3Router,uint24 _univ3Fee) {
        require(_weth != address(0), "INVALID_ADDRESS");
        require(_leverSS != address(0), "INVALID_ADDRESS");
        require(_univ3Router != address(0), "INVALID_ADDRESS");
        weth = _weth;
        leverSS = _leverSS;
        univ3Router = _univ3Router;
        univ3Fee = _univ3Fee;
    }

    event SetSwapInfo(address router, uint24 fee);

    modifier onlyLeverSS() {
        require(_msgSender() == leverSS, "ONLY_LEVER_VAULT_CALL");
        _;
    }

    /**
        Set Swap Info
     */
    function setSwapInfo(
        address _univ3Router,
        uint24 _univ3Fee
    ) public onlyOwner {
        require(_univ3Router != address(0), "INVALID_ADDRESS");

        univ3Router = _univ3Router;
        univ3Fee = _univ3Fee;

        emit SetSwapInfo(univ3Router, univ3Fee);
    }

    function swapExactInput(
        address _from,
        address _to,
        uint256 _amount,
        uint256 _minOut
    ) external onlyLeverSS returns (uint256 amountOut){
        require(univ3Router != address(0), "ROUTER_NOT_SET");
        IERC20(_from).safeTransferFrom(leverSS,address(this),_amount);
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: _from,
                tokenOut: _to,
                fee: univ3Fee,
                recipient: leverSS,
                deadline:block.timestamp+1000,
                amountIn: _amount,
                amountOutMinimum: _minOut,
                sqrtPriceLimitX96: 0
            });

        IERC20(_from).approve(univ3Router, 0);
        IERC20(_from).approve(univ3Router, _amount);
        amountOut = ISwapRouter(univ3Router).exactInputSingle(params);
    }

    function swapExactOutput(
        address _from,
        address _to,
        uint256 _amountOut,
        uint256 _amountInMax
    ) external onlyLeverSS returns (uint256 amountIn){
        require(univ3Router != address(0), "ROUTER_NOT_SET");
        IERC20(_from).safeTransferFrom(leverSS,address(this),_amountInMax);
        ISwapRouter.ExactOutputSingleParams
            memory params = ISwapRouter.ExactOutputSingleParams({
                tokenIn: _from,
                tokenOut: _to,
                fee: univ3Fee,
                recipient: leverSS,
                deadline:block.timestamp+1000,
                amountOut: _amountOut,
                amountInMaximum: _amountInMax,
                sqrtPriceLimitX96: 0
            });
        
        IERC20(_from).approve(univ3Router, 0);
        IERC20(_from).approve(univ3Router, _amountInMax);
        amountIn = ISwapRouter(univ3Router).exactOutputSingle(params);
        if (_amountInMax>amountIn){
            IERC20(_from).safeTransfer(leverSS,_amountInMax-amountIn);
        }
    }
}
