// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

/// @title ITokenFactoryV2
/// @author Sentrix Labs
/// @notice Deploys extended ERC-20 tokens with Permit, optional supply cap,
///         and freeze controls.
interface ITokenFactoryV2 {
    event TokenDeployed(
        address indexed token,
        address indexed owner,
        string name,
        string symbol,
        uint8 decimals,
        uint256 initialSupply,
        uint256 cap,
        bool permitEnabled,
        bool pauseEnabled
    );

    /// @notice Deploy a new FactoryTokenV2 with `initialSupply` minted to caller.
    /// @param name          Token name (1-64 chars)
    /// @param symbol        Token symbol (1-16 chars)
    /// @param decimals_     Token decimals (e.g. 18)
    /// @param initialSupply Amount minted to `msg.sender` on deploy
    /// @param cap           Maximum total supply (0 = unlimited)
    /// @param permitEnabled Whether EIP-2612 permit is enabled
    /// @param pauseEnabled  Whether admin-pause is enabled
    /// @return token        Address of the new FactoryTokenV2
    function deployToken(
        string calldata name,
        string calldata symbol,
        uint8 decimals_,
        uint256 initialSupply,
        uint256 cap,
        bool permitEnabled,
        bool pauseEnabled
    ) external returns (address token);

    /// @notice Returns all tokens deployed by `owner`.
    function tokensOf(address owner) external view returns (address[] memory);

    /// @notice Number of tokens deployed by `owner`.
    function tokenCount(address owner) external view returns (uint256);
}
