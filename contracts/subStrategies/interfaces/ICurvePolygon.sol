// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICurvePolygon {
    function get_dy(
        uint256 i,
        uint256 j,
        uint256 dx
    ) external view returns (uint256);
    function exchange(
        uint256 i,
        uint256 j,
        uint256 dx,
        uint256 min_dy,
        bool use_eth
    ) external payable returns (uint256);
}
