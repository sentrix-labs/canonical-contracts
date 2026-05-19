// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {FactoryTokenV2} from "./FactoryTokenV2.sol";
import {ITokenFactoryV2} from "./interfaces/ITokenFactoryV2.sol";

/// @title Sentrix TokenFactoryV2
/// @author Sentrix Labs
/// @notice Deploys extended ERC-20 tokens with Permit, optional supply cap,
///         and freeze controls. Sits next to TokenFactory (v1), not replacing it.
/// @dev Tracks deployed-token-by-deployer for discovery.
contract TokenFactoryV2 is ITokenFactoryV2 {
    uint256 public constant MAX_NAME_LENGTH = 64;
    uint256 public constant MAX_SYMBOL_LENGTH = 16;

    mapping(address => address[]) public deployedTokens;

    /// @notice Deploy a new FactoryTokenV2.
    /// @param name          Token name
    /// @param symbol        Token symbol
    /// @param decimals_     Token decimals (e.g. 18)
    /// @param initialSupply Amount minted to `msg.sender` on deploy
    /// @param cap           Maximum total supply (0 = unlimited)
    /// @param permitEnabled Whether EIP-2612 permit is enabled
    /// @param pauseEnabled  Whether admin-pause controls are enabled
    /// @return token        Address of the new FactoryTokenV2
    function deployToken(
        string calldata name,
        string calldata symbol,
        uint8 decimals_,
        uint256 initialSupply,
        uint256 cap,
        bool permitEnabled,
        bool pauseEnabled
    ) external returns (address token) {
        require(bytes(name).length > 0 && bytes(name).length <= MAX_NAME_LENGTH, "TokenFactoryV2: BAD_NAME");
        require(bytes(symbol).length > 0 && bytes(symbol).length <= MAX_SYMBOL_LENGTH, "TokenFactoryV2: BAD_SYMBOL");

        // If cap is set, initialSupply must not exceed it.
        if (cap > 0) {
            require(initialSupply <= cap, "TokenFactoryV2: CAP_EXCEEDED");
        }

        FactoryTokenV2 t = new FactoryTokenV2(
            name, symbol, decimals_, initialSupply, cap, msg.sender,
            permitEnabled, pauseEnabled
        );
        token = address(t);
        deployedTokens[msg.sender].push(token);
        emit TokenDeployed(
            token, msg.sender, name, symbol, decimals_,
            initialSupply, cap, permitEnabled, pauseEnabled
        );
    }

    /// @notice All tokens deployed by `owner`.
    function tokensOf(address owner) external view returns (address[] memory) {
        return deployedTokens[owner];
    }

    /// @notice Number of tokens deployed by `owner`.
    function tokenCount(address owner) external view returns (uint256) {
        return deployedTokens[owner].length;
    }
}
