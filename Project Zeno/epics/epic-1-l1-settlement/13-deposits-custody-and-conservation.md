# Ticket 13 — Deposit custody, conservation invariant, AssetFlowSummary

**Epic:** 1 — L1 Settlement · **Phase:** 1B · **Order:** 13

## Goal
Implement the value layer: the `Deposit` method, the aggregate per-(domain,
asset) custody counters, the on-chain conservation invariant enforced on every
mutating path, the canonical `AssetID` encoding, and `AssetFlowSummary` deposit
correspondence. End state: aggregate over-withdrawal is impossible on-chain,
independent of executor honesty.

## SPEC refs
SPEC §18.1 (AssetID), §18.1a (no protocol ledger), §18.2 (deposits/withdrawals),
§18.3 (conservation), §18.4 (AssetFlowSummary), §18.5 (deposit delivery/claim/
refund — the on-chain custody half); §5.3 (`Deposit`).

## Depends on
Tickets 11 (domain), 09 (counters storage).

## Key work
- `Deposit(domainId, target_contract, …)` — user send carrying a ZTS value;
  `ValidateSendBlock` rejects a non-custodyable asset for the domain. On embedded
  receive, increase `totalDeposited[domainId][asset]` **unconditionally and
  finally** (L1 transfer already settled). Enqueue the deposit as a canonical
  input delivered to `target_contract` (empty payload); off-chain runtime handles
  claim/refund.
- Input-admission helper (shared, §4.6): on every valid input receive, assign
  the next global input index, record it against the domain, and update the
  per-(domain, asset) cumulative deposit totals at that index. Undecodable sends
  consume no index. This helper is consumed by every input method (this ticket's
  `Deposit`, plus Tickets 14 and 17) and is what Ticket 15 verifies batch bounds
  against.
- Canonical `AssetID` (§18.1): 32-byte ZTS encoding (`[0:22]` zero, `[22:32]`
  ZTS); reject non-zero high bytes (`UNSUPPORTED_OPERATION` on user input,
  `VALIDATION_FAILED` on `SubmitBatch`) and non-canonical alignment. One custody
  pot per real asset.
- Track only aggregates: `totalDeposited`, `pendingWithdrawalReserve`,
  `totalReleased` — **no per-account ledger**.
- Conservation check (§18.3) as a shared helper run after **every** mutating
  deposit/withdrawal/release path: revert if
  `totalReleased + pendingWithdrawalReserve > totalDeposited`
  (`ErrSettlementConservationViolated`). This is the **`ESCROW`** custody-mode
  invariant — the only mode in Phase 1. The `MINTED` predicates and their
  reconciliation (§18.3, OD-1) are reserved and out of scope here.
- `AssetFlowSummary` verification hook (consumed by Ticket 15): on `SubmitBatch`,
  verify each summary `depositCredit` against the per-(domain, asset) cumulative
  deposit totals over the batch's assigned-index range (§4.6, §18.4 — incl.
  payable `CallL2` deposits). `depositCredit` = on-chain deposited amount,
  independent of contract claim outcome.
- Undeployed `target_contract` ⇒ the input fails `VALIDATION_FAILED` and the full
  `deposit_amount` is auto-refunded via the §18.5 path (runtime-emitted refund;
  on-chain side honours it through `RelayMessage` registration + `Update`
  release, Ticket 16).

## Code references
- `vm/vm.go` (token burn/mint, descendant `ContractSend`, embedded
  auto-receive observing `sendBlock.TokenStandard`/`Amount`) [EXISTS].
- `vm/embedded/implementation/liquidity.go` (`LiquidityStakeMethod` — value +
  call in one send) [EXISTS].
- `common/types/tokenstandard.go` (ZTS) [EXISTS]; serializer AssetID (Ticket 03
  shares the encoding) [NEW].

## Acceptance criteria
- Deposit increases `totalDeposited`; a non-custodyable asset is rejected in
  `ValidateSendBlock`.
- Input admission assigns strictly increasing indices in receive order across
  mixed input kinds; an undecodable send consumes no index; cumulative deposit
  totals reproduce each deposit's amount at its assigned index.
- CV-ASSET-1/2 (round-trip; reject non-canonical) pass on the L1 side.
- Conservation helper reverts any operation that would breach the invariant
  (unit test each path).
- A deposit to an undeployed target yields `VALIDATION_FAILED` + full refund
  registered (EXEC-DEP-3 on-chain half).
