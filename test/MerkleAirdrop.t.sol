// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../contracts/MerkleAirdrop.sol";

contract MerkleAirdropTest is Test {
    MerkleAirdrop airdrop;

    address constant ALICE = address(0xA11CE);
    address constant BOB = address(0xB0B0);
    address constant CAROL = address(0xCAA01);
    address constant DAN = address(0xDAD); // not in tree

    address constant OWNER = address(0x0FF1CE); // SentrixSafe stand-in
    address constant SWEEP_TARGET = address(0x5EED); // Strategic Reserve stand-in

    uint256 constant ALICE_AMT = 100 ether;
    uint256 constant BOB_AMT = 200 ether;
    uint256 constant CAROL_AMT = 300 ether;
    uint256 constant TOTAL = ALICE_AMT + BOB_AMT + CAROL_AMT;

    bytes32 constant ALICE_LEAF = keccak256(abi.encodePacked(ALICE, ALICE_AMT));
    bytes32 constant BOB_LEAF = keccak256(abi.encodePacked(BOB, BOB_AMT));
    bytes32 constant CAROL_LEAF = keccak256(abi.encodePacked(CAROL, CAROL_AMT));

    bytes32 root;
    uint256 deadline;

    function setUp() public {
        // Build a 3-leaf tree (Alice, Bob, Carol) by sorting leaves and pair-hashing.
        // Tree shape (sorted siblings):
        //          root
        //         /    \
        //      H(AB)   H(C, C)  -- single-leaf branch padded with itself? No: standard
        //                          OpenZeppelin trees pair-hash unbalanced trees by
        //                          carrying the lone leaf up. We simulate that:
        //          root = H_sorted(H_sorted(A, B), C)

        bytes32 ab = _hashPair(ALICE_LEAF, BOB_LEAF);
        root = _hashPair(ab, CAROL_LEAF);

        deadline = block.timestamp + 90 days;

        airdrop = new MerkleAirdrop(root, deadline, SWEEP_TARGET, OWNER);

        // Pre-fund the contract with the total claim amount + a buffer
        vm.deal(address(this), TOTAL + 10 ether);
        (bool ok,) = address(airdrop).call{value: TOTAL + 10 ether}("");
        require(ok, "fund failed");
    }

    // ── Helpers ──────────────────────────────────────────────
    function _hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    function _aliceProof() internal pure returns (bytes32[] memory) {
        bytes32[] memory p = new bytes32[](2);
        p[0] = BOB_LEAF; // sibling at level 0
        p[1] = CAROL_LEAF; // sibling at level 1
        return p;
    }

    function _bobProof() internal pure returns (bytes32[] memory) {
        bytes32[] memory p = new bytes32[](2);
        p[0] = ALICE_LEAF;
        p[1] = CAROL_LEAF;
        return p;
    }

    function _carolProof() internal pure returns (bytes32[] memory) {
        bytes32[] memory p = new bytes32[](1);
        p[0] = _hashPair(ALICE_LEAF, BOB_LEAF);
        return p;
    }

    // ── Tests ────────────────────────────────────────────────

    function test_constructor_setsImmutables() public view {
        assertEq(airdrop.merkleRoot(), root);
        assertEq(airdrop.claimDeadline(), deadline);
        assertEq(airdrop.sweepRecipient(), SWEEP_TARGET);
        assertEq(airdrop.owner(), OWNER);
        assertFalse(airdrop.swept());
        assertEq(airdrop.totalClaimed(), 0);
    }

    function test_constructor_revertsOnZeroSweepRecipient() public {
        vm.expectRevert(MerkleAirdrop.ZeroAddress.selector);
        new MerkleAirdrop(root, deadline, address(0), OWNER);
    }

    function test_constructor_revertsOnZeroOwner() public {
        vm.expectRevert(MerkleAirdrop.ZeroAddress.selector);
        new MerkleAirdrop(root, deadline, SWEEP_TARGET, address(0));
    }

    function test_claim_aliceSucceeds() public {
        uint256 balanceBefore = ALICE.balance;

        vm.prank(ALICE);
        airdrop.claim(ALICE_AMT, _aliceProof());

        assertEq(ALICE.balance, balanceBefore + ALICE_AMT);
        assertTrue(airdrop.claimed(ALICE));
        assertEq(airdrop.totalClaimed(), ALICE_AMT);
    }

    function test_claim_emitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit MerkleAirdrop.Claimed(ALICE, ALICE_AMT);

        vm.prank(ALICE);
        airdrop.claim(ALICE_AMT, _aliceProof());
    }

    function test_claim_revertsOnDoubleClaim() public {
        vm.prank(ALICE);
        airdrop.claim(ALICE_AMT, _aliceProof());

        vm.expectRevert(MerkleAirdrop.AlreadyClaimed.selector);
        vm.prank(ALICE);
        airdrop.claim(ALICE_AMT, _aliceProof());
    }

    function test_claim_revertsOnInvalidAmount() public {
        // Alice tries to claim Bob's amount with her proof
        vm.expectRevert(MerkleAirdrop.InvalidProof.selector);
        vm.prank(ALICE);
        airdrop.claim(BOB_AMT, _aliceProof());
    }

    function test_claim_revertsOnNonRecipient() public {
        // Dan tries to claim with Alice's proof
        vm.expectRevert(MerkleAirdrop.InvalidProof.selector);
        vm.prank(DAN);
        airdrop.claim(ALICE_AMT, _aliceProof());
    }

    function test_claim_revertsAfterDeadline() public {
        vm.warp(deadline + 1);
        vm.expectRevert(MerkleAirdrop.ClaimWindowClosed.selector);
        vm.prank(ALICE);
        airdrop.claim(ALICE_AMT, _aliceProof());
    }

    function test_claim_revertsAfterSweep() public {
        // Warp past deadline + sweep
        vm.warp(deadline + 1);
        vm.prank(OWNER);
        airdrop.sweep();

        // Even if we warp back (impossible IRL, but tests reentrancy-style logic)
        vm.warp(deadline - 1);
        vm.expectRevert(MerkleAirdrop.AlreadySwept.selector);
        vm.prank(ALICE);
        airdrop.claim(ALICE_AMT, _aliceProof());
    }

    function test_multipleClaims_independent() public {
        vm.prank(ALICE);
        airdrop.claim(ALICE_AMT, _aliceProof());

        vm.prank(BOB);
        airdrop.claim(BOB_AMT, _bobProof());

        vm.prank(CAROL);
        airdrop.claim(CAROL_AMT, _carolProof());

        assertEq(airdrop.totalClaimed(), TOTAL);
        assertEq(ALICE.balance, ALICE_AMT);
        assertEq(BOB.balance, BOB_AMT);
        assertEq(CAROL.balance, CAROL_AMT);
    }

    function test_sweep_revertsBeforeDeadline() public {
        vm.expectRevert(MerkleAirdrop.ClaimWindowOpen.selector);
        vm.prank(OWNER);
        airdrop.sweep();
    }

    function test_sweep_revertsForNonOwner() public {
        vm.warp(deadline + 1);
        vm.expectRevert(MerkleAirdrop.NotOwner.selector);
        vm.prank(ALICE);
        airdrop.sweep();
    }

    function test_sweep_succeedsAfterDeadline() public {
        // Alice claims, Bob+Carol don't
        vm.prank(ALICE);
        airdrop.claim(ALICE_AMT, _aliceProof());

        uint256 balanceBefore = SWEEP_TARGET.balance;
        uint256 expectedSweep = address(airdrop).balance; // includes the buffer

        vm.warp(deadline + 1);

        vm.expectEmit(true, false, false, true);
        emit MerkleAirdrop.Swept(SWEEP_TARGET, expectedSweep);

        vm.prank(OWNER);
        airdrop.sweep();

        assertEq(SWEEP_TARGET.balance, balanceBefore + expectedSweep);
        assertTrue(airdrop.swept());
        assertEq(address(airdrop).balance, 0);
    }

    function test_sweep_cannotBeCalledTwice() public {
        vm.warp(deadline + 1);
        vm.prank(OWNER);
        airdrop.sweep();

        vm.expectRevert(MerkleAirdrop.AlreadySwept.selector);
        vm.prank(OWNER);
        airdrop.sweep();
    }

    function test_isEligible_view() public view {
        assertTrue(airdrop.isEligible(ALICE, ALICE_AMT, _aliceProof()));
        assertTrue(airdrop.isEligible(BOB, BOB_AMT, _bobProof()));
        assertTrue(airdrop.isEligible(CAROL, CAROL_AMT, _carolProof()));
        assertFalse(airdrop.isEligible(DAN, ALICE_AMT, _aliceProof()));
        assertFalse(airdrop.isEligible(ALICE, BOB_AMT, _aliceProof()));
    }

    function test_receive_anyoneCanFund() public {
        vm.deal(BOB, 1 ether);
        uint256 before = address(airdrop).balance;
        vm.prank(BOB);
        (bool ok,) = address(airdrop).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(address(airdrop).balance, before + 1 ether);
    }
}
