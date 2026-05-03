# Hostile Review — Zenon Initial Sync Strategy Specification

## Overall Assessment

Verdict: **Strong pass with a few important operational clarifications**

This is the correct eighth Phase 1 specification.

The dependency chain remains coherent:

Host
→ Peer Service Discovery
→ Peer Reachability Verification
→ Peer Service Scoring
→ libp2p Sync Protocol
→ Sync Candidate Selection
→ Sync Request Scheduling
→ Initial Sync Strategy

That progression is architecturally sound.

This specification gets the core invariant right:

> planning is not trust
> transport is not trust
> matching peers are not trust
> acceptance remains authoritative

That is the spine of the document.

The strongest design decisions are:

* **minimum advisory sampling**
* **lowest observed height targeting**
* **bounded range stepping**
* **`RESPONSE_TOO_LARGE` halving**
* **explicit pause states**
* **explicit halt states**
* **ordering unknown → halt**
* **partial prefix disabled by default**

Those are excellent Phase 1 safety choices.

---

## What Survives Attack

### 1. Lowest Common Height Targeting

Excellent.

Default:

> minimum usable advisory height observed

This is conservative and correct.

Prevents:

* tallest liar attraction
* optimistic overreach
* chasing phantom height
* single-peer influence

This survives hostile review.

---

### 2. Divergence Means Uncertainty, Not Fault

Strong.

Conflicting tips produce:

> pause

Not:

> liar classification
> malicious classification
> slashing
> blacklist

That avoids false accusation logic.

Correct.

This survives hostile review.

---

### 3. RESPONSE_TOO_LARGE Handling

Excellent.

Treating oversized response as:

> planning feedback

rather than:

> peer misconduct

is correct.

Halving strategy:

```text id="e8x4pm"
64 → 32 → 16 → 8 → 4 → 2 → 1
```

is deterministic, bounded, and simple.

Correct Phase 1 behavior.

This survives hostile review.

---

### 4. Ordering Unknown → Halt

Excellent discipline.

If momentum/account-block dependency ordering is not source verified:

> halt

Do not guess.

Do not infer.

Do not “probably.”

That is exactly correct.

This survives hostile review.

---

### 5. Partial Prefix Disabled

Very strong.

If returned range contains invalid object:

> pause

Do not accept earlier prefix by assumption.

That avoids hidden acceptance policy creation.

Correct.

This survives hostile review.

---

## Weaknesses

## 1. Lowest Height Can Stall Progress

Conservative target:

> minimum usable advisory height

Safe—but sticky.

One stale honest peer can anchor target lower than reality repeatedly.

Result:

slow catch-up staircase.

Safe.

Operationally sluggish.

Need explicit note:

> Phase 1 intentionally prefers conservative advancement over aggressive tip pursuit

Clarify expectation.

---

## 2. Two Matching Tips Are Still Weak

You say:

> not proof

Correct.

But operators will mentally treat:

> two peers agree

as strong evidence.

Need stronger explicit wording:

> matching advisory tips reduce uncertainty only; they do not materially change validation requirements

Keep that boundary hard.

---

## 3. Pause Frequency May Be High

Pause on:

* divergence
* no candidates
* no usable candidates
* budget exhaustion
* validation rejection
* response-too-large floor
* unknown ordering

That is safe.

But many pauses may be normal.

Need explicit operator expectation:

> frequent safe pauses are expected in conservative Phase 1

Otherwise pauses will be interpreted as failure.

---

## 4. Candidate Refresh Interval Fixed Default Is Crude

60 seconds is sane.

But:

* small network → maybe too slow
* unstable network → maybe too fast
* high churn → suboptimal

Need wording:

> conservative default, implementation tuning expected

Not pseudo-precise.

---

## 5. Range Growth Strategy Is Underdefined

You define halving on oversize.

Good.

You say:

> gradual growth on success

But growth schedule is vague.

Need explicit default:

example:

```text id="sx8d7m"
1 → 2 → 4 → 8 → 16 → 32 → 64
```

or capped additive growth.

Otherwise implementations diverge.

---

## Missing Abuse Cases

Need explicit handling for:

### Honest Stale Anchor Peer

Low tip peer repeatedly keeps minimum target low.

Need stale-tip weighting / freshness consideration later.

---

### Budget Pause Loop

Scheduler budget exhaustion repeatedly pauses sync.

Need operator visibility note.

---

### Tiny Range Crawl

Repeated halving to 1 creates extremely slow sync.

Safe, but mention this is deliberate bounded fallback.

---

### Divergence Oscillation

Advisory tips repeatedly converge / diverge.

Need expectation that pause/resample loops may occur.

---

### Candidate Churn Mid-Session

Good target chosen, candidates disappear.

Need explicit:

re-plan safely, not trust old plan indefinitely.

---

## Final Review Verdict

### Scope Discipline

**Excellent**

### Acceptance Boundary

**Excellent**

### Conservative Planning

**Excellent**

### Failure Semantics

**Excellent**

### Determinism

**Excellent**

### Operational Clarity

**Very Good**

### Throughput Expectations

**Good, needs explicit framing**

### Implementation Readiness

**Pass**

---

## Required Tightening Before Locked

1. Explicitly state conservative advancement > speed
2. Strengthen “matching tips are not trust” wording
3. Note frequent pauses may be normal
4. Clarify refresh interval is conservative default
5. Define default growth schedule on success
6. Mention divergence / pause loops are expected
7. Mention candidate churn triggers safe re-plan

---

## Final Verdict

This is the correct eighth primitive.

Selection chooses:

> who is eligible

Scheduling chooses:

> who gets asked

Initial Sync chooses:

> what bounded chain data to request next

Still:

> requested is not trusted
> returned is not accepted
> matched is not canonical

Acceptance remains authoritative.

That invariant survives.
