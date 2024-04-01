// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../operator.sol";
import "../saveApprove.sol";
import "../../interfaces/ISubStrategy.sol";
import "../../interfaces/IVault.sol";
import "../interfaces/IOracle.sol";


abstract contract farmStrategy is operatorMap,saveApprove, ISubStrategy {
    using SafeERC20 for IERC20;


    // Controller address
    address public controller;

    // Vault address
    address public vault;


    // Constant magnifier
    uint256 public constant magnifier = 10000;

    uint256 public feeRate = 500;
    uint256 public rebalanceFee = 500;


    address public baseAsset;
    // deposit asset into farm pool
    address public depositAsset;

    address public depositPool;
    address public farmPool;

    // Max Deposit
    uint256 public override maxDeposit;

    // Fee Collector
    address public feePool;


    address public oracle;


    address[] public rewardTokens;



    event SetController(address controller);

    event SetFeePool(address _feePool);
    event SetOracle(address oracle);

    event SetVault(address vault);

    event SetMaxDeposit(uint256 maxDeposit);

    event SetRewards(address[] rewardTokens);

    event SetFeeRate(uint256 oldRate, uint256 newRate,uint256 oldRebalanceFee, uint256 newRebalanceFee);

    constructor(
        address _baseAsset,
        address _depositAsset,
        address _vault,
        address _depositPool,
        address _farmPool,
        address _feePool
    ) {
        baseAsset = _baseAsset;
        depositAsset = _depositAsset;

        require(_vault != address(0), "INVALID_ADDRESS");
        require(_depositPool != address(0), "INVALID_ADDRESS");
        require(_farmPool != address(0), "INVALID_ADDRESS");
        require(_feePool != address(0), "INVALID_ADDRESS");
        vault = _vault;
        depositPool = _depositPool;
        farmPool = _farmPool;
        feePool = _feePool;

        // Set Max Deposit as max uin256
        maxDeposit = type(uint256).max;
    }
    receive() external payable {}
    /**
        Only controller can call
     */
    modifier onlyController() {
        require(controller == _msgSender(), "ONLY_CONTROLLER");
        _;
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
    ) external override onlyController returns (uint256) {
        uint256 deposited = _deposit(_amount);
        return deposited;
    }

    /**
        Withdraw function of WBTC
     */
    function withdraw(
        uint256 _amount
    ) external override onlyController returns (uint256) {
        uint256 withdrawn = _withdraw(_amount);
        return withdrawn;
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
    function setController(address _controller) external onlyOwner {
        require(controller == address(0), "CONTROLLER_ALREADY");
        require(_controller != address(0), "INVALID_ADDRESS");
        controller = _controller;
        IERC20(baseAsset).safeApprove(_controller,type(uint256).max);
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
    function setOracle(address _oracle) public onlyOwner {
        require(_oracle != address(0), "INVALID_ADDRESS");
        oracle = _oracle;

        emit SetOracle(_oracle);
    }


    /**
        Set Max Deposit
     */
    function setMaxDeposit(uint256 _maxDeposit) public onlyOwner {
        require(_maxDeposit > 0, "INVALID_MAX_DEPOSIT");
        maxDeposit = _maxDeposit;

        emit SetMaxDeposit(maxDeposit);
    }

    function setRewards(address[] memory _rewards) external onlyOwner {
        rewardTokens = _rewards;
        emit SetRewards(_rewards);
    }
    /**
        Set Fee Rate
     */
    function setFeeRate(uint256 _feeRate,uint256 _rebalanceFee,uint256 slipPage) public onlyOwner {
        _rebalance(slipPage,feePool,true);
        require(_feeRate+_rebalanceFee <magnifier, "INVALID_RATE");

        uint256 oldRate = feeRate;
        feeRate = _feeRate;
        uint256 oldRebalanceFee = rebalanceFee;
        rebalanceFee = _rebalanceFee;
        emit SetFeeRate(oldRate, _feeRate,oldRebalanceFee,_rebalanceFee);
    }

    /**
        Deposit internal function
     */
    function _deposit(uint256 _amount) internal returns (uint256) {
        // Get Prev Deposit Amt
        uint256 prevAmt = _totalAssets();

        // Check Max Deposit
        require(prevAmt + _amount <= maxDeposit, "EXCEED_MAX_DEPOSIT");

        uint256 outAmount = swapBaseAssetToDepositAsset(_amount,0);
        depositToken(outAmount);
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
        uint256 _depositAmount = getMinOut(baseAsset,depositAsset,_amount,0);
        withdrawToken(_depositAmount);
        return swapDepositAssetTobaseAsset(_depositAmount,0);
    }
    function rebalance(uint256 slipPage,address receiver,bool bDepositFee) external {
        _rebalance(slipPage,receiver,bDepositFee);
    }
    function _rebalance(uint256 slipPage,address receiver,bool bDepositFee)internal{
        uint256 totalEF = IERC20(vault).totalSupply();
        if (totalEF == 0){
            return;
        }
        claimRewards(slipPage);
        uint256 balance = IERC20(depositAsset).balanceOf(address(this));
        if (balance == 0){
            return;
        }
        uint256 _fee = balance*feeRate/magnifier;
        uint256 _rebFee = balance*rebalanceFee/magnifier;
        uint256 _totalBalance = _totalDeposit()+balance-_fee-_rebFee;
        if(_fee>0){
            uint256 mintAmount = totalEF*_fee/_totalBalance; 
            IVault(vault).mint(mintAmount, feePool);
        }
        if(_rebFee>0){
            if(bDepositFee){
                uint256 mintAmount = totalEF*_rebFee/_totalBalance; 
                IVault(vault).mint(mintAmount, receiver);
            }else{
                IERC20(depositAsset).safeTransfer(receiver, _rebFee);
                balance -= _rebFee;
            }
        }

        depositToken(balance);
    }
    function getMinOut(address tokenIn,address tokenOut, uint256 amount,uint256 slipPage)internal view returns(uint256){
        if(amount == 0){
            return 0;
        }
        (uint256 price0,uint8 decimals0) = IOracle(oracle).getPrice(tokenIn);
        (uint256 price1,uint8 decimals1) = IOracle(oracle).getPrice(tokenOut);
        uint8 decimals00 = IERC20Metadata(tokenIn).decimals();
        uint8 decimals11 = IERC20Metadata(tokenOut).decimals();
        uint256 amountOut = amount*price0;
        if(decimals0+decimals00 > decimals1+decimals11){
            amountOut = amountOut/(10**(decimals0+decimals00-decimals1-decimals11));
        }else{
            amountOut = amountOut*(10**(decimals1+decimals11-decimals0-decimals00));
        }
        return amountOut*(magnifier-slipPage)/price1/magnifier;
    }
    function _totalAssets() internal view returns (uint256){
        return getMinOut(depositAsset,baseAsset,_totalDeposit(),0);
    }
    function depositToken(uint256 amount) internal virtual;
    function withdrawToken(uint256 amount)internal virtual;
    function claimRewards(uint256 slipPage)internal virtual;
    function _totalDeposit() internal view virtual returns (uint256);
    function swapBaseAssetToDepositAsset(uint256 amount,uint256 minAmount) internal virtual returns(uint256);
    function swapDepositAssetTobaseAsset(uint256 amount,uint256 minAmount) internal virtual returns(uint256);
}
