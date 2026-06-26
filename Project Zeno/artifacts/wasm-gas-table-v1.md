# wasm-gas-table-v1.md — Zenon WASM Layer Opcode Gas Table V1

**Companion to:** `wasm-gas-table-v1.json`
**Normative status:** This artifact and its JSON are normative companions of the Phase 1 spec `../SPEC.md` (§10, §13.7). Where the JSON specifies a cost, that cost is binding and an implementation **MUST** reproduce it exactly.
**metering_version:** `1`
**Runtime profile:** WebAssembly Core 1.0 MVP, integer subset.

`wasm-gas-table-v1.json` is the machine-readable source of truth (Go, Rust, TypeScript consume it directly). This document explains the model and is normative where it states rules.

---

## 1. Scope and exclusions

**Normative:**

- The gas table covers every WebAssembly Core 1.0 instruction that survives the deployment validation pipeline (`../SPEC.md` §7.2, §11.3).
- The following are **never metered** because they are rejected at deployment and can never appear in an instrumented module: all `f32.*`/`f64.*` floating-point instructions; all `v128` SIMD instructions; all threads/atomics instructions; all WASI imports. The sign-extension operators (`i32.extend8_s`, `i32.extend16_s`, `i64.extend8_s`, `i64.extend16_s`, `i64.extend32_s`) and saturating float-to-int conversions (`*.trunc_sat_*`) are outside the strict Core 1.0 MVP and are likewise rejected and unmetered.
- An instruction not present in `wasm-gas-table-v1.json` and not in the rejected set **MUST NOT** appear in a validated module; if encountered, the module **MUST** be rejected at deployment, not assigned an implicit cost.

The metered set is **104 opcodes** across nine groups: control, parametric, variable, memory, numeric constants, comparisons, i32 numeric, i64 numeric, and integer conversions.

---

## 2. Unit and cost principles

**Normative:**

- Costs are in L2 gas (plasma) units (`../SPEC.md` §10.1). They are unrelated to L1 plasma.
- Every cost is a fixed non-negative integer. Costs **MUST NOT** change without a `metering_version` increment, because in Phase 3 the table becomes part of the arithmetic circuit (`../SPEC.md` §10.2).

The cost scale (informative rationale):

- `1` — trivial: integer constants, local access, `i32`/`i64` add, sub, and, or, xor, shifts, rotates, and all comparisons.
- `2` — light: loads and stores, `mul`, `clz`/`ctz`/`popcnt`, global access, `select`, integer conversions, `memory.size`.
- `5` — integer `div`/`rem` (variable-latency division) and the base cost of `memory.grow`.
- Control transfer is modeled explicitly: `br`/`br_if`/`br_table` and `return` cost `2`; `call` costs `5`; `call_indirect` costs `10` (table bounds check, type check, dispatch).

---

## 3. Basic-block metering model

**Normative:**

- Gas for straight-line instructions **MUST** be summed per basic block and decremented once at block entry (the standard fuel model). The observable gas cost of executing a basic block **MUST** equal the exact sum of its instructions' table costs.
- The gas counter **MUST** be checked at each basic-block boundary, before each host-function call, and before the post-execution effect charge. On exhaustion at any of these points the input **MUST** fail `OUT_OF_GAS` with full rollback (`../SPEC.md` §10.3–10.5).
- Instrumentation is deterministic (`../SPEC.md` §11.3). Two compliant implementations **MUST** decrement identical gas totals for identical executed basic-block sequences.

---

## 4. Surcharges

Two instructions carry a size-dependent surcharge on top of their base table cost.

**Normative:**

- `br_table`: total = base `2` + `1` per branch target in the table, counting the default target. A `br_table` with `N` labelled targets plus the default costs `2 + (N + 1)`.
- `memory.grow delta`: total = base `5` + `1000` per page grown, where one page is `65536` bytes. A `memory.grow` that would exceed `MaxMemory` (`../SPEC.md` §25) **MUST** return `-1`, grow nothing, and charge only the base `5`; the per-page charge is **not** applied to the rejected pages.

---

## 5. Memory model

**Normative:**

- One WASM page is `65536` bytes.
- `memory.grow` base cost is `5` (in the opcode table); the per-page surcharge is `1000` (Section 4).
- Initial declared memory at instantiation **MUST** be charged as `1000 * initial_pages` against the input's L2 gas budget before execution begins. If the budget cannot cover it, the input fails `OUT_OF_GAS` before the contract runs.

---

## 6. Host-function gas

The Phase 1 host ABI has exactly three imports (`../SPEC.md` §8.1). Host gas is charged at invocation, before the host function runs (`../SPEC.md` §10.3).

**Normative:**

| Host function | Cost |
|---------------|------|
| `storage_len(key)` | `100` (fixed; key length bounded by `MaxStateKeySize = 32`, no per-byte term) |
| `storage_read(key)` | `200 + 10 * ceil(value_bytes / 32)`; an absent key (returns `-1`) charges the base `200` only |
| `abort(code)` | `1` |

`ceil(n / 32) = (n + 31) / 32` integer division.

---

## 7. Post-execution effect charge

After the contract returns its `ExecutionResult` blob and before the `StateDiff` is applied, the runtime charges for declared effects from their serialized sizes (`../SPEC.md` §10.4). If remaining gas cannot cover the full effect charge, the input fails `OUT_OF_GAS` with full rollback; no effects are applied.

**Normative:**

| Effect (per item) | Cost |
|-------------------|------|
| `StateDiff` entry | `500 + 20 * ceil(value_bytes / 32)`; a deletion (EMPTY sentinel, `value_bytes = 0`) charges the base `500` only |
| Event | `100 + 10 * ceil(data_bytes / 32)` |
| Outbox message | `200 + 5 * ceil(payload_bytes / 32)` |
| `ReturnData` (once) | `10 + 2 * ceil(return_bytes / 32)` |

---

## 8. Worked examples

These are illustrative; the JSON is authoritative.

- `storage_read` of a 100-byte value: `200 + 10 * ceil(100/32) = 200 + 10*4 = 240`.
- `StateDiff` entry writing a 64-byte value: `500 + 20 * ceil(64/32) = 500 + 20*2 = 540`.
- `StateDiff` deletion (EMPTY sentinel): `500`.
- `memory.grow` by 3 pages: `5 + 1000*3 = 3005`.
- `br_table` with 5 labelled targets plus default: `2 + (5 + 1) = 8`.
- An event with 200 bytes of data: `100 + 10 * ceil(200/32) = 100 + 10*7 = 170`.

---

## 9. Conformance

An implementation is gas-conformant iff:

- it assigns every metered opcode exactly the cost in `wasm-gas-table-v1.json`;
- it rejects (does not meter) every excluded instruction in Section 1;
- it applies the `br_table` and `memory.grow` surcharges exactly;
- it charges host functions and post-execution effects per Sections 6 and 7;
- it checks gas at every basic-block boundary, host call, and the effect charge, failing `OUT_OF_GAS` with full rollback on exhaustion;
- it produces identical total gas for identical executed instruction sequences as any other compliant implementation.
