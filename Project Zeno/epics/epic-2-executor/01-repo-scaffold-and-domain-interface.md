# Ticket 01 — Executor repo scaffold + Domain plugin interface

**Epic:** 2 — Executor · **Phase:** 1A · **Order:** 01

## Goal
Stand up the executor as a separate Go module that pins `go-zenon` as a
dependency, define the generic-runtime / plugin-domain seam (`Domain`, `Source`,
`StateAccess`, `Effects`), and the single-instance lease. End state: an empty but
type-complete runtime that compiles, registers a no-op WASM plugin, acquires a
boot lease, and exits cleanly. No execution, no chain I/O yet.

## SPEC refs
EXECUTOR.md §1.4 (packaging, one-way dependency), §2 (principles), §5 (layered
runtime skeleton), §7 (plugin interface), §13 (single-instance lease); SPEC §3,
§6.

## Depends on
None. This is the first ticket and has no on-chain dependency.

## Key work
- Create repo/module `github.com/zenon-network/zenon-executor` with
  `require github.com/zenon-network/go-zenon vX.Y.Z` (pin a commit). Import only
  consensus-frozen packages: `common/trie`, `common/types`,
  `vm/embedded/definition` (the last is stubbed until Epic 1 lands the ABI).
- Define the plugin interface exactly as EXECUTOR.md §7:
  `Domain{ Genesis, DecodeInput, Apply }` and optional `Source{ Watch }`; plus
  runtime-supplied `StateAccess{ Read, Len }` and `Effects` (mirrors
  `ContractEffects`, SPEC §14.2).
- `runtime.New(cfg)` + `exec.Register(plugin)` + `exec.Run()` wiring; static,
  compile-time plugin registration (no dynamic loading). Register a stub
  `wasm.New()` that returns `Genesis()=empty` and errors on `Apply`.
- Single-active-instance lease at boot (file lock or external lease); a
  non-holder exits before entering the loop (EXECUTOR.md §13). Enforce the
  one-way dependency direction with a CI/lint check: `go-zenon` is never
  imported in reverse.
- Per-domain in-process state/key isolation scaffolding (EXECUTOR.md §4).

## Code references
- `common/trie/pathapi.go` [EXISTS] — the only trie seam the executor consumes.
- `common/types` (`Address`, `Hash`, `AccountHeader`) and `chain/nom`
  (`AccountBlock`, `Momentum`) [EXISTS].
- EXECUTOR.md §7 plugin interface block [NEW code, spec-defined].

## Acceptance criteria
- Module builds with `go-zenon` pinned; `go vet` clean.
- A grep proves the executor imports **only** the path-native trie API — zero
  references to `VerifyProof(`/`VerifyAbsence(`/`Tree.Update`/`stagedApplier`/
  `CompactTree` (EXECUTOR.md §19 precondition).
- Lease test: a second process with the same `executorId` fails to acquire and
  exits non-zero without entering the loop.
- `exec.Run()` with the stub plugin starts, logs registration, and shuts down
  cleanly on signal.
