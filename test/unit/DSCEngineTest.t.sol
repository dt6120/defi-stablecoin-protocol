// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

import {IDSCEngine, DecentralizedStablecoin} from "../../src/DSCEngine.sol";

contract DSCEngineTest is Test {
    DecentralizedStablecoin dsc;
    IDSCEngine engine;
    HelperConfig helperConfig;

    address weth;
    address wbtc;

    address USER = makeAddr("user");
    uint256 STARTING_ERC20_BALANCE = 1000e18;
    uint256 MIN_AMOUNT_BOUND = 1;

    modifier dealAndApproveTokenBalance() {
        _;
        deal(weth, USER, STARTING_ERC20_BALANCE, true);
        deal(wbtc, USER, STARTING_ERC20_BALANCE, true);

        vm.startPrank(USER);
        IERC20(weth).approve(address(engine), type(uint256).max);
        IERC20(wbtc).approve(address(engine), type(uint256).max);
        vm.stopPrank();
    }

    modifier depositCollateral(address token, uint256 amount) {
        engine.depositCollateral(token, amount);
        _;
    }

    function setUp() public dealAndApproveTokenBalance {
        (dsc, engine, helperConfig) = (new DeployDSC()).run();

        (,, weth, wbtc,) = helperConfig.activeNetworkConfig();
    }

    function test_dscOwnerIsEngine() public view {
        assertEq(dsc.owner(), address(engine));
    }

    function test_getUsdValue() public view {
        uint256 ethAmount = 3e18;
        uint256 expectedUsdValue = ethAmount * uint256(helperConfig.MOCK_ETH_USD_PRICE())
            * engine.getAdditionalPriceFeedPrecision() / engine.getPrecision();
        uint256 actualUsdValue = engine.getUsdValue(weth, ethAmount);

        assertEq(expectedUsdValue, actualUsdValue);
    }

    function test_depositRevertsOnZeroAmount() public {
        uint256 amount = 0;

        vm.expectRevert(IDSCEngine.DSCEngine__ZeroAmountNotAllowed.selector);

        vm.prank(USER);
        engine.depositCollateral(weth, amount);
    }

    function test_depositRevertsOnInvalidCollateralToken() public {
        address token = makeAddr("random-token");
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

    function test_mintDsc(uint256 collateralAmount, uint256 mintAmount) public {
        address token = collateralAmount % 2 == 0 ? weth : wbtc;

        collateralAmount = bound(collateralAmount, MIN_AMOUNT_BOUND, STARTING_ERC20_BALANCE);

        vm.startPrank(USER);
        engine.depositCollateral(token, collateralAmount);

        uint256 maxMintableAmount = engine.getMaxMintableDsc(USER);
        mintAmount = maxMintableAmount > 0 ? bound(mintAmount, MIN_AMOUNT_BOUND, maxMintableAmount) : 0;

        if (mintAmount == 0) return;

        engine.mintDsc(mintAmount);
    }
}
