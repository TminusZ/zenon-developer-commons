# Ticket 12 — Executor registration + two-leg bond

**Epic:** 1 — L1 Settlement · **Phase:** 1B · **Order:** 12

## Goal
Bind/replace the single executor identity per domain (admin) and implement the
sentinel-style two-leg bond the executor posts itself: QSR deposited first,
ZNN posted second, both returnable via revocation once the executor is replaced
and its batches finalize. End state: a domain has exactly one registered
executor that becomes ACTIVE only when fully bonded; replacement preserves state
lineage. No slashing (Phase 2).

## SPEC refs
SPEC §22 (executor model, bond posting/return), §6.2 (executor set / `SINGLE`),
§5.3 (`RegisterExecutor`, `DepositQsr`/`WithdrawQsr`, `PostBond`, `RevokeBond`),
§19 (ACTIVE required for `SubmitBatch`), §23 (admin-gated registration), §25.2
(bond amounts).

## Depends on
Tickets 11 (domain exists), 10 (admin gate).

## Key work
- `RegisterExecutor(domainId, executorAddress)` — admin-only identity binding.
  Phase 1: `executors` must contain exactly one member; reject a second active
  member.
- Bond legs, posted by the registered executor address (sentinel flow):
  - `DepositQsr` — accumulate QSR against the sender (`GetQsrDeposit` pattern);
    `WithdrawQsr` reclaims while unconsumed.
  - `PostBond(domainId)` — carries exactly the ZNN leg as the attached amount;
    accepted only from the domain's registered executor address and only when
    the accumulated QSR deposit covers the required amount, which it consumes
    (`checkAndConsumeQsr` pattern).
- ACTIVE predicate: registered **and** fully bonded — exposed to Ticket 15's
  `SubmitBatch` check. Bond amounts ≥ the **Core-ceiling** value of
  `MaxBatchWithdrawal` (not the current Periphery value), so an admin raising
  the cap can never under-collateralize (§25.2 pre-mainnet amounts).
- `RevokeBond(domainId)` — accepted only from an address that is **no longer**
  the registered executor and only when every batch it submitted is
  `FINALIZED`; returns both legs in full (sentinel revoke-window analogue).
- Replacement: a replacement's first batch `preStateRoot` MUST equal the last
  accepted `postStateRoot` for the domain; registration MUST NOT alter finalized
  state. Record `executorId` in storage (§19 commitment field) —
  forward-compatible with a Phase 2 set, no format change.
- Downtime lever (Phase 1): admin may replace an unresponsive executor via
  `RegisterExecutor` after the applicable `AdministratorDelay` (documented, no
  automation); the replaced executor's bond exits via `RevokeBond`.

## Code references
- `vm/embedded/implementation/sentinel.go` (`RegisterSentinelMethod:30` —
  exact-amount ZNN leg + QSR consumption; `RevokeSentinelMethod:85`) [EXISTS].
- `vm/embedded/implementation/common.go` (`DepositQsrMethod:196`,
  `WithdrawQsrMethod`, `checkAndConsumeQsr`, `GetQsrDeposit`) [EXISTS].
- `vm/constants/embedded.go` (`SentinelZnnRegisterAmount:51`,
  `SentinelQsrDepositAmount:52` — amount-constant pattern) [EXISTS].
- Ticket 10 admin gate; Ticket 09 executor/bond + QSR-deposit storage [NEW].

## Acceptance criteria
- Register → `DepositQsr` → `PostBond` activates the executor; `PostBond` from
  an unregistered address, with insufficient QSR, or with a wrong ZNN amount is
  rejected; a second concurrent active member is rejected.
- `WithdrawQsr` reclaims an unconsumed deposit; it cannot reclaim a consumed
  bond leg.
- An executor that is registered but not fully bonded is not ACTIVE
  (`SubmitBatch` rejected — verified end-to-end with Ticket 15).
- `RevokeBond` while still registered, or while a `SUBMITTED` (un-finalized)
  own batch exists, is rejected; after replacement + finalization both legs
  return in full.
- Replacement whose first batch `preStateRoot` ≠ last `postStateRoot` is
  rejected (verified end-to-end with Ticket 15).
