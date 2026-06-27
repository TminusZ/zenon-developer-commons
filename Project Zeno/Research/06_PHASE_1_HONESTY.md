# Phase 1 Honesty

## Purpose

This note explains the Phase 1 trust model for Project Zeno’s DS layer.

The core thesis is:

**Phase 1 is bonded attestation with bounded custody, not fully trustless execution.**

The safe phrase is:

```text id="xuv85k"
Bonded attestation now. Proof-based verification later.
```

This document is explanatory. `SPEC.md` governs on any conflict.

---

## The short version

Phase 1 activates the first safe slice of the DS layer.

It provides:

```text id="1y5thq"
one WASM domain
L1_NATIVE inputs
one bonded executor
off-chain execution
on-chain batch commitments
public state roots
aggregate custody enforcement
withdrawal delays
value caps
asynchronous messaging
data-availability commitments
```

It does not provide:

```text id="7myfzx"
fully trustless execution
fraud-proof enforcement
validity-proof enforcement
permissionless executor sets
multiple active runtimes
Bitcoin interoperability
Ethereum interoperability
oracle domains
synchronous composability
```

That boundary is not a weakness.

It is the safety boundary of Phase 1.

---

## Why this document matters

The easiest way to damage Project Zeno’s credibility is to overclaim Phase 1.

The DS layer is a powerful architecture, but Phase 1 is intentionally narrow.

The honest framing is:

```text id="dfed1p"
Phase 1 gives Zenon a bounded, publicly auditable execution domain with aggregate custody safety and delayed exits.
```

The dishonest framing is:

```text id="ciy5pn"
Phase 1 ships fully trustless smart contracts.
```

It does not.

Phase 1 is the first implementation step toward a larger proof-based architecture.

---

## What Phase 1 actually is

Phase 1 is a single-domain execution system.

The active domain is:

```text id="j1bm7k"
runtimeKind = WASM
inputSource = L1_NATIVE
executor model = single bonded executor
```

Users submit inputs through Zenon L1.

Zenon orders those inputs.

The executor processes them off-chain.

Settlement records the resulting commitments.

The flow is:

```text id="pzc370"
User input
   ↓
Zenon L1 ordering
   ↓
Single bonded executor
   ↓
Off-chain WASM execution
   ↓
Batch commitment
   ↓
Settlement anchoring
```

That is the Phase 1 model.

---

## Bonded attestation

Phase 1 relies on a bonded executor.

The executor computes the domain state transition and submits the result.

The bond creates an economic stake behind the executor’s attestation.

But the important caveat is:

```text id="68m2z9"
Bonded attestation is not the same as proof-based verification.
```

In Phase 1, the chain does not fully re-execute every contract step on-chain.

It does not yet enforce fraud proofs.

It does not yet verify validity proofs.

Instead, the executor publicly commits to the state transition, and Settlement enforces aggregate custody limits around that commitment.

The safe phrase is:

```text id="7j7orb"
The executor attests. Settlement bounds the risk.
```

---

## What Settlement guarantees in Phase 1

Settlement can enforce rules that do not require re-running the whole domain.

Phase 1 Settlement can enforce:

```text id="vqj5er"
domain isolation
batch commitment structure
aggregate custody conservation
withdrawal delays
value caps
public commitment visibility
ordered input anchoring
```

Most importantly, Settlement can prevent a domain from withdrawing more of an asset than it has received in aggregate.

That means Phase 1 protects against aggregate over-withdrawal.

In simple terms:

```text id="jajuvl"
The domain cannot drain more than the domain has been allowed to control.
```

That is a real safety property.

---

## What Settlement does not guarantee in Phase 1

Settlement does not maintain every user’s internal balance.

Settlement does not prove every contract-level state transition.

Settlement does not know whether a user’s internal domain balance is correct.

Settlement does not know whether the executor applied every contract rule honestly.

Those are execution-correctness questions.

In Phase 1, execution correctness depends on the bonded executor and public auditability.

The safe statement is:

```text id="jzlecd"
Phase 1 enforces aggregate custody safety, not full per-account correctness.
```

The unsafe statement is:

```text id="v7msxj"
Every user balance is trustlessly enforced on-chain in Phase 1.
```

It is not.

---

## Aggregate custody vs per-account correctness

This distinction is essential.

### Aggregate custody

Aggregate custody asks:

```text id="irf7b1"
Did this domain withdraw more total value than it received?
```

Settlement can enforce this.

### Per-account correctness

Per-account correctness asks:

```text id="t9rnd0"
Did the executor correctly track Alice’s balance, Bob’s balance, and every contract state update?
```

Phase 1 does not fully enforce this on-chain.

That is why Phase 1 is called bonded attestation.

The executor’s behavior is publicly committed and economically bounded, but not yet fully proven by fraud or validity proofs.

---

## Balance-blind settlement

Settlement is intentionally balance-blind.

It does not maintain a per-user ledger for every domain.

Instead, it tracks aggregate custody per domain and asset.

Per-account balances live inside domain state.

This lets Settlement stay thin.

The tradeoff is:

```text id="rd6jrv"
Settlement can enforce domain-level conservation.
The domain/executor must correctly maintain internal balances.
```

Future proof systems are meant to strengthen that second part.

---

## Withdrawal delays

Withdrawal delays are one of the key Phase 1 risk controls.

A withdrawal is not instantly released the moment a domain emits it.

There is a delay window.

That gives time for:

```text id="ll5lzf"
public observation
watcher alerts
operator response
user awareness
future challenge mechanisms
```

In Phase 1, the delay is not yet a full fraud-proof challenge game.

But it still matters.

It prevents instant extraction from a bad commitment and creates time for detection and response.

The safe phrase is:

```text id="nf3vz6"
Withdrawal delays give Phase 1 time to notice problems before value exits.
```

---

## Value caps

Value caps are another Phase 1 risk control.

A domain can be limited in how much value it can move over a defined window.

This matters because Phase 1 does not yet have full proof-based correctness.

If the executor is dishonest or broken, the damage should be bounded.

The principle is:

```text id="6v4gr5"
When verification is not fully trustless yet, exposure must be capped.
```

Value caps make Phase 1 safer while the proof ladder is still being built.

---

## Public commitments

Even though Phase 1 does not prove every state transition on-chain, it does make commitments public.

A batch commitment can include roots such as:

```text id="xgxkpk"
preStateRoot
postStateRoot
inputRoot
receiptRoot
eventRoot
outboxRoot
DAHash
```

These commitments matter because they create a public audit trail.

They allow watchers, users, developers, and future proof systems to reason about what the executor claimed.

The safe phrase is:

```text id="fmpage"
Phase 1 makes execution publicly committed before it becomes fully proof-enforced.
```

---

## Watchers in Phase 1

Watchers are important, but their Phase 1 role must be stated carefully.

A watcher can observe, replay, compare, and raise alarms.

A watcher can help detect executor divergence.

But Phase 1 does not yet include the full fraud-proof enforcement path.

That means a watcher is not yet an on-chain slashing or dispute system.

The safe claim is:

```text id="zp4e2v"
Phase 1 watchers can support public auditability and alarms.
```

The unsafe claim is:

```text id="qjswi8"
Phase 1 watchers enforce fraud proofs on-chain.
```

They do not.

---

## Data availability in Phase 1

Phase 1 includes data-availability commitments.

A batch can commit to the data needed to understand or replay execution.

But committing to a data hash is not the same thing as fully enforcing data availability on-chain.

The safe framing is:

```text id="h0sn1w"
Phase 1 commits to data availability artifacts, while stronger DA enforcement belongs to later phases.
```

The unsafe framing is:

```text id="m92sit"
Phase 1 fully enforces data availability on-chain.
```

It does not.

---

## Why Phase 1 is still meaningful

It would be wrong to dismiss Phase 1 because it is not fully trustless yet.

Phase 1 is meaningful because it establishes the core DS layer machinery:

```text id="1bdqai"
domain registration model
WASM execution domain
canonical input ordering
off-chain execution pipeline
on-chain batch commitments
aggregate custody enforcement
withdrawal delay model
value cap model
data-availability commitments
asynchronous message roots
future proof hooks
```

That is a lot.

The important point is not that Phase 1 is the final trust model.

The important point is that Phase 1 creates the first working domain inside an architecture designed to become stronger over time.

---

## The proof ladder

The DS layer should be understood as a staged proof ladder.

### Phase 1

```text id="sn52z2"
bonded attestation
public commitments
bounded custody
withdrawal delays
value caps
```

### Future fraud-proof phase

```text id="kfjgto"
watchers replay execution
invalid transitions can be challenged
fraud evidence can be submitted
bad executors can be penalized
withdrawal delays become challenge windows
```

### Future validity-proof phase

```text id="52i7kp"
batch commitments include validity proofs
Settlement verifies succinct proof data
execution correctness is proven before finalization
withdrawal risk can shrink
executor trust assumptions can weaken
```

This is the honest direction:

```text id="3181hg"
Bonded attestation now. Fraud proofs later. Validity proofs after that.
```

---

## Why not ship everything at once?

Trying to ship the whole final architecture at once would be risky.

A safe first phase should minimize moving parts.

Phase 1 keeps the system constrained:

```text id="7i6zjv"
one runtime
one input source
one executor
bounded value
public commitments
delayed exits
```

That makes implementation, testing, and auditing more manageable.

The DS layer is designed for expansion, but the first slice should be narrow.

The safe phrase is:

```text id="zobn2r"
Phase 1 is narrow because the architecture is serious.
```

---

## What Phase 1 does not ship

Phase 1 does not ship:

```text id="v34kpu"
multiple active domains
multiple active runtimes
public domain creation
permissionless executor sets
fraud-proof enforcement
validity-proof enforcement
Bitcoin relayed inputs
Ethereum relayed inputs
oracle observed inputs
Sentinel service markets
QSR collateral assignment
synchronous contract calls
native BTC custody
Ethereum asset interoperability
```

These may be future research or future implementation directions.

They should not be marketed as current features.

---

## Safe public framing

Use this:

```text id="sbpn64"
Phase 1 ships the first safe slice of the DS layer: one WASM domain, native Zenon inputs, a bonded executor, public commitments, aggregate custody enforcement, withdrawal delays, and value caps.
```

For a shorter version:

```text id="f6p9zv"
Phase 1 is bonded attestation with bounded custody, not fully trustless execution.
```

For the roadmap version:

```text id="bfpyj4"
Phase 1 commits execution. Later phases prove execution.
```

---

## Unsafe public framing

Avoid these claims:

```text id="qz8lis"
Project Zeno is fully trustless in Phase 1.
Project Zeno already has fraud proofs.
Project Zeno already has validity proofs.
Project Zeno has permissionless executors.
Project Zeno has multiple active runtimes.
Project Zeno has Bitcoin interoperability.
Project Zeno has Ethereum interoperability.
Project Zeno has oracle domains.
Settlement verifies every contract state transition today.
Every user balance is enforced on-chain.
```

These claims overstate Phase 1 and weaken credibility.

---

## Why honesty is marketable

Honesty is not anti-marketing.

It is the only way the DS layer can be taken seriously.

The market has seen too many systems claim trustlessness before the proof machinery exists.

Project Zeno has a stronger story if it says exactly what is true:

```text id="nfbo81"
The architecture is larger than Phase 1.
Phase 1 is intentionally bounded.
The first domain is WASM.
The executor is bonded.
Settlement enforces aggregate custody.
Future phases add stronger proof systems.
```

That framing is credible.

It respects developers.

It protects users.

It makes the future roadmap believable.

---

## What builders should understand

Builders should understand that Phase 1 is not a free-for-all.

The first deployment should be treated like a bounded execution environment.

Good Phase 1 applications should be designed with the trust model in mind.

That means:

```text id="poewil"
do not assume instant trustless finality
respect withdrawal delays
respect value caps
design for public auditability
avoid unnecessary high-value custody early
make user-facing trust assumptions clear
```

Phase 1 can support useful applications, but the earliest applications should match the phase.

The trust model should shape the app design.

---

## What users should understand

Users should understand that Phase 1 gives them a new execution capability on Zenon, but not the final trust-minimized architecture.

The honest user-facing version is:

```text id="mgifux"
Your inputs are ordered by Zenon, execution is performed by a bonded executor, results are publicly committed, and withdrawals are bounded and delayed. Full proof-based execution verification comes later.
```

That is understandable.

It does not bury the risk.

---

## What researchers should explore next

Research should focus on the path from bonded attestation to stronger verification.

Important research tracks include:

```text id="nrdynb"
watcher replay design
fraud-proof challenge format
data-availability enforcement
executor decentralization
validity-proof integration
state-root proof formats
domain-specific proof adapters
safe value-cap parameters
withdrawal-delay calibration
```

These are the next trust-strengthening layers.

---

## What not to claim

Do not claim:

```text id="9ykjbb"
Phase 1 is trustless
Phase 1 proves execution correctness
Phase 1 has live fraud proofs
Phase 1 has live validity proofs
Phase 1 eliminates executor trust
Phase 1 has permissionless executor sets
Phase 1 supports external-chain inputs
Phase 1 makes all future hooks active
```

Use the safer versions:

```text id="aa9j75"
Phase 1 is bonded attestation.
Phase 1 bounds custody risk.
Phase 1 creates public commitments.
Phase 1 uses withdrawal delays and value caps.
Phase 1 prepares the path for fraud proofs and validity proofs.
Phase 1 activates one WASM domain with L1_NATIVE inputs.
```

---

## Final summary

Phase 1 is not the final form of Project Zeno.

It is the first safe slice of the DS layer.

The clean thesis is:

```text id="xlxi47"
Bonded attestation now. Proof-based verification later.
```

Phase 1 provides:

```text id="jpwy4t"
one WASM domain
native Zenon inputs
a bonded executor
public commitments
aggregate custody enforcement
withdrawal delays
value caps
data-availability commitments
future proof hooks
```

It does not provide fully trustless execution yet.

That honesty is what makes the architecture credible.

Project Zeno’s ambition is large, but Phase 1 should be explained exactly as it is.
