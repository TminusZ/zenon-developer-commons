# Ticket 09 — Settlement storage layout + constants

**Epic:** 1 — L1 Settlement · **Phase:** 1B · **Order:** 09

## Goal
Define the contract's storage key layout and the new protocol constants/hard
bounds, with typed read/write helpers. End state: every Phase 1 storage entity
has a documented, collision-free key and a tested accessor; constants live in
`vm/constants/` and are enforceable as Core hard bounds.

## SPEC refs
SPEC §5.4 (storage responsibilities), §25.1 (fixed constants), §25.2 (pre-mainnet
params), §32 (storage key layout to finalize); SPEC §18.3, §19, §23.

## Depends on
Ticket 08.

## Key work
- Key layout (all domain-keyed where domain-scoped): `DomainRecord` by
  `domainId`; batch chain entries (roots, indices, `DAHash`, `DAMode`,
  `executorId`, `submittedAtHeight`, `AssetFlowSummary`, state) by
  `(domainId, batchId)`; per-domain input-sequence cursor; the global
  received-input counter + per-domain assigned-index records + per-(domain,
  asset) cumulative deposit totals (§4.6, §18.4); per-(domain, asset)
  `totalDeposited`/`pendingWithdrawalReserve`/`totalReleased`; the per-domain
  withdrawal release queue (registration order, §18.2); the Settlement
  `lastUpdate` entry for the `Update` rate limit (`definition.GetLastUpdate`
  pattern); pending deploy records by `(domainId, code_hash)`; `processedOutbox`
  set; executor registration + bond state (registered / ACTIVE) and per-address
  QSR bond-deposit balances (§22 sentinel flow, `GetQsrDeposit` pattern);
  Periphery config.
- Constants in `vm/constants/` (new `settlement.go`): `MaxBatchInputs=64`,
  `MaxOnChainCommitmentSize=15 KiB`, `MaxCallPayload`, `MaxReturnData`,
  `MaxExecutionResult`, `MaxCodeSize`, `MaxDeployChunkData=15 KiB`,
  `MaxChunkCount=18`, `DeploymentExpiryWindow`, `MaxAssetsPerBatch`,
  `MaxWithdrawalsPerUpdate`, `MaxStateValueSize`, etc. (full table §25.1).
  Reuse existing `MaxDataLength` (`vm/constants/plasma.go`) and
  `UpdateMinNumMomentums` (`vm/constants/embedded.go`).
- Hard-bound holders for pre-mainnet params (§25.2): challenge/withdrawal-delay
  min/max, `MaxBatchWithdrawal` floor/ceiling, `MinRuntimeUpgradeDelay ≥
  WithdrawalDelay`, `valueCaps` window floor ≥ `WithdrawalDelay`, and (reserved,
  `MINTED` only) `MaxBatchMint` floor/ceiling (§18.3, §25.2). Natural floor
  reference `MomentumsPerEpoch` (`vm/constants/embedded.go`).
- Encode the **generalized** `DomainRecord` (§6 schema, so the layout is
  schema-shaped from day one and later profile/bridge activation is a spork, not a
  storage migration): `domainClass`, `runtimeKind`, `stfSpecHash`, `inputSource`,
  `execProfile`, `foreignProfile`, `profileConfig`, `chainBinding` (nullable),
  `executors`, `minExecutors`, `proposerPolicy`, `valueCaps`, `finalityModel`,
  `status`. Phase 1 writes only the default values (Ticket 11 clamps them); the
  encoding **MUST** still reserve space for the full set.
- **Reserved storage entities (schema present, unused in Phase 1, §5.4):** the
  per-(domain, asset) `AssetRegistry` (`custodyMode` + `MINTED` counters), the
  per-`outboxId` `MessageState` (timeout/ack), and the Periphery verifier
  registries (fraud-referee / validity-key). Reserve their key prefixes now to
  avoid a later collision; no accessor logic beyond a stub is required in Phase 1.

## Code references
- `vm/constants/plasma.go` (`MaxDataLength`), `vm/constants/embedded.go`
  (`MomentumsPerEpoch`, `MinSoftDelay`, `MinAdministratorDelay`) [EXISTS].
- Existing contract storage patterns in `vm/embedded/definition/*.go` (ABI
  variable encoding) and `vm/embedded/implementation/*.go` [EXISTS].

## Acceptance criteria
- Unit tests: round-trip read/write for `DomainRecord`, batch entry, the three
  per-(domain, asset) counters, the received-input counter + assigned-index
  records + cumulative deposit totals, the release queue (FIFO order preserved),
  deploy record, `processedOutbox` membership.
- No key prefix collides across entities (table documented in the ticket's PR).
- Constants match §25.1 exactly; hard-bound clamps reject out-of-range values in
  a unit test.
