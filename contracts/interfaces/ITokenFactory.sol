// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

/// @title ITokenFactory
/// @author Sentrix Labs
/// @notice Deploys minimal ERC-20 tokens. One-call factory; emits TokenDeployed.
interface ITokenFactory {
    event TokenDeployed(
        address indexed token,
        address indexed owner,
        string name,
        string symbol,
        uint256 initialSupply
    );

    /// @notice Deploy a new ERC-20 with `initialSupply` minted to caller.
    /// @return token Address of the new ERC-20 contract.
    function deployToken(string calldata name, string calldata symbol, uint256 initialSupply)
        external
        returns (address token);

    /// @notice Returns all tokens deployed by `owner`.
    function tokensOf(address owner) external view returns (address[] memory);

    /// @notice Number of tokens deployed by `owner`.
    function tokenCount(address owner) external view returns (uint256);
}
