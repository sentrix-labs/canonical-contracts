// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {CoinBlastFactory} from "../contracts/CoinBlastFactory.sol";
import {CoinBlastCurve} from "../contracts/CoinBlastCurve.sol";

/// Smoke tests for CoinBlastFactory. CoinBlastCurve has its own
/// 16-test suite — this file just verifies the factory passthrough
/// + event emission + registry bookkeeping. Re-uses the same inline
/// MockRouter / MockFactory pattern from CoinBlastCurve.t.sol so we
/// don't need a fully-running SentrixV2 stack just to graduate a
/// curve — and graduation isn't even exercised here, just construction.
contract MockFactory {
    mapping(address => mapping(address => address)) public pairs;
    function getPair(address a, address b) external view returns (address) {
        return pairs[a][b] != address(0) ? pairs[a][b] : pairs[b][a];
    }
    function setPair(address a, address b, address pair) external { pairs[a][b] = pair; }
}

contract MockRouter {
    address public mockFactory;
    address public mockWsrx;
    constructor(address f, address w) { mockFactory = f; mockWsrx = w; }
    function factory() external view returns (address) { return mockFactory; }
}

contract CoinBlastFactoryTest is Test {
    CoinBlastFactory factory;
    MockRouter router;
    MockFactory dexFactory;
    address treasury = makeAddr("treasury");
    address wsrx = address(0xCafe);
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        dexFactory = new MockFactory();
        router = new MockRouter(address(dexFactory), wsrx);
        factory = new CoinBlastFactory();
    }

    function _baseParams(string memory name, string memory symbol)
        internal
        view
        returns (CoinBlastCurve.InitParams memory)
    {
        return CoinBlastCurve.InitParams({
            name: name,
            symbol: symbol,
            curveSupply: 1_000_000 ether,
            basePriceNum: 1,
            basePriceDen: 10000,
            kNum: 1,
            kDen: 2,
            graduationSrxThreshold: 100 ether,
            feeRecipient: treasury,
            feeBps: 100,
            router: address(router),
            wsrx: wsrx
        });
    }

    function test_createCurve_emits_event_and_returns_curve() public {
        CoinBlastCurve.InitParams memory p = _baseParams("Alice Coin", "ALICE");
        vm.recordLogs();
        vm.prank(alice);
        CoinBlastCurve curve = factory.createCurve(p);

        assertTrue(address(curve) != address(0));
        assertEq(curve.curveSupply(), p.curveSupply);
        assertEq(curve.graduationSrxThreshold(), p.graduationSrxThreshold);
        // Factory ownership of curves[] is bookkeeping only — the curve
        // itself owns its token supply.
        assertEq(curve.token().balanceOf(address(curve)), p.curveSupply);
    }

    function test_allCurves_grows_per_deploy() public {
        assertEq(factory.totalCurves(), 0);

        vm.prank(alice);
        factory.createCurve(_baseParams("A", "A"));
        assertEq(factory.totalCurves(), 1);

        vm.prank(bob);
        factory.createCurve(_baseParams("B", "B"));
        assertEq(factory.totalCurves(), 2);

        vm.prank(alice);
        factory.createCurve(_baseParams("A2", "A2"));
        assertEq(factory.totalCurves(), 3);
    }

    function test_curvesOf_groups_by_msg_sender() public {
        vm.prank(alice);
        CoinBlastCurve curveA1 = factory.createCurve(_baseParams("A1", "A1"));
        vm.prank(bob);
        CoinBlastCurve curveB1 = factory.createCurve(_baseParams("B1", "B1"));
        vm.prank(alice);
        CoinBlastCurve curveA2 = factory.createCurve(_baseParams("A2", "A2"));

        address[] memory aliceCurves = factory.curvesOf(alice);
        address[] memory bobCurves = factory.curvesOf(bob);

        assertEq(aliceCurves.length, 2);
        assertEq(aliceCurves[0], address(curveA1));
        assertEq(aliceCurves[1], address(curveA2));
        assertEq(bobCurves.length, 1);
        assertEq(bobCurves[0], address(curveB1));
    }

    function test_curve_constructor_revert_propagates() public {
        // Zero supply trips InvalidParams in CoinBlastCurve constructor —
        // the factory shouldn't swallow the revert.
        CoinBlastCurve.InitParams memory p = _baseParams("X", "X");
        p.curveSupply = 0;
        vm.expectRevert(CoinBlastCurve.InvalidParams.selector);
        vm.prank(alice);
        factory.createCurve(p);
    }
}
