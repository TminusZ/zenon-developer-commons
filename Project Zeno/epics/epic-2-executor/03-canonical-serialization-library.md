# Ticket 03 — Canonical serialization library (wire formats §27)

**Epic:** 2 — Executor · **Phase:** 1A · **Order:** 03

## Goal
Implement the full custom canonical binary codec for every consensus-visible
structure, with exactly-one-valid-encoding semantics and strict decode
rejection. This is shared by the runtime, the batch builder, the DA bundle, and
(by identical bytes) the Settlement contract. End state: every serialization
conformance vector round-trips byte-for-byte.

## SPEC refs
SPEC §14 (ExecutionResult/ContractEffects), §15 (receipts), §16 (events),
§17.2/§27.4 (outbox), §18.1/§18.4 (AssetID, AssetFlowSummary), §19 (batch
commitment), §20 (DA bundle), §27.0–§27.9 (all primitives + grammars), §24
(version fields), §31 (vectors).

## Depends on
Ticket 01.

## Key work
- §27.0 primitives: fixed-width BE `u8/u16/u32/u64/u256`, `bytes32`, 20-byte
  `Address`, `Bytes` (`u32` len + raw), `List<T>` (`u32` count). Decoder rejects
  trailing bytes, inconsistent prefixes, out-of-order fields.
- Structures: `ExecutionInputFrame` (§27.1), `ContractEffects` and
  `ExecutionResult` (§27.1a, incl. the 9-field-with-roots rejection and
  mandatory `claimed_deposit`), `StateDiffEntry` local + derived forms with the
  `EMPTY` sentinel rules (§27.2), `Event` (§27.3), `OutboxMessage` incl.
  kind-branch + withdrawal-empty-payload rule (§27.4), canonical input encoding
  + `inputHash` for all six input kinds (§27.5), `AssetFlowSummary` (§27.6),
  `Receipt` (§27.7), batch commitment (§19), `BundleInputRecord`/`WitnessEntry`
  (§20).
- §27.3 Merkle construction (leaf `sha3(0x00‖el)`, node `sha3(0x01‖l‖r)`, odd
  node promoted, empty set = `bytes32(0)`) — distinct from the SMT.
- `AssetID` codec (§18.1): 32-byte canonical ZTS encoding (`[0:22]` zero,
  `[22:32]` ZTS); reject non-zero high bytes / non-canonical alignment.
- Version fields encoded first; unknown `protocol_version` rejected before any
  other field (§24).

## Code references
- `common/types/hash.go`, `tokenstandard.go` (ZTS) [EXISTS] — primitives to
  bridge into `AssetID`.
- `../WASM Spec/execution-conformance-v1.json`, `proof-format.md` [ARTIFACT].
- SPEC §27 grammars [spec-defined].

## Acceptance criteria
- **This ticket authors the serialization vectors** (SPEC §31): CV-COMMIT-1/2
  (empty `proofData` round-trip; reject non-empty / trailing), CV-INPUTROOT-1
  (mixed-kind batch root), CV-BUNDLE-1 (two-input bundle, one absent read,
  fixed `DAHash`), CV-ASSET-1/2, CV-OUTBOX-1 (non-empty withdrawal payload ⇒
  reject) — committed as a machine-readable artifact in `../WASM Spec/` and all
  passing.
- Fuzz: random byte mutation of any encoded struct is rejected (no silent
  repair), and every valid struct has exactly one encoding.
