// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
interface IAavePool {
    function deposit(address asset,uint256 amount)external;
    function aave() external view returns (address);
    function convertAmount(address _tokenIn,address _tokenOut,uint256 _amount) external view returns (uint256);
    function getCollateral(address _user) external view returns (uint256);
    function getDebt(address _user) external view returns (uint256);
    function getCollateralAndDebt(address _user)external view returns (uint256 _collateral, uint256 _debt);
    function getCollateralMaxWithdraw(address _user) external view returns (uint256);

    function getCollateralTo(address _user,address _token) external view returns (uint256);
    function getDebtTo(address _user,address _token) external view returns (uint256);
    function getCollateralAndDebtTo(address _user,address _token)external view returns (uint256 _collateral, uint256 _debt);
    function getCollateralMaxWithdrawTo(address _user,address _token) external view returns (uint256);

}