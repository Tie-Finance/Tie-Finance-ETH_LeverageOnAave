// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IVault.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IOracle.sol";
abstract contract farmClaim is Ownable, ReentrancyGuard{
    using SafeERC20 for IERC20;
    uint256 public constant calDecimals = 10000;
    uint256 public farmFee = 500;
    uint256 public harvestFee = 500;
    event SetfarmFee(uint256 oldRate, uint256 newRate,uint256 oldHarvestFee, uint256 newHarvestFee);
    event Harvest(address caller,uint256 curDeposit,uint256 fee,uint256 harvestFee);


    constructor(
    ){

    }
    function harvest(uint256 slippage,address receiver,bool bDepositFee) nonReentrant external {
        _harvest(slippage,receiver,bDepositFee);
    }
    function _harvest(uint256 slippage,address receiver,bool bDepositFee)internal{
        require(slippage <= 200 , "slippage_TOO_HIGH");
        address _vault = getVault();
        address _depositAsset = getDepositAsset();
        uint256 _total = IERC20(_vault).totalSupply();
        require(_total>0, "EMPTY_SUPPLY");
        claimRewards(slippage);
        uint256 balance = IERC20(_depositAsset).balanceOf(address(this));
        require(balance>0, "EMPTY_REBALANCE");
        uint256 _rebFee = balance*harvestFee/calDecimals;
        if (!bDepositFee && _rebFee>0){
                IERC20(_depositAsset).safeTransfer(receiver, _rebFee);
                balance -= _rebFee;
        }
        uint256 totalDeposit = _totalDeposit();
        uint256 curDeposit = depositToken(balance);
        uint256 _fee = curDeposit*farmFee/calDecimals;
        _rebFee = bDepositFee ? curDeposit*harvestFee/calDecimals : 0;
        uint256 _totalBalance = totalDeposit+curDeposit-_fee-_rebFee;
        if(_fee>0){
            uint256 mintAmount = _total*_fee/_totalBalance; 
            IVault(_vault).mint(mintAmount, getFeePool());
        }
        if(_rebFee>0){
            uint256 mintAmount = _total*_rebFee/_totalBalance; 
            IVault(_vault).mint(mintAmount, receiver);
        }
        emit Harvest(msg.sender,curDeposit,_fee,_rebFee);
        
    }
    /**
        Set Fee Rate
     */
    function setfarmFee(uint256 _farmFee,uint256 _harvestFee,uint256 slippage) public nonReentrant onlyOwner {
        _harvest(slippage,getFeePool(),true);
        require(_farmFee+_harvestFee <5000, "INVALID_RATE");

        uint256 oldRate = farmFee;
        farmFee = _farmFee;
        uint256 oldHarvestFee = harvestFee;
        harvestFee = _harvestFee;
        emit SetfarmFee(oldRate, _farmFee,oldHarvestFee,_harvestFee);
    }

    function getMinOut(address tokenIn,address tokenOut, uint256 amount,uint256 slippage)internal view returns(uint256){
        if(amount == 0){
            return 0;
        }
        (uint256 price0,uint8 decimals0) = IOracle(getOracle()).getPrice(tokenIn);
        (uint256 price1,uint8 decimals1) = IOracle(getOracle()).getPrice(tokenOut);
        uint8 decimals00 = IERC20Metadata(tokenIn).decimals();
        uint8 decimals11 = IERC20Metadata(tokenOut).decimals();
        uint256 amountOut = amount*price0;
        if(decimals0+decimals00 > decimals1+decimals11){
            amountOut = amountOut/(10**(decimals0+decimals00-decimals1-decimals11));
        }else{
            amountOut = amountOut*(10**(decimals1+decimals11-decimals0-decimals00));
        }
        return amountOut*(calDecimals-slippage)/price1/calDecimals;
    }
    function claimRewards(uint256 slippage)internal virtual;
    function _totalDeposit() internal view virtual returns (uint256);
    function depositToken(uint256 amount) internal virtual returns (uint256);
    function getVault() internal view virtual returns(address);
    function getDepositAsset() internal view virtual returns(address);
    function getFeePool() internal view virtual returns(address);
    function getOracle() internal view virtual returns(address);
}