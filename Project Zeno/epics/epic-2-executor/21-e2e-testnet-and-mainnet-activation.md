# Ticket 21 — End-to-end integration, testnet, and mainnet activation

**Epic:** 2 — Executor (operational; spans Epic 1) · **Phase:** 1C · **Order:** 21

## Goal
Bring the whole system live: register the WASM domain and the bonded executor,
run the full deposit → call → batch → finalize → withdraw flow end-to-end on
testnet, set pre-mainnet parameters within Core bounds, then activate the spork
on mainnet. End state: a working Phase 1 off-chain WASM execution layer on
mainnet behind `OffchainExecutionSpork`.

## SPEC refs
SPEC §29-1C (build sequencing), §25.2 (pre-mainnet parameters), §5.1 (activation),
§4 / §18 / §19 / §21 (the end-to-end path); EXECUTOR.md §20 (phase mapping).

## Depends on
All prior tickets (01–20); the E2E flows run against the Ticket 20 system vault
contract.

## Key work
- Operational bring-up: `RegisterDomain(WASM, L1_NATIVE, SINGLE, size-1)`;
  `RegisterExecutor` + two-leg bond (`DepositQsr` → `PostBond`, §22) with
  combined value ≥ the Core-ceiling `MaxBatchWithdrawal`; deploy the system
  vault (Ticket 20) as the first contract.
- Set pre-mainnet parameters (§25.2) within Core hard bounds: withdrawal-delay
  duration, executor bond amount/denomination, `MaxBatchWithdrawal` + its
  ceiling, per-domain `valueCaps` (window length/reset), administrator + guardian
  set, emergency-pause authority, runtime-upgrade delay length.
- **E2E flows** on testnet (ARCHITECTURE.md §4): payable `CallL2` deposit-and-call
  with partial-claim refund; pure `Deposit`; chunked deploy + finalize; L2→L1
  withdrawal via outbox → batch `FINALIZED` → `RelayMessage` registration →
  `Update` release; force-inclusion; pause/unpause; executor replacement
  preserving lineage; crash-recovery against a finalized anchor.
- Spork release flow: placeholder → governance `CreateSpork` → real id in
  `common/types/spork.go` → coordinated binary release → `ActivateSpork` →
  enforcement. Stand up DA serving + browser gateway (Ticket 19) at activation.

## Code references
- `common/types/spork.go` release-flow comments (placeholder → activate)
  [EXISTS].
- `vm/embedded/tests/` (e.g. `state_root_test.go`, `dp_test.go`,
  `z_bridge_test.go`) as integration-test patterns with spork override [EXISTS].

## Acceptance criteria
- Full testnet E2E green: deposit-and-call (with refund), deploy, withdrawal
  release, force-inclusion, pause behaviour, executor replacement, crash
  recovery.
- Conservation holds across the whole run:
  `totalReleased + pendingWithdrawalReserve ≤ totalDeposited` per (domain, asset)
  at every step.
- All §31 conformance suites green in the executor's CI and the node's trie/
  embedded tests.
- Trust-model disclosure (SPEC §1) published with activation: Phase 1 is bonded
  attestation, not trustless execution.
