# Phase 1

This directory contains implementation-ready specifications for an additive libp2p networking foundation beside the current Zenon network stack.

The operating constraint is strict:

Current P2P remains authoritative.

Nothing in Phase 1 implies replacement.

Every integration boundary is source-verification gated.

Every specification is accompanied by a hostile review.

## How To Read This

Read sequentially.

Do not jump ahead.

Each specification establishes assumptions, interfaces, and safety boundaries used by the next specification. Skipping order weakens implementation safety and increases the chance of introducing hidden coupling to current network behavior.

Recommended reading order:

1. libp2p Host
2. Peer Service Discovery
3. Peer Reachability Verification
4. Peer Service Scoring
5. libp2p Sync Protocol
6. Sync Candidate Selection
7. Sync Request Scheduling
8. Initial Sync Strategy
9. libp2p Gossip Protocol
10. Current P2P Coexistence and Migration
11. Implementation Readiness Checklist

For each specification:

1. Read the specification
2. Read the accompanying hostile review
3. Resolve open assumptions
4. Proceed only after review conclusions are understood

## Implementation Rule

Build local mechanisms first.

Connect them to real node behavior only through source-verified boundaries.

If a path can mutate state and is not source-verified, do not call it.
