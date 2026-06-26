# WASM Spec Artifacts — Reviewer Handoff

**Location:** `phase-1/WASM Spec/` (these artifacts). **Normative spec:** `../SPEC.md`.

**Bottom line:** every artifact's technical content is accurate and current **except `execution-conformance-v1`**, which must be regenerated because of two `../SPEC.md` changes — the input-frame deposit fields and the new `claimed_deposit` field. This doc gives (1) exactly what to regenerate, and (2) the spec changes that drove it.

---

## 1. Which artifacts need work

| Artifact | Status |
|---|---|
| `execution-conformance-v1.json` + `-README.md` | ⏳ **Regenerate** (§2) |
| `wasm-gas-table-v1.md` / `.json` | ✅ Accurate — costs/model match `../SPEC.md` §10 |
| `smt-v1-test-vectors.json` | ✅ Accurate — also validated in-tree by the `common/trie` conformance test |
| `proof-format.md` | ✅ Accurate — byte layout matches `common/trie/proof.go` and `../SPEC.md` §13.4 |
| `smt-implementation-checklist.md` | ✅ Accurate — consistent with `../SPEC.md` §13 |
| `SMT-SPEC-BLOCKERS.md` | ✅ Historical — the SMT profile (B-1/B-2/B-3) is now pinned in `../SPEC.md` §13.4 and implemented in `common/trie` |

---

## 2. Regenerate `execution-conformance-v1`

Two `../SPEC.md` changes invalidate the current vectors (confirmed by decoding `EXEC-001`'s `input_frame_hex`).

**Change A — input frame gained two fields (`../SPEC.md` §27.1):**

```
    input_index     : u64
    deposit_asset   : AssetID      // NEW — zero32 when no value attached
    deposit_amount  : u256         // NEW — 0 when none
    payload         : Bytes
```

Every `input_frame_hex` and `context` is stale (the old layout goes straight from `input_index` to `payload`). The `CallL2` `inputHash` preimage also changed (`../SPEC.md` §27.5 folds `deposit_asset || deposit_amount` in), so affected `receipt_hex` values change.

**Change B — `ContractEffects`/`ExecutionResult` gained a trailing field (`../SPEC.md` §14.2):**

```
    … , ReturnData, claimed_deposit : u256
```

`claimed_deposit` is how much of `deposit_amount` the contract accepts; the runtime auto-refunds the unclaimed remainder via an `L1_WITHDRAWAL` outbox (`../SPEC.md` §18.5). So `contract_effects_blob_hex`, `execution_result_blob_hex`, and the `outboxRoot`/`receipt_hex` of any deposit-bearing vector all change.

**Regeneration checklist:**

| Step | Detail |
|---|---|
| Add frame fields | `deposit_asset = zero32`, `deposit_amount = 0` in every existing (non-deposit) vector; recompute `input_frame_hex` and any `CallL2` `receipt_hex`. |
| Add `claimed_deposit` | Append `claimed_deposit` (u256) to `contract_effects_blob_hex` and `execution_result_blob_hex` in every vector (`0` where no deposit). |
| New `EXEC-013` | Payable `CallL2`, `deposit_amount > 0`, contract returns `claimed_deposit == deposit_amount`, credits its own state; no refund outbox. |
| New `EXEC-014` | Pure `Deposit` (no application payload), `claimed_deposit == deposit_amount`. |
| New `EXEC-015` | Under-claim or failed deposit: `claimed_deposit < deposit_amount` (or `REVERT`) ⇒ runtime emits one `L1_WITHDRAWAL` refund for the remainder (`source_contract = bytes32(0)`); assert it lands in `outboxRoot`. |
| Update README | Document `claimed_deposit`, the deposit frame fields, and the auto-refund outbox. |

> Requires running the executor against real modules. Nothing is live, so regenerating in place (keep the `-v1` name) is fine; no migration concern.

---

## 3. Spec changes behind the regeneration

Context for what's normative now (folded into `../SPEC.md`):

- **Deposit / balance model (Model A, contract-managed).** `../SPEC.md` §18.1a/§18.2/§18.5: no protocol balance ledger, no balance host call; deposits are delivered to a target contract that credits its own state. The contract returns `claimed_deposit` for the amount it accepts, and the runtime auto-refunds the unclaimed remainder via an `L1_WITHDRAWAL` outbox — so a failed, no-deposit-logic, or partial contract cannot strand funds. `Deposit` is the no-payload funding form; payable `CallL2` is the with-payload form.
- **Two gas details now in the spec.** `../SPEC.md` §10.2 charges initial declared memory; §7.2/§11.3 reject sign-extension and `trunc_sat`. (Both originated in `wasm-gas-table-v1`; the spec and table now agree.)

---

## 4. Summary

The only remaining artifact task is **regenerating `execution-conformance-v1`** (§2), which needs the executor. The spec changes that drive it are in §3. Nothing else needs touching — the SMT vectors, gas-table costs, and proof-format byte layouts are unchanged.
