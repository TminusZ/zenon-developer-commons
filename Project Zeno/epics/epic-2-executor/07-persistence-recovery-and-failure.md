# Ticket 07 — Persistence, recovery state machine, fail-closed handling

**Epic:** 2 — Executor · **Phase:** 1A · **Order:** 07

## Goal
Make the executor crash-safe and fail-closed: the on-disk layout, atomic cursor
writes, the boot→ready recovery state machine that reconciles against the most
recent finalized on-chain root, reorg handling, and the `HALTED`/`AWAIT_DA`
terminal states. End state: the executor survives kill-at-any-point with no
reorder/skip/duplicate and halts (never silently continues) on any consistency
fault. The finalized-anchor *read path* is interface-stubbed until Ticket 18.

## SPEC refs
EXECUTOR.md §14 (recovery & state machine), §15 (failure table), §16 (storage
layout); SPEC §21 (finality).

## Depends on
Tickets 05, 06. (Recovery anchor read from Settlement storage → P-6, wired in
Ticket 18; here, code against an interface with a genesis fallback.)

## Key work
- Storage layout per `EXECUTOR.md §16`: `state/`, `snapshots/` (tagged
  `inputSeq`+`stfSpecHash`), `bundles/` (by `DAHash`), atomic `cursor` (rename-
  over), `momentum_hashes/`, `batches/`, `meta.json`.
- Recovery machine: `BOOT → LOAD_SNAPSHOT → FIND_RECOVERY_ANCHOR →
  RECONCILE_FINALIZED_ROOT → REPLAY_POST_ANCHOR → READY`; anchor = most recent
  `FINALIZED` batch `postStateRoot`+`lastInputSeq`, fallback genesis (empty SMT,
  seq −1).
- Forward replay walks the **domain subsequence** (next `globalInputIndex`
  belonging to the domain), never `+1`.
- Edge cases: anchor-ahead-of-local (local-absent → replay forward vs root
  mismatch → HALT); intermediate-finalized mismatch → HALT; reorg ≤
  `confirmationDepth` → rollback+re-derive, deeper → HALT; `AWAIT_DA` with
  bounded retry → HALT on exhaustion.
- Failure table (§15): malformed effects → `RUNTIME_FAULT` (stay READY);
  trie/`DAHash`/anchor mismatch, corruption → HALTED; znnd unavailable → backoff
  then HALT; superseded submission → READY. Transient faults may auto-restart;
  consistency faults stay HALTED until operator action.

## Code references
- `rpc/api/ledger.go` `GetStateRoot` (~:349), `GetProof` (~:361) [EXISTS] — the
  anchor read path, behind an interface until Ticket 18.
- EXECUTOR.md §14 state diagram [spec-defined].

## Acceptance criteria
- Crash-recovery test reconciles against a finalized anchor with no
  reorder/skip/duplicate.
- Snapshot-substitution and root-mismatch tests reach HALTED.
- Reorg rollback test (≤ depth) re-derives correctly; deeper reorg halts.
- Missing local bundle for an un-finalized batch enters `AWAIT_DA`, then HALTs on
  retry exhaustion — never silent.

## Phase 1A exit gate
With Tickets 01–07 complete (and Ticket 04's sub-tickets), the executor passes
the EXECUTOR.md §19 component + operational conformance with execution stubbed or
real, **before any chain change** — satisfying SPEC §29-1A.
