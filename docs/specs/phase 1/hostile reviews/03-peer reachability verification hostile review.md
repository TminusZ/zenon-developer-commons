# Hostile Review — Zenon Peer Reachability Verification Specification

## Overall Assessment

Verdict: **Strong pass with a few important boundary clarifications**

This is the correct third Phase 1 specification.

The dependency chain is now coherent:

Host
→ Peer Service Discovery
→ Peer Reachability Verification

That architecture is clean.

This specification does something subtle and important correctly:

> it verifies reachability without pretending to verify trustworthiness

That distinction is critical.

The design keeps reachability as:

* local observation
* time-bounded
* challenge-validated
* authenticated
* non-consensus
* non-economic

That survives hostile review.

The strongest design decision is the **fresh dial requirement**.

Without that rule, existing connections would create false positives and the whole verification layer would degrade into “peer happened to be connected once.”

Fresh dial preserves meaning.

That is the spine of the spec.

---

## What Survives Attack

### 1. Local-Only Evidence Model

Strong.

A successful result means:

> reachable from this node
> at this time
> through this path

It does not mean:

> globally reachable
> honest
> performant
> reward eligible
> network trusted

That framing is correct.

This survives hostile review.

---

### 2. Fresh Dial Requirement

Excellent.

Requiring:

* pre-check connection snapshot
* new post-check connection handle
* authenticated peer match
* fresh challenge-response

eliminates:

* stale connection false positives
* reused idle connection false positives
* cheap replay success surfaces

This is the correct operational definition of fresh reachability.

This survives hostile review.

---

### 3. Nonce Design

Strong.

Requirements:

* cryptographically random
* 32 bytes
* non-empty
* non-reused within TTL
* non-reused across peers

Good replay resistance.

Good cross-peer isolation.

Good bounded cache semantics.

This survives hostile review.

---

### 4. Service Discovery Coupling

Strong.

Rule:

> service claim absent → verification loses active meaning

That prevents:

> once reachable = forever trusted

Correct.

Discovery remains authoritative for claims.

Verification remains authoritative for local observation.

Clean separation.

This survives hostile review.

---

### 5. Negative Result Containment

Very strong.

Negative results:

* are local only
* are diagnostic only
* are not accusations
* are not gossiped
* are not punishments

That avoids reputation poisoning.

Correct.

This survives hostile review.

---

## Weaknesses

## 1. Snapshot / Dial Race Is Real

You correctly document it.

Good honesty.

But operationally:

concurrent connection creation may satisfy:

> new post-check connection handle observed

without being created by checker dial.

Meaning:

fresh dial can be falsely satisfied.

Current mitigation:

> acknowledged known limitation

This is acceptable for Phase 1 because:

* local only
* no rewards
* no slashing
* no consensus meaning

But note clearly:

> local verified reachable is best-effort evidence, not perfect proof

That sentence should be explicit.

---

## 2. verified_multiaddr Can Drift

You correctly store:

> successfully dialed authenticated address

Good.

But peers may rotate addresses quickly.

Stored verified_multiaddr may become stale long before TTL expiry.

Recommendation:

explicitly state:

> verified_multiaddr is evidence of last successful path, not guaranteed current preferred path

Otherwise consumers may overweight it.

---

## 3. Manual Mode Is Semantically Different

Manual checks are diagnostic.

Automatic PUBLIC_RELAY checks are policy relevant.

These are materially different evidence classes.

Current field:

```text
source_service_claim = MANUAL
```

Good.

But consumers may still merge them mentally.

Recommendation:

explicitly call manual results:

> diagnostic reachability only

not:

> verified relay

Need stronger wording.

---

## 4. Nonce Cache Global Rule May Be Overkill

Cross-peer non-reuse is strong.

Security-wise good.

Operationally:

global cache grows faster than needed.

With 32-byte random nonces, accidental collision is negligible.

Cross-peer non-reuse is conservative, but memory-expensive.

Not wrong—just costly.

Acceptable if bounded.

Worth noting in implementation review.

---

## 5. No NAT Ambiguity Warning

Peer may genuinely be:

* reachable from some nodes
* unreachable from others

This spec knows that.

But README-style interpretation may drift into:

> reachable / unreachable binary truth

Need explicit note:

> reachability is topology-relative

Otherwise operators overgeneralize local observations.

---

## Missing Abuse Cases

Need explicit discussion of:

### Coordinated Probe Amplification

Many nodes probing same peer simultaneously.

Can become accidental load spike.

Mitigation:

randomized scheduling / jitter.

Mention it.

---

### Challenge Reflection Noise

Peer blindly echoes malformed or duplicate challenges.

Low severity, but mention malformed challenge handling.

---

### Multiaddr Churn Spam

Peer constantly rotates advertised addresses.

Can waste dial budget.

Need address-selection damping or cooldown mention.

---

### Friendly False Positives

LAN peers look very reachable.

Internet peers do not.

Need operator awareness that local topology biases results.

---

## Final Review Verdict

### Scope Discipline

**Excellent**

### Isolation

**Excellent**

### Verification Model

**Excellent**

### Replay Resistance

**Very Good**

### Abuse Hardening

**Very Good**

### Operational Precision

**Good, small clarifications needed**

### Implementation Readiness

**Pass**

---

## Required Tightening Before Locked

1. Explicitly state result is **best-effort local evidence**, not perfect proof
2. Clarify verified_multiaddr semantics as historical path evidence
3. Strengthen manual-mode diagnostic wording
4. Mention topology-relative reachability
5. Add jitter / randomized scheduling guidance
6. Mention address churn dial damping

---

## Final Verdict

This is the right third primitive.

Host creates connection.

Discovery creates vocabulary.

Reachability creates first local verification signal.

Scoring can now safely consume evidence.

That is the correct Phase 1 dependency chain.
