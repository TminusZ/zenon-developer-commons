# Ticket 06 — STF driver, batch builder, commitment & DA bundle

**Epic:** 2 — Executor · **Phase:** 1A · **Order:** 06

## Goal
The execution loop that feeds decoded inputs to `plugin.Apply` one at a time with
the witnessing accessor, collects effects, computes `pre`/`postStateRoot`,
charges effect gas, slices the domain subsequence into contiguous batches, and
assembles the batch commitment + DA bundle (`DAHash`). End state: a full batch
commitment and bundle are produced and self-verified for a stub/real plugin, with
the `DAHash` round-trip enforced.

## SPEC refs
SPEC §13.5 (apply-on-success), §14 (results), §15 (receipts), §16 (events),
§17 (outbox), §18.4 (AssetFlowSummary), §19 (commitment), §20 (DA bundle);
EXECUTOR.md §5.2, §5.4, §9.

## Depends on
Tickets 02 (store/witness), 03 (serializer), 05 (ordered inputs). Real execution
needs Ticket 04; until then drive a stub `Apply`.

## Key work
- Per input: `DecodeInput → Apply (witnessed) → stage effects → receipt`;
  compute `preStateRoot` (before) and `postStateRoot` (after applying the
  staged `StateDiff` on success only).
- Batch slicing: contiguous over **this domain's subsequence** up to
  `MaxBatchInputs (64)`; a batch begins at the successor of the domain's own
  cursor, never `globalIndex+1`; ≥1 input per batch.
- Assemble roots: `inputRoot`, `receiptRoot`, `eventRoot`, `outboxRoot` (§27.3
  construction, correct orderings), and `AssetFlowSummary` (deposit credit /
  withdrawal debit per asset, incl. refund debits, ≤ `MaxAssetsPerBatch`).
- Build the canonical DA bundle (`BundleInputRecord` per input, ascending
  `globalInputIndex`, witnesses ascending by derived key, no duplicates);
  `DAHash = sha3(bundle)`.
- **Fail-closed `DAHash` round-trip**: reconstruct from the persisted bundle,
  confirm equality before any submit; mismatch → halt (EXECUTOR.md §5.4, §15).
- Enforce per-batch `MaxBatchWithdrawal` aggregation rules and the refund
  exemption (§27.9) at build time so batches are never built unsubmittable.

## Code references
- Tickets 02/03 packages [NEW].
- SPEC §20 bundle layout; §27.3 Merkle [spec-defined].

## Acceptance criteria
- Replay determinism: same inputs → identical roots, `ExecutionResult`s, and
  `DAHash` across runs.
- `DAHash` round-trip verified; a deliberately corrupted bundle halts before
  submit.
- A batch with one absent read produces the CV-BUNDLE-1 `DAHash`.
- Batch never exceeds `MaxBatchInputs`; per-domain contiguity holds across a
  multi-batch slice.
