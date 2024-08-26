// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
import "../interfaces/AggregatorV3Interface.sol";
import "../interfaces/IWstETH.sol";
contract wstETHAggregator is AggregatorV3Interface {
    address public stEthAggregator;
    address public wstETH;
    uint256 public constant calDecimals = 1e10;
    constructor(address _stEthAggregator,address _wstETH){
        stEthAggregator = _stEthAggregator;
        wstETH = _wstETH;
    }
    function decimals() external view returns (uint8){
        return AggregatorV3Interface(stEthAggregator).decimals();
    }
    function description() external view returns (string memory) {
        return string(abi.encodePacked("Wrapped ", AggregatorV3Interface(stEthAggregator).description()));
    }
    function version() external view returns (uint256){
        return AggregatorV3Interface(stEthAggregator).version();
    }

    // getRoundData and latestRoundData should both raise "No data present"
    // if they do not have data to report, instead of returning unset values
    // which could be misinterpreted as actual reported values.
    function getRoundData(uint80 _roundId)public view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ){
        (roundId,answer,startedAt,updatedAt,answeredInRound) = AggregatorV3Interface(stEthAggregator).getRoundData(_roundId);
        answer = getWstEthPrice(answer);
    }
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ){
        (roundId,answer,startedAt,updatedAt,answeredInRound) = AggregatorV3Interface(stEthAggregator).latestRoundData();
        answer = getWstEthPrice(answer);
    }
    function latestAnswer() external view returns (int256){
        return getWstEthPrice(AggregatorV3Interface(stEthAggregator).latestAnswer());
    }
    function latestTimestamp() external view returns (uint256){
        return AggregatorV3Interface(stEthAggregator).latestTimestamp();
    }
    function latestRound() external view returns (uint256){
        return AggregatorV3Interface(stEthAggregator).latestRound();
    }
    function getAnswer(uint256 roundId) external view returns (int256){
        return getWstEthPrice(AggregatorV3Interface(stEthAggregator).getAnswer(roundId));
    }
    function getTimestamp(uint256 roundId) external view returns (uint256){
        return AggregatorV3Interface(stEthAggregator).getTimestamp(roundId);
    }
    function getWstEthPrice(int256 _stEthPrice) internal view returns (int256){
        uint256 _stAmount = IWstETH(wstETH).getStETHByWstETH(calDecimals);
        return _stEthPrice * int256(_stAmount) / int256(calDecimals);
    }
}