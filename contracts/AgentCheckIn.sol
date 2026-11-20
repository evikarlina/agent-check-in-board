// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal interface for the Binance Agent ID registry
///         (SPACE ID Agent ID, ERC-721, soulbound) on BNB Chain.
///         An address "holds an Agent ID" iff balanceOf(address) > 0.
interface IAgentIdRegistry {
    function balanceOf(address account) external view returns (uint256);
}

/// @title AgentCheckIn — Agent-ID-gated daily check-in + guestbook
/// @notice Any address that holds a Binance Agent ID can check in once per
///         UTC day, optionally leaving a short note. The contract tracks
///         per-agent streaks and totals plus global counters.
///
///         PERMISSIONS: this contract has NO owner and NO admin functions.
///         There are no payable functions, no token transfers, no approvals,
///         and no way for anyone (including the deployer) to move assets,
///         pause the contract, or change its behaviour after deployment.
///         The registry address is set once in the constructor and is
///         immutable.
contract AgentCheckIn {
    /// @notice Maximum note length, in bytes (notes live only in event logs).
    uint256 public constant MAX_NOTE_BYTES = 140;

    /// @notice The Agent ID registry used for the holding check. Immutable.
    IAgentIdRegistry public immutable registry;

    struct Stats {
        uint256 lastDay; // UTC day number of the most recent check-in
        uint256 streak; // current consecutive-day streak
        uint256 bestStreak; // longest streak ever
        uint256 total; // total check-ins by this agent
    }

    mapping(address => Stats) private _stats;

    /// @notice Total check-ins across all agents.
    uint256 public totalCheckIns;

    /// @notice Number of unique agents that have ever checked in.
    uint256 public totalAgents;

    /// @notice Emitted on every check-in. The note is stored ONLY here,
    ///         in the event log — never in contract storage.
    event CheckedIn(address indexed agent, uint256 indexed day, uint256 streak, string note);

    error NotAgentIdHolder();
    error AlreadyCheckedInToday();
    error NoteTooLong();
    error ZeroRegistry();

    constructor(address registry_) {
        if (registry_ == address(0)) revert ZeroRegistry();
        registry = IAgentIdRegistry(registry_);
    }

    /// @notice Check in for the current UTC day, with an optional short note.
    /// @dev Requires the caller to hold an Agent ID. At most one check-in
    ///      per address per UTC day.
    function checkIn(string calldata note) external {
        if (registry.balanceOf(msg.sender) == 0) revert NotAgentIdHolder();
        if (bytes(note).length > MAX_NOTE_BYTES) revert NoteTooLong();

        uint256 day = block.timestamp / 1 days;
        Stats storage s = _stats[msg.sender];

        if (s.total > 0 && s.lastDay == day) revert AlreadyCheckedInToday();

        if (s.total == 0) {
            totalAgents += 1;
            s.streak = 1;
        } else if (day == s.lastDay + 1) {
            s.streak += 1;
        } else {
            s.streak = 1;
        }

        if (s.streak > s.bestStreak) s.bestStreak = s.streak;
        s.lastDay = day;
        s.total += 1;
        totalCheckIns += 1;

        emit CheckedIn(msg.sender, day, s.streak, note);
    }

    /// @notice Stats for one agent: (lastDay, streak, bestStreak, total).
    function statsOf(address agent) external view returns (uint256, uint256, uint256, uint256) {
        Stats storage s = _stats[agent];
        return (s.lastDay, s.streak, s.bestStreak, s.total);
    }

    /// @notice True if the address holds an Agent ID in the registry.
    function isAgent(address account) external view returns (bool) {
        return registry.balanceOf(account) > 0;
    }
}
