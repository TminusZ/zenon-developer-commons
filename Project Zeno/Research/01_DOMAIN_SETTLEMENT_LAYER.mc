# Project Zeno Domain Settlement Layer

## Purpose

This note explains the core architectural reframe behind Project Zeno:

**Project Zeno is not a WASM layer. It is a Domain Settlement Layer.**

For short, these research notes call it the **DS layer**.

The name has two meanings:

```text
DS = Domain Settlement
DS = a nod to DigitalSloth, the developer who assisted in formalizing this architecture
```

This document is explanatory. `SPEC.md` governs on any conflict.

---

## The core reframe

The first mistake is to describe Project Zeno as a WASM smart-contract layer.

That is too small.

WASM is the first runtime. It is not the architecture.

The architecture is the **Domain Settlement Layer**: a runtime-agnostic settlement system where isolated execution domains can be registered, executed off-chain, and anchored back to Zenon through ordered inputs, state commitments, custody rules, withdrawal limits, and future proof hooks.

In simple terms:

```text
Settlement is the platform.
Domains are tenants.
WASM is the first tenant.
```

Project Zeno does not make Zenon into one giant VM.

It makes Zenon a settlement base for domains.

---

## Why “Domain Settlement Layer”?

The phrase matters because each word does work.

A **domain** is an isolated execution environment. It can have its own runtime, input source, state-transition rules, executor policy, state root, outbox, data-availability commitments, and custody limits.

A **settlement** layer is the common base where domains anchor commitments and where aggregate custody rules are enforced.

A **layer** sits between Zenon L1 and off-chain execution. Zenon L1 provides ordering, inclusion, feeless access, and base settlement. Domains provide execution and application logic.

The DS layer connects those pieces without turning Zenon L1 into a monolithic smart-contract VM.

---

## What is a domain?

A Project Zeno domain is an isolated execution environment that settles to Zenon.

A domain defines:

```text
runtimeKind
inputSource
stfSpecHash
executor set
proposerPolicy
state roots
outboxRoot
eventRoot
receiptRoot
DAHash
valueCaps
withdrawal rules
future proof hooks
```

These fields matter because they show the spec is not merely adding a contract VM.

It is defining a general framework for execution domains.

A virtual machine answers:

```text
What code can run?
```

A domain answers:

```text
What code can run?
Where do its inputs come from?
Who executes it?
What state transition is valid?
What assets can it control?
What roots does it commit?
How does it message other domains?
How can it be verified later?
```

That is why “WASM layer” is not enough.

WASM is one possible runtime inside one domain.

The domain is the actual unit of the system.

---

## The shortest definition

Project Zeno’s DS layer is:

```text
a runtime-agnostic settlement layer for off-chain execution domains
```

Or shorter:

```text
a Domain Settlement Layer
```

The clean public sentence is:

```text
Project Zeno is not a WASM layer. It is a Domain Settlement Layer. WASM is the first domain.
```

The clean technical sentence is:

```text
Project Zeno registers isolated execution domains whose runtimes, input sources, state-transition rules, executor policies, custody limits, data-availability commitments, outbox roots, and state roots are anchored by Zenon Settlement.
```

---

## The two axes of a domain

The most important design idea is that a domain has two separate axes:

```text
runtimeKind = what executes
inputSource = where truth comes from
```

Most people will notice `runtimeKind` first because it points toward multiple runtimes.

That is the obvious part.

But `inputSource` is the deeper part.

It means Project Zeno is not only asking:

```text
What virtual machine can run?
```

It is also asking:

```text
Where does this domain receive truth from?
```

That is what turns Project Zeno from a smart-contract layer into a Domain Settlement Layer.

---

## runtimeKind: what executes

`runtimeKind` defines what execution environment a domain uses.

Phase 1 activates:

```text
WASM
```

Future runtimes could theoretically include:

```text
EVM
Move
SVM
Cairo
zkVMs
domain-specific runtimes
```

But those are not Phase 1 deliverables.

The safe claim is:

```text
The DS layer is runtime-agnostic by design, but Phase 1 activates one runtime: WASM.
```

The unsafe claim is:

```text
Project Zeno ships multiple VMs.
```

It does not.

The schema points toward a multi-runtime future. The implementation begins with one runtime.

---

## inputSource: where truth comes from

`inputSource` defines where a domain’s canonical inputs come from.

The spec identifies three input-source classes:

```text
L1_NATIVE
L1_RELAYED
EXTERNAL_OBSERVED
```

Only `L1_NATIVE` is active in Phase 1.

The other two are reserved.

---

## L1_NATIVE

`L1_NATIVE` means the domain receives inputs directly from Zenon L1.

This is the Phase 1 model.

A user submits a call or deposit through Zenon. Zenon orders it. The executor processes it. Settlement anchors the resulting state commitment.

The flow looks like this:

```text
User input
   ↓
Zenon L1 ordering
   ↓
Domain executor
   ↓
State transition
   ↓
Settlement commitment
```

This is the first safe slice of the DS layer.

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
```

For Bitcoin, the model would look like this:

```text
Bitcoin event happens
   ↓
Relayer posts headers and proofs to Zenon L1
   ↓
Zenon orders that proof-data
   ↓
Bitcoin SPV domain verifies it
   ↓
Settlement anchors the resulting state root
```

This does not make Bitcoin native to Zenon.

It makes Bitcoin legible to a Zeno domain.

The safe claim is:

```text
The DS layer identifies a route for Bitcoin proof-data to enter Zenon through L1_RELAYED.
```

The unsafe claim is:

```text
Project Zeno ships a Bitcoin bridge.
```

It does not.

A Bitcoin SPV domain could verify that a Bitcoin transaction happened. It would not, by itself, solve native BTC custody or withdrawal.

The clean phrase is:

```text
Bitcoin legibility, not Bitcoin custody.
```

---

## EXTERNAL_OBSERVED

`EXTERNAL_OBSERVED` means the executor observes some external system directly rather than relying on data posted to Zenon L1.

This could eventually point toward:

```text
oracle-like domains
external market data
proof-of-reserve observations
off-chain service reports
other externally observed systems
```

But this model has weaker data-availability assumptions than `L1_RELAYED`, because the input data is not necessarily carried by Zenon L1 itself.

This is reserved.

The safe claim is:

```text
The DS layer reserves an input-source class for externally observed systems.
```

The unsafe claim is:

```text
Project Zeno ships oracle domains.
```

It does not.

---

## Why inputSource is the hidden gem

`runtimeKind` tells you what kind of machine runs.

`inputSource` tells you what kind of truth enters.

That is the more original idea.

A normal smart-contract platform is mostly concerned with execution.

The DS layer is concerned with settlement of domains that may receive different kinds of inputs.

That means the design space includes:

```text
native Zenon applications
future EVM-style domains
Bitcoin proof domains
external event verification domains
oracle-like observed domains
cross-domain message domains
data-availability and proof-serving domains
```

The DS layer is not just multi-VM.

It is multi-domain.

And domains are defined by both execution and truth.

---

## What Settlement does

Settlement is not a VM.

Settlement is the anchor.

It records commitments such as:

```text
preStateRoot
postStateRoot
inputRoot
receiptRoot
eventRoot
outboxRoot
DAHash
```

It enforces aggregate custody and conservation.

It applies withdrawal delays and value caps.

It isolates domains by `domainId`.

It provides the surface future fraud proofs and validity proofs can target.

Settlement does not need to know every contract detail. It needs to know whether the domain’s aggregate commitments and custody movements obey the rules.

In plain English:

```text
Execution happens off-chain.
State roots settle on-chain.
Custody is bounded on-chain.
Per-account correctness is strengthened in later proof phases.
```

That is the DS layer.

---

## Execution is not custody

One of the most important design separations is this:

```text
Executors compute.
Settlement custodies.
```

The executor advances the domain state.

Settlement enforces that a domain cannot withdraw more than it has received in aggregate.

That means Phase 1 does not prove every per-account balance on-chain, but it does prevent aggregate over-withdrawal.

This is why the trust model must be stated honestly.

Phase 1 is:

```text
bonded attestation
aggregate custody enforcement
public commitments
withdrawal delays
value caps
```

Phase 1 is not:

```text
trustless execution
fraud-proof enforcement
validity-proof enforcement
permissionless executor sets
```

The DS layer is designed so those stronger phases can be added later without redefining the whole system.

---

## Balance-blind settlement

Settlement does not maintain a per-account ledger for every user inside every domain.

Instead, it tracks aggregate custody per domain and asset.

Per-account balances live inside the domain’s state.

That is why Settlement is balance-blind.

It can enforce:

```text
this domain cannot withdraw more of this asset than it has received
```

But Phase 1 does not enforce:

```text
this individual user’s internal balance is correct
```

That comes from executor honesty in Phase 1, and from stronger proof systems later.

This is not a flaw.

It is the core scaling move.

Settlement stays thin.

Domains carry their own state.

---

## Why the DS layer is different

A normal smart-contract layer usually puts execution directly into the chain.

The DS layer keeps Zenon L1 thin.

Zenon L1 provides:

```text
ordering
inclusion
feeless access
momentum finality
base settlement
```

Domains provide:

```text
execution
state transitions
application logic
runtime-specific behavior
contract state
```

Settlement provides:

```text
commitments
custody boundaries
withdrawal delays
caps
domain isolation
future proof targets
```

That is a different architecture from “add smart contracts to L1.”

Zenon does not become Ethereum.

Zenon becomes the settlement base for domains.

---

## Phase 1: the first safe slice

Phase 1 activates the smallest safe version of the DS layer.

It includes:

```text
one WASM domain
L1_NATIVE inputs
one bonded executor
off-chain execution
on-chain batch commitments
aggregate custody checks
withdrawal delays
value caps
asynchronous outbox messaging
data-availability commitments
browser-checkable settlement floor
```

Phase 1 does not include:

```text
multiple runtimes
public domain creation
permissionless executor sets
fraud proofs
validity proofs
Bitcoin interoperability
Ethereum interoperability
oracle domains
Sentinel service markets
QSR collateral assignment
synchronous contract calls
```

The correct framing is:

```text
Phase 1 ships the first safe slice of the Domain Settlement Layer.
```

That sentence lets the project show ambition without misrepresenting what is live.

---

## Future runtime domains

Because Settlement is runtime-agnostic, future runtimes do not need to become Zenon L1.

They can become domains.

A future EVM domain would not make Zenon Ethereum.

It would mean:

```text
EVM-style execution settles to Zenon
Solidity tooling may become reusable
EVM contracts could communicate with other Zeno domains asynchronously
custody and commitments remain under Zeno Settlement
```

But it would not automatically bring:

```text
Ethereum assets
Ethereum liquidity
Ethereum users
Ethereum security
Ethereum finality
```

Those require separate bridges, proofs, relayers, or custody systems.

The safe claim is:

```text
A future EVM domain could provide runtime and tooling compatibility.
```

The unsafe claim is:

```text
A future EVM domain automatically gives Ethereum interoperability.
```

Runtime compatibility is not asset interoperability.

---

## Future external proof domains

Because the DS layer separates runtime from input source, future domains can also be designed around external proof-data.

Bitcoin is the clearest example.

A Bitcoin SPV domain would not be about running Bitcoin scripts as a general smart-contract VM.

It would be about verifying Bitcoin facts:

```text
valid block headers
proof-of-work
chain linkage
confirmation depth
transaction inclusion
payment to watched outputs
```

That is not runtime compatibility.

It is external truth verification.

This is why the two-axis model matters.

An EVM domain and a Bitcoin SPV domain are both domains, but they exist for different reasons.

One is about compatible execution.

The other is about verified external input.

---

## Relayers in the DS layer

A relayer brings external or cross-domain data into the system.

A relayer may provide:

```text
Bitcoin headers
Merkle proofs
Ethereum event proofs
cross-domain outbox proofs
DA bundle references
external-chain state proofs
```

The relayer does not need to be trusted if the domain verifies the proof-data itself.

A dishonest relayer can submit garbage, but the state-transition function rejects it.

A lazy relayer can withhold data, but relaying can be permissionless.

So the main relayer risk is usually liveness, not correctness, assuming the proof verification logic is sound.

This is one of the most important future service roles created by the DS layer.

---

## Cross-domain messaging

If multiple domains settle to the same Settlement layer, they can communicate through committed outbox messages.

That is different from a traditional bridge.

A bridge between two separate chains usually requires an external trust assumption.

But two Zeno domains share the same Settlement surface.

A message from one domain can be proven against its committed `outboxRoot` and relayed into another domain.

This is still asynchronous.

It is not synchronous composability.

The safe claim is:

```text
The DS layer creates a path for asynchronous cross-domain messaging under shared settlement.
```

The unsafe claim is:

```text
The DS layer eliminates all bridges.
```

It only changes the bridge problem between domains that already share Settlement.

External chains remain external.

---

## Sentinels and the DS layer

The DS layer creates many possible infrastructure-service roles:

```text
executors
watchers
relayers
proof servers
DA bundle servers
oracle reporters
Bitcoin header relayers
liquidity routers
fraud-proof challengers
```

These roles fit the spirit of Zenon’s Sentinel concept.

However, the spec does not currently assign all of these jobs to Sentinels.

The safe claim is:

```text
The DS layer creates future infrastructure-service roles that may fit Sentinels.
```

The unsafe claim is:

```text
Sentinels are officially assigned to run all DS layer services.
```

That is not a Phase 1 claim.

---

## Why this honors DigitalSloth

The name **DS layer** is fitting because the architecture did not merely add WASM to Zenon.

It formalized the place where execution belongs.

A normal WASM-layer design could have tried to bolt a VM onto Zenon.

This design instead separated:

```text
execution from settlement
runtime from input source
custody from contract state
commitments from full state
internal messaging from external bridging
Phase 1 attestation from future proof verification
```

That is the contribution.

It turns a simple smart-contract request into a generalized settlement architecture.

So **DS layer** can stand for **Domain Settlement Layer**, while also honoring the developer who made that architecture legible.

The name is respectful because it describes the design, not just the person.

---

## What not to claim

Do not claim:

```text
Project Zeno ships multiple domains
Project Zeno ships multiple VMs
Project Zeno ships Bitcoin interoperability
Project Zeno ships Ethereum interoperability
Project Zeno ships oracle domains
Project Zeno is trustless in Phase 1
Project Zeno eliminates all bridges
Project Zeno makes BTC native
Sentinels are officially assigned to DS services
QSR is confirmed as collateral
```

Use the safer versions:

```text
The schema is domain-oriented; Phase 1 activates one WASM domain.
The architecture reserves routes for external proof-data and observed systems.
Bitcoin legibility is described, not shipped.
Future EVM domains could provide runtime/tooling compatibility, not automatic Ethereum liquidity.
Sentinel service markets are a natural research direction, not a Phase 1 assignment.
Phase 1 is bonded attestation with bounded custody, not trustless execution.
```

---

## Final summary

Project Zeno is best understood as a **Domain Settlement Layer**.

The DS layer separates:

```text
execution from settlement
runtime from input source
state from commitments
custody from contract logic
domain messaging from external bridging
Phase 1 attestation from future proof enforcement
```

That separation is the architecture.

WASM is where it begins.

The DS layer is what it is.
