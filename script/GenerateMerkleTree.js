#!/usr/bin/env node
/**
 * GenerateMerkleTree.js — off-chain merkle tree builder for MerkleAirdrop deploys.
 *
 * Input:  recipients.json — array of {address, amount} pairs (amount in wei string)
 * Output: merkle-tree.json — root + per-recipient proof + total amount
 *
 * Leaf format (matches MerkleAirdrop.sol _verify):
 *   keccak256(abi.encodePacked(address, uint256))
 *
 * Sibling-pair hashing (sorted siblings, OpenZeppelin convention):
 *   if (a < b) keccak256(a || b) else keccak256(b || a)
 *
 * Unbalanced trees: lone leaf at a level carries up unchanged (NOT padded).
 * This matches the test contract MerkleAirdrop.t.sol convention.
 *
 * Usage:
 *   node script/GenerateMerkleTree.js path/to/recipients.json
 */

const fs = require("fs");
const path = require("path");
const { keccak256 } = require("ethereum-cryptography/keccak");
const { hexToBytes, bytesToHex } = require("ethereum-cryptography/utils");

function leafFor(addr, amountWei) {
  // abi.encodePacked(address, uint256) = 20 bytes addr + 32 bytes amount
  const addrBytes = hexToBytes(addr.toLowerCase().replace(/^0x/, ""));
  if (addrBytes.length !== 20) {
    throw new Error(`bad address: ${addr}`);
  }
  const amountHex = BigInt(amountWei).toString(16).padStart(64, "0");
  const amountBytes = hexToBytes(amountHex);
  const packed = new Uint8Array(52);
  packed.set(addrBytes, 0);
  packed.set(amountBytes, 20);
  return keccak256(packed);
}

function hashPair(a, b) {
  // Sorted siblings: smaller first. Compare as big-endian.
  const aHex = bytesToHex(a);
  const bHex = bytesToHex(b);
  const ordered =
    aHex < bHex ? new Uint8Array([...a, ...b]) : new Uint8Array([...b, ...a]);
  return keccak256(ordered);
}

function buildTree(leaves) {
  if (leaves.length === 0) throw new Error("no leaves");
  // Build levels bottom-up. Layer 0 = leaves. Each next level pairs siblings;
  // an odd lone node at a level passes through unchanged.
  const levels = [leaves];
  let current = leaves;
  while (current.length > 1) {
    const next = [];
    for (let i = 0; i < current.length; i += 2) {
      if (i + 1 < current.length) {
        next.push(hashPair(current[i], current[i + 1]));
      } else {
        // Lone leaf carries up — matches MerkleAirdrop.t.sol pattern
        next.push(current[i]);
      }
    }
    levels.push(next);
    current = next;
  }
  return levels;
}

function proofFor(levels, leafIndex) {
  const proof = [];
  let idx = leafIndex;
  for (let level = 0; level < levels.length - 1; level++) {
    const layer = levels[level];
    let siblingIdx;
    if (idx % 2 === 0) {
      siblingIdx = idx + 1;
    } else {
      siblingIdx = idx - 1;
    }
    if (siblingIdx < layer.length) {
      proof.push(bytesToHex(layer[siblingIdx]));
    }
    // If sibling missing (lone-leaf carry-up), no proof entry added at this level
    idx = Math.floor(idx / 2);
  }
  return proof;
}

function main() {
  const inputPath = process.argv[2];
  if (!inputPath) {
    console.error("Usage: node GenerateMerkleTree.js <recipients.json>");
    console.error("");
    console.error("recipients.json format:");
    console.error('  [{"address": "0x...", "amount": "1000000000000000000"}, ...]');
    process.exit(2);
  }

  const recipients = JSON.parse(fs.readFileSync(inputPath, "utf8"));
  if (!Array.isArray(recipients)) {
    throw new Error("recipients.json must be an array");
  }

  // Sort recipients by address (canonical order — makes the root stable across
  // re-runs even if input order changes)
  recipients.sort((a, b) => a.address.toLowerCase().localeCompare(b.address.toLowerCase()));

  const leaves = recipients.map((r) => leafFor(r.address, r.amount));
  const levels = buildTree(leaves);
  const root = levels[levels.length - 1][0];

  const totalAmount = recipients.reduce(
    (sum, r) => sum + BigInt(r.amount),
    0n,
  );

  const output = {
    merkleRoot: "0x" + bytesToHex(root),
    totalAmount: totalAmount.toString(),
    recipientCount: recipients.length,
    recipients: recipients.map((r, i) => ({
      address: r.address,
      amount: r.amount,
      proof: proofFor(levels, i).map((h) => "0x" + h),
    })),
  };

  const outputPath = path.join(
    path.dirname(inputPath),
    "merkle-tree.json",
  );
  fs.writeFileSync(outputPath, JSON.stringify(output, null, 2));

  console.log(`Merkle root: 0x${bytesToHex(root)}`);
  console.log(`Total amount: ${totalAmount} wei (${Number(totalAmount) / 1e18} SRX)`);
  console.log(`Recipients: ${recipients.length}`);
  console.log(`Output: ${outputPath}`);
}

main();
