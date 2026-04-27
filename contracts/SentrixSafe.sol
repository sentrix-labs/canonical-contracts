// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

/// @title SentrixSafe
/// @notice Minimal multi-signature wallet for treasury management.
/// @dev Inspired by Gnosis Safe v1.4.1 but trimmed to the
///      execute-from-N-of-M-owners core. No modules, no guards,
///      no fallback handlers — those are out of scope for canonical
///      treasury use. Owners sign tx hashes off-chain (EIP-712 typed
///      hashing); on-chain `execTransaction` verifies threshold + nonce.
contract SentrixSafe {
    // ── Storage ──────────────────────────────────────────────
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public threshold;
    uint256 public nonce;

    // EIP-712 domain separator
    bytes32 public immutable DOMAIN_SEPARATOR;
    bytes32 private constant TX_TYPEHASH = keccak256(
        "SafeTx(address to,uint256 value,bytes data,uint256 operation,uint256 nonce)"
    );

    // ── Events ───────────────────────────────────────────────
    event ExecutionSuccess(bytes32 indexed txHash, uint256 nonce);
    event ExecutionFailure(bytes32 indexed txHash, uint256 nonce);
    event AddedOwner(address indexed owner);
    event RemovedOwner(address indexed owner);
    event ChangedThreshold(uint256 threshold);

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

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(uint256 chainId,address verifyingContract)"),
                block.chainid,
                address(this)
            )
        );
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

        if (operation == 1) {
            assembly {
                let dataPtr := add(data.offset, 0)
                success := delegatecall(gas(), to, dataPtr, data.length, 0, 0)
            }
        } else {
            (success, ) = to.call{value: value}(data);
        }

        if (success) {
            emit ExecutionSuccess(txHash, nonce - 1);
        } else {
            emit ExecutionFailure(txHash, nonce - 1);
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
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
    }

    // ── Receive native SRX ──────────────────────────────────
    receive() external payable {}

    // ── Owner management (self-call only via execTransaction) ─
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

    function removeOwner(address owner, uint256 _threshold) external {
        require(msg.sender == address(this), "Safe: self-call only");
        require(isOwner[owner], "Safe: not owner");
        require(owners.length - 1 >= _threshold, "Safe: threshold too high");

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
            require(_threshold > 0, "Safe: invalid threshold");
            threshold = _threshold;
            emit ChangedThreshold(_threshold);
        }
    }

    function getOwners() external view returns (address[] memory) {
        return owners;
    }
}
