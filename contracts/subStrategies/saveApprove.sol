// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract saveApprove {
    using SafeERC20 for IERC20;
    mapping(address=>mapping(address=>bool)) public approveMap;
    function approve(address token, address spender) internal {
        require(token != address(0), "INVALID_ADDRESS");
        if(!approveMap[token][spender]){
            approveMap[token][spender] = true;
            IERC20(token).safeApprove(spender,type(uint256).max);
        }
    }
}