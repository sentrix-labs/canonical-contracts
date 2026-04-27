// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {TokenFactory} from "../contracts/TokenFactory.sol";

/// Usage:
///   forge script script/DeployFactory.s.sol:DeployFactory \
///     --rpc-url sentrix_testnet --broadcast \
///     --private-key $DEPLOYER_PRIVATE_KEY
contract DeployFactory is Script {
    function run() external returns (TokenFactory factory) {
        uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(pk);
        factory = new TokenFactory();
        vm.stopBroadcast();
        console2.log("TokenFactory deployed at:", address(factory));
        console2.log("Chain ID:", block.chainid);
    }
}
