// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/// @title FactoryTokenV2
/// @notice Extended ERC-20 deployed by TokenFactoryV2.
///         Adds EIP-2612 Permit, optional supply cap, and freeze controls.
/// @dev Combines OpenZeppelin extensions for gasless approvals,
///      capped supply, and admin-pausable transfers.
contract FactoryTokenV2 is ERC20, ERC20Permit, ERC20Capped, Ownable, Pausable {
    error FactoryTokenV2__CapExceeded(uint256 cap, uint256 requested);

    /// @param _name         Token name
    /// @param _symbol       Token symbol
    /// @param _initialSupply Initial amount minted to deployer
    /// @param _cap          Maximum total supply (0 = unlimited)
    /// @param _owner        Admin address (pause, unpause, ownership)
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply,
        uint256 _cap,
        address _owner
    )
        ERC20(_name, _symbol)
        ERC20Permit(_name)
        ERC20Capped(_cap == 0 ? type(uint256).max : _cap)
        Ownable(_owner)
    {
        // _cap == 0 means unlimited — max uint256 cap is effectively unlimited.
        if (_initialSupply > 0) {
            _mint(_owner, _initialSupply);
        }
    }

    // ─── Pause controls ────────────────────────────────────────────

    /// @notice Pause all token transfers. Only owner.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause token transfers. Only owner.
    function unpause() external onlyOwner {
        _unpause();
    }

    // ─── Supply cap override ───────────────────────────────────────

    /// @notice Mint new tokens up to the supply cap. Only owner.
    /// @dev Reverts if mint would exceed cap.
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    // ─── Internal overrides ────────────────────────────────────────

    /// @dev Hook into ERC20 _update: enforce cap + pause on all transfers.
    ///      Pausable v5.3.0 uses modifier pattern, not _update override,
    ///      so we call _requireNotPaused() manually.
    function _update(
        address from,
        address to,
        uint256 value
    )
        internal
        override(ERC20, ERC20Capped)
    {
        _requireNotPaused();
        super._update(from, to, value);
    }

    /// @notice Returns the current supply cap. Max uint256 = unlimited.
    /// @dev Exposed for transparency. Use `isCapped()` to check if a cap is set.
    function cap() public view override(ERC20Capped) returns (uint256) {
        return ERC20Capped.cap();
    }

    /// @notice Returns true if a supply cap is enforced.
    function isCapped() public view returns (bool) {
        return ERC20Capped.cap() != type(uint256).max;
    }
}
