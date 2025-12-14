# Browser-Native Light Client Overview

This document explores the feasibility and implications of running a native Zenon light client directly inside a web browser, without trusted servers or centralized relays.

The goal of this research is to understand:

- whether Zenon's architecture supports browser-level execution
- which components are already compatible
- what additional work would be required
- and how this fits into the long-term design of the Network of Momentum

This is exploratory analysis, not a final specification.

## 1. Why Browser-Native Light Clients Matter

A browser light client enables:

- instant onboarding (no binary downloads)
- trust-minimized interaction with the network
- decentralized dApps running entirely in the browser
- peer-to-peer connectivity using WebRTC
- a path toward browser-based DEXs, messaging, and micro-applications

This removes the dependency on full nodes, RPC servers, or custodial infrastructure.

## 2. Why Zenon Is a Candidate for Browser Execution

Several aspects of the NoM architecture are unusually compatible with browser environments:

### 2.1 ACIs (Application Contract Interfaces)

Zenon uses deterministic, schema-based contract interfaces rather than a VM.
This reduces the need for in-browser virtual machine execution.

### 2.2 Modular networking layers

The networking layer is abstracted enough that alternate transports (e.g., libp2p, WebRTC) can theoretically be implemented.

### 2.3 SPV-style verification compatibility

Zenon's block structure and account model allow verification using lightweight proofs instead of full state execution.

### 2.4 Historical hints in design discussions

Several early descriptions and patterns (e.g., intent toward lightweight clients, modular execution, and proof-serving nodes) suggest that light clients were intended to be a first-class citizen.

## 3. Requirements for a Browser Light Client

Implementing a browser-native client would require:

**Transport layer**

A browser-compatible P2P stack, likely through:

- WebRTC (peer-to-peer data channels)
- libp2p with WebRTC transport
- Fallback relay nodes (circuit relays)

**Local state management**

IndexedDB or similar in-browser storage for:

- account state
- headers
- proofs
- cached momentum data

**Proof verification**

Implementing validation of:

- momentum headers
- signature checks
- Merkle/SPV proofs
- ACI contract commitment proofs

**Transaction construction**

Local transaction signing and assembly using JavaScript or WASM crypto libraries.

## 4. Role of Sentries (Hypothesis)

If Sentries act as proof-serving nodes, they could supply:

- momentum proofs
- state roots
- contract call proofs
- deterministic execution results

This would dramatically reduce the resource burden on the browser.

## 5. Open Questions

These require deeper exploration:

- What parts of Zenon's networking layer would need adaptation?
- How would proof-serving be standardized?
- What is the minimum set of data a browser needs to trustlessly verify?
- How do ACI calls map to deterministic, off-chain execution?
- Could this evolve into a framework for browser-native zApps?

These questions will be expanded in future documents.

## 6. Next Steps

This document is the starting point for a series of deeper investigations:

- Transport layer analysis
- SPV model specification
- ACI client-side execution model
- Sentry / proof-serving design
- Browser storage model
- Security considerations

Future contributors can build on this outline.
