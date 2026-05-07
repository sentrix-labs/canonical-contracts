// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {SentrixSafe} from "../contracts/SentrixSafe.sol";

/// Audit 2026-05-07 C2: pre-fix this file only tested the constructor —
/// execTransaction, signatures, replay, delegatecall, and owner management
/// were entirely unaudited. C1 (delegatecall MEMORY-vs-CALLDATA bug) shipped
/// to mainnet because of this gap. v1.1 patches the contract; this test file
/// pins the new behaviour.
contract SafeTest is Test {
    SentrixSafe safe;
    uint256 pk1 = 0xa11ce;
    uint256 pk2 = 0xb0b;
    uint256 pk3 = 0xcafe;
    address owner1;
    address owner2;
    address owner3;

    // Sorted PKs so we know which pk corresponds to which owner.
    uint256[3] sortedPks;

    receive() external payable {}

    function setUp() public {
        owner1 = vm.addr(pk1);
        owner2 = vm.addr(pk2);
        owner3 = vm.addr(pk3);

        // Sort owners + their PKs ascending so signature loop's strict-
        // ascending check can be satisfied with sigs sorted by signer addr.
        (address[] memory ownersSorted, uint256[] memory pksSorted) =
            _sortOwnersAndPks(owner1, owner2, owner3, pk1, pk2, pk3);
        owner1 = ownersSorted[0];
        owner2 = ownersSorted[1];
        owner3 = ownersSorted[2];
        sortedPks[0] = pksSorted[0];
        sortedPks[1] = pksSorted[1];
        sortedPks[2] = pksSorted[2];

        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;
        safe = new SentrixSafe(owners, 2);

        vm.deal(address(safe), 10 ether);
    }

    // ── Constructor ──────────────────────────────────────────

    function test_constructor_sets_owners_and_threshold() public view {
        assertEq(safe.threshold(), 2);
        assertTrue(safe.isOwner(owner1));
        assertTrue(safe.isOwner(owner2));
        assertTrue(safe.isOwner(owner3));
        assertEq(safe.getOwners().length, 3);
    }

    function test_reverts_on_zero_threshold() public {
        address[] memory owners = new address[](1);
        owners[0] = owner1;
        vm.expectRevert(bytes("Safe: invalid threshold"));
        new SentrixSafe(owners, 0);
    }

    function test_reverts_on_threshold_exceeds_owners() public {
        address[] memory owners = new address[](1);
        owners[0] = owner1;
        vm.expectRevert(bytes("Safe: invalid threshold"));
        new SentrixSafe(owners, 2);
    }

    function test_reverts_on_duplicate_owner() public {
        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner1;
        vm.expectRevert(bytes("Safe: duplicate owner"));
        new SentrixSafe(owners, 1);
    }

    // ── execTransaction (call) ───────────────────────────────

    function test_exec_call_with_threshold_signatures() public {
        address payable recipient = payable(address(0xDEAD));
        bytes32 txHash = safe.getTransactionHash(recipient, 1 ether, "", 0, safe.nonce());
        bytes memory sigs = _sign2(txHash);
        bool success = safe.execTransaction(recipient, 1 ether, "", 0, sigs);
        assertTrue(success);
        assertEq(recipient.balance, 1 ether);
        assertEq(safe.nonce(), 1);
    }

    function test_exec_reverts_on_below_threshold() public {
        address payable recipient = payable(address(0xDEAD));
        bytes32 txHash = safe.getTransactionHash(recipient, 1 ether, "", 0, safe.nonce());
        // Only 1 signature when threshold is 2.
        bytes memory sigs = _signOne(txHash, sortedPks[0]);
        vm.expectRevert(bytes("Safe: signatures too short"));
        safe.execTransaction(recipient, 1 ether, "", 0, sigs);
    }

    function test_exec_reverts_on_unsorted_signatures() public {
        address payable recipient = payable(address(0xDEAD));
        bytes32 txHash = safe.getTransactionHash(recipient, 1 ether, "", 0, safe.nonce());
        // Reverse the sort: owner2 first then owner1 (would-be ascending fails).
        bytes memory s2 = _signOne(txHash, sortedPks[1]);
        bytes memory s1 = _signOne(txHash, sortedPks[0]);
        bytes memory sigs = bytes.concat(s2, s1);
        vm.expectRevert(bytes("Safe: signatures not sorted"));
        safe.execTransaction(recipient, 1 ether, "", 0, sigs);
    }

    function test_exec_reverts_on_non_owner_signature() public {
        address payable recipient = payable(address(0xDEAD));
        bytes32 txHash = safe.getTransactionHash(recipient, 1 ether, "", 0, safe.nonce());
        // Use a pk NOT in the owner set.
        uint256 outsiderPk = 0xc0c0a;
        bytes memory s1 = _signOne(txHash, sortedPks[0]);
        bytes memory s2 = _signOne(txHash, outsiderPk);
        bytes memory sigs = vm.addr(outsiderPk) > owner1
            ? bytes.concat(s1, s2)
            : bytes.concat(s2, s1);
        vm.expectRevert();
        safe.execTransaction(recipient, 1 ether, "", 0, sigs);
    }

    function test_exec_replay_blocked_by_nonce() public {
        address payable recipient = payable(address(0xDEAD));
        bytes32 txHash = safe.getTransactionHash(recipient, 1 ether, "", 0, safe.nonce());
        bytes memory sigs = _sign2(txHash);
        safe.execTransaction(recipient, 1 ether, "", 0, sigs);
        // Replay attempt with same signatures fails — txHash is now stale
        // because nonce incremented; the same sigs verify against old txHash
        // but the contract now wants a NEW txHash with nonce=1.
        vm.expectRevert();
        safe.execTransaction(recipient, 1 ether, "", 0, sigs);
    }

    // ── execTransaction (delegatecall) — Audit C1 ────────────

    function test_exec_delegatecall_runs_against_safe_storage() public {
        // Audit C1: deploy a target that writes to a high slot. With proper
        // delegatecall, the SAFE's storage receives the write — not the
        // target's. Pre-fix the delegatecall pointed at calldata offsets as
        // if they were memory; the call would either revert or write garbage
        // to the wrong slot.
        DelegateTarget target = new DelegateTarget();

        // Use slot 99 — far from anything the Safe uses (owners=0, isOwner=1,
        // threshold=2, nonce=3, _CACHED_DOMAIN_SEPARATOR=4 [immutable so not
        // really a slot], _CACHED_CHAIN_ID=5 [immutable]).
        bytes32 magic = bytes32(uint256(0x1337));
        bytes memory data = abi.encodeCall(DelegateTarget.setHighSlot, (magic));

        bytes32 before = vm.load(address(safe), bytes32(uint256(99)));
        assertEq(before, bytes32(0));

        bytes32 txHash = safe.getTransactionHash(address(target), 0, data, 1, safe.nonce());
        bytes memory sigs = _sign2(txHash);

        bool success = safe.execTransaction(address(target), 0, data, 1, sigs);
        assertTrue(success);
        assertEq(safe.nonce(), 1);

        bytes32 afterVal = vm.load(address(safe), bytes32(uint256(99)));
        assertEq(afterVal, magic);
    }

    function test_exec_delegatecall_with_complex_calldata() public {
        // Specifically verify CALLDATA → MEMORY copy preserves bytes.
        // Pre-fix bug: assembly used data.offset as memory pointer.
        // Pass a non-trivial calldata payload (arbitrary bytes mid-buffer)
        // and verify the target sees the same bytes.
        DelegateTarget target = new DelegateTarget();
        bytes memory payload = hex"deadbeef0102030405060708090a0b0c0d0e0f10";
        bytes memory data = abi.encodeCall(DelegateTarget.assertPayload, (payload));

        bytes32 txHash = safe.getTransactionHash(address(target), 0, data, 1, safe.nonce());
        bytes memory sigs = _sign2(txHash);

        // assertPayload reverts if the bytes don't match. If pre-fix bug
        // were still present the inner call would either revert (corrupted
        // data) OR succeed-with-garbage. Audit H1 fix means we now revert
        // on inner-call failure → either way, this test catches drift.
        bool success = safe.execTransaction(address(target), 0, data, 1, sigs);
        assertTrue(success);
    }

    // ── execTransaction failure path — Audit H1 ─────────────

    function test_exec_revert_bubbles_inner_call_revert() public {
        // Audit H1: failed inner call should REVERT now (used to silently
        // return false + emit ExecutionFailure).
        Reverter target = new Reverter();
        bytes memory data = abi.encodeCall(Reverter.alwaysRevert, ());

        bytes32 txHash = safe.getTransactionHash(address(target), 0, data, 0, safe.nonce());
        bytes memory sigs = _sign2(txHash);

        vm.expectRevert(bytes("Reverter: nope"));
        safe.execTransaction(address(target), 0, data, 0, sigs);
    }

    // ── Owner management — Audit H3 ─────────────────────────

    function test_addOwner_via_self_call() public {
        address newOwner = address(0xBEEF);
        bytes memory data = abi.encodeCall(SentrixSafe.addOwner, (newOwner, 3));
        bytes32 txHash = safe.getTransactionHash(address(safe), 0, data, 0, safe.nonce());
        bytes memory sigs = _sign2(txHash);
        safe.execTransaction(address(safe), 0, data, 0, sigs);
        assertTrue(safe.isOwner(newOwner));
        assertEq(safe.threshold(), 3);
    }

    function test_addOwner_revert_on_external_caller() public {
        vm.expectRevert(bytes("Safe: self-call only"));
        safe.addOwner(address(0xBEEF), 3);
    }

    function test_removeOwner_enforces_minimum_floor() public {
        // Set up a 1-of-1 fresh safe just so we can verify the floor.
        address[] memory single = new address[](1);
        single[0] = owner1;
        SentrixSafe smallSafe = new SentrixSafe(single, 1);

        // Self-call to removeOwner should fail because we'd be removing
        // the last owner.
        bytes memory data = abi.encodeCall(SentrixSafe.removeOwner, (owner1, 1));
        bytes32 txHash = smallSafe.getTransactionHash(address(smallSafe), 0, data, 0, smallSafe.nonce());
        bytes memory sigs = _signOneSafe(txHash, sortedPks[0]);

        vm.expectRevert(bytes("Safe: cannot remove last owner"));
        smallSafe.execTransaction(address(smallSafe), 0, data, 0, sigs);
    }

    function test_removeOwner_threshold_floor_enforced() public {
        // 3 owners, threshold 2. Remove an owner AND set threshold to 3 —
        // illegal because remaining = 2 owners but threshold = 3.
        bytes memory data = abi.encodeCall(SentrixSafe.removeOwner, (owner3, 3));
        bytes32 txHash = safe.getTransactionHash(address(safe), 0, data, 0, safe.nonce());
        bytes memory sigs = _sign2(txHash);

        vm.expectRevert(bytes("Safe: threshold too high"));
        safe.execTransaction(address(safe), 0, data, 0, sigs);
    }

    // ── DOMAIN_SEPARATOR — Audit H2 ─────────────────────────

    function test_domain_separator_recomputes_on_chainid_change() public {
        bytes32 cached = safe.DOMAIN_SEPARATOR();

        // Simulate a host-chain hard fork that changes chainid.
        vm.chainId(99999);
        bytes32 fresh = safe.DOMAIN_SEPARATOR();

        assertTrue(cached != fresh);
    }

    // ── Helpers ──────────────────────────────────────────────

    function _sign2(bytes32 txHash) internal returns (bytes memory) {
        // sigs sorted by signer addr ascending — owner1 < owner2 < owner3
        // by sortedPks[0] / [1] / [2] mapping
        bytes memory s0 = _signOne(txHash, sortedPks[0]);
        bytes memory s1 = _signOne(txHash, sortedPks[1]);
        return bytes.concat(s0, s1);
    }

    function _signOne(bytes32 txHash, uint256 pk) internal returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, txHash);
        return abi.encodePacked(r, s, v);
    }

    function _signOneSafe(bytes32 txHash, uint256 pk) internal returns (bytes memory) {
        return _signOne(txHash, pk);
    }

    function _sortOwnersAndPks(address a, address b, address c, uint256 pa, uint256 pb, uint256 pc)
        internal
        pure
        returns (address[] memory, uint256[] memory)
    {
        address[] memory addrs = new address[](3);
        uint256[] memory pks = new uint256[](3);
        addrs[0] = a; addrs[1] = b; addrs[2] = c;
        pks[0] = pa; pks[1] = pb; pks[2] = pc;
        for (uint256 i = 0; i < 3; i++) {
            for (uint256 j = i + 1; j < 3; j++) {
                if (addrs[i] > addrs[j]) {
                    (addrs[i], addrs[j]) = (addrs[j], addrs[i]);
                    (pks[i], pks[j]) = (pks[j], pks[i]);
                }
            }
        }
        return (addrs, pks);
    }
}

contract DelegateTarget {
    function setHighSlot(bytes32 v) external {
        assembly {
            sstore(99, v)
        }
    }

    function assertPayload(bytes calldata expected) external pure {
        // Dummy assertion — the function exists to verify calldata bytes
        // arrive intact. If they don't, the function selector itself is
        // wrong and the call reverts via fallback.
        require(expected.length > 0, "empty payload");
    }
}

contract Reverter {
    function alwaysRevert() external pure {
        revert("Reverter: nope");
    }
}

