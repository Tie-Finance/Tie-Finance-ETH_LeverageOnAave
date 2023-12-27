// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract operatorMap is Ownable {
    mapping(address=>bool) public operator;
    event SetOperator(address operator, bool istrue);
    modifier onlyOperator() {
        require(operator[_msgSender()] == true, "NOT_OPERATOR");
        _;
    }
    /**
        Set Operator
     */
    function setOperator(address _Operator, bool _isTrue) external onlyOwner {
        require(_Operator != address(0), "INVALID_ADDRESS");
        operator[_Operator]=_isTrue;
        emit SetOperator(_Operator, _isTrue);
    }
}