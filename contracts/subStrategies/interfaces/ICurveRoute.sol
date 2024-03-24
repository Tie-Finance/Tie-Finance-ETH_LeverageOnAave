// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
interface ICurveRoute {
    function exchange(
        address _pool,
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) external payable returns (uint256);
    function get_dy(
        address _pool,
        int128 i,
        int128 j,
        uint256 dx
    ) external view returns (uint256);
    function exchange_underlying(
        address _pool,
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) external payable returns (uint256);
    function get_dy_underlying(
        address _pool,
        int128 i,
        int128 j,
        uint256 dx
    ) external view returns (uint256);
    function exchange(
        address _pool,
        uint256 i,
        uint256 j,
        uint256 dx,
        uint256 min_dy,
        bool use_eth
    ) external payable returns (uint256);
    function get_dy(
        address _pool,
        uint256 i,
        uint256 j,
        uint256 dx
    ) external view returns (uint256);
}
