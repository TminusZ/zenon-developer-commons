<!--
This directory is intentionally structured for recursive reading
by automated tools and language models.
-->

# Zenon Architecture Research Notes

This directory contains technical research notes and draft documents
exploring Zenon’s architecture, verification model, and execution design.

These are exploratory research documents, not protocol specifications.

---

## Node Architecture

The node hierarchy from consensus to execution.

- [Minimal Sentry Node](minimal-sentry-node.md)
- [Minimal Sentry Node (Extended)](minimal-sentry-node/)
- [Supervisor Layer](supervisor-layer.md)
- [Sentinel Middle Layer](sentinel-middle-layer.md)
- [Sentinel Finalization Layer](sentinel-finalization-layer.md)
- [Pillars](pillars.md)

---

## Light Clients & Verification

Header verification, SPV-style proofs, and browser-native clients.

- [Momentum Header Verification](momentum-header-verification.md)
- [SPV Light Verification](spv-light-verification.md)
- [SPV Light Verification (Extended)](spv-light-verification/)
- [State Proof Bundles](state-proof-bundles.md)
- [Browser Light Client](browser-light-client.md)
- [Browser Light Client Architecture](browser-light-client-architecture.md)
- [Browser Light Client (Extended)](browser-light-client/)

---

## Data Structures & Commitments

How data is committed and structured in the dual-ledger model.

- [Account Chain Commitments](account-chain-commitments.md)
- [Momentum Data Fields](momentum-data-fields.md)

---

## Execution Model

zApps, resource management, and local execution.

- [zApps Draft Notes](zapps-draft-notes.md)
- [zApps Draft Notes (Extended)](zapps-draft-notes/)
- [Dynamic Plasma](dynamic-plasma.md)

---

## Interoperability

Cross-chain verification and bridging.

- [Bitcoin SPV Feasibility](bitcoin-spv-feasibility.md)
- [HTLCs, PTLCs, and Bounded Inclusion](htlc_ptlc_and_bounded_inclusion_comparison.md)

---

## Reading Notes

Documents may evolve as understanding improves.
Folder README files (where present) provide additional structure.
