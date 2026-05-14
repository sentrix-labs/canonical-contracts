// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

/// @title SentrixSafe
/// @author Sentrix Labs
/// @notice Minimal multi-signature wallet for treasury management.
/// @dev Inspired by Gnosis Safe v1.4.1 but trimmed to the
///      execute-from-N-of-M-owners core. No modules, no guards,
///      no fallback handlers - those are out of scope for canonical
///      treasury use. Owners sign tx hashes off-chain (EIP-712 typed
///      hashing); on-chain `execTransaction` verifies threshold + nonce.
///
/// SECURITY (audit 2026-05-07 v1.1):
///   - C1: delegatecall path now properly copies calldata into memory before
///         the DELEGATECALL opcode. Pre-fix the assembly used `data.offset`
///         as a memory pointer, but DELEGATECALL reads from MEMORY not
///         CALLDATA — so owners signed one payload and the contract executed
///         arbitrary memory bytes (or reverted). FIXED.
///   - C2: full Safe.t.sol test suite added covering execTransaction,
///         signature verification, replay, delegatecall, owner management.
///   - H1: ExecutionFailure now reverts (instead of silently succeeding +
///         emitting an event) so callers can't be fooled into thinking a
///         failed treasury op succeeded.
///   - H2: DOMAIN_SEPARATOR rebuilds on chainid mismatch (replay-safe across
///         hard forks of the host chain).
///   - H3: removeOwner enforces threshold ≤ remaining-owners floor.
contract SentrixSafe {
    // ── Storage ──────────────────────────────────────────────
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public threshold;
    uint256 public nonce;

    // EIP-712 domain separator
    /// @dev Audit H2: cached at construction; if `block.chainid` ever differs
    ///      (i.e. the host chain hard-forks the chainid) we recompute on the
    ///      fly. The immutable cache stays as the fast path for the 99.99% case.
    bytes32 private immutable _CACHED_DOMAIN_SEPARATOR;
    uint256 private immutable _CACHED_CHAIN_ID;

    bytes32 private constant TX_TYPEHASH = keccak256(
        "SafeTx(address to,uint256 value,bytes data,uint256 operation,uint256 nonce)"
    );

    // ── Events ───────────────────────────────────────────────
    event ExecutionSuccess(bytes32 indexed txHash, uint256 nonce);
    event ExecutionFailure(bytes32 indexed txHash, uint256 nonce);
    event AddedOwner(address indexed owner);
    event RemovedOwner(address indexed owner);
    event ChangedThreshold(uint256 threshold);

    // ── Errors (audit 2026-05-13) ────────────────────────────
    /// @dev Audit M-Safe (MEDIUM): owners sign over `value` but DELEGATECALL
    ///      ignores msg.value at the opcode level (the executing code runs in
    ///      this Safe's context with this Safe's balance). Pre-fix the value
    ///      was silently dropped, so an N-of-M quorum could approve a
    ///      "send 1 ETH via delegatecall to X" payload, see ExecutionSuccess,
    ///      and never realise the transfer was a no-op. Reject at exec.
    error DelegateCallWithValue();

    // ── Constructor ──────────────────────────────────────────
    constructor(address[] memory _owners, uint256 _threshold) {
        require(_owners.length > 0, "Safe: no owners");
        require(_threshold > 0 && _threshold <= _owners.length, "Safe: invalid threshold");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0) && owner != address(this), "Safe: invalid owner");
            require(!isOwner[owner], "Safe: duplicate owner");
            isOwner[owner] = true;
            owners.push(owner);
            emit AddedOwner(owner);
        }
        threshold = _threshold;
        emit ChangedThreshold(_threshold);

        _CACHED_CHAIN_ID = block.chainid;
        _CACHED_DOMAIN_SEPARATOR = _buildDomainSeparator(block.chainid);
    }

    /// @dev Build the EIP-712 domain separator for a given chain id.
    ///      Audit H2: previously the constructor-built separator was
    ///      cached as `immutable`; if the host chain ever changes its
    ///      chainid (hard fork or re-org) the cached value would be
    ///      stale and signatures would fail to verify even with the
    ///      same (chainId, verifyingContract) intent. We rebuild on
    ///      mismatch.
    function _buildDomainSeparator(uint256 chainId) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("SentrixSafe")),
                keccak256(bytes("1.1")),
                chainId,
                address(this)
            )
        );
    }

    /// @notice Public domain separator, recomputed if host chainid drifted.
    /// @dev Audit H2 fix.
    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        if (block.chainid == _CACHED_CHAIN_ID) {
            return _CACHED_DOMAIN_SEPARATOR;
        }
        return _buildDomainSeparator(block.chainid);
    }

    // ── Core: execute with N-of-M signatures ─────────────────
    /// @notice Execute a transaction with `threshold` signatures.
    /// @param to Target address.
    /// @param value Native value (wei) to send.
    /// @param data Calldata.
    /// @param operation 0 = call, 1 = delegatecall.
    /// @param signatures Concatenated 65-byte ECDSA signatures, sorted by signer address ascending.
    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        uint256 operation,
        bytes calldata signatures
    ) external returns (bool success) {
        bytes32 txHash = getTransactionHash(to, value, data, operation, nonce);
        checkSignatures(txHash, signatures);
        nonce++;

        // Audit M-Safe (MEDIUM, 2026-05-13): reject the silent-value-drop
        // class. Owners sign over `value` but DELEGATECALL doesn't transfer.
        // If the intent was "transfer + delegatecall combined", the caller
        // should split into two ops (send via call, then delegatecall).
        if (operation == 1 && value != 0) revert DelegateCallWithValue();

        if (operation == 1) {
            // Audit C1 (CRITICAL, 2026-05-07): pre-fix this assembly used
            // `data.offset` (a CALLDATA offset) directly as the DELEGATECALL
            // argsOffset argument, but the DELEGATECALL opcode reads from
            // MEMORY. Owners signed one payload, the contract executed
            // arbitrary memory bytes — or reverted. FIX: copy calldata to
            // a fresh memory region first, then DELEGATECALL points at THAT.
            //
            // We use Solidity's standard pattern (`bytes memory`) which
            // does the calldatacopy + memory layout for free.
            bytes memory dataMem = data;
            assembly {
                // dataMem layout: [length (32 bytes)][bytes...]
                // argsOffset = dataMem + 32 (skip length prefix)
                // argsLength = mload(dataMem)
                let dataPtr := add(dataMem, 0x20)
                let dataLen := mload(dataMem)
                success := delegatecall(gas(), to, dataPtr, dataLen, 0, 0)
            }
        } else {
            (success, ) = to.call{value: value}(data);
        }

        if (success) {
            emit ExecutionSuccess(txHash, nonce - 1);
        } else {
            // Audit H1 (HIGH): pre-fix this only emitted ExecutionFailure +
            // returned `false`, so callers using the standard "(bool success
            // = safe.execTransaction(...))" pattern saw `success = false`
            // but no revert. A treasury op that failed silently would still
            // count as "executed" in audit logs — confusing at best.
            // Now revert with the inner-call's revert reason bubbled up.
            emit ExecutionFailure(txHash, nonce - 1);
            assembly {
                let returnSize := returndatasize()
                returndatacopy(0, 0, returnSize)
                revert(0, returnSize)
            }
        }
    }

    // ── Signature verification ───────────────────────────────
    function checkSignatures(bytes32 dataHash, bytes calldata signatures) public view {
        uint256 _threshold = threshold;
        require(signatures.length >= _threshold * 65, "Safe: signatures too short");

        address lastOwner = address(0);
        for (uint256 i = 0; i < _threshold; i++) {
            address currentOwner = recoverSigner(dataHash, signatures, i);
            require(currentOwner > lastOwner, "Safe: signatures not sorted");
            require(isOwner[currentOwner], "Safe: signer not owner");
            lastOwner = currentOwner;
        }
    }

    function recoverSigner(bytes32 dataHash, bytes calldata signatures, uint256 pos) internal pure returns (address) {
        uint8 v;
        bytes32 r;
        bytes32 s;
        assembly {
            let sigPtr := add(signatures.offset, mul(pos, 65))
            r := calldataload(sigPtr)
            s := calldataload(add(sigPtr, 32))
            v := byte(0, calldataload(add(sigPtr, 64)))
        }
        // Audit L-Safe (LOW, 2026-05-13): EIP-2 signature malleability.
        // ecrecover accepts both s and (n-s) as valid for the same message.
        // Without bounding s, the same approval can be re-encoded into a
        // distinct 65-byte blob; harmless here (nonce blocks replay) but
        // hygiene. v must be 27/28; pre-EIP-155 chain-id encoding rejected.
        require(uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0, "Safe: invalid s");
        require(v == 27 || v == 28, "Safe: invalid v");
        return ecrecover(dataHash, v, r, s);
    }

    function getTransactionHash(
        address to,
        uint256 value,
        bytes calldata data,
        uint256 operation,
        uint256 _nonce
    ) public view returns (bytes32) {
        bytes32 structHash = keccak256(abi.encode(
            TX_TYPEHASH,
            to,
            value,
            keccak256(data),
            operation,
            _nonce
        ));
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), structHash));
    }

    // ── Receive native SRX ──────────────────────────────────
    receive() external payable {}

    // ── Owner management (self-call only via execTransaction) ─
    /// @notice Add a new owner and optionally re-set the threshold.
    /// @dev Audit L-Safe (LOW, 2026-05-13): must be invoked via
    ///      execTransaction with operation=Operation.Call (i.e. operation=0);
    ///      delegatecall self-invocation will fail because msg.sender becomes
    ///      the owner EOA, not address(this), and the self-call guard rejects.
    function addOwner(address owner, uint256 _threshold) external {
        require(msg.sender == address(this), "Safe: self-call only");
        require(owner != address(0) && !isOwner[owner], "Safe: invalid or existing owner");
        isOwner[owner] = true;
        owners.push(owner);
        emit AddedOwner(owner);
        if (_threshold != threshold) {
            require(_threshold > 0 && _threshold <= owners.length, "Safe: invalid threshold");
            threshold = _threshold;
            emit ChangedThreshold(_threshold);
        }
    }

    /// @notice Remove an owner and optionally re-set the threshold.
    /// @dev Audit L-Safe (LOW, 2026-05-13): same call-only constraint as
    ///      addOwner. Must be invoked via execTransaction with
    ///      operation=Operation.Call (operation=0); delegatecall would make
    ///      msg.sender the owner EOA and fail the self-call guard.
    function removeOwner(address owner, uint256 _threshold) external {
        require(msg.sender == address(this), "Safe: self-call only");
        require(isOwner[owner], "Safe: not owner");
        // Audit H3 (HIGH): minimum-owner floor. Without this, a 1-of-N safe
        // could remove its only remaining owner and brick itself, OR a
        // 2-of-2 safe could remove an owner without lowering threshold and
        // brick itself (threshold > owners.length means no signature set
        // can verify). require(_threshold <= owners.length - 1) covers it.
        require(owners.length > 1, "Safe: cannot remove last owner");
        require(_threshold > 0, "Safe: invalid threshold");
        require(_threshold <= owners.length - 1, "Safe: threshold too high");

        isOwner[owner] = false;
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == owner) {
                owners[i] = owners[owners.length - 1];
                owners.pop();
                break;
            }
        }
        emit RemovedOwner(owner);

        if (_threshold != threshold) {
            threshold = _threshold;
            emit ChangedThreshold(_threshold);
        }
    }

    function getOwners() external view returns (address[] memory) {
        return owners;
    }
}
