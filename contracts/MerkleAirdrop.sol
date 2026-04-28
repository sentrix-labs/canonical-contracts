// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

/// @title MerkleAirdrop
/// @author Sentrix Labs
/// @notice Generic merkle-tree airdrop claim contract for Sentrix airdrop phases.
/// @dev Minimal & immutable: deploy with merkle root + total amount, pre-fund with
///      native SRX, recipients claim with a merkle proof. After the claim window
///      expires, the owner sweeps unclaimed balance back to a configured recipient.
///
///      Designed for one phase per deploy — Phase 1 (Testnet Heroes) gets its own
///      MerkleAirdrop instance pre-funded from Strategic Reserve. Subsequent phases
///      deploy fresh instances.
///
///      Tree leaf format: keccak256(abi.encodePacked(address, uint256))
///      Proof verification follows OpenZeppelin's MerkleProof convention
///      (sorted siblings).
contract MerkleAirdrop {
    // ── Immutable config ─────────────────────────────────────
    bytes32 public immutable merkleRoot;
    uint256 public immutable claimDeadline; // unix timestamp; after this, no more claims
    address public immutable sweepRecipient; // where unclaimed SRX returns (e.g. Strategic Reserve)
    address public immutable owner; // address allowed to call sweep() after deadline

    // ── State ────────────────────────────────────────────────
    /// @dev address => has-claimed flag
    mapping(address => bool) public claimed;

    /// @dev cumulative claimed amount (for accounting / introspection)
    uint256 public totalClaimed;

    /// @dev set true after sweep() is called; locks any further state changes
    bool public swept;

    // ── Events ───────────────────────────────────────────────
    event Claimed(address indexed recipient, uint256 amount);
    event Swept(address indexed recipient, uint256 amount);

    // ── Errors ───────────────────────────────────────────────
    error AlreadyClaimed();
    error InvalidProof();
    error ClaimWindowClosed();
    error ClaimWindowOpen();
    error AlreadySwept();
    error NotOwner();
    error TransferFailed();
    error ZeroAddress();

    // ── Constructor ──────────────────────────────────────────
    /// @param _merkleRoot Root of the airdrop merkle tree. Leaves are
    ///        `keccak256(abi.encodePacked(address, uint256))` sorted-pair internal hashes.
    /// @param _claimDeadline Unix timestamp after which claims are rejected.
    /// @param _sweepRecipient Address that receives unclaimed balance after sweep().
    /// @param _owner Address allowed to call sweep() after deadline (typically SentrixSafe).
    constructor(
        bytes32 _merkleRoot,
        uint256 _claimDeadline,
        address _sweepRecipient,
        address _owner
    ) {
        if (_sweepRecipient == address(0)) revert ZeroAddress();
        if (_owner == address(0)) revert ZeroAddress();
        merkleRoot = _merkleRoot;
        claimDeadline = _claimDeadline;
        sweepRecipient = _sweepRecipient;
        owner = _owner;
    }

    // ── Pre-fund ─────────────────────────────────────────────
    /// @notice Anyone can fund the contract by sending SRX to it.
    ///         Typically the Strategic Reserve owner pre-funds at deploy time.
    receive() external payable {}

    // ── Claim ────────────────────────────────────────────────
    /// @notice Claim airdrop allocation by submitting a merkle proof.
    /// @param amount The allocated amount (in wei) for the calling address.
    /// @param proof Merkle proof showing `(msg.sender, amount)` is in the tree.
    function claim(uint256 amount, bytes32[] calldata proof) external {
        if (block.timestamp > claimDeadline) revert ClaimWindowClosed();
        if (claimed[msg.sender]) revert AlreadyClaimed();
        if (swept) revert AlreadySwept();

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount));
        if (!_verify(proof, merkleRoot, leaf)) revert InvalidProof();

        claimed[msg.sender] = true;
        totalClaimed += amount;

        (bool ok,) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit Claimed(msg.sender, amount);
    }

    // ── Sweep ────────────────────────────────────────────────
    /// @notice After claim window closes, sweep remaining balance to sweepRecipient.
    ///         Only callable by owner. Locks state to prevent re-sweep.
    function sweep() external {
        if (msg.sender != owner) revert NotOwner();
        if (block.timestamp <= claimDeadline) revert ClaimWindowOpen();
        if (swept) revert AlreadySwept();

        swept = true;

        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool ok,) = sweepRecipient.call{value: balance}("");
            if (!ok) revert TransferFailed();
        }

        emit Swept(sweepRecipient, balance);
    }

    // ── View helpers ─────────────────────────────────────────
    /// @notice Check whether `account` is eligible (proof valid) without claiming.
    function isEligible(address account, uint256 amount, bytes32[] calldata proof)
        external
        view
        returns (bool)
    {
        bytes32 leaf = keccak256(abi.encodePacked(account, amount));
        return _verify(proof, merkleRoot, leaf);
    }

    // ── Merkle verification (OpenZeppelin-compatible sorted siblings) ──
    function _verify(bytes32[] calldata proof, bytes32 root, bytes32 leaf)
        private
        pure
        returns (bool)
    {
        bytes32 computed = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 sibling = proof[i];
            if (computed < sibling) {
                computed = keccak256(abi.encodePacked(computed, sibling));
            } else {
                computed = keccak256(abi.encodePacked(sibling, computed));
            }
        }
        return computed == root;
    }
}
