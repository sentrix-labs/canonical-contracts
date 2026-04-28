// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../contracts/StrategicReserveTimelock.sol";

/// @notice Tests for StrategicReserveTimelock. The contract is a thin
///         wrapper over OpenZeppelin TimelockController v5.6.0; these tests
///         focus on Sentrix-specific configuration + integration scenarios
///         (not re-testing OZ internals which are already audited).
contract StrategicReserveTimelockTest is Test {
    StrategicReserveTimelock timelock;

    address constant SENTRIX_SAFE = address(0x6272dC0C842F05542f9fF7B5443E93C0642a3b26);
    address constant RECIPIENT = address(0xBEEF);
    address constant ATTACKER = address(0xBAD);

    uint256 constant RESERVE_AMOUNT = 10_500_000 ether; // 10.5M SRX in wei (18-dec EVM convention)
    uint256 constant MIN_DELAY = 86400; // 24 hours
    bytes32 constant SALT = bytes32(uint256(0x1));

    function setUp() public {
        timelock = new StrategicReserveTimelock(SENTRIX_SAFE);
        // Pre-fund the contract with Strategic Reserve amount
        vm.deal(address(this), RESERVE_AMOUNT + 100 ether);
        (bool ok,) = address(timelock).call{value: RESERVE_AMOUNT}("");
        require(ok, "fund failed");
    }

    // ── Constructor / role assignment ────────────────────────────

    function test_constructor_minDelayIs24h() public view {
        assertEq(timelock.getMinDelay(), MIN_DELAY);
    }

    function test_constructor_sentrixSafeHasProposerRole() public view {
        assertTrue(timelock.hasRole(timelock.PROPOSER_ROLE(), SENTRIX_SAFE));
    }

    function test_constructor_sentrixSafeHasExecutorRole() public view {
        assertTrue(timelock.hasRole(timelock.EXECUTOR_ROLE(), SENTRIX_SAFE));
    }

    function test_constructor_sentrixSafeHasCancellerRole() public view {
        assertTrue(timelock.hasRole(timelock.CANCELLER_ROLE(), SENTRIX_SAFE));
    }

    function test_constructor_noAdmin() public view {
        // No external admin — role changes must go through timelock
        assertFalse(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), address(this)));
        assertFalse(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), SENTRIX_SAFE));
        // Only the timelock itself has admin role
        assertTrue(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), address(timelock)));
    }

    function test_constructor_balanceFunded() public view {
        assertEq(address(timelock).balance, RESERVE_AMOUNT);
    }

    // ── Spend flow (happy path) ──────────────────────────────────

    function test_scheduleAndExecute_happyPath() public {
        // 1. SentrixSafe schedules a spend
        vm.prank(SENTRIX_SAFE);
        timelock.schedule(
            RECIPIENT,
            1000 ether, // value to send
            "",         // calldata (empty = plain transfer)
            bytes32(0), // predecessor
            SALT,
            MIN_DELAY
        );

        // 2. Cannot execute before delay
        vm.prank(SENTRIX_SAFE);
        vm.expectRevert();
        timelock.execute(RECIPIENT, 1000 ether, "", bytes32(0), SALT);

        // 3. Wait the delay
        vm.warp(block.timestamp + MIN_DELAY + 1);

        // 4. SentrixSafe executes
        uint256 recipientBefore = RECIPIENT.balance;
        vm.prank(SENTRIX_SAFE);
        timelock.execute(RECIPIENT, 1000 ether, "", bytes32(0), SALT);

        assertEq(RECIPIENT.balance, recipientBefore + 1000 ether);
        assertEq(address(timelock).balance, RESERVE_AMOUNT - 1000 ether);
    }

    // ── Cancel flow (operator safety) ────────────────────────────

    function test_cancel_before_execute() public {
        vm.prank(SENTRIX_SAFE);
        timelock.schedule(RECIPIENT, 5000 ether, "", bytes32(0), SALT, MIN_DELAY);

        bytes32 id = timelock.hashOperation(RECIPIENT, 5000 ether, "", bytes32(0), SALT);

        // Cancel during the delay window
        vm.prank(SENTRIX_SAFE);
        timelock.cancel(id);

        // After delay, attempted execute reverts (operation no longer scheduled)
        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.prank(SENTRIX_SAFE);
        vm.expectRevert();
        timelock.execute(RECIPIENT, 5000 ether, "", bytes32(0), SALT);

        // Recipient never received funds
        assertEq(RECIPIENT.balance, 0);
    }

    // ── Access control (anti-bypass) ─────────────────────────────

    function test_attacker_cannotSchedule() public {
        vm.prank(ATTACKER);
        vm.expectRevert(); // missing PROPOSER_ROLE
        timelock.schedule(ATTACKER, 1000 ether, "", bytes32(0), SALT, MIN_DELAY);
    }

    function test_attacker_cannotExecute() public {
        // Schedule a legitimate spend
        vm.prank(SENTRIX_SAFE);
        timelock.schedule(RECIPIENT, 1000 ether, "", bytes32(0), SALT, MIN_DELAY);
        vm.warp(block.timestamp + MIN_DELAY + 1);

        // Attacker tries to execute
        vm.prank(ATTACKER);
        vm.expectRevert(); // missing EXECUTOR_ROLE
        timelock.execute(RECIPIENT, 1000 ether, "", bytes32(0), SALT);

        // SentrixSafe still can
        vm.prank(SENTRIX_SAFE);
        timelock.execute(RECIPIENT, 1000 ether, "", bytes32(0), SALT);
        assertEq(RECIPIENT.balance, 1000 ether);
    }

    function test_attacker_cannotCancel() public {
        vm.prank(SENTRIX_SAFE);
        timelock.schedule(RECIPIENT, 1000 ether, "", bytes32(0), SALT, MIN_DELAY);

        bytes32 id = timelock.hashOperation(RECIPIENT, 1000 ether, "", bytes32(0), SALT);

        vm.prank(ATTACKER);
        vm.expectRevert(); // missing CANCELLER_ROLE
        timelock.cancel(id);
    }

    function test_anyone_cannotChangeMinDelay() public {
        // updateDelay() can only be called by the timelock itself
        vm.prank(ATTACKER);
        vm.expectRevert();
        timelock.updateDelay(60); // try to set 1-minute delay

        vm.prank(SENTRIX_SAFE);
        vm.expectRevert();
        timelock.updateDelay(60); // SentrixSafe also cannot directly change delay

        // Min delay unchanged
        assertEq(timelock.getMinDelay(), MIN_DELAY);
    }

    function test_changeMinDelay_requiresTimelock() public {
        // The proper way to change minDelay: schedule a call to the
        // timelock itself with calldata for updateDelay, wait, execute.
        bytes memory data = abi.encodeWithSelector(
            timelock.updateDelay.selector,
            48 * 3600 // 48 hours
        );

        vm.prank(SENTRIX_SAFE);
        timelock.schedule(address(timelock), 0, data, bytes32(0), SALT, MIN_DELAY);

        // Cannot execute before delay
        vm.warp(block.timestamp + MIN_DELAY - 100);
        vm.prank(SENTRIX_SAFE);
        vm.expectRevert();
        timelock.execute(address(timelock), 0, data, bytes32(0), SALT);

        // After delay, executes successfully
        vm.warp(block.timestamp + 200);
        vm.prank(SENTRIX_SAFE);
        timelock.execute(address(timelock), 0, data, bytes32(0), SALT);

        assertEq(timelock.getMinDelay(), 48 * 3600);
    }

    // ── Schedule cannot be too short ─────────────────────────────

    function test_schedule_revertsOnTooShortDelay() public {
        vm.prank(SENTRIX_SAFE);
        vm.expectRevert(); // delay < minDelay
        timelock.schedule(RECIPIENT, 1000 ether, "", bytes32(0), SALT, 60);
    }

    // ── receive() — anyone can fund ──────────────────────────────

    function test_receive_anyoneCanFund() public {
        vm.deal(ATTACKER, 100 ether);
        uint256 before = address(timelock).balance;
        vm.prank(ATTACKER);
        (bool ok,) = address(timelock).call{value: 50 ether}("");
        assertTrue(ok);
        assertEq(address(timelock).balance, before + 50 ether);
    }

    // Role enumeration omitted — TimelockController extends AccessControl
    // (not AccessControlEnumerable), so per-role member iteration isn't
    // supported. The hasRole tests above are sufficient: they confirm
    // the right address has each role; AccessControl's role-grant flow
    // (only via DEFAULT_ADMIN_ROLE which is the timelock itself) means
    // no other addresses can hold proposer/executor/canceller without
    // a timelocked grantRole proposal.
}
