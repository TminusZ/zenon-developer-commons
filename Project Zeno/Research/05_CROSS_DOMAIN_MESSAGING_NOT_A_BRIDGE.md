# Cross-Domain Messaging Is Not a Bridge

## Purpose

This note explains how Project Zeno’s DS layer can support asynchronous messaging between domains that share the same Settlement layer.

The core thesis is:

**Cross-domain messaging inside the DS layer is not the same thing as bridging between external chains.**

A bridge usually connects two separate systems with separate security assumptions.

Cross-domain messaging in Project Zeno connects domains that settle to the same Settlement layer.

That is a different trust model.

This document is explanatory. `SPEC.md` governs on any conflict.

---

## The short version

If two domains settle to the same Settlement layer, they can communicate through committed messages.

The flow is:

```text id="sjo1cn"
Domain A emits a message
   ↓
Domain A batch commits an outboxRoot
   ↓
A relayer proves the message was included
   ↓
Domain B receives the message as input
   ↓
Domain B processes it in a later batch
```

The safe phrase is:

```text id="nkoneu"
Shared settlement changes the bridge problem, but only inside the DS layer.
```

This means:

```text id="jzfynp"
A future WASM domain and EVM domain could communicate under shared Zenon Settlement.
```

It does not mean:

```text id="57xt45"
Project Zeno eliminates all bridges to external chains.
```

External chains remain external.

---

## Why this matters

A major problem in crypto is that separate chains do not naturally trust each other.

If an app on one chain wants to interact with an app on another chain, some bridge, oracle, federation, light client, or proof system must connect them.

That is hard because each chain has its own:

```text id="i6ovbf"
consensus
state
finality
validator set
data availability
custody model
failure modes
```

Project Zeno’s DS layer changes the problem for domains that settle to the same base.

A WASM domain, a future EVM domain, or a future Bitcoin proof domain would not be separate chains with separate settlement layers.

They would be domains anchored by the same Settlement layer.

That shared settlement surface is what makes cross-domain messaging different from external bridging.

---

## What a domain message is

A domain message is an output emitted by one domain that can later be consumed by another domain.

The source domain does not directly execute the target domain.

It emits a message.

That message becomes part of the source domain’s committed outbox.

The committed `outboxRoot` lets others prove the message was actually emitted.

A target domain can later accept the proven message as an input.

In simple terms:

```text id="0nhxt1"
The source domain says something.
Settlement anchors that it said it.
The target domain later hears it and reacts.
```

This is asynchronous.

It is not an instant call.

---

## What outboxRoot does

`outboxRoot` is the commitment to messages emitted by a domain batch.

Instead of storing every message directly in Settlement, the domain commits to a root.

That root lets a relayer later prove that a specific message was included in the source domain’s batch.

The basic pattern is:

```text id="zd8w5h"
many emitted messages
   ↓
committed into an outbox structure
   ↓
outboxRoot included in the batch commitment
   ↓
specific message can later be proven with an inclusion proof
```

This preserves the DS layer’s design principle:

```text id="lc0q6z"
Settlement anchors commitments without becoming the execution environment.
```

Settlement does not need to interpret every message.

It needs to anchor the root that makes the message provable.

---

## What the relayer does

A relayer carries the proven message from one domain to another.

The relayer may provide:

```text id="2m9hm4"
the message
the source domain identifier
the source batch reference
the proof that the message is included in outboxRoot
metadata required by the target domain
```

The relayer is not the trusted bridge.

The relayer is a courier.

If the proof is invalid, the target domain rejects the message.

If the message was never committed, it cannot be proven.

If a relayer withholds the message, another relayer can submit it if relaying is permissionless.

So, assuming proof verification is sound, the relayer mainly affects liveness, not correctness.

---

## Why this is not a traditional bridge

A traditional bridge usually connects two independent chains.

That bridge must answer:

```text id="s0w0wu"
How does Chain B know what happened on Chain A?
Who verifies Chain A?
Who controls locked assets?
Who signs withdrawals?
What happens during reorgs?
What happens if the bridge operator lies?
```

Cross-domain messaging inside the DS layer is different.

Both domains settle to the same Settlement layer.

The source domain’s outbox root is already part of the shared settlement surface.

The target domain does not need to trust an external validator set or bridge federation to know that the source domain emitted a message.

It needs a valid proof against the committed outbox root.

The safe phrase is:

```text id="6soj9q"
This is not bridgeless external-chain interoperability. It is shared-settlement domain messaging.
```

---

## Why this is still not synchronous composability

Cross-domain messaging is not the same as Ethereum-style synchronous contract calls.

A synchronous call means one contract calls another contract during the same execution step and receives the result immediately.

Project Zeno’s DS layer does not require that model.

Instead, the model is asynchronous:

```text id="oxfahq"
emit message now
commit message in a batch
relay proof later
process message in another batch
```

That means a source domain does not block waiting for the target domain to execute.

The target domain reacts later.

This is less immediate than synchronous calls, but it preserves domain isolation.

That is the tradeoff.

The safe phrase is:

```text id="l9uzf3"
Cross-domain messaging is asynchronous, proof-based, and settlement-anchored.
```

The unsafe phrase is:

```text id="zavvzk"
Project Zeno supports synchronous cross-domain composability.
```

It does not.

---

## Why asynchronous messaging fits the DS layer

The DS layer is built around isolated domains.

Each domain may have its own:

```text id="3m8hgw"
runtime
state-transition function
executor policy
input source
state root
data-availability commitments
proof system
```

If domains are isolated, they should not be able to call directly into each other’s execution state.

That would collapse the isolation boundary.

Asynchronous messaging keeps the boundary intact.

A domain can emit a message.

Another domain can consume it later.

But the first domain does not directly execute inside the second domain.

That is cleaner for a multi-domain architecture.

---

## Example: WASM domain to EVM domain

Imagine Phase 1 has a WASM domain, and a future phase adds an EVM domain.

A WASM contract could emit a message intended for the EVM domain.

The flow could look like:

```text id="yq6jh9"
WASM contract emits message
   ↓
WASM domain batch commits outboxRoot
   ↓
Relayer submits message and inclusion proof
   ↓
EVM domain accepts the message as input
   ↓
EVM contract logic reacts in a later batch
```

This would allow communication between different runtimes under shared Settlement.

That is powerful.

But it is not Ethereum interoperability.

It is Zeno-WASM to Zeno-EVM interoperability.

The EVM domain would be a Zeno domain that runs EVM-style execution.

It would not automatically connect to Ethereum L1.

---

## Example: Bitcoin SPV domain to WASM domain

A future Bitcoin SPV domain could verify a Bitcoin event.

Then it could emit an outbox message that another Zeno domain consumes.

The flow could look like:

```text id="s4bwco"
Bitcoin transaction happens
   ↓
Bitcoin proof-data is relayed to Zenon L1
   ↓
Bitcoin SPV domain verifies the event
   ↓
SPV domain emits a verified event message
   ↓
WASM domain consumes the message
   ↓
WASM app reacts to the verified Bitcoin event
```

This shows how external proof-data and internal cross-domain messaging can combine.

First, the Bitcoin-facing domain verifies an external event.

Then, other Zeno domains consume the verified result.

The key distinction:

```text id="ep43fb"
The external Bitcoin proof is handled by the Bitcoin SPV domain.
The internal message is handled by shared Settlement.
```

Those are two different steps.

---

## What this enables

Cross-domain messaging could eventually enable:

```text id="asw9wn"
WASM-to-EVM application messages
EVM-to-WASM contract events
Bitcoin proof-domain outputs consumed by apps
oracle-domain outputs consumed by apps
cross-domain accounting
domain-specific applications that compose asynchronously
runtime-specific domains that still communicate
```

The bigger idea is:

```text id="0ka50d"
Different runtimes can remain isolated but still communicate under shared settlement.
```

That is one of the most important benefits of a DS layer.

---

## What this does not enable by itself

Cross-domain messaging does not automatically enable:

```text id="4hfci5"
external-chain bridging
native BTC withdrawal
Ethereum asset movement
instant synchronous calls
shared global state across all domains
automatic liquidity routing
trustless external-chain custody
```

Those require separate mechanisms.

For Bitcoin, external proof-data and custody are separate problems.

For Ethereum, event verification and asset movement are separate problems.

For cross-domain messaging, the shared-settlement path applies only after the relevant domain exists inside the DS layer.

The safe summary is:

```text id="pazcf2"
Cross-domain messaging helps domains inside the DS layer communicate. It does not magically connect Zenon to every external chain.
```

---

## Internal messages vs external bridges

The distinction can be summarized like this:

```text id="v8wmyz"
Internal DS-layer message:
Domain A and Domain B share Settlement.
A message is proven against Domain A’s committed outboxRoot.
Domain B consumes it later.

External bridge:
Chain A and Chain B have separate settlement layers.
Some mechanism must prove, attest, or custody value across them.
```

Internal messages are easier because the domains share a settlement surface.

External bridges are harder because the systems do not.

This is why Project Zeno can potentially reduce bridge complexity between its own domains while still needing serious proof or custody systems for outside chains.

---

## The role of Settlement

Settlement is the common anchor.

It does not execute the source domain’s logic.

It does not execute the target domain’s logic.

It anchors the commitments that make messages provable.

Settlement records the batch commitment that includes the source domain’s `outboxRoot`.

The target domain can then rely on the proof that a message was emitted by the source domain.

This preserves a clean division:

```text id="u7q2f6"
Source domain emits.
Settlement anchors.
Relayer carries proof.
Target domain consumes.
```

Each component has one job.

---

## The role of proofs

The proof is what prevents the relayer from becoming trusted.

The target domain should not accept a relayer’s word.

It should accept a message only if the relayer provides a valid proof that the message was included in the source domain’s committed outbox.

That means the trust assumption is not:

```text id="ox7pqz"
trust the relayer
```

It is:

```text id="7p64yy"
verify the proof against the committed root
```

This is why outbox roots matter.

They turn messages into verifiable objects.

---

## Replay protection

Cross-domain messaging also needs replay protection.

A valid message should not be consumed twice.

The target domain needs a way to track which messages have already been processed.

The general idea is:

```text id="ehh6z7"
message emitted once
message proven once
message consumed once
duplicates rejected
```

Replay protection is what prevents a relayer from reusing the same valid proof over and over.

This is a normal requirement for message-passing systems.

---

## Ordering and delay

Cross-domain messaging is naturally delayed.

A message must be emitted, committed, proven, relayed, and processed.

That means cross-domain interaction happens over multiple batches.

This has important consequences:

```text id="eqwtqb"
apps must be designed for delayed finality
contracts cannot assume instant responses
cross-domain workflows need callbacks or later-state handling
liquidity routing may require waiting periods
user interfaces must explain pending states
```

This is not a bug.

It is the cost of keeping domains isolated.

---

## Why this matters for future EVM domains

A future EVM domain becomes much more interesting if it can communicate with other Zeno domains.

Without cross-domain messaging, an EVM domain would mostly be a separate execution island.

With cross-domain messaging, an EVM domain could:

```text id="z28xzp"
receive verified events from a Bitcoin SPV domain
send messages to a WASM domain
consume oracle-domain outputs
coordinate with application-specific domains
participate in DS-layer routing
```

This is the powerful version of runtime compatibility.

Not:

```text id="mvj4bz"
EVM means Ethereum comes to Zenon.
```

But:

```text id="ugwr8l"
EVM-style execution can become one domain inside a larger settlement fabric.
```

That is a much better claim.

---

## Why this matters for Bitcoin domains

A Bitcoin SPV domain becomes more useful if its verified outputs can be consumed by other domains.

The SPV domain verifies Bitcoin facts.

Other domains use those facts.

That means the Bitcoin-facing domain does not need to be every application at once.

It can be a specialized truth domain.

Then WASM, EVM, or application-specific domains can consume its outputs.

This is the DS layer pattern:

```text id="rz0fcv"
specialized domains verify or compute specific things
shared Settlement anchors their commitments
other domains consume their outputs asynchronously
```

That is broader than a normal bridge.

---

## Phase status

This research route has an important caveat.

Phase 1 has one active domain.

That means there is no live cross-domain messaging yet because there is no second active domain.

Phase 1 can still define asynchronous messaging patterns within the active domain, but cross-domain messaging requires multiple domains.

Phase 1 activates:

```text id="s3g1yl"
one WASM domain
L1_NATIVE inputs
one bonded executor
outbox-style asynchronous messaging
settlement commitments
```

Phase 1 does not activate:

```text id="9xvv3x"
multiple domains
future EVM domain
Bitcoin SPV domain
cross-domain messaging between separate active domains
synchronous composability
external-chain bridge elimination
```

The safe framing is:

```text id="zw9p9r"
The DS layer defines the path for asynchronous cross-domain messaging, but Phase 1 activates only one domain.
```

---

## Research questions

A serious cross-domain messaging design should answer:

```text id="a4meaz"
How is an outbox message encoded?
How is outboxRoot computed?
How is message inclusion proven?
How does the target domain verify the proof?
How is replay protection enforced?
How are failed message deliveries handled?
How are message fees or relayer incentives handled?
How are messages ordered when multiple batches are involved?
How are cross-domain dependencies represented in app logic?
How does a user interface display pending cross-domain actions?
How does messaging interact with withdrawal delays and value caps?
How does messaging change under fraud-proof or validity-proof phases?
```

These questions should be answered before claiming full cross-domain composability.

---

## What not to claim

Do not claim:

```text id="thszib"
Project Zeno eliminates all bridges
Project Zeno supports synchronous cross-domain composability
Project Zeno can bridge Ethereum assets through outbox messages alone
Project Zeno can withdraw native BTC through cross-domain messaging
Project Zeno has live cross-domain messaging in Phase 1
Relayers are trusted bridges
All domains share one global state
```

Use the safer versions:

```text id="iek6jl"
Domains that share Settlement can communicate asynchronously through committed messages.
Cross-domain messaging is proof-based, not relayer-trusted.
Shared settlement changes the bridge problem inside the DS layer.
External-chain bridging still requires separate proof, custody, or light-client mechanisms.
Phase 1 activates one domain, so cross-domain messaging is a future multi-domain capability.
```

---

## Final summary

Cross-domain messaging is one of the most important future capabilities of the DS layer.

The clean thesis is:

```text id="o4hhxh"
Domains that share Settlement can communicate through asynchronous, proof-based messages.
```

That is not the same as an external-chain bridge.

It is not synchronous composability.

It does not eliminate the hard problems of Bitcoin or Ethereum custody.

But it does create a powerful internal architecture:

```text id="6ibugz"
different runtimes
different input sources
different domain roles
one shared settlement surface
asynchronous messages between domains
```

That is the DS layer pattern.

Shared settlement changes the bridge problem, but only inside the DS layer.
