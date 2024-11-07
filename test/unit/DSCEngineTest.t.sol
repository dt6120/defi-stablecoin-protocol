// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig, MockV3Aggregator} from "../../script/HelperConfig.s.sol";

import {IDSCEngine, DecentralizedStablecoin} from "../../src/DSCEngine.sol";

contract DSCEngineTest is Test {
    DecentralizedStablecoin dsc;
    IDSCEngine engine;
    HelperConfig helperConfig;

    address wethUsdPriceFeed;
    address wbtcUsdPriceFeed;
    address weth;
    address wbtc;

    address USER = makeAddr("user");
    address LIQUIDATOR = makeAddr("liquidator");
    uint256 STARTING_ERC20_BALANCE = 100e18;
    uint256 STARTING_DSC_BALANCE = 10e6 * 10e18;
    uint256 MIN_AMOUNT_BOUND = 1;

    modifier dealAndApproveTokenBalance() {
        _;
        deal(weth, USER, STARTING_ERC20_BALANCE, true);
        deal(wbtc, USER, STARTING_ERC20_BALANCE, true);
        deal(address(dsc), LIQUIDATOR, STARTING_DSC_BALANCE, true);

        vm.startPrank(USER);
        IERC20(weth).approve(address(engine), type(uint256).max);
        IERC20(wbtc).approve(address(engine), type(uint256).max);
        dsc.approve(address(engine), type(uint256).max);
        vm.stopPrank();

        vm.prank(LIQUIDATOR);
        dsc.approve(address(engine), type(uint256).max);
    }

    modifier depositCollateralAndMintDsc(address token) {
        vm.startPrank(USER);
        engine.depositCollateral(token, STARTING_ERC20_BALANCE);
        uint256 mintAmount = engine.getAdjustedCollateralUsdValue(token, STARTING_ERC20_BALANCE);
        engine.mintDsc(mintAmount);
        vm.stopPrank();
        _;
    }

    function setUp() public dealAndApproveTokenBalance {
        (dsc, engine, helperConfig) = (new DeployDSC()).run();

        (wethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc,) = helperConfig.activeNetworkConfig();
    }

    function test_dscOwnerIsEngine() public view {
        assertEq(dsc.owner(), address(engine));
    }

    function test_getUsdValue(uint64 amount) public view {
        address token = amount % 2 == 0 ? weth : wbtc;
        int256 unitUsdPrice = token == weth ? helperConfig.MOCK_ETH_USD_PRICE() : helperConfig.MOCK_BTC_USD_PRICE();
        uint256 expectedUsdValue =
            amount * uint256(unitUsdPrice) * engine.getAdditionalPriceFeedPrecision() / engine.getPrecision();
        uint256 actualUsdValue = engine.getUsdValue(token, amount);

        assertEq(expectedUsdValue, actualUsdValue);
    }

    function test_getTokenAmountFromUsdValue(uint64 amount) public view {
        address token = amount % 2 == 0 ? weth : wbtc;
        int256 unitUsdPrice = token == weth ? helperConfig.MOCK_ETH_USD_PRICE() : helperConfig.MOCK_BTC_USD_PRICE();
        uint256 expectedValue =
            amount * engine.getPrecision() / (uint256(unitUsdPrice) * engine.getAdditionalPriceFeedPrecision());
        uint256 actualValue = engine.getTokenAmountFromUsdValue(token, amount);

        assertEq(actualValue, expectedValue);
    }

    function test_getUserTotalCollateralUsdValue() public depositCollateralAndMintDsc(weth) {
        uint256 totalCollateralUsdValue = engine.getUserTotalCollateralUsdValue(USER);
        (, int256 unitUsdPrice,,,) = MockV3Aggregator(wethUsdPriceFeed).latestRoundData();
        uint256 expectedUsdValue = STARTING_ERC20_BALANCE * uint256(unitUsdPrice)
            * engine.getAdditionalPriceFeedPrecision() / engine.getPrecision();

        assertEq(totalCollateralUsdValue, expectedUsdValue);
    }

    function test_getAdditionalPriceFeedPrecision() public view {
        assertGt(engine.getAdditionalPriceFeedPrecision(), 0);
    }

    function test_getPrecision() public view {
        assertGt(engine.getPrecision(), 0);
    }

    function test_getLiquidationThreshold() public view {
        assertGt(engine.getLiquidationThreshold(), 0);
    }

    function test_getLiquidationPrecisionn() public view {
        assertGt(engine.getLiquidationPrecision(), 0);
    }

    function test_getMinHealthFactor() public view {
        assertGt(engine.getMinHealthFactor(), 0);
    }

    function test_getPriceFeed() public view {
        assertNotEq(engine.getPriceFeed(weth), address(0));
        assertNotEq(engine.getPriceFeed(wbtc), address(0));
    }

    function test_getUserCollateralDepositAmount() public depositCollateralAndMintDsc(weth) {
        assertEq(engine.getUserCollateralDepositAmount(USER, weth), STARTING_ERC20_BALANCE);
    }

    function test_getDscMinted() public depositCollateralAndMintDsc(weth) {
        uint256 mintAmount = engine.getAdjustedCollateralUsdValue(weth, STARTING_ERC20_BALANCE);
        assertEq(engine.getDscMinted(USER), mintAmount);
    }

    function test_getCollateralTokens() public view {
        assertGt(engine.getCollateralTokens().length, 0);
    }

    function test_getMaxMintableDsc() public depositCollateralAndMintDsc(weth) {
        assertEq(engine.getMaxMintableDsc(USER), 0);
    }

    function test_getHealthFactor() public depositCollateralAndMintDsc(weth) {
        assertGe(engine.getHealthFactor(USER), engine.getMinHealthFactor());
    }

    function test_getUserInfo() public depositCollateralAndMintDsc(weth) {
        (uint256 totalDscMinted, uint256 totalCollateralUsdValue) = engine.getUserInfo(USER);
        assertGt(totalDscMinted, 0);
        assertGt(totalCollateralUsdValue, 0);
    }

    function test_depositRevertsOnZeroAmount() public {
        uint256 amount = 0;

        vm.expectRevert(IDSCEngine.DSCEngine__ZeroAmountNotAllowed.selector);

        vm.prank(USER);
        engine.depositCollateral(weth, amount);
    }

    function test_depositRevertsOnInvalidCollateralToken(address token) public {
        vm.assume(token != weth && token != wbtc);
        uint256 amount = 10e18;

        vm.expectRevert(abi.encodeWithSelector(IDSCEngine.DSCEngine__InvalidCollateralToken.selector, token));

        vm.prank(USER);
        engine.depositCollateral(token, amount);
    }

    function test_depositCollateral(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT_BOUND, STARTING_ERC20_BALANCE);
        address token = amount % 2 == 0 ? weth : wbtc;

        uint256 startingCollateralDepositAmount = engine.getUserCollateralDepositAmount(USER, token);
        uint256 startingEngineTokenBalance = IERC20(token).balanceOf(address(engine));

        vm.expectEmit(true, true, true, true, address(engine));
        emit IDSCEngine.CollateralDeposited(USER, token, amount);

        vm.expectEmit(true, true, true, true, token);
        emit IERC20.Transfer(USER, address(engine), amount);

        vm.prank(USER);
        engine.depositCollateral(token, amount);

        uint256 endingCollateralDepositAmount = engine.getUserCollateralDepositAmount(USER, token);
        uint256 endingEngineTokenBalance = IERC20(token).balanceOf(address(engine));

        assertEq(endingCollateralDepositAmount - startingCollateralDepositAmount, amount);
        assertEq(endingEngineTokenBalance - startingEngineTokenBalance, amount);
        assertEq(engine.getDscMinted(USER), 0);
    }

    function test_mintRevertsOnZeroAmount() public {
        uint256 amount = 0;

        vm.expectRevert(IDSCEngine.DSCEngine__ZeroAmountNotAllowed.selector);

        vm.prank(USER);
        engine.mintDsc(amount);
    }

    function test_mintRevertsOnZeroDeposit(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT_BOUND, type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(IDSCEngine.DSCEngine__HealthFactorBreached.selector, 0));

        vm.prank(USER);
        engine.mintDsc(amount);
    }

    function test_mintRevertsIfAmountBreaksHealthFactor(uint256 collateralAmount) public {
        address token = collateralAmount % 2 == 0 ? weth : wbtc;

        collateralAmount = bound(collateralAmount, MIN_AMOUNT_BOUND, STARTING_ERC20_BALANCE);

        vm.startPrank(USER);
        engine.depositCollateral(token, collateralAmount);

        uint256 maxMintableAmount = engine.getMaxMintableDsc(USER);
        uint256 extraFactor = 2;

        vm.expectRevert(
            abi.encodeWithSelector(
                IDSCEngine.DSCEngine__HealthFactorBreached.selector, engine.getMinHealthFactor() / extraFactor
            )
        );
        engine.mintDsc(maxMintableAmount * extraFactor);
        vm.stopPrank();
    }

    function test_mintDsc(uint256 collateralAmount, uint256 mintAmount) public {
        address token = collateralAmount % 2 == 0 ? weth : wbtc;

        collateralAmount = bound(collateralAmount, MIN_AMOUNT_BOUND, STARTING_ERC20_BALANCE);

        vm.startPrank(USER);
        engine.depositCollateral(token, collateralAmount);

        uint256 maxMintableAmount = engine.getMaxMintableDsc(USER);
        mintAmount = maxMintableAmount > 0 ? bound(mintAmount, MIN_AMOUNT_BOUND, maxMintableAmount) : 0;

        if (mintAmount == 0) return;

        vm.expectEmit(true, true, true, true, address(dsc));
        emit IERC20.Transfer(address(0), USER, mintAmount);

        engine.mintDsc(mintAmount);
        vm.stopPrank();
    }

    function test_depositCollateralAndMintDsc(uint256 collateralAmount) public {
        address token = collateralAmount % 2 == 0 ? weth : wbtc;

        collateralAmount = bound(collateralAmount, MIN_AMOUNT_BOUND, STARTING_ERC20_BALANCE);
        uint256 mintAmount = engine.getAdjustedCollateralUsdValue(token, collateralAmount);

        vm.expectEmit(true, true, true, true, address(engine));
        emit IDSCEngine.CollateralDeposited(USER, token, collateralAmount);

        vm.expectEmit(true, true, true, true, token);
        emit IERC20.Transfer(USER, address(engine), collateralAmount);

        vm.expectEmit(true, true, true, true, address(dsc));
        emit IERC20.Transfer(address(0), USER, mintAmount);

        vm.prank(USER);
        engine.depositCollateralAndMintDsc(token, collateralAmount, mintAmount);

        (uint256 totalDscMinted, uint256 totalCollateralUsdValue) = engine.getUserInfo(USER);

        assertEq(totalDscMinted, mintAmount);
        assertEq(totalCollateralUsdValue, engine.getUsdValue(token, collateralAmount));
    }

    function test_redeemRevertsOnZeroAmount() public {
        address token = uint256(keccak256(abi.encode(msg.sender, block.timestamp))) % 2 == 0 ? weth : wbtc;
        uint256 amount = 0;

        vm.expectRevert(IDSCEngine.DSCEngine__ZeroAmountNotAllowed.selector);

        vm.prank(USER);
        engine.redeemCollateral(token, amount);
    }

    function test_redeemRevertsOnInvalidCollateralToken(address token) public {
        vm.assume(token != weth && token != wbtc);
        uint256 amount = 10e18;

        vm.expectRevert(abi.encodeWithSelector(IDSCEngine.DSCEngine__InvalidCollateralToken.selector, token));

        vm.prank(USER);
        engine.redeemCollateral(token, amount);
    }

    function test_redeemRevertsIfHealthFactorBreaks(uint256 amount) public depositCollateralAndMintDsc(weth) {
        amount = bound(amount, MIN_AMOUNT_BOUND, STARTING_ERC20_BALANCE);

        vm.expectRevert();

        vm.prank(USER);
        engine.redeemCollateral(weth, amount);
    }

    function test_redeemCollateralForDscRevertsIfHealthFactorBreaks(uint256 amount)
        public
        depositCollateralAndMintDsc(weth)
    {
        amount = bound(amount, MIN_AMOUNT_BOUND, STARTING_ERC20_BALANCE);
        uint256 adjustedCollateralUsdAmount = engine.getAdjustedCollateralUsdValue(weth, amount);

        vm.expectRevert();

        vm.prank(USER);
        engine.redeemCollateralForDsc(weth, amount, adjustedCollateralUsdAmount - 1);
    }

    function test_redeemCollateralForDsc(uint256 amount) public depositCollateralAndMintDsc(weth) {
        amount = bound(amount, MIN_AMOUNT_BOUND, STARTING_ERC20_BALANCE);
        uint256 adjustedCollateralUsdAmount = engine.getAdjustedCollateralUsdValue(weth, amount);

        vm.prank(USER);
        engine.redeemCollateralForDsc(weth, amount, adjustedCollateralUsdAmount);
    }

    function test_burnDscRevertsOnZeroAmount() public {
        uint256 amount = 0;

        vm.expectRevert(IDSCEngine.DSCEngine__ZeroAmountNotAllowed.selector);

        vm.prank(USER);
        engine.burnDsc(amount);
    }

    function test_burnDsc(uint256 amount) public depositCollateralAndMintDsc(weth) {
        amount = bound(amount, MIN_AMOUNT_BOUND, engine.getDscMinted(USER));

        vm.prank(USER);
        engine.burnDsc(amount);
    }

    function test_liquidateRevertsOnZeroAmount() public depositCollateralAndMintDsc(weth) {
        uint256 amount = 0;

        vm.expectRevert(IDSCEngine.DSCEngine__ZeroAmountNotAllowed.selector);

        vm.prank(LIQUIDATOR);
        engine.liquidate(USER, weth, amount);
    }

    function test_liquidateRevertsIfHealthFactorOkay(uint256 amount) public depositCollateralAndMintDsc(weth) {
        amount = bound(amount, MIN_AMOUNT_BOUND, STARTING_ERC20_BALANCE);

        MockV3Aggregator aggregator = MockV3Aggregator(wethUsdPriceFeed);
        (, int256 unitUsdPrice,,,) = aggregator.latestRoundData();
        aggregator.updateAnswer(unitUsdPrice * 2);

        uint256 healthFactor = engine.getHealthFactor(USER);

        vm.expectRevert(abi.encodeWithSelector(IDSCEngine.DSCEngine__HealthFactorNotBreached.selector, healthFactor));

        vm.prank(LIQUIDATOR);
        engine.liquidate(USER, weth, amount);
    }

    function test_liquidate(uint256 amount) public depositCollateralAndMintDsc(weth) {
        uint256 dscMinted = engine.getDscMinted(USER);
        amount = bound(amount, MIN_AMOUNT_BOUND, dscMinted);

        MockV3Aggregator aggregator = MockV3Aggregator(wethUsdPriceFeed);
        (, int256 unitUsdPrice,,,) = aggregator.latestRoundData();
        aggregator.updateAnswer(unitUsdPrice - 200e8);
        // aggregator.updateAnswer(unitUsdPrice / 3);

        vm.prank(LIQUIDATOR);
        engine.liquidate(USER, weth, amount);
    }
}
