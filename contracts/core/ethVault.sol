// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Vault.sol";
import "../subStrategies/interfaces/IWeth.sol";
contract ethVault is Vault {
    using SafeERC20 for IERC20;
    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol
    ) Vault(_asset,_name, _symbol) {
    }

    function depositEth(
        address receiver
    )
        public
        payable
        nonReentrant
        unPaused
        returns (uint256 shares)
    {
        uint256 amount = msg.value;
        require(amount != 0, "ZERO_ASSETS");
        require(receiver != address(0), "ZERO_ADDRESS");
        require(amount <= maxDeposit, "EXCEED_ONE_TIME_MAX_DEPOSIT");
        IWeth(address(asset)).deposit{value:amount}();

        // Need to transfer before minting or ERC777s could reenter.
        IERC20(asset).safeTransfer(address(controller), amount);
        // Total Assets amount until now
        return _deposit(amount,receiver);
    }

    function withdrawEth(
        uint256 assets,
        address payable receiver
    )
        public
        nonReentrant
        unPaused
        returns (uint256 shares)
    {
        require(assets != 0, "ZERO_ASSETS");
        require(receiver != address(0), "ZERO_ADDRESS");
        require(assets <= maxWithdraw, "EXCEED_ONE_TIME_MAX_WITHDRAW");
        // Calculate share amount to be burnt
        shares =
            (totalSupply() * assets) /
            IController(controller).totalAssets();

        require(shares > 0, "INVALID_WITHDRAW_SHARES");
        require(balanceOf(msg.sender) >= shares, "EXCEED_TOTAL_DEPOSIT");

        uint256 amount = _withdraw(assets, shares, address(this));
        IWeth(address(asset)).withdraw(amount);
        receiver.transfer(amount);
    }

    function redeemEth(
        uint256 shares,
        address payable receiver
    )
        public
        nonReentrant
        unPaused
        returns (uint256 assets)
    {
        require(shares != 0, "ZERO_SHARES");
        require(receiver != address(0), "ZERO_ADDRESS");
        require(shares <= balanceOf(msg.sender), "EXCEED_TOTAL_BALANCE");

        assets =
            (shares * IController(controller).totalAssets()) /
            totalSupply();

        require(assets <= maxWithdraw, "EXCEED_ONE_TIME_MAX_WITHDRAW");

        // Withdraw asset
        uint256 amount = _withdraw(assets, shares, address(this));
        IWeth(address(asset)).withdraw(amount);
        receiver.transfer(amount);
    }

}