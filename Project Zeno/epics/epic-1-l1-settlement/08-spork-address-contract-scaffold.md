# Ticket 08 — Spork, address, and Settlement contract scaffold

**Epic:** 1 — L1 Settlement · **Phase:** 1B · **Order:** 08

## Goal
Register a new spork-gated embedded contract following the HTLC precedent: add
`OffchainExecutionSpork`, the Settlement embedded address, an empty ABI
definition, the `applySettlementDiffs` gate, and a `Method`-interface skeleton.
End state: before spork enforcement every Settlement method rejects; after, the
(empty) method map is reachable. No business logic yet.

## SPEC refs
SPEC §5.1 (activation), §5.2 (Core/Periphery split), §28 (codebase foundations);
EXECUTOR.md §6.

## Depends on
None (first L1 ticket). Independent of Epic 2.

## Key work
- Add `OffchainExecutionSpork` to `common/types/spork.go` with a placeholder
  hash and entry in `ImplementedSporksMap`, following the documented release flow
  (placeholder → `CreateSpork` → real id → `ActivateSpork`). It is a **contract-
  activation** spork — **no momentum-version bump** (unlike `StateRootSpork`).
- Add `IsOffchainExecutionSporkEnforced()` in `vm/vm_context/spork.go`, mirroring
  `IsHtlcSporkEnforced()`.
- Add `SettlementContract` address via `parseEmbedded("z1qxemdeddedx…")` and
  append to `EmbeddedContracts` in `common/types/address.go`.
- New `vm/embedded/definition/settlement.go` ABI stub + method-name constants.
- New `applySettlementDiffs(contractsMap)` in `vm/embedded/embedded.go`, gated
  inside `GetEmbeddedMethod` by `context.IsOffchainExecutionSporkEnforced()`;
  wire into `getAllEmbedded()` for tests.
- Skeleton `Method` impls (`GetPlasma`/`ValidateSendBlock`/`ReceiveBlock`) under
  `vm/embedded/implementation/settlement.go` returning not-implemented.

## Code references
- `common/types/spork.go` (`NewImplementedSpork`, `ImplementedSporksMap`,
  `HtlcSpork`, `StateRootSpork`) [EXISTS].
- `common/types/address.go` (`parseEmbedded`, `EmbeddedContracts`,
  `HtlcContract:32`) [EXISTS].
- `vm/embedded/embedded.go` (`getOrigin`, `applyHtlcDiffs:45`,
  `GetEmbeddedMethod:220`, gate at `:240`) [EXISTS].
- `vm/vm_context/spork.go` (`IsHtlcSporkEnforced`) [EXISTS].

## Acceptance criteria
- Before enforcement: a call to any Settlement selector returns
  `ErrContractDoesntExist`/method-not-found (rejected).
- After enforcement (test override of `ImplementedSporksMap`, dp_test pattern):
  the Settlement address resolves and the skeleton method is dispatched.
- Existing embedded-contract tests still pass (no regression to the HTLC/bridge
  gates).
