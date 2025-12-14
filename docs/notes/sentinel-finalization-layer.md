# Sentinel Finalization Layer

Research Notes on Proof Anchoring in a Dual-Ledger Architecture

Status: Exploratory research note
Scope: Interpretation of documented Sentinel behavior and its role in a dual-ledger system
Note: This document distinguishes between documented behavior and inferred architectural roles. It is not a specification.

## 1. Introduction

Zenon's architecture is explicitly described as a dual-ledger system, consisting of:

- Account-chains, where users author their own state transitions
- Momentum blocks, which provide global ordering and confirmation

Within this model, Sentinels are documented as a network role distinct from Pillars and users. While the documentation does not present a formal, standalone "Sentinel specification," references across the whitepaper and related materials indicate that Sentinels participate in validation, monitoring, and network integrity enforcement.

This research note explores how Sentinels can be understood as a final verification and anchoring layer between account-level activity and Momentum-level ordering, based on documented behavior and reasonable architectural inference.

## 2. Position in the System Architecture

Documented components:

- Users / account-chains generate account blocks.
- Pillars produce Momentum blocks and maintain global ordering.
- Sentinels are described as a separate role involved in validation and monitoring.

Inferred positioning (clearly labeled):

- Sentinels operate between raw account-chain activity and Momentum inclusion.
- They do not replace Pillars and do not author account blocks.

The resulting conceptual flow is:

1. Account-chains generate signed state transitions.
2. Sentinels observe, validate, and monitor these transitions.
3. Pillars finalize ordering by including validated transitions into Momentums.

This interpretation is consistent with the stated goal of keeping Pillars lightweight and deterministic.

## 3. Sentinel Responsibilities (Documented + Inferred)

### 3.1 Validation and Monitoring (Documented)

The whitepaper and related discussions describe Sentinels as nodes that:

- Monitor network activity
- Validate structural correctness
- Enforce protocol rules
- Assist in spam and abuse prevention

They are explicitly not block producers.

### 3.2 Deterministic Filtering (Inferred)

Given that:

- Account-chains are independently authored
- Pillars avoid executing user logic

It is reasonable to infer that Sentinels act as a filtering and verification layer, ensuring that only structurally valid and protocol-compliant transitions propagate toward final ordering.

This does not imply consensus participation, but rather rule enforcement.

## 4. Anchoring and Discoverability (Inferred)

While not formally specified, Sentinels are frequently referenced in contexts related to:

- Network observability
- External monitoring
- Verification support

From this, one can reasonably infer that Sentinels contribute to state discoverability by:

- Observing which account-chain transitions are valid
- Making validated transitions visible to the rest of the network
- Supporting light-client or SPV-style verification flows

This anchoring role is conceptual and should be treated as a research interpretation, not a defined protocol guarantee.

## 5. Relationship to Pillars (Documented + Clarified)

Explicitly documented:

- Pillars alone produce Momentums.
- Pillars apply deterministic rules and signatures.
- Pillars do not execute application logic.

Implication:
Sentinels do not compete with Pillars. Instead, they reduce the validation burden by ensuring that the data Pillars see is already structurally valid.

This separation preserves:

- Determinism at the consensus layer
- Scalability at the network edge

## 6. Implications for Light Clients (Inferred)

Zenon documentation emphasizes:

- Minimal global state
- Deterministic verification
- Avoidance of global execution

These properties are compatible with (but do not explicitly specify) light-client or SPV-style verification.

Under this interpretation:

- Sentinels act as a verifiable observation layer
- Light clients can rely on cryptographic commitments rather than RPC trust
- Verification remains local and deterministic

This is an architectural implication, not a documented feature.

## 7. Security Considerations (Research Perspective)

The Sentinel role, as described and inferred, contributes to:

- Early detection of malformed transitions
- Reduced spam reaching the consensus layer
- Improved network observability

Security assumptions remain unchanged:

- No single Sentinel is trusted
- Verification remains cryptographic
- Final authority remains with Pillars and Momentum ordering

## 8. Open Research Questions

The documentation leaves several aspects intentionally unspecified:

- What exact data Sentinels persist or serve
- How redundancy among Sentinels is achieved
- Whether Sentinels are incentivized beyond protocol enforcement
- How Sentinel behavior could formally support light-client verification

These gaps represent open design space, not omissions.

## 9. Summary

From a research perspective:

- Sentinels are a documented network role focused on validation and monitoring.
- Their position between account-chains and Pillars naturally suggests an anchoring and filtering function.
- This role supports Zenon's stated goals of minimal consensus load, determinism, and scalability.
- While not formally specified as a "finalization layer," Sentinels can reasonably be interpreted as a verification bridge in a proof-first architecture.

This interpretation aligns with documented behavior while clearly separating explicit protocol facts from architectural inference.
