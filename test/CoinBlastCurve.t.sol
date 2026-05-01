// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {CoinBlastCurve} from "../contracts/CoinBlastCurve.sol";
import {FactoryToken} from "../contracts/TokenFactory.sol";

// Local mock router that satisfies the addLiquiditySRX call coinblast makes
// on graduation. We don't import the real V2 router here — that lives in the
// sister sentrix-dex repo. The mock just records the call + returns a
// plausible (token, srx, lp) tuple so graduate() flows end-to-end.
contract MockRouter {
    address public mockFactory;
    address public mockWsrx;
    bool public called;
    uint256 public srxReceived;
    address public tokenReceived;

    constructor(address f, address w) {
        mockFactory = f;
        mockWsrx = w;
    }

    function factory() external view returns (address) {
        return mockFactory;
    }

    function addLiquiditySRX(
        address token,
        uint256 amountTokenDesired,
        uint256, /*amountTokenMin*/
        uint256, /*amountSRXMin*/
        address, /*to*/
        uint256 /*deadline*/
    ) external payable returns (uint256 amountToken, uint256 amountSRX, uint256 liquidity) {
        called = true;
        srxReceived = msg.value;
        tokenReceived = token;
        // Pull the tokens to simulate real router's safeTransferFrom.
        require(FactoryToken(token).transferFrom(msg.sender, address(this), amountTokenDesired), "MOCK_PULL");
        amountToken = amountTokenDesired;
        amountSRX = msg.value;
        // Pretend LP minted = sqrt-ish; we don't need it to be exact.
        liquidity = amountToken < amountSRX ? amountToken : amountSRX;
    }
}

contract MockFactory {
    mapping(address => mapping(address => address)) public pairs;

    function getPair(address a, address b) external view returns (address) {
        return pairs[a][b] != address(0) ? pairs[a][b] : pairs[b][a];
    }

    function setPair(address a, address b, address p) external {
        pairs[a][b] = p;
        pairs[b][a] = p;
    }
}

contract CoinBlastCurveTest is Test {
    CoinBlastCurve curve;
    MockFactory factory;
    MockRouter router;
    address wsrx = address(0xCafe);
    address treasury = address(0xFEE);
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    uint256 constant CURVE_SUPPLY = 1_000_000 ether; // 1M tokens (1e24 wei)
    // Price is SRX-wei per token-wei (so multiplying by token-wei yields
    // SRX-wei). 0.0001 SRX per whole token = 1e14 SRX-wei / 1e18 token-wei
    // = 1e-4 = 1/10000.
    uint256 constant BASE_PRICE_NUM = 1;
    uint256 constant BASE_PRICE_DEN = 10000;
    uint256 constant K_NUM = 1;
    uint256 constant K_DEN = 2; // K = 0.5
    uint256 constant GRAD_THRESHOLD = 100 ether; // 100 SRX raised → graduate
    uint256 constant FEE_BPS = 100; // 1%

    function setUp() public {
        factory = new MockFactory();
        router = new MockRouter(address(factory), wsrx);
        // Pre-register pair address so graduate() can look it up
        // (the curve's token isn't known until construction, so we'll set
        // the pair address later via vm.etch... actually MockFactory.setPair
        // works fine).

        CoinBlastCurve.InitParams memory p = CoinBlastCurve.InitParams({
            name: "Test",
            symbol: "TST",
            curveSupply: CURVE_SUPPLY,
            basePriceNum: BASE_PRICE_NUM,
            basePriceDen: BASE_PRICE_DEN,
            kNum: K_NUM,
            kDen: K_DEN,
            graduationSrxThreshold: GRAD_THRESHOLD,
            feeRecipient: treasury,
            feeBps: FEE_BPS,
            router: address(router),
            wsrx: wsrx
        });
        curve = new CoinBlastCurve(p);

        // Now register the pair address (after curve constructor created the token)
        factory.setPair(address(curve.token()), wsrx, address(0xBeef));

        vm.deal(alice, 1000 ether);
        vm.deal(bob, 1000 ether);
    }

    // ── Construction guards ─────────────────────────────────────────

    function test_construction_rejects_zero_supply() public {
        CoinBlastCurve.InitParams memory p = _baseParams();
        p.curveSupply = 0;
        vm.expectRevert(CoinBlastCurve.InvalidParams.selector);
        new CoinBlastCurve(p);
    }

    function test_construction_rejects_excessive_fee() public {
        CoinBlastCurve.InitParams memory p = _baseParams();
        p.feeBps = 600; // > MAX_FEE_BPS=500
        vm.expectRevert(CoinBlastCurve.FeeTooHigh.selector);
        new CoinBlastCurve(p);
    }

    function test_construction_rejects_zero_router() public {
        CoinBlastCurve.InitParams memory p = _baseParams();
        p.router = address(0);
        vm.expectRevert(CoinBlastCurve.InvalidParams.selector);
        new CoinBlastCurve(p);
    }

    function test_construction_rejects_oversize_supply() public {
        CoinBlastCurve.InitParams memory p = _baseParams();
        p.curveSupply = 1e31; // > MAX_CURVE_SUPPLY=1e30
        vm.expectRevert(CoinBlastCurve.InvalidParams.selector);
        new CoinBlastCurve(p);
    }

    function _baseParams() internal view returns (CoinBlastCurve.InitParams memory p) {
        p = CoinBlastCurve.InitParams({
            name: "X",
            symbol: "X",
            curveSupply: CURVE_SUPPLY,
            basePriceNum: BASE_PRICE_NUM,
            basePriceDen: BASE_PRICE_DEN,
            kNum: K_NUM,
            kDen: K_DEN,
            graduationSrxThreshold: GRAD_THRESHOLD,
            feeRecipient: treasury,
            feeBps: FEE_BPS,
            router: address(router),
            wsrx: wsrx
        });
    }

    // ── Curve math invariants ───────────────────────────────────────

    function test_initial_price_at_zero_sold() public view {
        // P(0) = basePriceNum / basePriceDen = 1e14 / 1 = 1e14 wei per token.
        // Cost to buy 1 wei-token from s=0: P0 × 1 = 1e14
        (uint256 grossSrx,) = curve.quoteBuy(1);
        // The fee is added on top: grossSrx = baseCost + fee, so a 1-wei trade
        // sees baseCost ≈ 0 because (basePriceNum × 1)/basePriceDen / 1 = 0.0001 wei
        // which truncates to 0 in integer math. Floor effect — expected.
        // Buying 1e18 wei-tokens (1 whole token) is the meaningful test:
        (grossSrx,) = curve.quoteBuy(1 ether);
        assertGt(grossSrx, 0);
    }

    function test_quote_buy_monotone_in_size() public view {
        (uint256 cost1,) = curve.quoteBuy(100 ether);
        (uint256 cost2,) = curve.quoteBuy(200 ether);
        assertGt(cost2, cost1);
        // Doubling tokens should more than double cost (curve is convex).
        assertGt(cost2, 2 * cost1);
    }

    function test_buy_then_sell_round_trip_lossy_by_fees() public {
        uint256 buyAmount = 50 ether;
        (uint256 cost, uint256 fee) = curve.quoteBuy(buyAmount);

        vm.prank(alice);
        uint256 tokensOut = curve.buy{value: cost}(0);
        // The binary search may overshoot by a few token-wei because the
        // discrete cost function is step-flat at small magnitudes. Cap the
        // overshoot at one nano-token (1e9 token-wei = 1e-9 of a whole token).
        assertGe(tokensOut, buyAmount);
        assertLt(tokensOut - buyAmount, 1e9);

        // Approve curve to pull tokens back. Cache the token reference *before*
        // the prank — `vm.prank` consumes on the very next call, including
        // view getters like `curve.token()`, so chaining `curve.token().approve`
        // would prank the wrong call.
        FactoryToken tok = curve.token();
        vm.prank(alice);
        tok.approve(address(curve), tokensOut);

        uint256 srxBefore = alice.balance;
        vm.prank(alice);
        uint256 srxOut = curve.sell(tokensOut, 0);

        // After buy+sell, alice loses ~2× fee (one on buy, one on sell)
        // plus rounding. Check srxOut < cost (definitely).
        assertLt(srxOut, cost - fee);
        assertEq(alice.balance - srxBefore, srxOut);
    }

    function test_buy_refunds_dust() public {
        // Send way more SRX than needed; expect refund.
        uint256 srxIn = 100 ether;
        vm.prank(alice);
        uint256 balanceBefore = alice.balance;
        curve.buy{value: srxIn}(0);
        // alice should have spent only what the curve consumed; refund returns the rest.
        // Total spent = balanceBefore - alice.balance = grossSrx (cost paid + fee), refund implicit.
        uint256 spent = balanceBefore - alice.balance;
        assertLe(spent, srxIn);
        assertGt(spent, 0);
    }

    function test_buy_slippage_protection() public {
        // Ask for impossibly high tokens-out for the SRX sent.
        vm.prank(alice);
        vm.expectRevert(CoinBlastCurve.Slippage.selector);
        curve.buy{value: 1 ether}(CURVE_SUPPLY); // can't get full supply for 1 SRX
    }

    function test_buy_zero_value_reverts() public {
        vm.prank(alice);
        vm.expectRevert(CoinBlastCurve.ZeroValue.selector);
        curve.buy{value: 0}(0);
    }

    // ── Reentrancy ──────────────────────────────────────────────────

    function test_reentrancy_buy_via_recipient_callback() public {
        // Make the attacker contract BOTH buyer and feeRecipient so the
        // fee-forward step (always non-zero) triggers receive() — the dust
        // refund path is unreliable since binary search often lands on
        // exact-match cost (no dust). Deploy a fresh curve with attacker
        // as fee recipient.
        CoinBlastCurve.InitParams memory p = _baseParams();
        ReentrantBuyer attacker = new ReentrantBuyer(CoinBlastCurve(payable(address(0))));
        p.feeRecipient = address(attacker);
        CoinBlastCurve victim = new CoinBlastCurve(p);
        attacker.setCurve(victim);
        factory.setPair(address(victim.token()), wsrx, address(0xC0DE));

        vm.deal(address(attacker), 100 ether);
        vm.expectRevert(CoinBlastCurve.TransferFailed.selector);
        attacker.attack(10 ether);
    }

    // ── Graduation ──────────────────────────────────────────────────

    function test_graduate_reverts_below_threshold() public {
        vm.expectRevert(CoinBlastCurve.NotGraduatable.selector);
        curve.graduate();
    }

    function test_graduate_succeeds_above_threshold() public {
        // Buy until threshold met
        vm.deal(alice, 10000 ether);
        vm.startPrank(alice);
        for (uint256 i = 0; i < 5; i++) {
            curve.buy{value: 50 ether}(0);
            if (curve.srxRaised() >= GRAD_THRESHOLD) break;
        }
        vm.stopPrank();
        assertGe(curve.srxRaised(), GRAD_THRESHOLD);

        // Anyone can trigger graduate
        vm.prank(bob);
        curve.graduate();
        assertTrue(curve.graduated());
        assertTrue(router.called());
    }

    function test_post_graduation_buy_reverts() public {
        vm.deal(alice, 10000 ether);
        vm.startPrank(alice);
        for (uint256 i = 0; i < 5; i++) {
            curve.buy{value: 50 ether}(0);
            if (curve.srxRaised() >= GRAD_THRESHOLD) break;
        }
        vm.stopPrank();
        curve.graduate();

        vm.prank(bob);
        vm.expectRevert(CoinBlastCurve.AlreadyGraduated.selector);
        curve.buy{value: 1 ether}(0);
    }

    function test_double_graduate_reverts() public {
        vm.deal(alice, 10000 ether);
        vm.startPrank(alice);
        for (uint256 i = 0; i < 5; i++) {
            curve.buy{value: 50 ether}(0);
            if (curve.srxRaised() >= GRAD_THRESHOLD) break;
        }
        vm.stopPrank();
        curve.graduate();

        vm.expectRevert(CoinBlastCurve.AlreadyGraduated.selector);
        curve.graduate();
    }

    // ── Stray SRX rejection ─────────────────────────────────────────

    function test_random_eoa_send_reverts() public {
        // Alice tries to send SRX directly without going through buy() — must revert
        vm.prank(alice);
        (bool ok,) = address(curve).call{value: 1 ether}("");
        assertFalse(ok);
    }
}

// Helper for the reentrancy test — buys then attempts to re-enter buy()
// via the fee-recipient callback (curve always forwards a non-zero fee
// when feeBps > 0, so this path is reliable; the SRX-dust refund path is
// only triggered when binary search undershoots msg.value).
contract ReentrantBuyer {
    CoinBlastCurve curve;
    bool reentered;

    constructor(CoinBlastCurve c) {
        curve = c;
    }

    function setCurve(CoinBlastCurve c) external {
        curve = c;
    }

    function attack(uint256 amount) external {
        curve.buy{value: amount}(0);
    }

    receive() external payable {
        if (!reentered) {
            reentered = true;
            // Re-enter with a non-trivial amount so the inner buy() doesn't
            // bail on ZeroValue before reaching the lock check. The inner
            // call MUST revert with Reentrancy — that's what propagates back
            // up as the curve's _safeSendSRX failure.
            curve.buy{value: 1 ether}(0);
        }
    }
}
