// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
import "../interfaces/AggregatorV3Interface.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
contract STGAggregator is AggregatorV3Interface {
    IUniswapV2Pair internal sushiPair = IUniswapV2Pair(0xA34Ec05DA1E4287FA351c74469189345990a3F0C);
    AggregatorV3Interface internal usdcOracle = AggregatorV3Interface(0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7);
    function decimals() external pure returns (uint8){
        return 8;
    }
    function description() external pure returns (string memory){
        return "StargateToken Oracle";
    }
    function version() external pure returns (uint256){
        return 3;
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
        return (_roundId,getSTGPrice(),0,0,_roundId);
    }
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ){
        return getRoundData(100);
    }
    function latestAnswer() external view returns (int256){
        (,int256 answer,,,) = getRoundData(100);
        return answer;
    }
    function latestTimestamp() external view returns (uint256){
        return usdcOracle.latestTimestamp();
    }
    function latestRound() external view returns (uint256){
        return usdcOracle.latestRound();
    }
    function getAnswer(uint256 roundId) external view returns (int256){
        (,int256 answer,,,) = getRoundData(uint80(roundId));
        return answer;
    }
    function getTimestamp(uint256 roundId) external view returns (uint256){
        return usdcOracle.getTimestamp(roundId);
    }
    function getSTGPrice() internal view returns (int256){
        address usdc = sushiPair.token0();
        address stg = sushiPair.token1();
        (,int256 price,,,) = usdcOracle.latestRoundData();
        int256 balance0 = int256(IERC20(usdc).balanceOf(address(sushiPair)));
        int256 balance1 = int256(IERC20(stg).balanceOf(address(sushiPair)));
        return balance0*1e12*price/balance1;

    }
}