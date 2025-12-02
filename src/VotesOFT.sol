// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {OFTCore} from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

/**
 * @title VotesOFT
 * @notice LayerZero OFT with ERC20Votes for governance participation.
 * @dev Implements ERC-6372 clock mode for Governor compatibility.
 *      Uses block.number by default; override clock() and CLOCK_MODE() for timestamps.
 */
contract VotesOFT is ERC20, ERC20Permit, ERC20Votes, OFTCore { 

    /**
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _lzEndpoint LayerZero endpoint address
     * @param _delegate OApp configuration delegate
     * @param _owner Token owner (for minting and OApp config)
     */
    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        address _delegate,
        address _owner
    )
        ERC20(_name, _symbol)
        ERC20Permit(_name)
        OFTCore(decimals(), _lzEndpoint, _delegate)
        Ownable(_owner)
    {
        if (block.chainid == 11155111) {  // Sepolia
            _mint(msg.sender, 100000 * (10 ** 18));
        } else if (block.chainid == 80002) {  // Amoy
            _mint(msg.sender, 10000 * (10 ** 18));
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // OFT IMPLEMENTATION
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Returns the address of the underlying ERC20 token.
     */
    function token() public view returns (address) {
        return address(this);
    }

    /**
     * @notice OFT does not require approval since the contract IS the token.
     */
    function approvalRequired() external pure returns (bool) {
        return false;
    }

    /**
     * @dev Burns tokens from sender when bridging out.
     */
    function _debit(
        address _from,
        uint256 _amountLD,
        uint256 _minAmountLD,
        uint32 _dstEid
    ) internal virtual override returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        (amountSentLD, amountReceivedLD) = _debitView(_amountLD, _minAmountLD, _dstEid);
        _burn(_from, amountSentLD);
    }

    /**
     * @dev Mints tokens to recipient when bridging in.
     */
    function _credit(
        address _to,
        uint256 _amountLD,
        uint32 /*_srcEid*/
    ) internal virtual override returns (uint256 amountReceivedLD) {
        if (_to == address(0x0)) _to = address(0xdead);
        _mint(_to, _amountLD);
        return _amountLD;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ERC-6372 CLOCK MODE (for Governor compatibility)
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Returns the current timepoint (block number by default).
     * @dev Override to use block.timestamp for timestamp-based governance.
     */
    function clock() public view virtual override returns (uint48) {
        return uint48(block.number);
    }

    /**
     * @notice Machine-readable description of the clock mode.
     * @dev Returns "mode=blocknumber&from=default" for block number mode.
     *      Override to "mode=timestamp" for timestamp-based governance.
     */
    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public view virtual override returns (string memory) {
        return "mode=blocknumber&from=default";
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MINTING (Owner only)
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Mints tokens to an address. Owner only.
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // REQUIRED OVERRIDES (ERC20 + ERC20Votes)
    // ═══════════════════════════════════════════════════════════════════════════

    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(
        address owner
    ) public view virtual override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
