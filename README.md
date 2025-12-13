# ───────────────────────────────────────────
#     ZENON DEVELOPER COMMONS
# ───────────────────────────────────────────

A public, community-driven space for exploring and documenting the technical
architecture of **Zenon — The Network of Momentum (NoM)**.

[![Research](https://img.shields.io/badge/Focus-Research-blue)]()
[![Architecture](https://img.shields.io/badge/Topic-Architecture-green)]()
[![Light Client](https://img.shields.io/badge/Topic-Browser--Light--Client-orange)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-lightgrey.svg)]()

***The full, structured Zenon architecture documentation is available here:
👉 https://zenon-developer-commons.gitbook.io/zenon-developer-commons-docs


This repository serves as:

- a space for ongoing research into whether Zenon’s architecture can support a
  **browser-native, proof-verified light client** using technologies like WebRTC
  and libp2p  
- a neutral hub for engineering research  
- a place to organize architecture insights  
- a space to publish design notes, proposals, and analysis  
- a way for developers to collaborate without relying on chatrooms or politics  

The goal is simple:  
**Make Zenon’s deeper technical ideas easier to explore, discover, and understand.**

---

# ░░ Why This Repository Exists ░░

Zenon is an unconventional architecture combining:

- deterministic, VM-free contract interfaces  
- modular execution layers  
- dual-token economics  
- peer-to-peer communication primitives  
- concepts like Sentries, Pillars, and Accelerators  

However, much of Zenon’s design intent is:

- scattered  
- undocumented  
- buried in old chats  
- or never fully explained publicly  

This repository provides a structured place to collect, clarify, and refine that knowledge.

---

# ░░ What This Repository Is *Not* ░░

It is **not**:

- a governance tool  
- a decision-making authority  
- a replacement for core developers  
- a political or social channel  
- a roadmap for the ecosystem  

It *is* an **open research space** for technical thinkers who want to explore how Zenon works — or how it could evolve.

---

# ░░ Who This Is For ░░

This repository is intended for:

- protocol researchers  
- distributed systems engineers  
- blockchain architecture enthusiasts  
- P2P networking developers  
- cryptography and SPV-proof engineers  
- browser/WebRTC/libp2p developers  
- Zenon ecosystem contributors  
- curious readers with technical interest  

You *do not* need to be an expert to participate.

---

# ░░ Initial Research Areas ░░

### **Featured Research**
- [Browser-Native Light Client Overview](docs/research/browser-light-client-overview.md)

---

### **Architecture**
- NoM design overview  
- Account-chain vs momentum-based models  
- Deterministic contract interfaces (ACIs)  
- Sentry node conceptual design  
- Fusion, Plasma, and QSR mechanics  

---

### **Potential Future Directions**
- Browser-native light clients  
- libp2p transports for Zenon  
- WebRTC peer-to-peer connectivity  
- Proof-serving nodes  
- Off-chain, VM-less execution models  

---

### **Open Questions**
- What parts of NoM were intentionally designed for light clients?  
- Can Zenon support browser-native node execution?  
- How does Zenon achieve deterministic execution without a VM?  
- What role would Sentries play in proof-serving?  
- How do extension chains fit into Zenon’s long-term architecture?  

---

# ░░ How to Contribute ░░

Contributions of all kinds are welcome — including beginners.

You may:

- open issues for questions or research topics  
- add documents under `/docs`  
- create diagrams or architecture sketches  
- propose improvements  
- participate in GitHub Discussions (if enabled)

All contributions should remain:

- technical  
- respectful  
- calm  
- curiosity-driven  

This is a place for **collaboration**, not confrontation.

---

# ░░ Key Documents ░░

- [Browser-Native Light Client Overview](docs/research/browser-light-client-overview.md)  
- [Open Research Questions](docs/research/open-research-questions.md)  
- [Architecture Overview](docs/architecture/architecture-overview.md)  

---

## ░░ Curated Reading List ░░

This reading list provides background material and adjacent research that can help
developers understand Zenon’s architecture and evaluate the feasibility of
browser-native light clients, deterministic off-chain execution, and modern P2P
transport layers.

### Zenon-Specific Resources

- **Zenon Docs (Community Snapshot)**
  Concepts such as momentums, account-chains, ACIs, plasma, and fusion.  
  (Use the most recent community-maintained sources.)

- **Zenon GitHub Organization**
  Review the C++ and Go repositories for architecture hints.

### Browser & Light Client Technologies

- **Nakamoto SPV — Bitcoin Whitepaper (Section 8)**
  Foundational model for lightweight verification without full nodes.

- **BIP-157/158 — Neutrino**
  Modern SPV protocol design using compact filters.

- **WebRTC DataChannel Overview (MDN)**
  Understanding browser-native peer-to-peer communication.

- **libp2p Documentation**
  Modular networking stack used by IPFS, Filecoin, and other decentralized systems.

- **libp2p WebRTC Transport Specification**
  How P2P connectivity can be achieved from inside the browser.

- **IndexedDB (MDN)**
  Browser storage options for headers, proofs, and local partial state.

### Deterministic Execution & VM-Free Design

- **Deterministic State Machines in Distributed Systems**
  Useful background for understanding Zenon’s ACI design.

- **Optimistic Rollup Architecture (High-Level)**
  Not directly related to Zenon, but useful for understanding the idea of off-chain execution with on-chain verification.

- **Merkle Trees & Proof Systems**
  Practical knowledge for proof-serving, account block inclusion, and SPV mechanics.

### P2P & Networking Theory

- **Kademlia DHT**
  Foundational theory for peer discovery in decentralized networks.

- **libp2p Peer Routing & Discovery Modules**
  Helps understand how browser peers might discover full nodes or Sentries.

- **NAT Traversal & STUN/TURN Basics**
  Required background for WebRTC-based node connections.

### Blockchain Architecture References

- **Avalanche — Snowcone Light Client Paper**
  Modern example of proof-efficient light clients.

- **Zcash Halo 2 Overview (Optional)**
  Advanced topic, but useful for understanding recursive proof systems.

- **Tendermint Light Client Spec**
  Example of deterministic header verification logic.

### Optional Deeper Background

- **Google QUIC + WebTransport Overview**
  Not required for Zenon, but helpful for thinking about future browser-native transports.

- **Ethereum Stateless Client Research**
  Explores how minimal data structures enable ultra-light clients.

---

These materials are not required knowledge but can be extremely helpful for anyone
exploring Zenon’s architectural possibilities or contributing new research.

# ░░ License ░░

MIT License — open to anyone who wants to learn or build.

