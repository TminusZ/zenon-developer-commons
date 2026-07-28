# Ticket 14 — Chunked deployment state machine (on-chain bookkeeping)

**Epic:** 1 — L1 Settlement · **Phase:** 1B · **Order:** 14

## Goal
Implement the on-chain half of WASM deployment: the chunked, hash-committed
`DeployContractStart/Chunk/Finalize` state machine keyed by `(domainId,
code_hash)`, with per-chunk hash verification and expiry. End state: a deployer
can commit a large module across chunks and finalize it deterministically.
**Settlement verifies chunk hashes at receive and record bookkeeping only — it
never assembles, validates, or instruments code** (assembly verification and
the §11.3 pipeline are the executor's STF, Ticket 04); Settlement MUST NOT
execute WASM.

## SPEC refs
SPEC §11 (deployment), §11.5 (expiry), §12 (identity/upgrade — `code_hash` vs
`CodeHash` split), §5.3 (deploy trio), §1 (no WASM on L1).

## Depends on
Tickets 11 (domain), 09 (deploy-record storage), 13 (input-admission helper).

## Key work
- `DeployContractStart(domainId, code_hash, metadata_hash, total_size,
  chunk_count)`: `total_size ≤ MaxCodeSize (256 KiB)`,
  `chunk_count = ceil(total_size / MaxDeployChunkData) ≤ MaxChunkCount (18)`;
  create pending record (metadata_hash, sizes, deployer `caller`, start height,
  empty chunk set); reject a duplicate non-expired record.
- `DeployContractChunk(domainId, code_hash, chunk_index, chunk_hash,
  chunk_data)`: record must exist (non-final, non-expired), `caller` = deployer;
  `chunk_index ∈ [0, chunk_count)` not already present; sizing rules (all but
  last exactly `MaxDeployChunkData (15 KiB)` — sized so chunk + ABI envelope fits
  `MaxDataLength` —, last = remainder; `chunk_count==1` ⇒ single chunk size ==
  `total_size`); `chunk_hash == sha3(chunk_data)`. Store
  `(chunk_index → chunk_hash)`; only the hash is committed (bytes go to DA).
- `DeployContractFinalize(domainId, code_hash)`: on-chain checks only —
  record exists, `caller` = deployer, all chunks present; on acceptance the
  record is consumed (finalized). The **executor's STF** performs assembly,
  `sha3(assembled) == code_hash` + `len == total_size` verification (mismatch ⇒
  `VALIDATION_FAILED` receipt, no contract), the §11.3 validation +
  instrumentation, and `CodeHash`/`ContractID` derivation (this contract does
  none of it — §11.3 on-chain/off-chain split).
- Mutually exclusive consumers (§12): a completed pending record is consumed by
  **either** `DeployContractFinalize` (new contract) **or** `UpgradeContract`
  (re-codes an existing contract, Ticket 17) — whichever is accepted first; a
  consumed record is finalized for §11 purposes. Wire the record-consumption
  hook Ticket 17 calls.
- Expiry: a record unfinalized within `DeploymentExpiryWindow (2880)` heights is
  treated as nonexistent and frees `code_hash`; plasma not refunded. Applies to
  upgrade-destined records identically.

## Code references
- Ticket 09 deploy-record storage [NEW]; Ticket 03 canonical input encodings for
  the deploy kinds (§27.5) [NEW].
- `vm/constants/` deployment constants (Ticket 09) [NEW].

## Acceptance criteria
- Multi-chunk deploy with all chunks present finalizes (record consumed); a
  finalize with a missing chunk or wrong `caller` is rejected; a chunk whose
  `chunk_hash ≠ sha3(chunk_data)` is rejected at receive.
- CV-DEPLOY-1 single-chunk (`chunk_count==1`) sizing accepted.
- Duplicate-active record rejected; wrong-deployer chunk rejected; out-of-range /
  duplicate `chunk_index` rejected.
- A record left unfinalized past `DeploymentExpiryWindow` is freed and the
  `code_hash` is reusable.
