// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../interfaces/IAave.sol";
import "../interfaces/IAaveOracle.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
contract aavePoolV3 {
    address public aave;
    address public aaveOracle;
    address public weth;
    uint256 constant private ethDecimal = 1e18;
    constructor(address _aave, address _aaveOracle,address _weth) {
        aave = _aave;
        aaveOracle = _aaveOracle;
        weth = _weth;
    }
    function convertAmount(address _tokenIn,address _tokenOut,uint256 _amount) external view returns (uint256) {
        address[] memory tokens = new address[](2);
        tokens[0] = _tokenIn;
        tokens[1] = _tokenOut;
        uint256[] memory prices = IAaveOracle(aaveOracle).getAssetsPrices(tokens);
        uint8 decimalsIn = IERC20Metadata(_tokenIn).decimals();
        uint8 decimalsOut = IERC20Metadata(_tokenOut).decimals();
        return _amount*prices[0]*(10**decimalsIn)/(10**decimalsOut)/prices[1];
    }

    function getCollateral(address _user) external view returns (uint256) {
        return getCollateralTo(_user,weth,ethDecimal);
    }

    function getDebt(address _user) external view returns (uint256) {
        return getDebtTo(_user,weth,ethDecimal);
    }
    function getCollateralAndDebt(address _user)external view returns (uint256 _collateral, uint256 _debt) {
        return getCollateralAndDebtTo(_user,weth,ethDecimal);
    }
    function getCollateralTo(address _user,address _token,uint256 _decimals) public view returns (uint256) {
        (uint256 c, , , , , ) = IAave(aave).getUserAccountData(_user);
        uint256 price = IAaveOracle(aaveOracle).getAssetPrice(_token);
        return c*_decimals/price;
    }

    function getDebtTo(address _user,address _token,uint256 _decimals) public view returns (uint256) {
        //decimal 18
        (, uint256 d, , , , ) = IAave(aave).getUserAccountData(_user);
        uint256 price = IAaveOracle(aaveOracle).getAssetPrice(_token);
        return d*_decimals/price;
    }
    function getCollateralAndDebtTo(address _user,address _token,uint256 _decimals)public view returns (uint256 _collateral, uint256 _debt) {
        (_collateral, _debt, , , , ) = IAave(aave).getUserAccountData(_user);
        uint256 price = IAaveOracle(aaveOracle).getAssetPrice(_token);
        _collateral =  _collateral*_decimals/price;
        _debt =  _debt*_decimals/price;
    }
}
