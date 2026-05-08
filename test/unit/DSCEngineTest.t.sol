//SPDX-License-Identifier:MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {DeployDscEngine} from "../../script/DeployDscEngine.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    uint256 private constant AMOUNT_COLLATERAL = 5 ether;
    uint256 private constant AMOUNT_MINTED = 10 ether;
    DSCEngine engine;
    DecentralizedStableCoin dsc;
    HelperConfig helperConfig;
    address wethUsdPriceFeed;
    address wbtcUsdPriceFeed;
    address weth;
    address wbtc;
    uint256 deployerKey;
    address USER = makeAddr("user");

    function setUp() public {
        DeployDscEngine deployDscEngine = new DeployDscEngine();
        (dsc, engine, helperConfig) = deployDscEngine.run();
        (wethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc, deployerKey) = helperConfig.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, AMOUNT_MINTED);
    }

    ///////////////////////////////
    //       Price  Tests       //
    //////////////////////////////

    function testGetTokenValueInUsd() public view {
        uint256 amount = 5e18;
        uint256 expectedAnswer = 10000e18;
        uint256 actualAnswer = engine.getValueInUsd(weth, amount);
        assertEq(expectedAnswer, actualAnswer);
    }

    /////////////////////////////////
    // Collateral  Deposit Test    //
    ////////////////////////////////

    function testRevertIfCollateralIsZero() public {
        vm.startPrank(USER);
        // The user is allowing dsc contract to get AMOUNT_COLLATERAL token from his wallet
        // (owner,to which we are allowing to ,amount that we are allowing)
        ERC20Mock(weth).approveInternal(USER, address(dsc), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__MoreThanZero.selector);
        engine.depositCollateral(weth, 0);

        vm.stopPrank();
    }
//Test collateral deposits successfully as expected or not
    function testCollateralDepositedSuccessfully() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approveInternal(USER, address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, 1 ether);
        uint256 actualCollateralDeposited = engine.getTotalCollateralDepositedOfSpecificToken(USER, weth);
        uint256 expectedCollateralDeposited = 1 ether;
        assertEq(actualCollateralDeposited, expectedCollateralDeposited);
        vm.stopPrank();
    }
}
