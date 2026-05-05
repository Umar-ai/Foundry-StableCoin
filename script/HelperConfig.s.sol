//SPDX-License-Identifier:MIT
pragma solidity ^0.8.34;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/mockV3Aggregator.sol";
import {ERC20Mock} from "../test/mocks/ERC20Mock.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address weth;
        address wbtc;
        uint256 deployerKey;
    }

    NetworkConfig public activeNetworkConfig;
    uint8 private constant DECIMALS = 8;
    int256 private constant ETH_USD = 2000e8;
    int256 private constant BTC_USD = 1000e8;
    uint256 private constant DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory sepoliaNetworkConfig) {
        sepoliaNetworkConfig = NetworkConfig({
            wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306, // ETH / USD
            wbtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory anvilNetworkConfig) {
        if (activeNetworkConfig.wethUsdPriceFeed != address(0)) {
            return activeNetworkConfig;
        }
        vm.startBroadcast();
        MockV3Aggregator ethUsdAggregator = new MockV3Aggregator(DECIMALS, ETH_USD);
        ERC20Mock wethMock = new ERC20Mock("weth", "weth", msg.sender, 1000e8);
        MockV3Aggregator btcUsdAggregator = new MockV3Aggregator(DECIMALS, BTC_USD);
        ERC20Mock wbtcMock = new ERC20Mock("wbtc", "wbtc", msg.sender, 1000e8);

        anvilNetworkConfig = NetworkConfig({
            wethUsdPriceFeed: address(ethUsdAggregator),
            wbtcUsdPriceFeed: address(btcUsdAggregator),
            weth: address(wethMock),
            wbtc: address(wbtcMock),
            deployerKey: DEFAULT_ANVIL_KEY
        });
        vm.stopBroadcast();
    }
}
