# Ticket 16 — `RelayMessage` registration + `Update` withdrawal release

**Epic:** 1 — L1 Settlement · **Phase:** 1B · **Order:** 16

## Goal
Implement the two-method withdrawal path: permissionless `RelayMessage`
registration of a proven, finalized outbox message, and the permissionless,
rate-limited `Update` crank that releases queued withdrawals under the
conservation, replay, and fan-out bounds. End state: a finalized L1-withdrawal
outbox message can be registered exactly once and released by the next `Update`,
with aggregate solvency preserved and `FINALIZED` as the only time gate.

## SPEC refs
SPEC §17 (outbox/messaging, replay, `RelayMessage`), §18.2/§18.3 (release queue,
`Update`, conservation), §21 (finality — the only time gate), §27.9
(`MaxWithdrawalsPerUpdate`, fan-out bounds), §27.10 (pause), §5.3
(`RelayMessage`, `Update`), §28 (`Update` crank precedent).

## Depends on
Tickets 15 (FINALIZED batches + committed `outboxRoot`), 13 (conservation
counters), 09 (release queue + `lastUpdate` storage), 10 (pause gate).

## Key work
- `RelayMessage(domainId, batchId, message, inclusionProof)` — permissionless,
  **registration-only, releases no funds**. Verify: batch is `FINALIZED`;
  inclusion proof of `message` against the batch's committed `outboxRoot`
  (§27.3 Merkle); the supplied `domainId`/`batchId` match the batch whose
  `outboxRoot` verifies the proof (reject mismatch);
  `outboxId = sha3(domainId‖batchId‖inputIndex‖outboxIndex)` not in
  `processedOutbox`. Record `outboxId` at registration (at-most-once — a message
  is registered exactly once, ever).
- L1 withdrawal (`kind==1`) registration: increase
  `pendingWithdrawalReserve[domainId][asset]` and append to the domain's release
  queue in registration order. No additional delay — `FINALIZED` already gates.
- `Update()` — permissionless, rate-limited via `checkAndPerformUpdate` /
  `UpdateMinNumMomentums` (the Accelerator-payout pattern). Each accepted call
  drains the domain's release queue in registration order, at most
  `MaxWithdrawalsPerUpdate (16)` per call: per release, move the amount to
  `totalReleased`, decrease `pendingWithdrawalReserve`, transfer via a
  descendant `ContractSend`, re-check conservation (§18.3).
- Per-(domain, asset) batch withdrawal cap `MaxBatchWithdrawal` enforced;
  runtime-emitted deposit refunds (§18.5) excluded from the cap (still
  conservation-bounded).
- Pause interaction (§27.10): `PAUSE_SUBMIT` MUST NOT freeze registration or
  release for `FINALIZED` batches; `PAUSE_RELAY` halts both `RelayMessage`
  registration and `Update` release and is separately authorized; on
  deactivation, queued withdrawals release again in unchanged registration
  order.

## Code references
- `vm/vm.go` (descendant `ContractSend` from embedded; unlimited embedded
  plasma) [EXISTS]; `pillar/worker_contract_generator.go` (auto-receive)
  [EXISTS].
- `vm/embedded/implementation/accelerator.go` (`UpdateEmbeddedAcceleratorMethod`)
  + `vm/embedded/implementation/common.go` (`checkAndPerformUpdate`) — the
  `Update` crank pattern [EXISTS]; `vm/constants/embedded.go`
  (`UpdateMinNumMomentums`) [EXISTS].
- Ticket 03 outbox + proof codecs [NEW]; Ticket 13 conservation helper [NEW];
  Ticket 09 release queue [NEW].

## Acceptance criteria
- Registration of a valid finalized withdrawal records `outboxId`, increases the
  reserve, and enqueues; the next `Update` releases it (transfer + counters +
  conservation re-check). A relay against a `SUBMITTED` batch is rejected.
- Replay of the same `outboxId` rejected; a proof valid against a mismatched
  domain/batch rejected.
- `Update` releases in registration order, stops at `MaxWithdrawalsPerUpdate`,
  and a second `Update` within `UpdateMinNumMomentums` is rejected; remaining
  queue entries release on the next accepted call.
- Aggregate per-(domain, asset) cap enforced; refund withdrawals exempt from the
  cap but conservation-bounded.
- Deposit-refund path (EXEC-FAIL-OUTBOX-1 / EXEC-DEP-1) releases the unclaimed
  remainder to the original depositor.
