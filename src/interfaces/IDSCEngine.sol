// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IDSCEngine {
    error DSCEngine__ZeroAmountNotAllowed();
    error DSCEngine__InvalidCollateralToken(address token);
    error DSCEngine__TokenAndPriceFeedLengthMismatch(uint256 tokenLength, uint256 priceFeedLength);
    error DSCEngine__TransferFailed();
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorThresholdBreached(uint256 healthFactor);

    function depositCollateral(address token, uint256 amount) external;
    // function depositCollateralAndMintDsc(address token, uint256 amount) external;
    // function redeemCollateralForDsc() external;
    // function redeemCollateral() external;
    function mintDsc(uint256 amount) external;
    // function burnDsc() external;
    // function liquidate() external;
    // function getHealthFactor() external view;
}
