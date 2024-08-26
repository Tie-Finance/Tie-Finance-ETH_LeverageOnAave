pragma solidity ^0.8.0;

contract AavePool {
    address aaveAddr;
    mapping(address => uint256) private _balances;

    constructor(address _aaveMock ) {  
        aaveAddr = _aaveMock;
    }

    function deposit(address asset,uint256 amount)external {
        _balances[msg.sender] += amount;
    }

    function aave() external view returns (address) {
        return aaveAddr;
    }

    function convertAmount(address _tokenIn,address _tokenOut,uint256 _amount) external view returns (uint256) {
    }

    function getCollateral(address _user) external view returns (uint256) {
        return _balances[_user] ;
    }

    function getDebt(address _user) external view returns (uint256) {
        return 0;
    }

    function getCollateralAndDebt(address _user)external view returns (uint256 _collateral, uint256 _debt) {
        return (_balances[_user] ,0);
    }
    function getCollateralMaxWithdraw(address _user) external view returns (uint256) {

    }

    function getCollateralTo(address _user,address _token) external view returns (uint256) {
        return _balances[_user] ;
    }
    function getDebtTo(address _user,address _token) external view returns (uint256) {
        0;
    }
    function getCollateralAndDebtTo(address _user,address _token)external view returns (uint256 _collateral, uint256 _debt) {

    }

    function getCollateralMaxWithdrawTo(address _user,address _token) external view returns (uint256) {

    }

}


