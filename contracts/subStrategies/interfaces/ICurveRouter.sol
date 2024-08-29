// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
interface ICurveRouter {
    function exchange(address[11] calldata _route,uint256[5][5] calldata _swap_params,uint256 _amount,uint256 _min_dy)payable  external returns (uint256);
    function exchange(address[11] calldata _route,uint256[5][5] calldata _swap_params,uint256 _amount,uint256 _min_dy,address[5] calldata _pools) payable external returns (uint256);
    function exchange(address[11] calldata _route,uint256[5][5] calldata _swap_params,uint256 _amount,uint256 _min_dy,address[5] calldata _pools,address _receiver)payable  external returns (uint256);
    function get_dy(address[11] calldata _route,uint256[5][5] calldata _swap_params,uint256 _amount)external view returns(uint256);
    function get_dy(address[11] calldata _route,uint256[5][5] calldata _swap_params,uint256 _amount,address[5] calldata _pools)external view returns(uint256);
    function get_dx(address[11] calldata _route,uint256[5][5] calldata _swap_params,uint256 _amount,address[5] calldata _pools)external view returns(uint256);
    function get_dx(address[11] calldata _route,uint256[5][5] calldata _swap_params,uint256 _amount,address[5] calldata _pools,address[5] calldata _base_pools)external view returns(uint256);
    function get_dx(address[11] calldata _route,uint256[5][5] calldata _swap_params,uint256 _amount,address[5] calldata _pools,address[5] calldata _base_pools,address[5] calldata _base_tokens)external view returns(uint256);
}