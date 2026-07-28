# Ticket 19 — Watcher role + best-effort DA serving

**Epic:** 2 — Executor · **Phase:** 1C · **Order:** 19

## Goal
Add the alarm-only watcher role and the best-effort DA layer. The watcher reuses
the executor pipeline minus submit, plus a compare stage; the DA layer
publishes/fetches bundles by `DAHash` over Sentinel/libp2p with a browser
gateway. End state: a watcher reproduces the proposer's roots and alarms on
divergence; bundles are retrievable by `DAHash`. Both are advisory in Phase 1.

## SPEC refs
EXECUTOR.md §4 (roles), §5.6 (DA layer), §11 (watcher role); SPEC §20 (DA,
`DAMode=0`), §1 (Phase 1 advisory — no on-chain divergence channel).

## Depends on
Tickets 06, 18. (Watcher needs the full pipeline + Settlement read path.)

## Key work
- **Watcher**: run §5.1–§5.4 identically to the executor, then instead of
  submitting: read the committed batch for the domain (via `GetProof`), compare
  committed `pre`/`postStateRoot`/`inputRoot`/`receiptRoot`/`outboxRoot`/`DAHash`
  to recomputed values over the same input-sequence range; on agreement advance,
  on divergence raise a **public alarm**. Phase 1 is **alarm-only** — MUST NOT
  build the Phase 2 fraud-proof emitter. A non-proposing set member SHOULD run as
  a watcher.
- **DA serving** (`DAMode=0`): publish bundles content-addressed by `DAHash` over
  Sentinel/libp2p, retrievable in chunks ≤ `MaxDAChunkSize`; a browser gateway
  for clients/watchers to fetch and reproduce. Best-effort, not consensus-
  critical.
- Disclose the Phase 1 DA limitation (unavailable bundle ⇒ reliance on executor
  honesty) in operator docs.

## Code references
- `rpc/api/ledger.go` `GetProof:361` [EXISTS] (committed-batch read).
- Sentinel/libp2p stack (`Libp2pSpork` context, `p2p/`) [EXISTS] as the serving
  substrate; bundle store from Ticket 07 `bundles/` [NEW].

## Acceptance criteria
- Watcher detects a deliberately corrupted commitment (root mismatch) and alarms;
  agrees silently on a correct one.
- A published bundle is fetchable by `DAHash` and its round-trip reproduces the
  committed roots.
- Watcher recovery/reconciliation reuses Ticket 07 logic unchanged (no separate
  execution code path).
