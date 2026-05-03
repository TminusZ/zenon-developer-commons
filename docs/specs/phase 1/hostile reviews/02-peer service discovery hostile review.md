# Hostile Review — Zenon Peer Service Discovery Specification

## Overall Assessment

Verdict: **Pass with targeted tightening**

This is a strong second specification.

The sequencing is correct:

Host → Discovery

That dependency chain is clean.

The document correctly treats discovery as:

> self-reported capability advertisement

not:

> proof
> trust
> economics
> verification
> routing authority

That architectural restraint is the biggest win.

The spec turns a connection substrate into a bounded local discovery layer without accidentally introducing consensus meaning, economic meaning, or privileged peer semantics.

That survives hostile review.

The remaining weaknesses are naming precision, metadata abuse edges, and a few underdefined operational boundaries.

---

## What Survives Attack

### 1. Consensus Isolation

Strong.

The specification cleanly blocks:

* consensus coupling
* chain-state writes
* reward interpretation
* validation-path influence
* sync-path influence
* routing authority
* ChainBridge access

Registry remains:

> local only
> bounded
> informational

Correct.

This survives hostile review.

---

### 2. Authenticated Identity Binding

Strong.

Registry key:

> authenticated libp2p peer ID

not:

> payload field

This avoids:

* forged registry IDs
* identity spoofing through protobuf fields
* metadata aliasing

This is the correct trust anchor.

This survives hostile review.

---

### 3. Bounded Registry Model

Strong.

Good constraints:

* max records
* max peers
* max services
* max metadata pairs
* max metadata sizes
* TTL expiry
* eviction order
* rate limiting

That prevents:

* unbounded memory growth
* metadata stuffing
* persistence bloat

This survives hostile review.

---

### 4. Correct Semantic Framing

Very strong.

Repeatedly reinforces:

> hints only

Not:

> proof of service
> proof of quality
> proof of uptime
> proof of honesty
> proof of reward eligibility

That keeps discovery from silently becoming a reputation layer.

Correct.

This survives hostile review.

---

### 5. Unknown Vocabulary Handling

Strong.

Unknown valid names:

> accepted as informational

not rejected.

That gives forward compatibility without protocol fragility.

Correct design.

This survives hostile review.

---

## Weaknesses

## 1. PUBLIC_RELAY Name Is Slightly Misleading

This is subtle.

PUBLIC_RELAY sounds like:

> verified public ingress point

But spec means:

> self-reported claim of accepting inbound connections

Those are very different.

Operators may overinterpret.

### Better options

Rename to:

* ACCEPTS_INBOUND
  or
* PUBLIC_ENDPOINT
  or
* INBOUND_AVAILABLE

Cleaner semantics.

Current name risks implied verification.

---

## 2. No Signature Over Service Payload

Service records rely on:

> authenticated channel identity

This is fine for live exchange.

But persisted records become:

> trust-by-storage artifact

Need explicit statement:

> persisted registry entries are cache only
> reconnect authentication remains authoritative

Otherwise implementers may overtrust persisted entries.

---

## 3. Timestamp Window Can Be Farmed

Current skew:

10 minutes

Replay within window remains possible.

Low risk because records are hints only.

Still:

malicious peer can replay old advertisement repeatedly within skew tolerance.

Need explicit wording:

newer valid record replaces older
older timestamp valid records must not overwrite newer local records

Monotonic freshness rule recommended.

---

## 4. Region / Operator Metadata Is Weakly Defined

Optional metadata examples:

* version
* listen_addr
* region
* operator_note
* uptime_hint

Some are vague.

Problem:

freeform strings become garbage fields.

Recommendation:

Either:

fully define allowed metadata schema

or:

remove suggested examples entirely

Underspecified metadata becomes junk drawer protocol.

---

## 5. Registry Persistence Is Still Too Optional

Same issue as Host.

Optional persistence creates implementation divergence.

Need explicit default:

Recommended:

> ephemeral registry
> rebuild on discovery

Cleaner deterministic behavior.

Persistence can be future optimization.

---

## Missing Abuse Cases

Need explicit handling for:

### Metadata Churn Spam

Peer repeatedly changes harmless metadata to refresh registry priority.

Mitigation:

last_seen and last_updated separation helps.

Good.

Need explicitly mention this abuse is intentional mitigation target.

---

### Identity Rotation Flood

Attacker rotates peer IDs.

Backoff and peer limits become weak.

Need IP / subnet / connection manager coupling note.

---

### Service Name Entropy Attack

Attacker advertises thousands of unique unknown valid names over time.

Even bounded entries create log / metric explosion.

Need observability cap or dedupe.

---

### Poisoned Bootstrap Advertising

Malicious bootstrap peers advertise attractive services.

Need explicit:

bootstrap advertisements have no privileged weighting.

---

## Final Review Verdict

### Scope Discipline

**Excellent**

### Isolation

**Excellent**

### Safety Boundaries

**Excellent**

### Registry Design

**Very Good**

### Abuse Hardening

**Good**

### Operational Precision

**Good, needs tightening**

### Implementation Readiness

**Pass**

---

## Required Tightening Before Locked

1. Clarify PUBLIC_RELAY naming or semantics
2. Add persisted-cache trust clarification
3. Add monotonic freshness overwrite rule
4. Define metadata schema more tightly or shrink it
5. Pick default registry persistence behavior
6. Mention identity-rotation abuse explicitly
7. Cap unknown-name observability churn

---

## Final Verdict

This is the correct second Phase 1 specification.

Host establishes connection.

Discovery establishes vocabulary.

Verification can now come next.

That progression is architecturally sound.
