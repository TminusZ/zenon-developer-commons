# Hostile Review — Zenon Sync Candidate Selection Specification

## Overall Assessment

Verdict: **Strong pass with targeted simplification**

This is the correct sixth Phase 1 specification.

The dependency chain remains coherent:

Host
→ Peer Service Discovery
→ Peer Reachability Verification
→ Peer Service Scoring
→ libp2p Sync Protocol
→ Sync Candidate Selection

That progression is architecturally sound.

This specification gets the core invariant right:

> selection chooses who to ask, never what to believe

That is the spine of the document.

Candidate ranking remains:

* local-only
* deterministic
* bounded
* non-consensus
* non-economic
* diagnostic
* reversible

That survives hostile review.

The strongest design decision is the **authenticated identity merge rule**.

Everything merges by:

> authenticated libp2p peer ID

not:

> payload identity
> multiaddr text
> self-declared metadata

That prevents identity confusion and record poisoning.

Correct design.

---

## What Survives Attack

### 1. Clear Authority Separation

Strong.

Selection decides:

> request priority

Validation decides:

> acceptance

Those are separate.

A selected peer gains:

* no truth privilege
* no canonical privilege
* no authority privilege
* no reward privilege

Correct separation.

This survives hostile review.

---

### 2. Hard Eligibility Gates

Strong.

Known bad state remains excluded:

* wrong network
* wrong genesis
* malformed identity
* confirmed unsupported protocol

Even manual peers cannot bypass those exclusions.

That is exactly right.

Manual configuration must never become:

> operator trust switch

This survives hostile review.

---

### 3. Cooldown Is Local and Temporary

Very strong.

Cooldown is:

* bounded
* expiring
* diagnostic
* local-only

Not:

* punishment
* slashing
* reputation broadcast

Correct framing.

This survives hostile review.

---

### 4. Layer Independence

Excellent.

Expired service claim does not revive score.

Fresh score does not revive stale reachability.

Fresh reachability does not restore missing protocol support.

Each layer expires independently.

That avoids hidden coupling.

Correct.

This survives hostile review.

---

### 5. Deterministic Ordering

Strong.

No randomness.

Same state → same output.

That improves:

* debugging
* reproducibility
* explainability
* auditability

Determinism belongs here.

Scheduling randomness later is correct separation.

This survives hostile review.

---

## Weaknesses

## 1. Manual Override Surface Is Still Wide

Even constrained, manual peers may relax:

* missing service record
* missing reachability
* missing score
* unknown protocol support
* missing authenticated compatibility evidence

That is reasonable for bootstrap.

But operationally this creates:

> quasi-trusted peers

Need stronger wording:

> manual peers are bootstrap convenience only, not elevated trust peers

That should be explicit.

---

## 2. Unknown Protocol Default Exclusion May Slow Cold Start

Rule:

> unknown support → excluded

This is safe.

But early network growth may produce:

> many potentially good peers excluded until peer-info refresh occurs

Safe, but conservative.

Need note:

> Phase 1 intentionally favors correctness over fast candidate expansion

Clarify expectation.

---

## 3. Diversity Promotion Can Surprise Operators

Rule:

> may promote lower-ranked eligible peers

Good anti-centralization locally.

But:

operators may expect strict score ordering.

Need explicit:

> diversity only shuffles among already eligible peers, never promotes ineligible peers

You imply this—worth stating more forcefully.

---

## 4. Active Connection Shortcut Needs Clarification

Address eligibility:

> usable multiaddr OR active authenticated connection

This is mostly correct.

But active authenticated connection may be stale / half-dead.

Need stronger:

> active connection must be live and stream-capable under local host state

Otherwise zombie connections may satisfy eligibility.

---

## 5. DEGRADED Label Is Slightly Ambiguous

Current:

> eligible only if better peers are insufficient

Good policy.

But DEGRADED means:

* flaky?
* stale?
* slow?
* timeout-heavy?
* low score?

Need clearer semantic boundary.

Recommendation:

define DEGRADED explicitly as:

> locally usable but materially below preferred operational quality

That keeps meaning crisp.

---

## Missing Abuse Cases

Need explicit mention of:

### Friendly Peer Monoculture

One very strong peer dominates repeatedly.

Diversity policy helps.

Mention this directly.

---

### Manual Misconfiguration Lock-In

Operator pins weak peers.

Need operator warning language.

---

### Cooldown Oscillation

Peer repeatedly crosses threshold and flaps.

Need jitter / cooldown floor guidance.

---

### Stale Authenticated Connection

Existing connection remains open but remote usefulness collapsed.

Need stream-capable health awareness.

---

### Candidate Starvation

Conservative gating returns empty often in small networks.

Need explicit expectation:

empty result is valid and safer than weak inclusion.

---

## Final Review Verdict

### Scope Discipline

**Excellent**

### Identity Model

**Excellent**

### Layering

**Excellent**

### Safety Gates

**Excellent**

### Determinism

**Excellent**

### Operational Clarity

**Very Good**

### Bootstrap Ergonomics

**Good, needs wording clarity**

### Implementation Readiness

**Pass**

---

## Required Tightening Before Locked

1. Clarify manual peers as bootstrap convenience only
2. Explain conservative unknown-support exclusion
3. Strengthen diversity wording
4. Clarify active connection must be stream-capable
5. Define DEGRADED semantics more explicitly
6. Mention cooldown oscillation handling
7. Mention empty-result safety expectations

---

## Final Verdict

This is the correct sixth primitive.

Discovery identifies peers.

Verification checks reachability.

Scoring creates operational memory.

Sync defines bounded transport.

Candidate Selection decides:

> who is worth asking first

Still:

selection is not trust.

That invariant survives.
