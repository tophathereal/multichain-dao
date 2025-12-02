// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {IERC6372} from "@openzeppelin/contracts/interfaces/IERC6372.sol";

/**
 * @title MultiTokenGovernor
 * @notice Governor that aggregates voting power from multiple ERC20Votes tokens.
 * All tokens must share the same ERC-6372 clock mode (block number or timestamp).
 */
contract MultiTokenGovernor is Governor, GovernorSettings, GovernorCountingSimple {
    IVotes[] public voteTokens;
    string private _storedClockMode;

    error NoTokensProvided();
    error DuplicateToken(address token);
    error ClockMismatch(address token, uint48 expected, uint48 actual);
    error ClockModeNotImplemented(address token);
    error ClockModeMismatch(address token, string expected, string actual);

    constructor(IVotes[] memory _voteTokens)
        Governor("MultiTokenGovernor")
        GovernorSettings(
            0,  // 0 blocks voting delay
            30, // 30 blocks voting period
            0   // 0 token proposal threshold
        )
    {
        if (_voteTokens.length == 0) revert NoTokensProvided();

        // Validate first token and establish reference clock
        IERC6372 refToken = IERC6372(address(_voteTokens[0]));
        uint48 referenceClock;
        string memory referenceClockMode;

        try refToken.clock() returns (uint48 c) {
            referenceClock = c;
        } catch {
            revert ClockModeNotImplemented(address(refToken));
        }

        try refToken.CLOCK_MODE() returns (string memory cm) {
            referenceClockMode = cm;
            _storedClockMode = cm;
        } catch {
            revert ClockModeNotImplemented(address(refToken));
        }

        // Validate all tokens share same clock semantics and check for duplicates
        for (uint256 i = 0; i < _voteTokens.length; i++) {
            IVotes token = _voteTokens[i];
            
            // Check for duplicate tokens
            for (uint256 j = 0; j < i; j++) {
                if (address(token) == address(_voteTokens[j])) {
                    revert DuplicateToken(address(token));
                }
            }

            // Validate clock consistency
            IERC6372 token6372 = IERC6372(address(token));
            uint48 tokenClock = token6372.clock();
            if (tokenClock != referenceClock) {
                revert ClockMismatch(address(token), referenceClock, tokenClock);
            }

            // Validate CLOCK_MODE consistency
            string memory tokenClockMode = token6372.CLOCK_MODE();
            if (keccak256(bytes(tokenClockMode)) != keccak256(bytes(referenceClockMode))) {
                revert ClockModeMismatch(address(token), referenceClockMode, tokenClockMode);
            }

            voteTokens.push(token);
        }
    }

    /// @notice Returns number of voting tokens
    function voteTokensLength() external view returns (uint256) {
        return voteTokens.length;
    }

    /// @notice Aggregate votes for an account at a given timepoint from all tokens
    function _getVotes(
        address account,
        uint256 timepoint,
        bytes memory /*params*/
    ) internal view override returns (uint256) {
        uint256 totalVotes = 0;
        for (uint256 i = 0; i < voteTokens.length; i++) {
            totalVotes += voteTokens[i].getPastVotes(account, timepoint);
        }
        return totalVotes;
    }

    /// @notice Quorum as 4% of total voting supply across all tokens
    function quorum(uint256 timepoint) public view override returns (uint256) {
        uint256 totalSupply = 0;
        for (uint256 i = 0; i < voteTokens.length; i++) {
            totalSupply += voteTokens[i].getPastTotalSupply(timepoint);
        }
        return (totalSupply * 4) / 100;
    }

    /// @notice Clock mechanism delegated to first token
    function clock() public view override returns (uint48) {
        return IERC6372(address(voteTokens[0])).clock();
    }

    /// @notice Clock mode delegated to first token
    function CLOCK_MODE() public view override returns (string memory) {
        return _storedClockMode;
    }

    // Required overrides

    function votingDelay() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingDelay();
    }

    function votingPeriod() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingPeriod();
    }

    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }
}
