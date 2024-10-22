// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./lendingStrategySpark.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IAave.sol";
import "./interfaces/IAavePool.sol";


contract SavingDaiStrategy is lendingStrategySpark {
    using SafeERC20 for IERC20;
    address public immutable savingDai;
        constructor(
            address _savingDai,
            IERC20 _depositAsset,
            address _weth,
            uint256 _mlr,
            address _IaavePool,
            address _vault,
            address _ethLeverage,
            address _feePool
    ) lendingStrategySpark(_depositAsset,_weth,_mlr,_IaavePool,_vault,_ethLeverage,_feePool){
        savingDai = _savingDai;
        //IERC20(savingDai).safeApprove(_IaavePool, type(uint256).max);
        _depositAsset.safeApprove(savingDai, type(uint256).max);
    }

    
    function depositToPool(uint256 _amount)internal override {
        // Deposit token
        uint256 shares = IERC4626(savingDai).deposit(_amount, address(this));
        IAavePool(IaavePool).deposit(savingDai, shares);
        address aave = IAavePool(IaavePool).aave();
        (uint256 col,) = IAavePool(IaavePool).getCollateralAndDebt(address(this));
        if (col == 0) {
            IAave(aave).setUserUseReserveAsCollateral(savingDai, true);
        }
    } 
    function withdrawFromPool(uint256 _amount)internal override returns(uint256) {
        address aave = IAavePool(IaavePool).aave();
        uint256 shares = IERC4626(savingDai).convertToShares(_amount);
        shares = IAave(aave).withdraw(savingDai, shares, address(this));
        return IERC4626(savingDai).redeem(shares, address(this), address(this));
    }
}
