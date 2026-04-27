// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {WSRX} from "../contracts/WSRX.sol";

/// Usage:
///   forge script script/DeployWSRX.s.sol:DeployWSRX \
///     --rpc-url sentrix_testnet --broadcast \
///     --private-key $DEPLOYER_PRIVATE_KEY
contract DeployWSRX is Script {
    function run() external returns (WSRX wsrx) {
        uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(pk);
        wsrx = new WSRX();
        vm.stopBroadcast();
        console2.log("WSRX deployed at:", address(wsrx));
        console2.log("Chain ID:", block.chainid);
    }
}
