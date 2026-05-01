// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "../contracts/StrategicReserveTimelock.sol";

/// @title DeployStrategicReserveTimelock
/// @notice One-shot deploy script for the Strategic Reserve timelock.
///         After deploy, the operator (separately) transfers the
///         Strategic Reserve EOA balance (10.5M SRX) to the contract
///         address. The Reserve EOA private key is then retired.
///
///         Required env vars:
///           SENTRIX_SAFE         — SentrixSafe address (chain-specific)
///           DEPLOYER_PRIVATE_KEY — private key for deploy gas
///
///         Suggested per-chain run:
///           Mainnet (7119):
///             SENTRIX_SAFE=0x6272dC0C842F05542f9fF7B5443E93C0642a3b26 \
///             DEPLOYER_PRIVATE_KEY=... \
///             forge script script/DeployStrategicReserveTimelock.s.sol \
///               --rpc-url https://rpc.sentrixchain.com --broadcast
///
///           Testnet (7120):
///             SENTRIX_SAFE=0xc9D7a61D7C2F428F6A055916488041fD00532110 \
///             DEPLOYER_PRIVATE_KEY=... \
///             forge script script/DeployStrategicReserveTimelock.s.sol \
///               --rpc-url https://testnet-rpc.sentrixchain.com --broadcast
contract DeployStrategicReserveTimelock is Script {
    function run() external {
        address sentrixSafe = vm.envAddress("SENTRIX_SAFE");
        uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");

        require(sentrixSafe != address(0), "SENTRIX_SAFE not set");

        console.log("Deploying StrategicReserveTimelock");
        console.log("  SentrixSafe (proposer/executor/canceller):", sentrixSafe);
        console.log("  Min delay: 86400 seconds (24 hours)");

        vm.startBroadcast(pk);
        StrategicReserveTimelock timelock = new StrategicReserveTimelock(sentrixSafe);
        vm.stopBroadcast();

        console.log("");
        console.log("StrategicReserveTimelock deployed at:");
        console.log("  ", address(timelock));
        console.log("");
        console.log("NEXT STEPS (operator, manual):");
        console.log("1. Verify on scan.sentrixchain.com that contract is");
        console.log("   self-administered (DEFAULT_ADMIN_ROLE held by");
        console.log("   contract itself, not deployer or SentrixSafe).");
        console.log("2. Transfer Strategic Reserve EOA balance (10.5M SRX)");
        console.log("   to this address. Use Sentrix tools/transfer-amount");
        console.log("   with the Reserve EOA private key. Sample command:");
        console.log("   ");
        console.log("   echo <reserve-privkey> | tools/transfer-amount/...");
        console.log("     --rpc <chain-rpc>");
        console.log("     --receiver", address(timelock));
        console.log("     --chain-id <7119|7120>");
        console.log("     --amount-sentri 1050000000000000  # 10.5M SRX");
        console.log("");
        console.log("3. After transfer confirms, RETIRE the Reserve EOA");
        console.log("   private key. Wipe from keystores. Document the");
        console.log("   migration in the operator address register as");
        console.log("   'Migrated to StrategicReserveTimelock <address>'.");
        console.log("4. Verify Sourcify: contract source already in");
        console.log("   sentrix-labs/canonical-contracts. Run verify.");
        console.log("5. Update TOKENOMICS.md + GOVERNANCE.md to point to");
        console.log("   contract address as Strategic Reserve location.");
    }
}
