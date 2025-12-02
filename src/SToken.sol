// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Bridgeable} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Bridgeable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

contract SToken is ERC20, ERC20Bridgeable, ERC20Permit, ERC20Votes {
    // Hardcoded role addresses
    address public constant STOCKHOLDER0  = 0xeAC596bdA9F0025095FFa942563CB23290e7ab9c;
    address public constant STOCKHOLDER1  = 0x0bd60A0400E6135D2447756a68F8756E5ABFdE49;

    address public tokenBridge;
    error Unauthorized();

    constructor(address tokenBridge_)
        ERC20("SToken", "STK")
        ERC20Permit("SToken")
    {
        require(tokenBridge_ != address(0), "Invalid tokenBridge_ address");
        tokenBridge = tokenBridge_;
        if (block.chainid == 11155111) {
          uint256 amount = 1000 * 10 ** decimals();
          _mint(STOCKHOLDER0, amount);
          _mint(STOCKHOLDER1, amount);
        }
    }

    function _checkTokenBridge(address caller) internal view override {
        if (caller != tokenBridge) revert Unauthorized();
    }

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, value);
    }

    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}
