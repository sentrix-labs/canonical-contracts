// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {SentrixSafe} from "../contracts/SentrixSafe.sol";

/// Usage (3-of-5 example):
///   export SAFE_OWNERS="0xowner1,0xowner2,0xowner3,0xowner4,0xowner5"
///   export SAFE_THRESHOLD=3
///   forge script script/DeploySafe.s.sol:DeploySafe \
///     --rpc-url sentrix_testnet --broadcast \
///     --private-key $DEPLOYER_PRIVATE_KEY
contract DeploySafe is Script {
    function run() external returns (SentrixSafe safe) {
        uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address[] memory owners = vm.envAddress("SAFE_OWNERS", ",");
        uint256 threshold = vm.envUint("SAFE_THRESHOLD");

        vm.startBroadcast(pk);
        safe = new SentrixSafe(owners, threshold);
        vm.stopBroadcast();

        console2.log("SentrixSafe deployed at:", address(safe));
        console2.log("Owners:", owners.length);
        console2.log("Threshold:", threshold);
        console2.log("Chain ID:", block.chainid);
    }
}
