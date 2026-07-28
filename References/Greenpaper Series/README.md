# Greenpaper Series Collection

This folder contains a set of community-authored exploratory papers (non-normative, non-official) focused on resource-bounded, verification-first architectures for distributed ledger systems.

These documents explore ideas around lightweight verification, proof-based applications, and composable external inputs—all designed for edge devices (browsers, mobile, offline nodes) with explicit resource limits and refusal semantics.

## Documents

- **0x00_greenpaper_series_bounded_verification.pdf** (13 pages)  
  A theoretical framework for offline-resilient, resource-constrained verification in dual-ledger systems. Introduces adaptive retention horizons and optional privacy-enhanced verifier variants.

- **0x01_greenpaper_series_zApps.pdf** (7 pages)  
  Defines proof-first verifiable applications (zApps) where correctness is established via cryptographic proofs instead of execution replay. Emphasizes verifier sovereignty under strict memory, bandwidth, and availability constraints.

- **0x02_greenpaper_series_composable_external_verification.pdf** (8 pages)  
  Outlines a model for trustlessly verifying external facts (e.g., Bitcoin events) as bounded-verifier inputs, without intermediaries or full cross-chain execution.

- **ZENON_GREENPAPER_SPV_IMPLEMENTATION_GUIDE.pdf** (17 pages)  
  A practical, pre-prototype builder guide for implementing a lightweight SPV-style verifier. Includes interfaces, flows, resource examples, refusal rules, and a prototyping checklist (dated January 4, 2026).

These are community contributions meant to encourage discussion, prototyping, and further research. Feel free to open issues or share feedback!
