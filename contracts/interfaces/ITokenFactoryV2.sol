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
        uint256 initialSupply,
        uint256 cap
    );

    /// @notice Deploy a new FactoryTokenV2 with `initialSupply` minted to caller.
    /// @param cap Maximum total supply (0 = unlimited).
    /// @return token Address of the new FactoryTokenV2.
    function deployToken(
        string calldata name,
        string calldata symbol,
        uint256 initialSupply,
        uint256 cap
    ) external returns (address token);

    /// @notice Returns all tokens deployed by `owner`.
    function tokensOf(address owner) external view returns (address[] memory);

    /// @notice Number of tokens deployed by `owner`.
    function tokenCount(address owner) external view returns (uint256);
}
