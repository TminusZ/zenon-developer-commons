# Project Zeno Research

This folder contains explanatory research notes on Project Zeno.

The purpose of these notes is to explore the broader architecture implied by the Project Zeno specification while keeping a strict boundary between what is active in Phase 1, what is reserved, and what remains speculative.

`SPEC.md` governs on any conflict.

---

## Core research thesis

Project Zeno is not merely a WASM smart-contract layer.

It is best understood as a **Domain Settlement Layer**.

For short, these notes refer to it as the **DS layer**.

The name has two meanings:

```text
DS = Domain Settlement
DS = a nod to DigitalSloth, the developer who assisted in formalizing this architecture
```

The DS layer is a runtime-agnostic settlement surface where isolated execution domains can be registered, executed off-chain, and anchored back to Zenon through ordered inputs, state commitments, custody limits, withdrawal rules, and future proof hooks.

In simple terms:

```text
Settlement is the platform.
Domains are tenants.
WASM is the first tenant.
```

---

## What is active in Phase 1

Phase 1 activates the first safe slice of the DS layer:

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

Phase 1 is **bonded attestation**, not fully trustless execution.

---

## What is not shipping in Phase 1

These research notes discuss several future-facing design hooks, but they should not be confused with current implementation.

Phase 1 does not ship:

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
Phase 1 ships the first safe slice of a larger Domain Settlement Layer architecture.
```

---

## Research tracks

### 1. Domain Settlement Layer

The main reframe.

Project Zeno should not be understood as “smart contracts on Zenon.” It should be understood as a settlement layer for execution domains.

See:

```text
01_DOMAIN_SETTLEMENT_LAYER.md
```

### 2. Input sources

A domain is defined not only by what runtime it executes, but also by where its inputs come from.

The two key axes are:

```text
runtimeKind = what executes
inputSource = where truth comes from
```

This is the hidden design hook behind native domains, relayed external proof-data, and externally observed systems.

See:

```text
02_INPUT_SOURCES.md
```

### 3. Bitcoin legibility

The `L1_RELAYED` input source identifies a future route for Bitcoin proof-data to enter Zenon.

The safe framing is:

```text
Bitcoin legibility, not Bitcoin custody.
```

A Bitcoin SPV domain could verify Bitcoin headers and transaction inclusion proofs. It would not, by itself, solve native BTC custody or withdrawal.

See:

```text
03_BITCOIN_L1_RELAYED.md
```

### 4. Ethereum and EVM-domain feasibility

A future EVM domain could provide runtime and tooling compatibility.

That does not automatically bring Ethereum assets, liquidity, users, finality, or security.

The safe framing is:

```text
Runtime compatibility is not asset interoperability.
```

See:

```text
04_ETHEREUM_EVM_DOMAIN_FEASIBILITY.md
```

### 5. Cross-domain messaging

Domains that share the same Settlement layer can communicate through asynchronous outbox messages.

This is not the same as an external-chain bridge, and it is not synchronous composability.

See:

```text
05_CROSS_DOMAIN_MESSAGING_NOT_A_BRIDGE.md
```

### 6. Phase 1 honesty

Project Zeno’s Phase 1 trust model should be stated plainly.

Phase 1 provides bonded attestation, public commitments, aggregate custody enforcement, withdrawal delays, and value caps.

It does not yet provide fraud-proof or validity-proof enforcement.

See:

```text
06_PHASE_1_HONESTY.md
```

---

## Research discipline

These notes follow a strict rule:

```text
Do not market future hooks as current features.
```

Reserved fields are treated as reserved.

Speculative roles are labeled as speculative.

Nothing is called trustless unless the specification actually makes it trustless.

---

## Safe public summary

Project Zeno is a **Domain Settlement Layer** — the DS layer.

It lets Zenon anchor isolated execution domains without turning Zenon L1 into a monolithic VM.

WASM is the first domain, not the whole architecture.

The larger idea is that Zenon can become a settlement base for domains with different runtimes, different input sources, different execution policies, and future proof systems.
