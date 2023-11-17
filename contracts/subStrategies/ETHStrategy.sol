// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


import "./interfaces/IAavePool.sol";
import "./interfaces/IAave.sol";
import "./interfaces/IETHLeverage.sol";
import "./interfaces/IFlashloanReceiver.sol";
import "./interfaces/IExchange.sol";
import "../interfaces/ISubStrategy.sol";
import "../interfaces/IVault.sol";

contract ETHStrategy is Ownable, ISubStrategy, IETHLeverage {

    using SafeERC20 for IERC20;
    // Sub Strategy name
    string public constant poolName = "ETHStrategy V0.9";

    // Controller address
    address public controller;

    // Vault address
    address public vault;

    // Constant magnifier
    uint256 public constant magnifier = 10000;

    // Exchange Address
    address public exchange;

    // Flashloan receiver
    address public receiver;

    // Fee collector
    address public feePool;

    // user input asset
    IERC20 public baseAsset;

    // deposit asset into aave pool
    IERC20 public depositAsset;

    // aave pool token
    IERC20 public aDepositAsset;

    // aave address
    address public IaavePool;

    // Slippages for deposit and withdraw
    uint256 public depositSlippage;
    uint256 public withdrawSlippage;
    uint256 public swapSlippage = 100;

    uint256 public feeRate = 1000;

    // Max Deposit
    uint256 public override maxDeposit;

    // Last Earn Total
    uint256 internal lastTotal;
    bool internal harvested = false;

    // Max Loan Ratio
    uint256 public mlr;

    enum SrategyState {
        Normal,
        Deposit,
        Withdraw
        //EmergencyWithdraw
    }

    event SetController(address controller);

    event SetVault(address vault);

    event SetExchange(address exchange);

    event SetFeePool(address feePool);

    event SetDepositSlippage(uint256 depositSlippage);

    event SetWithdrawSlippage(uint256 withdrawSlippage);

    event SetSwapSlippage(uint256 swapSlippage);

    event SetMaxDeposit(uint256 maxDeposit);

    event SetFlashloanReceiver(address receiver);

    event SetMLR(uint256 oldMlr, uint256 newMlr);

    event SetFeeRate(uint256 oldRate, uint256 newRate);

    event LTVUpdate(
        uint256 oldDebt,
        uint256 oldCollateral,
        uint256 newDebt,
        uint256 newCollateral
    );

    constructor(
        IERC20 _baseAsset,
        IERC20 _depositAsset,
        IERC20 _aDepositAsset,
        uint256 _mlr,
        address _IaavePool,
        address _vault,
        address _feePool
    ) {
        mlr = _mlr;
        baseAsset = _baseAsset;
        depositAsset = _depositAsset;
        aDepositAsset = _aDepositAsset;
        IaavePool = _IaavePool;

        vault = _vault;
        feePool = _feePool;


        // Set Max Deposit as max uin256
        maxDeposit = type(uint256).max;
        address aave = IAavePool(_IaavePool).aave();
        baseAsset.safeApprove(aave, type(uint256).max);
        depositAsset.safeApprove(aave, type(uint256).max);
    }

    receive() external payable {}

    /**
        Only controller can call
     */
    modifier onlyController() {
        require(controller == _msgSender(), "NOT_CONTROLLER");
        _;
    }

    /**
        Only Flashloan receiver can call
     */
    modifier onlyReceiver() {
        require(receiver == _msgSender(), "NOT_FLASHLOAN_RECEIVER");
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
        lastTotal = _realTotalAssets();
    }
    //////////////////////////////////////////
    //           Flash loan Fallback        //
    //////////////////////////////////////////

    /**
        External Function for Callback when to flash loan
     */
    function loanFallback(
        uint256 loanAmt,
        uint256 feeAmt,
        bytes calldata userData
    ) external override onlyReceiver {
        (SrategyState curState,uint256 amountIn) = abi.decode(userData,(SrategyState,uint256));
        require(curState != SrategyState.Normal, "NORMAL_STATE_CANT_CALL_THIS");
        address aave = IAavePool(IaavePool).aave();
        if (curState == SrategyState.Deposit) {
            // Transfer baseAsset to Exchange
            amountIn = amountIn+loanAmt;
            baseAsset.safeTransfer(exchange, amountIn);
            // Swap baseAsset to depositAsset
            uint256 minOut = IAavePool(IaavePool).convertAmount(address(baseAsset), address(depositAsset), amountIn*(magnifier-swapSlippage)/magnifier);
            IExchange(exchange).swap(address(baseAsset),address(depositAsset),amountIn,minOut);
    
            // Deposit depositAsset to AAVE
            uint256 depoistBalance = depositAsset.balanceOf(address(this));

            IAave(aave).deposit(address(depositAsset), depoistBalance, address(this), 0);
            if (IAavePool(IaavePool).getCollateral(address(this)) == 0) {
                IAave(aave).setUserUseReserveAsCollateral(address(depositAsset), true);
            }
            // Repay flash loan
            uint256 repay = loanAmt + feeAmt;
            IAave(aave).borrow(address(baseAsset), repay, 2, 0, address(this));

            baseAsset.safeTransfer(receiver, repay);
        } else if (curState == SrategyState.Withdraw) {
            uint256 withdrawAmount = (loanAmt *
                aDepositAsset.balanceOf(address(this))) / IAavePool(IaavePool).getDebt(address(this));

            // Repay WETH to aave
            IAave(aave).repay(address(baseAsset), loanAmt, 2, address(this));
            IAave(aave).withdraw(address(depositAsset), withdrawAmount, address(this));

            // Swap depositAsset to baseAsset
            depositAsset.safeTransfer(exchange, withdrawAmount);
            uint256 minOut = IAavePool(IaavePool).convertAmount(address(depositAsset), address(baseAsset), withdrawAmount*(magnifier-swapSlippage)/magnifier);
            IExchange(exchange).swap(address(depositAsset),address(baseAsset),withdrawAmount,minOut);
            // Repay Weth to receiver
            baseAsset.safeTransfer(receiver, loanAmt + feeAmt);
        } else {
            revert("NOT_A_SS_STATE");
        }
    }

    //////////////////////////////////////////
    //          VIEW FUNCTIONS              //
    //////////////////////////////////////////

    /**
        External view function of total USDC deposited in Covex Booster
     */
    function totalAssets() external view override returns (uint256) {
        return _totalAssets();
    }

    /**
        Internal view function of total USDC deposited
    */
    function _totalAssets() internal view returns (uint256) {
        if (!harvested){
            (uint256 fee,) = _calculateFee();
            return _realTotalAssets() - fee;
        }else{
            return _realTotalAssets();
        }
    }
    function _realTotalAssets()internal view returns (uint256) {
        (uint256 st,uint256 e) = IAavePool(IaavePool).getCollateralAndDebt(address(this));
        return st-e;
    }
    /**
        Deposit function of USDC
     */
    function deposit(
        uint256 _amount
    ) external override onlyController collectFee returns (uint256) {
        uint256 deposited = _deposit(_amount);
        return deposited;
    }

    /**
        Deposit internal function
     */
    function _deposit(uint256 _amount) internal returns (uint256) {
        // Get Prev Deposit Amt
        uint256 prevAmt = _totalAssets();

        // Check Max Deposit
        require(prevAmt + _amount <= maxDeposit, "EXCEED_MAX_DEPOSIT");

        // Calculate Flashloan Fee - in terms of 1e4
        uint256 fee = IFlashloanReceiver(receiver).getFee();
        uint256 feeParam = fee + magnifier;
        uint256 loanAmt = (_amount * mlr) / (feeParam - mlr);
        // uint256 feeAmt = (loanAmt * fee) / magnifier;

        // Execute flash loan
        IFlashloanReceiver(receiver).flashLoan(address(baseAsset), loanAmt,abi.encode(SrategyState.Deposit,_amount));

        // Get new total assets amount
        uint256 newAmt = _totalAssets();

        // Deposited amt
        uint256 deposited = newAmt - prevAmt;
        uint256 minOutput = (_amount * (magnifier - depositSlippage)) /
            magnifier;
        require(deposited >= minOutput, "DEPOSIT_SLIPPAGE_TOO_BIG");
        return deposited;
    }

    /**
        Withdraw function of USDC
     */
    function withdraw(
        uint256 _amount
    ) external override onlyController collectFee returns (uint256) {

        // Get Prev Deposit Amt
        uint256 prevAmt = _totalAssets();
        require(_amount <= prevAmt, "INSUFFICIENT_ASSET");

        uint256 loanAmt = (IAavePool(IaavePool).getDebt(address(this)) * _amount) / prevAmt;
        IFlashloanReceiver(receiver).flashLoan(address(baseAsset), loanAmt,abi.encode(SrategyState.Withdraw,uint256(0)));

        uint256 toSend = baseAsset.balanceOf(address(this));
        baseAsset.safeTransfer(controller, toSend);

        return toSend;
    }

    /**
        Harvest reward token from convex booster
     */
    function harvest() external onlyOwner collectFee {
    }
    function _calculateFee()internal view returns (uint256,uint256) {
        uint256 currentAssets = _realTotalAssets();
        if(lastTotal>=currentAssets){
            return (0,0);
        }else{
            uint256 totalEF = IERC20(vault).totalSupply();
            if (totalEF == 0){
                return (0,0);
            }
            //uint256 feePoolBal = IERC20(vault).balanceOf(feePool);
            
            uint256 stFee = (currentAssets-lastTotal) *feeRate /magnifier;
            //stFee = stFee - ((stFee * feePoolBal) / (totalEF));
            uint256 mintAmt = (stFee * totalEF) / (currentAssets - stFee);
            if (mintAmt == 0){
                return (0,0);
            }
            return (stFee,mintAmt);
        }
    }


    /**
        Raise LTV
     */
    function raiseLTV(uint256 lt) public onlyOwner {
        (uint256 st,uint256 e) = IAavePool(IaavePool).getCollateralAndDebt(address(this));

        require(e * magnifier < st * mlr, "NO_NEED_TO_RAISE");

        address aave = IAavePool(IaavePool).aave();
        uint256 x = (st * mlr - (e * magnifier)) / (magnifier - mlr);
        uint256 y = (st * lt) / magnifier - e - 1;

        if (x > y) {
            x = y;
        }

        IAave(aave).borrow(address(baseAsset), x, 2, 0, address(this));
        uint256 baseAmt = baseAsset.balanceOf(address(this));

        // Transfer base asset to Exchange
        baseAsset.safeTransfer(exchange, baseAmt);
        // Swap baseAsset to depositAsset
        uint256 minOut = IAavePool(IaavePool).convertAmount(address(baseAsset), address(depositAsset),baseAmt*(magnifier-swapSlippage)/magnifier);
        IExchange(exchange).swap(address(baseAsset),address(depositAsset),baseAmt,minOut);

        // Deposit STETH to AAVE
        uint256 depositAmt = depositAsset.balanceOf(address(this));

        IAave(aave).deposit(address(depositAsset), depositAmt, address(this), 0);
        (uint256 st1,uint256 e1) = IAavePool(IaavePool).getCollateralAndDebt(address(this));
        emit LTVUpdate(e, st, e1, st1);
    }

    /**
        Reduce LTV
     */
    function reduceLTV() public onlyOwner {
        (uint256 st,uint256 e) = IAavePool(IaavePool).getCollateralAndDebt(address(this));

        require(e * magnifier > st * mlr, "NO_NEED_TO_REDUCE");

        address aave = IAavePool(IaavePool).aave();

        uint256 x = (e * magnifier - st * mlr) / (magnifier - mlr);

        uint256 loanAmt = (x * e) / st;

        IFlashloanReceiver(receiver).flashLoan(address(baseAsset), loanAmt,abi.encode(SrategyState.Withdraw,uint256(0)));


        uint256 baseBal = baseAsset.balanceOf(address(this));
        // Approve WETH to AAVE
        // Repay WETH to aave
        IAave(aave).repay(address(baseAsset), baseBal, 2, address(this));
    }



    /**
        Check withdrawable status of required amount
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
    function setController(address _controller) public onlyOwner {
        require(_controller != address(0), "INVALID_ADDRESS");
        controller = _controller;

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
        Set Deposit Slipage
     */
    function setDepositSlippage(uint256 _slippage) public onlyOwner {
        require(_slippage < magnifier, "INVALID_SLIPPAGE");

        depositSlippage = _slippage;

        emit SetDepositSlippage(depositSlippage);
    }

    /**
        Set Withdraw Slipage
     */
    function setWithdrawSlippage(uint256 _slippage) public onlyOwner {
        require(_slippage < magnifier, "INVALID_SLIPPAGE");

        withdrawSlippage = _slippage;

        emit SetWithdrawSlippage(withdrawSlippage);
    }

    /**
        Set swap Slipage
     */
    function setSwapSlippage(uint256 _slippage) public onlyOwner {
        require(_slippage < magnifier, "INVALID_SLIPPAGE");

        swapSlippage = _slippage;

        emit SetSwapSlippage(swapSlippage);
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
        Set Flashloan Receiver
     */
    function setFlashLoanReceiver(address _receiver) public onlyOwner {
        require(_receiver != address(0), "INVALID_RECEIVER_ADDRESS");
        receiver = _receiver;

        emit SetFlashloanReceiver(receiver);
    }

    /**
        Set Exchange
     */
    function setExchange(address _exchange) public onlyOwner {
        require(_exchange != address(0), "INVALID_ADDRESS");
        exchange = _exchange;

        emit SetExchange(exchange);
    }

    /**
        Set Fee Rate
     */
    function setFeeRate(uint256 _rate) public collectFee onlyOwner {
        require(_rate > 0, "INVALID_RATE");

        uint256 oldRate = feeRate;
        feeRate = _rate;

        emit SetFeeRate(oldRate, feeRate);
    }

    /**
        Set MLR
     */
    function setMLR(uint256 _mlr) public onlyOwner {
        require(_mlr > 0 && _mlr < magnifier, "INVALID_RATE");

        uint256 oldMlr = mlr;
        mlr = _mlr;

        emit SetMLR(oldMlr, _mlr);
    }
}
