// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/shared/interfaces/AggregatorV3Interface.sol";

import {IDSCEngine} from "./interfaces/IDSCEngine.sol";
import {DecentralizedStablecoin} from "./DecentralizedStablecoin.sol";

/**
 * @title DSCEngine
 * @author Dhruv Takwal
 *
 * @notice This contract is the core of the DSC system. It is responsible for functionalities like minting, redeeming DSC stablecoin and depositing, withdrawing collateral.
 *
 * @dev It is very similar to MakerDAO DAI system minus the governance, fees and limited backing assets.
 * @dev The DSC system should always be overcollateralized.
 *
 */
contract DSCEngine is IDSCEngine, ReentrancyGuard {
    uint256 private constant ADDITIONAL_PRICE_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;

    mapping(address token => address priceFeed) private s_tokenToPriceFeed;
    mapping(address user => mapping(address token => uint256 amount)) s_userCollateralDepositAmount;
    mapping(address user => uint256 amount) private s_dscMinted;

    address[] private s_collateralTokens;

    DecentralizedStablecoin private immutable i_dsc;

    modifier revertOnZeroAmount(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__ZeroAmountNotAllowed();
        }
        _;
    }

    modifier revertOnInvalidCollateralToken(address token) {
        if (s_tokenToPriceFeed[token] == address(0)) {
            revert DSCEngine__InvalidCollateralToken(token);
        }
        _;
    }

    constructor(address[] memory tokens, address[] memory priceFeeds, address dscAddress) {
        if (tokens.length != priceFeeds.length) {
            revert DSCEngine__TokenAndPriceFeedLengthMismatch(tokens.length, priceFeeds.length);
        }

        for (uint256 i = 0; i < tokens.length; i++) {
            s_tokenToPriceFeed[tokens[i]] = priceFeeds[i];
            s_collateralTokens.push(tokens[i]);
        }

        i_dsc = DecentralizedStablecoin(dscAddress);
    }

    function depositCollateralAndMintDsc(address token, uint256 collateralAmount, uint256 mintAmount) external {
        depositCollateral(token, collateralAmount);
        mintDsc(mintAmount);
    }

    /**
     * @param token The address of token to deposit as collateral
     * @param amount The amount of token to deposit as collateral
     */
    function depositCollateral(address token, uint256 amount)
        public
        revertOnZeroAmount(amount)
        revertOnInvalidCollateralToken(token)
        // check if modifier is actually required
        nonReentrant
    {
        s_userCollateralDepositAmount[msg.sender][token] += amount;
        emit CollateralDeposited(msg.sender, token, amount);

        bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /**
     * @param amount The amount of DSC token to mint
     */
    function mintDsc(uint256 amount)
        public
        revertOnZeroAmount(amount)
        // check if actually required
        nonReentrant
    {
        s_dscMinted[msg.sender] += amount;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool success = i_dsc.mint(msg.sender, amount);
        if (!success) {
            revert DSCEngine__MintFailed();
        }
    }

    /**
     * @param user The address of the user for which info is required
     *
     * @return totalDscMinted The amount of DSC token minted for the `user`
     * @return totalCollateralUsdValue The amount of collateral value deposited in USD for the `user`
     */
    function _getUserInfo(address user)
        internal
        view
        returns (uint256 totalDscMinted, uint256 totalCollateralUsdValue)
    {
        totalDscMinted = s_dscMinted[user];
        totalCollateralUsdValue = getUserTotalCollateralUsdValue(user);
    }

    /**
     * @param user The address of the user for which health factor is required
     *
     * @return healthFactor The ratio of adjusted collateral value to total dsc minted
     */
    function _healthFactor(address user) internal view returns (uint256 healthFactor) {
        (uint256 totalDscMinted, uint256 totalCollateralUsdValue) = _getUserInfo(user);
        uint256 adjustedTotalCollateralUsdValue =
            totalCollateralUsdValue * LIQUIDATION_THRESHOLD / LIQUIDATION_PRECISION;

        healthFactor = totalDscMinted == 0 ? MIN_HEALTH_FACTOR : adjustedTotalCollateralUsdValue / totalDscMinted;
    }

    /**
     * @param user The address of the user for which health factor needs to be checked
     */
    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 healthFactor = _healthFactor(user);
        if (healthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorBreached(healthFactor);
        }
    }

    /**
     * @param user The address of the user for which total collateral value deposited in USD is required
     *
     * @return totalCollateralUsdValue The sum of deposited collateral token values in USD for the `user`
     */
    function getUserTotalCollateralUsdValue(address user) public view returns (uint256 totalCollateralUsdValue) {
        address[] memory collateralTokens = s_collateralTokens;
        for (uint256 i = 0; i < collateralTokens.length; i++) {
            address token = collateralTokens[i];
            uint256 depositedAmount = s_userCollateralDepositAmount[user][token];
            totalCollateralUsdValue += getUsdValue(token, depositedAmount);
        }
    }

    /**
     * @dev Calculates the USD value of a specified amount of a token, using the token's price feed.
     *
     * @param token The address of the token whose USD value is to be calculated
     * @param amount The amount of the token for which USD value is to be calculated
     *
     * @return usdValue The USD value of the specified token amount
     */
    function getUsdValue(address token, uint256 amount) public view returns (uint256 usdValue) {
        address priceFeed = s_tokenToPriceFeed[token];
        (, int256 unitUsdPrice,,,) = AggregatorV3Interface(priceFeed).latestRoundData();
        usdValue = ((uint256(unitUsdPrice) * ADDITIONAL_PRICE_FEED_PRECISION) * amount) / PRECISION;
    }

    /**
     * @dev This constant is used to adjust the precision of price feeds.
     * @return The precision factor for price feeds (1e10).
     */
    function getAdditionalPriceFeedPrecision() external pure returns (uint256) {
        return ADDITIONAL_PRICE_FEED_PRECISION;
    }

    /**
     * @dev This constant is commonly used for scaling token amounts or calculations requiring high precision.
     * @return The general precision factor for collateral USD values (1e18).
     */
    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    /**
     * @dev This constant represents the percentage used to derive the adjusted collateral value.
     * @return The liquidation threshold percentage (50).
     */
    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    /**
     * @dev This constant helps ensure the correct precision when computing liquidation-related values.
     * @return The liquidation precision factor (100).
     */
    function getLiquidationPrecision() external pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    /**
     * @dev A position with a health factor below this value is considered under-collateralized and at risk of liquidation.
     * @return The minimum health factor (1).
     */
    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    /**
     * @dev Returns the price feed address for a specific token.
     * @param token The address of the token.
     * @return The price feed address associated with the token.
     */
    function getPriceFeed(address token) external view returns (address) {
        return s_tokenToPriceFeed[token];
    }

    /**
     * @dev Returns the collateral deposit amount for a specific user and token.
     * @param user The address of the user.
     * @param token The address of the token.
     * @return The collateral deposit amount for the user and token.
     */
    function getUserCollateralDepositAmount(address user, address token) external view returns (uint256) {
        return s_userCollateralDepositAmount[user][token];
    }

    /**
     * @dev Returns the total amount of DSC minted by a specific user.
     * @param user The address of the user.
     * @return The total amount of DSC minted by the user.
     */
    function getDscMinted(address user) external view returns (uint256) {
        return s_dscMinted[user];
    }

    /**
     * @dev Returns the list of all collateral tokens.
     * @return An array of addresses representing all collateral tokens.
     */
    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    /**
     * @dev The maximum mintable DSC is determined by the user's total collateral value (adjusted by the liquidation threshold)
     *      minus the amount of DSC they have already minted.
     *      If the total collateral value is less than or equal to the DSC already minted, no more DSC can be minted.
     * @param user The address of the user for whom the maximum mintable DSC is being calculated.
     * @return maxMintAmount The maximum amount of DSC that the user can mint.
     */
    function getMaxMintableDsc(address user) external view returns (uint256 maxMintAmount) {
        (uint256 totalDscMinted, uint256 totalCollateralUsdValue) = _getUserInfo(user);
        uint256 adjustedTotalCollateralUsdValue =
            totalCollateralUsdValue * LIQUIDATION_THRESHOLD / LIQUIDATION_PRECISION;

        maxMintAmount =
            adjustedTotalCollateralUsdValue <= totalDscMinted ? 0 : adjustedTotalCollateralUsdValue - totalDscMinted - 1;
    }
}
