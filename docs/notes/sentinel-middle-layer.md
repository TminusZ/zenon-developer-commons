# Sentinels: Deterministic Middle-Layer Verification (Draft Notes)

These notes outline how Sentinels fit into Zenon's architecture as the deterministic verification and relay layer between lightweight Sentries and consensus-producing Pillars.

This is not a formal specification. It is an architectural framing for researchers investigating light-node design, SPV patterns, and browser-native execution.

---

## 1. Purpose of Sentinels

Sentinels exist to enforce deterministic rules before any data reaches the consensus layer.

In the Zenon design, a Sentinel:

- Validates incoming account-chain transitions.
- Ensures PoW-links meet minimum difficulty.
- Performs rule-checks for embedded contract calls.
- Protects Pillars from spam and malformed data.
- Relays only well-formed transitions to Momentum producers.

A Sentinel is not a consensus node and not a light client.
It is the filtering and shaping layer that keeps the network feeless without relying on economic fees.

---

## 2. Why Sentinels Exist in a Dual-Ledger System

Zenon splits responsibilities:

- Sentries handle local execution and proof construction.
- Pillars finalize ordering and build Momentum blocks.
- Sentinels sit between them, ensuring that only valid, well-structured transitions reach consensus.

This middle layer is necessary because Zenon does not use:

- Gas fees.
- A VM for global execution.
- Transaction inclusion markets.

Without Sentinels, Pillars would face unbounded spam and malformed transitions.

With Sentinels, the system remains lightweight while staying trustless.

---

## 3. What a Sentinel Actually Verifies

A Sentinel checks a deterministic set of conditions:

- Account-chain structure (parent hash, sequence, signature)
- Micro-PoW validity according to difficulty rules
- Embedded contract calls (argument structure, sender requirements, basic invariants)
- Receive block correctness for state transitions
- No double-spend or invalid predecessor state
- Transition formatting (sizes, fields, constraints)

Sentinels do not re-execute contract logic or maintain global state.
They validate structure, not semantics.

This keeps them extremely lightweight.

---

## 4. The Sentinel → Pillar Pipeline

A typical flow:

1. A Sentry constructs a signed account-chain transition.
2. The Sentry attaches micro-PoW.
3. The Sentinel receives the transition.
4. Sentinel performs deterministic validation.
5. Sentinel attaches its own PoW-link (optional future mechanism).
6. Sentinel forwards valid transitions to Pillars.
7. Pillars finalize transitions inside Momentum blocks.

This preserves a clean separation of concerns:

- Sentry = local execution
- Sentinel = rule enforcement
- Pillar = consensus + ordering

---

## 5. Sentinels vs. Sentries

A clear distinction:

**Sentry**

- Lives on the edge
- Local execution
- Builds transitions
- Computes PoW
- Only tracks its own account-chain

**Sentinel**

- Lives in the middle
- Does not execute zApps
- Does not maintain full state
- Ensures correctness of incoming transitions
- Filters spam before consensus

Sentinels are resource-lean infrastructure nodes.

They enable scaling by absorbing the operational load that would otherwise hit Pillars.

---

## 6. Why Sentinels Matter for Browser Nodes and SPV

Modern light-node efforts (browser clients, mobile clients, SPV nodes) benefit from Sentinels because Sentinels:

- Offload verification that is too heavy for browsers.
- Provide a stable gateway into the network without requiring RPC servers.
- Allow Sentries to remain minimal.
- Reduce the burden on consensus nodes.

Sentinels effectively stabilize the edge so that browsers can act as real peers.

---

## 7. Sentinel Incentivization (Open Direction)

The whitepaper describes Sentinels but does not finalize their economic model.

A future incentive model could reward Sentinels for:

- Uptime
- Correct relaying
- Validating transitions
- Supporting light clients
- Providing PoW-links or rate-limiting services

This would align Sentinels as the "work layer" in a feeless system.

(The above remains research, not a proposal.)

---

## 8. Open Questions

- How minimal can Sentinel state be while still validating all required rules?
- Should Sentinels maintain a rolling cache of account-chain frontier data?
- How should Sentinels communicate with Sentries—WebRTC, libp2p, or another interface?
- What verification load is appropriate for Sentinels vs. Sentries?
- Should PoW-links evolve to include Sentinel-generated scoring?

These questions guide future exploration.
