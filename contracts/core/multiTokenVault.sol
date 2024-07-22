// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Vault.sol";
import "../subStrategies/interfaces/IWeth.sol";
import "../subStrategies/interfaces/IExchange.sol";
import "../subStrategies/saveApprove.sol";
contract multiTokenVault is Vault,saveApprove {
    using SafeERC20 for IERC20;
    address[] public groupToken;
    // Exchange Address
    address public exchange;

    event SetGroupToken(address[] groupToken);
    event SetExchange(address exchange);
    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol,
        address[] memory _groupToken
    ) Vault(_asset,_name, _symbol) {
        groupToken = _groupToken;
    }

    function depositToken(address token,uint256 amount,uint256 minShares,address receiver) external returns (uint256 shares)
    {
        require(amount != 0, "ZEROassetS");
        require(tokenAvailable(token),"ILLEGAL_TOKEN");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        approve(token,exchange);
        amount = IExchange(exchange).swap(token,address(asset),amount,0);
        require(amount != 0, "ZEROassetS");
        require(receiver != address(0), "ZERO_ADDRESS");
        require(amount <= maxDeposit, "EXCEED_ONE_TIME_MAX_DEPOSIT");
        // Total Assets amount until now
        return _deposit(amount,minShares,receiver);
    }

    function withdrawToken(address token,uint256 assets,uint256 minWithdraw,address receiver) external nonReentrant unPaused returns (uint256 shares)
    {
        require(assets != 0, "ZEROassetS");
        require(tokenAvailable(token),"ILLEGAL_TOKEN");
        // Calculate share amount to be burnt
        require(receiver != address(0), "ZERO_ADDRESS");
        require(assets <= maxWithdraw, "EXCEED_ONE_TIME_MAX_WITHDRAW");
        // Calculate share amount to be burnt
        shares =
            (totalSupply() * assets) /
            IController(controller).totalAssets();

        require(shares > 0, "INVALID_WITHDRAW_SHARES");
        require(balanceOf(msg.sender) >= shares, "EXCEED_TOTAL_DEPOSIT");

        uint256 amount = _withdraw(assets, shares,0, address(this));
        approve(address(asset),exchange);
        amount = IExchange(exchange).swap(address(asset),token,amount,minWithdraw);
        IERC20(token).safeTransfer(msg.sender,amount);
    }

    function redeemToken(address token,uint256 shares,uint256 minWithdraw,address payable receiver) external nonReentrant unPaused returns (uint256 assets)
    {
        require(shares != 0, "ZERO_SHARES");
        require(tokenAvailable(token),"ILLEGAL_TOKEN");
        require(receiver != address(0), "ZERO_ADDRESS");
        require(shares <= balanceOf(msg.sender), "EXCEED_TOTAL_BALANCE");

        assets =
            (shares * IController(controller).totalAssets()) /
            totalSupply();

        require(assets <= maxWithdraw, "EXCEED_ONE_TIME_MAX_WITHDRAW");

        // Withdraw asset
        uint256 amount = _withdraw(assets, shares,0, address(this));
        approve(address(asset),exchange);
        amount = IExchange(exchange).swap(address(asset),token,amount,minWithdraw);
        IERC20(token).safeTransfer(msg.sender,amount);
    }
    function setExchange(address _exchange) external onlyOwner {
        require(_exchange != address(0), "INVALID_ADDRESS");
        exchange = _exchange;
        emit SetExchange(exchange);
    }
    function setGroupToken(address[] memory _groupToken) external virtual onlyOwner {
        groupToken = _groupToken;
        emit SetGroupToken(_groupToken);
    }

    function tokenAvailable(address token) internal view returns(bool){
        uint256 nLen = groupToken.length;
        for (uint i=0;i<nLen;i++){
            if(token == groupToken[i]){
                return true;
            }
        }
        return false;
    }
}