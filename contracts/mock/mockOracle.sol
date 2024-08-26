
contract mockOracle  {
    /**
  * @notice set price of an asset
      * @dev function to set price for an asset
      * @param asset Asset for which to set the price
      * @param aggregator the Asset's aggregator
      */
    function setAssetsAggregator(address asset,address aggregator) external {

    }
    function _setAssetsAggregator(address asset,address aggregator) internal {

    }
    function getAssetsAggregator(address asset) external view returns (address) {

    }

    function getPrice(address asset) external view returns (uint256,uint8) {
            return (10**18,18);
    }
}