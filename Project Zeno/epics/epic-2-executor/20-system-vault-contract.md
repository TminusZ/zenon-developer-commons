# Ticket 20 — System vault contract (bare custody / park-and-withdraw)

**Epic:** 2 — Executor · **Phase:** 1C · **Order:** 20

## Goal
Implement the canonical first-party **system vault** WASM contract (SPEC §18.1a,
§32): bare custody with no application logic beyond credit/debit, giving users a
"park value in L2 and withdraw later, no dapp" path and giving Ticket 21 a real
contract for every E2E flow. End state: an audited, `IMMUTABLE` vault module
whose deposit/withdraw round-trip passes the deposit conformance vectors.

**Placement:** an ordinary L2 contract inside the WASM domain — deployed through
the normal §11 path, executed by the executor, balances in that domain's SMT.
It is **not** Settlement code and has **no protocol privileges**; "first-party"
means only that it is written, audited, and its `ContractID` published by the
team. Per-domain by construction: a future runtime/domain ships its own
equivalent for its runtime.

## SPEC refs
SPEC §18.1a (contract-managed balances; the vault as the canonical bare-custody
contract), §18.5 (payable deposit claim/refund), §17 (withdrawal outbox), §8
(three-import ABI), §12 (`IMMUTABLE` policy), §32 (implementation task list).

## Depends on
Ticket 04 (runtime to build/test against; the vault is an ordinary WASM module).
Consumed by Ticket 21 (E2E fixture).

## Key work
- Vault module (any language compiling to Core 1.0 WASM within the §7 profile):
  - **Payable deposit** (via `Deposit` or payable `CallL2`): credit `caller` by
    the full `deposit_amount` per (asset) in vault state; return
    `claimed_deposit = deposit_amount` (no refund remainder in the normal path).
  - **Withdraw(asset, amount, recipient_l1)**: debit `caller`'s vault balance
    (fail `REVERT` on insufficient balance) and emit one `L1_WITHDRAWAL` outbox
    message (§27.4).
  - **Balance read** for clients via `storage_len`/`storage_read` key layout
    documented in the module's metadata.
- Deploy policy `IMMUTABLE`; no owner. State layout: one derived key per
  `(account, asset)` balance; values `u256`.
- Unit tests against the Ticket 04 runtime: deposit credit, partial/failed
  deposit refund behaviour (a deliberately failing call path exercises the
  §18.5 auto-refund), withdraw + outbox emission, insufficient-balance revert,
  determinism across two builds.
- Publish the module + `code_hash`/`CodeHash` + metadata as the deployment
  fixture Ticket 21 uses on testnet/mainnet.

## Code references
- Ticket 04 WASM runtime plugin [NEW]; Ticket 03 outbox/state-diff encodings
  [NEW].
- `../SPEC.md` §18.1a informative note (vault semantics) [spec-defined].

## Acceptance criteria
- EXEC-DEP-1 (partial claim + refund) reproduced against a vault variant with a
  partial-claim test hook; EXEC-DEP-3 (undeployed target full refund) covered by
  the harness; the normal vault path claims in full with no refund outbox.
- Deposit → withdraw → `RelayMessage` registration → `Update` release
  round-trips value to L1 in the Ticket 21 integration environment.
- Module passes §11.3 validation/instrumentation unchanged (no prohibited
  features), and its instrumented size is within the §25 ceiling.
