pragma solidity ^0.8.0;

interface IcallBack {
    function loanFallback(
        uint256 loanAmt,
        uint256 feeAmt,
        bytes calldata userData
    ) external;
}

contract FlashloanReceiver {

    function getFee() external view returns (uint256 fee){
        return 10000;
    }

    function flashLoan(address token, uint256 amount,bytes calldata userData) external {
        IcallBack(msg.sender).loanFallback(amount,0,userData);
        return;
    }
}
