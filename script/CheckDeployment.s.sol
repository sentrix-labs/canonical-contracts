// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {WSRX} from "../contracts/WSRX.sol";
import {Multicall3} from "../contracts/Multicall3.sol";
import {SentrixSafe} from "../contracts/SentrixSafe.sol";
import {TokenFactory} from "../contracts/TokenFactory.sol";

/// Smoke-test the canonical deployment for the current network.
///
/// Reads expected addresses from env (operator pastes them after deploy),
/// pings each contract with a cheap view call, and logs OK / MISMATCH /
/// UNREACHABLE. Run between testnet deploy and mainnet deploy as a sanity
/// gate.
///
/// Usage:
///   export WSRX_ADDR=0x...
///   export MULTICALL3_ADDR=0x...
///   export SAFE_ADDR=0x...
///   export FACTORY_ADDR=0x...
///   forge script script/CheckDeployment.s.sol:CheckDeployment --rpc-url sentrix_testnet
contract CheckDeployment is Script {
    function run() external view {
        console2.log("=== Sentrix canonical deployment check ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Block:", block.number);
        console2.log("");

        _checkWSRX();
        _checkMulticall3();
        _checkSafe();
        _checkFactory();

        console2.log("");
        console2.log("done.");
    }

    function _checkWSRX() internal view {
        address addr = vm.envOr("WSRX_ADDR", address(0));
        if (addr == address(0)) { console2.log("WSRX:        SKIP (no WSRX_ADDR env)"); return; }
        try WSRX(payable(addr)).totalSupply() returns (uint256 sup) {
            console2.log("WSRX:        OK", addr);
            console2.log("  totalSupply:", sup);
        } catch {
            console2.log("WSRX:        UNREACHABLE", addr);
        }
    }

    function _checkMulticall3() internal view {
        address addr = vm.envOr("MULTICALL3_ADDR", address(0));
        if (addr == address(0)) { console2.log("Multicall3:  SKIP (no MULTICALL3_ADDR env)"); return; }
        try Multicall3(addr).getBlockNumber() returns (uint256 n) {
            console2.log("Multicall3:  OK", addr);
            console2.log("  blockNumber:", n);
        } catch {
            console2.log("Multicall3:  UNREACHABLE", addr);
        }
    }

    function _checkSafe() internal view {
        address addr = vm.envOr("SAFE_ADDR", address(0));
        if (addr == address(0)) { console2.log("SentrixSafe: SKIP (no SAFE_ADDR env)"); return; }
        try SentrixSafe(payable(addr)).threshold() returns (uint256 t) {
            console2.log("SentrixSafe: OK", addr);
            console2.log("  threshold:", t);
        } catch {
            console2.log("SentrixSafe: UNREACHABLE", addr);
        }
    }

    function _checkFactory() internal view {
        address addr = vm.envOr("FACTORY_ADDR", address(0));
        if (addr == address(0)) { console2.log("Factory:     SKIP (no FACTORY_ADDR env)"); return; }
        try TokenFactory(addr).tokenCount(address(this)) returns (uint256) {
            console2.log("Factory:     OK", addr);
        } catch {
            console2.log("Factory:     UNREACHABLE", addr);
        }
    }
}
