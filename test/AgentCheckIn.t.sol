// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentCheckIn} from "../contracts/AgentCheckIn.sol";

/// @notice Minimal cheatcode interface (avoids a forge-std dependency).
interface Vm {
    function warp(uint256 newTimestamp) external;
    function prank(address msgSender) external;
}

/// @notice Minimal stub of the Agent ID registry for tests.
contract MockRegistry {
    mapping(address => uint256) private _balances;

    function setBalance(address account, uint256 amount) external {
        _balances[account] = amount;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }
}

contract AgentCheckInTest {
    Vm private constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    MockRegistry private registry;
    AgentCheckIn private board;

    address private constant ALICE = address(0xA11CE);
    address private constant BOB = address(0xB0B);
    address private constant NOBODY = address(0xDEAD);

    // 2026-11-20T00:00:00Z — a clean UTC day boundary.
    uint256 private constant DAY0 = 1_795_852_800;

    function setUp() public {
        registry = new MockRegistry();
        board = new AgentCheckIn(address(registry));
        registry.setBalance(ALICE, 1);
        registry.setBalance(BOB, 1);
        vm.warp(DAY0 + 3600); // 01:00 UTC on day0
    }

    // ---------- helpers ----------

    function assertEq(uint256 got, uint256 want, string memory what) internal pure {
        if (got != want) {
            revert(string(abi.encodePacked("assertEq failed: ", what)));
        }
    }

    function assertTrue(bool cond, string memory what) internal pure {
        if (!cond) revert(string(abi.encodePacked("assertTrue failed: ", what)));
    }

    function checkInAs(address user, string memory note) internal {
        vm.prank(user);
        board.checkIn(note);
    }

    function checkInReverts(address user, string memory note) internal returns (bool) {
        vm.prank(user);
        try board.checkIn(note) {
            return false;
        } catch {
            return true;
        }
    }

    // ---------- tests ----------

    function testNonHolderCannotCheckIn() public {
        assertTrue(checkInReverts(NOBODY, "hello"), "non-holder check-in must revert");
        assertEq(board.totalCheckIns(), 0, "totalCheckIns after rejected check-in");
        assertEq(board.totalAgents(), 0, "totalAgents after rejected check-in");
    }

    function testHolderCanCheckIn() public {
        checkInAs(ALICE, "first day");
        (uint256 lastDay, uint256 streak, uint256 best, uint256 total) = board.statsOf(ALICE);
        assertEq(total, 1, "alice total");
        assertEq(streak, 1, "alice streak");
        assertEq(best, 1, "alice best streak");
        assertEq(lastDay, (DAY0 + 3600) / 1 days, "alice lastDay");
        assertEq(board.totalCheckIns(), 1, "global totalCheckIns");
        assertEq(board.totalAgents(), 1, "global totalAgents");
    }

    function testSecondCheckInSameDayReverts() public {
        checkInAs(ALICE, "morning");
        vm.warp(DAY0 + 7200); // later the same UTC day
        assertTrue(checkInReverts(ALICE, "again"), "second same-day check-in must revert");
        (, , , uint256 total) = board.statsOf(ALICE);
        assertEq(total, 1, "alice total unchanged after revert");
    }

    function testStreakIncrementsOnConsecutiveDays() public {
        checkInAs(ALICE, "d0");
        vm.warp(DAY0 + 1 days + 100);
        checkInAs(ALICE, "d1");
        vm.warp(DAY0 + 2 days + 100);
        checkInAs(ALICE, "d2");
        (, uint256 streak, uint256 best, uint256 total) = board.statsOf(ALICE);
        assertEq(streak, 3, "streak after 3 consecutive days");
        assertEq(best, 3, "best streak after 3 consecutive days");
        assertEq(total, 3, "total after 3 consecutive days");
    }

    function testStreakResetsAfterGap() public {
        checkInAs(ALICE, "d0");
        vm.warp(DAY0 + 1 days + 100);
        checkInAs(ALICE, "d1");
        vm.warp(DAY0 + 3 days + 100); // skipped a day
        checkInAs(ALICE, "d3");
        (, uint256 streak, uint256 best, uint256 total) = board.statsOf(ALICE);
        assertEq(streak, 1, "streak resets after a gap");
        assertEq(best, 2, "best streak preserved after reset");
        assertEq(total, 3, "total still counts all check-ins");
    }

    function testCountersAcrossAgents() public {
        checkInAs(ALICE, "a0");
        checkInAs(BOB, "b0");
        vm.warp(DAY0 + 1 days + 100);
        checkInAs(ALICE, "a1");

        assertEq(board.totalAgents(), 2, "unique agents");
        assertEq(board.totalCheckIns(), 3, "total check-ins");

        (, , , uint256 aliceTotal) = board.statsOf(ALICE);
        (, , , uint256 bobTotal) = board.statsOf(BOB);
        assertEq(aliceTotal, 2, "alice total");
        assertEq(bobTotal, 1, "bob total");
    }

    function testNoteTooLongReverts() public {
        bytes memory long = new bytes(141);
        assertTrue(checkInReverts(ALICE, string(long)), "141-byte note must revert");
        // Exactly 140 bytes is fine.
        bytes memory exact = new bytes(140);
        checkInAs(ALICE, string(exact));
        (, , , uint256 total) = board.statsOf(ALICE);
        assertEq(total, 1, "140-byte note accepted");
    }

    function testIsAgent() public view {
        assertTrue(board.isAgent(ALICE), "alice is an agent");
        assertTrue(!board.isAgent(NOBODY), "nobody is not an agent");
    }
}
