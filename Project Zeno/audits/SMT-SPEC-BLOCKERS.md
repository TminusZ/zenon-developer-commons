# SMT-SPEC-BLOCKERS.md

> **STATUS: RESOLVED (historical).** Blockers SMT-B-1, SMT-B-2, SMT-B-3 (and clarification C-1) are now **ratified normatively in `../SPEC.md` §13.4** (MSB-first routing, `0`=left/`1`=right, full-depth-256, constant-zero empties with the both-empty short-circuit) and implemented in `common/trie`. This document is retained only as the record of why those rules were needed; it raises no open issues.

**Artifact:** SMT Conformance Test Suite V1 — blocker report
**Scope:** Only rules required to compute deterministic SMT **roots** and deterministic **proofs**. Architecture, trust, fraud proofs, governance, and roadmap are out of scope by instruction.

## Summary

The locked spec (`../SPEC.md` §13.2) pins the hash function, the leaf preimage, the interior preimage, the empty-subtree value, the key space, and the key size. These are sufficient to define leaf and interior hashing. They are **not** sufficient, on their own, to produce a deterministic root, because the spec does not pin **how a 256-bit key maps to a position in the tree**. Three rules required for root computation are missing.

Two independent implementations that both obey every locked sentence can still produce different roots for the same key/value set. Therefore the locked spec, as written, is **insufficient to generate deterministic roots**, and the missing rules are reported below as blockers.

The vector suite in `smt-v1-test-vectors.json` is generated under one explicitly declared **canonical profile** (the resolutions B-1, B-2, B-3 below, plus the literal reading C-1). The suite becomes the normative reference the moment these three blockers are ratified with the proposed text. Nothing in the suite was invented silently: every non-pinned rule is named here.

---

## BLOCKER SMT-B-1 — Path-bit direction is unspecified

**Missing rule.** The spec does not state which bit of the 32-byte key selects the branch at a given depth. It does not say whether descent is most-significant-bit-first (root branches on the top bit of `key[0]`) or least-significant-bit-first (root branches on the low bit of `key[31]`).

**Why deterministic roots cannot be generated.** The branch direction at each depth determines which leaves share a subtree and therefore which leaf hashes are combined by each `SHA3-256(left || right)`. MSB-first and LSB-first produce entirely different interior-node groupings and therefore different roots for any set of two or more keys, and different single-leaf roots as well (the climb order differs). `SHA3-256(left || right)` is well defined only **after** the routing is fixed; the spec fixes the combiner but not the routing.

**Minimal protocol text required (proposed B-1).**
> The SMT is a binary tree of depth 256. Descent is most-significant-bit-first: at depth `d` (`0 <= d <= 255`), the branch is selected by key bit index `255 - d`, where bit index 255 is the most-significant bit of `key[0]` and bit index 0 is the least-significant bit of `key[31]`. Equivalently, at depth `d` the selecting bit is `(key[d / 8] >> (7 - (d mod 8))) & 1`.

---

## BLOCKER SMT-B-2 — Bit-value-to-side mapping is unspecified

**Missing rule.** Given the selecting bit at a depth, the spec does not state whether bit value `0` routes to the left child or the right child.

**Why deterministic roots cannot be generated.** `SHA3-256(left || right)` is order-sensitive. If implementation A treats bit `0` as left and implementation B treats bit `0` as right, then for any key whose path includes a populated sibling the two implementations swap the operands of the interior hash and compute different node hashes, hence different roots. This is independent of B-1 and must be fixed separately.

**Minimal protocol text required (proposed B-2).**
> At each depth, a selecting bit value of `0` routes to the left child and a selecting bit value of `1` routes to the right child. The interior node hash is `SHA3-256(left || right)` where `left` is the depth-`d+1` subtree reached by bit `0` and `right` is the depth-`d+1` subtree reached by bit `1`.

---

## BLOCKER SMT-B-3 — Tree-depth / leaf-placement model is unspecified

**Missing rule.** The spec does not state that the tree has a fixed depth of 256 with each leaf placed at depth 256 according to its full 32-byte key. It defines leaf and interior hashing but never states the structural model that determines how many interior combinations sit between a leaf and the root.

**Why deterministic roots cannot be generated.** The number of interior `SHA3-256(left || right)` applications between a leaf and the root is part of the root preimage chain. A full-depth-256 model hashes each single leaf upward through 256 levels (combining with the empty sibling at each level). A "collapsed"/"compressed" model that stops at the deepest distinguishing bit and treats the node as the leaf hash directly yields a different root for the same single key. Without fixing the structural model, the single-insert root (and every other root) is undetermined even after B-1 and B-2.

**Minimal protocol text required (proposed B-3).**
> Every key occupies a leaf at depth 256. The root is computed by evaluating the depth-256 binary tree bottom-up: a leaf node is `SHA3-256(key || value)`; an absent leaf position is the 32-byte zero hash; an interior node at depth `d` is `SHA3-256(left || right)` over its depth-`d+1` children. The root is the depth-0 node. Implementations MAY use a sparse or compressed in-memory representation, but the committed root MUST equal the root of this full depth-256 evaluation.

---

## CLARIFICATION SMT-C-1 — Empty-subtree constant versus computed default (resolved by literal reading; not a blocker)

**Observation.** `../SPEC.md` §13.2 states: *"Empty subtrees MUST be represented by the 32-byte zero hash."* Two readings exist:

1. **Constant-zero (literal):** every empty subtree, at every level, is the 32-byte zero hash. An interior node whose two children are both zero is itself zero (the all-empty subtree is represented by zero, not by `SHA3-256(zero || zero)`).
2. **Computed-default:** only the empty leaf is zero, and `default[d] = SHA3-256(default[d+1] || default[d+1])` is recomputed per level, so an empty subtree at depth `d` is a non-zero constant.

**Why this is a clarification, not a blocker.** The locked text *does* determine a value under its literal reading (reading 1): "empty subtrees ... the 32-byte zero hash" assigns the same zero constant to any empty subtree at any level. Because a value is determined, deterministic roots are computable; the risk is only that an implementer imports a library defaulting to reading 2.

**Resolution adopted by this suite.** Reading 1 (constant zero). The interior-node rule carries one consequence that MUST be stated to prevent reading 2 from leaking in:

**Recommended confirming text (C-1).**
> The 32-byte zero hash represents an empty subtree at every depth. An interior node both of whose children are the 32-byte zero hash MUST itself be the 32-byte zero hash; it MUST NOT be computed as `SHA3-256(zero || zero)`. An interior node with exactly one empty child MUST be computed as `SHA3-256(left || right)` with the empty side set to the 32-byte zero hash.

---

## CLARIFICATION SMT-C-2 — Leaf preimage has no length delimiter (resolved by literal reading; not a blocker)

**Observation.** `leaf = SHA3-256(key || value)` with a fixed 32-byte key and a variable-length value. Because the key is fixed-width and is the prefix, the preimage `key || value` is unambiguous: the first 32 bytes are the key and the remainder is the value. No length delimiter is required for determinism.

**Status.** Determinism is not affected. No protocol text change is required for root computation. (Any collision discussion is architecture and is out of scope here.) Recorded only so the absence of a length prefix is a deliberate, noted decision rather than an oversight.

---

## Verdict

- **Roots are NOT deterministically computable from the locked spec as written.** Blockers SMT-B-1, SMT-B-2, SMT-B-3 each independently change the root and are not pinned.
- Ratifying the three proposed texts (B-1, B-2, B-3), plus the confirming text C-1, makes roots fully deterministic.
- `proof-format.md` defines the proof structure, which the spec also leaves entirely open; that is a deliverable here, not a spec blocker for roots.
- Under the declared canonical profile (B-1 MSB-first, B-2 `0=left/1=right`, B-3 full-depth-256, C-1 constant-zero), the full vector suite is generated with real expected outputs and every serialized proof has been independently re-verified to reproduce its root.
