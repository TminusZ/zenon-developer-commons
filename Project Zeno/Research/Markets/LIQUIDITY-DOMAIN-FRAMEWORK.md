# Project Zeno: Liquidity Domain Framework

**Document status:** Frontier research. Non-normative. No implementation claims. No roadmap commitments. No tokenomics. No governance proposals.
**Version:** 0.1.0
**Governing documents (in priority order):**

1. `SPEC.md` v1.3.0 (the controlling authority for all on-chain rules)
2. `BRIDGE-FRAMEWORK-SPEC.md` v0.2.0 (the Bridge Framework normative specification)
3. `EXECUTION-PROVIDER-FRAMEWORK.md` v0.1.0 (the Execution Provider architecture)
4. `INTENT-ORDERFLOW-FRAMEWORK.md` v0.1.0 (the Intent and Orderflow architecture)
5. `ECONOMIC-SECURITY-FRAMEWORK.md` v0.1.0 (the Economic Security architecture)
6. `SERVICE-DOMAIN-FRAMEWORK.md` v0.1.0 (the Service Domain architecture)
7. `MARKET-FRAMEWORK.md` v0.1.0 (the Market architecture)

This document is Frontier research. It does not make implementation claims, introduce new protocol features, propose token economics, or bind any deployment. Every speculative mechanism is explicitly marked. Where this document references a mechanism defined in a governing document, the governing document controls.

**Purpose:** The Market Framework introduced, and deliberately left unspecified, the concept of a Liquidity Domain (`MARKET-FRAMEWORK.md` §15.5). This document defines that architecture. A Liquidity Domain is not a DEX, not an AMM, not a lending protocol, not a stablecoin, and not an implementation. It is an architectural pattern for hosting liquidity infrastructure inside an isolated, Settlement-backed domain.

**Boundary discipline:** This document does not redefine Settlement, the Service Domain pattern, or any concept already specified in the Market Framework. It applies those patterns specifically to liquidity. Where a concept (bonds, reputation, competition, custody modes, conservation) is already governed elsewhere, this document cites it rather than restating it.

**Commit discipline:** Settlement never owns liquidity, never prices assets, never allocates capital, never lends, never borrows, and never performs market making. A Liquidity Domain is not Settlement. It is simply another domain, registered, committed, and finalized exactly as any other domain. If any mechanism described here would require Settlement Core to make a liquidity decision, the mechanism is wrong; it belongs in the domain's STF, not in Settlement.

---

## 1. Why this document exists

### 1.1 Where the Market Framework stopped

The Market Framework established three things: Settlement determines truth; markets determine value; and markets may optionally be implemented as Service Domains without that implementation becoming Settlement (`MARKET-FRAMEWORK.md` §15.1, §15.2). Having established that a market-as-domain remains categorically a market and not Settlement, it named a natural next category, the Liquidity Domain, and stopped (`MARKET-FRAMEWORK.md` §15.5). It defined no STF, no input vocabulary, no economic model, no custody mode. That was deliberate: the Market Framework's job was to establish the boundary, not to furnish the room behind it.

### 1.2 A different question than price

Markets answer: what is X worth, right now (`MARKET-FRAMEWORK.md` §2.2)? That is a valuation question. It presupposes something more basic: that capital capable of transacting at that value actually exists, somewhere, ready to be drawn upon. A market can discover a perfectly accurate price for an asset that nobody can currently trade, because no capital is positioned to take the other side. Price discovery and capital availability are different questions, answered by different mechanisms, and conflating them is as much a category error as conflating truth with value was the subject of the prior document.

This document answers the availability question: where does the capital markets need actually come from, how is it tracked once it arrives, and how is it made available, consumed, and returned? That is liquidity, treated as infrastructure rather than as the abstract concept the Market Framework defined (`MARKET-FRAMEWORK.md` §6).

### 1.3 Scope

This document defines the Liquidity Domain as an architectural pattern: its properties, its relationship to Settlement, the categories of capability it may host, the shape of the state it manages, its lifecycle, its communication surface, its isolation guarantees, and its economic relationship to the participants described in the Economic Security Framework. It does not design an AMM, a lending market, a stablecoin, or any specific protocol. Every concrete mechanism mentioned is a category, marked as such, not a specification.

---

## 2. What is a Liquidity Domain?

### 2.1 Definition

A **Liquidity Domain** is a Service Domain (`SERVICE-DOMAIN-FRAMEWORK.md` §2.1) specialized in hosting liquidity infrastructure: the state, accounting, and allocation logic that tracks capital positioned for market use. Its STF manages liquidity state (§5); Settlement merely commits its outputs, exactly as Settlement commits the outputs of any domain without understanding what that domain computes (`SERVICE-DOMAIN-FRAMEWORK.md` §2.3).

A Liquidity Domain is not a new domain class. It is registered, bonded, committed, and finalized identically to any other domain (`SPEC.md` §6; `SERVICE-DOMAIN-FRAMEWORK.md` §5). The specialization is entirely inside the plugin, as it is for every Service Domain.

### 2.2 What makes it distinct among Service Domains

The Service Domain Framework's worked examples (`SERVICE-DOMAIN-FRAMEWORK.md` §14) gave Oracle, Identity, Storage, Payment, AI Compute, and Messaging Domains. A Liquidity Domain is distinguished from each of these by one property: it is the domain type whose primary job is to hold capital at rest, persistently, as deployable inventory, rather than to produce information, credentials, commitments, or capital merely in transit.

| Domain type | Primary product | Holds capital at rest? | Typical Execution Provider need |
|---|---|---|---|
| Oracle Domain | Aggregated information (prices) | No | No |
| Identity Domain | Credentials, attestations | No | No |
| Storage Domain | Data commitments | No (the blob is off-chain; only a hash is committed) | No |
| Payment Domain | Completed payments | Transiently, in transit | Yes, for cross-chain delivery |
| **Liquidity Domain** | **Available, deployable capital** | **Yes, persistently** | **No (Execution Providers are consumers, not enablers)** |

This is the defining characteristic: a Liquidity Domain's state is, in large part, a ledger of capital sitting in the domain, waiting to be allocated. No other Service Domain type in the prior taxonomy has that as its central function.

### 2.3 The general claim

Liquidity naturally fits the Service Domain architecture because everything a liquidity ledger needs (deterministic tracking so depositors can trust their recorded balance, replay protection so a withdrawal cannot be claimed twice, an auditable history so a dispute over "did I deposit X" resolves from data rather than from trust, isolation so a bug cannot reach unrelated capital, and an independent upgrade cadence so the allocation logic can improve without touching anything else) is precisely the property set a Service Domain already provides (`SERVICE-DOMAIN-FRAMEWORK.md` §3.1). Liquidity management is not a strange new requirement bolted onto the domain model; it is close to the canonical case the model was built for.

---

## 3. Liquidity vs Settlement

### 3.1 The five-way distinction

Five things are easy to conflate and must not be: Settlement escrow, market liquidity, provider inventory, capital pools, and credit.

| Concept | What it is | Bounded by | Can it be deployed, lent, or pooled? |
|---|---|---|---|
| **Settlement escrow** | Custody held under a domain's `ESCROW` mode | Conservation: `totalReleased + pendingWithdrawalReserve ≤ totalDeposited` (`BRIDGE-FRAMEWORK-SPEC.md` §13.7) | No; it exists solely to back authorized releases one-for-one |
| **Market liquidity** | Capital committed to a venue, immediately available for transactional use | Market dynamics, not conservation (`MARKET-FRAMEWORK.md` §6.1) | Yes; this is its purpose |
| **Provider inventory** | A single participant's own, owned, pre-positioned capital | The participant's own balance sheet (`MARKET-FRAMEWORK.md` §8.1) | Yes, by that participant alone |
| **Capital pools** | Liquidity aggregated from many depositors, accessed by many consumers | Whatever allocation logic the pool implements | Yes; this is the multi-party generalization of inventory |
| **Credit** | The extension of value now against a promise of value later | Trust, collateral, or legal recourse, never conservation (`MARKET-FRAMEWORK.md` §7.2) | Not capital at all; a temporal claim |

A Liquidity Domain typically hosts the middle three (market liquidity, generalized as either inventory-like or pool-like, and sometimes credit relationships built on top of either). It never hosts the first, because Settlement escrow is not deployable by definition, and any attempt to make it deployable would break the conservation invariant that defines it.

### 3.2 Why Settlement cannot host liquidity, even via a domain

Settlement's conservation invariant is a cross-domain, protocol-wide guarantee that must hold by construction for the entire network (`BRIDGE-FRAMEWORK-SPEC.md` §13.7). A guarantee of that kind cannot tolerate under-collateralization, market-timing exposure, or withdrawal-availability risk anywhere inside its own logic, for the same reason the Market Framework argued Settlement cannot tolerate price volatility inside its own logic (`MARKET-FRAMEWORK.md` §2.2): these are properties that vary continuously and must be allowed to vary, while Settlement's value comes precisely from not varying.

A Liquidity Domain's internal accounting is different in kind, not just in degree. It is local, isolated, and itself subject to ordinary domain isolation (`SERVICE-DOMAIN-FRAMEWORK.md` §7): if a domain's internal claims become momentarily unbacked, that is a local, market-level risk, fully contained by isolation and never propagating to Settlement's protocol-wide guarantee. Settlement Core never holds, prices, or allocates that capital; the domain's STF does. A Liquidity Domain is still liquidity, not Settlement, by exactly the same Core-versus-plugin argument the Market Framework used for markets-as-domains (`MARKET-FRAMEWORK.md` §15.2).

### 3.3 What conservation does and does not reach

If a Liquidity Domain uses `ESCROW` custody for its own Settlement-anchored deposits, that domain remains fully conservation-bound at that boundary, exactly as any domain does: its aggregate authorized outflow can never exceed its aggregate accounted inflow (`BRIDGE-FRAMEWORK-SPEC.md` §13.7). What conservation does not, and cannot, reach is the domain's internal allocation of claims on that aggregate. Whether a lending domain extends credit against collateral at a 60% ratio or a 150% ratio is a question about who, within the domain, holds what claim on the domain's own pooled capital; it is not a question about whether the domain as a whole releases more than it received from Settlement. The domain's STF is free to implement any internal allocation logic, over-collateralized, under-collateralized, reputation-scored, or otherwise, bounded only by domain isolation (the worst case is that domain's own capital is impaired) and never by Settlement's cross-domain guarantee.

This is also the answer to an apparent contradiction: §7.2 of the Market Framework states that Settlement has no concept of credit, because conservation makes undercollateralized exposure structurally impossible at the protocol level. A Liquidity Domain implementing a lending facility does not contradict this. The credit relationship exists between the domain's own depositors and borrowers, tracked in the domain's own state. Settlement is never exposed to it; Settlement sees only the domain's committed roots and, if the domain uses `ESCROW` mode for any of its own deposits, the domain's own fully-collateralized custody at that specific boundary.

---

## 4. What can live inside a Liquidity Domain?

The following are categories of capability a Liquidity Domain's STF may host. None is designed here; each is named only to establish the breadth of what the pattern accommodates.

**AMM infrastructure.** A deterministic pricing curve over pooled assets, where deposits become claims on the pool and trades shift its composition. (Also a market structure in the Market Framework's sense, `MARKET-FRAMEWORK.md` §9.1; §11 below addresses the overlap.)

**Lending infrastructure.** Deposited collateral and borrowed positions, with interest accrual and liquidation logic entirely internal to the domain's state.

**RFQ liquidity pools.** Standing, executable inventory exposed to a quoting process rather than a continuous curve, where providers commit capital that responders can draw against (`INTENT-ORDERFLOW-FRAMEWORK.md` §5).

**Inventory coordination.** Logic that helps multiple participants, particularly solvers (`EXECUTION-PROVIDER-FRAMEWORK.md` §7.2), signal and position capital across venues without centralizing custody.

**Market making.** Automated or semi-automated quoting logic that continuously offers both sides of a market from the domain's own pooled or allocated capital.

**Liquidity routing.** Logic that does not hold capital itself but indexes and directs consumption requests toward whichever venue, internal or external, offers the best terms.

**Vaults.** Capital deposited under a defined strategy or mandate, with depositor claims tracked as shares of the vault's evolving value.

**Collateral accounting.** Tracking of posted collateral against obligations, whether for lending, derivatives, or any other contingent claim.

**Pooled capital.** The general case of capital aggregated from many depositors and accessed by many consumers, underlying AMMs, lending pools, and vaults alike.

**Auction liquidity.** Capital committed specifically to participate in periodic or batch price-discovery events (`MARKET-FRAMEWORK.md` §9.1).

**Credit facilities.** Standing arrangements that extend credit (§3.3) against collateral, reputation, or bond, with the credit relationship held entirely within the domain's own state.

None of these is a protocol primitive. Each is a category of STF logic a domain operator may choose to build, subject to the properties and constraints the rest of this document describes.

---

## 5. Liquidity State

### 5.1 What liquidity state consists of

A Liquidity Domain's state is, structurally, a ledger. The categories below name what such a ledger typically tracks. None belongs in Settlement; all of it lives in the domain's own isolated state (`SERVICE-DOMAIN-FRAMEWORK.md` §3.1).

**Available liquidity.** Capital currently unallocated and ready for immediate use.

**Reserved liquidity.** Capital earmarked for a specific pending operation (a quote awaiting acceptance, a fill in progress) but not yet consumed.

**Locked liquidity.** Capital committed for a defined period or condition (a vault lockup, collateral posted against an open position) and unavailable for other use until release.

**Provider balances.** Each depositor's individual claim on the domain's pooled or allocated capital.

**Vault accounting.** The evolving relationship between a vault's total value and the shares depositors hold against it.

**Collateral.** Capital posted to secure an obligation, tracked separately from the obligation it secures.

**Claims.** Any depositor's or counterparty's entitlement to a future distribution, withdrawal, or settlement from the domain's state.

**Fees.** Accrued compensation for liquidity provision, routing, or market making, however the domain's STF chooses to calculate and distribute it.

**Positions.** A participant's net exposure within the domain, whether a pool share, a loan, a collateral posting, or a standing quote.

### 5.2 Where this state lives

All of it is ordinary domain state, held in the domain's own SMT, committed through the domain's own batch commitments, and replay-protected exactly as any domain's inputs are (`SPEC.md` §4.6). Settlement records the domain's roots and enforces the domain's own conservation boundary where one applies (§3.3). It has no visibility into, and no opinion on, what "available," "reserved," or "locked" mean inside that state; those are STF-defined categories, not protocol-defined ones.

---

## 6. Liquidity Lifecycle

### 6.1 A lifecycle nested inside Operate

The Service Domain Framework's lifecycle (Design, Build, Register, Deploy, Operate, Upgrade, Retire, Migration, Fork, Deprecation; `SERVICE-DOMAIN-FRAMEWORK.md` §5.1) describes the domain's own existence. This section describes a different, narrower lifecycle: what happens to a specific unit of capital while the domain is in its Operate stage.

**Capital deposited.** A participant moves capital into the domain. If this crosses Settlement-anchored custody (`ESCROW` mode), Settlement records the deposit and the domain's conservation counters update accordingly (`BRIDGE-FRAMEWORK-SPEC.md` §18.2-equivalent accounting, generalized in `BRIDGE-FRAMEWORK-SPEC.md` §13.7). If the domain operates entirely on assets already native to it, no Settlement-anchored custody event occurs at all; only the domain's own state changes.

**Capital becomes liquidity.** The deposit is recorded against a provider balance, a vault share, or a pool position (§5.1), converting a stock of capital into positioned, available liquidity (`MARKET-FRAMEWORK.md` §6.1).

**Liquidity allocated.** The domain's STF assigns available liquidity to a specific use: a quote, a loan, a swap counterparty, a market-making position.

**Liquidity consumed.** A counterparty (often an Execution Provider, §10) draws on the allocated liquidity to complete a transaction.

**Liquidity replenished.** Fees, interest, or returned principal flow back into the pool, vault, or provider balance, restoring available liquidity for future allocation.

**Liquidity withdrawn.** A depositor redeems their claim. If this crosses back out through Settlement-anchored custody, the domain's release is subject to the same conservation check as any withdrawal (§3.3). If it does not, only the domain's own state changes.

### 6.2 Settlement's role throughout

Settlement never participates in the liquidity decisions: which deposits are accepted, how capital is allocated, what rate or price applies, who may withdraw and when. What Settlement does, as with any domain, is anchor the resulting state commitments (§2.1). The distinction is exact: Settlement commits the outputs of this lifecycle; it never makes any choice within it.

---

## 7. Liquidity Communication

### 7.1 The same rule as every Service Domain

A Liquidity Domain communicates exactly as the Service Domain Framework specifies: through Settlement, never directly (`SERVICE-DOMAIN-FRAMEWORK.md` §6.1). No new communication mechanism is introduced here. Outbox messages, finalized authorizations, and authenticated inputs (`SERVICE-DOMAIN-FRAMEWORK.md` §6.2) carry liquidity-domain traffic exactly as they carry any other domain's traffic.

### 7.2 Execution Providers

Execution Providers consume liquidity (§10) the same way they consume any external source, by submitting inputs to the domain (a swap, a quote acceptance, a draw against a credit facility) and receiving the domain's effects in return. This is the direct, concrete instance of the `Liquidity Pool` execution profile already named in the Execution Provider Framework (`EXECUTION-PROVIDER-FRAMEWORK.md` §4.7): a Liquidity Domain is what that profile draws from.

### 7.3 Markets

A market structure (`MARKET-FRAMEWORK.md` §9) and a Liquidity Domain are not always the same thing, but they are not mutually exclusive either; §11 addresses this directly. Where a market structure is implemented as a domain that also holds capital at rest, the two descriptions apply to the same infrastructure simultaneously.

### 7.4 Service Domains generally

A Liquidity Domain may compose with other Service Domains exactly as the Service Domain Framework's composition pattern describes (`SERVICE-DOMAIN-FRAMEWORK.md` §12): an oracle domain supplying a reference price, a payment domain drawing conversion liquidity, an identity domain gating access to a permissioned facility. Each remains independent; the Liquidity Domain owns none of them, and none of them owns it.

### 7.5 Intents

Some Liquidity Domains consume Intents directly: a domain exposing an RFQ-style facility naturally receives quote requests from the Intent layer's discovery process (`INTENT-ORDERFLOW-FRAMEWORK.md` §5). Others are purely infrastructure-level and never see an Intent at all, in the same category as a DA domain or an indexing domain (`SERVICE-DOMAIN-FRAMEWORK.md` §10.3): a routing domain or an inventory-coordination domain may be consumed only by other system components, never by a user-facing Intent.

### 7.6 Bridge Domains

A Liquidity Domain may compose with one or more bridge domains to position capital across foreign chains (the Cross-chain Liquidity Domain worked example, §13), using the Bridge Framework's seams (`BRIDGE-FRAMEWORK-SPEC.md` §7.3, §7.5) without altering them.

---

## 8. Liquidity Isolation

### 8.1 The same guarantee, applied to capital

The Service Domain Framework's isolation guarantee states that a fault in one domain can never reach another domain's custody, state, or lineage (`SERVICE-DOMAIN-FRAMEWORK.md` §7.1). For a Liquidity Domain, where the state in question is capital rather than information, this guarantee is the difference between a contained loss and a systemic one.

### 8.2 Why an AMM bug cannot affect a lending domain

An AMM domain and a lending domain, if separately registered, hold separate SMTs, maintain separate conservation counters for any `ESCROW`-mode assets they each hold, and are served by separate bonded executor sets (`SERVICE-DOMAIN-FRAMEWORK.md` §7.3). A bug in the AMM domain's curve logic, however severe, cannot write to the lending domain's state, cannot debit its custody, and cannot alter its conservation accounting. The worst the AMM bug can do to the lending domain is fail to deliver an asset the lending domain was expecting through an ordinary, validated, asynchronous message, a liveness problem the lending domain's own STF must be written to tolerate, not a state-corruption problem Settlement must guard against.

### 8.3 Insolvency remains domain-local

If a Liquidity Domain's internal accounting becomes insolvent (collateral value falls below outstanding loans, a pool is drained by an exploit, a vault's strategy fails), the loss is borne by that domain's own depositors and claimants. This cannot cascade to: Settlement's conservation guarantee for any domain, since conservation is enforced per `(domainId, asset)` (`BRIDGE-FRAMEWORK-SPEC.md` §13.7); any other domain's custody or state, by isolation (§8.2); or Settlement's truth guarantees for any unrelated authorization. It can, and does, affect the specific participants who held a claim on that specific domain's capital, exactly as the Economic Security Framework's failure-economics pattern describes for every other failure mode in the stack: the damage is real, and it is contained (`ECONOMIC-SECURITY-FRAMEWORK.md` §9.3, "Settlement is unaffected").

---

## 9. Liquidity Economics

### 9.1 Reference, not redefinition

The Economic Security Framework already defines the trust models (`ECONOMIC-SECURITY-FRAMEWORK.md` §3), the participant security models for market makers and liquidity providers specifically (`ECONOMIC-SECURITY-FRAMEWORK.md` §4.5, §4.6), the bond models (`ECONOMIC-SECURITY-FRAMEWORK.md` §5), reputation (§6), and competition (§7). None of it is redefined here.

### 9.2 Applying it to a Liquidity Domain

A depositor into a Liquidity Domain relies on the same layered assurance any domain participant relies on: cryptographic correctness from the domain's execution profile (an `OPTIMISTIC` or `ZK_VALIDITY` domain gives depositors a fraud-provable or proof-verified guarantee on the STF's correctness, `BRIDGE-FRAMEWORK-SPEC.md` §6.3), plus whatever bonding, reputation, or insurance the specific facility chooses to layer on top of that (`ECONOMIC-SECURITY-FRAMEWORK.md` §5, §6, §10). Which of these a given Liquidity Domain uses, and in what combination, is an Economic Profile choice (`ECONOMIC-SECURITY-FRAMEWORK.md` §13), made by whoever stands the domain up, not by this document.

### 9.3 Vault depositors and capital providers

The Economic Security Framework's existing participant models cover market makers and liquidity providers directly. Two further roles common inside Liquidity Domains specifically are worth naming, without introducing new trust categories: a **vault depositor** holds a claim on a strategy's evolving value rather than on a fixed pool share, so the depositor's primary exposure is to the strategy's own correctness and the STF's faithful accounting of it (§5.1, vault accounting), an instance of the same cryptographic-correctness reliance as §9.2. A **capital provider** in the treasury or institutional sense (§13) supplies capital under governance or contractual terms external to the domain itself; the domain enforces the resulting allocation deterministically, but the terms under which the capital was committed are a legal or social trust relationship (`ECONOMIC-SECURITY-FRAMEWORK.md` §3.1), not a protocol one. Neither role requires a new entry in the Economic Security Framework's taxonomy; both are instances of existing categories applied to liquidity-specific state.

### 9.4 Fees and yield, named but not specified

Fees and yield are domain-specific STF logic, falling under "pooled capital" and "collateral accounting" in §4. Their rate, distribution mechanism, and denomination are deployment-level choices, exactly as the Execution Provider Framework declined to assign bond denominations (`EXECUTION-PROVIDER-FRAMEWORK.md` §10.3) and the Economic Security Framework declined to assign bond sizes or token economics (`ECONOMIC-SECURITY-FRAMEWORK.md` §5.4). This document does the same: fees and yield are named as a category liquidity infrastructure typically includes, and nothing about their economics is specified.

---

## 10. Liquidity and Execution Providers

### 10.1 Customers, not owners

Execution Providers consume liquidity. They are customers of a Liquidity Domain, not owners of Settlement, and not owners of the domain either. An Execution Provider's relationship to a Liquidity Domain is the same kind of relationship any user has: it submits inputs (a swap, a draw, a quote acceptance) and receives the domain's effects. The Execution Provider is simply a more frequent, more sophisticated customer than an individual user typically is.

### 10.2 One source among several

The Execution Provider Framework already enumerates where liquidity comes from: a provider's own inventory, on-chain pools, OTC and institutional capital, and other bridges (`EXECUTION-PROVIDER-FRAMEWORK.md` §5.2). A Liquidity Domain is one more entry in that list, distinguished only by being Settlement-anchored, auditable, and deterministically replayable (`MARKET-FRAMEWORK.md` §15.3), properties an off-chain pool or a private OTC desk does not automatically have. It does not replace the other sources; it is simply one of them, and Execution Providers remain free to source from whichever combination serves a given fill best.

---

## 11. Liquidity and Markets

### 11.1 Two different questions, sometimes one answer

Markets discover prices (`MARKET-FRAMEWORK.md` §2, §4). Liquidity Domains provide deployable capital (§5, §6). Neither replaces the other: a market with no liquidity behind it produces prices nobody can transact at; liquidity with no market discovering a price for it sits idle, with no signal for how it should be used.

### 11.2 The same domain, two lenses

An AMM domain is the clearest case where these two descriptions apply to the same infrastructure at once. Viewed through the Market Framework's lens, it is a market structure: its curve discovers a price on every trade (`MARKET-FRAMEWORK.md` §9.1). Viewed through this document's lens, it is a Liquidity Domain: its pool holds capital at rest, tracks provider claims, and allocates liquidity to each trade (§2.2, §5). These are not two competing classifications requiring a tiebreaker; they are two complementary architectural treatments of one domain, exactly as a single object can be described by its geometry and by its material without either description being wrong.

### 11.3 Not coextensive

The two concepts overlap without being identical. An OTC desk or a bilateral order book needs no pooled liquidity infrastructure at all; two parties trade their own inventory directly (`MARKET-FRAMEWORK.md` §9.1), so a market can exist with no Liquidity Domain behind it. Conversely, a pure vault or treasury domain (§13) may hold and allocate capital with no independent price-discovery function of its own, instead consuming prices discovered elsewhere (an oracle domain, `SERVICE-DOMAIN-FRAMEWORK.md` §14.1), so a Liquidity Domain can exist with no market function of its own. The two categories intersect; neither contains the other.

---

## 12. Liquidity as Infrastructure

### 12.1 Infrastructure, not application

An application asks: what does this specific pool, this specific lending market, this specific vault do? Infrastructure asks a different question: what capability does the network now have, that any future application can draw on? The distinction matters because it changes what gets built next. Treated as an application, "liquidity" means one more DEX competing for the same flow as every other DEX. Treated as infrastructure, liquidity means a capability class, available to a payment domain needing conversion capital, to a bridge domain's solver needing reimbursement, to a treasury domain needing a venue to deploy idle capital, none of which had to build their own pool, their own accounting, or their own isolation guarantees to get it. Every section of this document, the state categories (§5), the lifecycle (§6), the isolation guarantees (§8), describes infrastructure properties: things that are true of the capability regardless of which specific facility implements it. None of it describes what any one facility should do with users' money. That is the line this document holds.

### 12.2 Beyond pools and DEXs

Generalized properly, liquidity becomes programmable infrastructure: not a single DEX, not a single lending app, but a capability class the network can host, compose, and improve independently, in exactly the sense the Service Domain Framework treats oracles, identity, and storage as capability classes rather than as one-off applications (`SERVICE-DOMAIN-FRAMEWORK.md` §2.1, §13).

### 12.3 A shared layer other domains draw on

Just as an Oracle Domain becomes the network's shared layer for external prices, available for any domain to consume (`SERVICE-DOMAIN-FRAMEWORK.md` §14.1, §12.2), a Liquidity Domain becomes the network's shared layer for capital availability. Bridge domains' solver reimbursement draws on it (`EXECUTION-PROVIDER-FRAMEWORK.md` §7.2). Payment domains draw on it for conversion liquidity alongside oracle-supplied rates (`SERVICE-DOMAIN-FRAMEWORK.md` §14.4). Cross-chain delivery generally draws on it to front capital ahead of slower, finality-bound settlement. Liquidity, treated this way, is infrastructure other domains compose with, not an endpoint in itself.

### 12.4 The compounding point

This is the same move the Service Domain Framework made for computation, applied here to capital: the network does not need Settlement to grow richer in order for the network itself to grow richer. Every new piece of liquidity infrastructure is a domain, not a protocol modification, and the richness this enables compounds the same way the Service Domain Framework's scaling argument compounds (`SERVICE-DOMAIN-FRAMEWORK.md` §13.3): independently, permissionlessly, and without ever asking Settlement to do more than it already does.

---

## 13. Worked Examples

Every example below is [SPECULATIVE]. None is a design; each names a category, situates it against the architecture already established, and sketches the dimensions a domain operator would need to settle, without settling any of them here.

**AMM Domain.** Hosts a deterministic pricing curve; deposits become pool shares; trades shift pool composition and accrue fees. Doubles as a market structure (§11.2) and a Liquidity Domain.

- **Input source:** `L1_NATIVE` (on-chain swap and deposit instructions).
- **Execution profile:** `OPTIMISTIC` or `ZK_VALIDITY`, given continuous, high-frequency, value-bearing state changes where bonded-attestation honesty alone is a thin guarantee for a pool holding significant capital.
- **Execution Provider need:** None directly; Execution Providers are consumers routing fills through it (§7.2, §10).
- **Composition:** Simultaneously a market structure (`MARKET-FRAMEWORK.md` §9.1) and a Liquidity Domain (§11.2); the same registered domain satisfies both descriptions.

**RFQ Liquidity Domain.** Aggregates standing, executable inventory commitments from multiple providers, exposed to a quoting process rather than a continuous curve.

- **Input source:** `L1_NATIVE`.
- **Execution profile:** `ATTESTATION` or `OPTIMISTIC`; quote commitments are typically lower-frequency than continuous AMM trades.
- **Execution Provider need:** None for the domain itself; the providers posting inventory are themselves acting in an Execution-Provider-like capacity (§10.1).
- **Composition:** Consumes Intent-layer quote requests directly (`INTENT-ORDERFLOW-FRAMEWORK.md` §5); the domain's STF matches takers against posted provider inventory.

**Lending Domain.** Tracks deposited collateral and borrowed positions; interest accrual and liquidation logic live entirely in the domain's STF.

- **Input source:** `L1_NATIVE`.
- **Execution profile:** `OPTIMISTIC` or `ZK_VALIDITY`; liquidation correctness is exactly the kind of property worth fraud-proving or proving outright.
- **Execution Provider need:** Typically none for the core facility; possibly yes for liquidation execution if collateral must be delivered cross-chain.
- **Composition:** The credit relationship (§3.3) exists entirely between the domain's own depositors and borrowers; an oracle domain (`SERVICE-DOMAIN-FRAMEWORK.md` §14.1) is a natural composed dependency for collateral valuation.

**Institutional Liquidity Domain.** A permissioned domain restricting participation to vetted or regulated entities.

- **Input source:** `L1_NATIVE`, gated by an identity or compliance check.
- **Execution profile:** Likely `ATTESTATION` with a smaller, known executor set, consistent with the Economic Security Framework's institutional profile (`ECONOMIC-SECURITY-FRAMEWORK.md` §13.1).
- **Execution Provider need:** Often yes; institutional flow frequently settles through regulated custodians or payment processors (`EXECUTION-PROVIDER-FRAMEWORK.md` §4.6).
- **Composition:** Composes with an identity domain (`SERVICE-DOMAIN-FRAMEWORK.md` §14.2) for participation gating, and relies on the Economic Security Framework's legal/regulatory trust model (`ECONOMIC-SECURITY-FRAMEWORK.md` §3.1) rather than primarily on bonding.

**Cross-chain Liquidity Domain.** Composes with one or more bridge domains to position capital across multiple foreign chains from a single coordinating domain.

- **Input source:** `L1_RELAYED`, where foreign positions are tracked through each composed bridge domain's `ChainVerifier` (`BRIDGE-FRAMEWORK-SPEC.md` §7.3).
- **Execution profile:** Inherited per-leg from each composed bridge domain's own profile; the coordinating domain itself may run `ATTESTATION` over the aggregated view.
- **Execution Provider need:** Yes, for each foreign leg's actual delivery, exactly as any bridge domain requires (`EXECUTION-PROVIDER-FRAMEWORK.md` §3).
- **Composition:** The clearest case of a Liquidity Domain that is mostly composition: it holds little unique logic of its own beyond aggregating and coordinating across bridge domains it does not own.

**Treasury Domain.** Holds and allocates a DAO's, protocol's, or organization's own capital across other Liquidity Domains and markets.

- **Input source:** `L1_NATIVE`, typically gated by a governance or multisig-equivalent authorization (`ECONOMIC-SECURITY-FRAMEWORK.md` §3.1, legal/social trust model).
- **Execution profile:** `ATTESTATION`; treasury actions are usually low-frequency and high-deliberation, not latency-sensitive.
- **Execution Provider need:** None directly; the domain allocates to other domains and markets rather than fulfilling external authorizations itself.
- **Composition:** A consumer of other Liquidity Domains (§11) and markets (`MARKET-FRAMEWORK.md` §9) rather than a primary liquidity source for external Execution Providers.

**Liquidity Router Domain.** Holds no capital of its own; indexes and routes consumption requests across multiple other Liquidity Domains.

- **Input source:** `L1_NATIVE`.
- **Execution profile:** `ATTESTATION`; the domain's STF is routing logic, not custody, so the correctness bar concerns routing decisions rather than fund safety at the router itself.
- **Execution Provider need:** None for the router; it is consumed by Execution Providers seeking the best venue, the on-chain-infrastructure analogue of an off-chain DEX aggregator.
- **Composition:** Pure composition: the router's value is entirely in how well it indexes and compares other Liquidity Domains, never in capital it holds.

**Inventory Coordination Domain.** Helps multiple Execution Providers, particularly solvers, signal and coordinate inventory positioning across chains without centralizing custody.

- **Input source:** `L1_NATIVE` or `L1_RELAYED`, depending on whether coordinated inventory spans foreign chains.
- **Execution profile:** `ATTESTATION`; the domain coordinates signals, it does not itself custody the inventory being coordinated.
- **Execution Provider need:** The domain's entire purpose is serving Execution Providers (specifically solvers, `EXECUTION-PROVIDER-FRAMEWORK.md` §7) as its primary consumers.
- **Composition:** Addresses the cross-domain liquidity coordination question the Execution Provider Framework left open (`EXECUTION-PROVIDER-FRAMEWORK.md` §13) without centralizing the inventory itself, which remains on each solver's own balance sheet (`MARKET-FRAMEWORK.md` §8.1).

---

## 14. Future Research

The following topics are identified as potential future work. They are explicitly speculative and do not commit any implementation or roadmap. Several extend threads the Market Framework already opened (`MARKET-FRAMEWORK.md` §17); this list deepens them specifically for liquidity infrastructure.

**Shared liquidity.** [SPECULATIVE] Multiple Liquidity Domains, or multiple consumers of a single domain, drawing from a common capital base rather than maintaining fully separate pools.

**Cross-domain liquidity.** [SPECULATIVE] Mechanisms for a single unit of capital to serve demand across more than one domain without duplication, extending the cross-domain liquidity routing question already raised (`MARKET-FRAMEWORK.md` §17).

**Cross-margin.** [SPECULATIVE] Collateral posted in one Liquidity Domain securing obligations in another, trading capital efficiency against the cross-domain risk coupling such coordination would introduce.

**Intent-native liquidity.** [SPECULATIVE] Liquidity Domains designed to consume Intents directly as their primary input vocabulary, rather than lower-level swap or draw operations.

**Programmable vaults.** [SPECULATIVE] Vault logic expressible as composable, user-configurable strategies rather than fixed, operator-defined mandates.

**Dynamic collateral.** [SPECULATIVE] Collateral requirements that adjust algorithmically to volatility, liquidity depth, or other observed conditions rather than remaining fixed.

**Restaked liquidity.** [SPECULATIVE] Capital already committed to securing one domain or protocol being reused, with appropriate risk disclosure, to provide liquidity elsewhere.

**Institutional liquidity.** [SPECULATIVE] Deeper integration patterns for regulated capital providers, building on the Institutional Liquidity Domain example (§13) and the Economic Security Framework's regulatory models (`ECONOMIC-SECURITY-FRAMEWORK.md` §11).

**RWA liquidity.** [SPECULATIVE] Liquidity infrastructure for tokenized real-world assets, requiring custody, legal, and market structures distinct from purely crypto-native capital (`MARKET-FRAMEWORK.md` §17).

**Yield markets.** [SPECULATIVE] Markets that price the yield a given liquidity position is expected to generate, separable from the underlying capital itself.

**Liquidity virtualization.** [SPECULATIVE] Representing access to liquidity (a claim, a credit line, a routing right) as a tradeable object distinct from the underlying capital it draws against.

**Credit domains.** [SPECULATIVE] A Liquidity Domain specialized entirely in credit facilities (§4), potentially warranting its own dedicated architectural treatment in a future Frontier document, in the same way this document followed from the Market Framework.

---

## 15. Relationship to Previous Documents

### 15.1 Parallel layers, not a pipeline

These eight documents do not form a sequence to be read in order. Each answers an independent architectural question. Presented as a sequence of arrows, that independence is easy to lose; presented as a set, it is not.

| Document | Question it answers |
|---|---|
| `SPEC.md` | What is the deterministic truth machine? |
| `BRIDGE-FRAMEWORK-SPEC.md` | How does truth extend across chains? |
| `EXECUTION-PROVIDER-FRAMEWORK.md` | How does truth become a real-world outcome? |
| `INTENT-ORDERFLOW-FRAMEWORK.md` | How do users express what they want? |
| `ECONOMIC-SECURITY-FRAMEWORK.md` | Why does every participant behave honestly? |
| `SERVICE-DOMAIN-FRAMEWORK.md` | How does infrastructure capability become modular? |
| `MARKET-FRAMEWORK.md` | How does the network discover what truth is worth? |
| `LIQUIDITY-DOMAIN-FRAMEWORK.md` | Where does the capital markets need actually come from? |

### 15.2 Where this document sits

This document sits at the intersection of two earlier threads. The Service Domain Framework established that infrastructure capability can be modularized without enlarging Settlement (`SERVICE-DOMAIN-FRAMEWORK.md` §13). The Market Framework established that markets may optionally be implemented using that same modular pattern, without becoming Settlement in the process (`MARKET-FRAMEWORK.md` §15.1, §15.2). A Liquidity Domain is what results when those two claims are applied specifically to capital: a Service Domain, built using the same pattern as an oracle or a payment domain, whose particular specialization happens to be holding and allocating liquidity rather than aggregating prices or processing payments.

No document in this set depends on being read before or after another to be true. Each is a complete, independent architectural claim; together they describe a set of layers that compose, not a chain that must be traversed in order.

---

## 16. Closing

This document has defined the Liquidity Domain as an architectural pattern, not a protocol: a Service Domain specialized in holding capital at rest, tracking claims against it, and allocating it to consumers, all while remaining categorically distinct from Settlement at every point where the two meet. It has shown why Settlement structurally cannot host liquidity itself, what state a Liquidity Domain typically tracks, how capital moves through its lifecycle, how it communicates with the rest of the network, why its failures stay contained, and how it relates to the markets and Execution Providers that depend on it.

The closing principle:

> **Settlement determines truth. Markets determine value. Liquidity determines availability. Execution Providers transform availability into action. Every layer remains independent.**

---

**Document end.**

This document is Frontier research. It does not commit to any implementation, any specific Liquidity Domain deployment, or any token model. It defines an architectural pattern that follows directly from the Service Domain Framework and the Market Framework. The controlling authority for all on-chain rules remains `SPEC.md` v1.3.0. Where this document speculates, it says so.
