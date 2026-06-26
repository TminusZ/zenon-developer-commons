# execution-conformance-v1 — README

Normative companion artifact (`../SPEC.md` §13.7). Machine-readable vectors are in `execution-conformance-v1.json`. Each vector is the full bridge from input to committed state: **input frame → pre-state → real WASM execution → `ContractEffects` → canonical `ExecutionResult` → `postStateRoot` + receipt**.

## What each vector contains

- `input_frame_hex` — the exact `ExecutionInputFrame` bytes the runtime writes at memory offset 0 (spec 27.1).
- `context` — the context fields encoded into that frame.
- `pre_state_local` / `pre_state_derived` — pre-state shown by local key and by derived SMT key `SHA3-256(contract_id || local_key)` (`../SPEC.md` §13.3).
- `pre_state_root` — SMT root of the pre-state (full-depth-256, SHA3-256, MSB-first, 0=left/1=right; same profile as `smt-v1-test-vectors.json`).
- `status` — `SUCCESS`, `REVERT`, or `RUNTIME_FAULT`.
- On `SUCCESS`:
  - `contract_effects_blob_hex` — exact bytes the contract's `run` returns (no roots).
  - `execution_result_blob_hex` — canonical `ExecutionResult` bytes after the runtime inserts `preStateRoot`/`postStateRoot`.
  - `execution_result` — decoded view; `state_diff_local` (length-prefixed local keys, as emitted) and `state_diff_derived` (fixed 32-byte derived keys, ascending, as committed).
  - `post_state_derived`, `expected_post_state_root`, `expected_event_root`, `expected_outbox_root`, `receipt_hex`.
  - `witness_keys` — derived SMT keys observed via `storage_len`/`storage_read`, including **absent** reads.
- On failure: `expected_post_state_root == pre_state_root` (full rollback), plus a failed-input `receipt_hex`.

## Key rules these vectors lock (resolved while authoring)

1. **ContractEffects vs ExecutionResult.** The contract returns a `ContractEffects` blob with no roots (it cannot compute SMT roots). The runtime computes `preStateRoot`/`postStateRoot` and assembles the canonical `ExecutionResult` (`../SPEC.md` §14.2, §27.1). The runtime never trusts a contract-supplied root.
2. **Host-side key derivation.** Contracts pass and emit `local_key`s; the runtime derives `SHA3-256(contract_id || local_key)` using the executing contract's own `contract_id`, so a contract cannot address another contract's state (`../SPEC.md` §13.3).
3. **StateDiff key encoding differs by blob.** In `ContractEffects`, StateDiff keys are length-prefixed local keys, unordered. In the canonical `ExecutionResult`, StateDiff keys are fixed 32-byte derived keys, ascending, deduplicated (spec 27.2).

## Reproduction

Every vector was produced by executing a real WebAssembly module under the three-import ABI (`abort`, `storage_len`, `storage_read`) and was then independently re-derived from the JSON fields alone: parse pre-state → apply StateDiff → recompute `postStateRoot`; reassemble the `ExecutionResult` blob; recompute event/outbox roots. An implementation is execution-conformant iff, for every vector, it reproduces `contract_effects_blob_hex` (given the same module), `execution_result_blob_hex`, `expected_post_state_root`, `expected_event_root`, `expected_outbox_root`, `receipt_hex`, and the `witness_keys` set.

## Coverage

EXEC-001 pure return / no state · EXEC-002 single write · EXEC-003 update · EXEC-004 delete (EMPTY sentinel) · EXEC-005 present-empty value · EXEC-006 multi-key StateDiff ordering · EXEC-007 event emission · EXEC-008 L1 withdrawal outbox · EXEC-009 combined write+event+outbox+return · EXEC-010 `abort` → REVERT rollback · EXEC-011 trap → RUNTIME_FAULT rollback · EXEC-012 absent-read witnessing.
