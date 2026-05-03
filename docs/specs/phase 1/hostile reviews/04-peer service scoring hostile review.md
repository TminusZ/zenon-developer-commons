# Hostile Review — Zenon Peer Service Scoring Specification

## Overall Assessment

Verdict: **Strong pass with moderate tightening recommended**

This is the correct fourth Phase 1 specification.

The dependency chain remains coherent:

Host
→ Peer Service Discovery
→ Peer Reachability Verification
→ Peer Service Scoring

That progression is architecturally sound.

This specification does the most important thing correctly:

> it treats scoring as local operational memory, not protocol truth

That distinction preserves Phase 1 discipline.

Scores remain:

* local
* bounded
* decaying
* expiring
* observation-based
* non-consensus
* non-economic
* non-transferable

That survives hostile review.

The strongest design decision is the **reachability cap**.

A peer cannot become preferred if fresh local reachability evidence is missing.

That prevents stale high-score ghosts from dominating selection.

That is the spine of the scoring model.

---

## What Survives Attack

### 1. Local-Only Opinion Model

Strong.

A score means:

> this node has locally observed useful behavior

It does not mean:

> network-wide best peer
> globally trusted
> economically entitled
> objectively superior
> protocol blessed

Correct framing.

This survives hostile review.

---

### 2. Minimum Observation Gate

Excellent.

Rule:

```text id="i6thv4"
observation_count >= 3
```

before scoring eligibility prevents:

* one lucky success
* first-contact inflation
* accidental preferred promotion

This is correct anti-noise design.

This survives hostile review.

---

### 3. Score Expiry + Decay

Very strong.

Dual mechanism:

expiry
+
decay

prevents:

* stale preferred peers
* fossilized reputation
* “once good always good” behavior

That keeps ranking fresh.

Correct.

This survives hostile review.

---

### 4. Reachability Hard Cap

Excellent.

No fresh reachability:

> cannot become preferred

That binds discovery → verification → scoring in proper dependency order.

No fake usefulness without fresh verification.

This survives hostile review.

---

### 5. Deterministic Tie Breaking

Strong.

Tie order:

label
→ numeric score
→ latency
→ recency
→ failures
→ peer ID

That avoids random selection drift.

Determinism matters.

This survives hostile review.

---

## Weaknesses

## 1. Weight Constants Feel Arbitrary

Current:

* success = 50
* failure = 25
* timeout = 20
* reachability = 20
* freshness = 20
* compatibility = 5

These are sane, but not justified.

Builders will ask:

> why 50?
> why not 40?
> why is timeout weaker than failure?
> why is compatibility non-trivial?

Need explicit note:

> initial conservative defaults, implementation tuning subject to observation

Otherwise weights feel pseudo-precise.

---

## 2. Latency Can Be Misleading

Low latency ≠ useful peer.

Examples:

* LAN peer
* geographically close weak peer
* low latency but unreliable peer

Latency bonus should remain small.

Need explicit cap wording:

> latency is minor adjustment, never dominant scoring factor

Otherwise scoring may overweight speed.

---

## 3. CompatibleVersions Is Operator-Defined

Danger:

operators can bias selection through config.

That is acceptable because:

> local only

But should be explicit:

> compatibility weighting is operator-local preference, not objective quality

Clarify that boundary.

---

## 4. Persisted Observation Trust Needs Stronger Wording

Good:

> cache only

Needs stronger:

> persisted observations are historical hints and must never bypass freshness, expiry, reachability, or minimum observation gates

Otherwise startup state may accidentally overtrust disk state.

---

## 5. Score Per Service May Fragment Too Hard

Good architecture:

peer ID + service

But small networks may have sparse observations.

Result:

many peers remain UNSCORABLE for long periods.

Acceptable, but operationally slow.

Need note:

> Phase 1 favors correctness over aggressive scoring convergence

Otherwise operators may think scoring is “not working.”

---

## Missing Abuse Cases

Need explicit handling for:

### Observation Farming

Friendly peer intentionally responds repeatedly to farm score.

Mitigation:

rate-limited observation windows help.

Need explicit mention.

---

### Latency Spoofing

Peer fast on probe, poor under load.

Need note:

latency is advisory only.

---

### Connection Locality Bias

Peers near node always score better.

Expected.

Need explicit topology-relative warning.

---

### Sparse Network Bootstrap Problem

Small network → insufficient observations → many UNSCORABLE peers.

Need fallback operator expectations documented.

---

### Version String Spam

Peers advertise exotic versions to manipulate compatibility buckets.

Need strict parsing and normalization.

---

## Final Review Verdict

### Scope Discipline

**Excellent**

### Architectural Dependency

**Excellent**

### Isolation

**Excellent**

### Freshness Design

**Excellent**

### Abuse Hardening

**Very Good**

### Operational Clarity

**Good, needs tightening**

### Implementation Readiness

**Pass**

---

## Required Tightening Before Locked

1. Explain weight constants as conservative defaults
2. Cap latency influence explicitly
3. Clarify compatibility as operator-local preference
4. Strengthen persisted-observation cache wording
5. Mention sparse-network convergence expectations
6. Add observation-farming note
7. Mention topology-relative scoring bias

---

## Final Verdict

This is the correct fourth primitive.

Host creates connection.

Discovery creates vocabulary.

Verification creates evidence.

Scoring creates bounded local memory.

That is the right Phase 1 progression.
