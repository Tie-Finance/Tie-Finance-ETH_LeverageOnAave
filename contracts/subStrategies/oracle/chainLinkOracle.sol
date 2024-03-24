// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
import "../interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
contract chainLinkOracle is Ownable {
    mapping(address => AggregatorV3Interface) internal assetsMap;
    event SetAssetsAggregator(address indexed sender,address asset,address aggregator);
        /**
      * @notice set price of an asset
      * @dev function to set price for an asset
      * @param asset Asset for which to set the price
      * @param aggregator the Asset's aggregator
      */    
    function setAssetsAggregator(address asset,address aggregator) external onlyOwner {
        _setAssetsAggregator(asset,aggregator);
    }
    function _setAssetsAggregator(address asset,address aggregator) internal {
        assetsMap[asset] = AggregatorV3Interface(aggregator);
        emit SetAssetsAggregator(msg.sender,asset,aggregator);
    }
    function getAssetsAggregator(address asset) external view returns (address) {
        return (address(assetsMap[asset]));
    }
    function getPrice(address asset) external view returns (uint256,uint8) {
        AggregatorV3Interface assetsPrice = assetsMap[asset];
        require(address(assetsPrice) != address(0),"ZERO_AGGREGATOR");
        (, int price,,,) = assetsPrice.latestRoundData();
        return (uint256(price),assetsPrice.decimals());
    }
}