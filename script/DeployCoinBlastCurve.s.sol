// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {CoinBlastCurve} from "../contracts/CoinBlastCurve.sol";

/// @notice Deploy a single CoinBlastCurve instance for one launchpad token.
///         Reads every curve parameter from env so a deploy run is fully
///         reproducible and reviewable. Each launch is its own deploy —
///         there's no factory wrapping these yet.
///
/// Usage (testnet bake first):
///   COINBLAST_NAME="TestLaunch" \
///   COINBLAST_SYMBOL="TEST" \
///   COINBLAST_CURVE_SUPPLY=1000000000000000000000000000  # 1B × 1e18
///   COINBLAST_BASE_PRICE_NUM=100000000000000              # 1e14 = 0.0001 SRX-wei/token
///   COINBLAST_BASE_PRICE_DEN=1
///   COINBLAST_K_NUM=1
///   COINBLAST_K_DEN=2                                     # K = 0.5
///   COINBLAST_GRADUATION_SRX_THRESHOLD=100000000000000000000  # 100 SRX (low for testnet smoke)
///   COINBLAST_FEE_BPS=100                                 # 1%
///   COINBLAST_FEE_RECIPIENT=0xeb70fdefd00fdb768dec06c478f450c351499f14  # Ecosystem Fund
///   COINBLAST_ROUTER=0x2bF73491733c3b87D72b16d4f7151dA294b55cB0          # testnet Router02
///   COINBLAST_WSRX=0x85d5E7694AF31C2Edd0a7e66b7c6c92C59fF949A            # testnet WSRX
///   forge script script/DeployCoinBlastCurve.s.sol:DeployCoinBlastCurve \
///     --rpc-url sentrix_testnet --broadcast \
///     --private-key $DEPLOYER_PRIVATE_KEY
contract DeployCoinBlastCurve is Script {
    function run() external returns (CoinBlastCurve curve) {
        CoinBlastCurve.InitParams memory p = CoinBlastCurve.InitParams({
            name: vm.envString("COINBLAST_NAME"),
            symbol: vm.envString("COINBLAST_SYMBOL"),
            curveSupply: vm.envUint("COINBLAST_CURVE_SUPPLY"),
            basePriceNum: vm.envUint("COINBLAST_BASE_PRICE_NUM"),
            basePriceDen: vm.envUint("COINBLAST_BASE_PRICE_DEN"),
            kNum: vm.envUint("COINBLAST_K_NUM"),
            kDen: vm.envUint("COINBLAST_K_DEN"),
            graduationSrxThreshold: vm.envUint("COINBLAST_GRADUATION_SRX_THRESHOLD"),
            feeRecipient: vm.envAddress("COINBLAST_FEE_RECIPIENT"),
            feeBps: vm.envUint("COINBLAST_FEE_BPS"),
            router: vm.envAddress("COINBLAST_ROUTER"),
            wsrx: vm.envAddress("COINBLAST_WSRX")
        });

        uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(pk);
        curve = new CoinBlastCurve(p);
        vm.stopBroadcast();

        console2.log("CoinBlastCurve deployed at:", address(curve));
        console2.log("FactoryToken deployed at:  ", address(curve.token()));
        console2.log("Chain ID:                  ", block.chainid);
        console2.log("Treasury (feeRecipient):   ", p.feeRecipient);
        console2.log("Router:                    ", p.router);
        console2.log("WSRX:                      ", p.wsrx);
        console2.log("Curve supply:              ", p.curveSupply);
        console2.log("Graduation threshold (SRX wei):", p.graduationSrxThreshold);
        console2.log("Fee (bps):                 ", p.feeBps);
    }
}
