# Project Zeno Research Commons

This repository is a **work-in-progress research and specification commons** for Project Zeno: a VM-agnostic settlement architecture for off-chain execution on Zenon.

Project Zeno separates execution from consensus:

```text
Consensus orders.
Executors compute.
Settlement anchors.
```

The core idea is that execution environments can operate as isolated domains under one settlement base. Phase 1 focuses on a WASM execution domain with a bonded executor. Future runtimes may be possible through additional domains, but they are not shipping in Phase 1.

This repository exists to collect and organize the public research, specifications, conformance material, audits, and explanatory writing around that architecture.

It is **not** a complete implementation repository.

It is **not** guaranteed to contain every latest implementation detail.

The developers shipping Project Zeno are actively iterating, and implementation documentation will evolve as the work progresses. Some low-level details, ABI examples, storage layouts, code examples, and phase-specific implementation notes may not appear here immediately, or may be documented elsewhere first before being reflected in this commons.

Treat this repository as a public research/specification workspace, not as the final source of all implementation truth.

---

## Status

**Work in progress.**

The documents in this repository are being organized while the implementation is still evolving.

Some files describe current Phase 1 design.
Some files are architecture companions or hardening notes.
Some files are conformance artifacts.
Some files are explanatory essays.
Some files are speculative research directions.

Readers should pay close attention to the status of each document.

Unless a document is explicitly marked as final, normative, or locked, assume it may change.

---

## Current Phase 1 scope

Phase 1 is focused on:

* WASM execution
* one bonded executor per domain
* bonded attestation
* off-chain execution
* on-chain settlement commitments
* custody and conservation enforcement
* canonical L1 input ordering
* withdrawal delays and public commitments
* future compatibility with fraud proofs and validity proofs

Phase 1 does **not** currently ship:

* multiple VM domains
* permissionless executor sets
* fraud proofs
* validity proofs
* Bitcoin interoperability
* Sentinel service markets
* QSR collateral mechanics
* unikernel packaging
* a complete implementation guide

Future-facing material may appear in this repository, but it should not be read as shipped functionality.

---

## Repository structure

```text
project-zeno/
  README.md

  specs/
    SPEC.md
    EXECUTOR.md
    ARCHITECTURE.md

  conformance/
    smt-v1-test-vectors.json
    proof-format.md
    wasm-gas-table-v1.json
    wasm-gas-table-v1.md
    execution-conformance-v1.json
    README.md

  audits/
    SPEC_HARDENING_REPORT.md
    EXECUTOR_HARDENING_REPORT.md
    SMT-SPEC-BLOCKERS.md
    MERKLE_STATE_L2_ALIGNMENT.md
    README.md

  implementation/
    README.md

  essays/
    PROJECT_ZENO.md
    README.md

  research/
    README.md
```

---

## Directory guide

### `specs/`

Core specification and architecture documents.

This directory contains the documents that define or explain the Project Zeno architecture.

Expected contents:

* `SPEC.md`
* `EXECUTOR.md`
* `ARCHITECTURE.md`

`SPEC.md` is the normative protocol document when marked as current.
`EXECUTOR.md` describes the executor architecture.
`ARCHITECTURE.md` is an informative design companion.

If documents conflict, the current normative spec governs.

---

### `conformance/`

Conformance and test-vector material.

This directory is for artifacts intended to make implementations deterministic and testable, including:

* SMT test vectors
* proof format documentation
* WASM gas tables
* execution conformance vectors

Files in this directory should indicate whether they are draft, current, locked, or pending implementation validation.

---

### `audits/`

Hardening notes, blocker reports, and engineering reviews.

This directory is for documents that identify ambiguity, risks, missing details, implementation blockers, and edge cases.

These files are part of the engineering process. They may describe problems, open questions, or corrections that are later resolved elsewhere.

---

### `implementation/`

Implementation documentation placeholder.

This directory is reserved for implementation notes as they become available.

The shipping developers are iterating phase by phase. This repository may not immediately contain every implementation detail being worked on.

Future contents may include:

* Settlement ABI examples
* method call examples
* storage key layouts
* executor module layout
* RPC helper notes
* `SubmitBatch` examples
* `RelayMessage` examples
* `RegisterDomain` / `RegisterExecutor` integration notes
* WASM runtime implementation notes
* DA bundle implementation notes
* Phase 2 fraud-proof implementation docs
* Phase 3 validity-proof implementation docs

Until those files exist, this repository should not be described as a complete implementation guide.

---

### `essays/`

Public-facing explanatory writing.

This directory contains narrative material explaining the broader thesis behind Project Zeno.

Essays are not normative. They may describe possibilities, implications, or future directions that are not part of the current implementation.

If an essay conflicts with a specification, the specification wins.

---

### `research/`

Speculative and non-normative research.

This directory is for future-facing ideas that are not part of the current Phase 1 implementation.

Examples may include:

* Sentinel service markets
* QSR collateral models
* Bitcoin interoperability research
* oracle service models
* payment routing
* DA incentive models
* unikernel or service-image concepts

Research documents should be clearly labeled as speculative, deferred, or non-normative.

Do not treat research notes as implementation commitments.

---

## What this repository is

This repository is:

* a public research commons
* a specification workspace
* a place to organize architecture documents
* a place to collect conformance artifacts
* a place to preserve hardening notes and audits
* a place to explain the broader Project Zeno thesis
* a work in progress

---

## What this repository is not

This repository is not currently:

* a production implementation
* a complete implementation guide
* a guarantee that every implementation detail is up to date
* the final source of all ABI or storage-layout details
* a finished smart contract platform
* a Bitcoin bridge
* a unikernel specification
* a Sentinel economics specification
* a QSR collateral specification
* a finished multi-VM network
* a trustless execution system in Phase 1

The architecture may permit some of these directions later, but they are not current shipped functionality unless explicitly documented as such by the implementation team.

---

## Phase model

### Phase 1 — Bonded attestation

Phase 1 uses a bonded executor to run a WASM domain off-chain and submit commitments to Settlement.

Settlement enforces custody, conservation, commitment recording, batch rules, caps, and withdrawal delays. It does not execute WASM and does not verify execution correctness on-chain.

Phase 1 prevents aggregate over-withdrawal, but per-account correctness still depends on executor honesty.

### Phase 2 — Fraud proofs

Phase 2 is expected to add fraud proofs and stronger enforcement against incorrect execution.

### Phase 3 — Validity proofs

Phase 3 is expected to add validity proofs so execution correctness is proven rather than attested.

---

## Document status labels

Documents should use clear status labels where possible:

```text
Normative
Informative
Draft
Current
Locked
Speculative
Deferred
Implementation note
Pending implementation validation
```

Readers should not assume an unlabeled document is final.

---

## Contribution notes

Please keep contributions aligned with the repository structure:

* protocol rules go in `specs/`
* implementation details go in `implementation/`
* hardening notes go in `audits/`
* explanatory writing goes in `essays/`
* speculative ideas go in `research/`

Avoid presenting future directions as shipped functionality.

Avoid presenting research notes as implementation commitments.

Avoid assuming this commons is always synchronized with the latest private or in-progress implementation work.

---

## Disclaimer

This repository is under active development.

Project Zeno is being built iteratively. The developers working on the implementation may update, replace, or supersede documents as the architecture hardens and code is written.

This commons is intended to make the research and specification process easier to follow in public. It should be used as a guide to the architecture and its evolution, not as a promise that every implementation detail is complete or final.

The work is open. The documents are evolving. The implementation is ongoing.
