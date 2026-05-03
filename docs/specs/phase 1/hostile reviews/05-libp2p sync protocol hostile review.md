# Hostile Review — Zenon libp2p Sync Protocol Specification

## Overall Assessment

Verdict: **Strong pass with a few critical clarifications**

This is the correct fifth Phase 1 specification.

The dependency chain remains coherent:

Host
→ Peer Service Discovery
→ Peer Reachability Verification
→ Peer Service Scoring
→ libp2p Sync Protocol

That progression is architecturally sound.

This specification gets the most important thing right:

> transport is not trust

That sentence is the spine of the document.

Returned bytes remain:

* untrusted
* bounded
* locally validated
* non-canonical until verified
* non-consensus
* non-authoritative

That survives hostile review.

The strongest design decisions are:

* **read-only serving**
* **validation-before-use**
* **no partial OK responses**
* **no direct chain insertion**
* **ChainBridge write prohibition**

Those are the right guardrails.

---

## What Survives Attack

### 1. Additive Isolation

Strong.

The protocol clearly forbids:

* replacing current P2P
* rerouting sync authority
* changing consensus behavior
* modifying chain insertion paths
* changing reward surfaces

Current P2P remains authoritative.

Correct isolation.

This survives hostile review.

---

### 2. Validation-Before-Use

Excellent.

Transport proves only:

> peer returned bytes

Nothing else.

Receiver still must validate:

* decode
* hash match
* ownership match
* range correctness
* canonical validation path acceptance

This is correct protocol hygiene.

This survives hostile review.

---

### 3. No Partial OK Rule

Excellent.

This is one of the strongest design choices.

Examples:

requested 128 momentums → server returns 97 → rejects
requested full momentum account-block set → partial → rejects

That prevents:

* ambiguous partial success semantics
* withholding attacks disguised as success
* implementation drift

Correct.

This survives hostile review.

---

### 4. Read-Only Serving Boundary

Very strong.

Serving node:

reads local data only

Never:

* mutates state
* invents data
* fetches externally to answer
* writes through ChainBridge

This sharply constrains attack surface.

This survives hostile review.

---

### 5. Tight Bounds

Strong.

Everything bounded:

* request size
* response size
* stream count
* request rate
* timeout
* range count
* memory footprint

That prevents accidental unbounded surfaces.

Correct.

This survives hostile review.

---

## Weaknesses

## 1. GET_PEER_TIP Can Create Trust Gravity

Even with advisory wording, implementers will naturally think:

> highest tip = best peer

That is dangerous.

Peer tip is:

* self-reported
* unauthenticated chain claim
* topology-relative
* potentially stale
* potentially dishonest

Need stronger wording:

> GET_PEER_TIP is range planning metadata only, never best-chain evidence

Make that explicit.

---

## 2. RESPONSE_TOO_LARGE May Leak Shape Information

Peer can probe:

* how many account blocks attach to a momentum
* whether chain ranges exceed local bounds

This leaks coarse structural information.

Low severity.

Mostly acceptable.

But worth acknowledging:

> bounded metadata leakage is accepted in Phase 1

Explicit honesty strengthens spec.

---

## 3. NOT_FOUND Semantics Need One Hard Sentence

You explain it well.

Still needs one unmistakable rule:

> NOT_FOUND means not found in this peer’s current local readable view only

Otherwise operators may interpret:

> object does not exist

That inference is wrong.

Need stronger wording.

---

## 4. Request ID Is Correlation, Not Security

Correctly stated.

But implementers love overloading IDs.

Need stronger explicit rule:

> request_id must never be treated as replay protection, freshness proof, or authentication primitive

Keep nonce semantics separate.

---

## 5. Aggregate Memory Bound Is Mentioned But Lightly

This is biggest implementation risk.

32 streams × 8 MiB = 256 MiB

Reasonable.

But concurrent serialization / buffering can exceed it.

Need stronger operational guidance:

* bounded worker pool
* response serialization cap
* reject under pressure
* no full fanout buffering

Clarify this more aggressively.

---

## Missing Abuse Cases

Need explicit mention of:

### Honest Heavy Peer

Peer serves huge valid responses repeatedly.

Still exhausts resources.

Need throughput fairness note.

---

### Valid But Expensive Objects

Canonical decode may be CPU heavy.

Need bounded decode cost awareness.

---

### Slow Read Consumer

Requester reads response very slowly.

Responder buffers.

Need write deadline / bounded write queue note.

---

### Peer Tip Lying

Peer advertises inflated tip to attract requests.

Need note:

tip affects planning only, not trust.

---

### Range Walking Probe

Attacker enumerates chain shape via bounded requests.

Mostly accepted leakage, but should be acknowledged.

---

## Final Review Verdict

### Scope Discipline

**Excellent**

### Isolation

**Excellent**

### Validation Model

**Excellent**

### Boundedness

**Excellent**

### Serving Safety

**Excellent**

### Operational Hardening

**Very Good**

### Clarity

**Good, small tightening needed**

### Implementation Readiness

**Pass**

---

## Required Tightening Before Locked

1. Stronger GET_PEER_TIP warning
2. Explicit NOT_FOUND local-view wording
3. Explicit request_id non-security wording
4. Stronger memory-pressure operational guidance
5. Mention bounded metadata leakage acceptance
6. Add write-deadline / slow-reader note
7. Mention topology-relative tip honesty

---

## Final Verdict

This is the correct fifth primitive.

Discovery identifies peers.

Verification checks reachability.

Scoring builds local operational memory.

Sync creates bounded read-only data exchange.

Still:

transport is not trust.

That invariant survives.
