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
pragma solidity ^0.8.19;
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";

contract DSCEngine {
    ///////////////////////////////
    ////     Errors           ////
    //////////////////////////////

    error DSCEngine__MoreThanZero();
    error DSCEngine__lengthOfTokenAddressesArrayAndPriceFeedArrayMustBeSame();
    error DSCEngine__notAllowedToken();


    ///////////////////////////////
    ////     State            ////
    //////////////////////////////

    mapping(address token=>address priceFeed) private s_priceFeeds;
    DecentralizedStableCoin private immutable i_dsc;

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
        if(s_priceFeeds[token]==address(0)){
            revert DSCEngine__notAllowedToken();

        }
        _;
    }

    ///////////////////////////////
    ////     Functions         ////
    //////////////////////////////
    constructor(address[] memory tokenAddress,address[] memory priceFeedAddress,address dsc){
        if(tokenAddress.length!=priceFeedAddress.length){
            revert DSCEngine__lengthOfTokenAddressesArrayAndPriceFeedArrayMustBeSame(); 
        }

        for (uint256 i=0;i<tokenAddress.length;i++){
            s_priceFeeds[tokenAddress[i]]=priceFeedAddress[i];
        }
        i_dsc=DecentralizedStableCoin(dsc);


    }

    function depositCollateralAndMintDsc() external {}

    /*
     *@params _addressOfTokenToBeCollaterlized --Address of tokens used for collaterlization
     *@params _amountOfTokenToBeCollaterlized --Amount of the token to be collaterlized
     *
     */
    function depositCollateral(
        address _addressOfTokenToBeCollaterlized,
        uint256 _amountOfTokenToBeCollaterlized
    ) external moreThanZero(_amountOfTokenToBeCollaterlized) {}

    function reedemCollateralForDsc() external {}
    function getHealthFactor() external {}
    function burn() external {}
    function liquidate() external {}
    function mintDsc() external {}
}
