# Ticket 04 — Deterministic WASM runtime plugin (high-level / sub-project)

**Epic:** 2 — Executor · **Phase:** 1A · **Order:** 04

> **Scope note.** This is the single largest and highest-risk Phase 1 component
> (`EXECUTOR.md` P-5; SPEC §29 "retires the deterministic-instrumentation risk
> first"). It is captured here as **one high-level ticket** and **must be broken
> into its own sub-ticket set** before implementation. The breakdown below is the
> seam map for that follow-up planning, not a 2–5 day unit.

## Goal
A deterministic WebAssembly Core 1.0 interpreter, packaged as the WASM `Domain`
plugin, that turns `(witnessed pre-state, input) → ContractEffects` byte-
identically across implementations. End state: `execution-conformance-v1.json`
green; all WASM-specifics live behind `Domain.Apply`/`DecodeInput`.

## SPEC refs
SPEC §7 (runtime profile, prohibited capabilities, limits, traps), §8 (three-
import host ABI), §9 (execution context), §10 (gas, `metering_version=1`), §11
(deployment validation + instrumentation), §12 (identity/upgrade), §14/§27.1/
§27.1a (entry-point ABI, effects blob), §18.5 (deposit claim/refund STF step).

## Depends on
Tickets 02 (witnessing `StateAccess`) and 03 (serializer).

## Suggested sub-ticket breakdown
1. **Assembly + module validation pipeline** (§7.1/§7.2, §11.3 STF half):
   chunk assembly in ascending index with `sha3(assembled) == code_hash` and
   `len == total_size` verification (mismatch ⇒ `VALIDATION_FAILED`, no
   contract — Settlement only checks per-chunk hashes, Ticket 14); Core 1.0
   structural validation; reject WASI/floats/threads/atomics/SIMD,
   sign-extension & `trunc_sat`; restrict imports to exactly
   `storage_len`/`storage_read`/`abort`; required exports `memory` +
   `run (i32,i32)->i64`.
2. **Deterministic instrumentation** (§7.4, §11): gas-metering injection (basic-
   block model), stack-depth limiter (`MaxStackDepth=512`), memory-growth
   limiter (`MaxMemory=4 MiB`); deterministic output; post-instrumentation size
   ≤ 1 MiB; `CodeHash = sha3(instrumented)`.
3. **Gas metering** (§10, `metering_version=1`): opcode table from
   `wasm-gas-table-v1.json` exactly; `memory.grow` + initial-memory per-page
   charge; host-fn charge before invocation; post-execution effect charge;
   `OUT_OF_GAS` rollback.
4. **Host ABI + entry-point** (§8, §27.1): three imports; zero-init memory;
   input-frame write at offset 0; `run` return decoding (`r≥0` ptr/len, `r<0`
   abort), trap ⇒ `RUNTIME_FAULT`.
5. **Effects + deposit settlement** (§14.2/§14.3, §27.1a, §18.5): validate
   returned blob (reject roots in blob, missing `claimed_deposit`,
   `claimed_deposit>deposit_amount`); compute refund outbox; `ContractID`
   derivation (§12); upgrade policy enforcement.

## Code references
- `../WASM Spec/wasm-gas-table-v1.json` / `.md` [ARTIFACT].
- `../WASM Spec/execution-conformance-v1.json` [ARTIFACT].
- Lives entirely inside the WASM plugin, **never** in `go-zenon` (EXECUTOR.md
  §1.4). A WASM interpreter library choice is part of sub-ticket planning.

## Acceptance criteria
- **This ticket regenerates `execution-conformance-v1.json` against the current
  SPEC** (deposit frame fields + mandatory `claimed_deposit`, §27.1/§27.1a),
  adds EXEC-DEP-1/2/3 and EXEC-FAIL-OUTBOX-1 (SPEC §31), retires the stale
  banners on the artifact README and SPEC §31, and all vectors pass.
- Determinism harness: identical `(module, input, witnessed pre-state)` yields
  byte-identical `ContractEffects` and `postStateRoot` across two builds.
- CV-DEPLOY-1 single-chunk sizing; CV-OUTBOX-1 enforced at runtime.
- All §7.2 prohibited features rejected at validation with explicit reasons.
