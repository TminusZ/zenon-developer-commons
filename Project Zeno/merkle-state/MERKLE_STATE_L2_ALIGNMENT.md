# `common/trie` — L1/L2 SMT Alignment Changelog

**Audience:** go-zenon core developers.
**Status:** Upgrade plan. Nothing here is live; `StateRootSpork` is not yet activated, so these changes carry **no consensus risk** and require **no state migration**.
**One-line summary:** the L1 SMT *algorithm* already matches the WASM Phase 1 spec exactly — same hashing, routing, empties, and proof bytes. This changelog is **API hygiene only**: expose the existing pure core as a clean path-based public API (so the L2 executor and the Phase 2 dispute referee can share it without double-hashing), and quarantine the two L1-only maintenance conventions so they can never leak into L2. **Roots and proof bytes are byte-identical before and after.**

---

## 0. Why this is needed (and why it is small)

The Phase 1 WASM spec (`phase-1/SPEC.md` §13) requires the L2 executor's state tree and the L1 momentum state tree to share one SMT so that proofs and the Phase 2 referee have a single verifier. We verified the current `common/trie` against the spec:

| Spec requirement (§13.2 / §13.4 / `proof-format.md`) | `common/trie` today | Match? |
|---|---|---|
| Full-depth-256 binary, leaf at `sha3(path‖value)`, interior `sha3(l‖r)`, both-empty short-circuit, constant-zero empties | `hash.go` `LeafHash`/`InternalHash`/`emptyHash`; `compute.go` `subtreeHash`/`padLeaf` | ✅ exact |
| MSB-first routing, bit `0`→left / `1`→right | `hash.go` `pathBit`; `compute.go`/`proof.go` ordering | ✅ exact |
| Deepest-first, 256-bit non-zero-sibling bitmap proof, pure (no DB) | `proof.go` `encodeProof`/`decodeProof`/`reconstructRoot` | ✅ exact |
| One conformance vector set governs both | `conformance_test.go` loads `WASM Spec/smt-v1-test-vectors.json` | ✅ already wired |

**Conclusion: there is no algorithmic divergence to fix.** The trees are already compatible. The only friction is in the *maintenance* layer (`tree.go`), which carries two conventions that are correct for L1 but must not be imposed on L2:

1. **Key pre-hashing.** L1 keys are arbitrary-length DB keys, so the adapter computes `path = types.NewHash(key)` (`tree.go` appliers; `proof.go` `VerifyProof`/`VerifyAbsence`). The L2 derived key is *already* a 32-byte SHA3 output (`sha3(contract_id‖local_key)`), so reusing these entry points would hash twice and put L2 leaves at the wrong path.
2. **Empty-value-as-deletion.** The L1 appliers fold an empty value to a deletion (`stagedApplier.Put`: `if len(value) == 0 { del }`; `FoldFilter`). The L2 model requires a *present-empty* leaf distinct from an absent key (spec §13.6, §27.8). The shared core already supports this (`LeafHash(path, [])` = `sha3(path)`, non-zero); only the L1 adapter collapses it.

The changes below make the path-based core the official shared surface, turn the L1 conventions into clearly-scoped adapter behavior, and give the Phase 2 referee a no-rehash verifier.

---

## 1. Change C1 — add path-based verifiers; make key-hashing an explicit wrapper

**Today:** `proof.go` exposes only key-hashing verifiers:

```go
func VerifyProof(root types.Hash, key, value, proof []byte) (bool, error)   // does types.NewHash(key)
func VerifyAbsence(root types.Hash, key, proof []byte) (bool, error)         // does types.NewHash(key)
```

**Change:** add path-based variants that take the 32-byte path directly, and refactor the existing functions into thin wrappers:

```go
// Path-based: caller supplies the 32-byte SMT path. Used by the L2 executor and the
// Phase 2 dispute referee, whose keys are already SHA3 outputs.
func VerifyProofByPath(root, path types.Hash, value, proof []byte) (bool, error)
func VerifyAbsenceByPath(root, path types.Hash, proof []byte) (bool, error)

// Key-based wrappers (L1 / arbitrary-length keys). Behaviour unchanged.
func VerifyProof(root types.Hash, key, value, proof []byte) (bool, error) {
    return VerifyProofByPath(root, types.NewHash(key), value, proof)
}
func VerifyAbsence(root types.Hash, key, proof []byte) (bool, error) {
    return VerifyAbsenceByPath(root, types.NewHash(key), proof)
}
```

Internally this is a one-line extraction: the current bodies already compute `d.path` and compare against `types.NewHash(key)` — replace that comparison with the supplied `path`. **No change to proof parsing or root reconstruction; proof bytes unchanged.**

---

## 2. Change C2 — export path-based root and proof primitives

**Today:** the pure root/prove primitives and the leaf type are unexported (`rootOfLeaves`, `proveLeaves`, `leaf`), reachable only through the `Tree` adapter, which hashes keys and folds empties.

**Change:** expose a path-based public API the L2 executor can drive over its own leaf set:

```go
// Leaf is a populated entry positioned at a 32-byte path with a raw value.
type Leaf struct {
    Path  types.Hash
    Value []byte
}

// RootOfLeaves computes the full-depth-256 SMT root over a leaf set. Empty set -> zero hash.
func RootOfLeaves(leaves []Leaf) types.Hash

// ProveLeaves returns presence, the value if present, and the canonical proof bytes for
// `path` over the leaf set (proof-format.md). No key hashing, no DB.
func ProveLeaves(leaves []Leaf, path types.Hash) (present bool, value []byte, proof []byte)
```

These are renames/exports of the existing `rootOfLeaves`/`proveLeaves`+`encodeProof` with the exported `Leaf` type. The L1 `Tree` keeps using them internally. **No behavioural change.**

---

## 3. Change C3 — quarantine the L1-only conventions

**Goal:** make it structurally obvious which code is the shared, frozen, consensus-visible core and which is L1-momentum-specific, so an L2 implementer cannot accidentally import the wrong thing.

**Change (organizational; pick one):**

- *Minimum:* split files within `common/trie`. Put the shared core in `hash.go`/`compute.go`/`proof.go` (already there) and move the L1-only pieces — `FoldFilter`, `foldFilter`, `isFrontierKey`, `stagedApplier`, `stagedApplierMap`, and the `Tree` persistence/versioning — into clearly named `momentum_tree.go` / `momentum_fold.go`, with a package doc-comment delineating "SHARED CORE (frozen, used by L1 + L2)" vs "L1 MOMENTUM ADAPTER (not for L2)".
- *Preferred long-term:* extract the shared core into a `common/trie/smtcore` subpackage that depends only on `common/crypto` + `common/types`. `common/trie` (the L1 adapter) imports it; the L2 executor imports it directly. This makes the dependency direction enforce the boundary. Can be done in a later pass — C1/C2 are sufficient to unblock L2.

No symbol behaviour changes; this is packaging and documentation.

---

## 4. Change C4 — document the empty / present-empty boundary

Add explicit comments at both layers:

- **Shared core (`hash.go`):** keep/strengthen the existing note — `LeafHash(path, [])` is a valid *present-empty* leaf (`sha3(path)`, non-zero), distinct from the empty/absent slot (`emptyHash`). The core never folds empties; deletion vs present-empty is the caller's responsibility.
- **L1 adapter (`momentum_fold.go`):** state that the L1 momentum tree deliberately folds empty→delete because go-zenon storage has no present-empty values, giving history-independence. This is an L1 application choice, **not** a core rule.

---

## 5. Change C5 — decision: L1 keeps empty-as-delete (do not add present-empty to the momentum tree)

**Recommendation: no change to L1 semantics.** The momentum state tree commits to embedded-contract storage, which has no need for a present-empty value (setting empty == clearing). Keeping empty→delete preserves the existing history-independence property and avoids touching consensus-visible L1 behaviour. The present-empty distinction is required only by L2 (where `storage_len` must return `0` vs `-1`), and L2 implements it in its own applier (§6). Record this as a deliberate decision so a future reader does not "fix" it.

> If a future L1 feature ever needs present-empty, it becomes a versioned momentum-tree change at that time — out of scope here.

---

## 6. L2 executor adapter (new code, in the executor; contract defined here)

The executor does **not** use `Tree` at all. It maintains its own leaf set and drives the shared core:

```go
// Derive the SMT path for a contract-local key (spec §13.3). The result is the path directly.
func l2Path(contractID types.Hash, localKey []byte) types.Hash {
    return types.BytesToHashPanic(crypto.Hash(contractID[:], localKey)) // sha3(contract_id || local_key)
}

// Apply a canonical StateDiff (spec §13.5, §27.2) over the executor's leaf map.
// EMPTY sentinel (0xFFFFFFFF) deletes; a zero-length value is a PRESENT-EMPTY leaf.
func (s *L2State) apply(entries []StateDiffEntry) {
    for _, e := range entries {           // e.Key is the 32-byte derived path
        if e.IsDelete {                    // EMPTY sentinel
            delete(s.leaves, e.Key)
        } else {
            s.leaves[e.Key] = append([]byte{}, e.Value...) // len==0 is a real present-empty leaf
        }
    }
}

// Root and proofs come from the shared core, by path — never re-hashed.
func (s *L2State) Root() types.Hash { return trie.RootOfLeaves(s.leafSlice()) }
func (s *L2State) Prove(path types.Hash) (bool, []byte, []byte) { return trie.ProveLeaves(s.leafSlice(), path) }
```

`storage_len`/`storage_read` semantics (spec §27.8): a key absent from `s.leaves` → `-1`; present with zero-length value → `0`; present with `L>0` → `L`. Every observed path (including absent) is added to the input's witness set.

---

## 7. Testing & acceptance

- **Regression (must stay green):** `conformance_test.go` against `smt-v1-test-vectors.json` — proves roots and proof bytes are unchanged by C1–C3.
- **Equivalence:** add a test asserting `VerifyProof(root, key, …)` == `VerifyProofByPath(root, types.NewHash(key), …)` for random keys.
- **L2 applier:** add tests for the three observable conditions (absent vs present-empty vs present non-empty), deletion via the EMPTY sentinel producing a subsequent non-inclusion proof, and "delete non-existent key is a no-op" (root unchanged).
- **No-rehash guard:** a lint/review check that no caller outside the L1 adapter passes an already-32-byte derived key into `VerifyProof`/`Tree`.

**Acceptance criteria:** (1) all existing `common/trie` tests pass with identical expected vectors; (2) the L2 executor verifies its own proofs via `VerifyProofByPath`; (3) the Phase 2 referee (when built) verifies L2 proofs via `VerifyProofByPath` with no key hashing.

---

## 8. Rollout

Pure refactor + additive API. No data migration, no root change, no proof-byte change, no spork interaction. Land it on the merkle-state-root branch before `StateRootSpork` activation and before L2 executor work depends on the shared core. Risk: low (covered by the existing conformance vectors).
