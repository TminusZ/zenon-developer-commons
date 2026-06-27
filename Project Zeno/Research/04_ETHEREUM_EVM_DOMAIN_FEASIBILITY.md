# Ethereum and EVM Domain Feasibility

## Purpose

This note explains what Ethereum-facing compatibility could mean inside Project Zeno’s DS layer.

The core thesis is:

**A future EVM domain could provide runtime and tooling compatibility, but it would not automatically provide Ethereum asset, liquidity, finality, or security interoperability.**

The safe phrase is:

```text id="xm2q7q"
Runtime compatibility is not asset interoperability.
```

This document is explanatory. `SPEC.md` governs on any conflict.

---

## The short version

A future EVM domain would mean:

```text id="c2m1au"
EVM-style execution settles to Zenon.
Solidity-style contracts may become portable.
Ethereum tooling patterns may be reusable.
EVM contracts could communicate asynchronously with other Zeno domains.
```

It would not automatically mean:

```text id="p5tb3x"
Ethereum assets move to Zenon
Ethereum liquidity appears on Zenon
Ethereum users migrate to Zenon
Ethereum finality is available inside Zenon
Ethereum security is inherited by Zenon
Ethereum rollups can be copied unchanged
```

An EVM domain would be a **Zeno-settled EVM environment**, not Ethereum itself.

That distinction matters.

---

## Why this belongs in the DS layer discussion

The DS layer separates two major questions:

```text id="ffn6dt"
runtimeKind = what executes
inputSource = where truth comes from
```

Ethereum-facing research touches both, but they are separate.

An EVM domain is mostly a `runtimeKind` question:

```text id="wzrt2s"
Can Ethereum-style execution run as a Zeno domain?
```

Ethereum event verification is an `inputSource` question:

```text id="jro4c8"
Can Ethereum events or state proofs be relayed into a Zeno domain and verified?
```

Those are different research tracks.

Confusing them leads to bad claims.

Running an EVM does not mean reading Ethereum.

Reading Ethereum does not mean moving Ethereum assets.

Moving Ethereum assets does not mean inheriting Ethereum security.

Each of those requires a different mechanism.

---

## EVM does not mean Ethereum

The Ethereum Virtual Machine is an execution environment.

Ethereum is a full network with consensus, validators, finality, state, assets, liquidity, bridges, tooling, RPC standards, wallets, and social adoption.

A future Zeno EVM domain could potentially reuse parts of the Ethereum execution stack.

But it would not automatically reuse Ethereum itself.

In simple terms:

```text id="spzrwn"
EVM = execution format
Ethereum = chain, state, users, assets, liquidity, and security
```

A Zeno EVM domain could provide the first.

It would not automatically provide the second.

---

## What an EVM domain could mean

A future EVM domain would be an execution domain that uses EVM-style rules.

It would likely define:

```text id="ldm9j8"
runtimeKind = EVM
inputSource = L1_NATIVE, at least initially
stfSpecHash = pinned EVM transition rules
executor set = who computes the domain
state roots = EVM-domain state commitments
outboxRoot = messages emitted from the EVM domain
DAHash = data-availability commitment
valueCaps = custody risk limits
```

The executor would process EVM-style transactions off-chain.

Settlement would anchor the resulting domain commitments.

The domain would settle to Zenon, not Ethereum.

The flow would look like this:

```text id="1fe6sn"
User submits EVM-domain input through Zenon
   ↓
Zenon orders the input
   ↓
EVM-domain executor processes it
   ↓
EVM-domain state changes
   ↓
Settlement anchors the new state root
```

This is runtime compatibility under Zeno settlement.

---

## What EVM compatibility could enable

A future EVM domain could make several Ethereum-style development patterns available inside the DS layer.

Possible benefits:

```text id="d1fawe"
Solidity-style contract portability
EVM bytecode compatibility
ABI-style tooling
Ethereum-like developer workflows
familiar wallet and RPC patterns
reuse of EVM developer knowledge
integration with other Zeno domains through asynchronous messaging
```

The most marketable safe claim is:

```text id="3b0he2"
A future EVM domain could let Ethereum-style applications settle to Zenon.
```

That is different from saying:

```text id="7kzrgv"
Ethereum itself comes to Zenon.
```

It does not.

---

## What EVM compatibility does not enable by itself

A future EVM domain would not automatically provide:

```text id="daej3s"
Ethereum asset interoperability
Ethereum liquidity interoperability
Ethereum security inheritance
Ethereum finality verification
Ethereum L1 state access
Ethereum L2 state access
automatic bridge functionality
automatic rollup portability
```

Those require separate mechanisms.

For example:

To read Ethereum events, a Zeno domain would need something like:

```text id="9bsi60"
Ethereum headers
receipts
logs
state proofs
finality proofs
```

Those belong to an external-input route, not merely an EVM runtime.

To move Ethereum assets, a system would need:

```text id="zy7w6d"
custody
bridging
locking and minting
burning and releasing
proof verification
or another asset representation model
```

Those are not solved by running EVM code.

---

## Runtime compatibility vs asset interoperability

This distinction is the heart of the document.

Runtime compatibility means:

```text id="u2b0zy"
similar code can run
similar tools can be used
similar contract patterns can be ported
```

Asset interoperability means:

```text id="hvn6xh"
value from another chain can be represented, moved, redeemed, or settled across systems
```

An EVM domain may give runtime compatibility.

It does not automatically give asset interoperability.

The safe phrase is:

```text id="chhmdu"
Running EVM gives you Ethereum-style execution, not Ethereum’s assets.
```

---

## Runtime compatibility vs liquidity interoperability

Liquidity is not code.

Liquidity is users, assets, market makers, bridges, trust, incentives, and routing.

A future EVM domain could make it easier for Ethereum builders to understand the environment.

It could make it easier to port contracts.

It could make it easier to reuse tooling.

But it would not cause liquidity to appear.

Unsafe claim:

```text id="eflvwe"
If Zeno runs EVM, Ethereum liquidity comes with it.
```

Safer claim:

```text id="x7n4cg"
A future EVM domain could reduce developer friction, but liquidity would require separate asset, bridge, and incentive infrastructure.
```

---

## Runtime compatibility vs security inheritance

A Zeno-settled EVM domain would settle to Zenon.

That means it would inherit the security model of the DS layer, not Ethereum.

In Phase 1 terms, that means:

```text id="6atvoh"
bonded attestation
public commitments
aggregate custody checks
withdrawal delays
value caps
```

Future phases may add:

```text id="p8w8ne"
fraud proofs
validity proofs
permissionless executor sets
stronger verification
```

But it would not inherit Ethereum security merely because it runs EVM-style code.

Unsafe claim:

```text id="ogvi4t"
A Zeno EVM domain inherits Ethereum security.
```

Safer claim:

```text id="opqsvr"
A Zeno EVM domain would run Ethereum-style execution under Zeno settlement assumptions.
```

---

## What “forking an Ethereum chain” really means

The phrase “fork an Ethereum chain onto Zeno” is too vague.

It can mean several different things.

### Forking the runtime

This means reusing the EVM execution engine or EVM-compatible semantics.

This is the most realistic meaning.

A future EVM domain would be this kind of fork.

It gives:

```text id="ibfop2"
runtime compatibility
tooling familiarity
contract portability
```

It does not give:

```text id="ks61eb"
Ethereum state
Ethereum liquidity
Ethereum finality
Ethereum custody
Ethereum security
```

### Forking a rollup stack

A rollup stack includes more than execution.

It may include:

```text id="dtpaz8"
sequencer
batcher
bridge contracts
proof system
data availability assumptions
settlement contract
fraud-proof or validity-proof machinery
withdrawal rules
```

Porting a rollup stack to Zeno would require replacing much of that machinery with the DS layer model.

Zenon provides ordering and settlement differently than Ethereum.

So this is not a simple copy-paste.

### Forking an app ecosystem

A deployed Ethereum app has more than code.

It has:

```text id="0u06im"
users
liquidity
token balances
integrations
oracles
frontends
market expectations
```

A Zeno EVM domain could potentially run similar code.

It would not automatically bring the live Ethereum ecosystem with it.

### Forking a bridge

A bridge is its own system.

It deals with custody, proofs, locking, minting, burning, releasing, and withdrawal trust assumptions.

An EVM domain does not automatically include a bridge.

Asset movement is a separate research track.

---

## Ethereum rollups and the DS layer

Ethereum rollups are useful references, but they cannot be assumed to port unchanged.

A rollup normally depends on Ethereum for some combination of:

```text id="vc1ajf"
settlement
data availability
bridge custody
proof verification
withdrawal finality
sequencer rules
```

A Zeno-settled domain would replace those assumptions with DS layer assumptions.

That means the question is not:

```text id="al67f9"
Can we copy an Ethereum rollup onto Zeno unchanged?
```

The better question is:

```text id="3egahc"
Which parts of an Ethereum rollup stack are reusable inside a Zeno domain, and which parts must be replaced by DS layer components?
```

The likely answer:

```text id="0wcaea"
Reusable: runtime ideas, contract tooling, some execution logic, proof-system design references.
Replace: settlement, bridge, DA assumptions, sequencer role, withdrawal logic, security model.
```

---

## OP Stack, Arbitrum, and zkEVMs as references

Ethereum rollup stacks are still valuable research material.

They can teach:

```text id="jh92fl"
how EVM execution is structured
how batch commitments are built
how fraud proofs are designed
how validity proofs are integrated
how bridges handle deposits and withdrawals
how sequencer censorship is handled
how data availability is exposed
```

But in the DS layer, the architecture is different.

Zenon L1 already provides canonical ordering for native inputs.

Settlement anchors domains.

Executors compute off-chain.

Future watchers and proof systems challenge or verify execution.

So Ethereum rollups are useful as reference designs, not drop-in solutions.

---

## Ethereum event interoperability

If Project Zeno wants to read Ethereum itself, an EVM domain is not enough.

Ethereum event interoperability would require a domain to process Ethereum proof-data or observations.

Possible input routes:

```text id="e4lkmw"
L1_RELAYED = Ethereum proof-data posted to Zenon L1
EXTERNAL_OBSERVED = Ethereum or L2 state observed directly by an executor
```

A relayed Ethereum route could involve:

```text id="vzrqmd"
headers
finality proofs
receipt proofs
event logs
storage proofs
rollup output roots
```

This is harder than the basic EVM-domain story.

It requires Ethereum-specific verification rules.

That means Ethereum event interoperability is an input-source problem, not a runtime problem.

---

## Ethereum assets and bridges

Moving Ethereum assets into a Zeno domain is a separate problem.

It would require a bridge or asset representation model.

A complete asset bridge usually needs:

```text id="1g4eiu"
proof of deposit or lock on Ethereum
minting or crediting a representation on Zeno
burning or locking on Zeno
withdrawal or release back on Ethereum
custody or proof-based control of the origin asset
clear failure and challenge rules
```

An EVM domain could host the accounting side.

It could perhaps receive a verified Ethereum deposit event.

But it does not automatically control the Ethereum-side asset.

That is why this note keeps returning to the same point:

```text id="te8ntv"
Runtime compatibility is not asset interoperability.
```

---

## Internal EVM-to-WASM interoperability

A future EVM domain could become powerful inside the DS layer even without Ethereum asset interoperability.

If a Zeno EVM domain and a Zeno WASM domain both settle to the same Settlement layer, they could communicate asynchronously through committed messages.

For example:

```text id="zo1xew"
EVM domain emits an outbox message
   ↓
Message is proven against the EVM domain’s outboxRoot
   ↓
Relayer delivers it to the WASM domain
   ↓
WASM domain processes it as an input
```

This is not Ethereum interoperability.

It is DS-layer internal interoperability.

That is still valuable.

It means different runtimes could communicate under shared Zenon settlement.

The safe claim is:

```text id="yh8x9b"
A future EVM domain could compose asynchronously with native Zeno domains under shared Settlement.
```

The unsafe claim is:

```text id="rfdrrq"
An EVM domain automatically bridges Ethereum to Zenon.
```

---

## The best first Ethereum-facing research route

The best first Ethereum-facing research route is not a bridge.

It is an **EVM domain feasibility study**.

That study should answer:

```text id="ywpddx"
What exact EVM version would be targeted?
How would EVM gas map to the DS layer?
How would EVM accounts and nonces map to domain state?
How would EVM storage map to the DS layer SMT?
How would EVM transactions enter through Zenon L1?
How would contract events map to eventRoot?
How would cross-domain messages map to outboxRoot?
How would deposits and withdrawals map to aggregate custody?
What would stfSpecHash pin?
What would a future fraud-proof adapter need?
What tooling could be reused?
What tooling would need to be rewritten?
```

That is the right next step.

Not:

```text id="3w16nm"
claiming Ethereum interoperability
claiming liquidity migration
claiming rollup portability
claiming Ethereum security
```

The first serious artifact should define exactly what an EVM domain would be.

---

## Classification of Ethereum-facing possibilities

### 1. Future EVM domain

Status:

```text id="mamf9l"
reserved / future
```

What it gives:

```text id="9ax3f9"
runtime compatibility
tooling compatibility
Ethereum-style contract execution
potential internal DS-layer messaging with other domains
```

What it does not give:

```text id="592qx0"
Ethereum assets
Ethereum liquidity
Ethereum security
Ethereum finality
Ethereum state access
```

### 2. Ethereum event relay domain

Status:

```text id="6pc0sb"
reserved / future
```

What it gives:

```text id="ucefff"
event interoperability
proof-based reads from Ethereum or Ethereum L2s
```

What it does not give:

```text id="c9b0nr"
automatic asset movement
automatic liquidity
automatic settlement to Ethereum
```

### 3. Ethereum bridge or asset representation

Status:

```text id="2iz5ge"
separate future research
```

What it gives:

```text id="c0mjhf"
possible asset interoperability
```

What it requires:

```text id="kik3lc"
custody model
proof model
mint/burn or lock/release rules
withdrawal rules
risk limits
```

### 4. Rollup-stack adaptation

Status:

```text id="vxj41t"
future feasibility study
```

What it gives:

```text id="bdvn59"
possible reuse of execution and proof-system ideas
```

What must change:

```text id="a1ffxj"
settlement assumptions
DA assumptions
sequencing assumptions
bridge assumptions
withdrawal assumptions
```

---

## The console analogy

A tempting analogy is:

```text id="kxcqko"
hacking an Xbox to play PlayStation games
```

That is close, but not quite right.

It suggests the host system simply runs another system’s games and gets its whole library.

A better analogy is:

```text id="i0a7v1"
Project Zeno is a settlement dock where different runtime cartridges can be adapted to run, but each cartridge settles to Zenon and does not bring the original chain’s assets, users, or security with it.
```

Even that analogy needs a caveat.

The runtime may be portable.

The ecosystem is not.

The safest framing is:

```text id="yn1e2c"
Zeno can potentially host Ethereum-style execution. It does not become Ethereum.
```

---

## Phase status

This research route is not Phase 1 active.

Phase 1 activates:

```text id="kmdk78"
one WASM domain
L1_NATIVE inputs
one bonded executor
on-chain commitments
bounded custody
```

Phase 1 does not activate:

```text id="ir3fbo"
EVM runtime domains
Ethereum relayed inputs
Ethereum event verification
Ethereum bridges
Ethereum asset interoperability
Ethereum rollup settlement
```

The safe framing is:

```text id="jycft6"
The DS layer is runtime-agnostic by design, but an EVM domain is a future research and implementation route, not a Phase 1 feature.
```

---

## Research questions

A serious EVM domain feasibility study should answer:

```text id="eqzyxo"
What EVM version or fork target would be supported?
Would the EVM domain be a native domain handler or implemented through WASM?
How would EVM gas map to DS layer gas rules?
How would 256-bit arithmetic be handled?
How would EVM storage map to the DS layer state tree?
How would Ethereum-style logs map to eventRoot?
How would EVM calls emit cross-domain outbox messages?
How would deposits enter EVM contracts?
How would withdrawals leave the EVM domain?
How would chain ID, signatures, nonces, and replay protection work?
How much existing Ethereum tooling could be reused?
What would need custom RPC or wallet adapters?
What would Phase 2 fraud proofs require for EVM execution?
What would Phase 3 validity proofs require?
```

These questions should be answered before claiming EVM compatibility.

---

## What not to claim

Do not claim:

```text id="o5gpcv"
Project Zeno ships EVM
Project Zeno ships Ethereum interoperability
Project Zeno can fork Ethereum rollups unchanged
Project Zeno inherits Ethereum liquidity
Project Zeno inherits Ethereum security
Project Zeno can move Ethereum assets just by running EVM
A future EVM domain means Ethereum users and apps automatically migrate
Ethereum finality is automatically available inside Zeno
```

Use the safer versions:

```text id="gw8t0i"
A future EVM domain could provide runtime and tooling compatibility.
Ethereum event interoperability would require an external-input route.
Ethereum asset interoperability would require a bridge or custody model.
A Zeno EVM domain would settle to Zenon, not Ethereum.
Runtime compatibility is not asset interoperability.
```

---

## Final summary

Ethereum-facing research should begin with a narrow, honest claim:

```text id="hbrn8o"
A future EVM domain could let Ethereum-style execution settle to Zenon.
```

That is powerful enough.

It means Project Zeno could potentially support familiar Solidity-style development while preserving the DS layer model.

But it does not mean Ethereum itself comes with it.

The difference is simple:

```text id="mhvohc"
EVM compatibility = code and tooling compatibility
Ethereum interoperability = event, asset, liquidity, finality, or security connection to Ethereum
```

Those are not the same.

The DS layer can potentially host an EVM domain.

It does not automatically inherit Ethereum.
