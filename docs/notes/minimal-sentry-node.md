# Minimal Sentry Node (Draft Notes)

These are early notes on what a minimal Zenon Sentry node might look like. This is not a spec, just an outline for reasoning about the role between a light client and the rest of the network.

The goal is to describe the smallest useful Sentry implementation that:

- does not hold global state
- can run on modest hardware
- still provides clear value beyond a pure browser light client

---

## Role in the Architecture

In the current mental model:

- a light client is the user's identity and account view
- a Sentry is the local node that handles network interaction on behalf of one or more light clients
- a Sentinel is the deterministic verification and filtering layer
- a Pillar is the consensus/ordering layer (Momentum)

A minimal Sentry node is the smallest process that can sit between:

- a browser light client (or other thin client), and
- one or more Sentinels / full nodes,

without ever becoming a "full state" node itself.

---

## Why a Sentry Exists (Instead of Just a Browser Client)

A dedicated Sentry node is useful when:

- the light client environment is ephemeral (browsers, mobile apps, etc.)
- there is a need to share bandwidth and storage across multiple light clients
- the user wants some privacy shielding between their identity and the wider network
- proofs and headers should be cached locally to avoid repeated downloads
- micro-PoW and basic checks can be offloaded from the UI surface

The minimal Sentry is essentially:

a small, always-on, proof-aware relay and cache
that speaks the network's protocol on behalf of thin clients.

---

## Minimal Responsibilities

A minimal Sentry node should do as little as possible, but no less than:

1. **Networking**
   - Maintain P2P connections to Sentinels / peers (TCP, libp2p, or equivalent).
   - Handle basic peer selection and reconnection.

2. **Header and Momentum Tracking**
   - Follow Momentum headers with a light-client / SPV-style verifier.
   - Track the best chain by weight / difficulty, without downloading full blocks.

3. **Account-Chain Storage**
   - Store pruned account-chains for one or more users.
   - Maintain only the minimum data required for local validation and UX.
   - Avoid global state or unrelated account-chains.

4. **Proof and Commitment Verification**
   - Verify proofs and commitments tied to the tracked account-chains.
   - Reject data that is inconsistent with the current Momentum view.

5. **Transaction Pipeline**
   - Receive signed, micro-PoW-attached transactions from light clients.
   - Perform basic sanity checks (format, PoW threshold, replay protection).
   - Forward valid transactions to Sentinels for deeper verification and routing.

6. **Micro-PoW Assistance (Optional)**
   - Optionally assist with micro-PoW computation for connected clients.
   - Enforce local limits to avoid abuse (rate limits, resource caps).

7. **Local Observability**
   - Keep basic logs/metrics for debugging and tuning.
   - Expose a simple API for light clients (e.g., HTTP/WebSocket/local bridge).

---

## Single-User vs Multi-User Sentry

A minimal Sentry can be:

- single-user: one account-chain, one identity, maximum privacy
- multi-user (hybrid): several account-chains for different users, sharing the same node

In a hybrid setup the Sentry:

- keeps multiple account-chains locally
- still avoids global state
- behaves more like a small "edge gateway" for a household, team, or app cluster

The privacy and sovereignty trade-offs should be explicit: running a personal Sentry keeps more control local; using a shared Sentry trades that for convenience.

---

## Interaction with Browser Light Clients

A minimal Sentry does not replace browser light clients. It supports them:

- The browser keeps the user's keys and immediate session state.
- The Sentry handles long-lived networking, caching, and proof flow.
- The browser connects to the Sentry over a local or app-level channel and never talks to the wider P2P network directly.

In that sense:

- the browser light client = identity + UX
- the Sentry = local node + network shield

---

## Rough Startup and Flow

Very rough outline for a minimal process:

1. Start Sentry → load config and any existing account-chain snapshots.
2. Connect to peers → sync and verify Momentum headers (SPV-style).
3. Serve local API → accept light-client requests over a simple interface.
4. For incoming transactions from light clients:
   - validate structure and micro-PoW
   - attach any additional metadata if needed
   - forward to Sentinels
5. For incoming updates from the network:
   - verify against current Momentum view
   - update stored account-chains
   - notify connected light clients

---

## Open Questions

Some questions that need more work before this becomes a real design:

- What is the minimal proof format a Sentry must understand?
- How much account-chain history should it keep versus re-fetch on demand?
- What is the smallest viable SPV verifier for Momentum headers?
- How should multi-user Sentries isolate account-chains from each other?
- Where is the line between "minimal Sentry" and "small Sentinel-like node"?

These notes are intentionally narrow. The intent is to isolate the Sentry's smallest useful shape so it can be reasoned about separately from Sentinels, Pillars, and full archival implementations
