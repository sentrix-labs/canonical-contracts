// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {FactoryToken} from "./TokenFactory.sol";

/// @title CoinBlastCurve
/// @author Sentrix Labs
/// @notice On-chain linear bonding curve for the CoinBlast launchpad. One
///         instance per launched token. Buyers send native SRX, get tokens
///         along the curve P(s) = P0 × (1 + K × s/S). When SRX raised hits
///         the graduation threshold, anyone can call `graduate()` which
///         seeds the canonical Sentrix V2 DEX pool with the raised SRX +
///         remaining curve inventory and burns the resulting LP forever.
///
/// @dev Designed to match the frontend's bonding-curve.ts arithmetic
///      exactly so off-chain estimates equal on-chain settlements.
///
///      Security model:
///        - Immutable post-deploy: no admin keys, no upgrade path, no
///          parameter mutation. Once SRX is raised it can only exit via
///          a sell() back along the curve OR via graduate() into locked LP.
///        - nonReentrant guards every state-changing entry point so the
///          ERC-20 token's transfer hooks (or a malicious recipient on
///          SRX refund) cannot re-enter the curve mid-trade.
///        - On graduation, the launchpad calls into the DEX router and
///          immediately burns the LP receipt — the raised SRX is locked
///          as DEX liquidity forever.
contract CoinBlastCurve {
    // ── Immutable curve parameters ────────────────────────────────────
    /// @notice ERC-20 token sold by this curve. The curve owns the entire
    ///         initial supply at construction; tokens leave via buy() and
    ///         return via sell()/graduate().
    FactoryToken public immutable token;
    /// @notice Total token supply (also the curve's denominator). Constant.
    uint256 public immutable curveSupply;
    /// @notice Base price numerator/denominator in SRX-wei per whole token.
    ///         price0 = basePriceNum / basePriceDen (whole-token units).
    uint256 public immutable basePriceNum;
    uint256 public immutable basePriceDen;
    /// @notice Curve steepness — k = kNum / kDen (e.g. 1/2 = 0.5).
    uint256 public immutable kNum;
    uint256 public immutable kDen;
    /// @notice Once `srxRaised` reaches this value, graduation unlocks.
    uint256 public immutable graduationSrxThreshold;
    /// @notice Trading-fee taker (in basis points; capped at 500 = 5%).
    address public immutable feeRecipient;
    uint256 public immutable feeBps;
    /// @notice Sentrix V2 router used for graduation. Pinned at construction
    ///         so a future router upgrade can't redirect graduation flow.
    address public immutable router;
    /// @notice WSRX address — needed by router.addLiquiditySRX. Pinned.
    address public immutable wsrx;

    /// @dev Hard cap on fees so a misconfigured deploy can't drain users.
    uint256 public constant MAX_FEE_BPS = 500; // 5%
    /// @dev Bound on basePriceNum × kNum so the curve-cost product stays
    ///      under 2^256 across the full supply range (see _curveCost notes).
    uint256 public constant MAX_PRICE_NUM = 1e18;
    uint256 public constant MAX_K_NUM = 1e3;
    uint256 public constant MAX_CURVE_SUPPLY = 1e30; // 1T tokens × 1e18

    // ── Mutable curve state ───────────────────────────────────────────
    /// @notice Tokens currently held by buyers (= curveSupply - balanceOf(this)).
    uint256 public tokensSold;
    /// @notice Cumulative native SRX received (net of fees + sells).
    uint256 public srxRaised;
    /// @notice Latched true after graduate() runs. Locks buy/sell forever.
    bool public graduated;

    /// @dev Reentrancy lock — initialised to 1 so the first acquire is cheap.
    uint256 private _locked = 1;

    // ── Events ────────────────────────────────────────────────────────
    event Buy(address indexed buyer, uint256 srxIn, uint256 fee, uint256 tokensOut);
    event Sell(address indexed seller, uint256 tokensIn, uint256 fee, uint256 srxOut);
    event Graduated(address indexed pair, uint256 srxLiquidity, uint256 tokenLiquidity, uint256 lpBurned);

    // ── Errors ────────────────────────────────────────────────────────
    error AlreadyGraduated();
    error NotGraduatable();
    error ZeroValue();
    error Slippage();
    error InsufficientReserve();
    error TransferFailed();
    error Reentrancy();
    error FeeTooHigh();
    error InvalidParams();

    modifier nonReentrant() {
        if (_locked != 1) revert Reentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }

    modifier active() {
        if (graduated) revert AlreadyGraduated();
        _;
    }

    /// @notice One-shot construction parameters — packed into a struct so the
    ///         constructor stays under solc's stack-depth limit (12 args
    ///         tripped the EVM-stack frame for the via-Yul codegen).
    struct InitParams {
        string name;
        string symbol;
        uint256 curveSupply;
        uint256 basePriceNum;
        uint256 basePriceDen;
        uint256 kNum;
        uint256 kDen;
        uint256 graduationSrxThreshold;
        address feeRecipient;
        uint256 feeBps;
        address router;
        address wsrx;
    }

    // ── Construction ──────────────────────────────────────────────────
    constructor(InitParams memory p) {
        if (p.curveSupply == 0 || p.basePriceDen == 0 || p.kDen == 0) revert InvalidParams();
        if (p.graduationSrxThreshold == 0) revert InvalidParams();
        if (p.router == address(0) || p.wsrx == address(0) || p.feeRecipient == address(0)) revert InvalidParams();
        if (p.feeBps > MAX_FEE_BPS) revert FeeTooHigh();
        // Magnitude bounds — see _curveCost. Without these, the slope-term
        // product can overflow uint256 for extreme parameter combinations.
        if (p.basePriceNum > MAX_PRICE_NUM || p.kNum > MAX_K_NUM) revert InvalidParams();
        if (p.curveSupply > MAX_CURVE_SUPPLY) revert InvalidParams();

        token = new FactoryToken(p.name, p.symbol, p.curveSupply, address(this));
        curveSupply = p.curveSupply;
        basePriceNum = p.basePriceNum;
        basePriceDen = p.basePriceDen;
        kNum = p.kNum;
        kDen = p.kDen;
        graduationSrxThreshold = p.graduationSrxThreshold;
        feeRecipient = p.feeRecipient;
        feeBps = p.feeBps;
        router = p.router;
        wsrx = p.wsrx;
    }

    // ── Curve math ────────────────────────────────────────────────────
    //
    // Linear curve: P(s) = (basePriceNum / basePriceDen) × (1 + (kNum/kDen) × s / curveSupply)
    //
    // Cost to move from `a` tokens-sold to `b` tokens-sold (with b > a):
    //   ∫[a,b] P(s) ds
    //   = (basePriceNum / basePriceDen) × (b − a)                                 // base term
    //     + (basePriceNum / basePriceDen) × (kNum / kDen) × (b² − a²) / (2 × curveSupply)  // slope term
    //
    // We multiply through to keep everything in SRX-wei and uint256-safe. With
    // curveSupply ≤ 1e30 (1B tokens × 1e18), b² ≤ 1e60 still fits into uint256.

    /// @notice SRX-wei cost to move from `a` to `b` tokens (b ≥ a, both in token-wei).
    /// @dev    Linear bonding curve P(s) = P0 × (1 + K × s/S) integrates to:
    ///           Cost = P0 × Δ + P0 × K × Δ × (a+b) / (2S)
    ///         where Δ = b - a, S = curveSupply.
    ///
    ///         To avoid uint256 overflow on the slope term we apply the
    ///         constructor-enforced bounds:
    ///             basePriceNum ≤ 1e18, kNum ≤ 1e3, curveSupply ≤ 1e30
    ///         The largest intermediate is `basePriceNum × kNum × delta × sum`
    ///         which is ≤ 1e18 × 1e3 × 1e30 × 2e30 = 2e81 — ABOVE 2^256.
    ///         So we factor and divide eagerly: compute `delta × sum / (2S)`
    ///         first (≤ S = 1e30, safe), then multiply by `basePriceNum × kNum`
    ///         (≤ 1e21), giving a final ≤ 1e51 → safe.
    function _curveCost(uint256 a, uint256 b) internal view returns (uint256) {
        if (b <= a) return 0;
        uint256 delta = b - a;

        // Base term: P0 × Δ
        uint256 baseTerm = (basePriceNum * delta) / basePriceDen;

        // Slope term in three steps with eager division to keep intermediates
        // bounded:
        //   step1 = (delta × (a + b)) / (2 × curveSupply)        ≤ curveSupply
        //   step2 = step1 × basePriceNum × kNum                   ≤ 1e51
        //   step3 = step2 / (basePriceDen × kDen)                 = result
        //
        // Two ordering caveats:
        //   - delta × (a + b) can reach 2 × curveSupply² = 2 × 1e60. Still
        //     under 2^256 (≈ 1.16e77), so the multiplication itself is safe.
        //   - Eager division by (2 × curveSupply) discards up to (2S - 1)
        //     wei of precision per term. Test suite asserts settlement
        //     within ≤ 1 wei of the TS reference for typical params.
        uint256 sum = a + b;
        uint256 slopeTerm = (delta * sum) / (2 * curveSupply);
        slopeTerm = slopeTerm * basePriceNum;
        slopeTerm = (slopeTerm * kNum) / (basePriceDen * kDen);

        return baseTerm + slopeTerm;
    }

    /// @notice Cost in SRX-wei for buying enough tokens to move from
    ///         `tokensSold` → `tokensSold + tokensOut`. View helper.
    function quoteBuy(uint256 tokensOut) public view returns (uint256 grossSrxIn, uint256 fee) {
        if (tokensOut == 0) return (0, 0);
        if (tokensSold + tokensOut > curveSupply) revert InsufficientReserve();
        uint256 baseCost = _curveCost(tokensSold, tokensSold + tokensOut);
        // Fee is taken on top of the curve cost so the user pays
        // grossSrxIn = baseCost + fee.
        fee = (baseCost * feeBps) / (10_000 - feeBps);
        grossSrxIn = baseCost + fee;
    }

    /// @notice Tokens received when selling along the curve.
    function quoteSell(uint256 tokensIn) public view returns (uint256 srxOut, uint256 fee) {
        if (tokensIn == 0) return (0, 0);
        if (tokensIn > tokensSold) revert InsufficientReserve();
        uint256 baseRefund = _curveCost(tokensSold - tokensIn, tokensSold);
        fee = (baseRefund * feeBps) / 10_000;
        srxOut = baseRefund - fee;
    }

    // ── Trade entrypoints ─────────────────────────────────────────────

    /// @notice Buy along the curve. Caller specifies `minTokensOut` for slippage
    ///         protection. Excess SRX is refunded.
    function buy(uint256 minTokensOut) external payable active nonReentrant returns (uint256 tokensOut) {
        if (msg.value == 0) revert ZeroValue();

        // Binary search for the largest tokensOut such that quoteBuy(tokensOut) ≤ msg.value.
        // For a strictly-monotone-increasing curve this converges in ≤256 iterations.
        uint256 lo = 0;
        uint256 hi = curveSupply - tokensSold;
        while (lo < hi) {
            uint256 mid = lo + (hi - lo + 1) / 2;
            (uint256 cost,) = quoteBuy(mid);
            if (cost <= msg.value) lo = mid;
            else hi = mid - 1;
        }
        tokensOut = lo;
        if (tokensOut < minTokensOut) revert Slippage();
        if (tokensOut == 0) revert ZeroValue();

        (uint256 grossPaid, uint256 fee) = quoteBuy(tokensOut);

        tokensSold += tokensOut;
        srxRaised += (grossPaid - fee);

        // Forward fee to recipient; refund any dust to buyer.
        if (fee > 0) _safeSendSRX(feeRecipient, fee);
        uint256 refund = msg.value - grossPaid;
        if (refund > 0) _safeSendSRX(msg.sender, refund);

        require(token.transfer(msg.sender, tokensOut), "CoinBlast: TOKEN_TRANSFER");

        emit Buy(msg.sender, grossPaid, fee, tokensOut);
    }

    /// @notice Sell tokens back along the curve. Caller must have approved
    ///         the curve for `tokensIn` beforehand.
    function sell(uint256 tokensIn, uint256 minSrxOut)
        external
        active
        nonReentrant
        returns (uint256 srxOut)
    {
        if (tokensIn == 0) revert ZeroValue();
        (uint256 srxNet, uint256 fee) = quoteSell(tokensIn);
        if (srxNet < minSrxOut) revert Slippage();

        require(token.transferFrom(msg.sender, address(this), tokensIn), "CoinBlast: TOKEN_TRANSFER_FROM");
        tokensSold -= tokensIn;
        srxRaised -= (srxNet + fee);

        if (fee > 0) _safeSendSRX(feeRecipient, fee);
        _safeSendSRX(msg.sender, srxNet);

        emit Sell(msg.sender, tokensIn, fee, srxNet);
        srxOut = srxNet;
    }

    // ── Graduation ────────────────────────────────────────────────────

    /// @notice Anyone may trigger graduation once the SRX raised meets the
    ///         threshold. Migrates raised SRX + remaining tokens into a fresh
    ///         Sentrix V2 pool and burns the LP forever.
    function graduate() external active nonReentrant {
        if (srxRaised < graduationSrxThreshold) revert NotGraduatable();
        graduated = true;

        uint256 tokenLiquidity = token.balanceOf(address(this));
        // Surfaced during testnet smoke 2026-05-01: integer rounding inside
        // quoteBuy/quoteSell can leave srxRaised a few wei *above* the
        // actual native balance (the fee math discards sub-wei lossage on
        // each trade, accumulated). Sourcing srxLiquidity from
        // address(this).balance avoids router.call{value: srxLiquidity}
        // reverting with insufficient-native-funds at the very last step.
        // We still zero srxRaised so any future read sees 0 — the curve
        // is graduated either way.
        uint256 srxLiquidity = address(this).balance;
        srxRaised = 0;

        // Approve router to pull tokens, then add liquidity. LP receipt is
        // sent to address(0) → permanently locked.
        require(token.approve(router, tokenLiquidity), "CoinBlast: APPROVE");
        (bool ok, bytes memory ret) = router.call{value: srxLiquidity}(
            abi.encodeWithSignature(
                "addLiquiditySRX(address,uint256,uint256,uint256,address,uint256)",
                address(token),
                tokenLiquidity,
                tokenLiquidity, // accept any positive token amount (we control supply)
                srxLiquidity,    // accept any positive SRX amount (we control raise)
                address(0xdEaD),  // LP receipt destination — burnt forever
                block.timestamp + 1 hours
            )
        );
        require(ok, "CoinBlast: ADD_LIQUIDITY");
        // ret = (uint amountToken, uint amountSRX, uint liquidity); we only
        // need the LP amount for the event log.
        (,, uint256 lpBurned) = abi.decode(ret, (uint256, uint256, uint256));

        // Compute the deterministic pair address by reading the factory off the
        // router. Done after the router call so we know the pair definitely
        // exists.
        (bool fOk, bytes memory fRet) = router.staticcall(abi.encodeWithSignature("factory()"));
        require(fOk, "CoinBlast: FACTORY_LOOKUP");
        address factoryAddr = abi.decode(fRet, (address));
        (bool pOk, bytes memory pRet) =
            factoryAddr.staticcall(abi.encodeWithSignature("getPair(address,address)", address(token), wsrx));
        require(pOk, "CoinBlast: PAIR_LOOKUP");
        address pair = abi.decode(pRet, (address));

        emit Graduated(pair, srxLiquidity, tokenLiquidity, lpBurned);
    }

    // ── Internal helpers ──────────────────────────────────────────────
    function _safeSendSRX(address to, uint256 amount) internal {
        (bool ok,) = to.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    // Reject stray native SRX so accidental sends don't pollute the curve's
    // accounting. Buyers must use buy().
    receive() external payable {
        if (msg.sender != router) revert TransferFailed();
    }
}
