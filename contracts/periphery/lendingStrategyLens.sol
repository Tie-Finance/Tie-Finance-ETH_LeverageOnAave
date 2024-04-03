// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/ISubStrategy.sol";
import "../interfaces/IVault.sol";
import "../subStrategies/interfaces/IQuoter.sol";
import "../subStrategies/interfaces/IAavePool.sol";
import "./interfaces/ILens.sol";
import "./interfaces/ILendingStrategy.sol";
import "./interfaces/IUniExchange.sol";


contract lendingStrategyLens is Ownable{
    address public immutable lendingVault;
    address public immutable lendingStrategy;
    address public immutable ethVault;
    address public immutable ethStrategyLens;
    address immutable public aavePool;

    address public immutable aWBTC;
    address public immutable aDebtETH;
    address public immutable wbtc;
    address public immutable weth;
    address public univ3Quoter;
    constructor(address _vault,address _strategy,address _univ3Quoter,address _ethStrategyLens,address _aDebtEth,address _aWBTC){
        lendingVault = _vault;
        lendingStrategy = _strategy;
        ethStrategyLens = _ethStrategyLens;
        aDebtETH = _aDebtEth;
        aWBTC = _aWBTC;
        ethVault = ILendingStrategy(_strategy).ethLeverage();
        aavePool = ILendingStrategy(_strategy).IaavePool();
        weth = ILendingStrategy(_strategy).weth(); 
        wbtc = ILendingStrategy(_strategy).depositAsset(); 
        univ3Quoter = _univ3Quoter;
    }
    function setUniv3Quoter(address _univ3Quoter) external onlyOwner {
        univ3Quoter = _univ3Quoter;
    }
    function getDepositOut(uint256 assets) external view returns (uint256) {
        uint256 totalAsset = ISubStrategy(lendingVault).totalAssets();
        if (totalAsset == 0){
            return assets;
        }
        uint256 supply = IERC20(lendingVault).totalSupply();
        uint256 balDebtETH = IERC20(aDebtETH).balanceOf(address(lendingStrategy));
        uint256 _lending =  balDebtETH*assets/totalAsset;
        uint256 ethShares = ILens(ethStrategyLens).getDepositOut(_lending);
        uint256 ethAssets = IVault(ethVault).convertToAssets(ethShares);
        uint256 totalDeposit = assets-IAavePool(aavePool).convertAmount(weth,wbtc,_lending)+IAavePool(aavePool).convertAmount(weth,wbtc,ethAssets);
        return totalDeposit*supply/totalAsset;
    }

    function getRedeemOut(uint256 shares) external returns (uint256) {
        uint256 supply = IERC20(ethVault).totalSupply();
        if (supply == 0){
            return shares;
        }
        uint256 ethShare = IERC20(ethVault).balanceOf(address(lendingStrategy))*shares/supply;
        uint256 ethOut = ILens(ethStrategyLens).getRedeemOut(ethShare);
        uint256 balDebtETH = IERC20(aDebtETH).balanceOf(address(lendingStrategy));
        uint256 debt = balDebtETH*shares/supply;
        uint256 balWBTC = IERC20(aWBTC).balanceOf(address(lendingStrategy));
        uint256 wbtcAmount = balWBTC*shares/supply;
        address exchange = ILendingStrategy(lendingStrategy).exchange();
        uint24 univ3Fee = IUniExchange(exchange).univ3Fee();
        if(debt<ethOut){
            uint256 swapOut = IQuoter(univ3Quoter).quoteExactInputSingle(weth, wbtc, univ3Fee, ethOut-debt, 0);
            wbtcAmount += swapOut;
        }else if(debt>ethOut){
            uint256 swapIn = IQuoter(univ3Quoter).quoteExactOutputSingle(wbtc, weth, univ3Fee, debt-ethOut, 0);
            wbtcAmount -= swapIn;
        }
        return wbtcAmount;
    }

}