# Hostile Review — Zenon libp2p Host Specification

## Overall Assessment

Verdict: **Pass with targeted revisions**

The specification is disciplined, bounded, and correctly constrained as an additive networking layer. Its strongest property is architectural restraint. It repeatedly reinforces that current P2P remains authoritative, consensus remains untouched, sync remains untouched, gossip remains untouched, and replacement is explicitly blocked.

That is the correct first move.

The design does not overreach.

It introduces only the minimum viable substrate required to establish a modern peer identity and authenticated communication layer beside the current network stack.

This is a good specification.

The remaining weaknesses are mostly implementation-boundary precision, abuse hardening, and a few implied assumptions that should be made explicit before calling the document fully hardened.

---

## What Survives Attack

### 1. Consensus Isolation

Strong.

The specification clearly prevents:

* consensus mutation
* chain-state writes
* validation-path modification
* Plasma accounting changes
* fork-choice changes

This cleanly isolates networking substrate from protocol correctness.

This survives hostile review.

---

### 2. Replacement Blocking Rule

Very strong.

Explicitly blocking:

* ProtocolManager modification
* p2p.Server replacement
* sync rerouting
* gossip rerouting
* seeder replacement
* sync peer accounting crossover

prevents accidental migration by implementation drift.

This is exactly the right guardrail.

This survives hostile review.

---

### 3. Separate Identity Domain

Strong.

Using separate Ed25519 identity instead of reusing:

* wallet keys
* consensus keys
* producer keys
* existing P2P identity

is correct separation of trust domains.

Key reuse would have been architectural contamination.

This survives hostile review.

---

### 4. Bounded Metadata Surface

Strong.

The spec correctly bounds:

* message size
* protocol arrays
* services arrays
* listening addresses
* stream lifetime

This sharply reduces memory abuse and parser abuse.

This survives hostile review.

---

### 5. Wrong-Network Rejection

Strong.

Disconnect + peer ID backoff is sane.

Most importantly:

> wrong-network handling is local only

No bleed into current P2P.

Correct isolation.

This survives hostile review.

---

## Weaknesses

## 1. Chain Tip Field Is Dangerous As Written

The spec includes:

* chain_tip_height
* chain_tip_hash

while saying:

> informational only

This is mechanically safe today.

It is psychologically dangerous tomorrow.

Builders will immediately think:

> useful sync hint

Then they will accidentally create trust coupling.

The field creates gravity toward misuse.

### Recommendation

Either:

remove them entirely

or rename:

* advertised_tip_height
* advertised_tip_hash

and add explicit wording:

> self-reported, unauthenticated application metadata, MUST NOT influence peer selection, sync target selection, trust, or relay behavior

Current wording is slightly too soft.

---

## 2. Bootstrap Trust Is Underdefined

Bootstrap peers are assumed dial targets.

Missing:

what happens if bootstrap list is malicious?

Potential abuse:

* eclipse attempts
* stale topology pinning
* topology centralization
* bootstrap churn spam

Need explicit statement:

bootstrap peers are only connection seeds, not trust anchors.

Their metadata has no privileged trust weighting.

Without this, operators may misunderstand bootstrap semantics.

---

## 3. No Handshake Abuse Limits

Missing explicit connection-level abuse controls:

* handshake timeout
* concurrent handshake cap
* inbound connection burst limits
* half-open connection limits

Otherwise attacker can exhaust file descriptors / sockets before protocol bounds matter.

Need explicit hardening section.

---

## 4. Peer Table Persistence Is Vague

Spec says optional.

This creates implementation divergence.

One node:

persistent memory

Another:

cold boot every restart

Different behavior surfaces.

Pick one:

either:

peer table is ephemeral

or:

peer table persists

Default ambiguity weakens reproducibility.

---

## 5. Clock Field Has No Validation Rule

timestamp_unix exists but:

no skew bound

no freshness bound

no replay guidance

no discard rule

If informational only:

say:

> ignored except logging

If meaningful:

bound it.

Right now it is ambiguous.

---

## Open Assumptions

These remain assumptions until source verification closes them:

* node startup hook placement
* shutdown hook placement
* config path assumptions
* `types.Hash == 32 bytes`
* port collision assumptions
* current resource accounting interaction
* coexistence with existing listener lifecycle

These are implementation assumptions, not proven facts.

Keep them flagged.

---

## Missing Abuse Cases

Need explicit handling for:

### Slow Reader Attack

Peer accepts stream but reads slowly.

Need read deadline enforcement.

---

### Slow Writer Attack

Peer sends protobuf frame extremely slowly.

Need write deadline enforcement.

---

### Multiaddr Spam Complexity

Syntactically valid but pathological multiaddr parsing.

Need parser cost bounds.

---

### Reconnect Thrash

Wrong-network peer repeatedly reconnects.

Need connection-rate limiter before expensive work.

---

### Identity Rotation Spam

Attacker rotates peer IDs to bypass backoff.

Need IP / subnet rate guard discussion.

---

## Final Review Verdict

### Architecture

**Excellent**

### Scope Discipline

**Excellent**

### Isolation

**Excellent**

### Abuse Hardening

**Good, not complete**

### Boundary Precision

**Good, needs tightening**

### Implementation Readiness

**Pass with revisions**

---

## Required Revisions Before “Locked”

1. Clarify chain tip fields or remove them
2. Define bootstrap peers as non-trust anchors
3. Add handshake / half-open / burst connection limits
4. Decide peer table persistence behavior
5. Define timestamp semantics explicitly
6. Add abuse-case appendix

---

## Final Verdict

This is the correct first Phase 1 specification.

It is additive.

It is bounded.

It is source-verification compatible.

It does not accidentally migrate the network.

With targeted tightening, this becomes implementation-grade and adversarially durable.
