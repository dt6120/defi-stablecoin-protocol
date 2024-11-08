// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig, MockV3Aggregator} from "../../script/HelperConfig.s.sol";

import {IDSCEngine, DecentralizedStablecoin} from "../../src/DSCEngine.sol";

contract Handler is Test {
    uint8 MIN_BOUND_AMOUNT = 1;
    uint96 MAX_DEPOSIT_AMOUNT = type(uint96).max;

    DecentralizedStablecoin dsc;
    IDSCEngine engine;

    address[] tokens;
    address weth;
    address wbtc;

    constructor(address _dsc, address _engine) {
        dsc = DecentralizedStablecoin(_dsc);
        engine = IDSCEngine(_engine);

        tokens = engine.getCollateralTokens();
        weth = tokens[0];
        wbtc = tokens[1];
    }

    function depositCollateral(uint256 collateralSeed, uint256 collateralAmount) public {
        collateralAmount = bound(collateralAmount, MIN_BOUND_AMOUNT, MAX_DEPOSIT_AMOUNT);
        address token = _getCollateralFromSeed(collateralSeed);

        deal(token, msg.sender, collateralAmount, true);
        vm.startPrank(msg.sender);
        IERC20(token).approve(address(engine), collateralAmount);
        engine.depositCollateral(token, collateralAmount);
        vm.stopPrank();
    }

    function mintDsc(uint256 amount) public {
        uint256 currentMintAmount = engine.getDscMinted(msg.sender);
        uint256 adjustedCollateralUsdValue = _getUserAdjustedTotalCollateralUsdValue(msg.sender);

        uint256 mintAmount =
            adjustedCollateralUsdValue > currentMintAmount ? adjustedCollateralUsdValue - currentMintAmount : 0;

        vm.assume(mintAmount != 0);
        amount = bound(amount, MIN_BOUND_AMOUNT, mintAmount);

        vm.prank(msg.sender);
        engine.mintDsc(mintAmount);
    }

    function redeemCollateral(uint256 collateralSeed, uint256 redeemAmount) public {
        address token = _getCollateralFromSeed(collateralSeed);
        uint256 currentAdjustedCollateralUsdValue = _getUserAdjustedTotalCollateralUsdValue(msg.sender);
        uint256 currentMintedDsc = engine.getDscMinted(msg.sender);
        uint256 allowableUsdRedeemAmount = currentAdjustedCollateralUsdValue - currentMintedDsc;
        uint256 maxRedeemAmount = engine.getTokenAmountFromUsdValue(token, allowableUsdRedeemAmount);

        vm.assume(maxRedeemAmount >= MIN_BOUND_AMOUNT);
        redeemAmount = bound(redeemAmount, MIN_BOUND_AMOUNT, maxRedeemAmount);

        vm.prank(msg.sender);
        engine.redeemCollateral(token, redeemAmount);
    }

    function burnDsc(uint256 amount) public {
        uint256 dscMinted = engine.getDscMinted(msg.sender);
        vm.assume(dscMinted != 0);

        amount = bound(amount, MIN_BOUND_AMOUNT, dscMinted);

        vm.startPrank(msg.sender);
        dsc.approve(address(engine), amount);
        engine.burnDsc(amount);
        vm.stopPrank();
    }

    // function updateCollateralPrice(uint256 seed, uint96 price) public {
    //     address token = _getCollateralFromSeed(seed);
    //     MockV3Aggregator(engine.getPriceFeed(token)).updateAnswer(int256(uint256(price)));
    // }

    function _getCollateralFromSeed(uint256 seed) private view returns (address token) {
        token = tokens[seed % tokens.length];
    }

    function _getUserAdjustedTotalCollateralUsdValue(address user) private view returns (uint256 adjustedAmount) {
        uint256 totalCollateralUsdValue = engine.getUserTotalCollateralUsdValue(user);
        return engine.getAdjustedUsdValue(totalCollateralUsdValue);
    }
}
