//SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    error DecentralizedStableCoin__CannotBurnZero();
    error DecentralizedStableCoin__CannotBurnMoreThanBalance();
    error DecentralizedStableCoin__CannotMintToNullAdress();
    error DecentralizedStableCoin__MintAmountMustGreaterThanZero();

    constructor() ERC20("DecentralizedStableCoin", "DSC") Ownable(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266) {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert DecentralizedStableCoin__CannotBurnZero();
        } else if (balance < _amount) {
            revert DecentralizedStableCoin__CannotBurnMoreThanBalance();
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralizedStableCoin__CannotMintToNullAdress();
        } else if (amount <= 0) {
            revert DecentralizedStableCoin__MintAmountMustGreaterThanZero();
        }
        _mint(_to, amount);
        return true;
    }
}
