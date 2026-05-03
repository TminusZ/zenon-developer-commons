# Hostile Review — Zenon Current P2P Coexistence and Migration Roadmap Specification

## Overall Assessment

Verdict: **Strong pass — one of the strongest documents in the set**

This is the correct tenth Phase 1 specification.

The dependency chain remains coherent:

Host
→ Discovery
→ Reachability
→ Scoring
→ Sync
→ Candidate Selection
→ Request Scheduling
→ Initial Sync
→ Gossip
→ Current P2P Coexistence & Migration Roadmap

That progression is architecturally sound.

This specification gets the most important invariant exactly right:

> coexistence is not replacement

That is the spine of the document.

The strongest design decisions are:

* **current P2P remains authoritative**
* **explicit gated modes**
* **no silent fallback**
* **no bridge by default**
* **ChainBridge isolation**
* **consensus isolation**
* **rollback at every layer**
* **crash downgrade**
* **late async generation invalidation**
* **ObjectIngressSource loop prevention**

Those are production-grade boundaries.

This survives hostile review.

---

## What Survives Attack

### 1. Authority Boundary Is Correct

Excellent.

You clearly separate:

current P2P authority

from:

libp2p additive capability

That avoids accidental replacement by feature creep.

Correct architecture.

This survives hostile review.

---

### 2. No Silent Fallback Rule

Excellent.

Failure must be:

> visible

Not:

> silently routed elsewhere

This prevents invisible coupling.

That is one of the most important operational rules in the whole Phase 1 set.

Correct.

This survives hostile review.

---

### 3. ObjectIngressSource Is Real Engineering

Excellent.

This is one of the strongest mechanisms in the entire spec set.

Rule:

Only:

```text id="n3p7wv"
LOCAL_ACCEPTANCE
```

may trigger publish.

Everything else:

> suppressed

That kills:

* gossip loops
* echo amplification
* rebroadcast storms
* source confusion

by mechanism—not operator discipline.

Excellent design.

This survives hostile review.

---

### 4. Rollback Architecture Is Mature

Very strong.

Rollback:

* stops new work
* preserves accepted state
* preserves current P2P
* ignores stale async generation results

This is real operational engineering.

Not hand-wavy architecture.

Correct.

This survives hostile review.

---

### 5. Migration Gates Are Honest

Excellent.

Passing readiness gates means:

> coexistence readiness

Not:

> migration authorization

That is honest scoping.

Very important distinction.

This survives hostile review.

---

## Weaknesses

## 1. Mode Ladder Implies Natural Progression

Sequence:

```text id="c5k8rx"
DISABLED → ... → MIGRATION_EXPERIMENTAL
```

Logical, but psychologically implies:

> roadmap destination

That may bias operators toward inevitable migration thinking.

Need stronger wording:

> progression is capability staging, not migration commitment

Clarify that hard.

---

## 2. GOSSIP_ACTIVE Is Operationally Heavy

At:

> publish + subscribe + fetch-after-announce

system complexity jumps sharply.

That is almost a mini-production network.

Need explicit:

> GOSSIP_ACTIVE is still additive observation / availability behavior only

Otherwise operators may overread capability.

---

## 3. Shadow Naming Can Mislead

Example:

```text id="x6q4tm"
LIBP2P_IBD_SHADOW
```

“IBD” implies:

> actual syncing

But semantics are:

> planning / comparison / diagnostics

Need stronger wording:

> shadow means non-authoritative simulation only

Clarify globally.

---

## 4. Metrics Are Underconstrained

Good list.

But metrics volume may explode:

* peer counts
* announcement counters
* drop reasons
* scheduler outcomes
* mode transitions

Need explicit:

> metrics must be bounded and sampling-friendly

Otherwise observability becomes resource sink.

---

## 5. MIGRATION_EXPERIMENTAL Label Is Dangerous

Even with restrictions, operators love toggles.

Need stronger:

> development / isolated test environments only, never public production activation

Make that unmistakable.

---

## Missing Abuse Cases

Need explicit handling for:

### Partial Rollback Completion

Some services stop, others linger.

Need generation fencing note everywhere (you mostly imply it).

---

### Config Drift

Different nodes running radically different coexistence modes.

Safe—but operator confusion likely.

Need observability clarity.

---

### Readiness Metric Vanity

Good metrics may create false migration confidence.

Need note:

metrics measure readiness signals, not safety proof.

---

### Long-Lived Shadow Cost

Shadow services may consume substantial resources indefinitely.

Need bounded-resource note.

---

### Manual Mode Thrashing

Repeated mode switching can create churn.

Need cooldown / operator discipline mention.

---

## Final Review Verdict

### Scope Discipline

**Excellent**

### Authority Isolation

**Excellent**

### Operational Safety

**Excellent**

### Rollback Design

**Excellent**

### Loop Prevention

**Excellent**

### Migration Discipline

**Excellent**

### Operational Clarity

**Very Good**

### Implementation Readiness

**Pass**

---

## Required Tightening Before Locked

1. Clarify progression ≠ migration intent
2. Clarify shadow = non-authoritative simulation
3. Clarify GOSSIP_ACTIVE remains additive only
4. Bound metrics footprint explicitly
5. Make MIGRATION_EXPERIMENTAL development-only unmistakable
6. Note readiness metrics ≠ migration proof
7. Mention mode-thrashing operational caution

---

## Final Verdict

This is one of the best specs in the Phase 1 set.

It does what good architecture should do:

> define capability
> define boundaries
> define rollback
> define what is explicitly forbidden

Most importantly:

> coexistence is not replacement

That invariant survives hostile review.
