// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title Vault4626
/// @notice Minimal canonical ERC-4626 vault for the Sentrix ecosystem.
///         Accepts an underlying ERC-20 asset and mints vault shares (1:1 start).
/// @dev OpenZeppelin-derived. No yield strategy — yield sources extend this.
///      Inflation-attack guard: deploys with a small dead-share mint to make
///      donation attacks unprofitable (virtual offset pattern).
contract Vault4626 is ERC4626 {
    using Math for uint256;

    /// @notice Emitted when the vault receives a donation (pure asset transfer, no shares minted).
    event Donation(address indexed donor, uint256 amount);

    error Vault4626__ZeroDeposit();

    /// @param _asset    Underlying ERC-20 token address.
    /// @param _name     Vault share token name.
    /// @param _symbol   Vault share token symbol.
    constructor(IERC20 _asset, string memory _name, string memory _symbol)
        ERC4626(_asset)
        ERC20(_name, _symbol)
    {
        // Inflation-attack guard: mint 1e3 dead shares to make donation attacks
        // prohibitively expensive. With a 1e3 share floor, an attacker needs
        // 1e3 * share_price of underlying to front-run, making the attack cost
        // exceed any reasonable first-deposit value.
        _mint(address(0xdead), 1e3);
    }

    // ─── Overrides for correct rounding ─────────────────────────────

    /// @inheritdoc ERC4626
    /// @dev Rounds UP (protects vault). Uses mulDiv with Math.Rounding.Ceil.
    function _convertToShares(uint256 assets, Math.Rounding rounding)
        internal
        view
        override
        returns (uint256)
    {
        uint256 supply = totalSupply();
        // If no live supply beyond our dead shares, shares = assets (1:1 after offset)
        if (supply == 1e3) return assets;

        return _tryMulDiv(assets, supply - 1e3, totalAssets(), rounding);
    }

    /// @inheritdoc ERC4626
    /// @dev Rounds DOWN (protects vault). Uses mulDiv with Math.Rounding.Floor.
    function _convertToAssets(uint256 shares, Math.Rounding rounding)
        internal
        view
        override
        returns (uint256)
    {
        uint256 supply = totalSupply();
        // If only dead shares exist, assets = shares (1:1)
        if (supply == 1e3) return shares;

        return _tryMulDiv(shares, totalAssets(), supply - 1e3, rounding);
    }

    /// @inheritdoc ERC4626
    function totalAssets() public view override returns (uint256) {
        return IERC20(asset()).balanceOf(address(this));
    }

    /// @inheritdoc ERC4626
    function maxDeposit(address) public view override returns (uint256) {
        return type(uint256).max;
    }

    /// @inheritdoc ERC4626
    function maxMint(address) public view override returns (uint256) {
        return type(uint256).max;
    }

    // ─── Hook pattern for yield extensions ──────────────────────────

    /// @notice Hook called after shares are minted (deposit/mint).
    /// @dev Override in yield-bearing children to route assets to strategies.
    function _afterDeposit(address caller, uint256 assets, uint256 shares) internal virtual {}

    /// @notice Hook called before shares are burned (withdraw/redeem).
    /// @dev Override in yield-bearing children to pull assets from strategies.
    function _beforeWithdraw(address caller, uint256 assets, uint256 shares) internal virtual {}

    // ─── Donation support ──────────────────────────────────────────

    /// @notice Donate underlying assets to the vault. No shares minted in return.
    ///         Donations increase the share price for all existing shareholders.
    function donate(uint256 assets) external {
        if (assets == 0) revert Vault4626__ZeroDeposit();
        SafeERC20.safeTransferFrom(IERC20(asset()), msg.sender, address(this), assets);
        emit Donation(msg.sender, assets);
    }

    // ─── Internal ──────────────────────────────────────────────────

    /// @dev Override deposit to call the after-hook.
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        SafeERC20.safeTransferFrom(IERC20(asset()), caller, address(this), assets);
        _mint(receiver, shares);
        _afterDeposit(caller, assets, shares);
        emit Deposit(caller, receiver, assets, shares);
    }

    /// @dev Override withdraw to call the before-hook.
    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        override
    {
        _beforeWithdraw(caller, assets, shares);
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }
        _burn(owner, shares);
        SafeERC20.safeTransfer(IERC20(asset()), receiver, assets);
        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    /// @dev Safe mulDiv that returns 0 when operands overflow, with configurable rounding.
    function _tryMulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator,
        Math.Rounding rounding
    ) internal pure returns (uint256) {
        if (denominator == 0) return 0;
        return x.mulDiv(y, denominator, rounding);
    }
}
