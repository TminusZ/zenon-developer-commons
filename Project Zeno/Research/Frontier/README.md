# Project Zeno Frontier Research

This folder contains exploratory research into future-facing Project Zeno capabilities implied by the DS layer.

These notes are not implementation claims.

They are boundary tests.

The purpose of this folder is to explore what may become possible if Project Zeno’s Domain Settlement Layer expands beyond its first Phase 1 WASM domain.

`SPEC.md` governs on any conflict.

---

## What this folder is

The main `Research/` folder explains the grounded architecture:

```text id="ygbsf6"
Domain Settlement Layer
input sources
Bitcoin L1_RELAYED route
EVM domain feasibility
cross-domain messaging
Phase 1 honesty
```

This `Frontier/` folder goes one step further.

It asks:

```text id="cx2rsg"
What are the boundaries of the DS layer?
What can a relayer safely bring into a domain?
What can be verified inside a domain?
When does a relayer become trusted?
What can be proven?
What must be observed?
What requires custody?
What roles could future infrastructure operators perform?
```

The goal is not to claim these systems are live.

The goal is to identify which ideas are feasible, which are blocked, which are speculative, and which are unsafe to market.

---

## Research discipline

Every Frontier note should follow this rule:

```text id="qf9oya"
Test the boundary without pretending the boundary has already been crossed.
```

That means:

```text id="fb61oi"
reserved means reserved
speculative means speculative
future means future
prototype means prototype
Phase 1 means Phase 1
```

Do not turn a design direction into a shipping claim.

Do not call something trustless unless the mechanism actually makes it trustless.

Do not call something a bridge unless it handles both event verification and custody/redemption.

Do not claim Sentinels or QSR have roles unless the spec assigns them.

---

## Core Frontier question

The central question of this folder is:

```text id="bb2f39"
What can enter the DS layer without becoming trusted?
```

That question mostly points to relayers.

A relayer can be many things:

```text id="kg220w"
courier of proof-data
cross-domain message carrier
Bitcoin header relayer
Ethereum event relayer
oracle reporter
DA bundle server
proof server
liquidity router
custody participant
```

Some relayer roles are low-trust because the domain can verify the proof-data.

Other relayer roles are high-trust because the data cannot be independently verified.

This folder exists to sort those categories.

---

## Proof-shaped data vs observed data

A major distinction in Frontier research is:

```text id="u6h5vl"
proof-shaped data
observed data
```

Proof-shaped data can be checked by the domain.

Examples:

```text id="yyp25f"
Bitcoin block headers
Merkle inclusion proofs
cross-domain outbox proofs
state proofs
receipt proofs
rollup output-root proofs
```

Observed data depends more on reporters, watchers, challenge windows, bonding, slashing, or reputation.

Examples:

```text id="cg8s2g"
price feeds
weather data
sports outcomes
proof-of-reserve observations
API states
off-chain service uptime
real-world event reports
```

This distinction matters because it changes the trust model.

The safe rule is:

```text id="y0km6h"
If the domain can verify the proof, the relayer is mostly a courier.
If the domain cannot verify the fact, the relayer becomes part of the trust model.
```

---

## Frontier research tracks

### 1. Relayer boundary

File:

```text id="etov1h"
01_RELAYER_BOUNDARY.md
```

Core question:

```text id="vdbsrg"
What kinds of external facts can a relayer bring into the DS layer, and what proof or trust model does each require?
```

This is the highest-priority Frontier topic.

---

### 2. Domain verification limits

File:

```text id="uwvvmw"
02_DOMAIN_VERIFICATION_LIMITS.md
```

Core question:

```text id="j4z2cj"
What can realistically be verified inside a domain without making execution too expensive or requiring new host functions?
```

Topics include Bitcoin SPV, Merkle proofs, Ethereum receipt proofs, BLS signatures, zk proof verification, and oracle quorum signatures.

---

### 3. Relayer trust models

File:

```text id="ryv37a"
03_RELAYER_TRUST_MODELS.md
```

Core question:

```text id="r7j93p"
When is a relayer merely a courier, and when does it become a trusted actor?
```

This document should classify relayers by trust level.

---

### 4. Bitcoin SPV domain prototype

File:

```text id="19xian"
04_BTC_SPV_DOMAIN_PROTOTYPE.md
```

Core question:

```text id="8n7v5p"
What is the minimum Bitcoin SPV verifier that could live as a Zeno domain?
```

This should focus on event verification only, not BTC custody.

---

### 5. Ethereum event relay limits

File:

```text id="s5kpcu"
05_ETHEREUM_EVENT_RELAY_LIMITS.md
```

Core question:

```text id="vvb92n"
Can Ethereum events be verified directly by a Zeno domain, or does Ethereum require compression, zk proofs, or an observed-input model first?
```

This should separate EVM runtime compatibility from Ethereum event interoperability.

---

### 6. EXTERNAL_OBSERVED oracle boundary

File:

```text id="6x09h1"
06_EXTERNAL_OBSERVED_ORACLE_BOUNDARY.md
```

Core question:

```text id="bqjga8"
What can an observed-input domain safely observe, and what trust mechanisms are required?
```

This should explore oracle-style systems without claiming Project Zeno ships oracles.

---

### 7. DA and proof-serving boundary

File:

```text id="rapl07"
07_DA_AND_PROOF_SERVING_BOUNDARY.md
```

Core question:

```text id="wh0t9x"
If Settlement only anchors commitments, who serves the data and proofs needed for users, browsers, and watchers to verify them?
```

This is likely one of the most important future infrastructure roles.

---

### 8. Cross-domain relay proofs

File:

```text id="s077k1"
08_CROSS_DOMAIN_RELAY_PROOFS.md
```

Core question:

```text id="t7sxlb"
What is the minimum proof object needed for one domain to safely consume another domain’s message?
```

This explores internal DS-layer message relaying, not external-chain bridging.

---

### 9. Custody boundary

File:

```text id="akzxsa"
09_CUSTODY_BOUNDARY.md
```

Core question:

```text id="9d70m0"
At what point does verified external event data become real asset interoperability?
```

This should separate event verification, accounting representation, minting, burning, custody, withdrawal, and redemption.

---

### 10. Sentinel service boundary

File:

```text id="ar13b8"
10_SENTINEL_SERVICE_BOUNDARY.md
```

Core question:

```text id="6177cw"
Which DS-layer infrastructure roles could naturally fit Sentinels, and which remain speculative?
```

This should keep the Sentinel thesis alive without assigning roles the spec has not assigned.

---

## Suggested reading order

Read the grounded research first:

```text id="atvky3"
../README.md
../01_DOMAIN_SETTLEMENT_LAYER.md
../02_INPUT_SOURCES.md
../03_BITCOIN_L1_RELAYED.md
../04_ETHEREUM_EVM_DOMAIN_FEASIBILITY.md
../05_CROSS_DOMAIN_MESSAGING_NOT_A_BRIDGE.md
../06_PHASE_1_HONESTY.md
```

Then read Frontier in this order:

```text id="5ymiqw"
01_RELAYER_BOUNDARY.md
02_DOMAIN_VERIFICATION_LIMITS.md
03_RELAYER_TRUST_MODELS.md
04_BTC_SPV_DOMAIN_PROTOTYPE.md
05_ETHEREUM_EVENT_RELAY_LIMITS.md
06_EXTERNAL_OBSERVED_ORACLE_BOUNDARY.md
07_DA_AND_PROOF_SERVING_BOUNDARY.md
08_CROSS_DOMAIN_RELAY_PROOFS.md
09_CUSTODY_BOUNDARY.md
10_SENTINEL_SERVICE_BOUNDARY.md
```

---

## What this folder should not claim

Do not claim:

```text id="hbxk38"
Project Zeno ships external-chain relayers
Project Zeno ships Bitcoin SPV domains
Project Zeno ships Ethereum event verification
Project Zeno ships oracle domains
Project Zeno ships trustless asset bridges
Project Zeno ships Sentinel service markets
Project Zeno ships QSR collateral roles
Project Zeno ships proof-serving economics
Project Zeno ships fully trustless execution in Phase 1
```

Use safer versions:

```text id="lot2zi"
The DS layer creates research paths for relayers and external proof-data.
Bitcoin SPV is a future proof-verification research route.
Ethereum event verification is possible to study, but likely heavier than Bitcoin.
Observed inputs require explicit trust assumptions.
Custody is separate from event verification.
Sentinel service roles are architecture-implied, not spec-assigned.
```

---

## Safe public summary

Project Zeno Frontier Research explores the edge of the DS layer.

The main question is:

```text id="dghsxv"
What can a domain safely know about the outside world?
```

The first answer is relayers.

Relayers may carry proof-data, messages, observations, DA bundles, or custody events.

But each kind of relayer has a different trust model.

This folder exists to classify those models before anyone markets them as features.
