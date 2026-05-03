# Zenon libp2p Gossip Protocol Specification

**Status:** Implementation Ready
**Scope:** Additive live-data availability announcements over libp2p libp2p
**Target:** go-zenon Phase 1
**Depends On:** libp2p Host Specification, Peer Service Discovery Specification, Peer Reachability Verification Specification, Peer Service Scoring Specification, libp2p Sync Protocol Specification, Sync Candidate Selection Specification, Sync Request Scheduling Specification, Initial Sync Strategy Specification, existing Zenon validation / acceptance logic
**Consensus Impact:** None
**Current P2P Impact:** None
**Economic Impact:** None
**Global Reputation Impact:** None

---

## Purpose

Initial sync catches a node up.

Gossip keeps a node aware of newly available live objects.

This specification defines:

* what may be announced
* how announcements are encoded
* how announcements are authenticated
* how duplicate announcements are suppressed
* how bounded fetch-after-announce works
* how scheduler caps remain authoritative
* how accepted local state becomes publishable
* how gossip observations feed local scoring and cooldown

Gossip does not define:

* fork choice
* canonicality
* trusted transport
* direct object acceptance
* current P2P replacement
* ChainBridge writes
* rewards
* slashing
* global reputation

---

## Core Rule

Gossip announces:

> possible availability

Sync fetches:

> bounded serialized objects

Validation decides:

> acceptance

A gossip announcement is:

> a compact claim that data may be available

It is not:

* the data
* proof the object exists
* proof the object is valid
* proof the object is canonical
* proof the announcing peer is honest

Announcement is signal only.

Trust remains unchanged.

---

## Design Goals

The gossip layer should:

1. Announce candidate availability without trusting announcements
2. Trigger bounded fetch-after-announce behavior
3. Suppress redundant fetches
4. Avoid announcement-triggered flooding
5. Respect scheduler caps / cooldowns
6. Publish only from accepted local state
7. Remain additive beside current P2P
8. Stay disableable
9. Produce local observations only
10. Keep topic and message formats versioned
11. Never write chain state directly
12. Never bypass validation

---

## Protocol Namespace

Protocol ID:

```text id="h4v8k2"
/zenon/gossip/1.0.0
```

Suggested topics:

```text id="2q6p9n"
/zenon/{network_id}/{genesis_hash}/momentum-announcements/1.0.0
/zenon/{network_id}/{genesis_hash}/tip-announcements/1.0.0
/zenon/{network_id}/{genesis_hash}/account-block-announcements/1.0.0
```

Rules:

* topic includes network ID
* topic includes genesis hash
* wrong-network topics ignored
* wrong-genesis topics ignored
* version mismatch is local protocol mismatch only
* topic mismatch has no consensus meaning

Account-block topic:

> disabled by default

---

## Message Types

Allowed:

* `MOMENTUM_ANNOUNCEMENT`
* `TIP_ANNOUNCEMENT`
* `ACCOUNT_BLOCK_ANNOUNCEMENT`

Unknown message types:

> ignore

Repeated unknown spam:

> local rate-limit observation only

No disconnect required by default.

---

## Authenticated Envelope

All gossip messages must use a versioned authenticated envelope.

Suggested protobuf:

```proto id="4v1x7m"
message GossipEnvelope {
  uint32 version;
  string network_id;
  bytes genesis_hash;
  bytes sender_peer_id;
  uint64 unix_time;
  uint64 message_id;

  oneof payload {
    MomentumAnnouncement momentum;
    TipAnnouncement tip;
    AccountBlockAnnouncement account_block;
  }
}
```

Rules:

* version must match
* network_id must match local network
* genesis_hash must match local genesis
* authenticated transport peer identity required
* envelope sender_peer_id must match authenticated peer ID
* exactly one payload required
* message_id advisory only
* unix_time advisory only

If:

```text id="7w3f6c"
sender_peer_id != authenticated_peer_id
```

then:

> drop message
> record local observation
> do not fetch

Payload identity never overrides authenticated identity.

Authenticated transport identity wins.

Always.

---

## Timestamp Policy

Timestamp is:

> advisory freshness metadata

Timestamp is not:

* consensus time
* object acceptance time
* replay protection

Suggested defaults:

```text id="8j2r5d"
max_clock_skew = 2 minutes
max_message_age = 10 minutes
dedup_ttl = 20 minutes
```

Rules:

* too far future → drop
* too old → drop
* stale timestamps may create local observation
* timestamp failure does not create global punishment

Fresh timestamp ≠ trustworthy object.

---

## Configuration

```go id="9x4c7n"
type GossipConfig struct {
    FetchAnnouncedMomentum     bool
    FetchAfterTipAnnouncement  bool
    PreferAnnouncerForFetch    bool

    AccountBlockGossipEnabled bool

    MaxMessagesPerPeerPerMinute uint32
    MaxAnnouncementsPerObject   uint32

    MaxFetchesPerMinute         uint32
    MaxFetchesPerPeerPerMinute  uint32
    MaxTipAnnouncementsPerMinute uint32

    MaxClockSkewSeconds uint64
    MaxMessageAgeSeconds uint64
    DedupTTLSeconds uint64
    PublishDedupTTLSeconds uint64
}
```

Suggested defaults:

```text id="6m9k1v"
FetchAnnouncedMomentum = true
FetchAfterTipAnnouncement = false
PreferAnnouncerForFetch = false

AccountBlockGossipEnabled = false

MaxMessagesPerPeerPerMinute = 120
MaxAnnouncementsPerObject = 32

MaxFetchesPerMinute = 60
MaxFetchesPerPeerPerMinute = 10
MaxTipAnnouncementsPerMinute = 12

MaxClockSkewSeconds = 120
MaxMessageAgeSeconds = 600
DedupTTLSeconds = 1200
PublishDedupTTLSeconds = 120
```

Invalid config:

> service start fails locally

No fallback.

No consensus effect.

---

## Announcement Model

Announcement lifecycle:

1. receive
2. authenticate envelope
3. validate topic / network / genesis
4. validate timestamp
5. deduplicate
6. rate-limit
7. policy check
8. optionally schedule bounded fetch
9. fetched payload goes through validation / acceptance
10. accepted objects may later become publishable

Gossip must not:

* open sync streams directly
* bypass scheduler
* bypass validation
* advance accepted state directly

---

## Momentum Announcements

May publish only after:

> local momentum acceptance

Must not publish:

* unvalidated momentum
* merely fetched momentum
* peer-announced momentum
* guessed momentum state

Inbound momentum announcement:

* verify envelope
* verify fields syntactically
* deduplicate
* apply rate limits
* optionally trigger:

```text id="5n8w2q"
GET_MOMENTUM_BY_HASH
```

Inbound announcement alone:

> changes nothing accepted locally

---

## Tip Announcements

Tip announcements are:

> advisory only

Inbound tip announcement may:

* record advisory observation
* optionally schedule:

```text id="0q4t7h"
GET_PEER_TIP
```

Inbound tip announcement must not:

* advance local accepted height
* choose fork
* trigger canonicality decision
* write ChainBridge state

Tip disagreement:

> advisory divergence only

Not peer dishonesty proof.

---

## Account-Block Announcements

Default:

```text id="3d7p1m"
disabled
```

Account-block gossip requires explicit source verification before enablement.

Until then:

* do not subscribe
* do not publish
* do not fetch
* drop inbound account-block announcements safely

No partial enablement.

---

## Deduplication

Object-level dedup key:

* message type
* announced hash
* announced height when applicable
* network ID
* genesis hash

Not included:

> sender peer ID

Reason:

> cross-peer duplicate suppression

If 50 peers announce same object:

> one dedup object record

not 50 fetches.

Dedup tracks:

* first seen
* last seen
* unique peer count
* fetch attempted
* fetch accepted
* fetch rejected

Duplicate announcements:

> update counters only
> do not trigger repeated fetches

Dedup state is:

* bounded
* local-only
* disposable on restart
* non-consensus

---

## Fetch-After-Announce

Mapping:

```text id="1k6v9s"
MOMENTUM_ANNOUNCEMENT -> GET_MOMENTUM_BY_HASH
TIP_ANNOUNCEMENT -> optional GET_PEER_TIP
ACCOUNT_BLOCK_ANNOUNCEMENT -> disabled by default
```

Rules:

Fetch must:

* go through Sync Request Scheduling
* obey candidate selection
* obey scheduler caps
* remain bounded
* skip already accepted local objects

Fetch must not:

* open direct stream
* bypass scheduler
* bypass cooldown
* force announcer selection
* trust returned payload automatically

---

## Announcer Preference

Default:

```text id="2t5m8q"
PreferAnnouncerForFetch = false
```

Meaning:

> announcer receives no automatic preference

If enabled:

> announcer may receive local ordering preference only if already eligible

Announcer must never bypass:

* candidate selection
* reachability policy
* scoring policy
* scheduler cooldown
* validation boundary

No announcer-exclusive fetch exists in Phase 1.

---

## Rate Limits

Suggested defaults:

```text id="7p1w4n"
120 messages / peer / minute
32 unique announcers / object / TTL
60 gossip-triggered fetches / minute
10 gossip-triggered fetches / peer / minute
12 tip announcements / peer / minute
```

Excess:

* drop or aggregate
* record local observation
* optionally apply local cooldown

Never:

* global punishment
* slashing
* rewards
* consensus meaning

Local spam protection only.

---

## Validation Boundary

Gossip validates:

* envelope version
* network ID
* genesis hash
* authenticated peer identity
* timestamp bounds
* payload syntax
* dedup policy
* rate-limit policy

Gossip does not validate:

* chain acceptance
* canonicality
* fork choice
* reward eligibility
* slashing eligibility

Fetched payload remains:

> untrusted serialized data

Existing validation / acceptance remains authoritative.

---

## Scheduler Interaction

Gossip-triggered fetches consume scheduler outcomes.

Examples:

* no candidates → local observation
* all candidates failed → local observation
* budget exhausted → local observation
* advisory divergence → local observation
* validation rejected → local observation

These are:

> local operational outcomes

Not peer dishonesty proof.

---

## Publish Policy

A node may publish only from:

> accepted local state

Default publishable:

* accepted momentum
* accepted local tip state

Not publishable by default:

* account blocks
* unvalidated objects
* merely fetched objects
* peer-announced objects
* guessed state

Publish is:

* deduplicated
* rate-limited
* topic-validated
* network/genesis bound

Accepted local state only.

Nothing else.

---

## Topic Subscription Policy

Default:

* momentum topic → enabled
* tip topic → enabled
* account-block topic → disabled

Subscribe only when:

* local network known
* local genesis known
* topic encoding valid

Wrong network / genesis:

> unsubscribe or ignore

Subscription failure:

> local protocol failure only

No consensus meaning.

---

## Security Rules

Must enforce:

* authenticated identity precedence
* wrong-network drop
* wrong-genesis drop
* bounded dedup state
* bounded rate limits
* scheduler-only fetch
* validation-before-acceptance
* accepted-state-only publishing
* no announcer trust promotion
* local-only observations

Must not:

* accept objects directly
* define fork choice
* replace current P2P
* write ChainBridge state
* create rewards
* create slashing
* create global reputation

---

## Abuse Cases

Mitigations exist for:

* announcement floods
* fake availability claims
* wrong-network gossip
* sender identity spoofing
* tip spam
* cross-peer duplicate storms
* announcer capture attempts
* malformed local publish attempts

All outcomes remain:

> local protocol handling only

Never consensus events.

---

## Final Rule

Gossip announces:

> possible availability

Sync fetches:

> bounded objects

Validation decides:

> acceptance

Still:

> announcement is not object
> object is not acceptance
> repeated announcement is not truth

Validation remains authoritative.
