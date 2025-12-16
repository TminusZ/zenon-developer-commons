# SPV for Zenon (Draft Notes)

These are early notes on what a minimal SPV-style verification model for Zenon might look like. This is not a proposal or spec — just an outline for exploring how SPV fits into the dual-ledger architecture.

## Why SPV matters in this context

Zenon's design already supports a verification model where:

- global state is not required,
- account-chains are locally maintained,
- proofs can be small, and
- header chains are the main global reference.

This aligns naturally with an SPV-style approach:

- verify only Momentum headers,
- accept small proofs for account-chain updates,
- avoid full-node execution,
- keep verification lightweight enough for browsers or constrained devices.

SPV is not a replacement for the existing node roles —
it is an exploration of how minimal verification can get while still remaining trustless.

## What an SPV verifier would actually do

A minimal SPV verifier only needs to:

1. Download recent Momentum headers.
2. Verify their proof-of-work, signatures, and ordering.
3. Fetch account-chain fragments when needed.
4. Verify inclusion proofs against the relevant header.
5. Track the user's local state using these updates.

This avoids global chain sync and avoids re-execution entirely.

## Rough verification flow

1. Connect to any peer capable of serving headers.
2. Request a header range (or subscribe to new ones).
3. Validate each header's integrity.
4. When the user performs an action:
   - build and sign the account-chain update locally,
   - attach micro-PoW,
   - send through the peer.
5. When receiving a proof of inclusion:
   - verify it against the corresponding header,
   - apply the update to local state.
6. Continue following headers for finality.

No global state is downloaded.
Only the minimal structure required for verification exists.

## How this differs from a full Sentry

A full Sentry handles:

- P2P routing,
- micro-PoW relaying,
- maintaining multiple account-chains,
- acting as an intermediary for zApps and other clients.

An SPV verifier is narrower:

- verify headers,
- verify proofs,
- maintain only the user's state.

It is closer to a client than a node, but still trustless.

## Open questions

- What is the minimum proof size needed for account-chain verification?
- How far back must an SPV verifier retain headers?
- Should SPV support both browser and non-browser runtimes?
- Can Sentinels optionally serve SPV proofs?
- What are the cost/latency implications of header-only sync?

These notes are exploratory and may expand once the broader structure becomes clearer.
