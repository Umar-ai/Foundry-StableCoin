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
    error DSCEngine__userHealthFactorIsOk();
    error DSCEngine__healthFactorNotImproved();

    ///////////////////////////////
    ////     State variables  ////
    //////////////////////////////
    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 dscMinted) private s_dscMintedByEachUser;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant LIQUIDATION_BONUS = 10;
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
        public
        moreThanZero(amountCollateral)
    {
        _reedemCollateral(msg.sender, msg.sender, collateralTokenAddress, amountCollateral);
        revertIfHealthFactorIsBroken(msg.sender);
    }

    function getHealthFactor() external view returns (uint256 healthFactor) {
        healthFactor = _getHealthFactor(msg.sender);
    }

    function burn(uint256 amountOfDscToBeBurned) public moreThanZero(amountOfDscToBeBurned) {
        _burnDsc(amountOfDscToBeBurned, msg.sender, msg.sender);
    }

    /*
     *@param collateralTokenAddress Collateral token address to redeem
     *@param collateralAmount Collateral amount to redeem
     *@param dscAmountToBurn Dsc token amount to be burned
     *@notice This function burn dsc and redeem underlying collateral in one transaction
     */

    function burnDscAndRedeemCollateral(
        address collateralTokenAddress,
        uint256 collateralAmount,
        uint256 dscAmountToBurn
    ) public {
        burn(dscAmountToBurn);
        reedemCollateral(collateralTokenAddress, collateralAmount);
    }

    /*
     *@param collateralAddress Collateral address that we will give to liquidator
     *@param user User who broke the health factor and his/her collateral will be liquidated
     *@param debtToCover amount of dsc that liquidator should give to protcol to receive the underlying collateral
     *@notice This function burn dsc and redeem underlying collateral in one transaction
     */

    function liquidate(address collateralAddress, address user, uint256 debtToCover) external {
        uint256 startingHealthFactor = _getHealthFactor(user);
        if (startingHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__userHealthFactorIsOk();
        }
        // debt 200$
        //200$=How many ETH or btc??
        uint256 tokenAmountFromDebt = tokenAmountFromUsd(collateralAddress, debtToCover);
        uint256 bonusAmount = (tokenAmountFromDebt * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebt + bonusAmount;
        _reedemCollateral(user, msg.sender, collateralAddress, totalCollateralToRedeem);
        _burnDsc(debtToCover, user, msg.sender);
        uint256 endingHealthFactor = _getHealthFactor(user);
        if (endingHealthFactor < startingHealthFactor) {
            revert DSCEngine__healthFactorNotImproved();
        }
        revertIfHealthFactorIsBroken(msg.sender);
    }

    /////////////////////////////////
    // Private & Internal Function//
    ////////////////////////////////

    /*
    *Only call this _burnDSc internal function if the function calling it check
    *if health factor is broken or not
    *
    * */
    function _burnDsc(uint256 dscAmountToBurn, address onBehalfOf, address dscFrom) internal {
        s_dscMintedByEachUser[onBehalfOf] -= dscAmountToBurn;
        bool success = i_dsc.transferFrom(dscFrom, address(this), dscAmountToBurn);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(dscAmountToBurn);
    }

    function _reedemCollateral(address from, address to, address collateralTokenAddress, uint256 amountCollateral)
        internal
        moreThanZero(amountCollateral)
    {
        s_collateralDeposited[from][collateralTokenAddress] -= amountCollateral;
        emit collateralRedeemed(msg.sender, amountCollateral, collateralTokenAddress);
        bool success = IERC20(collateralTokenAddress).transfer(to, amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function tokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return ((usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION));
        //1e18*1e18/1e8*1e10
        //1e36/1e18
        //1e18
    }

    function revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _getHealthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__healthFactorBroken(userHealthFactor);
        }
    }

    // 1.This health factor functions tell how much a user is close to liquidation
    // 2.If health factor is less than one then user may be liquidated
    function _getHealthFactor(address user) internal view returns (uint256 healthFactor) {
        //requires
        //total dsc minted,total collateral deposied
        (uint256 totalDscMinted, uint256 totalCollateralDepositedInUsd) = _getAccountInformation(user);
        if (totalDscMinted == 0) return type(uint256).max;
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
            totalCollateralDepositedInUsd += getValueInUsd(token, amount);
        }
        return totalCollateralDepositedInUsd;
    }

    function getValueInUsd(address token, uint256 amount) public view returns (uint256 valueInUsd) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    function getAccountInformation(address user)
        public
        view
        returns (uint256 totalCollateralDepositedInUsd, uint256 totalDscMinted)
    {
        (totalCollateralDepositedInUsd, totalDscMinted) = _getAccountInformation(user);
        return (totalCollateralDepositedInUsd, totalDscMinted);
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

    function getCollateralTokens() public view returns (address[] memory) {
        return s_collateralToken;
    }
}
