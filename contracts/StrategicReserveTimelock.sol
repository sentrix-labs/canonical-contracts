// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @title StrategicReserveTimelock
/// @author Sentrix Labs
/// @notice Holds the Strategic Reserve (10,500,000 SRX) under enforced
///         timelock. Spends require: SentrixSafe schedules a call → wait
///         minDelay → SentrixSafe executes.
/// @dev Thin wrapper over OpenZeppelin's audited TimelockController v5.6.0
///      (battle-tested in Compound governance, holds $billions). No
///      custom logic — just constructor that hardcodes Sentrix
///      configuration:
///      - minDelay = 24 hours (86400 seconds)
///      - proposer = SentrixSafe (Authority signer required to schedule)
///      - executor = SentrixSafe (Authority signer required to execute
///        post-delay)
///      - canceller = SentrixSafe (can cancel pending ops)
///      - admin = address(0) — fully self-administered. Role changes
///        themselves go through the timelock.
///
///      Migration flow (one-time):
///      1. Deploy this contract.
///      2. Transfer Strategic Reserve EOA balance (10.5M SRX) to this
///         contract address.
///      3. Reserve EOA private key is retired (zero out, never reuse).
///
///      Spend flow (recurring):
///      1. SentrixSafe calls schedule(target, value, data, predecessor,
///         salt, delay) — operation queued.
///      2. Wait at least minDelay (24h).
///      3. SentrixSafe calls execute(target, value, data, predecessor,
///         salt) — operation runs.
///      4. Optional: cancel(id) before delay elapses if mistake/coercion
///         detected.
///
///      Cancel flow (operator safety):
///      - 24-hour window between schedule + execute lets operator catch
///        wrong amounts, recipients, or proposed-under-coercion spends
///        and cancel before damage.
contract StrategicReserveTimelock is TimelockController {
    /// @notice Construct the timelock with Sentrix's standard config.
    /// @param sentrixSafe The SentrixSafe address (mainnet
    ///        0x6272dC0C842F05542f9fF7B5443E93C0642a3b26 / testnet
    ///        0xc9D7a61D7C2F428F6A055916488041fD00532110). Granted
    ///        proposer + executor + canceller roles.
    constructor(address sentrixSafe)
        TimelockController(
            // minDelay: 24 hours. Operations cannot be scheduled with
            // a shorter delay than this — and only the timelock itself
            // (via timelocked proposal) can change the minDelay.
            86400,
            // proposers: SentrixSafe is the only address authorized to
            // schedule new spend operations.
            _singletonArray(sentrixSafe),
            // executors: SentrixSafe is the only address authorized to
            // execute scheduled operations after the delay elapses.
            // We deliberately do NOT pass address(0) (which would let
            // anyone execute) — this keeps the audit trail clean
            // (every execution is via SentrixSafe execTransaction).
            _singletonArray(sentrixSafe),
            // admin: address(0) means no admin role. Role changes go
            // through timelock itself (proposed, delayed, executed).
            // This prevents anyone — including the deployer — from
            // bypassing the timelock to grant new roles.
            address(0)
        )
    {}

    /// @dev Helper: build a single-element address array for the
    ///      TimelockController constructor.
    function _singletonArray(address addr)
        private
        pure
        returns (address[] memory)
    {
        address[] memory arr = new address[](1);
        arr[0] = addr;
        return arr;
    }

    // Inherits from TimelockController:
    // - schedule(target, value, data, predecessor, salt, delay)
    // - scheduleBatch(targets, values, payloads, predecessor, salt, delay)
    // - execute(target, value, data, predecessor, salt)
    // - executeBatch(targets, values, payloads, predecessor, salt)
    // - cancel(id)
    // - getOperationState(id)
    // - hasRole(role, account)
    // - All standard AccessControl methods
    // - receive() to accept native SRX

    // No custom logic. All security properties come from OZ
    // TimelockController v5.6.0:
    // - Time-lock enforcement (operation cannot execute before
    //   readyTimestamp = scheduleTimestamp + delay)
    // - Role-based access (only PROPOSER can schedule, only EXECUTOR
    //   can execute, only CANCELLER can cancel)
    // - Self-administration (role changes go through timelock)
    // - Reentrancy-safe (uses internal _execute)
    // - Predecessor support (operations can require another op to be
    //   done first, for atomic multi-step flows)
}
