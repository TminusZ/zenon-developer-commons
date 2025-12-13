# Threat Model

**Status:** Proposed (applies to future light-client + proof-bundle designs)

This document defines adversaries, assumptions, and safety/liveness boundaries for:
- browser-native/light verification
- bundle-serving infrastructure (Sentinels/Supervisors)
- Momentum/header synchronization

## Goals

### Safety goals (must not break)
- A light client MUST NOT accept an invalid chain tip as canonical.
- A light client MUST NOT accept an invalid account frontier / state transition as valid.
- A light client MUST NOT accept proofs that do not match on-chain commitments.

### Liveness goals (best effort)
- A light client SHOULD be able to make progress without trusted RPCs, given reasonable peer connectivity.
- Bundle unavailability MAY stall progress, but MUST NOT break safety.

## Adversaries

Assume any of the following can be Byzantine:
- peers serving headers
- Sentinels relaying transactions
- Supervisors serving bundles
- a large fraction of non-committee nodes
- some fraction of committee/producers (bounded by consensus fault tolerance)

Assume network-level adversaries can:
- eclipse a client (peer isolation)
- delay or drop messages
- serve inconsistent data to different clients
- withhold bundles while serving headers

## Trust assumptions (explicit)

A light client’s safety relies on:
- cryptographic integrity of signatures/hashes
- correctness of fork-choice rule
- correctness of producer eligibility verification (committee proof strategy)
- at least one honest path to receive canonical headers eventually (anti-eclipse mitigation)

A light client’s liveness relies on:
- access to data availability (bundles/patches/proofs) from at least one source eventually

## Attack classes & handling

### Eclipse attack
**Impact:** can stall or mislead a client about best tip.
**Mitigations:**
- multi-peer sampling
- periodic peer rotation
- diversity constraints (networks/ASNs when possible)
- checkpointing / weak subjectivity anchors (if adopted)

### Withholding (data availability)
**Impact:** stalls client (liveness) if bundles are unavailable.
**Safety:** should remain safe if commitments are checked.
**Mitigations:**
- multiple independent bundle sources
- fallback modes (full patch fetch, or slow-path sync)
- explicit “availability timeout” policy

### Equivocation by bundle servers
**Impact:** serve different bundles for the same commitment.
**Safety:** client rejects any bundle that fails commitment checks.
**Mitigation:** commitment checks + optional gossip of bundle hashes.

### Invalid header chain (fork injection)
**Impact:** attempt to convince client to follow invalid fork.
**Mitigation:** strict header verification + committee/producer proofs + fork-choice.

## Safety vs Liveness Summary

- **Bundle absence** is primarily a **liveness** issue.
- **Bundle mismatch** (fails commitment checks) is a **safety** rejection, not a risk.
- **Committee proof weakness** is the highest safety-risk area for light clients.

## Non-goals
- No requirement that a browser executes global state.
- No requirement that a browser validates every transition on the network.
- No “trusted RPC gateway” assumption as a security requirement.
