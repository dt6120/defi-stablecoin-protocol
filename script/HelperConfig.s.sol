// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address weth;
        address wbtc;
        uint256 deployerKey;
    }

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 3200;
    int256 public constant BTC_USD_PRICE = 71000;

    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant AMOY_CHAIN_ID = 80002;
    uint256 public constant ETHEREUM_CHAIN_ID = 1;
    uint256 public constant POLYGON_CHAIN_ID = 137;
    uint256 public constant ARBITRUM_CHAIN_ID = 42161;

    uint256 public constant DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == SEPOLIA_CHAIN_ID) {
            activeNetworkConfig = getSepoliaConfig();
        } else if (block.chainid == AMOY_CHAIN_ID) {
            activeNetworkConfig = getAmoyConfig();
        } else if (block.chainid == ETHEREUM_CHAIN_ID) {
            activeNetworkConfig = getEthereumConfig();
        } else if (block.chainid == POLYGON_CHAIN_ID) {
            activeNetworkConfig = getPolygonConfig();
        } else if (block.chainid == ARBITRUM_CHAIN_ID) {
            activeNetworkConfig = getArbitrumConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.weth != address(0)) {
            return activeNetworkConfig;
        }

        vm.broadcast();
        NetworkConfig memory config = NetworkConfig({
            wethUsdPriceFeed: address(new MockV3Aggregator(DECIMALS, ETH_USD_PRICE)),
            wbtcUsdPriceFeed: address(new MockV3Aggregator(DECIMALS, BTC_USD_PRICE)),
            weth: address(new ERC20Mock()),
            wbtc: address(new ERC20Mock()),
            deployerKey: DEFAULT_ANVIL_KEY
        });

        return config;
    }

    function getSepoliaConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wbtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            weth: 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9,
            wbtc: 0x92f3B59a79bFf5dc60c0d59eA13a44D082B2bdFC,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getAmoyConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            wethUsdPriceFeed: 0xF0d50568e3A7e8259E16663972b11910F89BD8e7,
            wbtcUsdPriceFeed: 0xe7656e23fE8077D438aEfbec2fAbDf2D8e070C4f,
            weth: 0x52eF3d68BaB452a294342DC3e5f464d7f610f72E,
            wbtc: 0xD0b33a7aCb9303D9FE2de7ba849ec9b96A4C10C1,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getArbitrumConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            wethUsdPriceFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
            wbtcUsdPriceFeed: 0x6ce185860a4963106506C203335A2910413708e9,
            weth: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
            wbtc: 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getEthereumConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            wethUsdPriceFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419,
            wbtcUsdPriceFeed: 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c,
            weth: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            wbtc: 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getPolygonConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            wethUsdPriceFeed: 0xF9680D99D6C9589e2a93a78A04A279e509205945,
            wbtcUsdPriceFeed: 0xc907E116054Ad103354f2D350FD2514433D57F6f,
            weth: 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619,
            wbtc: 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }
}
