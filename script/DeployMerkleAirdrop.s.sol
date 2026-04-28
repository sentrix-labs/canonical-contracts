// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "../contracts/MerkleAirdrop.sol";

/// @title DeployMerkleAirdrop
/// @notice Deploys a single-phase MerkleAirdrop instance.
/// @dev One MerkleAirdrop per airdrop phase. Phase 1 (Testnet Heroes) gets
///      its own deploy with the Phase 1 merkle root + 90-day deadline +
///      sweep-back to Strategic Reserve + ownership to SentrixSafe.
///
///      Required env vars:
///        MERKLE_ROOT          — bytes32 root of the airdrop tree
///        CLAIM_DEADLINE       — uint256 unix timestamp claims close
///        SWEEP_RECIPIENT      — address that receives unclaimed (Strategic Reserve EOA)
///        OWNER                — address that calls sweep() (SentrixSafe contract)
///        DEPLOYER_PRIVATE_KEY — private key for deploy (read off-repo)
///
///      Pre-fund step is SEPARATE — after deploy, transfer the phase total
///      from Strategic Reserve to the contract via SentrixSafe execTransaction.
///      That gives a clean two-step audit trail:
///        1. Contract deployed (this script)
///        2. Strategic Reserve → contract pre-fund tx (manual via Safe)
contract DeployMerkleAirdrop is Script {
    function run() external {
        bytes32 root = vm.envBytes32("MERKLE_ROOT");
        uint256 deadline = vm.envUint("CLAIM_DEADLINE");
        address sweep = vm.envAddress("SWEEP_RECIPIENT");
        address owner = vm.envAddress("OWNER");
        uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");

        // Sanity logs (visible in deploy output, not on-chain)
        console.log("Merkle root:", vm.toString(root));
        console.log("Claim deadline (unix):", deadline);
        console.log("Sweep recipient:", sweep);
        console.log("Owner (sweep caller):", owner);

        vm.startBroadcast(pk);
        MerkleAirdrop airdrop = new MerkleAirdrop(root, deadline, sweep, owner);
        vm.stopBroadcast();

        console.log("MerkleAirdrop deployed at:", address(airdrop));
        console.log("");
        console.log("NEXT STEPS:");
        console.log("1. Verify deployment on scan.sentrixchain.com");
        console.log("2. Pre-fund via SentrixSafe execTransaction:");
        console.log("   - to = MerkleAirdrop address");
        console.log("   - value = total claim amount (phase allocation in wei)");
        console.log("   - data = 0x (empty calldata, hits receive())");
        console.log("3. Publish merkle leaf list for recipients to verify inclusion");
        console.log("4. Open claim portal at faucet.sentrixchain.com/airdrop");
    }
}
