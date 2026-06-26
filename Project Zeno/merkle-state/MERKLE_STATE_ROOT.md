# Momentum State Root — Feature Overview

> **Status:** Implemented (spork-gated, inactive until `StateRootSpork` activates).
> **What it is:** an authenticated commitment to all of go-zenon's consensus state, recorded in each momentum
> header and signed by the producing pillar. It lets anyone prove "key K has value V (or is absent) at height H"
> against a signed header, with no trust in the node serving the proof — the basis for light clients, state-sync,
> and the off-chain execution layer's Phase 2 fraud-proof referee.

---

## 1. What it adds

Before this feature a node could commit to the *diff* of each momentum (`ChangesHash`) but could not prove an
individual state fact to a third party — answering "what is the balance of address A?" required replaying the
whole patch history. This feature maintains a Merkleized image of the full state and publishes its root in the
momentum header, so a single key/value (or its absence) is provable with a compact proof that verifies against
the header alone.

The state root is a pure function of the state *set* (history-independent), so a node that builds it by replaying
from genesis and a node that builds it from an already-synced database arrive at the identical root.

---

## 2. How it works

**The tree (`common/trie`).** A versioned, full-depth-256 binary sparse Merkle tree, SHA3-256 throughout:

- Leaf at position `path = sha3(dbkey)`, hashed `sha3(path ‖ value)` over the raw value.
- Interior node `sha3(left ‖ right)`, with a both-empty short-circuit (a node whose children are both the zero
  hash is itself zero).
- Empty subtrees are the constant 32-byte zero at every level; routing is MSB-first, `0`→left / `1`→right.
- Persisted as an on-disk node store (`trie.NodeTree`) keyed by `(version, path)`, with a reversible per-version
  delta so a reorg can undo and historical heights can be read.

This is the **same library and proof format used by the L2 executor** in the off-chain execution layer, so one
verifier serves both L1 and L2 reads.

**What the root commits to (the fold rule).** The tree folds exactly the canonical write-set that `ChangesHash`
already commits to, minus the three momentum-frontier metadata keys (`{0}/{1}/{2}`) — `trie.FoldFilter`. The
producer, verifier, live maintainer, and startup build all apply the identical rule, so the root can never
diverge between them.

**Where the root lives (`chain/nom/momentum.go`).** A new `StateRoot` (32-byte) momentum field, `rlp:"optional"`,
folded into `Momentum.ComputeHash()` from **momentum version 3** (`StateRootMomentumVersion`). It is appended raw
after the version-2 (dynamic-plasma) bytes, so version-2 momentums hash and serialize exactly as before — the
field is backward-compatible by construction and is only emitted once populated.

**Producer and verifier.**

- The pillar producer (`pillar/worker_momentum.go`) stamps version 3 and sets `StateRoot` in `packMomentum` once
  the momentum's changes are known.
- The verifier (`verifier/momentum.go`) enforces it: before activation `StateRoot` must be zero; after activation
  it recomputes the candidate root with `ComputeStateRoot(previous, changes)` and rejects the momentum if it
  doesn't match (`ErrMStateRootInvalid`). Because the existing `ChangesHash` check still runs alongside, any
  divergence is caught either way.

**Node integration (`chain/state_tree.go`).** The tree mirrors `chainCache`'s lifecycle:

- **Init** — a synchronous catch-up build that folds every momentum from the tree frontier up to the chain
  frontier (the DB is quiescent at Init, so there is no concurrent insert/reorg to race). The tree is maintained
  from genesis onward on every node, so the root is ready the moment the spork activates.
- **UpdateStateTree** — folds one momentum's write-set per insert.
- **TruncateStateTreeTo** — undoes versions on a reorg (bounded by the rollback window).

---

## 3. Public surface

| Surface | Where | Purpose |
|---|---|---|
| `StateRoot` momentum field (v3) | `chain/nom/momentum.go` | Signed, hash-committed root in every post-activation momentum |
| `NodeTree` API (`Update`/`Commit`/`Root`/`ComputeRoot`/`Prove`/`Truncate`/`Prune`) | `common/trie` | Versioned tree maintenance + proof generation |
| `VerifyProof` / `VerifyAbsence` | `common/trie` | Pure (no-DB) proof verification — runs in a light client or the on-chain dispute referee |
| `ledger.getStateRoot(height)` | `rpc/api/ledger.go` | Read the root at a height (errors if pruned below a non-archive node's horizon) |
| `ledger.getProof(height, key)` | `rpc/api/ledger.go` | `{value, proof, root}` — proof verifies against the header `StateRoot`, no node trust required |
| `cmd/prove-balance` | `cmd/prove-balance` | CLI demonstrating end-to-end proof + verification |

A compact proof is ~1–1.4 KB in practice (32 bytes per non-zero sibling), well under the 16 KB account-block data
cap — which is what lets a proof be submitted on-chain to the future dispute referee.

---

## 4. Node-operator impact

- **First start on the upgraded binary** builds the tree to the chain frontier (synchronous; progress is logged
  for large catch-ups). Genesis-sync nodes maintain it as they sync.
- **Disk:** the node store grows with state. Default nodes **prune** versions older than the retention floor
  (rollback window + ~2 days of margin); **archive** nodes keep every version and can serve historical proofs.
  Configuration in §5.
- **Reorgs** undo tree versions in lock-step with the chain, within the rollback window.
- **Format migration:** if the on-disk store predates the node-store format, the node wipes and rebuilds it from
  chain patches automatically on start.
- **Old binaries** stall/exit at enforcement, exactly like previous sporks, before the first rooted momentum
  reaches them.

---

## 5. Configuration

Pruning is the only operator-tunable aspect. The tree's format and its retention floor are fixed — the
consensus-visible hashing must not vary, and the floor protects reorg-safety — so the single knob is whether to
keep *everything* (archive) or prune to the retention window (default).

**Archive mode** — a node-config flag in `config.json`:

```json
{
  "StateTreeArchive": true
}
```

- `StateTreeArchive` (bool, default `false`). When `true`, pruning is disabled: the node keeps every tree version
  and can serve `ledger.getProof` / `ledger.getStateRoot` at any historical height. When `false`, the node prunes
  and serves proofs only within the retention window; older heights return a "no such version" error.
- The flag is read at startup. Switching an already-pruned node to archive does **not** back-fill versions it
  already dropped — to get a full archive, delete the `statetree` directory and let it rebuild from genesis on the
  next start, or sync an archive node from genesis.
- Pruning is local-only; it never changes a root or affects consensus.

**Retention window (non-archive)** — fixed, not configurable:

- rollback window = `100` momentums (the chain's reorg bound),
- margin = `17280` momentums (≈ 2 days at 10s momentums), comfortably past an off-chain challenge window,
- ⇒ roughly `17380` momentums (~2 days) of historical proofs on a default node.

These are compile-time constants (`stateTreeRetentionMargin` in `chain/state_tree.go`; the rollback size in
`chain/cache/storage`). Keeping more history than that requires archive mode — there is no partial-retention
config value.

**Storage location** — the tree has its own LevelDB at `<DataDir>/statetree` (`Config.StateTreeDir()`), separate
from the main `nom` database.

---

## 6. Activation

Gated by `StateRootSpork` (placeholder hash until governance creates it), following the standard spork flow
(create → activate → enforcement after the min-height delay). Its enforcement height must be at or above the
dynamic-plasma spork's, since version 3 implies the version-2 rules. The root is *maintained* from genesis on
every node before activation; it is only *written into headers and enforced* once the spork is active.

---

## 7. Relationship to off-chain execution

The same `common/trie` library and proof format back the L2 executor's state tree in the off-chain execution
layer. The L1 root here gives trustless reads of Settlement-contract storage and L1 inputs; the L2 root commits
the executor's state in each batch. Sharing one tree means the Phase 2 fraud-proof referee verifies L1 and L2
reads with a single verifier. See `../phase-2/SPEC.md`.

---

## 8. Key files

`common/trie/` (hash, compute, proof, node store) · `chain/state_tree.go` · `chain/nom/momentum.go` ·
`verifier/momentum.go` · `pillar/worker_momentum.go` · `common/types/spork.go` (`StateRootSpork`) ·
`rpc/api/ledger.go` · `cmd/prove-balance/`.

Plain-language explainer: `MERKLE_STATE_GUIDE.md`.
