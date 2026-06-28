//SPDX-License-Identifier:MIT
pragma solidity ^0.8.34;

import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {Test,console} from "forge-std/Test.sol";

contract Handler is Test {
    DSCEngine dsce;
    DecentralizedStableCoin dsc;
    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;

    constructor(DSCEngine _dsce, DecentralizedStableCoin _dsc) {
        dsce = _dsce;
        dsc = _dsc;
        address[] memory collateralTokens = dsce.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);
    }

    function depositCollateral(uint256 collateralSeed, uint256 collateralAmount) public {
        ERC20Mock collateralAddress = getCollateralTokenFromSeed(collateralSeed);
        collateralAmount = bound(collateralAmount, 1, MAX_DEPOSIT_SIZE);
        vm.startPrank(msg.sender);
        collateralAddress.mint(msg.sender, collateralAmount);
        collateralAddress.approveInternal(msg.sender, address(dsce), collateralAmount);
        dsce.depositCollateral(address(collateralAddress), collateralAmount);
        vm.stopPrank();
    }

    function mintDsc(uint256 dscAmountToMint)public{
        dscAmountToMint=bound(dscAmountToMint,1,MAX_DEPOSIT_SIZE);
        (uint256 totalDscMinted,uint256 totalCollateralValueInUsd)=dsce.getAccountInformation(msg.sender);
        int256 maxDscToMint=int256(totalCollateralValueInUsd/2)-int256(totalDscMinted);
        if(maxDscToMint<0){
            return;
        }
        dscAmountToMint=bound(dscAmountToMint,0,uint256(maxDscToMint));
        if(dscAmountToMint==0){
            return;
        }
        vm.startPrank(msg.sender);
        dsce.mintDsc(dscAmountToMint);
        vm.stopPrank();

    }
    function reeedemCollateral(uint256 collateralSeed,uint256 collateralAmount) public{
        ERC20Mock collateralAddress=getCollateralTokenFromSeed(collateralSeed);
        uint256 userBalance=dsce.getTotalCollateralDepositedOfSpecificToken(msg.sender,address(collateralAddress));
        collateralAmount=bound(collateralAmount,0,userBalance);
        console.log(collateralAmount);
        if(collateralAmount==0){
            return;
        }
        vm.startPrank(msg.sender);
        dsce.reedemCollateral(address(collateralAddress),collateralAmount);
        vm.stopPrank();
    }


    function getCollateralTokenFromSeed(uint256 seed) private view returns (ERC20Mock) {
        if (seed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }
}
