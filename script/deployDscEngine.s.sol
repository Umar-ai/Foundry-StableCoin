//SPDX-License-Identifier:MIT
pragma solidity ^0.8.34;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract deployDscEngine is Script {
    address[] public tokenAddresses;
    address[] public tokenPriceFeeds;

    function run() external returns (DecentralizedStableCoin, DSCEngine) {
        HelperConfig helperConfig = new HelperConfig();
        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 deployerKey) =
            helperConfig.activeNetworkConfig();
        tokenAddresses = [weth, wbtc];
        tokenPriceFeeds = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        vm.startBroadcast(deployerKey);
        DecentralizedStableCoin decentralizedStableCoin = new DecentralizedStableCoin();
        DSCEngine dSCEngine = new DSCEngine(tokenAddresses, tokenPriceFeeds, address(decentralizedStableCoin));
        decentralizedStableCoin.transferOwnership(address(dSCEngine));
        vm.stopBroadcast();
        return (decentralizedStableCoin, dSCEngine);
    }
}
