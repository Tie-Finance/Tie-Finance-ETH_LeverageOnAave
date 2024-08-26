pragma solidity ^0.8.0;

contract Aave {

    function setUserEMode(uint8 categoryId) external {

    }

    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external {

    }

    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external {

    }

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256) {
        return amount;
    }

    function repay(
        address asset,
        uint256 amount,
        uint256 rateMode,
        address onBehalfOf
    ) external returns (uint256) {
        return amount;
    }

    function getUserAccountData(address)
    external
    view
    returns (
        uint256 totalCollateralETH,
        uint256 totalDebtETH,
        uint256 availableBorrowsETH,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 healthFactor
    ) {
        return (0,0,0,0,0,5000);
    }

    function setUserUseReserveAsCollateral(address _reserse, bool _useAsCollateral) external {

    }
}
