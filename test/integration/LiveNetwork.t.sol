// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {WSRX} from "../../contracts/WSRX.sol";
import {Multicall3} from "../../contracts/Multicall3.sol";
import {SentrixSafe} from "../../contracts/SentrixSafe.sol";
import {TokenFactory} from "../../contracts/TokenFactory.sol";

/// @title LiveNetwork integration tests
/// @notice Run against a live RPC to verify deployed addresses respond correctly.
/// @dev Run with `forge test --match-path test/integration/* --rpc-url sentrix_testnet -vvv`.
///      Reads expected addresses from env. Test is gated — skips when env not present
///      so default `forge test` doesn't fail in CI without a live network.
contract LiveNetworkTest is Test {
    function test_wsrx_responds() public {
        address addr = vm.envOr("WSRX_ADDR", address(0));
        if (addr == address(0)) {
            console2.log("WSRX_ADDR not set - skipping live integration test");
            return;
        }
        WSRX w = WSRX(payable(addr));
        // Just call a view; no asserts - point is "doesn't revert"
        w.totalSupply();
        w.name();
        w.symbol();
    }

    function test_multicall3_responds() public {
        address addr = vm.envOr("MULTICALL3_ADDR", address(0));
        if (addr == address(0)) {
            console2.log("MULTICALL3_ADDR not set - skipping");
            return;
        }
        Multicall3 m = Multicall3(addr);
        assertEq(m.getChainId(), block.chainid);
    }

    function test_safe_responds() public {
        address addr = vm.envOr("SAFE_ADDR", address(0));
        if (addr == address(0)) {
            console2.log("SAFE_ADDR not set - skipping");
            return;
        }
        SentrixSafe s = SentrixSafe(payable(addr));
        assertGt(s.threshold(), 0);
    }

    function test_factory_responds() public {
        address addr = vm.envOr("FACTORY_ADDR", address(0));
        if (addr == address(0)) {
            console2.log("FACTORY_ADDR not set - skipping");
            return;
        }
        TokenFactory f = TokenFactory(addr);
        f.tokenCount(address(this));
    }
}
