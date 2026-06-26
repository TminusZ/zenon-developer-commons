# Merkle State & State Roots — A Simple Guide

A plain-language companion to [MERKLE_STATE_ROOT.md](MERKLE_STATE_ROOT.md). It explains what the state root is,
what a proof proves, and how you check one — without the cryptographic detail (that's in the overview and the
code).

## The problem it solves

If you ask a node "what's the balance of address A?", how do you know the answer is real and not made up? Today
you'd have to replay the whole chain yourself. The state root fixes that: it lets a node hand you a small **proof**
that you can check against information the pillars already signed — so you trust the *math*, not the node.

## The root, in one sentence

Every node keeps all consensus state in a big hash tree. The single hash at the top — the **state root** — is a
fingerprint of *all* of that state. From momentum version 3 onward, that fingerprint is written into each momentum
header and signed by the pillar that produced it.

Change any value anywhere in state, and the root changes. So if two people agree on the root, they agree on the
entire state.

## What a proof is

State is stored as leaves in a tree; each key sits at a fixed position, and every node above is the hash of its
two children. To prove "key K = value V":

1. The node gives you V plus the handful of sibling hashes along the path from K's leaf up to the root.
2. You hash V into a leaf and combine it with those siblings, step by step, up to a single hash.
3. If that hash equals the `StateRoot` in the signed momentum header, the proof is good. If anything about V were
   wrong, the hashes wouldn't line up.

The same shape of proof can show a key is **absent** (it leads to an empty slot). A typical proof is about 1–1.4 KB.

## How you use it

- `ledger.getStateRoot(height)` — the root at a given height.
- `ledger.getProof(height, key)` — returns `{value, proof, root}`.
- Verify with the standalone `trie.VerifyProof` / `trie.VerifyAbsence` (no database needed), checking against the
  `StateRoot` in that height's signed header. The `cmd/prove-balance` tool shows the whole flow end to end.

Because verification needs no database and no trust in the server, the same check runs in a light client today and
inside the on-chain dispute referee in the off-chain execution layer's Phase 2.

## Good to know

- The root commits to the same state the existing `ChangesHash` already covers, so it adds provability without
  changing what state means.
- It is **history-independent**: rebuilding from genesis or from a synced database yields the identical root.
- The feature is built but dormant until the `StateRootSpork` activates; until then headers carry an empty root.

For how it's implemented and wired into consensus, see [MERKLE_STATE_ROOT.md](MERKLE_STATE_ROOT.md).
