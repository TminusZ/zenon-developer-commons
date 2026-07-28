# Ticket 11 — Domain registry + `RegisterDomain` lifecycle

**Epic:** 1 — L1 Settlement · **Phase:** 1B · **Order:** 11

## Goal
Implement admin-only domain registration and the lifecycle constraints that make
the schema multi-domain-ready while pinning Phase 1 to the degenerate WASM case.
End state: exactly one domain can be registered (WASM / `L1_NATIVE` / `SINGLE` /
size-1); reserved input sources and policies are rejected.

## SPEC refs
SPEC §6 (domain model / generalized `DomainRecord`), §6.1 (input-source
descriptor), §6.2 (executor set / proposer policy), §6.3–§6.4 (execution /
foreign-fact profile ladders — reserved), §6.5 (legal combinations, custody modes
— reserved), §5.3 (`RegisterDomain`); runtime-upgrade delay floor §6/§23.

## Depends on
Tickets 09 (storage/constants), 10 (admin gate).

## Key work
- `RegisterDomain(domainClass, runtimeKind, stfSpecHash, inputSource, execProfile,
  foreignProfile, profileConfig, chainBinding, minExecutors, valueCaps, status, …)`
  — admin-only. Assign `domainId (u32)`. The method accepts the full generalized
  field set (Ticket 09 stores it) even though Phase 1 pins it to one point.
- **Phase 1 profile clamp (§6.1, §6.5):** accept only `domainClass = EXECUTION`,
  `runtimeKind = WASM`, `inputSource = L1_NATIVE`, `execProfile = ATTESTATION`,
  `foreignProfile = NONE`, `chainBinding = null`, `proposerPolicy = SINGLE`,
  `minExecutors = 1`, `executors` size 1. **Reject** any other value for the new
  semantics-defining fields (`domainClass ∈ {BRIDGE, MESSAGING}`, any
  `execProfile`/`foreignProfile` above the base rung, a non-null `chainBinding`, a
  non-`ESCROW` custody mode) exactly as reserved `inputSource`/policies are
  rejected, while the Phase-1 profile is in force. Also verify `finalityModel`
  matches `execProfile` (`ATTESTATION → DELAY`).
- Treat `domainClass`/`inputSource`/`execProfile`/`foreignProfile`/`chainBinding`/
  `executors`/`proposerPolicy` as fixed at registration; changes only via governed
  mechanisms; a change to any semantics-defining field is a `stfSpecHash` bump
  under `MinRuntimeUpgradeDelay`.
- Runtime-upgrade path: `stfSpecHash` bump under a mandatory delay with the Core
  hard floor `MinRuntimeUpgradeDelay ≥ WithdrawalDelay` (reject shorter).
- Per-domain keying invariant: all later accounting keyed by `domainId` /
  `(domainId, asset)` — this ticket establishes the registry the rest reads.

## Code references
- Ticket 09 `DomainRecord` storage [NEW].
- Admin verification pattern: `vm/embedded/implementation/bridge.go`
  (`sendBlock.Address == Administrator`) [EXISTS] (consumed via Ticket 10).

## Acceptance criteria
- Registering `EXECUTION`/WASM/`L1_NATIVE`/`ATTESTATION`/`NONE`/`SINGLE`/size-1
  succeeds and is readable (all generalized fields round-trip at their defaults).
- Registering a reserved value fails: reserved `inputSource`, reserved
  `proposerPolicy`, `domainClass ∈ {BRIDGE, MESSAGING}`, `execProfile ≠ ATTESTATION`,
  `foreignProfile ≠ NONE`, non-null `chainBinding`, or a `finalityModel`
  disagreeing with `execProfile`.
- A second `RegisterDomain` is allowed by schema but gated by admin (Phase 1
  registers exactly one in practice); test both the success and the reserved-
  rejection paths.
- A configured runtime-upgrade delay `< WithdrawalDelay` is rejected by Core.
