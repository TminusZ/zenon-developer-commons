# Hostile Review — Zenon Sync Request Scheduling Specification

## Overall Assessment

Verdict: **Strong pass with minor operational tightening**

This is the correct seventh Phase 1 specification.

The dependency chain remains coherent:

Host
→ Peer Service Discovery
→ Peer Reachability Verification
→ Peer Service Scoring
→ libp2p Sync Protocol
→ Sync Candidate Selection
→ Sync Request Scheduling

That progression is architecturally sound.

This specification gets the core invariant right:

> scheduling decides how to ask, never what is true

That is the spine of the document.

The scheduler remains:

* bounded
* deterministic
* local-only
* non-consensus
* non-economic
* diagnostic
* reversible

That survives hostile review.

The strongest design decisions are:

* **deterministic request fingerprinting**
* **per-peer caps**
* **global caps**
* **same-peer retry disabled by default**
* **sequential identical-request scheduling**
* **advisory divergence treated as uncertainty, not fault**

Those are the right Phase 1 constraints.

---

## What Survives Attack

### 1. Clear Authority Separation

Strong.

Scheduler decides:

> who to ask
> when to ask
> how often to ask

Validation decides:

> what is acceptable

That keeps orchestration separate from truth.

Correct.

This survives hostile review.

---

### 2. Deterministic Fingerprinting

Excellent.

Identical logical request:

> same fingerprint

Different logical request:

> different fingerprint

Excluding:

* timestamps
* peer randomness
* peer-influenced data
* scores

is correct.

That prevents:

* duplicate request ambiguity
* scheduler drift
* response attribution confusion

This survives hostile review.

---

### 3. Sequential Default Is Correct

Excellent restraint.

Default:

```text id="c9s4lp"
max_identical_request_parallelism = 1
```

That avoids:

* fanout storms
* accidental amplification
* needless duplicate bandwidth
* early peer pile-on

Correct Phase 1 posture.

This survives hostile review.

---

### 4. Advisory Divergence Handling

Very strong.

Different tip claims are treated as:

> uncertainty

Not:

> malicious proof
> fork proof
> liar proof

That avoids false accusation logic.

Correct.

This survives hostile review.

---

### 5. Construction Failure Isolation

Strong.

If request construction fails:

> no peer observation emitted

Correct.

No contacted peer → no peer blame.

That preserves observation integrity.

This survives hostile review.

---

## Weaknesses

## 1. Deterministic Ordering May Create Herding

Every node with similar state will choose:

> same rank-1 peer

Even with per-peer caps, network-wide:

> hot peer concentration

Diversity earlier helps.

Still:

scheduler determinism creates convergence pressure.

Need explicit:

> future jitter layer may randomize among top eligible peers without changing eligibility

Phase 1 deterministic is acceptable, but acknowledge clustering.

---

## 2. Sequential Identical Requests Can Be Slow

Default safe.

But:

slow honest peer → wait → timeout → rotate

Small networks may feel sluggish.

This is acceptable because:

> correctness > speed in Phase 1

Worth stating explicitly.

Otherwise operators may interpret latency as design failure.

---

## 3. RATE_LIMITED Cooldown Needs Care

Peer may honestly rate limit because it is useful.

Cooldown too aggressive:

> punishes best infrastructure

Need note:

RATE_LIMITED cooldown should be gentle and short-lived.

Not equal to malformed / protocol violation.

Severity classes should be distinguished.

---

## 4. Validation Rejected Is Ambiguous

Could mean:

* peer stale
* peer buggy
* request mismatch
* corrupted payload
* adversarial payload

All grouped together operationally.

Safe, but broad.

Need note:

> validation rejection is a local incompatibility signal, not a dishonesty classification

Clarify semantics.

---

## 5. Advisory Session ID Needs Stronger Definition

Included in fingerprint.

Good.

But:

scope unclear.

Need explicitly define:

> advisory session ID groups one planning round only

Otherwise implementations may over-extend its lifetime.

---

## Missing Abuse Cases

Need explicit handling for:

### Slow Honest Peer Trap

Peer responds validly but near timeout repeatedly.

Consumes slot capacity.

Need adaptive timeout / score pressure mention.

---

### Hot Peer Convergence

Many nodes independently choose same preferred peer.

Need mention of top-set rotation possibility later.

---

### Candidate Starvation

Strict caps + cooldown + sequential behavior may temporarily exhaust candidates.

Need explicit:

empty scheduler output is acceptable and safe.

---

### Retry Horizon Explosion

Large retry budget on small candidate pool can waste cycles.

Need mention of bounded unique-peer attempts.

---

### Manual Peer Stickiness

Operator-configured peers may remain overused.

Need warning that manual peers still obey fairness.

---

## Final Review Verdict

### Scope Discipline

**Excellent**

### Authority Separation

**Excellent**

### Determinism

**Excellent**

### Boundedness

**Excellent**

### Failure Semantics

**Very Good**

### Operational Clarity

**Very Good**

### Network-Level Load Awareness

**Good, needs acknowledgement**

### Implementation Readiness

**Pass**

---

## Required Tightening Before Locked

1. Acknowledge deterministic hot-peer convergence
2. State Phase 1 favors correctness over sync speed
3. Clarify gentle RATE_LIMITED cooldown treatment
4. Clarify validation rejection semantics
5. Define advisory session lifetime explicitly
6. Mention bounded unique-peer retry horizon
7. Note empty scheduler output is valid and safe

---

## Final Verdict

This is the correct seventh primitive.

Selection chooses:

> who is eligible

Scheduling chooses:

> who is asked next

Still:

asked first is not trusted first.

That invariant survives.
