// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";

/// @title TransferOwnership
/// @author Sentrix Labs
/// @notice Documents the hand-off from the bootstrap deployer EOA to the
///         Sentrix Labs authority signer for any contract that has an
///         owner role.
/// @dev Current canonical set admin surface:
///      - WSRX:         no owner (immutable)
///      - Multicall3:   no owner (immutable)
///      - TokenFactory: no owner (open factory)
///      - SentrixSafe:  self-governed (owners + threshold via execTransaction)
///
///      Migration completed 2026-04-28 (both chains):
///      Step 1 — addOwner(authority, threshold=1): 1-of-1 deployer → 1-of-2 [deployer, authority].
///      Step 2 — removeOwner(deployer, threshold=1): 1-of-2 → 1-of-1 [authority].
///
///      Final state: SentrixSafe is a 1-of-1 multisig owned by the authority
///      signer 0xa25236925bc10954e0519731cc7ba97f4bb5714b on both chains
///      (mainnet 0x6272dC0C842F05542f9fF7B5443E93C0642a3b26 and testnet
///      0xc9D7a61D7C2F428F6A055916488041fD00532110). The deployer EOA is
///      retired from Safe ownership; future governance txs must be signed
///      by the authority key.
///
///      This script is read-only and prints the documented final state.
///      It does not perform any on-chain action — the migration is already
///      complete.
contract TransferOwnership is Script {
    address internal constant AUTHORITY = 0xa25236925Bc10954e0519731cc7ba97F4Bb5714b;
    address internal constant SAFE_MAINNET = 0x6272dC0C842F05542f9fF7B5443E93C0642a3b26;
    address internal constant SAFE_TESTNET = 0xc9D7a61D7C2F428F6A055916488041fD00532110;

    function run() external view {
        console2.log("=== SentrixSafe ownership (final state, post-2026-04-28 migration) ===");
        console2.log("Authority signer (sole Safe owner, threshold=1):", AUTHORITY);
        console2.log("Mainnet Safe (chain 7119):", SAFE_MAINNET);
        console2.log("Testnet Safe (chain 7120):", SAFE_TESTNET);
        console2.log("");
        console2.log("WSRX:        no owner (immutable, no transfer needed)");
        console2.log("Multicall3:  no owner (immutable, no transfer needed)");
        console2.log("TokenFactory: no owner (open factory, anyone may deploy)");
        console2.log("SentrixSafe: 1-of-1 with authority signer");
        console2.log("");
        console2.log("Migration is complete on-chain. See docs/ADDRESSES.md for tx hashes.");
        console2.log("If a future contract introduces an owner role, extend this script");
        console2.log("to emit the actual transferOwnership(...) calldata for the Safe.");
    }
}
