// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./operator.sol";
import "./interfaces/IWeth.sol";
import "./interfaces/IAave.sol";
import "./interfaces/IAavePool.sol";

import "./interfaces/IUniExchange.sol";
import "../interfaces/ISubStrategy.sol";
import "../interfaces/IVault.sol";

contract lendingStrategy is operatorMap, ISubStrategy {
    using SafeERC20 for IERC20;

    // Sub Strategy name
    string public constant poolName = "Lending Strategy V0.9";

    // Controller address
    address public controller;

    // Vault address
    address public vault;

    // ETH Leverage address
    address immutable public ethLeverage;


    // Constant magnifier
    uint256 public constant magnifier = 10000;

    uint256 public feeRate = 500;

    uint256 public lastCollateral;


    // WETH Address
    address immutable public weth;

    // deposit asset into aave pool
    IERC20 immutable public depositAsset;

    // aave address
    address immutable public IaavePool;

    // Max Deposit
    uint256 public override maxDeposit;


    // Max Loan Ratio
    uint256 public mlr;

    // Fee Collector
    address public feePool;

    // Exchange Address
    address public exchange;

    bool internal harvested = false;


    event SetController(address controller);

    event SetFeePool(address _feePool);

    event SetVault(address vault);

    event SetMaxDeposit(uint256 maxDeposit);

    event SetMLR(uint256 oldMlr, uint256 newMlr);

    event MLRUpdate(
        uint256 oldDebt,
        uint256 oldCollateral,
        uint256 newDebt,
        uint256 newCollateral
    );

    event SetExchange(address exchange);

    event SetFeeRate(uint256 oldRate, uint256 newRate);

    constructor(
        IERC20 _depositAsset,
        address _weth,
        uint256 _mlr,
        address _IaavePool,
        address _vault,
        address _ethLeverage,
        address _feePool
    ) {
        require(_weth != address(0), "INVALID_ADDRESS");
        require(_IaavePool != address(0), "INVALID_ADDRESS");
        require(_feePool != address(0), "INVALID_ADDRESS");
        require(_ethLeverage != address(0), "INVALID_ADDRESS");
        require(_vault != address(0), "INVALID_ADDRESS");
        require(_mlr < magnifier, "INVALID_RATE");

        mlr = _mlr;
        depositAsset = _depositAsset;
        weth = _weth;
        IaavePool = _IaavePool;

        vault = _vault;
        ethLeverage = _ethLeverage;

        feePool = _feePool;

        // Set Max Deposit as max uint256
        maxDeposit = type(uint256).max;
        address aave = IAavePool(_IaavePool).aave();
        _depositAsset.safeApprove(_IaavePool, type(uint256).max);
        IERC20(_weth).safeApprove(aave, type(uint256).max);
        IERC20(_weth).safeApprove(_ethLeverage, type(uint256).max);

    }
    /**
        Only controller can call
     */
    modifier onlyController() {
        require(controller == _msgSender(), "ONLY_CONTROLLER");
        _;
    }
    modifier collectFee(){
        (,uint256 mintAmount) = _calculateFee();
        harvested = true;
        if(mintAmount>0){
            IVault(vault).mint(mintAmount, feePool);
        }
        _;
        harvested = false;
        lastCollateral = IAavePool(IaavePool).getCollateralTo(address(this),address(depositAsset));
    }
    //////////////////////////////////////////
    //          VIEW FUNCTIONS              //
    //////////////////////////////////////////

    /**
        External view function of total WBTC deposited in Covex Booster
     */
    function totalAssets() external view override returns (uint256) {
        return _totalAssets();
    }

    /**
        Deposit function of WBTC
     */
    function deposit(
        uint256 _amount
    ) external override onlyController collectFee returns (uint256) {
        uint256 deposited = _deposit(_amount);
        return deposited;
    }

    /**
        Withdraw function of WBTC
     */
    function withdraw(
        uint256 _amount
    ) external override onlyController collectFee returns (uint256) {
        uint256 withdrawn = _withdraw(_amount);
        return withdrawn;
    }



    /**
        get withdrawable amount of required amount
     */
    function withdrawable(
        uint256 _amount
    ) external view override returns (uint256) {
        // Get Current Deposit Amt
        uint256 total = _totalAssets();

        // If requested amt is bigger than total asset, return false
        if (_amount > total) return total;
        // Todo Have to check withdrawable amount
        else return _amount;
    }

    //////////////////////////////////////////////////
    //               SET CONFIGURATION              //
    //////////////////////////////////////////////////

    /**
        Set Controller
     */
    function setController(address _controller) external onlyOwner {
        require(controller == address(0), "CONTROLLER_ALREADY");
        require(_controller != address(0), "INVALID_ADDRESS");
        controller = _controller;
        depositAsset.safeApprove(_controller,type(uint256).max);
        emit SetController(controller);
    }

    /**
        Set Vault
     */
    function setVault(address _vault) public onlyOwner {
        require(_vault != address(0), "INVALID_ADDRESS");
        vault = _vault;

        emit SetVault(vault);
    }

    /**
        Set Fee Pool
     */
    function setFeePool(address _feePool) public onlyOwner {
        require(_feePool != address(0), "INVALID_ADDRESS");
        feePool = _feePool;

        emit SetFeePool(feePool);
    }


    /**
        Set Max Deposit
     */
    function setMaxDeposit(uint256 _maxDeposit) public onlyOwner {
        require(_maxDeposit > 0, "INVALID_MAX_DEPOSIT");
        maxDeposit = _maxDeposit;

        emit SetMaxDeposit(maxDeposit);
    }

    /**
        Set MLR
     */
    function setMLR(uint256 _mlr,uint256 slippage) public onlyOperator {
        require(_mlr < magnifier, "INVALID_RATE");

        uint256 oldMlr = mlr;
        mlr = _mlr;
        (uint256 st,uint256 e) = IAavePool(IaavePool).getCollateralAndDebt(address(this));
        uint256 recentMlr = e*magnifier/st;
        if (recentMlr>_mlr){
            reduceMlr(st,e,slippage);
        }else if(recentMlr<_mlr){
            raiseMlr(st,e,slippage);
        }
        emit SetMLR(oldMlr, _mlr);
    }
    /**
        Raise Mlr
     */
    function raiseMlr(uint256 st,uint256 e,uint256 slippage) internal {

        require(e * magnifier < st * mlr, "NO_NEED_TO_RAISE");

        uint256 x = (st * mlr) / magnifier - e;

        address aave = IAavePool(IaavePool).aave();

        IAave(aave).borrow(weth, x, 2, 0, address(this));
        uint256 wethAmt = IERC20(weth).balanceOf(address(this));
        uint256 minShares = IVault(ethLeverage).convertToShares(wethAmt)*(magnifier-slippage)/magnifier;
        if(minShares>0){
            IVault(ethLeverage).deposit(wethAmt,minShares,address(this));
        }

        // Deposit ETH to ETH Leverage
        (uint256 st1,uint256 e1) = IAavePool(IaavePool).getCollateralAndDebt(address(this));

        emit MLRUpdate(e, st, e1, st1);
    }

    /**
        Reduce Mlr
     */
    function reduceMlr(uint256 st,uint256 e,uint256 slippage) internal {

        require(e * magnifier > st * mlr, "NO_NEED_TO_REDUCE");

        uint256 x = (e - (mlr * st) / magnifier);

        uint256 toWithdraw = (x * magnifier) / (magnifier - slippage);
        uint256 shares = IVault(ethLeverage).convertToShares(toWithdraw);
        uint256 balance = IERC20(ethLeverage).balanceOf(address(this));
        uint256 minWithdraw = x;
        if ( shares> balance){
            toWithdraw = IVault(ethLeverage).convertToAssets(balance);
            minWithdraw = toWithdraw*(magnifier-slippage)/magnifier;
        }
        // Withdraw ETH from Leverage
        IVault(ethLeverage).withdraw(toWithdraw,minWithdraw, address(this));
        uint256 wethAmt = IERC20(weth).balanceOf(address(this));
        //require(wethAmt >= x, "ETH withdrawn not enough");

        // Deposit exceed ETH
        if(wethAmt>x){
            uint256 depositAmt = wethAmt - x; 
            uint256 minShares = IVault(ethLeverage).convertToShares(depositAmt)*(magnifier-slippage)/magnifier;
            if(minShares>0){
                IVault(ethLeverage).deposit(depositAmt,minShares,address(this));
            }
        }else if(wethAmt<x){
            x = wethAmt;
        }

        address aave = IAavePool(IaavePool).aave();
        // Repay WETH to aave
        IAave(aave).repay(weth, x, 2, address(this));
        (uint256 st1,uint256 e1) = IAavePool(IaavePool).getCollateralAndDebt(address(this));

        emit MLRUpdate(e, st, e1, st1);
    }
    /**
        Set Exchange
     */
    function setExchange(address _exchange) external onlyOwner {
        require(_exchange != address(0), "INVALID_ADDRESS");
        if (exchange != address(0)){
            depositAsset.safeApprove(exchange,0);
            IERC20(weth).safeApprove(exchange,0);
        }
        exchange = _exchange;
        depositAsset.safeApprove(_exchange,type(uint256).max);
        IERC20(weth).safeApprove(_exchange,type(uint256).max);
        emit SetExchange(exchange);
    }
    /**
        Set Fee Rate
     */
    function setFeeRate(uint256 _rate) public onlyOwner collectFee {
        require(_rate > 0, "INVALID_RATE");

        uint256 oldRate = feeRate;
        feeRate = _rate;

        emit SetFeeRate(oldRate, feeRate);
    }
    //////////////////////////////////////////
    //          INTERNAL FUNCTIONS          //
    //////////////////////////////////////////
    /**
        Internal view function of total WBTC deposited
    */
    function _totalAssets() internal view returns (uint256) {
        if (!harvested){
            (uint256 fee,) = _calculateFee();
            return _realTotalAssets() - fee;
        }else{
            return _realTotalAssets();
        }
    }
    function _realTotalAssets() internal view returns (uint256) {
        (uint256 _collateral,uint256 _debt) = IAavePool(IaavePool).getCollateralAndDebtTo(address(this),address(depositAsset));
        return _collateral+IAavePool(IaavePool).convertAmount(weth,address(depositAsset),_totalETH())-_debt;
    } 
    //
    function _calculateFee()internal view returns (uint256,uint256) {
        uint256 currentCollateral = IAavePool(IaavePool).getCollateralTo(address(this),address(depositAsset));
        if(lastCollateral>=currentCollateral){
            return (0,0);
        }else{
            uint256 totalEF = IERC20(vault).totalSupply();
            if (totalEF == 0){
                return (0,0);
            }
            
            uint256 stFee = (currentCollateral-lastCollateral) *feeRate /magnifier;
            //stFee = stFee - ((stFee * feePoolBal) / (totalEF));
            uint256 currentTotal = _realTotalAssets();
            uint256 mintAmt = (stFee * totalEF) / (currentTotal - stFee);
            if (mintAmt == 0){
                return (0,0);
            }
            return (stFee,mintAmt);
        }
    }


    /**
        Internal view function of total ETH assets
     */
    function _totalETH() internal view returns (uint256) {
        uint256 lpBal = IERC20(ethLeverage).balanceOf(address(this));
        uint256 totalETH = IVault(ethLeverage).convertToAssets(lpBal);
        return totalETH;
    }

    /**
        Deposit internal function
     */
    function _deposit(uint256 _amount) internal returns (uint256) {
        // Get Prev Deposit Amt
        uint256 prevAmt = _totalAssets();

        // Check Max Deposit
        require(prevAmt + _amount <= maxDeposit, "EXCEED_MAX_DEPOSIT");

        (uint256 col,uint256 debt) = IAavePool(IaavePool).getCollateralAndDebt(address(this));
        address aave = IAavePool(IaavePool).aave();

        // Deposit WBTC
        IAavePool(IaavePool).deposit(address(depositAsset), _amount);

        if (col == 0) {
            IAave(aave).setUserUseReserveAsCollateral(address(depositAsset), true);
        }

        // Calculate ETH amount to borrow
        uint256 ethToBorrow;
        if (col == 0) {
            ethToBorrow = IAavePool(IaavePool).convertAmount(address(depositAsset),weth,mlr * _amount/magnifier);
        } else {
            ethToBorrow =IAavePool(IaavePool).convertAmount(address(depositAsset),weth,_amount *debt/col);
        }

        // Borrow ETH from AAVE
        if (ethToBorrow>0){
            IAave(aave).borrow(weth, ethToBorrow, 2, 0, address(this));
            // Deposit to ETH Leverage SS
            IVault(ethLeverage).deposit(ethToBorrow,1, address(this));
        }

        // Get new total assets amount
        uint256 newAmt = _totalAssets();

        // Deposited amt
        uint256 deposited = newAmt - prevAmt;

        return deposited;
    }

    function _withdraw(uint256 _amount) internal returns (uint256) {
        // Get Prev Deposit Amt
        uint256 prevAmt = _totalAssets();
        require(_amount <= prevAmt, "INSUFFICIENT_ASSET");

        address aave = IAavePool(IaavePool).aave();
        //Calculate how much collateral to be withdrawn
        uint256 _withdrawAmount = IAavePool(IaavePool).getCollateralTo(address(this),address(depositAsset)) * _amount/prevAmt;
        // Calculate how much eth to be withdrawn from Leverage SS
        uint256 ethWithdraw = (_totalETH() * _amount) / prevAmt;

        uint256 ethBefore = IERC20(weth).balanceOf(address(this));

        // Withdraw ETH from ETH Leverage
        if(ethWithdraw>0){
            IVault(ethLeverage).withdraw(ethWithdraw,0, address(this));
        }

        uint256 ethWithdrawn = IERC20(weth).balanceOf(address(this)) - ethBefore;

        // Withdraw WBTC from AAVE
        uint256 ethDebt = Math.ceilDiv((IAavePool(IaavePool).getDebt(address(this)) * _amount), prevAmt);
        if (ethWithdrawn >= ethDebt) {
            if(ethDebt>0){
                IAave(aave).repay(weth, ethDebt, 2, address(this));
            }
            uint256 swapAmount = 0;
            if(ethWithdrawn > ethDebt){
                swapAmount = IUniExchange(exchange).swapExactInput(
                    weth,
                    address(depositAsset),
                    ethWithdrawn - ethDebt,
                    0
                );
            }
            IAave(aave).withdraw(address(depositAsset), _withdrawAmount, address(this));
            _withdrawAmount += swapAmount;
        }else{
            if(ethWithdrawn>0){
                IAave(aave).repay(weth, ethWithdrawn, 2, address(this));
            }
            uint256 witdrawAmt = IAavePool(IaavePool).getCollateralMaxWithdrawTo(address(this), address(depositAsset));
            if (witdrawAmt>= _withdrawAmount){
                IAave(aave).withdraw(address(depositAsset), _withdrawAmount, address(this));
                uint256 swapAmount = IUniExchange(exchange).swapExactOutput(
                    address(depositAsset),
                    weth,
                    ethDebt - ethWithdrawn,
                    _withdrawAmount
                );
                IAave(aave).repay(weth, ethDebt - ethWithdrawn, 2, address(this));
                _withdrawAmount -= swapAmount;
            }else{
                IAave(aave).withdraw(address(depositAsset), witdrawAmt, address(this));
                uint256 swapAmount = IUniExchange(exchange).swapExactOutput(
                    address(depositAsset),
                    weth,
                    ethDebt - ethWithdrawn,
                    witdrawAmt
                );
                IAave(aave).repay(weth, ethDebt - ethWithdrawn, 2, address(this));
                IAave(aave).withdraw(address(depositAsset), _withdrawAmount-witdrawAmt, address(this));
                _withdrawAmount -= swapAmount;
            }
        }
        return _withdrawAmount;
    }
}
