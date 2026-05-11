//SPDX-License-Identifier:MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {DeployDscEngine} from "../../script/DeployDscEngine.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract DSCEngineTest is Test {
    uint256 private constant AMOUNT_COLLATERAL = 5 ether;
    uint256 private constant AMOUNT_MINTED = 10 ether;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant ADDITIONAL_PRECISION = 1e10;
    uint256 private constant AMOUNT_DSC_TO_MINT = 900e18;
    uint256 private constant BIG_DSC_AMOUNT_MINT = 10000e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
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
    //     Constructor  Tests  //
    //////////////////////////////

    address[] public tokenAddress;
    address[] public tokenPriceFeedAddress;

    function testRevertHappensIfTokenArrayLengthIsNotEqualToPriceFeedArray()public{
        tokenAddress.push(weth);
        tokenPriceFeedAddress.push(wethUsdPriceFeed);
        tokenPriceFeedAddress.push(wbtcUsdPriceFeed);
        vm.expectRevert(DSCEngine.DSCEngine__lengthOfTokenAddressesArrayAndPriceFeedArrayMustBeSame.selector);
        new DSCEngine(tokenAddress,tokenPriceFeedAddress,address(dsc));
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

    //Test token amount from usd
    function testTokenAmountFromUsd() public view {
        uint256 usdAmountInWei = 10 ether;
        uint256 expectedwei=0.005 ether;
        uint256 actualtokenAmount = engine.tokenAmountFromUsd(weth, usdAmountInWei);
        assertEq(actualtokenAmount, expectedwei);
    }
    //Test revert with unapproved collateral

    function testRevertWhenWeDepositUnApprovedCollateral()public {
        ERC20Mock ranToken=new ERC20Mock("RAN","RN",USER,AMOUNT_COLLATERAL);
        vm.prank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__notAllowedToken.selector);
        engine.depositCollateral(address(ranToken),AMOUNT_COLLATERAL);
    }
    modifier depositCollateral{
        vm.startPrank(USER);
        ERC20Mock(weth).approveInternal(USER,address(engine),AMOUNT_COLLATERAL);
        engine.depositCollateral(address(weth),AMOUNT_COLLATERAL);
        _;
        vm.stopPrank();
    }

    function testDespositCollateralAndGetAccountInfo()public depositCollateral{
        // 5 eth*2000=10000.000000000000000000
        (uint256 totalDscMinted,uint256 totalCollateralDepositedInUsd)=engine.getAccountInformation(USER);
        uint256 expectedDscMinted=0;
        uint256 depositedCollateralTokenAmount=engine.tokenAmountFromUsd(weth,totalCollateralDepositedInUsd);
        // assertEq(totalCollateralDepositedInUsd,10000 ether);
        assertEq(totalDscMinted,expectedDscMinted);
        assertEq(depositedCollateralTokenAmount,AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

     function testTotalCollateralDepositedInUsd()public depositCollateral{
        uint256 expectedTotalCollateralDepositedInUsd=10000 ether;
        uint256 actualTotalCollateralAmountInUsd=engine._getTotalCollateralDepositedInUsd(USER);
        assertEq(expectedTotalCollateralDepositedInUsd,actualTotalCollateralAmountInUsd);
     }

     function testCollateralValueInUsd()public depositCollateral{
        uint256 expectedTotalCollateralDepositedInUsd=10000 ether;
        uint256 actualCollateralDepositedInUsd=engine.getValueInUsd(weth,AMOUNT_COLLATERAL);
        assertEq(expectedTotalCollateralDepositedInUsd,actualCollateralDepositedInUsd);
     }

    

     function testCheckDscMintedSuccessfully()public depositCollateral{
        vm.startPrank(USER);
        uint256 expectedDscMinted=AMOUNT_DSC_TO_MINT;
        engine.mintDsc(AMOUNT_DSC_TO_MINT);
        (uint256 totalDscMinted,)=engine.getAccountInformation(USER);
        assertEq(totalDscMinted,expectedDscMinted);
        vm.stopPrank();
     }

     function testHealthFactorBrokeWhenWeMintMoreThanWeDeposit()public depositCollateral{
        vm.startPrank(USER);
        (,uint256 totalCollateralDepositedInUsd)=engine.getAccountInformation(USER);
         uint256 collateralAdjustedForThresHold =
            (totalCollateralDepositedInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        uint256 expectHealthFactor= (collateralAdjustedForThresHold * PRECISION) / BIG_DSC_AMOUNT_MINT;
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__healthFactorBroken.selector,expectHealthFactor));
        engine.mintDsc(BIG_DSC_AMOUNT_MINT);
        vm.stopPrank();
     }

     function testIsGetHealthFactorWorkingFine()public depositCollateral{
        vm.startPrank(USER);
        (,uint256 totalCollateralDepositedInUsd)=engine.getAccountInformation(USER);
         uint256 collateralAdjustedForThresHold =
            (totalCollateralDepositedInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        uint256 expectHealthFactor= (collateralAdjustedForThresHold * PRECISION) / AMOUNT_DSC_TO_MINT;
        engine.mintDsc(AMOUNT_DSC_TO_MINT);
        uint256 actualHealthFactor=engine.getHealthFactor();
        assertEq(expectHealthFactor,actualHealthFactor);
        vm.stopPrank();

     }
}
