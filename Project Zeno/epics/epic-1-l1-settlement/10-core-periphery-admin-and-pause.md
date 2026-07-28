# Ticket 10 — Core/Periphery, administration, guardians, emergency pause

**Epic:** 1 — L1 Settlement · **Phase:** 1B · **Order:** 10

## Goal
Implement the administration layer: a single time-challenged Settlement
administrator, guardian recovery, Core hard-bound clamping of all Periphery
values, and the two-scope emergency pause — all reusing the bridge
`SecurityInfo`/`TimeChallenge` machinery. End state: Periphery is admin-tunable
within Core bounds; Core is unreachable by the admin; pause works global and
per-domain.

## SPEC refs
SPEC §5.2 (Core/Periphery), §23 (administration, guardians, hard bounds, escape
hatch, emergency pause), §27.10 (relay under pause).

## Depends on
Ticket 09. Provides the admin gate consumed by Tickets 11, 12, 13, 15, 16.

## Key work
- Single administrator address in storage; admin-gated methods verify
  `sendBlock.Address == Administrator` (bridge pattern). `ChangeAdministrator`
  effective only after `AdministratorDelay ≥ MinAdministratorDelay
  (2×MomentumsPerEpoch)`; soft param changes after `SoftDelay ≥
  MinSoftDelay (MomentumsPerEpoch)`.
- Guardians (`SecurityInfo.Guardians`) vote to install a new admin under
  `AdministratorDelay` (lost/compromised key recovery).
- Periphery setters (clamped by Core): `DAMode` set, withdrawal-delay/challenge
  window, `MaxBatchWithdrawal`, per-domain executor identity + `valueCaps`,
  guardian set, pause-authority address, reserved Phase 2/3 verifier registries.
  **Core MUST clamp** to immutable hard bounds (§09 holders) — even a
  compromised admin cannot exceed them.
- `Pause` method: scopes `PAUSE_SUBMIT` (halts `SubmitBatch`) and `PAUSE_RELAY`
  (halts `RelayMessage` registration and `Update` release), settable global or
  per-domain; default activation sets `PAUSE_SUBMIT` only; `PAUSE_RELAY` is a
  separately authorized escalation emitting a distinct public event. Pause never
  rewrites history.
- Administrator prohibitions (§23) enforced: cannot alter finalized
  roots/receipts/balances/order/conservation/SMT/serialization formats.
- Domain escape hatch (§23 carve-out) — stub the method signature + event +
  time-lock now; forced-withdrawal mechanics may be a follow-up within this
  ticket's PR or a tracked sub-task.

## Code references
- `vm/embedded/implementation/common.go` (`TimeChallenge` ~:439),
  `vm/embedded/implementation/bridge.go` (`SecurityInfo`, `Administrator`,
  guardians, `Halt`/`Unhalt`, `ProposeAdministrator`/`ChangeAdministrator`,
  `NominateGuardians`, `Emergency`) [EXISTS].

## Acceptance criteria
- Admin change respects `AdministratorDelay`; pending change observable before
  activation; guardian recovery installs a new admin under the delay.
- Periphery value above a Core hard bound is clamped/rejected (test the
  `MaxBatchWithdrawal` ceiling and the runtime-upgrade-delay floor).
- `PAUSE_SUBMIT` blocks `SubmitBatch` but withdrawals from `FINALIZED` batches
  still register and release; `PAUSE_RELAY` requires separate authorization and
  emits its event; deactivation restores releasability in unchanged registration
  order.
