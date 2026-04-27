// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";

/// @title TransferOwnership
/// @author Sentrix Labs
/// @notice Hand off contract ownership from the deployer EOA to the
///         SentrixSafe multisig. Run after the initial deploy so the
///         deployer key can be retired.
/// @dev The current canonical set has limited admin surface:
///      - WSRX: no owner (immutable)
///      - Multicall3: no owner (immutable)
///      - TokenFactory: no owner (factory is open-access)
///      - SentrixSafe: owner-set is governed by the contract itself
///      So this script is a placeholder until owner-controlled contracts
///      (e.g., upgradeable proxies, pausable factories) are added in
///      future releases. Until then it just logs the situation.
contract TransferOwnership is Script {
    function run() external view {
        address safe = vm.envOr("SAFE_ADDR", address(0));
        if (safe == address(0)) {
            console2.log("TransferOwnership: SAFE_ADDR not set - skipping.");
            return;
        }

        console2.log("=== Ownership status (current canonical set) ===");
        console2.log("Target Safe:", safe);
        console2.log("");
        console2.log("WSRX:        no owner (immutable, no transfer needed)");
        console2.log("Multicall3:  no owner (immutable, no transfer needed)");
        console2.log("TokenFactory: no owner (open factory, anyone may deploy)");
        console2.log("SentrixSafe: self-governed (owners + threshold managed via execTransaction)");
        console2.log("");
        console2.log("No on-chain transfer to perform. Update CHANGELOG.md if this");
        console2.log("changes when a future contract introduces an owner role.");
    }
}
