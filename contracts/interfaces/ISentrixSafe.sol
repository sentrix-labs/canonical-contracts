// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

/// @title ISentrixSafe
/// @author Sentrix Labs
/// @notice Minimal multi-signature wallet interface. Owners sign tx hashes
///         off-chain; on-chain `execTransaction` verifies threshold + nonce.
interface ISentrixSafe {
    event ExecutionSuccess(bytes32 indexed txHash, uint256 nonce);
    event ExecutionFailure(bytes32 indexed txHash, uint256 nonce);
    event AddedOwner(address indexed owner);
    event RemovedOwner(address indexed owner);
    event ChangedThreshold(uint256 threshold);

    function threshold() external view returns (uint256);
    function nonce() external view returns (uint256);
    function isOwner(address owner) external view returns (bool);
    function getOwners() external view returns (address[] memory);

    /// @notice Execute a tx with `threshold` signatures.
    /// @param to Target address.
    /// @param value Native value (wei) to send.
    /// @param data Calldata.
    /// @param operation 0 = call, 1 = delegatecall.
    /// @param signatures Concatenated 65-byte ECDSA signatures, sorted by signer ascending.
    /// @return success True if the execution succeeded.
    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        uint256 operation,
        bytes calldata signatures
    ) external returns (bool success);

    function getTransactionHash(
        address to,
        uint256 value,
        bytes calldata data,
        uint256 operation,
        uint256 _nonce
    ) external view returns (bytes32);
}
