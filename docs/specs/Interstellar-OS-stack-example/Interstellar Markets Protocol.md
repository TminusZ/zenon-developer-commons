# Zenon Interstellar Markets Protocol

**Version:** 2.0.0  
**Status:** Interstellar OS Module Specification — Mainnet Candidate  
**Network:** Zenon Network of Momentum  
**Document Class:** Protocol Design Specification — Spot Trading, Version 2  
**Supersedes:** v1.9.0 (standalone validator-verified protocol)  
**Architecture:** Interstellar OS Protocol Module

---

## 0. Residual Non-Protocol Dependencies

> **This section exists so that no reader mistakes economic assumptions for protocol guarantees.** It is placed before the Abstract intentionally.

The following properties of ZIM depend on conditions outside the protocol's validity rules. They are real and important properties of the system. They are not guaranteed by the protocol logic alone.

---

**Price optimality depends on solver competition, not protocol validity.**

The protocol enforces price consistency and minimum-price satisfaction. It does not enforce that participants receive the best achievable price within the feasible region. In competitive markets with multiple solvers, competitive pressure tends to push prices toward the interior of the feasible region. In thin markets with one active solver, this pressure is absent. The protocol provides no structural substitute for solver competition on price quality.

---

**Safe use in volatile markets depends on watcher and cancellation infrastructure.**

A participant who publishes an intent with `min_price = 1.00` and does not cancel it has authorized any fill at or above 1.00 until expiry, regardless of what the market does. If the market moves to 1.10, a fill at 1.00 is valid and irrevocable. Cancellation is the only mechanism to revoke this authorization. Participants in volatile markets who do not operate — or delegate to — watcher services that monitor prices and cancel intents in time accept the risk of fills at stale minimums. This is inherent to asynchronous pre-signed execution and cannot be removed by protocol design.

---

**Thin markets may produce no settlement due to `E_MIN = 2`.**

A round in which fewer than two valid, deduplicated bundles qualify for the eligible set produces no fills. The rule exists because single-bundle rounds produce trivially biased randomness. The cost is real: a functioning market with one active solver produces no fills until a second solver participates. During bootstrapping, long-tail assets and off-hours trading are most likely to encounter this condition. The bootstrapping program (Section 11.4) and launch gate LG-1 (Section 16.2) are the primary mitigations.

---

**State divergence is governance-mediated.**

If the Markets reducer produces divergent state, recovery requires governance coordination. The `RECOVERY_WINDOW = 48 hours` commitment bounds the window and triggers automatic finalization suspension if exceeded. The recovery action itself — identifying the divergence claim position, coordinating kernel upgrades, specifying the rollback target — requires human governance coordination. Automated fraud proofs (Section 15.9) would remove this dependency and remain future work.

---

**Block hash randomness is a bounded approximation, not cryptographic fairness.**

Bundle selection uses `SHA3(finalization_block_hash || auction_round)` as its random seed. A block producer with sufficient hash evaluation capacity can bias this seed. The bias bound `min(H/|E|, 1)` is quantified and `E_MIN = 2` prevents the degenerate single-bundle case, but the fairness story remains contingent on the empirical assumption `H ≤ 8`. VRF-based randomness (Section 15.8) is the definitive resolution and remains future work.

---

**These are known, accepted, and explicitly managed.** Launch gates (Section 16.2) convert the first three into measurable go/no-go deployment conditions. The last two are structural properties of the v2 architecture, acknowledged in the design record and targeted for improvement in future versions.

---

## Abstract

Zenon Interstellar Markets (ZIM) is a non-custodial spot trading protocol implemented as an Interstellar OS protocol module. Participants open bounded reservation lanes and publish pre-signed executable intents within those lanes, authorizing settlement within declared bounds. Competing solvers construct settlement proposal claims containing at most one instruction per account and submit them for deterministic verification by the Markets reducer. The reducer enforces all validity rules against authenticated module namespace state and derives the resulting protocol state.

ZIM is spot-only. Settlement validity depends only on lane reservation sufficiency, pre-signed intent bounds, price-improvement constraints, lane nonce monotonicity, and globally consistent pricing. No oracle data is required. The protocol has a single execution model: bounded pre-signed asynchronous settlement. Core safety properties are formally statable and have machine-checked proofs as a mandatory mainnet precondition; see Sections 10.7 and Appendix E.

The protocol provides:

- **Deterministic settlement validity:** given the same ordered claim record and validity rules, the Markets reducer produces identical state across all conformant Interstellar OS instances.
- **Non-custodial authorization via bounds:** no fill may exceed a participant's published, signed intent bounds; the reducer enforces this structurally.
- **Reservation lanes:** concurrent intent expressiveness with bounded capital exposure per lane.
- **Isolated per-account state transitions:** one instruction per account per bundle; bundle settlement is a set of independent transitions, not a graph.
- **Transparent solver competition with anti-cartelization and bias floor:** intent pool is public; eligible bundle set is deduplicated by solver and randomized within a surplus band; block producer influence is bounded and quantified; minimum eligible set floor prevents degenerate single-bundle bias.
- **Best-execution incentives aligned with participant welfare:** improvement fees tied to actual fill outcomes; bundle selection uses post-fee participant welfare as the selection criterion.
- **Formally verified safety properties:** six invariants with machine-checked proofs as a mainnet deployment precondition (Appendix E).
- **Honest tradeoff disclosure:** solver price discretion within the feasible region is a deliberate design choice; thin markets may produce no settlement due to `E_MIN`; cancellation timing is an operational responsibility of participants; state divergence recovery is governance-mediated; block hash randomness is a bounded approximation. See Section 0.

The protocol does not claim MEV elimination, perfect decentralization, supply-demand clearing, guaranteed liquidity, coordinated multi-leg strategy execution, or automated state divergence recovery.

---

## Pre-Specification: Structured Adversarial Analysis

This section is the permanent record of structural risks considered across the full design history. It records what the design accepts, mitigates, or defers.

### Security Adversary Findings

**Balance overdraft via concurrent fills.** *Resolution:* Reservation lane model — total active lane reservations for any asset cannot exceed account balance at lane opening time. IR-7 ensures at most one instruction per account per bundle, eliminating intra-bundle balance races entirely.

**Intent bound exploitation.** Solver fills at participant minimum when better prices exist. *Resolution:* PR-5 (EXECUTION_TOLERANCE) bounds the deviation between fill price and declared clearing price. PR-6 ties improvement fees to actual fill outcomes, not declared prices.

**Namespace state forgery.** *Resolution:* All state is authenticated module namespace state under the Interstellar OS kernel. State transitions occur only through reducer application of verified claims.

**Bundle replay.** *Resolution:* Per-lane nonce monotonicity prevents replay. `lane_id` scopes nonces globally.

**Intent spam.** *Resolution:* Fee floor creates economic cost per intent.

**Strict-mode deposit griefing.** *Caused removal of strict mode.* Not present in this protocol.

**Band stuffing.** *Resolution:* Per-solver deduplication before the surplus band (SEL-1). A solver cannot amplify its selection probability by submitting many bundles.

**Sequential nonce as liquidity constraint.** *Caused introduction of reservation lanes.* *Resolution:* Per-lane nonces under reservation-bounded exposure enable concurrent intent publication.

**Cross-lane intra-bundle state dependency.** *Caused IR-7.* *Resolution:* One account per bundle; all state transitions are isolated. Each instruction's pre-state is the account's current namespace state at reducer application time, with no intra-bundle chaining.

**Lane expiry boundary ambiguity.** *Resolution:* Strict inequality `lane.expiry_block > bundle.submitted_block` in LR-2. A lane expiring exactly at the submission block is treated as expired.

**Capital fragmentation from fixed reservations.** *Accepted as operational cost in v1.* Reservation lanes lock capital per lane for the lane's lifetime. Participants who need to reallocate capital must close and reopen lanes. This is an efficiency cost, not a safety problem. Lane close-and-reopen is the correct mechanism for reservation management. The more complex ResizeLane operation was considered and rejected on grounds that its temporal reservation semantics — `committed_reserved_qty` at `submitted_block`, post-submission decrease protection, consensus-critical block boundary interpretation — added implementation risk that outweighed the capital efficiency benefit for a v1 deployment. Close-and-reopen is clunkier but auditable, formally simple, and free of temporal edge cases. *Documented as a known v1 operational limitation; see Section 1.5.*

**Degenerate single-bundle round bias.** *Resolution:* Minimum eligible set floor `E_MIN = 2` as a reducer finalization precondition (Section 6.3). Rounds with fewer than `E_MIN` valid bundles conclude with no settlement. This prevents trivially biased single-bundle rounds at the cost of producing no fills when only one solver participates.

**Formal verification aspirational.** *Resolution:* Machine-checked proofs of the six safety invariants are a mandatory mainnet deployment precondition. See Section 14.8 and Appendix E.

**Deployment assumptions unverified.** *Resolution:* All five principal deployment assumptions are converted to named launch gates with measurable go/no-go criteria. See Section 16.2.

### Incentive Design Findings

**Best-execution public-goods problem.** *Resolution:* Surplus-sharing improvement fee tied to actual fill outcomes (PR-6).

**Clearing price inflation incentive.** *Resolution:* PR-6 tied to actual fill outcomes, not declared clearing price. Declaring a high price without delivering proportional improvement reduces improvement fee revenue.

**Pre-fee surplus misalignment.** *Resolution:* Net-of-fee surplus formula in SEL-2. Solver optimization objective and selection criterion are identical.

**Clearing price discretion within feasible region.** Solver price-setting discretion within the feasible region is non-trivial and bounded only by feasibility constraints and competitive pressure. *This is a deliberate consequence of the oracle-free design, not a deficiency.* See Section 7.3 for the complete treatment.

**Solver lane-selection discretion.** When a participant has multiple active lanes, the solver chooses which lane to include. Documented in Section 8.2 with guidance for participants who need to express lane preference.

**Protocol optimizes trades, not strategies.** Per-instruction welfare maximization does not guarantee coordinated multi-leg execution. Documented in Section 7.4.

**Strategy sharding from IR-7.** Participants using multiple accounts for throughput distribute order flow across account identities. Solvers lose cross-strategy visibility. This slightly reduces solver optimization efficiency in aggregate. Not a security risk. Documented as accepted market structure side effect in Section 7.5.

### Systems Engineer Findings

**Reducer verification cost.** O(E) for price potential consistency check (CPR-2). Linear in bundle size for all other rules. The elimination of solver-supplied state proofs removes the prior SMT verification cost (~28ms per bundle at MAX_BUNDLE_SIZE) from the reducer's critical path.

**Block hash randomness bias — bounded and floored.** Quantitative upper bound `min(H/|E|, 1)` on block producer selection bias. `E_MIN = 2` finalization precondition prevents degenerate single-bundle bias. H ≤ 8 is an empirical claim, not a protocol guarantee. See Section 6.3.

**Cancellation timing as first-class operational risk.** Participants in volatile markets must operate watcher services. Failure to cancel before adverse moves results in fills at `min_price`. See Section 8.3.

**State divergence recovery window bounded.** `RECOVERY_WINDOW = 48 hours` defined. Auto-suspension of bundle finalization if unresolved. See Section 13.4.

**Lane lifecycle as primary implementation risk.** The lane lifecycle state machine is the most complex state machine in the protocol. The close-and-reopen simplification (no ResizeLane in v1) materially reduces this surface relative to earlier versions. See Section 14.8.

### Market Microstructure Findings

**Clearing price determination is not supply-demand equilibrium.** See Section 7.3. Accepted as the cost of oracle-free design.

**One-account-per-bundle throughput ceiling.** IR-7 limits a given account to one settled instruction per round (~80 seconds). Mitigation: multiple accounts, shorter round windows (future work). Strategy sharding side effect documented in Section 7.5.

**Cancellation timing is safety-critical.** First-class operational risk. Sections 3.4, 8.2, and 8.3.

---

## 1. System Overview

### 1.1 What the Protocol Does

ZIM coordinates asset swaps between participants without requiring assets to be deposited into a shared custody arrangement. Participants open reservation lanes that lock bounded quantities of a sell asset for a defined period, then publish signed trade intents within those lanes specifying the conditions under which they authorize settlement. Solvers identify compatible intents across the public pool, compute globally consistent clearing prices, construct settlement proposal claims with isolated per-account fill instructions, and submit them to the Commit Channels claim stream for deterministic verification by the Markets reducer.

The core trust model: participants trust the Zenon Network to sequence claims faithfully and trust the Markets reducer to correctly implement the validity rules during deterministic replay. They do not trust solvers, oracles, or any other participant. Fills are constrained to published, signed intent bounds and reservation limits; the reducer enforces both structurally without any participant being online at execution time.

### 1.2 What the Protocol Does Not Do

ZIM does not support:

- Margin or leveraged trading
- Derivatives
- Oracle-dependent settlement
- Cross-chain settlement
- Continuous order books
- Per-fill participant confirmation (see Section 1.6)
- Coordinated multi-leg strategy settlement within a single bundle (see Section 7.4)
- Dynamic lane reservation adjustment without close-and-reopen (see Section 1.5)

These are future work or deliberate exclusions, documented in Section 15.

### 1.3 The Tradeoff in Pre-Signed Intent Authorization

Participants sign bounds — a maximum sell quantity, a minimum price per unit, a maximum fee rate, a minimum fill size, and an expiry — not specific fills. Any fill within those bounds is valid. Within the envelope, solver behavior determines execution quality.

**What this improves:** No synchronous coordination required. Any solver reading the public claim pool can construct and submit a complete valid settlement proposal claim immediately after the solver window opens. Participants need not be online.

**What this changes:** Participants pre-approve an envelope of acceptable fills. The surplus-sharing fee model (Section 11.2) and the execution constraint (PR-5) keep solver behavior aligned with participant interests within the envelope in competitive markets. They are less effective in thin markets.

**Implication for participants:** Set tight bounds. `min_price` close to current market. Short expiry for volatile assets. `min_fill_quantity` that prevents granular extraction. There is no per-fill confirmation mechanism in v1. Participants must operate watcher services for volatile positions; see Section 8.3.

### 1.4 One-Account-per-Bundle Rule — Rationale and Tradeoff

IR-7 requires that a finalized bundle may contain at most one `SettlementInstruction` per `account_id`. This eliminates cross-lane state dependency within bundles. Each account's state transition is isolated: each instruction's pre-state is the account's current namespace state at reducer application time, with no intra-bundle chaining. The state transition rules simplify to six. The audit surface is materially smaller than a chained execution model.

**What this costs:** A participant with multiple active lanes can have at most one fill settle per round per account. Per-account throughput is capped at one fill per ~80 seconds. Mitigation: multiple accounts, shorter auction windows (future work, Section 15.5).

**Side effect:** Participants using multiple accounts distribute order flow across account identities. Solvers lose cross-strategy visibility. See Section 7.5.

**What this preserves:** Concurrent lane publication is fully intact. Participants can expose many simultaneous opportunities across lanes; solvers see the full concurrent order flow. IR-7 constrains same-round settlement, not concurrent publication.

### 1.5 Lane Capital Fragmentation — Accepted v1 Limitation

The reservation lane model enables concurrent positioning but introduces capital fragmentation: reserved quantities are locked per lane for the lane's lifetime and cannot be dynamically reallocated between lanes. A participant who needs to shift capital from one lane to another must close the source lane and open a new destination lane.

**Why this is accepted for v1:** A more capable lane management mechanism (ResizeLane) was designed and specified in earlier drafts. It was removed from v1 on the following grounds: (a) its temporal reservation semantics — determining the reservation value current at a specific block, distinguishing pre-submission from post-submission changes, handling race conditions between claim stream indexing and reducer validation — represent the single densest concentration of consensus-critical implementation risk remaining in the protocol; (b) that implementation risk exceeds the capital efficiency benefit for a v1 deployment where absolute auditability is the priority; (c) the problem ResizeLane solves is an efficiency problem, not a safety problem — the protocol is fully correct without it. Close-and-reopen lane operations are the correct v1 mechanism for reservation management. Dynamic lane resizing is documented as future work in Section 15.6.

**Operational guidance:** Size `reserved_qty` conservatively at lane opening. When capital needs to be reallocated, close the source lane (releasing its reservation) and open a new lane with the desired reservation. Set expiry appropriately for the expected intent duration to minimize idle locked capital.

### 1.6 Why Strict Mode Was Removed

An earlier version included a strict-mode flag allowing per-fill confirmation. The adversarial review identified a deposit griefing attack with no clean fix without an on-chain verifiable delivery mechanism. Strict mode introduces a second execution model in tension with the pre-signed asynchronous foundation. A future confirmation path is documented in Section 15.7.

### 1.7 Architectural Position

ZIM is implemented as a protocol module within the Interstellar OS verification kernel. The protocol stack is:

```
┌──────────────────────────────────────────────────────────────┐
│                      ZENON NETWORK                           │
│     Consensus and data availability layer                    │
└─────────────────────────────┬────────────────────────────────┘
                              │
┌─────────────────────────────▼────────────────────────────────┐
│                     COMMIT CHANNELS                          │
│     Globally ordered, append-only claim log                  │
│     Lane claims, intent claims, cancellation claims,         │
│     settlement proposal claims, resolution claims            │
└─────────────────────────────┬────────────────────────────────┘
                              │ ordered claim stream
┌─────────────────────────────▼────────────────────────────────┐
│                     INTERSTELLAR OS                          │
│     Verification kernel                                      │
│     Deterministic claim replay and reduction                 │
│     ┌───────────────────────────────────────────────────┐    │
│     │              MARKETS MODULE                       │    │
│     │   MarketsReducer enforces all validity rules      │    │
│     │   Derives and commits markets namespace state     │    │
│     │   Authenticated state: lanes / intents /          │    │
│     │   bundles / fills / balances / rounds             │    │
│     └───────────────────────────────────────────────────┘    │
└─────────────────────────────┬────────────────────────────────┘
                              │ derived market state
┌─────────────────────────────▼────────────────────────────────┐
│               AGENT SOFTWARE / SOLVERS / APPLICATIONS        │
│     Read public intent and lane state from claim stream      │
│     Construct and submit coordination claims                 │
│     Monitor fills via Interstellar OS state queries          │
└──────────────────────────────────────────────────────────────┘
```

**The division of responsibility:**

The Zenon Network orders and finalizes claims. Commit Channels provides the globally ordered, append-only claim record. Interstellar OS is the verification kernel that replays claims deterministically and produces a committed state root. The Markets module, running within Interstellar OS, enforces all market validity rules during reduction and maintains authenticated market state. Agents and solvers operate above the kernel: they sign claims, monitor state, and submit proposals. They do not execute protocol logic.

**What replaces "validator execution":** In the prior architecture, validators executed validity rules synchronously. In this architecture, the Markets reducer enforces the same rules deterministically during claim replay. Any conformant Interstellar OS instance replaying the same ordered claim history produces identical market state. This is the deterministic replay property: settlement state is fully determined by the ordered claim record and the reducer rules, with no external input.

### 1.8 Relationship to Prior Work

**CoW Protocol / 1inch Fusion:** Intent-based settlement with competitive solvers. ZIM differs in that settlement truth derives from deterministic replay of an ordered coordination claim record, not EVM execution. CoW and Fusion do not have a price potential consistency constraint, a surplus-sharing solver fee model tied to actual fill outcomes, minimum eligible set floors, or formally statable safety invariants with machine-checked proofs.

---

## 1A. Markets Module Interface

This section defines how the Markets protocol integrates with the Interstellar OS kernel.

```
Module ID:         interstellar.markets.v1
Execution context: Interstellar OS
Channel:           markets
Reducer:           MarketsReducer
Namespace prefix:  markets/
```

**Namespace layout:**

```
markets/
  accounts/{account_id}          — account metadata and sequence
  lanes/{lane_id}                — LaneState per lane
  intents/{intent_id}            — TradeIntent per intent (after claim acceptance)
  bundles/{bundle_id}            — SettlementBundle per round proposal
  fills/{instruction_id}         — SettlementInstruction per finalized fill
  balances/{account_id}/{asset}  — current balance per account per asset
  rounds/{round_id}              — auction round state and outcome
```

All state entries are derived and mutated exclusively through reducer application of verified claims. No state transition occurs outside MarketsReducer.apply(claim).

**Claim vocabulary:**

| Claim type | payload_kind | Market operation |
|---|---|---|
| `markets_assertion` | `open_lane` | Open a reservation lane |
| `markets_state_update` | `close_lane` | Close a reservation lane |
| `markets_assertion` | `trade_intent` | Publish a trade intent |
| `markets_rejection` | `cancel_intent` | Cancel a trade intent |
| `markets_proposal` | `settlement_bundle` | Solver submits a settlement bundle |
| `markets_resolution` | `bundle_finalize` | Winning bundle is resolved and fills applied |
| `markets_notice` | `no_settlement` | Round concludes with no settlement (E_MIN not met) |
| `markets_challenge` | `bundle_dispute` | Dispute of a claimed settlement |

**Reducer interface:**

```
MarketsReducer.apply(claim) →
    1. Validate claim structure and signature
    2. Check protocol invariants against current namespace state
    3. Derive state transitions
    4. Write updated state to markets/ namespace
    5. Emit derived lifecycle events
```

The reducer is deterministic: given identical ordered claim history and identical initial state, it produces identical namespace state. This is the fundamental requirement for inclusion in Interstellar OS.

---

## 2. Glossary

| Term | Definition |
|------|------------|
| Claim | A signed coordination event submitted to the markets channel |
| Intent | A participant's signed authorization claim to fill within specified bounds |
| Lane | A reservation unit that locks a bounded quantity of a sell asset for a defined period; opened via claim |
| Solver | A permissionless off-chain agent who constructs settlement proposal claims |
| Bundle | A proposed set of settlements submitted as a `settlement_bundle` claim payload; verified and settled by the reducer |
| Namespace state | The authenticated module state maintained by the Interstellar OS kernel under the `markets/` prefix |
| Feasible region | Set of price potential vectors satisfying all intent `min_price` constraints |
| Free balance | Total balance minus sum of active unrealized lane reservations, as derived from namespace state |
| Surplus | Aggregate post-fee welfare improvement above participant minimums, computed by the reducer during bundle selection |
| MarketsReducer | The deterministic reducer that enforces ZIM validity rules during claim replay |

---

## 3. Design Principles

### 3.1 No Oracle Dependencies

Settlement validity depends on no external price feed, reference rate, or off-chain data source. Every validity rule in Section 9 is checkable from the ordered claim record and current namespace state alone. This is the primary constraint that shapes the protocol's price model and is the reason solver price discretion within the feasible region is accepted rather than eliminated.

### 3.2 Participant Sovereignty Within Bounds

Once a participant signs an intent claim, they authorize any fill within the declared bounds. The protocol provides no per-fill confirmation and no per-fill veto. Participants control their risk exposure entirely through bound selection, expiry management, and cancellation claims. The reducer enforces the bounds; participants bear responsibility for setting them correctly.

### 3.3 Permissionless Solver Competition

The solver role is open to any party with the infrastructure to read the public intent and lane claim stream, run optimization, and submit settlement proposal claims. No registration, stake, or permission is required.

### 3.4 Cancellation as a Safety Mechanism

Because intents are pre-signed bounds, a participant who wishes to prevent a fill at `min_price` when the market has moved adversely must submit a `cancel_intent` claim that is accepted before expiry. Cancellation is the correct and only mechanism. See Section 8.3.

### 3.5 Simplicity Over Features in v1

Where a feature introduces consensus-critical implementation complexity without being required for protocol correctness, v1 excludes the feature and accepts the operational cost. Dynamic lane resizing (Section 1.5) is the primary example. The design is not minimal in an academic sense — it is minimal in the sense that removing any remaining piece would break oracle-freedom, concurrent intent expressiveness, or settlement correctness.

### 3.6 Deterministic Reduction

All protocol state is derived by the MarketsReducer through deterministic application of the ordered claim record. There is no execution of arbitrary programs, no stateful synchronous coordination between participants, and no state that exists outside the authenticated namespace. Any party can independently verify market state by replaying the claim history through the reducer rules.

---

## 4. Protocol Objects and Claim Payloads

Protocol operations are submitted as coordination claims to the markets channel. The MarketsReducer processes each claim and updates namespace state. Object fields are unchanged from v1.9.0; they are now expressed as claim payloads.

### 4.1 AssetIdentifier

```
AssetIdentifier = SHA3-256(chain_id || native_asset_id_or_contract)
```

### 4.2 IntentLane — `markets_assertion(open_lane)`

Submitted as a `markets_assertion` claim with `payload_kind = open_lane`.

```
OpenLaneClaim {
    lane_id:          bytes32           // SHA3-256(canonical(fields 1–5))
    account_id:       bytes32
    lane_sequence:    uint64            // account.last_lane_sequence + 1
    reserved_asset:   AssetIdentifier
    reserved_qty:     uint128           // Balance locked for this lane
    expiry_block:     uint64
    signature:        Signature
}
```

**Constraints enforced by MarketsReducer on open_lane claims:**

- `reserved_qty > 0`
- `expiry_block > current_block`
- `lane_sequence = markets/accounts/{account_id}.last_lane_sequence + 1`
- `markets/balances/{account_id}/{reserved_asset}` free balance ≥ `reserved_qty` at claim acceptance

**Reducer state update:** Writes `markets/lanes/{lane_id}` with initial `LaneState`. Increments `markets/accounts/{account_id}.last_lane_sequence`.

**Lane reservation is fixed at opening.** To change reservation, close the lane and open a new one.

### 4.3 CloseLane — `markets_state_update(close_lane)`

Submitted as a `markets_state_update` claim with `payload_kind = close_lane`.

```
CloseLaneClaim {
    close_id:         bytes32           // SHA3-256(canonical(fields 1–4))
    account_id:       bytes32
    lane_sequence:    uint64            // account.last_lane_sequence + 1
    lane_id:          bytes32
    signature:        Signature
}
```

**Reducer state update:** Sets `markets/lanes/{lane_id}.is_closed = true`. Advances `markets/accounts/{account_id}.last_lane_sequence`. Closed lanes are immediately ineligible for new fills.

### 4.4 TradeIntent — `markets_assertion(trade_intent)`

Submitted as a `markets_assertion` claim with `payload_kind = trade_intent`.

```
TradeIntentClaim {
    intent_id:          bytes32           // SHA3-256(canonical(fields 1–11))
    account_id:         bytes32
    lane_id:            bytes32
    lane_nonce:         uint64            // lane.last_lane_nonce + 1
    sell_asset:         AssetIdentifier   // Must equal lane.reserved_asset
    max_sell_quantity:  uint128
    buy_asset:          AssetIdentifier
    min_price:          FixedPoint128     // Minimum buy_quantity per unit sell_quantity
    max_fee_rate:       FixedPoint128
    expiry_block:       uint64            // Must be ≤ lane.expiry_block
    min_fill_quantity:  uint128
    flags:              uint8             // Bit 0: partial_fill. No other bits defined in v1.
    signature:          Signature
}
```

**Authorization semantics:** The participant's signature over `intent_id` authorizes any fill satisfying all intent parameters and the lane's reservation constraint. This is the sole authorization required.

**Constraints enforced by MarketsReducer on trade_intent claims:** `max_sell_quantity > 0`; `min_price > 0`; `sell_asset ≠ buy_asset`; `sell_asset = lane.reserved_asset`; `expiry_block > current_block`; `expiry_block ≤ lane.expiry_block`; `max_fee_rate ≥ MIN_FEE_RATE`; `lane_nonce = lane.last_lane_nonce + 1`; referenced lane is active and unexpired; `flags & 0xFE = 0`.

**Reducer state update:** Writes `markets/intents/{intent_id}`. Updates `markets/lanes/{lane_id}.last_lane_nonce`.

### 4.5 CancelIntent — `markets_rejection(cancel_intent)`

Submitted as a `markets_rejection` claim with `payload_kind = cancel_intent`.

```
CancelIntentClaim {
    cancel_id:          bytes32           // SHA3-256(canonical(fields 1–4))
    account_id:         bytes32
    lane_sequence:      uint64
    target_intent_id:   bytes32
    signature:          Signature
}
```

**Reducer state update:** Marks `markets/intents/{target_intent_id}.is_cancelled = true`. Releases unfilled reserved quantity back to lane available reservation.

### 4.6 SettlementInstruction

A `SettlementInstruction` is an individual fill record within a `SettlementBundle`. It is not a standalone claim; it is part of the `settlement_bundle` claim payload.

```
SettlementInstruction {
    instruction_id:     bytes32           // SHA3-256(canonical(fields 1–9))
    account_id:         bytes32
    lane_id:            bytes32
    lane_nonce:         uint64
    intent_id:          bytes32
    bundle_id:          bytes32
    sell_asset:         AssetIdentifier
    sell_quantity:      uint128
    buy_asset:          AssetIdentifier
    buy_quantity:       uint128
    clearing_price:     FixedPoint128
    base_fee:           uint128
    improvement_fee:    uint128
}
```

**Architectural note:** The fields `pre_state_root`, `post_state_root`, and `state_proof` from v1.9.0 are removed. In the Interstellar OS architecture, the MarketsReducer reads current state directly from the authenticated `markets/` namespace and computes the resulting state transitions itself. Solvers do not provide state proofs; the reducer verifies all balance and reservation constraints against namespace state at reduction time.

The solver's `bundle_signature` commits to every instruction.

### 4.7 SettlementBundle — `markets_proposal(settlement_bundle)`

Submitted as a `markets_proposal` claim with `payload_kind = settlement_bundle`.

```
SettlementBundleClaim {
    bundle_id:           bytes32
    auction_round:       uint64
    solver_id:           bytes32
    instructions:        []SettlementInstruction
    asset_potentials:    []AssetPotential
    solver_signature:    Signature
    submitted_block:     uint64
}

AssetPotential {
    asset:        AssetIdentifier
    phi:          FixedPoint128
}
```

A `settlement_bundle` claim is a candidate settlement proposal. The MarketsReducer determines whether it is valid and, if so, whether it wins selection among all proposals for the round. The reducer computes and applies the actual state transition upon bundle resolution; solvers do not supply state proofs.

### 4.8 Bundle Resolution — `markets_resolution(bundle_finalize)`

When the MarketsReducer selects a winning bundle at the close of a round, it produces a `markets_resolution` claim with `payload_kind = bundle_finalize`. This claim records the resolved outcome and triggers the reducer's state transition: balance updates, lane fill accumulation, and nonce advancement for each instruction in the winning bundle.

No-settlement rounds produce a `markets_notice` claim with `payload_kind = no_settlement` when `|E| < E_MIN`. This is a first-class protocol outcome, not an error.

---

## 5. Markets Namespace State

### 5.1 State Structure

All ZIM protocol state is maintained as authenticated module namespace state under the `markets/` prefix in Interstellar OS. State transitions occur only through MarketsReducer application of verified claims.

**Account state:**
```
markets/accounts/{account_id} →
    AccountState {
        last_lane_sequence:   uint64
        last_finalized_seq:   uint64
    }
```

**Lane state:**
```
markets/lanes/{lane_id} →
    LaneState {
        reserved_asset:   AssetIdentifier
        reserved_qty:     uint128           // Fixed at lane opening; never modified
        filled_qty:       uint128           // Accumulated fill quantity
        last_lane_nonce:  uint64
        expiry_block:     uint64
        is_closed:        bool
    }
```

**Balance state:**
```
markets/balances/{account_id}/{asset_id} →
    uint128     // Current total balance for this account and asset
```

**Intent state:**
```
markets/intents/{intent_id} →
    IntentState {
        claim:          TradeIntentClaim    // The original intent claim payload
        filled_qty:     uint128             // Total fill quantity finalized
        is_cancelled:   bool
    }
```

**Round state:**
```
markets/rounds/{round_id} →
    RoundState {
        status:         RoundStatus         // open | collecting | solver_window | finalized | no_settlement
        proposals:      []bytes32           // bundle_id of each submitted proposal claim
        winning_bundle: bytes32 | null
        seed:           bytes32 | null      // SHA3(finalization_block_hash || auction_round)
    }
```

**Free balance derivation** (derived from namespace state; not stored directly):

```
free_balance(account_id, asset) =
    markets/balances/{account_id}/{asset}
    − Σ (lane.reserved_qty − lane.filled_qty)
      for all active, unclosed lanes where lane.reserved_asset = asset
```

`reserved_qty` in lane state is immutable after lane opening. LR-1 is always evaluated against the current value in `markets/lanes/{lane_id}.filled_qty` and `markets/lanes/{lane_id}.reserved_qty`. There are no temporal interpretation complications.

### 5.2 Lane State Lifecycle

**Lane opening claim accepted:** New `markets/lanes/{lane_id}` entry created with `reserved_qty` fixed, `filled_qty = 0`, `last_lane_nonce = 0`, `is_closed = false`.

**Per settlement (fill applied by reducer):** Updates `markets/lanes/{lane_id}.filled_qty` and `markets/lanes/{lane_id}.last_lane_nonce`. Updates `markets/balances/{account_id}/{sell_asset}` and `markets/balances/{account_id}/{buy_asset}`.

**Lane closure claim accepted:** Sets `markets/lanes/{lane_id}.is_closed = true`.

### 5.3 Account History Reconstruction

Any party can replay all accepted claims from genesis through the MarketsReducer to reconstruct the current state of any account, lane, or intent. Divergent state is a reducer implementation defect; see Section 13.4.

---

## 6. Auction Mechanism

### 6.1 Round Structure

```
[Block N]         Round opens — markets/rounds/{round_id}.status = open
[Block N+K-1]     Last eligible block for this round
[Block N+K]       Collection window closes — status = solver_window
[Block N+K+1]     Solver window opens — settlement_bundle claims eligible
[Block N+K+M]     Solver submission deadline
[Block N+K+M+1]   MarketsReducer performs selection and emits resolution claim
```

| Parameter | Default | ~Wall-clock at 5s blocks |
|-----------|---------|--------------------------|
| K (collection) | 10 blocks | 50 seconds |
| M (solver) | 6 blocks | 30 seconds |
| Total round | 16 blocks | 80 seconds |

### 6.2 Uniform Clearing Price

```
clearing_price(A→B) = exp(φ(B) − φ(A))
```

Guarantees: global cycle consistency; intra-round price discrimination prevented; sequential sandwiching within a pair prevented.

Does not guarantee: supply-demand equilibrium; unique price determination; price optimality. See Section 7.3.

### 6.3 Bundle Selection with Net-of-Fee Surplus, Deduplicated Surplus Band, Bounded Randomness, and Minimum Eligible Set Floor

This selection logic is executed by the MarketsReducer at round close.

**Step 1 — Identify all valid proposal claims** (passing all SR through LR checks, including IR-7, evaluated against current namespace state).

**Step 2 — Deduplicate by solver:** For each distinct `solver_id`, retain only the highest-surplus bundle.

**Step 3 — Compute net-of-fee surplus** for each surviving bundle:

```
surplus(B) = Σ_{i ∈ B} max(0, buy_quantity_i − sell_quantity_i × intent_i.min_price
                              − (base_fee_i + improvement_fee_i))
```

**Step 4 — Eligible set:**

```
S_max = max surplus across all deduplicated bundles
E = { B | surplus(B) ≥ S_max × (1 − SURPLUS_BAND) }
```

**Step 5 — Minimum eligible set floor:**

```
If |E| < E_MIN:
    round concludes with no settlement
    reducer emits markets_notice(no_settlement)
```

`E_MIN = 2`. This is a finalization precondition, not a fallback.

**The E_MIN tradeoff — explicit design choice:**

`E_MIN = 2` solves one problem and creates another. This is stated explicitly.

*What it solves:* When `|E| = 1`, the block hash bias bound `min(H/|E|, 1)` is vacuous. A single-bundle round is trivially biased — the block producer selects the winner with certainty. The floor ensures randomness is non-trivial in all settled rounds.

*What it costs:* A round with one valid solver bundle — where a matching fill could have occurred — produces no settlement. In thin markets during bootstrapping, this may be the common case. The protocol is choosing bias-prevention over imperfect-but-functional settlement. This is the correct safety choice; it is not a costless one.

*Why the tradeoff is accepted:* Biased randomness in bundle selection is a structural attack surface that compounds over time; a delayed fill is recoverable, a biased market structure is not. The bootstrapping program (Section 11.4) is designed to ensure `|E| ≥ 3` in expectation. Launch gate LG-1 (Section 16.2) requires testnet evidence before mainnet.

**Step 6 — Random selection:**

```
seed = SHA3-256(finalization_block_hash || auction_round)
winner = E[seed mod |E|]   (indices by ascending claim submission position)
```

**Step 7 — Resolution:** Reducer emits `markets_resolution(bundle_finalize)` for the winning bundle and applies state transitions.

**Block hash randomness — quantitative bias bound:**

For a round with `|E| ≥ E_MIN = 2`, a block producer who can evaluate at most H candidate block hashes can shift any specific bundle's win probability by at most `min(H / |E|, 1)` above baseline `1/|E|`.

For H ≤ 8 and |E| ≥ 4 (expected competitive case), no specific bundle's win probability can exceed 50%.

**Limitation:** H ≤ 8 is an empirical assumption about Zenon's block production model, not a protocol guarantee. Launch gate LG-2 requires empirical verification before mainnet. VRF-based randomness (Section 15.8) is the definitive long-term resolution.

---

## 7. Price and Solver Model

### 7.1 Price Potential Model

**Definition:**

```
clearing_price(A→B) = exp(φ(B) − φ(A))
```

**Consistency guarantee:** Prices derivable from a common potential vector satisfy ∏ cycle_prices = 1 for every cycle. No cycle enumeration needed. O(E) reducer verification.

**Solver obligation:** Declare `asset_potentials` in the bundle claim; verified by CPR-1 and CPR-2.

### 7.2 What the Potential Model Enforces and What It Does Not

The price potential model enforces: (1) prices are globally consistent across all asset pairs in a bundle; (2) every intent's `min_price` is satisfied. It does not enforce: (3) that the selected price is the unique correct clearing price; (4) that the selected price is optimal for participants. When the feasible region is wide, the solver retains discretion over where within that region to clear.

### 7.3 Solver Price Discretion — Complete Treatment

The price potential vector is not uniquely determined by the intent set. There is generally a convex feasible region of φ vectors. The solver selects within this region to maximize surplus.

*Worked example:*

```
Intent I₁:  A→B  min_price = 1.00
Intent I₂:  B→A  min_price = 0.95
```

Feasible clearing price interval: `[1.00, 1.0526]` — approximately 5.3%. At `p = 1.00`, all improvement accrues to the B→A participant. At `p = 1.0526`, all improvement accrues to the A→B participant.

*What ZIM does to constrain this:*

- **PR-5 (execution tolerance):** fills must be within 0.2% of the declared clearing price.
- **PR-6 (actual outcome fees):** improvement fees are tied to actual `buy_quantity` vs `min_price × sell_quantity`, preventing declared-price inflation.
- **Net-of-fee surplus selection:** solvers who extract higher fees at the same nominal clearing price score lower and win fewer rounds.
- **Competitive pressure:** in a multi-solver market, a solver who systematically favors one side produces lower expected surplus than one who finds more balanced prices.

*Why ZIM does not enforce a unique equilibrium price:*

Oracle-enforced pricing introduces an external data dependency inconsistent with the no-oracle design. TWAP-based floors introduce stateful feedback dynamics with new attack surfaces. Neither is compatible with settlement validity depending on no external data. **Solver price discretion within the feasible region is a deliberate architectural choice.**

*The honest characterization:* ZIM enforces price consistency and minimum satisfaction. It incentivizes but does not enforce price optimality. Participants who require tight price certainty should set `min_price` close to current market.

*Collapse scenario:* If `|E| = 1`, competitive pressure is absent. The `E_MIN = 2` floor withholds settlement rather than allowing unconstrained solver discretion. The bootstrapping program (Section 11.4) targets ≥ 3 active solvers to prevent this scenario.

### 7.4 Solver Optimization Problem

```
Maximize:   Σ_{i ∈ S} max(0, buy_quantity_i − sell_quantity_i × intent_i.min_price
                              − (base_fee_i + improvement_fee_i))

Subject to:
  [Price constraints]
      exp(φ(buy_asset_i) − φ(sell_asset_i)) ≥ i.min_price   for each i ∈ S

  [Execution tolerance]
      buy_quantity_i / sell_quantity_i ≥ exp(φ(buy_asset_i) − φ(sell_asset_i)) × (1 − EXECUTION_TOLERANCE)

  [Minimum fill size]
      sell_quantity_i ≥ i.min_fill_quantity   for each i ∈ S

  [Net flow balance — asset conservation]
      Σ_{i ∈ S: buy_asset_i = a} buy_quantity_i = Σ_{i ∈ S: sell_asset_i = a} sell_quantity_i
      for each asset a

  [Lane reservation bound]
      sell_quantity_i ≤ lane_i.reserved_qty − lane_i.filled_qty
      (from markets/lanes/{lane_id} namespace state)

  [Balance sufficiency — per account, against current namespace state]
      markets/balances/{account_id}/{sell_asset} ≥ sell_quantity + base_fee + improvement_fee

  [One account per bundle — IR-7]
      At most one instruction per account_id in S

  [Bundle size]
      |S| ≤ MAX_BUNDLE_SIZE
```

**Objective alignment:** The solver maximizes the same net-of-fee surplus used in SEL-2. Optimizing for selection directly optimizes for participant welfare.

**The protocol optimizes trades, not strategies:** The objective sums per-instruction welfare improvements independently. A participant who uses multiple lanes as legs of a coordinated cycle has no protocol guarantee that all legs fill in the same round. Participants with coordinated strategies should set tight `min_price` per leg, use short `expiry_block`, and plan operationally for partial execution across rounds.

**Computational complexity:** MIP with LP relaxation as the standard practical approach. IR-7 simplifies per-account balance checks to single namespace lookups. See Appendix D.

### 7.5 Strategy Sharding — IR-7 Market Structure Side Effect

IR-7 limits each account to one settled instruction per round. Participants requiring higher throughput must use multiple accounts, distributing their order flow across separate account identities. Solvers lose cross-strategy visibility: a fund running three strategies across three accounts appears as three unrelated participants.

This is not a security risk. It slightly reduces solver optimization efficiency in aggregate and reduces on-chain transparency for participants who shard strategies. It cannot be addressed without removing IR-7, which would reintroduce cross-lane intra-bundle state complexity. The tradeoff is accepted.

### 7.6 Solver Infrastructure Requirements

- Public intent and lane claim stream access (via Interstellar OS state queries)
- Current namespace state mirror for balance and reservation checks
- LP/MIP optimization solver
- Low-latency claim submission infrastructure

Proof generation tooling is no longer required. Solvers construct settlement proposal claims and submit them; the MarketsReducer computes all state transitions.

Estimated infrastructure cost: $8,000–$20,000/month (preliminary estimate; benchmarks required).

### 7.7 Decentralization Properties

Pre-signed intent model eliminates private coordination advantage. Deduplicated net-of-fee surplus-band selection eliminates winner-take-most dynamics and band stuffing. Block producer influence on selection is bounded and quantified (Section 6.3). `E_MIN = 2` floor prevents degenerate single-bundle bias. Residual centralization pressure is optimization quality and namespace state indexing speed — a performance competition, not an access competition.

---

## 8. Agent Software

### 8.1 Scope

Agent software runs above the Interstellar OS kernel. Its responsibilities are:

1. **Key custody:** Hold private key; produce claim signatures.
2. **Balance and lane tracking:** Read current account state from `markets/` namespace via Interstellar OS state queries.
3. **Lane lifecycle management:** Submit `open_lane` and `close_lane` claims. When reservation needs to change, close the current lane and open a new one.
4. **Intent management:** Produce and sign `trade_intent` and `cancel_intent` claims.
5. **Fill auditing:** Verify all finalized fills (from `markets/fills/` namespace) were within signed bounds and lane reservations.
6. **Watcher services:** Monitor for adverse price movement and submit `cancel_intent` claims with sufficient lead time. Required for volatile positions; see Section 8.3.

Agent software does not execute protocol logic. It signs claims and queries derived state. The MarketsReducer enforces all validity rules.

### 8.2 Selecting Intent Bounds and Lane Parameters

- **min_price:** set close to current observable prices. Wide `min_price` = wide solver price discretion and larger potential adverse-fill exposure.
- **expiry:** short for volatile assets. Intent expiry must be ≤ lane expiry.
- **min_fill_quantity:** larger values reduce granular fee extraction risk.
- **max_fee_rate:** higher values improve fill probability in thin rounds; also signals lane priority to solvers for lane selection when a participant has multiple active lanes.
- **lane sizing:** size `reserved_qty` to actual intended exposure at lane opening time. Because reservation is fixed, be conservative rather than over-allocating locked capital. When order flow shifts, close the lane and reopen with revised reservation.
- **lane preference signaling:** to favor one lane over another in solver selection, set a higher `max_fee_rate`, tighter `min_price`, or shorter `expiry_block` on the intent the participant wants filled soonest.
- **multi-leg strategy guidance:** set tight per-leg `min_price`; use short `expiry_block`; plan for partial execution across rounds; consider whether the asynchronous model fits the strategy.

### 8.3 Cancellation Timing — Operational Requirement

**This is a first-class operational requirement, not an advisory.**

Because intents are pre-signed bounds, a fill at `min_price` is valid even if market prices have moved adversely. The only way to prevent such a fill is to submit a `cancel_intent` claim that is accepted before the intent is included in a bundle.

**Watcher requirement:** Any participant with active intents on volatile assets must operate — or delegate to — a watcher service that:

1. Continuously monitors market prices against `min_price` bounds.
2. Computes the adverse-move threshold at which cancellation is warranted.
3. Submits `cancel_intent` claims with sufficient lead time to be accepted before block `N+K` (collection window close) for the round the participant wishes to exclude.

**Timing constraint:** A `cancel_intent` claim accepted during the solver window M may not be observed by solvers already constructing bundles. Target cancellation completion before the collection window closes, not during the solver window.

**Consequence of inaction:** A participant who does not cancel in time accepts fills at `min_price` when the market has moved adversely. There is no protocol recourse once a bundle is finalized.

**Delegated runtime:** Participants using delegated or custodial agent software (Section 8.4) must verify that the delegated operator runs watcher services. Failure to do so is a counterparty risk, not a protocol risk.

### 8.4 Key Security Requirements

Production deployments: HSMs or secure enclaves. Development: software-only key storage acceptable.

### 8.5 Sovereignty Spectrum

| Tier | Description | Trust Model |
|------|-------------|-------------|
| Full | Self-hosted agent software, local keys | None beyond Zenon Network |
| Proof-assisted | ZK namespace state proofs, local keys | ZK proof system soundness |
| Delegated | Third-party agent software with attestation | Attested software integrity, including watcher services |
| Custodial | Custodian holds keys and agent software | Custodian honesty re: bounds, lanes, and cancellation timing |

---

## 9. Settlement Validity Rules

Complete and exhaustive. A bundle is accepted by the MarketsReducer if and only if every rule passes for every instruction. All rules are deterministic and require no external data. All state checks are against current `markets/` namespace state at reduction time.

**MarketsReducer.apply(settlement_bundle_claim):**
1. Check structural rules (SR)
2. Check IR-7 before per-instruction processing
3. For each instruction: check intent rules (IR), authorization rules (AR), price rules (PR), price potential rules (CPR), lane rules (LR), and state transition validity (STV)
4. If all rules pass: apply state transitions per Section 9.8
5. Record bundle outcome in `markets/bundles/{bundle_id}`

### 9.1 Structural Rules

**SR-1 (Bundle integrity):** `bundle_id = SHA3-256(canonical(all bundle fields excluding bundle_id))`

**SR-2 (Solver signature):** `verify(solver_signature, bundle_id, solver_id) = true`

**SR-3 (Auction round):** `bundle.auction_round` references an open round; `bundle.submitted_block ≤ round_solver_deadline_block`

**SR-4 (Non-empty):** `|instructions| ≥ 1`

**SR-5 (Bundle size):** `|instructions| ≤ MAX_BUNDLE_SIZE`

### 9.2 Intent Rules

**IR-1 (Intent exists):** `intent_id` references a `trade_intent` claim accepted at block ≤ `bundle.submitted_block`, present in `markets/intents/`.

**IR-2 (Intent not cancelled):** `markets/intents/{intent_id}.is_cancelled = false`

**IR-3 (Intent unexpired):** `intent.expiry_block ≥ bundle.submitted_block` (non-strict).

**IR-4 (No duplicate intents):** Each `intent_id` appears in at most one instruction.

**IR-5 (Residual quantity sufficient):**
- Partial fill flag set: `intent.max_sell_quantity − markets/intents/{intent_id}.filled_qty ≥ instruction.sell_quantity`
- Partial fill flag unset: `intent.max_sell_quantity − markets/intents/{intent_id}.filled_qty = instruction.sell_quantity`

**IR-6 (Minimum fill satisfied):** `instruction.sell_quantity ≥ intent.min_fill_quantity`

**IR-7 (One account per bundle):** Each `account_id` appears in at most one `SettlementInstruction`. Bundles with duplicate `account_id` values are rejected before per-instruction rules are evaluated.

*Consequence:* Because IR-7 guarantees no two instructions in a bundle affect the same account, each instruction's state checks are independent. There is no intra-bundle account state ordering. The reducer applies each instruction's state transition against the pre-bundle namespace state for that account.

### 9.3 Authorization Rules

**AR-1 (Standard authorization):** The `trade_intent` claim signature constitutes settlement authorization. The reducer verifies price, quantity, and fee fields are within intent bounds (PR-1 through PR-5) and lane bounds (LR-1 through LR-3). No additional participant signature is required or recognized.

### 9.4 Price Rules

**PR-1 (Minimum price):** `instruction.buy_quantity / instruction.sell_quantity ≥ intent.min_price`

**PR-2 (Uniform clearing price):** All instructions with the same (sell_asset, buy_asset) pair carry the same `clearing_price`.

**PR-3 (Arithmetic consistency):** `|instruction.buy_quantity − (instruction.sell_quantity × clearing_price)| ≤ 1`

**PR-4 (Fee bounds):**

```
instruction.base_fee + instruction.improvement_fee ≤ instruction.sell_quantity × intent.max_fee_rate
instruction.base_fee + instruction.improvement_fee ≥ instruction.sell_quantity × MIN_FEE_RATE
```

**PR-5 (Execution constraint):** `instruction.buy_quantity / instruction.sell_quantity ≥ clearing_price × (1 − EXECUTION_TOLERANCE)`

**PR-6 (Improvement fee — actual fill basis):**

```
actual_improvement = max(0, buy_quantity − min_price × sell_quantity)
improvement_fee ≤ actual_improvement × IMPROVEMENT_SHARE_RATE
```

### 9.5 Price Potential Rules

**CPR-1 (Completeness):** One `AssetPotential` entry per distinct asset referenced in any instruction.

**CPR-2 (Consistency):** For every distinct pair (A, B) with declared clearing price p:

```
|ln(p) − (φ(B) − φ(A))| ≤ δ   where δ = 10⁻⁹
```

### 9.6 Lane Rules

**LR-1 (Reservation bound):**

```
markets/lanes/{lane_id}.filled_qty + sell_quantity ≤ markets/lanes/{lane_id}.reserved_qty
```

`reserved_qty` is immutable after lane opening. This check has no temporal interpretation complications.

**LR-2 (Lane validity — strict expiry):** `lane_id` references an active, unclosed lane in `markets/lanes/` with acceptance block ≤ `bundle.submitted_block`, and `lane.expiry_block > bundle.submitted_block` (strict inequality). A lane expiring at exactly the submission block is treated as expired.

**LR-3 (Lane asset match):** `instruction.sell_asset = markets/lanes/{lane_id}.reserved_asset`.

### 9.7 State Transition Validity

The following checks replace the prior SPR (State Proof Rules) category. Because the reducer reads current namespace state directly, no solver-supplied state proof is needed. These are ordinary reducer transition checks.

**STV-1 (Balance sufficiency):**

```
markets/balances/{account_id}/{sell_asset} ≥ sell_quantity + base_fee + improvement_fee
```

**STV-2 (Non-negative balances after transition):** All post-transition balance values ≥ 0.

**STV-3 (Correct balance delta):**

```
new balance/{sell_asset} = current balance/{sell_asset} − sell_quantity − base_fee − improvement_fee
new balance/{buy_asset}  = current balance/{buy_asset}  + buy_quantity
```

For new buy_asset balances: current balance = 0.

**STV-4 (Correct lane delta):**

```
new lanes/{lane_id}.filled_qty      = current filled_qty + sell_quantity
new lanes/{lane_id}.last_lane_nonce = current last_lane_nonce + 1
```

Lane `reserved_qty` and `expiry_block` are not modified by a fill.

### 9.8 Bundle Selection Rules

Evaluated by the MarketsReducer at round close after all per-bundle checks pass.

**SEL-1 (Per-solver deduplication):** For each distinct `solver_id`, retain only the highest-surplus bundle.

**SEL-2 (Net-of-fee eligible set):**

```
surplus(B) = Σ_{i ∈ B} max(0, buy_quantity_i − min_price_i × sell_quantity_i − total_fee_i)

S_max = max { surplus(B) : B ∈ D }
E = { B ∈ D : surplus(B) ≥ S_max × (1 − SURPLUS_BAND) }
```

**SEL-3 (Minimum eligible set floor):** If `|E| < E_MIN`, the round produces no settlement. `E_MIN = 2`.

**SEL-4 (Random selection):**

```
seed = SHA3-256(finalization_block_hash || auction_round)
winner = E[seed mod |E|]   (indices by ascending claim submission position)
```

**SEL-5 (Atomicity):** A bundle is finalized entirely or not at all.

---

## 10. Security Model

### 10.1 Scope

Claims cover the protocol layer. Network properties are inherited from the Zenon Network. The deterministic reduction guarantee of Interstellar OS is assumed: any conformant instance replaying the same claim history produces identical state.

### 10.2 Asset Safety

**Claim:** An adversary cannot transfer assets from a participant's account beyond the bounds of their published, signed `trade_intent` claim and the reservation limits of the referenced lane.

**Argument:** AR-1 requires all fill parameters within intent bounds (PR-1 through PR-5) and lane bounds (LR-1 through LR-3). Bounds derive from participant signatures. Ed25519 forgery is computationally infeasible. The reducer enforces bounds without any participant being online. IR-7 ensures each transition is independently verifiable against current namespace state.

**Qualification:** Does not cover losses from poor bound selection or inadequate watcher coverage. See Sections 1.3 and 8.3.

### 10.3 Minimum-Price Extraction

**Claim:** A solver cannot consistently fill at `min_price` when a better clearing price exists.

**Argument:** PR-5 requires fill price within EXECUTION_TOLERANCE of declared clearing price. PR-6 ties improvement fees to actual fill outcomes. A solver who declares a low clearing price produces lower net surplus and loses selection probability.

**Qualification:** Solver retains discretion within the feasible region. In thin markets (`|E| = 1`), the `E_MIN = 2` floor withholds settlement rather than allowing unconstrained solver discretion. Section 7.3.

### 10.4 Cycle Price Manipulation

**Claim:** No clearing prices in a valid bundle can imply extractable value by cycling assets.

**Argument:** CPR-2 enforces consistency with a single potential vector. Prices derivable from a common potential satisfy ∏ cycle_prices = 1. Bundles with cycle profit violate CPR-2 and are rejected by the reducer.

### 10.5 Solver Cartelization

Net-of-fee surplus-band randomized selection: winner-take-most eliminated. Per-solver deduplication: band stuffing closed. `E_MIN = 2` floor: rounds without competitive bundles produce no settlement, reducing the value of monopoly control. Residual: a dominant solver with bundles persistently exceeding SURPLUS_BAND above all competitors wins every round. Mitigated by permissionless entry and bootstrapping incentives targeting ≥ 3 active solvers.

### 10.6 MEV Analysis

**Eliminated:** Intra-round price discrimination; sequential sandwiching; cycle price extraction; clearing-price inflation; cross-lane intra-bundle state manipulation.

**Residual — Intent exclusion:** Solver may exclude specific intents; mitigated by surplus scoring.

**Residual — Lane selection within account:** Solver chooses which of a participant's active lanes to fill; bounded by normal surplus incentives.

**Residual — Block producer bundle selection bias:** Bounded by `min(H/|E|, 1)` and floored by `E_MIN = 2`. Long-term resolution: VRF (Section 15.8).

### 10.7 Protocol Safety Invariants

The following six invariants hold for any valid claim history processed by a conformant MarketsReducer and serve as mandatory formal verification targets (Appendix E):

**Invariant 1 (Non-negative balances):** For all reachable namespace states and all assets, `markets/balances/{account_id}/{asset} ≥ 0`.

**Invariant 2 (Reservation integrity):** For all reachable namespace states and all active lanes, `markets/lanes/{lane_id}.filled_qty ≤ markets/lanes/{lane_id}.reserved_qty`.

**Invariant 3 (Fill bound):** Total fill across all finalized settlement instructions for any intent ≤ `intent.max_sell_quantity`.

**Invariant 4 (Replay prevention):** No two finalized instructions carry the same `(lane_id, lane_nonce)`.

**Invariant 5 (Cycle price consistency):** For any finalized bundle, all clearing prices are consistent with a single potential vector.

**Invariant 6 (Fee bounds):** For any finalized instruction: total fee within `[sell_quantity × MIN_FEE_RATE, sell_quantity × max_fee_rate]`, and `improvement_fee ≤ actual_improvement × IMPROVEMENT_SHARE_RATE`.

---

## 11. Economics

### 11.1 Fee Structure

Each fill carries a `base_fee` and an `improvement_fee`, both denominated in `sell_asset`.

- `base_fee`: compensates for base execution cost. Bounded by `MIN_FEE_RATE` floor and `max_fee_rate` ceiling.
- `improvement_fee`: tied to actual price improvement delivered above `min_price`. Bounded by `IMPROVEMENT_SHARE_RATE × actual_improvement`.

### 11.2 Surplus Sharing and Best-Execution Incentive

The surplus formula (SEL-2) deducts fees from the welfare improvement metric. A solver who extracts more fees at the same nominal clearing price scores lower and wins fewer rounds. This directly links solver revenue to participant welfare.

### 11.3 Solver Viability

Infrastructure: ~$8,000–$20,000/month (preliminary estimate). Viable for multiple competing operators above ~$30M daily volume plus bootstrapping subsidy. Proof generation tooling no longer required; solver infrastructure is reduced to claim stream access, namespace state queries, optimization, and submission.

### 11.4 Bootstrapping Incentives

- 18-month time-limited subsidy from Zenon Network treasury
- Fixed ZNN payment per filled bundle, declining 25% per quarter
- Eligibility: ≥ `SOLVER_BOOTSTRAP_THRESHOLD` monthly fill volume in trailing 30 days
- Target: ≥ 3 active competitive solver operators (minimum required for `E_MIN = 2` to be non-binding in expectation)
- Automatic sunset at month 18 or when volume is self-sustaining

### 11.5 Participant Fee Incentives

Higher `max_fee_rate` improves fill probability in thin rounds. The post-fee surplus mechanism ensures high improvement fees directly reduce bundle surplus score — the fee-extraction incentive is self-limiting.

---

## 12. Governance

### 12.1 Governed Parameters

**Tier 1 (67% supermajority, 7-day time-lock):**
- `MIN_FEE_RATE`, `MAX_BUNDLE_SIZE`, `CONFIRM_DEPTH`, `EXECUTION_TOLERANCE`, `IMPROVEMENT_SHARE_RATE`, `E_MIN`, `RECOVERY_WINDOW`

**Tier 2 (51% majority, 1-day time-lock):**
- K, M (auction window lengths), `SURPLUS_BAND`, `SOLVER_BOOTSTRAP_THRESHOLD`

**Protocol constant (not adjustable):** `δ = 10⁻⁹`

Governance parameter changes are submitted as governance claims on the markets channel. The MarketsReducer applies parameter updates at the activation block declared in the governance resolution claim.

### 12.2 Change Process

1. Governance claim published with proposed value and rationale hash.
2. Review period: 14 days (Tier 1), 3 days (Tier 2).
3. ZNN-weighted on-chain vote.
4. Time-lock if passed: 7 days (Tier 1), 1 day (Tier 2).
5. Activation at specified block height via resolution claim.

### 12.3 Governance Risks

**IMPROVEMENT_SHARE_RATE:** Reducing to 0 collapses best-execution incentives. Setting high gives solvers excessive surplus capture.

**SURPLUS_BAND:** Setting to 0 reverts to deterministic winner-take-most. Per-solver deduplication provides a structural floor.

**EXECUTION_TOLERANCE:** Setting to 0 conflicts with integer rounding. Setting high allows minimum-price extraction.

**E_MIN:** Setting to 1 re-enables degenerate single-bundle selection bias. Setting above 3 risks frequent no-settlement rounds during bootstrapping. `E_MIN = 2` is the recommended value.

**RECOVERY_WINDOW:** Too short forces governance into impractical response times. Too long weakens the operational commitment against prolonged state divergence.

**Emergency path:** 90% supermajority activates immediately; auto-reverts after 72 hours unless confirmed through standard process.

---

## 13. Failure Modes

### 13.1 Network Partition

Intent claims expire at `expiry_block`; lane reservations remain locked until expiry or explicit closure claim. No assets at risk. Watcher services should monitor for impending fills during extended disconnections.

### 13.2 Solver Failure

No fills occur. Intent claims accumulate. No assets at risk. Recovery is permissionless. Rounds with only one eligible bundle produce no fills regardless; this is a distinct failure mode in thin solver markets, mitigated by bootstrapping incentives.

### 13.3 Agent Software Unavailability

Fills proceed from pre-signed bounds within lane reservations. Set short expiries on volatile positions. Watcher services should be operated independently of the primary agent software where possible.

### 13.4 State Divergence

**Canonical replay procedure:**

1. Detecting party identifies the first claim position at which a conformant MarketsReducer instance produces divergent state from the published canonical state.
2. Detecting party publishes a dispute claim to the markets channel citing the first divergent claim position, affected account(s), computed state, and published state.
3. Any party replays the full claim history through the MarketsReducer from genesis. Replay is fully deterministic. If replay confirms the dispute claim, the divergence is confirmed.
4. Root cause: a reducer implementation defect that caused an incorrect state transition on a specific claim.
5. The MarketsReducer module is upgraded. The last pre-divergence confirmed-valid claim position is the recovery target. The Interstellar OS rollback procedure is followed.

**Recovery window commitment:** The maximum acceptable interval between divergence detection and governance coordination is `RECOVERY_WINDOW = 48 hours`. If a confirmed divergence is unresolved after `RECOVERY_WINDOW`, new bundle finalization is automatically suspended until governance acts.

**Known v1 gap:** No automated fraud proofs, no slashing, no automated rollback. The mitigation is multiple independent MarketsReducer implementations, public replay tooling, and continuous watcher monitoring. Automated dispute resolution is deferred to Section 15.9.

### 13.5 Solver Cartelization

Observable: solver win rates, surplus quality, intent exclusion patterns, lane selection bias. Primary mitigation: deduplicated net-of-fee surplus-band randomization and permissionless entry. Governance monitoring with threshold triggers required before mainnet.

### 13.6 Thin Solver Markets and E_MIN

A round in which fewer than `E_MIN = 2` valid, deduplicated settlement proposal claims are submitted produces no settlement. This is a deliberate protocol outcome. See Section 6.3 for the full tradeoff discussion.

During bootstrapping, long-tail asset pairs and off-hours rounds are most likely to encounter this condition. Launch gate LG-1 (Section 16.2) requires testnet evidence that E_MIN does not cause unacceptable settlement gaps on target pairs before mainnet.

---

## 14. Implementation Notes

### 14.1 Claim Stream Requirements

The Commit Channels ordering layer provides: append-only, globally ordered claim log; deterministic claim finality; Ed25519 verification at consensus layer; data availability for all markets channel claims; stable block times. The MarketsReducer requires ordered, append-only delivery of all claims on the markets channel with no gaps.

### 14.2 Namespace State Storage

The MarketsReducer maintains all state in the `markets/` namespace under Interstellar OS. The Jellyfish Merkle Tree construction used in Interstellar OS is the canonical state storage mechanism. Leaf key derivation follows the Interstellar OS SMT specification.

**Implementation note:** `markets/lanes/{lane_id}.reserved_qty` is written once at lane opening and never updated thereafter. Any reducer implementation that modifies `reserved_qty` after lane creation has a critical bug. This simplification also removes the entire class of temporal reservation lookup bugs.

### 14.3 Price Potential Computation

MIP with LP relaxation. Open-source solvers (HiGHS, SCIP, GLPK). O(E) reducer CPR-2 verification. See Appendix D.

### 14.4 IR-7 Implementation

Build a set of `account_id` values from all instructions in the bundle; if any appears more than once, reject at IR-7 before processing per-instruction rules. O(|instructions|). Must run before STV checks.

### 14.5 LR-2 Strict Expiry Implementation

`lane.expiry_block > bundle.submitted_block`. Strict inequality. Implement this exactly; `≥` is a consensus-diverging bug. Test explicitly with `lane.expiry_block = bundle.submitted_block` as a rejection conformance case (Appendix F, F.2.1).

### 14.6 E_MIN Finalization Check Implementation

Before running SEL-4 (random selection), verify `|E| ≥ E_MIN`. If `|E| < E_MIN`, emit a `markets_notice(no_settlement)` claim. No instructions are finalized. The round is closed. Implement the no-settlement path as a first-class protocol outcome, not an error condition.

### 14.7 Reducer Verification Performance

At MAX_BUNDLE_SIZE = 256 (estimated, not guaranteed):

| Rule set | Estimated time |
|---|---|
| SR checks + IR-7 deduplication | ~1ms |
| IR + LR checks (against namespace state) | ~2ms |
| AR checks | ~1ms |
| PR checks including CPR-2 | ~5ms |
| STV checks (namespace reads + arithmetic) | ~3ms |
| SEL computation including E_MIN check | ~2ms |
| **Total estimated** | **~14ms** |

Elimination of solver-supplied SMT proof verification reduces the prior ~28ms SPR cost to ~3ms for namespace-read-based STV checks. Adversarial benchmarks required before performance claims.

### 14.8 Audit and Formal Verification Requirements — Mandatory Mainnet Preconditions

**Formal verification — mandatory.** Machine-checked proofs of all six safety invariants (Section 10.7) must be completed before mainnet deployment. This is a precondition, not a recommendation. No mainnet launch date shall be set until all six proofs are complete and independently reviewed. See Appendix E for assignments, tools, and acceptance criteria.

**Audit — mandatory.** The following must be audited before mainnet:

*Priority 1 — Lane lifecycle state machine (highest priority):*

The lane lifecycle is the primary implementation risk surface. The audit must cover the complete interaction matrix:

| Operation | What to verify |
|-----------|----------------|
| Lane open with exact free balance | Does the free balance constraint hold at boundary? |
| Lane open with insufficient balance | Must be rejected at claim acceptance |
| Fill to exact reserved_qty | LR-1 boundary: `filled_qty + sell_quantity = reserved_qty` — PASS |
| Fill exceeding reserved_qty | LR-1: must be rejected |
| CloseLane with active intents | Does closure prevent future fills correctly? |
| Expiry at exactly submitted_block | LR-2 strict inequality: must be rejected |
| Expiry one block after submitted_block | LR-2: must pass |
| Sequential fills on same lane | Does filled_qty accumulate correctly across fills? |
| Close then fill attempt | Closed lane must be ineligible (LR-2) |

*Priority 2 — IR-7 enforcement:* Acceptance of multi-same-account bundles is a critical attack vector. Must test bundles with 2, 3, and N duplicate `account_id` values across instructions.

*Priority 3 — LR-2 strict expiry:* Conformance tests for the exact boundary case (Appendix F, F.2).

*Priority 4 — All validity rules:* Full audit of Sections 5 and 9 (all SR through SEL rules and STV rules).

*Priority 5 — Additional surfaces:* MarketsReducer determinism across independent implementations; solver reference implementation; per-solver deduplication (SEL-1) correctness; agent software key management and cancellation; state divergence recovery procedure (Section 13.4); E_MIN no-settlement path as a first-class outcome; Interstellar OS namespace integration.

Published audit reports; all critical findings resolved before deployment.

---

## 15. Future Extensions

### 15.1 Portfolio Margin and Leverage

Namespace model extends to position and collateral entries. Requires canonical oracle integration via a new module.

### 15.2 Derivatives

Requires v2 margin. Perpetual futures and options as namespace position types.

### 15.3 Cross-Chain Settlement

ZIM outputs triggering releases on foreign chains. Requires atomic cross-chain messaging and Portal module integration.

### 15.4 ZK-Assisted Lightweight Verification

The Interstellar OS namespace state is ZK-compatible. ZK proofs of namespace state transitions enable light client state verification without full history replay.

### 15.5 Continuous Matching Track

Shorter auction windows (2–5 blocks) for liquid pairs. Tradeoff: reduced MEV mitigation and solver optimization budget.

### 15.6 Dynamic Lane Reservation (ResizeLane)

A future version may introduce a ResizeLane claim type allowing participants to adjust `reserved_qty` without closing and reopening a lane. This feature was designed, specified, and removed from v1 (see Section 1.5 and the Pre-Specification adversarial record). It would improve capital efficiency but requires careful specification of temporal reservation semantics at reducer validation time. Any future introduction requires an independent adversarial review pass covering the full interaction matrix between reservation changes, in-flight bundles, and the block boundary interpretation rules.

### 15.7 Future Confirmation Path Design

Requires verifiable proof-of-delivery mechanism. Candidate approaches: (a) on-chain encrypted proposal commitment by solvers before solver deadline; (b) two-round architecture with distinct protocol phase. Requires independent adversarial review and audit.

### 15.8 VRF-Based Bundle Selection Randomness

Threshold VRF over the Zenon validator set, producing a publicly verifiable random beacon with zero individual-validator influence. This is the definitive long-term resolution to the block producer bias problem identified in Sections 6.3 and 10.6. Design, integration path, and governance requirements deferred to a future specification.

### 15.9 Automated Dispute Resolution and Fraud Proofs

Automated detection and recovery from invalid state transitions: (a) canonical challenge-response protocol for namespace state disputes, (b) slashing conditions for reducer instances finalizing bundles with incorrect state, (c) automated rollback with defined recovery boundaries. This would eliminate the governance-dependent recovery gap documented in Section 13.4.

### 15.10 Relaxed Same-Account Multi-Lane Bundle Rule

A future version may introduce explicit per-bundle account state sequencing enabling multi-lane same-account fills, removing the strategy sharding side effect documented in Section 7.5. Requires independent adversarial review.

### 15.11 Solver Quality Metrics and Public Dashboards

Ecosystem priority. Tracking: solver win rates, actual price improvement, surplus achievement, intent exclusion patterns, lane selection patterns, fee extraction rates relative to improvement delivered, no-settlement round frequency per pair. All metrics are derivable from public claim history and `markets/` namespace state.

---

## 16. Architecture Commitment and Launch Gates

### 16.1 Architecture Commitment

The protocol architecture is fixed. No changes will be made to the validity rules, namespace state model, claim definitions, or invariants unless one of the following conditions is satisfied:

1. **A formal contradiction is found** — a proof attempt produces a counterexample demonstrating that a validity rule fails to maintain one of the six invariants of Section 10.7.
2. **A new attack class is demonstrated** to violate a safety invariant under the stated assumptions — not merely to create economic inefficiency or operational difficulty.
3. **A soundness error is found** in the completed formal verification proofs.

Parameter adjustments (Section 12), future extensions (Section 15), and implementation tooling do not constitute architectural changes. Any proposed architectural change must identify which condition above it satisfies and must be accompanied by a new adversarial review pass before adoption.

### 16.2 Launch Gates

The following five conditions must each be satisfied and recorded in a governance vote before mainnet activation. All five are required; none is waivable. The activation block must be set no earlier than 7 days after that vote.

---

**LG-1 — E_MIN tolerability on target pairs.**

*Criterion:* Over a continuous 30-day testnet period with bootstrapping incentives active and at least 3 independent solver operators participating, at least 90% of rounds on each designated launch pair produce settlement (i.e., `|E| ≥ 2`).

*Gate owner:* Governance confirmation based on public claim stream data.

---

**LG-2 — Block production bias within H ≤ 8 assumption.**

*Criterion:* An independent measurement of Zenon's block production model confirms that no validator can evaluate more than 8 candidate block hashes within the finalization window. This measurement must be conducted on the live Zenon Network. If inconsistent with H ≤ 8, VRF-based randomness (Section 15.8) must be implemented before mainnet.

*Gate owner:* Independent technical auditor.

---

**LG-3 — Watcher and cancellation infrastructure available.**

*Criterion:* At least two independent, publicly accessible watcher service providers are operational. At least one open-source watcher reference implementation is available. The agent software reference implementation includes a working watcher service component.

*Gate owner:* Ecosystem coordinator; confirmed by governance.

---

**LG-4 — Solver competition healthy at target volume.**

*Criterion:* Over the 30-day period immediately before mainnet launch on testnet: (a) at least 3 distinct `solver_id` values win rounds; (b) no single solver wins more than 60% of settled rounds on any launch pair; (c) bootstrapping subsidy disbursement mechanism is tested end-to-end.

*Gate owner:* Governance; solver win rates are public claim stream observables.

---

**LG-5 — Lane lifecycle and churn rate manageable.**

*Criterion:* Over a 30-day testnet period, the ratio of `close_lane` + `open_lane` claims to finalized SettlementInstruction counts does not exceed 10:1 on any launch pair, confirming that close-and-reopen overhead is operationally acceptable without dynamic resizing.

*Gate owner:* Infrastructure working group; confirmed by governance.

---

## Appendix A: Encoding Specification

All ZIM protocol objects use CBOR deterministic serialization (RFC 8949 §4.2).

**Rules:** (1) Integer fields: minimum-length encoding. (2) Map keys: sorted by unsigned integer field index. (3) `FixedPoint128`: `[mantissa: uint128, exponent: int8]`. (4) `bytes32`: 32-byte CBOR byte strings. (5) `Signature`: 64-byte byte string (Ed25519 r‖s).

**OpenLaneClaim field indices:**

| Index | Field | | Index | Field |
|---|---|---|---|---|
| 0 | lane_id | | 4 | reserved_qty |
| 1 | account_id | | 5 | expiry_block |
| 2 | lane_sequence | | 6 | signature |
| 3 | reserved_asset | | | |

`lane_id = SHA3-256(canonical_cbor(fields 1–5))`

**CloseLaneClaim field indices:**

| Index | Field | | Index | Field |
|---|---|---|---|---|
| 0 | close_id | | 3 | lane_id |
| 1 | account_id | | 4 | signature |
| 2 | lane_sequence | | | |

`close_id = SHA3-256(canonical_cbor(fields 1–3))`

**TradeIntentClaim field indices:**

| Index | Field | | Index | Field |
|---|---|---|---|---|
| 0 | intent_id | | 7 | min_price |
| 1 | account_id | | 8 | max_fee_rate |
| 2 | lane_id | | 9 | expiry_block |
| 3 | lane_nonce | | 10 | min_fill_quantity |
| 4 | sell_asset | | 11 | flags |
| 5 | max_sell_quantity | | 12 | signature |
| 6 | buy_asset | | | |

`intent_id = SHA3-256(canonical_cbor(fields 1–11))`

**SettlementInstruction field indices:**

| Index | Field | | Index | Field |
|---|---|---|---|---|
| 0 | instruction_id | | 7 | sell_quantity |
| 1 | account_id | | 8 | buy_asset |
| 2 | lane_id | | 9 | buy_quantity |
| 3 | lane_nonce | | 10 | clearing_price |
| 4 | intent_id | | 11 | base_fee |
| 5 | bundle_id | | 12 | improvement_fee |
| 6 | sell_asset | | | |

`instruction_id = SHA3-256(canonical_cbor(fields 1–12))`

Note: `pre_state_root`, `post_state_root`, and `state_proof` fields from v1.9.0 are removed. The instruction_id derivation no longer includes them.

**SettlementBundleClaim field indices:**

| Index | Field | | Index | Field |
|---|---|---|---|---|
| 0 | bundle_id | | 4 | asset_potentials |
| 1 | auction_round | | 5 | solver_signature |
| 2 | solver_id | | 6 | submitted_block |
| 3 | instructions | | | |

---

## Appendix B: Protocol Parameter Registry

| Parameter | Symbol | Value | Tier | Notes |
|-----------|--------|-------|------|-------|
| Collection window | K | 10 blocks | Tier 2 | ~50s at 5s blocks |
| Solver window | M | 6 blocks | Tier 2 | |
| Max bundle size | MAX_BUNDLE_SIZE | 256 | Tier 1 | |
| Finality depth | CONFIRM_DEPTH | 30 blocks | Tier 1 | |
| Min fee rate | MIN_FEE_RATE | 0.0001 | Tier 1 | 1 basis point |
| Improvement share rate | IMPROVEMENT_SHARE_RATE | 0.10 | Tier 1 | 10% of actual fill improvement |
| Execution tolerance | EXECUTION_TOLERANCE | 0.002 | Tier 1 | 0.2% |
| Surplus band | SURPLUS_BAND | 0.005 | Tier 2 | 0.5% |
| Solver bootstrap threshold | SOLVER_BOOTSTRAP_THRESHOLD | $500,000 | Tier 2 | Monthly fill volume for subsidy eligibility |
| Price potential tolerance | δ | 10⁻⁹ | Constant | Not governance-adjustable |
| Minimum eligible set | E_MIN | 2 | Tier 1 | Rounds below this floor produce no settlement |
| Recovery window | RECOVERY_WINDOW | 48 hours | Tier 1 | Auto-suspension trigger for unresolved state divergence |

---

## Appendix C: Notation

| Symbol | Definition |
|--------|------------|
| SHA3-256(x) | Keccak-256 hash of x |
| canonical(o) | Canonical CBOR encoding of o |
| verify(sig, msg, key) | Ed25519 signature verification |
| MarketsReducer | The deterministic reducer that enforces ZIM validity rules and derives markets namespace state |
| φ(a) | Log-price potential of asset a |
| clearing_price(A→B) | exp(φ(B) − φ(A)) |
| surplus(B) | Aggregate post-fee participant welfare improvement of bundle B above minimums |
| S_max | Maximum surplus across deduplicated bundles in a round |
| D | Per-solver deduplicated bundle set |
| E | Eligible bundle set within SURPLUS_BAND of S_max, drawn from D |
| E_MIN | Minimum eligible set size for settlement to occur (2) |
| H | Upper bound on block hash evaluations per block producer per finalization window |
| δ | Price potential consistency tolerance (10⁻⁹) |
| EXECUTION_TOLERANCE | Max deviation of fill price from clearing price (0.2%) |
| IMPROVEMENT_SHARE_RATE | Solver's fraction of actual fill improvement above min_price (10%) |
| actual_improvement | max(0, buy_quantity − min_price × sell_quantity) per instruction |
| free_balance(account, asset) | markets/balances/{account}/{asset} − Σ active unrealized lane reservations for that asset |
| RECOVERY_WINDOW | Maximum interval between divergence detection and governance coordination (48 hours) |

---

## Appendix D: Scalability Properties

This appendix explains why the protocol structure allows realistic operation at 50,000–100,000 intents per round on competitive solver hardware. This is a structural argument, not a performance guarantee.

**1. Price search space is compressed by the potential model.** A solver chooses one log-price scalar per asset. For 80,000 intents across 200 assets, the continuous pricing degrees of freedom are approximately 200.

**2. Most intents are non-competitive after pruning.** Cheap filters — expired, cancelled, infeasible `min_price`, dominated, insufficient reservation — reduce practical pool size by one to two orders of magnitude before expensive optimization.

**3. IR-7 simplifies per-account state tracking.** Each account's balance check is a single namespace lookup. No intra-bundle running account state to maintain.

**4. Proof generation is eliminated.** Solvers no longer build SMT state proofs. The MarketsReducer reads namespace state directly. This removes the most compute-intensive per-instruction solver workload.

**5. The intent graph is sparse.** Real markets concentrate around a few quote assets. Hub-and-spoke structure decomposes into manageable subproblems.

**6. The protocol does not require an optimal solution.** Near-optimal bundles compete equally within the surplus band. The performance target is "good bundle quickly," not "global optimum."

**7. The pipeline is parallelizable.** Pruning, state lookups, candidate scoring are all parallelizable.

**8. The real bottleneck is not raw intent count.** Scaling constraints: distinct active asset count, hub pair density, and accounts with many interdependent lane intents.

---

## Appendix E: Formal Verification Properties

Completion of all items in this appendix is a **mandatory mainnet deployment precondition**. No mainnet launch date shall be set until all six proofs are complete and independently reviewed.

### E.1 Structural Preconditions for Formal Verification

Formal verification of protocol safety requires the state model to have four properties: (1) **determinism** — the MarketsReducer state transition function is fully specified; (2) **locality** — validity of a transition can be checked without reference to other concurrent transitions; (3) **closure** — no external data enters the transition function; (4) **finite type structure** — all state is expressible in finite typed values.

This protocol satisfies all four. Notably, the removal of ResizeLane from v1 eliminates the one area where property (2) was most fragile: the temporal reservation lookup at `submitted_block` would have required agreement on historical namespace state rather than current namespace state. With fixed reservation, LR-1 is a simple arithmetic check over values in the current `markets/lanes/` namespace. All transitions are local.

The architecture is committed (Section 16.1). Proofs completed against this specification remain valid unless a condition in Section 16.1 is satisfied.

### E.2 Verification Targets — The Six Invariants of Section 10.7

**Invariant 1 (Non-negative balances):** Safety property over the `markets/balances/` namespace. Proof approach: induction over reducer-accepted claims. Base case: genesis has all balances ≥ 0. Inductive step: STV-2 for settlements; balance sufficiency checks at lane opening.

**Invariant 2 (Reservation integrity):** For all reachable states and active lanes, `lanes/{lane_id}.filled_qty ≤ lanes/{lane_id}.reserved_qty`. Proof approach: LR-1 prevents any settlement that would violate this. Lane opening initializes `filled_qty = 0 ≤ reserved_qty`. No claim modifies `reserved_qty` after opening. Induction over settlements.

**Invariant 3 (Fill bound):** IR-5 enforces the residual quantity bound at each fill. Proof approach: induction over the sequence of fills for a given intent, with `markets/intents/{intent_id}.filled_qty` as the accumulator.

**Invariant 4 (Replay prevention):** Lane nonce is monotonically increasing within a lane. Proof approach: STV-4 increments `last_lane_nonce` by 1 per fill; the reducer rejects fills with `lane_nonce ≤ lane.last_lane_nonce`. Two instructions with the same `(lane_id, lane_nonce)` require the same pre-fill nonce, which is impossible after the first is applied.

**Invariant 5 (Cycle price consistency):** CPR-2 checked per bundle. Algebraic identity: prices derivable from a common potential satisfy ∏ cycle_prices = 1 because `clearing_price(A→B) = exp(φ(B) − φ(A))` and the product telescopes.

**Invariant 6 (Fee bounds):** PR-4 and PR-6 are checked at finalization and are arithmetic constraints over claim field values.

### E.3 Recommended Formal Methods Approaches

**Model checking:** The account state model is small and finitely typed. A bounded model checker (TLA+, Alloy, or SMT-based) can exhaustively verify Invariants 1–4 for accounts with bounded balances and bounded operation sequences. The lane lifecycle — materially simpler without ResizeLane — is the primary model checking target.

**Mechanized theorem proving:** Invariant 5 is amenable to proof in Lean 4 or Coq. The proof is a straightforward algebraic identity: the product around any directed cycle telescopes to `exp(0) = 1`.

**SMT-based arithmetic verification:** Invariants 1–3 and 6 involve bounded integer arithmetic over `uint128`. Z3 or CVC5 can verify these constraints are satisfiable under all valid operation sequences.

### E.4 What Formal Verification Does and Does Not Cover

**In scope:**
- The six safety invariants of Section 10.7
- Determinism of the MarketsReducer settlement validity rules
- The algebraic cycle consistency property
- The correctness of fee arithmetic under integer constraints

**Out of scope:**
- Liveness: no protocol guarantee that any intent will be filled
- Price optimality: not protocol-enforceable
- Solver market health: emergent property
- Implementation correctness: specification verification does not guarantee any specific reducer implementation is correct
- E_MIN sufficiency: that `E_MIN = 2` provides adequate competitive pressure is an empirical claim

### E.5 Verification Priority and Acceptance Criteria

All six must be complete before mainnet.

1. **Invariant 2 (Reservation integrity) and Invariant 3 (Fill bound)** — Direct anti-overdraft guarantees. *Acceptance:* Bounded model checker produces no counterexample for all lane lifecycle paths at MAX_BUNDLE_SIZE and uint128 max balances.

2. **Invariant 4 (Replay prevention)** — *Acceptance:* Mechanized proof in TLA+ or equivalent that no two finalized instructions share `(lane_id, lane_nonce)`.

3. **Invariant 5 (Cycle consistency)** — *Acceptance:* Machine-checked proof in Lean 4 or Coq of the telescoping algebraic identity.

4. **Invariant 1 (Non-negative balances)** — *Acceptance:* Proof follows compositionally from Invariant 2 and STV-1; document the derivation.

5. **Invariant 6 (Fee bounds)** — *Acceptance:* Z3 or CVC5 produces UNSAT for all fee constraint violations under uint128 arithmetic.

---

## Appendix F: Conformance Test Vectors

A MarketsReducer implementation that produces the correct outcome for all cases in this appendix is considered conformant with the ZIM validity rules. Partial conformance is not conformance.

### F.1 Lane Lifecycle Paths

**F.1.1 — Standard open, fill to partial, close**

```
open_lane claim:  reserved_qty = 1000, expiry_block = 200
trade_intent:     max_sell_quantity = 800, partial_fill = true
settlement fill:  sell_quantity = 600

LR-1: filled_qty(0) + 600 ≤ reserved_qty(1000) → PASS
STV-4: lanes/{lane_id}.filled_qty = 600; last_lane_nonce = 1
balances: sell_asset decreases by 600 + fees; lane holds (1000 - 600) = 400 reserved
```

**F.1.2 — Fill exactly to reserved_qty boundary**

```
open_lane: reserved_qty = 500
settlement fill: sell_quantity = 500, filled_qty = 0

LR-1: 0 + 500 ≤ 500 → PASS (boundary case)
```

**F.1.3 — Fill exceeding remaining reservation**

```
open_lane: reserved_qty = 500, filled_qty = 200
settlement fill: sell_quantity = 400

LR-1: 200 + 400 = 600 > 500 → FAIL → bundle rejected
```

**F.1.4 — Fill on closed lane**

```
close_lane claim accepted at block 90
bundle.submitted_block = 95

LR-2: lanes/{lane_id}.is_closed = true → lane not active → FAIL → bundle rejected
```

**F.1.5 — Sequential fills on same lane**

```
Fill 1: sell_quantity = 300, filled_qty = 0 → filled_qty_after = 300
Fill 2: sell_quantity = 300, filled_qty = 300 → filled_qty_after = 600
Fill 3: sell_quantity = 200, filled_qty = 600 → 600 + 200 = 800 ≤ 1000 → PASS
Fill 4: sell_quantity = 201, filled_qty = 800 → 800 + 201 = 1001 > 1000 → FAIL
```

---

### F.2 LR-2 Strict Expiry Boundary Cases

**F.2.1 — Lane expires exactly at submitted_block — REJECTED**

```
lane.expiry_block = 100
bundle.submitted_block = 100

LR-2: 100 > 100 → FALSE → lane EXPIRED → bundle REJECTED
```

**F.2.2 — Lane expires one block after submitted_block — VALID**

```
lane.expiry_block = 101
bundle.submitted_block = 100

LR-2: 101 > 100 → TRUE → lane ACTIVE → PASS
```

**F.2.3 — Conformance note:** Any implementation using `≥` instead of `>` in LR-2 passes F.2.1 incorrectly. This is a consensus-diverging bug. Test F.2.1 explicitly as a rejection case in every MarketsReducer implementation.

---

### F.3 IR-7 Duplicate Account Rejection

**F.3.1 — Bundle with two instructions for the same account — REJECTED**

```
instruction[0].account_id = 0xAAAA...
instruction[1].account_id = 0xAAAA...

IR-7: duplicate account_id found → bundle REJECTED before per-instruction processing
```

**F.3.2 — Bundle with N same-account instructions — REJECTED regardless of N**

```
instructions[0..N].account_id = 0xAAAA...

IR-7: any duplicate → bundle REJECTED
```

**F.3.3 — Bundle with two distinct accounts — PASS**

```
instruction[0].account_id = 0xAAAA...
instruction[1].account_id = 0xBBBB...

IR-7: no duplicate → PASS
```

---

### F.4 E_MIN Round Outcomes

**F.4.1 — Zero valid bundles: no settlement**

```
Valid proposal claims: 0
|E| = 0 < E_MIN = 2
Result: NO SETTLEMENT. markets_notice(no_settlement) emitted. Not an error.
```

**F.4.2 — Exactly one valid bundle: no settlement**

```
Valid proposals: B1 (solver S1 only)
|D| = 1, |E| = 1 < E_MIN = 2
Result: NO SETTLEMENT. Intent claims persist to next round.
```

**F.4.3 — Exactly two valid bundles: settlement proceeds**

```
Valid proposals: B1 (solver S1), B2 (solver S2)
|D| = 2. Assume both within SURPLUS_BAND: |E| = 2 ≥ E_MIN = 2.
seed = SHA3-256(finalization_block_hash || auction_round)
winner = E[seed mod 2]
Result: markets_resolution(bundle_finalize) emitted for winning bundle.
```

**F.4.4 — Two bundles from same solver: deduplication yields one, no settlement**

```
Proposals B1 and B2, both solver_id = S1
After SEL-1: |D| = 1 (higher-surplus bundle retained)
|E| ≤ 1 < E_MIN = 2
Result: NO SETTLEMENT.
```

---

### F.5 Fixed-Point Arithmetic Boundary Cases

**F.5.1 — PR-3 arithmetic consistency (rounding tolerance)**

```
sell_quantity = 1000, clearing_price = 1.0026
Expected buy_quantity = 1002.6

buy_quantity = 1003: |1003 − 1002.6| = 0.4 ≤ 1 → PASS
buy_quantity = 1002: |1002 − 1002.6| = 0.6 ≤ 1 → PASS
buy_quantity = 1001: |1001 − 1002.6| = 1.6 > 1 → FAIL
buy_quantity = 1004: |1004 − 1002.6| = 1.4 > 1 → FAIL
```

**F.5.2 — PR-5 execution tolerance**

```
clearing_price = 1.0500, EXECUTION_TOLERANCE = 0.002
floor = 1.0500 × 0.998 = 1.04790

buy_quantity / sell_quantity = 1.04791 ≥ 1.04790 → PASS
buy_quantity / sell_quantity = 1.04789 < 1.04790 → FAIL
```

**F.5.3 — PR-6 improvement fee cap**

```
sell_quantity = 1000, min_price = 1.00, buy_quantity = 1050
IMPROVEMENT_SHARE_RATE = 0.10

actual_improvement = max(0, 1050 − 1.00 × 1000) = 50
improvement_fee_cap = 50 × 0.10 = 5

improvement_fee = 5 → PASS (at cap)
improvement_fee = 6 → FAIL (above cap)
improvement_fee = 0 → PASS (below cap is valid)
```

**F.5.4 — CPR-2 price potential consistency tolerance**

```
δ = 10⁻⁹
p = 1.5, φ(A) = 0.0, φ(B) = ln(1.5) ≈ 0.405465108108164

|ln(1.5) − (0.405465108108164 − 0.0)| = 0 → PASS

φ(B) = 0.405465108208164 (off by 10⁻⁹):
|0.405465108108164 − 0.405465108208164| = 10⁻⁹ ≤ 10⁻⁹ → PASS (boundary)

φ(B) = 0.405465108308164 (off by 2 × 10⁻⁹):
|0.405465108108164 − 0.405465108308164| = 2 × 10⁻⁹ > 10⁻⁹ → FAIL
```

---

### F.6 Conformance Certification

A MarketsReducer implementation is conformant with the ZIM validity rules if and only if it produces the correct outcome — PASS or FAIL as specified — for all test cases in this appendix. Additional test cases may be added to this appendix before mainnet without constituting an architectural change, provided they do not alter the validity rules themselves.

---

*Zenon Interstellar Markets Protocol — v2.0.0*  
*Zenon Network of Momentum — Community Research*  
*Interstellar OS Protocol Module — Supersedes v1.9.0*  
*https://github.com/TminusZ/zenon-developer-commons*
