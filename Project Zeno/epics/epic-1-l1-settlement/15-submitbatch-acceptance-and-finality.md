# Ticket 15 — `SubmitBatch` acceptance + finality state machine

**Epic:** 1 — L1 Settlement · **Phase:** 1B · **Order:** 15

## Goal
Implement batch-commitment acceptance — the heart of Settlement's anchoring role
— and the `SUBMITTED → FINALIZED` finality timer. Core verifies ordering,
contiguity, chaining, sizing, version, and asset-flow correspondence, but **never
execution correctness** (Phase 1). End state: a contiguous, well-chained batch
from the entitled proposer is accepted and finalizes after the withdrawal delay.

## SPEC refs
SPEC §19 (batch commitments, `SubmitBatch`), §4.6 (per-domain contiguity), §21
(finality / withdrawal delay), §18.4 (AssetFlowSummary), §24 (version
rejection), §6.2 (entitled proposer — `SINGLE`).

## Depends on
Tickets 12 (executor/bond), 13 (conservation/AssetFlowSummary hook), 09
(batch-chain + cursor storage), 10 (pause gate).

## Key work
- `SubmitBatch(commitment)` — decode the canonical commitment (§19 field order;
  version fields first; reject unknown `protocol_version` before other fields).
- Acceptance checks (all MUST): caller is an **ACTIVE** (registered + fully
  bonded, §22, Ticket 12) set member **and** the entitled proposer for
  `domainId` at the batch's `firstInputSeq` cursor (Phase 1 `SINGLE` ⇒ "is the
  domain's single registered, fully bonded executor"); per-domain
  contiguity against the stored cursor **and** Settlement's assigned input
  indices (§4.6) — `firstInputSeq` is the domain's earliest
  assigned-but-unconsumed index, `lastInputSeq` is assigned to the domain and
  ≤ the highest index assigned, range count ≤ `MaxBatchInputs`, no
  gap/overlap/replay; commitment size ≤ `MaxOnChainCommitmentSize (15 KiB)`;
  `assetFlowSummary` deposit correspondence against the cumulative deposit
  totals over the assigned-index range (Ticket 13 hook); `proofData` is the
  zero-length encoding (reject non-empty / trailing bytes);
  `preStateRoot == previous accepted postStateRoot`.
- On acceptance: store batch `SUBMITTED`, record `submittedAtHeight` and
  `executorId`, advance the domain cursor to `lastInputSeq`.
- Finality: a batch becomes `FINALIZED` when `WithdrawalDelay` momentum heights
  have elapsed from `submittedAtHeight` (height-based, not wall-clock).
  `FINALIZED` is the only time gate on withdrawal release (§21). Provide the
  read predicate consumed by `RelayMessage`/`Update` (Ticket 16).
- Respect `PAUSE_SUBMIT` (Ticket 10). Core MUST NOT verify `preStateRoot`/
  `postStateRoot` correctness or run WASM.

## Code references
- Ticket 03 commitment codec [NEW]; Ticket 09 cursor/batch storage [NEW].
- `vm/embedded/implementation/common.go` height-window helpers (`TimeChallenge`
  pattern for the delay) [EXISTS].

## Acceptance criteria
- Contiguous, correctly-chained batch from the registered executor is accepted;
  cursor advances.
- Rejections: non-proposer; gap/overlap/replay; non-`+successor`
  `firstInputSeq`; `lastInputSeq` beyond the highest Settlement-assigned index
  (receive-lag race, §4.6); `assetFlowSummary` not matching the cumulative
  deposit totals; `preStateRoot` mismatch; unknown `protocol_version`;
  non-empty `proofData`; oversize commitment; count > `MaxBatchInputs`.
- Finality timer: no withdrawal releasable while `SUBMITTED`; transitions to
  `FINALIZED` exactly at `submittedAtHeight + WithdrawalDelay`.
- Replacement-executor first batch with wrong `preStateRoot` rejected (closes the
  Ticket 12 loop).
