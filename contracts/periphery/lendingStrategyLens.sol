// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/ISubStrategy.sol";
import "../subStrategies/interfaces/IWstETH.sol";
import "../subStrategies/interfaces/ICurve.sol";
import "../subStrategies/interfaces/IBalancer.sol";
contract lendingStrategyLens{
    address public immutable ethVault;
    address public immutable EthStrategy;
    address public immutable curvePool;
    address public immutable awstETH;
    address public immutable aDebtETH;
    address public immutable wstETH;
    address public immutable balancerFee;
    constructor(address _vault,address _strategy,address _curvePool,address _awstEth,address _aDebtEth,address _wstEth,address _balancerFee){
        ethVault = _vault;
        EthStrategy = _strategy;
        curvePool = _curvePool;
        awstETH = _awstEth;
        aDebtETH = _aDebtEth;
        wstETH = _wstEth;
        balancerFee = _balancerFee;
    }
    function getDepositOut(uint256 assets) external view returns (uint256) {
        uint256 totalAsset = ISubStrategy(EthStrategy).totalAssets();
        if (totalAsset == 0){
            return assets;
        }
        uint256 balDebtETH = IERC20(aDebtETH).balanceOf(address(EthStrategy));
        uint256 supply = IERC20(ethVault).totalSupply();
        uint256 debt =  balDebtETH*assets/totalAsset;
        uint256 swapOut = ICurve(curvePool).get_dy(0, 1, debt+assets);
        uint256 flashFee = IBalancer(balancerFee).getFlashLoanFeePercentage();
        if(swapOut<debt+assets){
            swapOut=debt+assets;
        }
        return (swapOut-(debt*1e18+flashFee)/1e18)*supply/totalAsset;
    }

    function getRedeemOut(uint256 shares) external view returns (uint256) {
        uint256 supply = IERC20(ethVault).totalSupply();
        if (supply == 0){
            return shares;
        }
        uint256 balWstETH = IERC20(awstETH).balanceOf(address(EthStrategy));
        uint256 balDebtETH = IERC20(aDebtETH).balanceOf(address(EthStrategy));        
        uint256 collateral =  IWstETH(wstETH).getStETHByWstETH(balWstETH)*shares/supply;
        uint256 debt =  balDebtETH*shares/supply;
        uint256 swapOut = ICurve(curvePool).get_dy(1, 0, collateral);
        uint256 flashFee = IBalancer(balancerFee).getFlashLoanFeePercentage();
        return swapOut-(debt*1e18+flashFee)/1e18;
    }

}