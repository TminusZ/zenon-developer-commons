# SMT Implementation Conformance Checklist V1

A Phase 1 SMT implementation is conformant iff every item below holds and every vector in `smt-v1-test-vectors.json` reproduces byte-for-byte. Targets: Go, Rust, TypeScript.

## Hashing
- [ ] Uses SHA3-256 (FIPS-202), confirmed by `SHA3-256("") = a7ffc6f8…8434a`. Not Keccak-256.
- [ ] Leaf hash is exactly `SHA3-256(key(32) || value)` with the 32-byte key as a raw prefix and the value appended with no length delimiter.
- [ ] Interior hash is exactly `SHA3-256(left(32) || right(32))`.
- [ ] Both-empty short-circuit: an interior node with two 32-byte-zero children is the 32-byte zero hash, **not** `SHA3-256(zero||zero)`.
- [ ] One-empty child: hashed as `SHA3-256(left||right)` with the empty side = 32-byte zero hash.

## Tree structure (`../SPEC.md` §13.4)
- [ ] Full-depth 256-level tree; every key is a leaf at depth 256.
- [ ] Path-bit ordering is MSB-first: depth `d` selects bit `(key[d/8] >> (7 - d%8)) & 1`.
- [ ] Side mapping: bit `0` → left, bit `1` → right.
- [ ] Empty subtree at every level is the 32-byte zero hash (constant; not a computed per-level default).
- [ ] Sparse/compressed in-memory storage (if any) reproduces the full-depth root exactly.

## Keys / values
- [ ] Keys are exactly 32 bytes; non-32-byte keys are rejected before tree operations.
- [ ] Present empty value (`value = ""`) yields leaf `SHA3-256(key || "")`, which is non-zero; the key is present.
- [ ] Absent key contributes the 32-byte zero hash at its slot.
- [ ] Present-empty and absent are distinguishable: `storage_len` returns `0` for present-empty and `-1` for absent (spec 27.8); their roots differ.

## StateDiff / deletion
- [ ] Deletion uses the EMPTY sentinel (value length prefix `0xFFFFFFFF`, spec 27.2); deleted key becomes absent (non-inclusion).
- [ ] Deleting a non-existent key is a well-formed no-op leaving the root unchanged.
- [ ] Update to a new value changes the root; update to the identical value leaves the root unchanged.
- [ ] Batch StateDiff entries are applied in ascending key order; duplicate or unsorted keys are rejected (spec 27.2).
- [ ] Incremental application equals full recompute at every step.

## Proofs (proof-format.md)
- [ ] Proofs are full-depth, leaf-to-root, 256 levels; no shortcut/truncated/variable-length proofs.
- [ ] Sibling ordering is deepest-first (`sib[255]…sib[0]`).
- [ ] 256-bit sibling bitmap, deepest-first index `i` ↔ depth `255 - i`, stored MSB-first within each byte.
- [ ] Only non-zero siblings are stored; `sib_count == popcount(bitmap)`.
- [ ] Serialization matches the byte layout in proof-format.md §4 exactly (flags, key, leaf_hash, bitmap, sib_count, siblings, optional value tail).
- [ ] Inclusion proof verifies `SHA3-256(key||value) == leaf_hash` during decode.
- [ ] Non-inclusion proof carries `leaf_hash = zero32` and no value tail.
- [ ] Verification climbs all 256 levels and enforces `next_sibling == sib_count` (no unused siblings).
- [ ] Reserved `flags` bits 1..7 must be zero; trailing bytes rejected.

## Vector conformance
- [ ] All 14 vectors (SMT-001…SMT-014) reproduce `expected_root` byte-for-byte.
- [ ] Every `expected_leaf_hashes` entry matches.
- [ ] Every `expected_branch_hashes` entry (where present) matches.
- [ ] Every `expected_inclusion_proof.serialized` and `expected_non_inclusion_proof.serialized` reproduces, and verifies against `expected_root`.
- [ ] SMT-010 `assert_distinct == true` (present-empty ≠ absent).
- [ ] SMT-014 `all_equal == true` (incremental == full recompute).

## Spec gating (blockers)
- [x] B-1 (MSB-first path-bit direction), B-2 (`0`=left/`1`=right), B-3 (full-depth-256 model) are **ratified** in `../SPEC.md` §13.4 and implemented in `common/trie`. This checklist is conformant to the locked spec.
