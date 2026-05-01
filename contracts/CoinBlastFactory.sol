// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {CoinBlastCurve} from "./CoinBlastCurve.sol";

/// @title CoinBlastFactory
/// @author Sentrix Labs
/// @notice Canonical deployer for CoinBlast bonding-curve launches.
///         Wrapping CoinBlastCurve construction here means every
///         launch fires a single CurveCreated event from a known
///         contract, so any indexer / launchpad / explorer can scan
///         this one address to enumerate every curve on chain.
///         Without it, frontends would have to scrape per-curve
///         bytecode signatures across every block — tractable but
///         wasteful when one event source does the job.
///
/// @dev    The factory is a passthrough: createCurve() does
///         `new CoinBlastCurve(p)` and emits + records. Each curve
///         is its own contract; the factory holds no state for the
///         curve's trading logic. Constructor bounds + reentrancy
///         guards live on CoinBlastCurve as before.
contract CoinBlastFactory {
    /// @notice Every curve ever deployed through this factory, oldest first.
    address[] public allCurves;
    /// @dev    Curves grouped by msg.sender — i.e. the address that
    ///         called createCurve, NOT the address that ends up owning
    ///         the underlying ERC-20 supply (the curve itself owns it
    ///         per CoinBlastCurve's design).
    mapping(address => address[]) private _curvesOfOwner;

    /// @notice Fires once per createCurve call. Indexed fields cover
    ///         the lookups frontends need most: curve address, token
    ///         address, and the deploying EOA.
    event CurveCreated(
        address indexed curve,
        address indexed token,
        address indexed owner,
        string name,
        string symbol,
        uint256 curveSupply,
        uint256 graduationSrxThreshold
    );

    /// @notice Deploy a new CoinBlastCurve and register it. msg.sender
    ///         is recorded as the launcher; the curve itself owns the
    ///         token supply per CoinBlastCurve mechanics.
    function createCurve(CoinBlastCurve.InitParams memory p)
        external
        returns (CoinBlastCurve curve)
    {
        curve = new CoinBlastCurve(p);
        address curveAddr = address(curve);
        address tokenAddr = address(curve.token());
        allCurves.push(curveAddr);
        _curvesOfOwner[msg.sender].push(curveAddr);
        emit CurveCreated(
            curveAddr,
            tokenAddr,
            msg.sender,
            p.name,
            p.symbol,
            p.curveSupply,
            p.graduationSrxThreshold
        );
    }

    /// @notice All curves deployed by `owner` via this factory.
    function curvesOf(address owner) external view returns (address[] memory) {
        return _curvesOfOwner[owner];
    }

    /// @notice Total curves deployed via this factory.
    function totalCurves() external view returns (uint256) {
        return allCurves.length;
    }
}
