// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "../subStrategies/interfaces/IAavePool.sol";
import "./interfaces/IAaveStrategy.sol";
import "../subStrategies/operator.sol";
contract aaveRebalance is operatorMap {
    uint64 public threshold;
    address immutable public strategy;
    uint64 public maxThreshold;
    address immutable public aavePool;
    uint64 public settingMLR;
    uint64 public slippage;
    uint256 public gasThreshold;
    uint256 public constant magnifier = 10000;
    event Rebalance(address strategy, address sender,rebalanceType rebalance, uint256 settingMLR,uint256 currentMLR);
    enum rebalanceType {
        normal,
        force
    }
    constructor(address _strategy,address _aavePool,uint64 _threshold,uint64 _maxThreshold,uint64 _settingMLR,uint64 _slippage,uint256 _gasThreshold){
        require(_strategy != address(0), "INVALID_ADDRESS");
        strategy = _strategy;
        require(_aavePool != address(0), "INVALID_ADDRESS");
        aavePool = _aavePool;
        require(_threshold>_settingMLR,"INVALID_MLR");
        threshold = _threshold;
        require(_maxThreshold>_threshold,"INVALID_threshold");
        maxThreshold = _maxThreshold;
        settingMLR = _settingMLR;
        gasThreshold =_gasThreshold;
        slippage = _slippage;
    }
    function checkThreshold() public view returns(bool,bytes memory execArgs){
        if(isOverThreshold(maxThreshold)){
            return (true,abi.encodeCall(this.rebalance, (rebalanceType.force)));
        }else if(isOverThreshold(threshold)){
            return (tx.gasprice<gasThreshold,abi.encodeCall(this.rebalance, (rebalanceType.normal)));
        }
        return (false,abi.encodeCall(this.rebalance, (rebalanceType.normal)));
    }
    function isOverThreshold(uint256 _threshold) public view returns(bool){
        (uint256 _collateral,uint256 _debt) = IAavePool(aavePool).getCollateralAndDebt(strategy);
        uint256 currentMLR = _debt*magnifier/_collateral;
        return currentMLR>_threshold;
    }
    function setThreshold(uint64 _threshold,uint64 _maxThreshold)external onlyOwner{
        require(_threshold>settingMLR,"INVALID_MLR");
        threshold = _threshold;
        require(_maxThreshold>_threshold,"INVALID_threshold");
        maxThreshold = _maxThreshold;
    }
    function setDefaultMLR(uint64 _settingMLR)external onlyOwner{
        settingMLR = _settingMLR;
    }
    function setConfig(uint256 _gasThreshold,uint64 _slippage)external onlyOwner{
        gasThreshold =_gasThreshold;
        slippage = _slippage;
    }
    function rebalance(rebalanceType _type) onlyOperator external{
        if(_type == rebalanceType.force){
            if(isOverThreshold(maxThreshold)){
                IAaveStrategy(strategy).setMLR(settingMLR,magnifier/2);
                emitRebalanceEvent(_type);
                return;
            }
        }
        if(isOverThreshold(threshold)){
            if(tx.gasprice<=gasThreshold){
                IAaveStrategy(strategy).setMLR(settingMLR,slippage);
                emitRebalanceEvent(_type);
            }
        }
    }
    function emitRebalanceEvent(rebalanceType _type)internal{
        (uint256 _collateral,uint256 _debt) = IAavePool(aavePool).getCollateralAndDebt(strategy);
        uint256 currentMLR = _debt*magnifier/_collateral;
        emit Rebalance(strategy,msg.sender,_type,settingMLR,currentMLR);
    }
}
