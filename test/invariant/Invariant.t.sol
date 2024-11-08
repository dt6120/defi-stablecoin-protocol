// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig, MockV3Aggregator} from "../../script/HelperConfig.s.sol";
import {Handler} from "./Handler.t.sol";

import {IDSCEngine, DecentralizedStablecoin} from "../../src/DSCEngine.sol";

contract DSCEngineInvariantTest is StdInvariant, Test {
    DecentralizedStablecoin dsc;
    IDSCEngine engine;
    HelperConfig helperConfig;

    Handler handler;

    address weth;
    address wbtc;

    function setUp() public {
        (dsc, engine, helperConfig) = (new DeployDSC()).run();
        (,, weth, wbtc,) = helperConfig.activeNetworkConfig();

        handler = new Handler(address(dsc), address(engine));

        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = Handler.depositCollateral.selector;
        selectors[1] = Handler.mintDsc.selector;
        selectors[2] = Handler.redeemCollateral.selector;
        selectors[3] = Handler.burnDsc.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    function invariant_protocolCollateralValueMoreThanDscMinted() public view {
        uint256 totalDscMinted = dsc.totalSupply();

        uint256 wethBalance = IERC20(weth).balanceOf(address(engine));
        uint256 wbtcBalance = IERC20(wbtc).balanceOf(address(engine));

        uint256 wethUsdBalance = engine.getUsdValue(weth, wethBalance);
        uint256 wbtcUsdBalance = engine.getUsdValue(wbtc, wbtcBalance);
        uint256 totalCollateralUsdValue = wethUsdBalance + wbtcUsdBalance;

        assertGe(totalCollateralUsdValue, totalDscMinted);
    }

    function invariant_gettersShouldNotRevert() public view {
        engine.getAdditionalPriceFeedPrecision();
        // engine.getAdjustedCollateralUsdValue(token, amount);
        // engine.getAdjustedUsdValue(amount);
        engine.getCollateralTokens();
        engine.getDscMinted(msg.sender);
        engine.getHealthFactor(msg.sender);
        engine.getLiquidationPrecision();
        engine.getLiquidationThreshold();
        engine.getMaxMintableDsc(msg.sender);
        engine.getMinHealthFactor();
        engine.getPrecision();
        // engine.getPriceFeed(token);
        // engine.getTokenAmountFromUsdValue(token, amount);
        // engine.getUsdValue(token, amount);
        // engine.getUserCollateralDepositAmount(msg.sender, token);
        engine.getUserInfo(msg.sender);
        engine.getUserTotalCollateralUsdValue(msg.sender);
    }
}
