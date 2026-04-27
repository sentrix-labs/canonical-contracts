// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";

/// Sourcify verification helper.
///
/// Usage:
///   forge script script/VerifyAll.s.sol:VerifyAll --rpc-url sentrix_testnet
///
/// This script reads `deployments/<chainId>.json` (via `vm.readFile`) and
/// emits the manual verification commands you would run against a Sourcify
/// endpoint. Once Sourcify is self-hosted (Tier 1 ecosystem readiness
/// sprint), this script will switch from "log commands" to actual HTTP POSTs.
///
/// For now, it's intentionally a thin shim — the deploy script flow is
/// foundry-only, and Sourcify integration ships in a follow-up PR.
contract VerifyAll is Script {
    function run() external view {
        uint256 chainId = block.chainid;
        string memory path = string.concat("deployments/", vm.toString(chainId), ".json");

        console2.log("=== Sourcify verification plan ===");
        console2.log("Chain ID:", chainId);
        console2.log("Deployment file:", path);
        console2.log("");
        console2.log("(Sourcify endpoint integration pending T1-1)");
        console2.log("Until self-hosted Sourcify lands, run manual verification:");
        console2.log("  forge verify-contract --watch --chain", chainId, "<address> <Contract>");
        console2.log("");
        console2.log("Skipping JSON parse + endpoint POST — wire up in v2 of this script.");
    }
}
