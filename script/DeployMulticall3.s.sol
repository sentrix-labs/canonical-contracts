// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {Multicall3} from "../contracts/Multicall3.sol";

/// Usage:
///   forge script script/DeployMulticall3.s.sol:DeployMulticall3 \
///     --rpc-url sentrix_testnet --broadcast \
///     --private-key $DEPLOYER_PRIVATE_KEY
///
/// Note: canonical Multicall3 address is `0xcA11bde05977b3631167028862bE2a173976CA11`
/// (deployed via the Create2 deployer at `0x4e59b44847b379578588920cA78FbF26c0B4956C`
/// with salt `0x00...`). Replicating that exact address requires using the Create2
/// deployer; this script just deploys via plain CREATE for now. Operators wanting the
/// canonical address should use forge's Create2 / cast 4byte tooling separately.
contract DeployMulticall3 is Script {
    function run() external returns (Multicall3 multicall) {
        uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(pk);
        multicall = new Multicall3();
        vm.stopBroadcast();
        console2.log("Multicall3 deployed at:", address(multicall));
        console2.log("Chain ID:", block.chainid);
    }
}
