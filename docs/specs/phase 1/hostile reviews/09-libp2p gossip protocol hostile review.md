# Hostile Review — Zenon libp2p Gossip Protocol Specification

## Overall Assessment

Verdict: **Strong pass with a few operational clarifications**

This is the correct ninth Phase 1 specification.

The dependency chain remains coherent:

Host
→ Peer Service Discovery
→ Peer Reachability Verification
→ Peer Service Scoring
→ libp2p Sync Protocol
→ Sync Candidate Selection
→ Sync Request Scheduling
→ Initial Sync Strategy
→ libp2p Gossip Protocol

That progression is architecturally sound.

This specification gets the core invariant right:

> announcement is not object
> object is not acceptance
> repeated announcement is not truth

That is the spine of the document.

The strongest design decisions are:

* **authenticated envelope precedence**
* **payload identity never overrides authenticated transport**
* **cross-peer dedup**
* **fetch-after-announce goes through scheduler**
* **announcer not preferred by default**
* **publish only from accepted local state**
* **account-block gossip disabled by default**
* **wrong-network / wrong-genesis hard drop**

Those are exactly the right Phase 1 constraints.

---

## What Survives Attack

### 1. Authenticated Envelope Rule

Excellent.

Rule:

> authenticated transport identity wins
> always

Payload-declared sender identity is subordinate.

That kills:

* spoofed sender IDs
* forged envelope identities
* metadata identity confusion

This is the correct trust anchor.

This survives hostile review.

---

### 2. Announcement / Fetch / Validation Separation

Excellent.

Three-layer separation:

Announcement:

> possible availability

Fetch:

> bounded transport retrieval

Validation:

> acceptance decision

That prevents gossip from silently becoming acceptance logic.

Correct.

This survives hostile review.

---

### 3. Cross-Peer Dedup

Very strong.

Dedup key excludes sender identity.

Meaning:

50 peers announce same object → one fetch path

That prevents:

* fetch storms
* duplicate amplification
* redundant bandwidth burn

Excellent Phase 1 design.

This survives hostile review.

---

### 4. Announcer Neutrality

Strong.

Default:

```text id="p4n7qw"
PreferAnnouncerForFetch = false
```

Correct.

Announcer gets:

> no trust promotion

Otherwise:

announcement spam becomes:

> selection capture surface

Neutral default is right.

This survives hostile review.

---

### 5. Publish-Only-After-Acceptance

Excellent.

Node may publish only from:

> accepted local state

Not:

* fetched bytes
* decoded bytes
* peer-announced bytes
* likely-valid bytes

That blocks rumor amplification.

Correct.

This survives hostile review.

---

## Weaknesses

## 1. Dedup TTL Is Fixed and Crude

Current:

```text id="x2q8vd"
20 minutes
```

Reasonable default.

But:

* high-throughput network → maybe too long
* sparse network → maybe too short

Operational tuning likely needed.

Need explicit note:

> conservative default, implementation tuning expected

Otherwise feels pseudo-precise.

---

## 2. Tip Topic Can Become Noise

Tip announcements are advisory only.

Good.

But tips naturally churn frequently.

Even with:

```text id="m1t6rw"
12 / peer / minute
```

network-wide tip chatter may dominate.

Need stronger aggregation guidance:

> repeated equivalent tip announcements should collapse locally into one advisory signal window

Otherwise tip noise becomes overhead.

---

## 3. message_id Semantics Are Weakly Defined

Current:

> advisory only

Correct.

But implementers may accidentally treat message_id as:

* replay protection
* ordering proof
* uniqueness proof

Need explicit:

> message_id is informational correlation metadata only

Nothing more.

Clarify hard.

---

## 4. Publish Dedup TTL May Suppress Useful Rebroadcast

Current:

```text id="z7n4pk"
120 seconds
```

Good spam guard.

But:

late joiners may miss announcements.

Needs note:

> rebroadcast suppression is local anti-spam policy, not network-wide object lifetime policy

Clarify semantics.

---

## 5. Account-Block Gossip Disabled Is Correct But Sharp

Architecturally right.

Operationally:

future enablement boundary is vague.

Need one line:

> requires explicit future specification, not config-only activation

Otherwise operators may think:

> flip config = supported

Boundary needs clarity.

---

## Missing Abuse Cases

Need explicit handling for:

### Equivalent Tip Flood

Peer repeatedly announces same tip.

Need collapse / aggregation note.

---

### New Message ID Same Payload Spam

Different message IDs, identical payload.

Dedup mostly handles it.

Mention explicitly.

---

### Honest Hot Publisher

One fast node becomes dominant announcer.

Neutral fetch preference helps.

Mention this capture prevention directly.

---

### Restart Dedup Loss

Restart clears dedup cache → repeated fetches possible.

Acceptable, but should be acknowledged.

---

### Announcement Before Candidate Eligibility

Peer announces object before becoming sync-eligible.

Need explicit:

announcement may be remembered locally without immediate fetch.

Fetch later if eligible.

---

## Final Review Verdict

### Scope Discipline

**Excellent**

### Trust Separation

**Excellent**

### Identity Model

**Excellent**

### Flood Resistance

**Excellent**

### Publication Discipline

**Excellent**

### Operational Clarity

**Very Good**

### Noise Handling

**Good, needs explicit wording**

### Implementation Readiness

**Pass**

---

## Required Tightening Before Locked

1. Clarify dedup TTL is conservative default
2. Add repeated-equivalent tip aggregation note
3. Clarify message_id is correlation metadata only
4. Clarify publish dedup semantics
5. Explicitly state account-block gossip needs future spec
6. Mention dedup loss on restart is acceptable
7. Mention announcements may be remembered before peer eligibility

---

## Final Verdict

This is the correct ninth primitive.

Initial Sync handles:

> bounded catch-up

Gossip handles:

> live availability awareness

Still:

> announcement is not object
> object is not acceptance
> repetition is not truth

Validation remains authoritative.

That invariant survives.
