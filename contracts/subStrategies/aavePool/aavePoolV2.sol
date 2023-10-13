
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../interfaces/IAave.sol";
import "../interfaces/IAaveOracle.sol";
contract aavePoolV2 {
    address public aave;
    address public aaveOracle;
    constructor(address _aave, address _aaveOracle) {
        aave = _aave;
        aaveOracle = _aaveOracle;
    }
    function convertEthTo(uint256 _amount,address _token,uint256 _decimals) external view returns (uint256) {
        uint256 price = IAaveOracle(aaveOracle).getAssetPrice(_token);
        return _amount*_decimals/price;
    }
    function convertToEth(uint256 _amount,address _token,uint256 _decimals) external view returns (uint256) {
        uint256 price = IAaveOracle(aaveOracle).getAssetPrice(_token);
        return _amount*price/_decimals;
    }
    function getCollateral(address _user) external view returns (uint256) {
        (uint256 c, , , , , ) = IAave(aave).getUserAccountData(_user);
        return c;
    }

    function getDebt(address _user) external view returns (uint256) {
        //decimal 18
        (, uint256 d, , , , ) = IAave(aave).getUserAccountData(_user);
        return d;
    }
    function getCollateralAndDebt(address _user)external view returns (uint256 _collateral, uint256 _debt) {
        (_collateral, _debt, , , , ) = IAave(aave).getUserAccountData(_user);
    }
    function getCollateralTo(address _user,address _token,uint256 _decimals) external view returns (uint256) {
        (uint256 c, , , , , ) = IAave(aave).getUserAccountData(_user);
        uint256 price = IAaveOracle(aaveOracle).getAssetPrice(_token);
        return c*_decimals/price;
    }

    function getDebtTo(address _user,address _token,uint256 _decimals) external view returns (uint256) {
        //decimal 18
        (, uint256 d, , , , ) = IAave(aave).getUserAccountData(_user);
        uint256 price = IAaveOracle(aaveOracle).getAssetPrice(_token);
        return d*_decimals/price;
    }
    function getCollateralAndDebtTo(address _user,address _token,uint256 _decimals)external view returns (uint256 _collateral, uint256 _debt) {
        (_collateral, _debt, , , , ) = IAave(aave).getUserAccountData(_user);
        uint256 price = IAaveOracle(aaveOracle).getAssetPrice(_token);
        _collateral =  _collateral*_decimals/price;
        _debt =  _debt*_decimals/price;
    }

}