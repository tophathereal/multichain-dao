// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract NSToken is ERC20, ERC20Burnable, Ownable, ERC20Permit, ERC20Votes {

    constructor(address initialOwner)
        ERC20("NSToken", "NSTK")
        Ownable(initialOwner)
        ERC20Permit("NSToken")
    {
        _mint(msg.sender, 40000 * (10 ** 18));
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
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

    // Override transfer function to block transfers unless the sender is the owner
    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        require(msg.sender == owner(), "NSToken: Only owner can transfer");
        return super.transfer(recipient, amount);
    }

    // Override transferFrom function to block transfers unless the sender is the owner
    function transferFrom(address sender, address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        require(msg.sender == owner(), "NSToken: Only owner can transfer");
        return super.transferFrom(sender, recipient, amount);
    }

    // Override approve function if you want to restrict approvals as well (optional)
    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        require(msg.sender == owner(), "NSToken: Only owner can approve");
        return super.approve(spender, amount);
    }
}

