# State-Tree Activation Build — Async / Non-Blocking Options (future pivot)

> **Status:** Design reference for a FUTURE pivot. **Not the v1 design.** v1 builds the state tree
> **synchronously** during `chain.Init` (a blocking, bulk, one-time build that mirrors
> `chainCache.Init`); see the implementation spec, §7. This document specifies the alternatives to
> reach for *if and only if* a mainnet-copy measurement shows the synchronous build's downtime is
> unacceptable even with the bulk-build algorithm and rolling/staggered upgrades.
>
> **Why this exists:** the synchronous build is simpler and safe by construction, but it takes the
> node offline for the duration of the one-time build. If that duration turns out to be too long
> for operators, this doc captures two ways to get the build off the critical path — *and the
> correctness rules a working async build must obey*, which a naive async build (an earlier draft of
> the spec) got wrong.

---

## 0. Decision ladder

Climb only as far as the measurement forces you:

1. **Synchronous bulk build (v1, default).** Build during `chain.Init`, blocking, bottom-up bulk
   construction. Node down for the build. Safe by construction — no concurrency. *Mitigate downtime
   operationally:* rolling pillar upgrades keep the **network** producing while individual nodes
   blip offline, staggered across the days-long spork campaign window.
2. **Offline pre-build tool (§2).** Build the tree against a DB snapshot *while the old binary keeps
   running*, then catch up a small delta synchronously on upgrade. **Near-zero downtime, no
   live-concurrency.** This is the preferred pivot — much simpler than rung 3.
3. **Concurrent async build (§3).** Build in a background goroutine while the upgraded node runs
   live. Node stays fully responsive during the build. **Only take this if rungs 1–2 are
   genuinely insufficient** — it adds consensus-adjacent concurrency code that must obey the
   non-negotiable locking rules in §3.2, or it is incorrect.

The whole point of the v1 sequencing is that you measure before climbing. Build time must be
measured on a mainnet copy (it is a release-gating item); that number tells you whether you ever
leave rung 1.

---

## 1. Why the naive async build was wrong (the trap to avoid)

An earlier spec draft proposed a background goroutine that coordinated only on the state tree's own
`changes` mutex. An independent critic pass found this is a **cross-lock data race**, because of how
go-zenon's locking actually works:

- Every live insert and reorg driver holds the **chain-wide `c.insert` mutex** (`AcquireInsert`,
  `chain/chain.go:139`) across its main-DB mutation.
- `chainCache` is lock-free-safe *only because of an invariant the naive build broke*: the cache is
  **never advanced or rewound except by code already holding `c.insert`** (`UpdateCache` /
  `RollbackCacheTo` are always called from inside the insert-locked driver — `protocol/broadcaster.go`,
  `protocol/chain_bridge.go`).
- A reorg's `Pop()` **deletes the patch** at the rolled-back height
  (`ldb.Delete(patchByte…)`, `common/db/versioned_db.go:383`, via `RollbackTo`
  `chain/momentum_pool.go:78`) under `momentumPool.changes` — a *different* lock from the tree's
  `changes` mutex.

So a background build holding only `stateTree.changes` can call `GetPatch(101)` at the exact moment
a concurrent reorg deletes patch 101 — and fold a nil/half-rolled-back read or an orphaned-branch
momentum into the consensus tree. Coordinating on the tree's own mutex does nothing to exclude the
reorg, which runs on `c.insert` + `momentumPool.changes`.

**The lesson, and the rule for any async build:** the build touches chain state (`GetPatch`,
`GetMomentumByHeight`, the main DB), so it must serialize with inserts/reorgs on the **same lock
they use** — `c.insert` — not on a private mutex. The synchronous v1 build sidesteps this entirely:
it runs inside `chain.Init`, before any driver runs, so there is no concurrent reorg to race.

---

## 2. Offline pre-build tool (preferred pivot — rung 2)

Goal: pay the one-time build cost **without** taking the live node down and **without** any
live-concurrency machinery.

**Shape:** a `znnd` subcommand, e.g. `znnd state-tree prebuild [--db <path>]`.

1. Operator points it at a **copy/snapshot** of the node's LevelDB (or runs it against the live DB
   during a brief planned pause). The old binary can keep running on the original DB.
2. The tool runs the **same bulk bottom-up `BuildFrom`** the synchronous v1 build uses (spec §4.2),
   producing the tree node-store up to the snapshot's frontier. It writes the tree into the same
   on-disk location the upgraded binary will look for.
3. Operator upgrades. On first start, the new binary's `stateTree.Init` finds a tree already built
   to height *H_snapshot*. It only needs to **catch up the delta** from *H_snapshot* to the current
   startup frontier — synchronously, the normal Init path, but now a *small* fold (minutes since the
   snapshot, not the whole history).

**Why this is simple:** the catch-up delta runs inside `chain.Init` exactly like v1 — quiescent main
DB, no concurrent reorg, no `c.insert` dance, no ready flag. The only new surface is the offline
command and its operator docs. Downtime collapses to the small delta-catchup.

**Caveats:**
- The snapshot frontier must be recent enough that the delta-catchup is short. Document a recommended
  "snapshot, then upgrade within N hours" window.
- Building against a live-mutating DB copy is fine *because it is a copy* — the bulk build reads a
  frozen snapshot; live mutation happens on the original DB and is reconciled by the delta-catchup.
- The prebuilt root must match what the node would compute itself (history-independence, spec §6.4) —
  the same equivalence test that covers v1 covers this.

---

## 3. Concurrent async build (rung 3 — only if rungs 1–2 are insufficient)

A background goroutine builds the tree while the upgraded node runs live and stays responsive
(sync, RPC, P2P, even v2 momentum production). This is the responsiveness-during-build option.
**It is only correct if it obeys §3.2.**

### 3.1 Shape
- Launch from `zenon.Start()` after `z.chain.Start()` (`zenon/zenon.go:76-95`); `chain.Start()` is a
  no-op (`chain/chain.go:96-101`), so the goroutine is the launch vehicle.
- A `ready atomic.Bool` (starts false). While not ready, the producer does not emit v3 and the
  verifier cannot enforce v3 — the **fail-closed** behaviour: a not-ready node behaves exactly like
  an un-upgraded node (it does not produce or accept an invalid momentum; it simply does not
  participate in v3 until built). Re-add to the `StateTree` interface: `StateTreeReady() bool`; and
  `ErrStateTreeNotReady` from `ComputeStateRoot`/`StateRoot`/`GetProof` until ready.
- Build loop folds heights `treeFrontier+1 …` using the bulk or incremental fold, applying the
  §3.1.1 FoldFilter (exclude `{0}/{1}/{2}`) so the build root equals the live root.
- Progress logging (height, %, ETA), like the cache's "Initializing cache: N%".
- Restart-safe: the persisted tree frontier is wherever the last committed version left it; Init
  resumes the background build from there.

### 3.2 NON-NEGOTIABLE correctness rules (the fixes for the §1 race)

1. **Hold `c.insert` around every batch's main-DB read + fold + commit.** The build MUST
   `AcquireInsert` (`chain/chain.go:139`) before reading `GetPatch`/`GetMomentumByHeight` and
   computing+committing the batch, and release after. This serializes the build with inserts and
   reorgs on the lock they actually use, making the §1 patch-deletion race impossible. Use
   **bounded batch sizes** (e.g. a few hundred heights per acquisition) so the build does not starve
   live inserts — acquire, fold a bounded chunk, release, repeat.
2. **Re-derive the live frontier momentum store each batch.** Do NOT fold from a momentum store
   snapshot captured at startup (`chainCache.Init`'s `frontierStore` is bound to the startup height
   and never observes live-inserted momentums — it would never let the build catch a moving
   frontier). Under the held `c.insert`, re-read the current frontier
   (`GetFrontierMomentumStore()`) at the top of each batch.
3. **Flip `ready` under `c.insert`, not the tree mutex.** The "caught up" decision — observe the
   live chain frontier, confirm the tree frontier equals it (height AND hash), set `ready = true` —
   must run inside the `c.insert` critical section that orders chain-frontier advancement. Flipping
   under only the tree's `changes` mutex can latch `ready` one momentum early (the chain frontier
   advances under `momentumPool.changes`, which the tree mutex does not hold), and `ready` is a
   one-way latch that gates consensus enforcement. Once flipped, the goroutine exits and
   `UpdateStateTree` is the sole writer (normal `chainCache` model).
4. **`UpdateStateTree` must be idempotent during the build.** While the build and the live driver
   both advance the tree, `UpdateStateTree` must no-op for any height `≤ tree.FrontierIdentifier()`
   (already folded) and fold only `frontier+1`. (This is net-new logic the `chainCache` template
   does not provide — the cache's `update` unconditionally applies; the async build is the only
   thing that needs it. Another reason rung 3 is the last resort.)
5. **Truncation interaction.** Because every batch re-reads the live frontier under `c.insert` and
   never caches a private "next height" across lock releases, a reorg's `TruncateStateTreeTo`
   (sibling of `RollbackCacheTo`, runs inside the insert-locked driver) naturally rewinds the build:
   the next batch resumes from the rewound frontier it re-reads under the lock. The invariant is that
   the build never folds a height it has not just re-derived from the live frontier under `c.insert`.

### 3.3 What rung 3 costs vs rung 1
Re-added surface relative to the synchronous v1: the `ready` flag + `StateTreeReady()` interface
method, `ErrStateTreeNotReady` and its handling, the producer not-ready guard in
`pillar/worker_momentum.go`, the bounded-batch `c.insert` loop, the live-frontier re-derivation, the
idempotent `UpdateStateTree`, the `zenon.Start()` goroutine launch, and the handoff + reorg-mid-build
tests. This is precisely the surface v1 deletes — which is why rung 3 is reserved for a measured,
demonstrated need.

---

## 4. Choosing

| | Downtime | Live-concurrency code | Operator UX | When |
|---|---|---|---|---|
| **Rung 1 — synchronous (v1)** | Full build, blocking | None | Restart in a window; rolling upgrades keep network up | Default. Keep unless measured too slow. |
| **Rung 2 — offline pre-build** | Small delta only | None | New `prebuild` command + docs | If rung-1 downtime is too long. Preferred pivot. |
| **Rung 3 — concurrent async** | None | Significant (must obey §3.2) | Transparent, but riskier code | Only if responsiveness *during* build is a hard requirement rungs 1–2 can't meet. |

The fail-closed guard means an up-but-not-ready node (rung 3) still can't produce or enforce v3 — so
during the spork campaign window, rung 3's "responsive during build" benefit is smaller than it
looks. Within a days-long window, rung 1 with rolling upgrades, or rung 2, almost always suffices.

---

## 5. Cross-references
- Synchronous v1 build: spec §7.2–§7.6 (`.pipeline/research/merkle-state-root/spec.md`).
- The race this doc's §1/§3.2 fixes: `.pipeline/research/merkle-state-root/critique-2.md`, Issues 1–3.
- FoldFilter (the canonical fold rule all build paths must apply): spec §3.1.1.
- Bulk `BuildFrom` construction: spec §4.2.
- Full-depth, history-independent hashing (why all build paths converge to one root): spec §6.4.
- Relevant code: `chain/cache.go` (template), `chain/chain.go:139` (`AcquireInsert`),
  `common/db/versioned_db.go:383` (`Pop` deletes patches), `protocol/broadcaster.go`,
  `protocol/chain_bridge.go` (insert/rollback drivers).
