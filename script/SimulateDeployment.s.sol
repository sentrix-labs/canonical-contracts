// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {WSRX} from "../contracts/WSRX.sol";
import {Multicall3} from "../contracts/Multicall3.sol";
import {SentrixSafe} from "../contracts/SentrixSafe.sol";
import {TokenFactory} from "../contracts/TokenFactory.sol";

/// @title SimulateDeployment
/// @author Sentrix Labs
/// @notice Dry-run all four deploys against a Tenderly fork (or any
///         forked RPC). Does not broadcast — just deploys + asserts the
///         resulting contracts respond correctly.
/// @dev Usage:
///        forge script script/SimulateDeployment.s.sol:SimulateDeployment \
///          --rpc-url $TENDERLY_FORK_RPC
///      No `--broadcast` flag — this stays in-memory.
contract SimulateDeployment is Script {
    function run() external {
        console2.log("=== Sentrix canonical deployment simulation ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Block:", block.number);
        console2.log("");

        WSRX wsrx = new WSRX();
        console2.log("WSRX simulated:", address(wsrx));
        require(keccak256(bytes(wsrx.symbol())) == keccak256("WSRX"), "WSRX: bad symbol");

        Multicall3 mc = new Multicall3();
        console2.log("Multicall3 simulated:", address(mc));
        require(mc.getChainId() == block.chainid, "Multicall3: chain mismatch");

        TokenFactory factory = new TokenFactory();
        console2.log("TokenFactory simulated:", address(factory));
        require(factory.tokenCount(address(this)) == 0, "Factory: bad initial state");

        // Safe needs a real owner set; for simulation, use msg.sender alone
        address[] memory owners = new address[](1);
        owners[0] = msg.sender;
        SentrixSafe safe = new SentrixSafe(owners, 1);
        console2.log("SentrixSafe simulated:", address(safe));
        require(safe.threshold() == 1, "Safe: bad threshold");

        console2.log("");
        console2.log("All four contracts deployed + sanity-checked. Safe to broadcast.");
    }
}
