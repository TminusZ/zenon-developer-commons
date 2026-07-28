# Ticket 17 — `CallL2` / `UpgradeContract` input surface + payable deposits

**Epic:** 1 — L1 Settlement · **Phase:** 1B · **Order:** 17

## Goal
Complete the WASM-domain user input surface: `CallL2` (payable) and
`UpgradeContract`, which enqueue canonical inputs into the domain's stream and,
for payable calls, route attached value into custody. End state: all six SPEC
§5.3 input types are accepted on-chain and surfaced as canonical inputs; the
on-chain half of payable deposit (custody increase + frame inputs) is done.

## SPEC refs
SPEC §5.3 (method list), §27.5 (CallL2/Deposit payload + input identity), §18.5
(payable `CallL2` deposit delivery), §12 (`UpgradeContract`), §10.1 (`plasma_
limit` is L2 budget, not L1 plasma).

## Depends on
Tickets 11 (domain), 13 (custody/deposit on-chain half), 14 (deploy records for
upgrade chaining).

## Key work
- `CallL2(domainId, target_contract, plasma_limit, payload)` — **payable**: MAY
  carry attached ZTS value. On receive, if value > 0 increase
  `totalDeposited[domainId][asset]` (unconditional/final) and mark the input as
  carrying `deposit_asset`/`deposit_amount` for the off-chain frame; enqueue as a
  canonical input (`input_kind=0`). `ValidateSendBlock` rejects a non-custodyable
  attached asset and `payload > MaxCallPayload`. `plasma_limit` is **not** placed
  in the contract-visible frame.
- `UpgradeContract(domainId, contract_id, new_code_hash)` — enqueue
  `input_kind=5`. Replacement bytecode is staged through the chunked mechanism
  (Ticket 14); `UpgradeContract` is the **finalizer** of the upgrade-destined
  record (§12): on-chain, verify a complete, non-expired pending record for
  `(domainId, new_code_hash)` exists with deployer == `caller`, then consume it
  via Ticket 14's consumption hook (mutually exclusive with
  `DeployContractFinalize`). Contract-level authorization
  (`OWNER_UPGRADEABLE`, owner via `caller`), validation/instrumentation, and
  `CodeHash` recomputation are the STF's (Ticket 04); `IMMUTABLE` upgrade
  attempts surface as `UNAUTHORIZED` in the off-chain receipt.
- Confirm the canonical input encodings for all six kinds (§27.5) are emitted
  consistently so the executor's `inputRoot` matches (shared codec, Ticket 03).
- Replay protection inherited from L1 account-block uniqueness + `chain_id`
  binding; no application nonce.

## Code references
- `vm/embedded/implementation/liquidity.go` (`LiquidityStakeMethod` — one send
  carrying value + ABI call) [EXISTS].
- `vm/constants/plasma.go` (`MaxDataLength`, 16 KiB input ceiling) [EXISTS];
  Ticket 09 `MaxCallPayload` [NEW].

## Acceptance criteria
- `CallL2` with and without attached value accepted; value path increases
  `totalDeposited` and tags the input frame; oversize payload / non-custodyable
  asset rejected.
- `UpgradeContract` enqueues `input_kind=5` with correct canonical encoding;
  it consumes a complete pending record (deployer == caller) and is rejected
  when the record is missing, incomplete, expired, wrong-deployer, or already
  consumed by `DeployContractFinalize`.
- Both methods run the Ticket 13 input-admission helper (index assigned;
  payable `CallL2` deposits land in the cumulative totals).
- All six input kinds round-trip into the canonical input encoding that the
  executor consumes (cross-checked against Ticket 03 CV-INPUTROOT-1).

## Phase 1B exit gate
With Tickets 08–17 the Settlement contract implements every §5.3 method,
custody/conservation, deployment, batch acceptance, relay/withdrawal, and admin/
pause — ready to **ship dark on testnet** (SPEC §29-1B) ahead of wiring.
