# Bitcoin Legibility Through L1_RELAYED

## Purpose

This note explains how Project Zeno’s DS layer could eventually make Bitcoin events legible to Zenon through the reserved `L1_RELAYED` input source.

The core thesis is:

**Bitcoin-facing interoperability begins with Bitcoin legibility, not Bitcoin custody.**

A Bitcoin-facing domain would not make BTC native to Zenon. It would not automatically solve BTC withdrawals. It would not be a complete Bitcoin bridge by itself.

Instead, the first clean research route is a Bitcoin SPV domain that verifies Bitcoin proof-data relayed into Zenon.

This document is explanatory. `SPEC.md` governs on any conflict.

---

## The short version

A future Bitcoin-facing Zeno domain could work like this:

```text id="k0xkiz"
Bitcoin transaction happens
   ↓
Relayer posts Bitcoin headers and Merkle proof to Zenon L1
   ↓
Zenon orders the proof-data
   ↓
Bitcoin SPV domain verifies it
   ↓
Domain updates its internal state
   ↓
Settlement anchors the resulting state root
```

The safe phrase is:

```text id="zscw9j"
Bitcoin legibility, not Bitcoin custody.
```

This means:

```text id="hqsddu"
A Zeno domain could verify that a Bitcoin event happened.
```

It does not mean:

```text id="c5iwbm"
Zenon controls native BTC.
```

That distinction is the entire point of this document.

---

## Why Bitcoin belongs in the input-source discussion

Bitcoin is not primarily a runtime compatibility problem.

The goal is not to run Bitcoin as a general smart-contract VM.

The goal is to verify Bitcoin facts.

That makes Bitcoin an `inputSource` problem.

A Bitcoin-facing domain needs to answer:

```text id="zj82ts"
Can this domain receive Bitcoin proof-data?
Can it verify Bitcoin headers?
Can it verify proof-of-work?
Can it verify chain linkage?
Can it verify confirmation depth?
Can it verify transaction inclusion?
Can it recognize payments to watched outputs?
```

Those are not normal smart-contract runtime questions.

They are external proof-verification questions.

That is why the reserved `L1_RELAYED` input source matters.

---

## What L1_RELAYED means

`L1_RELAYED` means external proof-data is posted to Zenon L1 and then processed by a domain.

For Bitcoin, the proof-data could include:

```text id="gmqa15"
Bitcoin block headers
Merkle proofs
transaction data
confirmation depth
chainwork information
watched output information
```

The important part is that the external proof-data is carried through Zenon L1.

That means Zenon orders the proof-data before the domain processes it.

The relayer does not define truth.

The relayer carries data.

The domain verifies the data.

---

## The Bitcoin SPV domain

The cleanest Bitcoin-facing research route is a **Bitcoin SPV domain**.

SPV stands for Simplified Payment Verification.

In this context, a Bitcoin SPV domain would verify that a Bitcoin transaction was included in a valid Bitcoin block with enough confirmations.

A Bitcoin SPV domain would likely verify:

```text id="ayfuzs"
header format
proof-of-work
header linkage
cumulative chainwork
confirmation depth
Merkle inclusion
transaction output conditions
```

The domain does not need to run a full Bitcoin node inside Zenon.

It does not need to store the entire Bitcoin chain.

It only needs enough proof-data to verify the relevant Bitcoin fact.

The point is not:

```text id="r4zaws"
Zenon becomes Bitcoin.
```

The point is:

```text id="4fxdg2"
A Zeno domain can verify selected Bitcoin events.
```

---

## What the relayer does

A relayer watches Bitcoin and submits proof-data to Zenon L1.

For example, a relayer may submit:

```text id="mw1z13"
a sequence of Bitcoin block headers
a transaction
a Merkle inclusion proof
metadata needed by the domain
```

The relayer is not the trusted bridge.

The relayer is a courier.

If the submitted proof-data is invalid, the Bitcoin SPV domain rejects it.

A dishonest relayer can waste effort by submitting bad data.

A lazy relayer can withhold data.

But if relaying is permissionless, another relayer can submit the needed data.

So the primary relayer risk is usually liveness, not correctness, assuming the domain’s verification logic is sound.

---

## What the executor does

The executor processes the domain’s canonical input stream.

For a Bitcoin SPV domain, the executor would apply the domain’s state-transition function to the relayed Bitcoin proof-data.

The executor may update domain state such as:

```text id="ywoizg"
known Bitcoin header chain
best valid chain tip
confirmed deposit events
watched outputs
credited internal balances
processed Bitcoin transaction IDs
```

The executor computes the result off-chain.

Settlement anchors the resulting state commitment.

In Phase 1-style language:

```text id="50ioi3"
Relayer brings proof-data.
Executor computes the domain state transition.
Settlement anchors the commitment.
```

---

## What Settlement does

Settlement does not verify Bitcoin directly.

Settlement does not become Bitcoin-aware at the base layer.

Settlement does not need to parse every Bitcoin transaction.

Instead, Settlement anchors the state roots and enforces the domain’s aggregate custody boundaries.

For a future Bitcoin SPV domain, Settlement would anchor commitments such as:

```text id="6c4jrk"
preStateRoot
postStateRoot
inputRoot
receiptRoot
eventRoot
outboxRoot
DAHash
```

This preserves the DS layer’s design principle:

```text id="ahxng1"
External logic belongs inside domains, not inside Zenon L1.
```

That is the clean architecture.

Bitcoin verification logic should live in the Bitcoin-facing domain.

Zenon L1 should remain thin.

---

## What this enables

A Bitcoin SPV domain could enable Bitcoin-aware applications on Zenon.

Possible capabilities include:

```text id="x2cu1t"
verifying that a Bitcoin payment happened
verifying deposits to watched Bitcoin outputs
triggering Zeno-domain state changes from Bitcoin events
crediting a wrapped representation after proof verification
building Bitcoin-aware contracts
using Bitcoin events as application inputs
creating proof-based payment acknowledgements
```

The most conservative first capability is:

```text id="ftc3pa"
verify that a Bitcoin transaction was included in a valid Bitcoin chain with enough confirmations
```

That is useful even before solving custody.

It makes Bitcoin events legible to the DS layer.

---

## What this does not enable by itself

A Bitcoin SPV domain does not automatically enable native BTC custody.

It does not automatically release BTC.

It does not automatically solve withdrawals.

It does not make BTC native to Zenon.

It does not remove the need for a custody mechanism if users expect to move value back to Bitcoin.

Unsafe claims:

```text id="vqy3j5"
Project Zeno ships a Bitcoin bridge.
Project Zeno makes BTC native.
Project Zeno can withdraw native BTC trustlessly.
Project Zeno controls Bitcoin.
Project Zeno solves Bitcoin custody with L1_RELAYED alone.
```

Safer versions:

```text id="7xigxd"
Project Zeno identifies a route for Bitcoin proof-data to enter a future domain.
A Bitcoin SPV domain could verify Bitcoin events.
Bitcoin legibility is separate from Bitcoin custody.
Withdrawals require a separate custody or signing mechanism.
```

---

## Deposit verification vs withdrawal custody

Bitcoin interop has two very different sides.

### Deposit verification

Deposit verification asks:

```text id="5wzsmw"
Did a Bitcoin transaction happen?
Was it included in a valid block?
Does it have enough confirmations?
Did it pay a watched output?
```

This is a proof-verification problem.

A Bitcoin SPV domain can plausibly handle this through relayed headers and Merkle proofs.

### Withdrawal custody

Withdrawal custody asks:

```text id="6oa3s5"
Who can spend the native BTC on Bitcoin?
How is a Bitcoin transaction signed?
Who controls the keys?
Can the signing process be minimized, challenged, or made trustless?
```

This is a custody and key-management problem.

It is not solved merely by verifying Bitcoin headers.

Possible withdrawal models could include:

```text id="ajuzb6"
federated custody
threshold signing
custodian-based withdrawal
BitVM-style mechanisms
future covenant-based mechanisms
other external Bitcoin-side constructions
```

Those are separate research tracks.

The DS layer can make Bitcoin events legible.

It does not automatically make Bitcoin spendable by Zenon.

---

## Why not put Bitcoin SPV into Zenon L1?

A tempting idea is to make Zenon L1 itself verify Bitcoin.

That would be the wrong direction for the DS layer.

The DS layer keeps external logic inside domains.

Putting Bitcoin verification directly into Zenon L1 would increase base-layer complexity and make the base protocol responsible for external-chain logic.

The cleaner model is:

```text id="bb4zti"
Zenon L1 orders relayed proof-data.
The Bitcoin SPV domain verifies Bitcoin-specific rules.
Settlement anchors the domain result.
```

That keeps the base layer thin.

It also means future external systems do not each require Zenon L1 to become aware of them.

Bitcoin logic belongs in a Bitcoin-facing domain.

Ethereum logic belongs in an Ethereum-facing domain.

Oracle logic belongs in an observed-input domain.

Settlement stays runtime-agnostic and input-source-aware.

---

## Why this is different from a bridge

A traditional bridge usually tries to move value between two chains.

A Bitcoin SPV domain starts with a narrower goal:

```text id="e1h5uw"
make Bitcoin events verifiable inside a Zeno domain
```

That may later support bridge-like behavior, but it is not a full bridge by itself.

A bridge needs both sides:

```text id="686vcx"
proof that value entered
a representation or accounting system on the target side
a withdrawal/custody system on the origin side
rules for minting, burning, locking, and releasing
```

`L1_RELAYED` helps with the proof that an external event happened.

It does not automatically solve custody.

That is why “Bitcoin legibility” is the safer first concept.

---

## Why this matters for the DS layer

Bitcoin is the clearest example of why the DS layer is more than a multi-VM system.

A multi-VM system asks:

```text id="59fwsx"
Can we run another runtime?
```

A Bitcoin SPV domain asks:

```text id="54vkoz"
Can we settle a domain whose truth comes from external proof-data?
```

That is a much deeper architectural question.

It proves why `inputSource` matters.

Bitcoin is not a runtime to host.

Bitcoin is an external truth system to verify.

That is exactly what `L1_RELAYED` is for.

---

## Relationship to other domains

A future Bitcoin SPV domain could produce outputs that other Zeno domains consume.

For example:

```text id="zeu9ee"
Bitcoin SPV domain verifies BTC deposit
   ↓
SPV domain emits an outbox message
   ↓
Relayer carries that message to a WASM domain
   ↓
WASM domain credits an application-level representation
```

This is internal DS-layer messaging after the Bitcoin event has been verified.

It is not the same as trusting an external bridge.

The Bitcoin event is verified by the Bitcoin-facing domain.

The message between domains is proven against a committed outbox root.

That is the larger architecture:

```text id="n23ijc"
external proof-data enters one domain
verified state updates happen there
other domains consume the result asynchronously
```

---

## Phase status

This research route is not Phase 1 active.

Phase 1 activates:

```text id="z18qiz"
L1_NATIVE inputs
one WASM domain
one bonded executor
on-chain commitments
bounded custody
```

Phase 1 does not activate:

```text id="huqeys"
L1_RELAYED
Bitcoin SPV domains
Bitcoin interoperability
Bitcoin custody
Bitcoin withdrawal mechanisms
external-chain light clients
```

The safe framing is:

```text id="qioe0k"
The spec describes the route for future Bitcoin proof-data through L1_RELAYED, but this route is reserved and not shipping in Phase 1.
```

---

## Research questions

A serious Bitcoin SPV domain would need to answer:

```text id="ivl26z"
What exact Bitcoin header format is accepted?
How is cumulative chainwork computed?
What confirmation depth is required?
How are reorgs handled?
How much header history must the domain retain?
How are watched outputs defined?
How is a Bitcoin transaction bound to a Zeno recipient?
How are duplicate proofs prevented?
How are deposits credited inside the domain?
What is the data-availability requirement for relayed Bitcoin proofs?
What gas cost does Bitcoin proof verification impose?
What withdrawal or custody model is explicitly out of scope?
```

These questions should be answered before any public claim of Bitcoin interoperability.

---

## Best first prototype

The best first prototype is not a bridge.

The best first prototype is:

```text id="51oeo7"
Bitcoin header + Merkle proof verification inside a domain-style state-transition function
```

A minimal prototype would:

```text id="bxbq6a"
accept Bitcoin headers
verify header linkage
verify proof-of-work
track cumulative chainwork
accept a Bitcoin transaction and Merkle proof
verify transaction inclusion
check confirmation depth
emit a verified Bitcoin event
```

This can be studied before the reserved `L1_RELAYED` route is activated.

The prototype should be clearly labeled:

```text id="ki4oqo"
research prototype
not Phase 1 active
not a bridge
not custody
not native BTC
```

---

## What not to claim

Do not claim:

```text id="l49jk7"
Project Zeno ships Bitcoin interoperability
Project Zeno ships a Bitcoin bridge
Project Zeno makes BTC native
Project Zeno can spend native BTC
Project Zeno solves Bitcoin withdrawals
L1_RELAYED is active in Phase 1
Relayers are trusted bridge operators
A Bitcoin SPV domain removes all Bitcoin-side trust assumptions
```

Use the safer versions:

```text id="xejlvh"
Project Zeno identifies a future route for Bitcoin proof-data through L1_RELAYED.
A Bitcoin SPV domain could verify Bitcoin events.
Bitcoin legibility is separate from Bitcoin custody.
Relayers carry proof-data; the domain verifies it.
Withdrawal custody is a separate problem.
L1_RELAYED is reserved, not Phase 1 active.
```

---

## Final summary

A Bitcoin-facing Project Zeno domain should be framed as a proof-verification domain, not a full bridge.

The clean thesis is:

```text id="ik1u1e"
Bitcoin legibility, not Bitcoin custody.
```

`L1_RELAYED` provides the architectural route:

```text id="5lvdoz"
external Bitcoin proof-data
posted to Zenon L1
ordered by Zenon
verified by a Bitcoin SPV domain
anchored by Settlement
```

This could allow Zenon domains to react to verified Bitcoin events.

It does not make BTC native.

It does not solve BTC withdrawals.

It does not ship in Phase 1.

That honesty is what makes the research credible.
