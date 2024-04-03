// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUniExchange {
    function univ3Router() external view returns (address);

    // UniV3 Fee
    function univ3Fee() external view returns (uint24);
}
