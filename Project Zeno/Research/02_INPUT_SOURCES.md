# Project Zeno Input Sources

## Purpose

This note explains one of the most important design ideas in Project Zeno:

**A domain is defined not only by what it executes, but also by where its inputs come from.**

In the DS layer, this distinction is captured by two separate fields:

```text
runtimeKind = what executes
inputSource = where truth comes from
```

This document focuses on the second field: `inputSource`.

This document is explanatory. `SPEC.md` governs on any conflict.

---

## The core idea

Most people will first understand Project Zeno through `runtimeKind`.

That is natural.

`runtimeKind` answers:

```text
What virtual machine or execution environment runs here?
```

For Phase 1, the answer is:

```text
WASM
```

Future runtimes could theoretically include EVM, Move, SVM, Cairo, zkVMs, or other domain-specific runtimes.

But `runtimeKind` is only half of the model.

The deeper field is `inputSource`.

`inputSource` answers:

```text
Where does this domain receive its canonical inputs from?
```

That is the hidden design hook.

It means Project Zeno is not just a system for running different VMs.

It is a system for settling domains that may receive different kinds of truth.

---

## The two-axis model

A Project Zeno domain has two major axes:

```text
runtimeKind = what executes
inputSource = where truth comes from
```

These are separate design questions.

An EVM domain and a Bitcoin SPV domain are both domains, but they are not the same kind of domain.

An EVM domain is mostly about runtime compatibility:

```text
Can Ethereum-style execution run here?
```

A Bitcoin SPV domain is mostly about external proof verification:

```text
Can this domain verify Bitcoin headers and transaction inclusion proofs?
```

Those are different problems.

Project Zeno separates them.

That separation is what makes the DS layer more than a smart-contract layer.

---

## The three input-source classes

The spec identifies three input-source classes:

```text
L1_NATIVE
L1_RELAYED
EXTERNAL_OBSERVED
```

Only one is active in Phase 1:

```text
L1_NATIVE
```

The other two are reserved:

```text
L1_RELAYED
EXTERNAL_OBSERVED
```

This boundary matters.

The architecture points toward external proof-data and observed systems, but Phase 1 does not activate them.

The safe framing is:

```text
Project Zeno’s domain model includes input-source types for native inputs, relayed external proof-data, and externally observed systems. Phase 1 activates only L1_NATIVE.
```

The unsafe framing is:

```text
Project Zeno ships Bitcoin, Ethereum, or oracle interoperability.
```

It does not.

---

## L1_NATIVE

`L1_NATIVE` means the domain receives its inputs directly from Zenon L1.

This is the Phase 1 model.

A user submits a call, deposit, or other domain input through Zenon.

Zenon orders it.

The executor processes it.

Settlement anchors the resulting commitment.

The flow is:

```text
User input
   ↓
Zenon L1
   ↓
Canonical ordering
   ↓
Domain executor
   ↓
State transition
   ↓
Settlement commitment
```

This is the cleanest and safest starting point for the DS layer.

It uses Zenon itself as the source of truth for the domain’s input stream.

---

## What L1_NATIVE gives a domain

A domain using `L1_NATIVE` inherits important properties from Zenon L1:

```text
Zenon ordering
Zenon inclusion
feeless access through plasma
momentum-based finality
publicly available input data
browser-checkable settlement commitments
```

This is why Phase 1 starts here.

The first WASM domain does not need an external chain, external oracle, or external watcher to define its input stream.

Its inputs come from Zenon.

That makes the first implementation easier to reason about.

---

## L1_RELAYED

`L1_RELAYED` means external proof-data is posted to Zenon L1 and then processed by a domain.

This is the route for external-chain proof systems.

Examples could include:

```text
Bitcoin headers
Bitcoin transaction inclusion proofs
Ethereum event proofs
external-chain light-client data
rollup output roots
other proof-shaped external data
```

The key detail is that the data is still posted to Zenon L1.

That means Zenon orders it.

The domain then verifies it.

The flow is:

```text
External event
   ↓
Relayer collects proof-data
   ↓
Relayer posts proof-data to Zenon L1
   ↓
Zenon orders the proof-data
   ↓
Domain verifies the proof-data
   ↓
Settlement anchors the resulting state commitment
```

This is not the same as trusting a relayer.

If the domain’s state-transition function verifies the proof, then a bad relayer can submit garbage, but the domain rejects it.

The relayer carries data.

The domain decides whether the data is valid.

---

## L1_RELAYED and Bitcoin

Bitcoin is the cleanest example of `L1_RELAYED`.

A Bitcoin-facing domain would not make Zenon into Bitcoin.

It would not make BTC native to Zenon.

It would not, by itself, solve BTC custody or withdrawal.

Instead, it could let a domain verify Bitcoin facts.

A Bitcoin SPV domain could verify things like:

```text
valid Bitcoin block headers
proof-of-work
chain linkage
confirmation depth
transaction inclusion
payment to a watched output
```

The flow would look like this:

```text
Bitcoin transaction happens
   ↓
Relayer posts Bitcoin headers and inclusion proofs to Zenon L1
   ↓
Zenon orders the relayed proof-data
   ↓
Bitcoin SPV domain verifies the proof
   ↓
The domain updates its own state
   ↓
Settlement anchors the new state root
```

The safe phrase is:

```text
Bitcoin legibility, not Bitcoin custody.
```

This means:

```text
Project Zeno could identify and verify Bitcoin events.
```

It does not mean:

```text
Project Zeno controls native BTC.
```

That distinction must stay clear.

---

## L1_RELAYED and Ethereum

Ethereum-facing relayed inputs are possible in concept, but harder than Bitcoin.

A domain could theoretically process:

```text
Ethereum logs
receipt proofs
storage proofs
finality proofs
rollup output roots
L2 event proofs
```

But running an EVM domain on Zeno is not the same thing as reading Ethereum.

These are separate ideas.

A future EVM domain would provide runtime compatibility:

```text
Solidity-style execution could settle to Zenon.
```

An Ethereum relay domain would provide event or state interoperability:

```text
Ethereum events or proofs could be verified by a Zeno domain.
```

Those are different.

The safe framing is:

```text
A future EVM domain could provide runtime and tooling compatibility. Ethereum event interoperability would require relayed proofs or another external-input mechanism.
```

The unsafe framing is:

```text
Running EVM on Zeno automatically gives Ethereum interoperability.
```

It does not.

Runtime compatibility is not asset interoperability.

---

## What a relayer does

A relayer brings proof-data or messages into the system.

A relayer may provide:

```text
Bitcoin headers
Merkle proofs
Ethereum event proofs
state proofs
rollup output roots
cross-domain outbox proofs
data-availability references
```

The relayer should not be confused with an executor.

The relayer carries data.

The executor computes the domain state transition.

Settlement anchors the result.

In simple terms:

```text
Relayer = brings inputs
Executor = computes state
Settlement = anchors commitments and enforces custody rules
```

A relayer may be untrusted if the domain verifies the proof-data itself.

A dishonest relayer can submit invalid data, but the domain rejects it.

A lazy relayer can withhold data, but if relaying is permissionless, another relayer can submit it.

So the main relayer risk is usually liveness, not correctness, assuming the verifier logic is sound.

---

## EXTERNAL_OBSERVED

`EXTERNAL_OBSERVED` means the executor observes an external system directly rather than relying on proof-data posted to Zenon L1.

This is different from `L1_RELAYED`.

With `L1_RELAYED`, external proof-data is posted to Zenon L1.

With `EXTERNAL_OBSERVED`, the executor watches something outside Zenon and includes its observation in the domain’s input sequence.

This could eventually point toward:

```text
oracle-like domains
market data feeds
proof-of-reserve observations
off-chain service reports
external system monitors
observed event feeds
```

But this model has weaker assumptions.

The observed data may not inherit Zenon L1 data availability.

The correctness may depend more heavily on executor rules, watcher rules, challenge windows, bonding, or future fraud-proof systems.

This is why `EXTERNAL_OBSERVED` must be treated carefully.

It is a reserved input-source class, not a shipped oracle system.

---

## L1_RELAYED vs EXTERNAL_OBSERVED

The difference matters.

`L1_RELAYED` means:

```text
The external proof-data is posted to Zenon L1.
Zenon orders it.
The domain verifies it.
The data is visible through the L1 input stream.
```

`EXTERNAL_OBSERVED` means:

```text
The executor observes the external system directly.
The observed input may not be posted to Zenon L1 first.
The domain must define how observations become canonical.
Data availability and verification assumptions are weaker.
```

A simple comparison:

```text
L1_NATIVE
Truth source: Zenon L1
Data availability: inherited from Zenon L1
Phase 1 status: active

L1_RELAYED
Truth source: external proof-data posted to Zenon L1
Data availability: inherited for the relayed payload
Phase 1 status: reserved

EXTERNAL_OBSERVED
Truth source: external system observed by executor
Data availability: domain-defined / weaker
Phase 1 status: reserved
```

The safest way to explain it:

```text
L1_NATIVE is native truth.
L1_RELAYED is external proof-data carried through Zenon.
EXTERNAL_OBSERVED is external observation handled by the domain.
```

---

## Why inputSource matters for interoperability

Interoperability is not one thing.

There are different kinds of interoperability:

```text
runtime compatibility
event interoperability
asset interoperability
settlement interoperability
tooling compatibility
liquidity interoperability
security interoperability
```

`inputSource` mostly controls event and truth interoperability.

For example:

A future EVM domain may give:

```text
runtime compatibility
tooling compatibility
```

But that does not automatically give:

```text
Ethereum asset interoperability
Ethereum liquidity interoperability
Ethereum security interoperability
```

To read Ethereum events, a domain needs an Ethereum proof or observation path.

To move Ethereum assets, a system needs custody, a bridge, or a proof-based asset representation.

To inherit Ethereum security, it would need to settle to Ethereum.

A Zeno-settled domain settles to Zenon.

That is why `inputSource` is so important.

It prevents people from confusing “runs similar code” with “connects to the same chain.”

---

## Why inputSource matters for Bitcoin

Bitcoin is not mainly a runtime compatibility target.

The point is not to run Bitcoin as a smart-contract VM.

The point is to verify Bitcoin facts.

A Bitcoin-facing domain would most likely be a relayed proof-data domain.

That makes Bitcoin an `inputSource` problem, not a `runtimeKind` problem.

The question is not:

```text
Can Zenon run Bitcoin?
```

The better question is:

```text
Can a Zeno domain verify Bitcoin events from relayed proof-data?
```

That is a cleaner and safer research path.

---

## Why inputSource matters for oracles

Oracles are also input-source problems.

An oracle domain is not primarily about what runtime it uses.

It is about where the data comes from, who observed it, how it was posted, how it can be challenged, and what guarantees users get.

`EXTERNAL_OBSERVED` points toward that future design space.

But because observed data is not naturally proof-shaped in the same way as a Bitcoin Merkle proof, the trust model is weaker.

That means any oracle-facing research must be careful about:

```text
data source rules
observer identity
bonding
challenge windows
data availability
fraud proofs
slashing
reputation
fallback behavior
```

The safe phrase is:

```text
The DS layer reserves an input-source class for observed external systems.
```

The unsafe phrase is:

```text
Project Zeno ships oracles.
```

---

## Why inputSource matters for cross-domain messages

Cross-domain messages are also inputs.

When one domain emits an outbox message, another domain can later consume it as an input.

That means a target domain may receive inputs from:

```text
users
deposits
relayed proofs
outbox messages from other domains
observed external systems
```

The DS layer’s power comes from treating inputs as ordered, verifiable objects rather than assuming every domain lives inside one shared synchronous VM.

This is why Project Zeno uses asynchronous messaging instead of synchronous composability.

A message can be committed, proven, relayed, and processed later.

That is slower than a direct call, but it preserves domain isolation.

---

## The safety boundary

The important boundary is simple:

```text
Only L1_NATIVE is active in Phase 1.
```

That means Phase 1 does not ship:

```text
Bitcoin relayed inputs
Ethereum relayed inputs
external observed inputs
oracle domains
external-chain light clients
external-chain bridges
```

The architecture reserves paths for those things.

It does not activate them.

The correct framing is:

```text
Project Zeno’s input-source model identifies how future domains could receive native inputs, relayed external proof-data, or observed external data. Phase 1 activates only native Zenon inputs.
```

---

## What not to claim

Do not claim:

```text
Project Zeno ships Bitcoin interoperability
Project Zeno ships Ethereum interoperability
Project Zeno ships oracle domains
Project Zeno can read any chain today
Project Zeno can bridge assets just because it has L1_RELAYED
Project Zeno can run EVM and therefore inherit Ethereum liquidity
EXTERNAL_OBSERVED has the same trust model as L1_RELAYED
Relayers are trusted bridges
```

Use the safer versions:

```text
The spec reserves a relayed-input route for external proof-data.
A Bitcoin SPV domain is a future research route, not a shipped feature.
A future EVM domain would provide runtime/tooling compatibility, not automatic Ethereum asset interoperability.
Observed external inputs require a weaker and clearly disclosed trust model.
Relayers carry proof-data; domains verify it.
```

---

## Final summary

`inputSource` is one of the most important fields in the DS layer.

It turns Project Zeno from a simple execution-layer story into a domain-settlement story.

A domain is not defined only by what code it runs.

It is also defined by where its truth comes from.

The three input-source classes are:

```text
L1_NATIVE = native Zenon inputs
L1_RELAYED = external proof-data posted to Zenon L1
EXTERNAL_OBSERVED = external systems observed by the domain
```

Phase 1 activates only `L1_NATIVE`.

The other two are reserved, but they reveal the larger design direction.

The DS layer is not just multi-runtime.

It is multi-domain.

And domains are defined by both execution and truth.
