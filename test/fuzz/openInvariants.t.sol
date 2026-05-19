// //SPDX-License-Identifier:MIT
// pragma solidity ^0.8.34;

// import {Test} from "forge-std/Test.sol";
// import {StdInvariant} from "forge-std/StdInvariant.sol";
// import {DeployDscEngine} from "../../script/DeployDscEngine.s.sol";
// import {HelperConfig} from "../../script/HelperConfig.s.sol";
// import {DSCEngine} from "../../src/DSCEngine.sol";
// import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// contract InvariantsTest is StdInvariant,Test {
//     HelperConfig config;
//     DeployDscEngine deployer;
//     DSCEngine dsce;
//     DecentralizedStableCoin dsc;
//     address weth;
//     address wbtc;

//     function setUp() public {
//         deployer = new DeployDscEngine();
//         (dsc, dsce, config) = deployer.run();
//         (,, weth, wbtc,) = config.activeNetworkConfig();
//         targetContract(address(dsce));
//     }

//     function invariant_protocolMustHaveMoreCollateralThanTotalSupply()public view{
//         uint256 totalSupply=dsc.totalSupply();
//         uint256 totalWethDeposited=IERC20(weth).balanceOf(address(dsce));
//         uint256 totalWbtcDeposited=IERC20(wbtc).balanceOf(address(dsce));

//         uint256 totalWethDepositedInUsd=dsce.getValueInUsd(weth,totalWethDeposited);
//         uint256 totalWbtcDepositedInUsd=dsce.getValueInUsd(wbtc,totalWbtcDeposited);

//         assert(totalWethDepositedInUsd+totalWbtcDepositedInUsd>=totalSupply);
//     }

   
// }
