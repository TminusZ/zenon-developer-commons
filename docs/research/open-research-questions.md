# Open Research Questions

This document lists open questions about Zenon's architecture that require further exploration, experimentation, or community insight.
These are not assumptions or claims — they are starting points for technical investigation.

Contributors are encouraged to create new documents, propose answers, or add additional questions.

## 1. Browser-Native Light Client Feasibility

- What is the minimum set of proofs a browser client must verify?
- Can momentum headers + Merkle proofs allow full trustless verification?
- What storage model (IndexedDB, WASM memory, etc.) best suits a browser node?
- How would a light client maintain local state or partial state?

## 2. Networking Layer Evolution

- Can Zenon's networking layer be adapted to support libp2p transports?
- What changes are required for WebRTC compatibility?
- How would fallback relays (circuit relays) function in this environment?
- Could browser peers participate in peer discovery?

## 3. Sentries as Proof-Serving Nodes

- What is the exact expected role of Sentries in the architecture?
- Can they serve:
  - momentum proofs
  - state roots
  - ACI execution proofs
  - historical account-block proofs?
- What trust assumptions does a light client make regarding Sentries?
- How would a Sentry advertise available proofs?

## 4. ACI Deterministic Execution

- How is deterministic execution guaranteed across clients?
- What is the minimum set of rules required to replicate execution in-browser?
- Could ACIs be executed directly in JavaScript or WASM?
- How will the system prevent state divergence between nodes?

## 5. Extension Chains vs Native Scalability

- In what cases should an extension chain be used rather than an ACI?
- How does the presence of extension chains impact browser native clients?
- Can extension chains integrate with proof-serving for cross-chain operations?

## 6. Security Considerations

- How resistant is a browser-based node to eclipse attacks?
- What rate limits are needed for proof-serving?
- Could WebRTC relays be exploited for spam or DoS?
- What cryptographic safeguards are required for client-side execution?

## 7. Developer Tooling

- What tools are required for developers to easily test light client logic?
- What documentation gaps exist in the current ecosystem?
- Would a browser test harness help prototype ideas quickly?

## How to Contribute

Anyone can add a new question or propose answers by:

- creating a new file in this folder
- opening a GitHub issue
- submitting a pull request
- or starting a discussion thread

This document will grow as the community explores the architecture more deeply.
