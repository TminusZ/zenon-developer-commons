# Ticket 18 — Settlement ABI/address integration + Settlement client

**Epic:** 2 — Executor · **Phase:** 1C · **Order:** 18

## Goal
Replace the executor's Settlement stubs (from Tickets 05/07) with the real ABI,
address, submission, and storage-read paths now that Epic 1 has landed. End
state: the executor decodes real Settlement inputs, submits `SubmitBatch`/
`RelayMessage`/`Update`, and reads the finalized recovery anchor from L1 state
proofs.

## SPEC refs
EXECUTOR.md §5.1 (input decode), §5.5 (Settlement client), §14 (recovery anchor),
§18 (prerequisites P-1…P-4, P-6); SPEC §19, §17.3.

## Depends on
Tickets 05, 06, 07 (executor) **and** Epic 1 Tickets 08, 15, 16 (Settlement
address/ABI, `SubmitBatch`, `RelayMessage`). This is the first cross-epic ticket.

## Key work
- Import the now-real `vm/embedded/definition` Settlement ABI + the Settlement
  address; replace the Ticket 05 plugin-decode stub so the input pipeline
  identifies and decodes Settlement-destined account-blocks (the six input
  kinds).
- Account-block construction/signing for executor submissions (wallet keys +
  embedded send pattern); build/send `SubmitBatch`, `RelayMessage`, and `Update`
  (the release crank, sent on finalization — EXECUTOR.md §9).
- Storage read path (P-6): read the domain cursor, batch status, and
  `postStateRoot` via `GetProof` against the L1 state root (`GetStateRoot`) —
  wire it into Ticket 07's recovery anchor interface, replacing the genesis-only
  fallback.
- Pre-submit guard: read the on-chain cursor before `SubmitBatch`; on a rejected
  (superseded) submission treat as `READY` per the §15 failure table.
- `submissionKeySource` (FILE/ENV/KMS) injected at boot, never embedded.

## Code references
- `rpc/api/ledger.go` `GetProof:361`, `GetStateRoot:349`,
  `GetDetailedMomentumsByHeight:446` [EXISTS].
- `wallet/` (keys/signing), embedded send pattern [EXISTS].
- `vm/embedded/definition/settlement.go` (Epic 1, Ticket 08) [NEW].
- Bonded registration mirror `vm/embedded/implementation/sentinel.go:30`
  (`RegisterSentinelMethod`) [EXISTS].

## Acceptance criteria
- Executor decodes a real Settlement `CallL2`/`Deposit`/deploy input from a
  confirmed momentum.
- `SubmitBatch` for a contiguous batch is accepted on-chain (integration test
  against a local node with the spork enforced).
- Recovery anchor reads the latest `FINALIZED` batch via `GetProof` and
  reconciles; mismatch → HALTED (closes Ticket 07 against the real path).
