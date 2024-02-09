// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../interfaces/IAaveV3.sol";
import "../interfaces/IAaveOracle.sol";
import "../interfaces/IAavePool.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../operator.sol";
import "../saveApprove.sol";
contract aavePoolV3 is IAavePool,saveApprove,operatorMap{
    using SafeERC20 for IERC20;
    address immutable public aave;
    address immutable public aaveOracle;
    address immutable public weth;
    constructor(address _aave, address _aaveOracle,address _weth) {
        require(_weth != address(0), "INVALID_ADDRESS");
        require(_aave != address(0), "INVALID_ADDRESS");
        require(_aaveOracle != address(0), "INVALID_ADDRESS");

        aave = _aave;
        aaveOracle = _aaveOracle;
        weth = _weth;
    }
    function deposit(address asset,uint256 amount)external onlyOperator{
        IERC20(asset).safeTransferFrom(msg.sender,address(this),amount);
        approve(asset,aave);
        IAaveV3(aave).supply(asset, amount, msg.sender, 0);
    }
    function convertAmount(address _tokenIn,address _tokenOut,uint256 _amount) external view returns (uint256) {
        address[] memory tokens = new address[](2);
        tokens[0] = _tokenIn;
        tokens[1] = _tokenOut;
        uint256[] memory prices = IAaveOracle(aaveOracle).getAssetsPrices(tokens);
        uint8 decimalsIn = IERC20Metadata(_tokenIn).decimals();
        uint8 decimalsOut = IERC20Metadata(_tokenOut).decimals();
        uint256 result = _amount*prices[0];
        if (decimalsOut >= decimalsIn) {
            result *= 10**(decimalsOut - decimalsIn);
        } else {
            result /= 10**(decimalsIn - decimalsOut);
        }
        result /= prices[1];
        return result;
    }

    function getCollateral(address _user) external view returns (uint256) {
        return getCollateralTo(_user,weth);
    }

    function getDebt(address _user) external view returns (uint256) {
        return getDebtTo(_user,weth);
    }
    function getCollateralAndDebt(address _user)external view returns (uint256 _collateral, uint256 _debt) {
        return getCollateralAndDebtTo(_user,weth);
    }
    function getCollateralMaxWithdraw(address _user) external view returns (uint256) {
        return getCollateralMaxWithdrawTo(_user,weth);
    }
    function getCollateralTo(address _user,address _token) public view returns (uint256) {
        (uint256 c, , , , , ) = IAaveV3(aave).getUserAccountData(_user);
        uint256 price = IAaveOracle(aaveOracle).getAssetPrice(_token);
        uint8 _decimals = IERC20Metadata(_token).decimals();
        return c*(10**_decimals)/price;
    }

    function getDebtTo(address _user,address _token) public view returns (uint256) {
        //decimal 18
        (, uint256 d, , , , ) = IAaveV3(aave).getUserAccountData(_user);
        uint256 price = IAaveOracle(aaveOracle).getAssetPrice(_token);
        uint8 _decimals = IERC20Metadata(_token).decimals();
        return d*(10**_decimals)/price;
    }
    function getCollateralAndDebtTo(address _user,address _token)public view returns (uint256 _collateral, uint256 _debt) {
        (_collateral, _debt, , , , ) = IAaveV3(aave).getUserAccountData(_user);
        uint256 price = IAaveOracle(aaveOracle).getAssetPrice(_token);
        uint8 _decimals = IERC20Metadata(_token).decimals();
        _collateral =  _collateral*(10**_decimals)/price;
        _debt =  _debt*(10**_decimals)/price;
    }
    function getCollateralMaxWithdrawTo(address _user,address _token) public view returns (uint256) {
        (uint256 _collateral, uint256 _debt,uint256  _available, , , ) = IAaveV3(aave).getUserAccountData(_user);
        uint256 amount = _collateral*_available/(_available+_debt);
        uint256 price = IAaveOracle(aaveOracle).getAssetPrice(_token);
        uint8 _decimals = IERC20Metadata(_token).decimals();
        return amount*(10**_decimals)/price;
    }
}
