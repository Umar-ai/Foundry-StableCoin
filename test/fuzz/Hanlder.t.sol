//SPDX-License-Identifier:MIT
pragma solidity ^0.8.34;

import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract Handler {

    DSCEngine dsce;
    DecentralizedStableCoin dsc;
    ERC20Mock weth;
    ERC20Mock wbtc;

    constructor(DSCEngine _dsce,DecentralizedStableCoin _dsc){
        dsce=_dsce;
        dsc=_dsc;

        address [] memory collateralTokens=dsce.getCollateralTokens();
        weth=ERC20Mock(collateralTokens[0]);
        wbtc=ERC20Mock(collateralTokens[1]);
    }

    function depositCollateral(uint256 collateralSeed,uint256 collateralAmount)public{
        dsce.depositCollateral(collateralAddress,collateralAmount);
    }

    function getCollateralTokenFromSeed(uint256 seed)private view returns(ERC20Mock){
        if(seed%2==0){
            return weth;
        }
        return wbtc;

    }


    
}