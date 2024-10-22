
contract MockERC4626 {

    mapping(address => uint256) public shareHolders;
    address public assetToken;
    uint256 public totalAssets;
    constructor(
        address _asset
    ){
        assetToken = _asset;
    }

    function asset() external view returns (address assetTokenAddress) {
       
        return assetToken;
    }

    function totalAssets() external view returns (uint256 totalManagedAssets) {
            return 0;
    }

    function convertToShares(uint256 assets) external view returns (uint256 shares) {
        return assets;
    }
    function convertToAssets(uint256 shares) external view returns (uint256 assets) {
        return shares;
    }

    function maxDeposit(address receiver) external view returns (uint256 maxAssets) {
        return 100000e18;
    }
    function previewDeposit(uint256 assets) external view returns (uint256 shares) {
        return 100000e18;
    }
    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        return assets;
    }
    function maxMint(address receiver) external view returns (uint256 maxShares) {
        return 100000e18;
    }
    function previewMint(uint256 shares) external view returns (uint256 assets) {
        return 100000e18;
    }
    function mint(uint256 shares, address receiver) external returns (uint256 assets) {
        return shares;
    }
    function maxWithdraw(address owner) external view returns (uint256 maxAssets) {
        return 100000e18;
    }
    function previewWithdraw(uint256 assets) external view returns (uint256 shares) {
        return 100000e18;
    }
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares) {
        return assets;
    }
    function maxRedeem(address owner) external view returns (uint256 maxShares) {
        return 100000e18;
    }
    function previewRedeem(uint256 shares) external view returns (uint256 assets) {
        return 100000e18;
    }
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets) {
        return shares;
    }
}