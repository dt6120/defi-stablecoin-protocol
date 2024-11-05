// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IDSCEngine {
    error DSCEngine__ZeroAmountNotAllowed();
    error DSCEngine__InvalidCollateralToken(address token);
    error DSCEngine__TokenAndPriceFeedLengthMismatch(uint256 tokenLength, uint256 priceFeedLength);
    error DSCEngine__TransferFailed();
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorBreached(uint256 healthFactor);

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    function depositCollateral(address token, uint256 amount) external;
    function depositCollateralAndMintDsc(address token, uint256 collateralAmount, uint256 mintAmount) external;
    // function redeemCollateralForDsc() external;
    // function redeemCollateral() external;
    function mintDsc(uint256 amount) external;
    // function burnDsc() external;
    // function liquidate() external;
    // function getHealthFactor() external view;
    function getUserTotalCollateralUsdValue(address user) external view returns (uint256);
    function getUsdValue(address token, uint256 amount) external view returns (uint256);
    function getLiquidationThreshold() external pure returns (uint256);
    function getAdditionalPriceFeedPrecision() external pure returns (uint256);
    function getPrecision() external pure returns (uint256);
    function getLiquidationPrecision() external pure returns (uint256);
    function getMinHealthFactor() external pure returns (uint256);
    function getPriceFeed(address token) external view returns (address);
    function getUserCollateralDepositAmount(address user, address token) external view returns (uint256);
    function getDscMinted(address user) external view returns (uint256);
    function getCollateralTokens() external view returns (address[] memory);
    function getMaxMintableDsc(address user) external view returns (uint256);
}
