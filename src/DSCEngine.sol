// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

//SPDX-License-Identifier:MIT
pragma solidity ^0.8.34;
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract DSCEngine {
    ///////////////////////////////
    ////     Errors           ////
    //////////////////////////////

    error DSCEngine__MoreThanZero();
    error DSCEngine__lengthOfTokenAddressesArrayAndPriceFeedArrayMustBeSame();
    error DSCEngine__notAllowedToken();
    error DSCEngine__transferFailedindepositCollateral();
    error DSCEngine__healthFactorBroken(uint256 userHealthFactor);
    error DSCEngine__mintFailed();
    error DSCEngine__TransferFailed();

    ///////////////////////////////
    ////     State variables  ////
    //////////////////////////////
    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 dscMinted) private s_dscMintedByEachUser;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    DecentralizedStableCoin private immutable i_dsc;
    address[] private s_collateralToken;

    ///////////////////////////////
    ////     Events           ////
    //////////////////////////////
    event collateralDeposited(address indexed user, address indexed tokenAddress, uint256 indexed amount);
    event collateralRedeemed(address indexed user, uint256 indexed amount, address indexed collaterallTokenAddress);

    ///////////////////////////////
    ////     Modifier         ////
    //////////////////////////////

    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) {
            revert DSCEngine__MoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__notAllowedToken();
        }
        _;
    }

    ///////////////////////////////
    ////     Functions         ////
    //////////////////////////////
    constructor(address[] memory tokenAddress, address[] memory priceFeedAddress, address dsc) {
        if (tokenAddress.length != priceFeedAddress.length) {
            revert DSCEngine__lengthOfTokenAddressesArrayAndPriceFeedArrayMustBeSame();
        }

        for (uint256 i = 0; i < tokenAddress.length; i++) {
            s_priceFeeds[tokenAddress[i]] = priceFeedAddress[i];
            s_collateralToken.push(tokenAddress[i]);
        }
        i_dsc = DecentralizedStableCoin(dsc);
    }

    function depositCollateralAndMintDsc(
        address _addressOfTokenToBeCollaterlized,
        uint256 _amountOfTokenToBeCollaterlized,
        uint256 _amountOfDscToMint
    ) external {
        depositCollateral(_addressOfTokenToBeCollaterlized, _amountOfTokenToBeCollaterlized);
        mintDsc(_amountOfDscToMint);
    }

    /*
     *@params follow CEI
     *@params _addressOfTokenToBeCollaterlized --Address of tokens used for collaterlization
     *@params _amountOfTokenToBeCollaterlized --Amount of the token to be collaterlized
     *
     */
    function depositCollateral(
        // CEI-->check,effects,interaction
        address _addressOfTokenToBeCollaterlized,
        uint256 _amountOfTokenToBeCollaterlized
    )
        public
        moreThanZero(_amountOfTokenToBeCollaterlized)
        isAllowedToken(_addressOfTokenToBeCollaterlized)
    {
        s_collateralDeposited[msg.sender][_addressOfTokenToBeCollaterlized] += _amountOfTokenToBeCollaterlized;
        emit collateralDeposited(msg.sender, _addressOfTokenToBeCollaterlized, _amountOfTokenToBeCollaterlized);
        bool success = IERC20(_addressOfTokenToBeCollaterlized)
            .transferFrom(msg.sender, address(this), _amountOfTokenToBeCollaterlized);
        if (!success) {
            revert DSCEngine__transferFailedindepositCollateral();
        }
    }

    function mintDsc(uint256 _amountOfDscToMint) public moreThanZero(_amountOfDscToMint) {
        s_dscMintedByEachUser[msg.sender] += _amountOfDscToMint;
        revertIfHealthFactorIsBroken(msg.sender);
        bool success = i_dsc.mint(msg.sender, _amountOfDscToMint);
        if (!success) {
            revert DSCEngine__mintFailed();
        }
    }

    function reedemCollateral(address collateralTokenAddress, uint256 amountCollateral)
        external
        moreThanZero(amountCollateral)
    {
        s_collateralDeposited[msg.sender][collateralTokenAddress] -= amountCollateral;
        emit collateralRedeemed(msg.sender, amountCollateral, collateralTokenAddress);
        bool success = IERC20(collateralTokenAddress).transfer(msg.sender, amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        revertIfHealthFactorIsBroken(msg.sender);
    }
    function getHealthFactor() external {}

    function burn(uint256 amountOfDscToBeBurned) external moreThanZero(amountOfDscToBeBurned) {
        s_dscMintedByEachUser[msg.sender] -= amountOfDscToBeBurned;
        bool success = i_dsc.transferFrom(msg.sender, address(this), amountOfDscToBeBurned);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amountOfDscToBeBurned);
    }
    function liquidate() external {}

    /////////////////////////////////
    // Private & Internal Function//
    ////////////////////////////////

    function revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _gethealthFactor(user);
        if (userHealthFactor > MIN_HEALTH_FACTOR) {
            revert DSCEngine__healthFactorBroken(userHealthFactor);
        }
    }

    // 1.This health factor functions tell how much a user is close to liquidation
    // 2.If health factor is less than one then user may be liquidated
    function _gethealthFactor(address user) internal view returns (uint256 healthFactor) {
        //requires
        //total dsc minted,total collateral deposied
        (uint256 totalDscMinted, uint256 totalCollateralDepositedInUsd) = _getAccountInformation(user);
        uint256 collateralAdjustedForThresHold =
            (totalCollateralDepositedInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThresHold * PRECISION) / totalDscMinted;
    }

    function _getAccountInformation(address user)
        internal
        view
        returns (uint256 totalCollateralDepositedInUsd, uint256 totalDscMinted)
    {
        totalDscMinted = s_dscMintedByEachUser[user];
        totalCollateralDepositedInUsd = _getTotalCollateralDepositedInUsd(user);
        return (totalDscMinted, totalCollateralDepositedInUsd);
    }
    /////////////////////////////////
    // Public  Function           //
    ////////////////////////////////

    function _getTotalCollateralDepositedInUsd(address user)
        public
        view
        returns (uint256 totalCollateralDepositedInUsd)
    {
        for (uint256 i = 0; i < s_collateralToken.length; i++) {
            address token = s_collateralToken[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralDepositedInUsd = getValueInUsd(token, amount);
        }
        return totalCollateralDepositedInUsd;
    }

    function getValueInUsd(address token, uint256 amount) public view returns (uint256 valueInUsd) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    ////////////////////
    //     Getters    //
    ////////////////////

    function getTotalCollateralDepositedOfSpecificToken(address user, address token)
        external
        view
        returns (uint256 totalCollateral)
    {
        return s_collateralDeposited[user][token];
    }
}
