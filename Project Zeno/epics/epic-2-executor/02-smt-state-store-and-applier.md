# Ticket 02 — SMT state store, witnessing accessor, L2 StateDiff applier

**Epic:** 2 — Executor · **Phase:** 1A · **Order:** 02

## Goal
Build the executor's L2 state layer over the shared `common/trie` path-native
API: a persistent SMT cache, a witnessing `StateAccess`, and the canonical L2
`StateDiff` applier that honours the present-empty / absent / EMPTY-delete
distinction. End state: SMT and path/applier conformance vectors pass; the store
can produce `preStateRoot`/`postStateRoot` and witnesses for any leaf set.

## SPEC refs
SPEC §13.1 (shared pure layer, path-native API), §13.3 (key derivation),
§13.4 (tree/proof shape), §13.5 / §13.5.1 (canonical applier), §13.6 (absent vs
present-empty), §13.7 / §31 (conformance); EXECUTOR.md §5.3, §10.

## Depends on
Ticket 01 (module + interfaces).

## Key work
- Wrap `RootOfLeaves` / `ProveByPath` / `VerifyProofByPath` /
  `VerifyAbsenceByPath` only. **Never** call key-hashing verifiers,
  `Tree.Update`, `stagedApplier`, or `CompactTree` (L1-only — would double-hash
  or fold empty→delete).
- Implement the canonical L2 applier of §13.5.1 verbatim: `0xFFFFFFFF` ⇒ delete
  (absent), `0x00000000` ⇒ present-empty (`LeafHash(key,[])`=`sha3(key)`),
  delete-absent = no-op, full rollback on input failure. Assert
  incremental-root == fresh `RootOfLeaves` recompute after every apply.
- Witnessing `StateAccess`: every `Read`/`Len`, **including absent observations**,
  captured automatically (the plugin never builds a witness). Expose the three
  observable conditions of §13.6/§27.8 (`-1` / `0` / `L`).
- Persistent cache with crash-recoverable writes (WAL or equivalent); the store
  is a cache of derivable state, never the source of truth.
- Derived-key handling: the runtime consumes already-derived 32-byte paths
  (`sha3(contract_id‖local_key)`, §13.3); the store must **not** hash again.

## Code references
- `common/trie/pathapi.go` (`RootOfLeaves`, `ProveByPath`) [EXISTS].
- `common/trie/proof.go` (`VerifyProofByPath`, `VerifyAbsenceByPath`) [EXISTS].
- `common/trie/hash.go` (`LeafHash`, `InternalHash`) [EXISTS].
- `common/trie/conformance_test.go` + `../WASM Spec/smt-v1-test-vectors.json`,
  `proof-format.md` [ARTIFACT].

## Acceptance criteria
- SMT-001…SMT-014 reproduce roots/proof bytes byte-for-byte.
- **This ticket authors the CV-PATH-1/2 and CV-APPLY-1/2 vectors** (SPEC §31)
  into `smt-v1-test-vectors.json` (both copies) and they pass: path-native
  equivalence; present-empty ≠ absent; mixed present-empty + EMPTY delete
  post-root; incremental == full recompute. `go-zenon`'s
  `conformance_test.go` is extended to gate them on the L1 side.
- Adversarial double-hash trap test passes (the key-hashing verifier rejects a
  path supplied as a key).
- Crash-recovery test: kill mid-write, reopen, root matches last committed.
