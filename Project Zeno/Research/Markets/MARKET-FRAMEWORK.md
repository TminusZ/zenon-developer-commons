# Project Zeno: Market Framework

**Document status:** Frontier research. Non-normative.
**Version:** 0.1.0
**Governing documents (in priority order):**

1. `SPEC.md` v1.3.0 (the controlling authority for all on-chain rules)
2. `BRIDGE-FRAMEWORK-SPEC.md` v0.2.0 (the Bridge Framework normative specification)
3. `EXECUTION-PROVIDER-FRAMEWORK.md` v0.1.0 (the Execution Provider architecture)
4. `INTENT-ORDERFLOW-FRAMEWORK.md` v0.1.0 (the Intent and Orderflow architecture)
5. `ECONOMIC-SECURITY-FRAMEWORK.md` v0.1.0 (the Economic Security architecture)
6. `SERVICE-DOMAIN-FRAMEWORK.md` v0.1.0 (the Service Domain architecture)

This document is Frontier research. It does not make implementation claims, introduce new protocol features, propose token economics, or bind any deployment. Every speculative mechanism is explicitly marked. Where this document references a mechanism defined in a governing document, the governing document controls.

**Purpose:** This document explains how markets emerge around the Domain Settlement Layer, why they exist entirely outside it, and why that separation is what allows an open, competitive, programmable financial ecosystem to form on top of a minimal settlement core. It is not a DEX paper, not a tokenomics paper, not an AMM proposal, and not a lending protocol. It defines the architectural role of markets, not the design of any one.

**Boundary discipline:** This document does not extend Settlement, redefine Execution Providers, redefine Intents, or redefine the trust models of the Economic Security Framework. It builds on all four to answer a question none of them fully addressed: once Settlement produces truth, how does the network discover what that truth is worth?

**Commit discipline:** Settlement never prices, never discovers a rate, never owns liquidity, never owns credit, and never allocates capital. If any mechanism described here would require Settlement to make a valuation judgment, the mechanism is wrong. Markets exist outside Settlement, operate on Settlement's output, and never reach back in.

---

## 1. Why this document exists

### 1.1 The remaining question

The Bridge Framework explains how Settlement produces deterministic truth. The Execution Provider Framework explains how that truth is fulfilled, and along the way introduced liquidity and pricing as concepts an Execution Provider must manage (`EXECUTION-PROVIDER-FRAMEWORK.md` §5, §6). The Intent Framework explains how users express desired outcomes and how providers compete to quote them. The Economic Security Framework explains why every participant behaves honestly. The Service Domain Framework explains how infrastructure capabilities become modular, independent domains.

None of these documents gives markets a full architectural treatment. Liquidity and pricing appeared in the Execution Provider Framework only in service of a narrower question: how does a specific provider fulfill a specific authorization? Competition appeared in the Economic Security Framework only in service of a narrower question: why does a specific participant behave honestly? This document asks the broader question directly: what is a market, architecturally, in this system, and why must it remain entirely external to Settlement?

### 1.2 Markets are broader than execution

A market is not merely the venue an Execution Provider sources liquidity from while filling a Settlement authorization. Markets include activity with no Settlement authorization in sight at all: two users trading already-bridged assets against each other on an AMM, a lender extending credit against collateral that was bridged months earlier, a market maker hedging a position across three venues with no Intent object anywhere in the chain. Execution is one thing markets enable. It is not the only thing markets do.

This document's scope is the full economic fabric: capital, liquidity, credit, inventory, price discovery, and the structures (order books, AMMs, RFQ, OTC, lending, derivatives) that produce them. Execution Providers are participants in this fabric, not the fabric itself.

### 1.3 The economic counterpart to the Service Domain Framework

The Service Domain Framework answered: what infrastructure capabilities should become domains, and how do they stay isolated from Settlement and from each other? This document answers the parallel question for value rather than capability: how does the network discover what something is worth, and how does that discovery stay isolated from Settlement?

Where the Service Domain Framework is about modular computation, this document is about modular valuation. Both arrive at the same structural conclusion: keep the core minimal, let everything else compete and specialize around it.

### 1.4 The central thesis

> **Settlement determines what is true. Markets determine what it is worth. Keeping those responsibilities separate is what allows an open, competitive, programmable financial ecosystem to emerge around a minimal settlement layer.**

---

## 2. What is a Market?

### 2.1 Definition

A **market** is any structure, formal or informal, centralized or decentralized, on-chain or off-chain, through which independent participants reveal what they are willing to pay or accept for an asset, a service, or a risk, and through which those revealed preferences aggregate into an observable price.

Three properties are required for a structure to be a market: a plurality of independent participants (not one entity dictating terms), voluntary and costly commitment (an actionable willingness to transact, not mere announcement), and an aggregation mechanism, explicit (an order book's matching engine) or emergent (an AMM's curve, a dealer's quoted spread), that converts individual signals into a price.

### 2.2 Settlement answers a different question

Settlement answers: is X true, authorized, and final? Markets answer: what is X worth, right now, to someone? These are categorically different questions, requiring categorically different machinery.

| Property | Settlement | Markets |
|---|---|---|
| Question answered | Is X true, authorized, final? | What is X worth, right now? |
| Output | A deterministic fact | A probabilistic, time-varying price |
| Change cadence | Conservative; upgrades are rare, delayed, audited (`SPEC.md` §23) | Continuous; prices update every block, every trade |
| Correctness standard | Provably correct, or rejected | Approximately right, continuously corrected by arbitrage |
| Number of instances | One settlement layer per domain | Many competing markets for the same asset |
| Failure mode if wrong | Catastrophic; a false authorization is unrecoverable | Self-correcting; a wrong price is arbitraged away |

A system built to be provably correct and rarely changed is structurally the wrong system to also be continuously, adaptively right about what something is worth. Forcing Settlement to price assets would require it to either become as fast-changing and adaptive as a market (destroying the conservative, auditable character that makes it trustworthy) or lag the market and become a stale, manipulable oracle (the classic oracle-attack vector). Either path breaks the property that makes Settlement valuable: that it is the one part of the system nobody has to second-guess.

### 2.3 Why markets are necessarily plural

A single, official market for an asset would itself be a single point of failure, no different in kind from a single bonded oracle (`EXECUTION-PROVIDER-FRAMEWORK.md` §6.4, "the protocol's non-opinion"). Price-discovery quality improves with the number of independent perspectives contributing to it; a monopoly market can be cornered, manipulated, or censored exactly as a monopoly oracle can. The architecture that follows from this document treats market plurality as a security property, not merely a competitive nicety, in the same sense that the Economic Security Framework treats provider competition as a security property (`ECONOMIC-SECURITY-FRAMEWORK.md` §7).

### 2.4 Truth alone cannot determine value

Settlement can prove, irrevocably, that Alice holds one unit of a given asset. It cannot say what that unit is worth in any other unit, because worth is not a fact about the asset; it is an emergent property of dispersed beliefs, competing claims on scarce capital, and time. No amount of cryptographic rigor resolves a disagreement about value, because the disagreement is the market. This is why markets exist outside Settlement: not as a design preference, but because the thing markets produce, a continuously corrected, competitively discovered price, is not the kind of thing a deterministic truth machine can produce at all.

---

## 3. Market Participants

### 3.1 The cast

Execution Providers (`EXECUTION-PROVIDER-FRAMEWORK.md` §3) are often market participants performing one specific role: filling a Settlement-authorized release. "Market participant" is the broader category, and includes roles with no Settlement authorization in sight.

| Participant | Role | Principal risk taken? |
|---|---|---|
| **Market maker** | Continuously quotes both sides of a market, profiting from the spread | Yes; holds inventory between quotes |
| **Liquidity provider** | Deposits capital into a pool or vault that others draw on | Yes; bears pool-level price and utilization risk |
| **Solver** | Competes to fill Intents, often fronting capital | Yes, temporarily; fronts delivery before reimbursement |
| **Broker** | Arranges trades between others without taking the other side itself | No; earns a commission, takes no position |
| **Dealer** | Takes the other side of a trade onto its own book | Yes; the defining feature of dealing is principal risk |
| **OTC desk** | Negotiates large, bespoke trades bilaterally, off public venues | Yes, typically; often dealer-structured |
| **Lender** | Extends capital now against a promise (and usually collateral) of repayment | Yes; bears credit risk |
| **Borrower** | Receives capital now against a promise of repayment | No principal risk to others; bears repayment obligation |
| **Arbitrageur** | Trades price discrepancies across venues into convergence | Yes, briefly; the position is held only until convergence |
| **Hedger / derivatives counterparty** | Takes an offsetting position to transfer a specific risk | Yes; the risk transferred is the position itself |

### 3.2 Brokers versus dealers

The broker/dealer distinction is precise and worth preserving: a broker arranges a trade between two other parties and never owns the asset; a dealer buys and sells from its own inventory, taking the asset onto its own balance sheet between the two legs. A broker's risk is reputational and operational. A dealer's risk is principal: the asset's price can move while the dealer holds it. Many real participants are hybrids (a broker-dealer), and the Execution Provider taxonomy already reflects this duality (`EXECUTION-PROVIDER-FRAMEWORK.md` §3.2: native custody, institutional custodian, decentralized solver, market maker, DEX execution, RFQ, external bridge, payment processor each sit somewhere on the broker-to-dealer spectrum).

### 3.3 None of this touches Settlement

Settlement does not register market participants, does not distinguish a broker from a dealer, and does not know which of these roles produced the input it received. It sees a valid, signed input or a finalized authorization. Everything in this section describes how that input or authorization came to exist; none of it is visible to, or relevant to, Settlement's own logic.

---

## 4. Price Discovery

### 4.1 What price discovery is

Price discovery is the process by which a market converts dispersed, private, and often conflicting information and preferences into a single observable number. No participant has complete information; the price is what emerges when many incomplete, competing views are forced into contact through actionable trades.

### 4.2 Mechanisms

**Continuous mechanisms** update the price on every trade or every new order: an order book's continuous double auction, an AMM's curve responding to every swap.

**Periodic mechanisms** collect interest over a window and clear at one price for everyone in that window: batch auctions, periodic call auctions.

**Negotiated mechanisms** discover a price through direct, often private interaction between two parties: RFQ (Request for Quote), bilateral OTC negotiation.

**Referential mechanisms** derive a price from other markets rather than discovering it natively: an oracle aggregating prices observed elsewhere is referential, not discovering anything new; it is reporting a price discovered somewhere else.

### 4.3 Intent-driven price discovery

The Intent Framework's Quote system (`INTENT-ORDERFLOW-FRAMEWORK.md` §5) is a negotiated, competitive price-discovery mechanism for episodic flow: when multiple providers quote the same Intent, the competing Quotes are themselves a momentary, single-use market instance, structurally similar to a sealed-bid auction. This document does not redefine that mechanism; it situates it as one instance of the negotiated category above, useful precisely for flow too large, too infrequent, or too bespoke for continuous venues to price efficiently.

### 4.4 Why price discovery must be adaptive

A price that does not update is not a price; it is a stale announcement. Price discovery is valuable only because it is continuously corrected: as new information arrives, as participants act on mispricing (arbitrage), and as supply and demand shift. This continuous correction is the opposite of Settlement's design goal, which is to change as rarely, deliberately, and auditable as possible (`SPEC.md` §23; `BRIDGE-FRAMEWORK-SPEC.md` §6.6). Embedding price discovery in Settlement would force one of these two designs to give way, and neither outcome is acceptable.

---

## 5. Capital

### 5.1 Definition

**Capital** is the stock of value a participant brings to the system: personal wealth, an institutional balance sheet, fund capital, treasury reserves, or borrowed/restaked capital. Capital is a stock, measured at a point in time, not yet committed to any specific use.

### 5.2 Where capital comes from

Capital is entirely external to the protocol. Users, funds, institutions, DAOs, and protocols hold capital on their own balance sheets, accumulated through economic activity that has nothing to do with Project Zeno. Settlement does not issue capital, does not hold capital reserves of its own (beyond the conservation-bounded escrow described next), and has no mechanism for capital formation.

### 5.3 Settlement's escrow is not capital

Settlement's `ESCROW` custody mode holds real assets under the conservation invariant (`BRIDGE-FRAMEWORK-SPEC.md` §13.7): `totalReleased + pendingWithdrawalReserve ≤ totalDeposited`. This is custody, not capital in the market sense. It cannot be deployed, lent, pooled, or put to market use; it exists solely to back authorized releases one-for-one. The distinction was established in the Execution Provider Framework (`EXECUTION-PROVIDER-FRAMEWORK.md` §5.3): an LP pool is bounded by market dynamics; Settlement's escrow is bounded by conservation. The two bounding logics are incompatible, and merging them would either freeze market capital under custody rules it was never designed for, or weaken custody to accommodate market withdrawals it cannot safely permit.

---

## 6. Liquidity

### 6.1 Capital becomes liquidity when it is positioned

**Liquidity** is capital committed to a specific venue, pool, inventory position, or standing quote, such that it is immediately available for transactional use. Capital is a reservoir; liquidity is the same water, deployed into a pipe and ready to flow. A participant can hold substantial capital with near-zero liquidity (everything locked in illiquid positions) or modest capital deployed with high liquidity (efficiently positioned, high-velocity).

### 6.2 Where liquidity lives

This document does not redefine the liquidity sources already established (`EXECUTION-PROVIDER-FRAMEWORK.md` §5.2): Execution Provider inventory, on-chain liquidity pools, OTC and institutional capital, and other bridges. It extends the point made there to the full market context: liquidity for a lending market, a derivatives market, or a pure spot-trading venue lives in exactly the same external places, regardless of whether a Settlement-authorized release is anywhere involved.

### 6.3 Liquidity risk

Liquidity risk is the risk that liquidity, once needed, is not there: a pool is depleted, a market maker withdraws during volatility, a credit line is pulled. This is distinct from capital risk (the risk to the underlying value of the capital itself) and is a property of availability, not value. Liquidity risk is owned by whoever depends on that liquidity being present at the moment of need, never by Settlement, which has no concept of liquidity to begin with.

---

## 7. Credit

### 7.1 Definition

**Credit** is the extension of value now against a promise of value later, collateralized or not. Credit introduces two dimensions that capital and liquidity alone do not require: time (the promise is fulfilled later, not now) and trust (the lender must believe the promise, the collateral, or the legal system will make them whole).

### 7.2 Settlement has no concept of credit

This is not a design preference; it follows logically from the conservation invariant. `totalReleased + pendingWithdrawalReserve ≤ totalDeposited` is, by construction, a fully collateralized model: nothing is ever released that was not first deposited. There is no protocol-level negative balance, no protocol IOU, no fractional reserve at the Settlement layer. A credit relationship, by definition, involves one party temporarily exposed beyond what it currently holds; Settlement's invariant exists specifically to make that exposure impossible at the protocol level. Settlement cannot own credit without ceasing to be Settlement.

### 7.3 Where credit appears

Credit appears entirely at the market layer. A solver that fronts delivery before claiming reimbursement (`EXECUTION-PROVIDER-FRAMEWORK.md` §7.2; `INTENT-ORDERFLOW-FRAMEWORK.md` §3.2 Commit stage) is extending short-term credit to the user, betting that its proof-of-delivery claim will be honored. A lending market, pooled or peer-to-peer, is a pure credit market: lenders extend capital against collateral or reputation, borrowers promise repayment, and the market prices the risk through an interest rate. A market maker's settlement lag, the gap between quoting a price and the trade actually clearing, is an implicit, very short-duration credit exposure.

### 7.4 Credit risk

Credit risk is the risk that the promise is not kept. It is owned entirely by the party extending the credit (or by whatever bond, collateral, or insurance backs that extension, per the Economic Security Framework's bond models, `ECONOMIC-SECURITY-FRAMEWORK.md` §5). Settlement neither bears nor mitigates credit risk; it is structurally incapable of doing so, by the same logic that makes it incapable of owning credit at all.

---

## 8. Inventory

### 8.1 Definition

**Inventory** is capital a participant holds on its own balance sheet, pre-positioned, specifically to avoid sourcing capital in real time when demand arrives. Inventory is a particular form of liquidity: owned, on-balance-sheet, immediately deployable, as distinct from pooled (third-party) liquidity or credit-sourced (borrowed) liquidity.

### 8.2 Why inventory exists

Sourcing capital at the moment of need is slow and often expensive: routing through a DEX, negotiating an OTC trade, or drawing a credit line all take time and incur cost. A participant that pre-positions inventory on a destination chain (`EXECUTION-PROVIDER-FRAMEWORK.md` §4.5 Solver Fill; §7.2 Solver inventory) can fill instantly, trading the cost of holding the position for the value of speed. This pattern generalizes beyond solvers: market makers classically hold inventory across the assets they quote, precisely so they can fill either side of a trade without first sourcing it.

### 8.3 Inventory risk

Inventory risk is the price risk borne while holding a pre-positioned asset: the asset's value can move, favorably or unfavorably, during the holding period. This is distinct from credit risk (a counterparty's broken promise) and from liquidity risk (capital unavailable when needed); inventory risk is the cost of capital actually held and actually exposed to the market. It is owned by whoever holds the inventory, managed through hedging, position limits, and pricing that reflects the holding cost.

---

## 9. Market Structures

### 9.1 The taxonomy

Every structure below is a market structure, not a protocol structure. Settlement has no opinion on which of these exist, which dominate, or which a given asset trades through. Any of them may be implemented entirely off-chain, inside a centralized venue, or, as a Service Domain (§15), on-chain and Settlement-anchored without becoming Settlement itself.

**Order books.** A continuous double auction: standing buy and sell orders are matched by price-time priority. Price discovery is continuous and transparent; depth at each price level is visible.

**RFQ systems.** A requester solicits quotes from a defined set of responders; the requester selects the best. Already specified for Intent-driven flow (`INTENT-ORDERFLOW-FRAMEWORK.md` §5); the structure generalizes to any negotiated, non-continuous trade.

**AMMs (Automated Market Makers).** A deterministic pricing curve (constant-product, stable-swap, concentrated-liquidity, or other) sets price as a function of pool composition; any party may trade against the pool at the curve's quoted price. Because the curve is a pure function, an AMM is a natural candidate for implementation as a Service Domain's STF (§15).

**OTC / dealer markets.** Bilateral, negotiated, off-venue trades, typically with a dealer taking principal risk onto its own book. Used for size or bespoke terms that public venues cannot absorb without significant price impact.

**Auctions.** Periodic price discovery: batch auctions clear all interest in a window at one price; Dutch auctions start high and fall until a taker accepts; English auctions start low and rise until bidding stops; sealed-bid auctions collect hidden bids revealed simultaneously. Already touched for Intent-driven flow (`INTENT-ORDERFLOW-FRAMEWORK.md` §6.2, §15) and for the Economic Security Framework's discussion of execution auctions (`ECONOMIC-SECURITY-FRAMEWORK.md` §16); this section generalizes auctions as a market-structure category independent of any specific application.

**Lending markets.** Pooled or peer-to-peer credit markets (§7): lenders supply capital, borrowers draw against collateral or reputation, and an interest rate prices the credit risk.

**Stable assets.** Not a protocol primitive but a market design pattern: a token engineered, through over-collateralization and redemption arbitrage, algorithmic supply adjustment, or fiat-backed redemption, to track a reference value. The peg is maintained by market mechanisms (arbitrageurs trading the token back toward its target), never by Settlement.

**Derivatives.** Contracts whose value derives from an underlying asset, rate, or event: futures, options, perpetuals, and other contingent claims. Derivatives markets price risk itself as a tradeable asset; they require their own price-discovery and margining infrastructure, entirely external to Settlement.

**Netting.** Offsetting opposing flows so only the net amount requires settlement, reducing gross capital and transaction cost. Already touched as a cross-domain optimization for Intent-driven flow (`INTENT-ORDERFLOW-FRAMEWORK.md` §11.4); the structure generalizes to any market with two-directional flow between the same parties or venues.

### 9.2 Summary

| Structure | What it discovers or allocates | Typical participants |
|---|---|---|
| Order book | Continuous price | Market makers, traders, arbitrageurs |
| RFQ | Negotiated price for episodic flow | Requesters, dealers, market makers |
| AMM | Curve-determined price | Liquidity providers, traders |
| OTC / dealer | Negotiated price, often for size | Dealers, institutional counterparties |
| Auction | Clearing price for a batch or single item | Bidders, the auctioneer/mechanism |
| Lending | Price of credit (interest rate) | Lenders, borrowers |
| Stable asset | Peg maintenance via arbitrage | Arbitrageurs, redeemers |
| Derivatives | Price of risk/contingent claims | Hedgers, speculators, dealers |
| Netting | Reduced gross settlement volume | Counterparties with offsetting flow |

---

## 10. Competition

### 10.1 Reference

The general argument for why competition improves outcomes, pricing, latency, reliability, capital efficiency, and user experience, and why it is itself a security property, is fully specified in the Economic Security Framework (`ECONOMIC-SECURITY-FRAMEWORK.md` §7). This section does not redefine that argument. It applies it at a level the Economic Security Framework did not address: competition between market structures, not only between participants within a structure.

### 10.2 Structure-level competition

Within a single market structure, participants compete: multiple market makers quote against each other on the same order book, multiple solvers race to fill the same Intent. This is participant-level competition, and the Economic Security Framework covers it fully.

A second, higher level of competition exists between structures themselves: an AMM domain, an order-book domain, and an off-chain RFQ network may all serve the same asset pair, competing for the same liquidity and the same order flow. No single market design can become a chokepoint, because nothing prevents a competing design from emerging and drawing flow away from an underperforming one. This mirrors, at the market layer, exactly the pattern the Bridge Framework establishes at the execution layer by keeping the execution and foreign-fact profiles pluggable (`BRIDGE-FRAMEWORK-SPEC.md` §6.3, §6.4): no single mechanism is mandatory, and better mechanisms can displace worse ones without any protocol change.

### 10.3 Why this matters architecturally

Structure-level competition is what prevents "the market" from becoming a single point of failure in the same way a single oracle or a single bonded committee would be (§2.3). It is also what makes the architecture described in this document genuinely open: nothing in Settlement favors one market design over another, so the best design, by whatever metric users and capital reward, wins on its own merits.

---

## 11. Risk Allocation

### 11.1 The market risk table

| Risk | Owner | Why |
|---|---|---|
| **Price risk** | The party holding the exposed position | The market, not Settlement, sets the price that moves |
| **Liquidity risk** | Whoever depends on the liquidity being present | Availability is a market property (§6.3) |
| **Credit risk** | The party extending credit (or its bond/insurer) | Settlement has no credit concept to bear this risk (§7.4) |
| **Inventory risk** | The party holding the inventory | Holding exposure is a market choice (§8.3) |
| **Counterparty risk** | Each party, with respect to the other | Settlement guarantees the authorization, not the counterparty's performance (`ECONOMIC-SECURITY-FRAMEWORK.md` §8.2) |
| **settlement risk** (delivery / DvP risk) | Each party to a trade, until both legs are confirmed | See disambiguation below |
| **Concentration / netting risk** | Parties relying on netted exposure | A netting failure exposes the gross position it was meant to reduce |

> **Terminology note.** Lowercase **settlement risk** in this table refers to the traditional market-structure concept, also called delivery-versus-payment (DvP) risk or Herstatt risk: the risk that one party delivers its leg of a trade while the counterparty fails to deliver theirs. This is a market risk, borne by the trading counterparties, and is fully external to the Domain Settlement Layer. It is unrelated to the capitalized **Settlement** used throughout this document series to mean the Project Zeno protocol layer. It is also a different sense than the "Settlement risk" row in the Economic Security Framework's risk table (`ECONOMIC-SECURITY-FRAMEWORK.md` §8.2), which refers to the risk of the protocol's own cryptographic guarantees failing, a risk Settlement does own. Both uses are legitimate within their own context; readers should rely on context, not the bare term, to distinguish them.

### 11.2 The pattern

Every risk in the table above is owned by a market participant, never by Settlement. Settlement's own guarantees (truth, finality, replay protection, conservation) are listed and bounded in the Economic Security Framework (`ECONOMIC-SECURITY-FRAMEWORK.md` §14.1) and are not repeated here. This document's risk table is strictly about the risks that arise once value enters the market layer, all of which exist downstream of, and independent from, Settlement's guarantees.

---

## 12. Relationship to Settlement

### 12.1 What Settlement must never do

**Settlement must never price assets.** A price is a continuously corrected, competitively discovered number; Settlement is a conservative, rarely-changing truth machine. The two cannot coexist in one system without one destroying the other (§2.2).

**Settlement must never discover exchange rates.** An exchange rate is a special case of price discovery between two assets; the same argument applies without modification.

**Settlement must never own liquidity.** Liquidity is capital deployed under market dynamics, bounded by withdrawal risk and utilization; Settlement's escrow is custody bounded by conservation. The two bounding logics are incompatible (§5.3).

**Settlement must never own credit.** Credit requires exposure beyond what is currently held; the conservation invariant makes such exposure structurally impossible at the protocol level (§7.2). Settlement cannot own credit without abandoning the invariant that makes it trustworthy.

**Settlement must never allocate capital.** Which Execution Provider fills an order, which pool receives a deposit, which market a user routes through: these are choices made by the market and the user (`INTENT-ORDERFLOW-FRAMEWORK.md` §8, Execution Selection), and Settlement only finalizes the result of whatever choice was made. It does not make the choice itself.

**Settlement must never choose market structures.** Order books, AMMs, RFQ, OTC, lending, derivatives: Settlement has no opinion on which exists, dominates, or is correct for a given asset. Mandating one would foreclose the competition that produces better designs (§10).

**Settlement must never select winners.** Among competing quotes, competing market makers, or competing market structures, the user, the wallet, or the market itself selects; Settlement has no mechanism for, and no business in, declaring a winner.

### 12.2 The thesis, restated

Settlement determines what is true. Markets determine what it is worth. Every "never" above is a direct consequence of that single separation, not seven independent rules.

---

## 13. Relationship to Execution Providers

### 13.1 The dual role

Execution Providers are, depending on context, either market participants performing price discovery or market price-takers consuming a price discovered elsewhere. A provider quoting into an RFQ for a specific Intent is actively contributing to price discovery: its quote is part of what makes the discovered price meaningful. A provider routing a fill through an existing AMM pool is a price-taker: it accepts the pool's curve-determined price rather than discovering anything new.

### 13.2 Reference, not redefinition

The Execution Provider Framework's pricing section (`EXECUTION-PROVIDER-FRAMEWORK.md` §6) already distinguishes Settlement truth from market pricing and enumerates the mechanisms (oracle-based, DEX, RFQ, market-maker, negotiated) a provider may use. This document does not redefine any of that. It situates those mechanisms within the broader market taxonomy of §9 and makes explicit what was implicit there: every pricing mechanism an Execution Provider uses is an instance of a market structure, and the provider's role within it is either participant or price-taker depending on whether it is quoting or routing.

### 13.3 Competing quotes as a momentary market

When two or more Execution Providers quote the same Intent, the set of competing Quotes is itself a small, episodic, sealed-bid-like market instance (§4.3): independent participants, voluntary commitment, an aggregation step (the user or wallet selecting the best Quote). Every Intent with competing Quotes is, structurally, a market event, even though no one would ordinarily describe it that way.

---

## 14. Relationship to Intent Framework

### 14.1 Intents route into markets

The Intent Framework's lifecycle (`INTENT-ORDERFLOW-FRAMEWORK.md` §3) reaches its Quote stage by routing the user's expressed outcome into the market: providers observe the Intent, evaluate it against their own pricing mechanism (§9), and respond with Quotes. The Quote system (`INTENT-ORDERFLOW-FRAMEWORK.md` §5) is, in the vocabulary of this document, a negotiated price-discovery mechanism (§4.2) specialized for Intent-driven flow. Solver competition (`INTENT-ORDERFLOW-FRAMEWORK.md` §6) is participant-level competition (§10.2) within that mechanism. Execution Selection (`INTENT-ORDERFLOW-FRAMEWORK.md` §8) is how the user converts the market's discovered prices into a chosen outcome.

### 14.2 Not every market interaction begins with an Intent

Intents are one way flow enters markets, not the only way. Two parties trading directly against an AMM, a lender and borrower matching on a lending market, a dealer warehousing inventory ahead of expected flow: none of these requires an Intent object at any point. The Intent layer is the user-facing on-ramp into markets for outcome-described, often cross-domain or cross-chain flow; markets themselves are larger than, and prior to, that on-ramp.

---

## 15. Relationship to Service Domains

### 15.1 Markets can be implemented as domains

A Service Domain's STF is general-purpose deterministic logic (`SERVICE-DOMAIN-FRAMEWORK.md` §2). Nothing prevents that logic from implementing a market structure: an AMM's pricing curve, an order-matching engine, or a lending pool's accounting are all expressible as a domain's `Apply` function, processing market-specific inputs and producing market-specific effects, exactly as an oracle domain or a payment domain would (`SERVICE-DOMAIN-FRAMEWORK.md` §14).

### 15.2 A market-as-domain is still a market, not Settlement

This is the crucial point, and it is easy to get wrong. When a market is implemented as a Service Domain, its internal bookkeeping inherits the same Settlement-anchoring properties any domain inherits: deterministic replay, an auditable commitment trail, isolation from every other domain's failures (`SERVICE-DOMAIN-FRAMEWORK.md` §3.1, §7). What it does not inherit is membership in Settlement itself. Settlement Core is node-binary logic (`SPEC.md` §5.2); a domain's pricing curve, however sophisticated, is plugin logic, never node-binary logic. Settlement still does not price anything. The domain, a market structure that happens to use the Service Domain pattern for its own state, does.

This distinction is what keeps the boundary discipline of §12 intact even when markets move on-chain: an on-chain AMM domain is no more "Settlement pricing an asset" than an off-chain centralized exchange is. Both are markets. One happens to inherit Settlement's replay and audit properties; the other does not. Neither is Settlement.

### 15.3 Benefits of implementing a market as a Service Domain

A market implemented as a domain gains deterministic replay (anyone can reconstruct the market's full history from L1-anchored data with no live access to the venue), a Settlement-anchored audit trail (every trade, deposit, and withdrawal is committed and finalized through the same mechanism as any other domain), and isolation (a bug in the market's STF cannot reach any other domain's state or custody, per the isolation argument of `SERVICE-DOMAIN-FRAMEWORK.md` §7). These are the same benefits any Service Domain provides; a market is simply one more capability that can choose to use the pattern.

### 15.4 Markets need not be domains at all

Centralized exchanges, OTC desks, and off-chain RFQ networks are equally valid market structures from Settlement's perspective. Settlement never sees the market; it sees only the resulting valid inputs or finalized authorizations a market participant submits. A market gains nothing from Settlement's perspective by being a domain, beyond the replay and audit properties of §15.3, and Settlement loses nothing by a market choosing not to be one.

### 15.5 Introducing, not specifying, the Liquidity Domain

[SPECULATIVE] Given §15.1 through §15.4, a natural category follows: a **Liquidity Domain**, a Service Domain whose specific capability is to host liquidity-provision, market-making, or capital-allocation infrastructure on-chain, in the same way an oracle domain hosts price-feed infrastructure or a payment domain hosts payment processing (`SERVICE-DOMAIN-FRAMEWORK.md` §14.1, §14.4).

This document does not specify a Liquidity Domain. It does not define its STF, its input vocabulary, its economic model, its custody mode, or its relationship to any specific market structure from §9. It establishes only that the concept is architecturally coherent, follows directly from everything this document and the Service Domain Framework have already established, and is a natural subject for its own future Frontier paper.

---

## 16. Why This Architecture Scales

### 16.1 Market innovation without protocol change

Just as the Service Domain Framework shows that adding an infrastructure capability means registering a domain, not changing consensus (`SERVICE-DOMAIN-FRAMEWORK.md` §13), this document's architecture shows that adding a market design means deploying a new structure, not changing Settlement. A new AMM curve, a new auction mechanism, a new credit model: each is deployable, tested, and adopted or abandoned entirely at the market layer, with zero coordination required from Settlement.

### 16.2 Coexistence without fragmentation

Multiple market structures compete and coexist for the same asset (§10.2) without fragmenting Settlement, because Settlement has no concept of "the" market for an asset; it only sees valid inputs, wherever they originated. Institutional and DeFi liquidity coexist for the same reason the Economic Security Framework's regulatory models coexist (`ECONOMIC-SECURITY-FRAMEWORK.md` §11): Settlement is agnostic to the regulatory status, the venue type, or the structure of whatever market produced a given input. Centralized, decentralized, and hybrid liquidity coexist for the identical reason.

### 16.3 The compounding effect

As more market structures emerge, each independently and permissionlessly, the depth and quality of price discovery across the network improves without any protocol coordination. This is the same "richer network around a minimal core" argument the Service Domain Framework makes for infrastructure capability (`SERVICE-DOMAIN-FRAMEWORK.md` §13.3), applied here to economic value: Settlement does not get richer; the market fabric around it does, and that fabric's richness is what makes the assets Settlement anchors actually useful.

---

## 17. Future Research

The following topics are identified as potential future work. They are explicitly speculative and do not commit any implementation or roadmap.

**Cross-domain liquidity routing.** [SPECULATIVE] Mechanisms for sourcing liquidity across multiple domains for a single fill, reducing fragmentation between isolated pools.

**Unified collateral and cross-margining.** [SPECULATIVE] A model allowing collateral posted in one domain to secure obligations in another, improving capital efficiency at the cost of cross-domain risk coupling that would need careful isolation analysis.

**On-chain credit markets.** [SPECULATIVE] Lending and undercollateralized credit design that remains entirely external to Settlement's fully-collateralized invariant (§7.2), exploring how reputation, bonds, or legal recourse might substitute for the over-collateralization common in today's on-chain lending.

**Synthetic assets and derivatives domains.** [SPECULATIVE] Service Domains specialized in contingent-claims accounting, margining, and settlement, distinct from any spot-asset bridge domain.

**Algorithmic market-making research.** [SPECULATIVE] Strategies and curve designs for automated liquidity provision, evaluated for capital efficiency and adverse-selection resistance.

**RFQ aggregation layers.** [SPECULATIVE] A meta-layer that solicits and compares quotes across multiple independent RFQ networks, improving price discovery for Intent-driven flow without favoring any single network.

**Institutional dark pools as domains.** [SPECULATIVE] Permissioned Service Domains offering reduced information leakage for large institutional flow, composed with the orderflow-privacy mechanisms of the Intent Framework (`INTENT-ORDERFLOW-FRAMEWORK.md` §7.3, §7.4).

**Prediction markets.** [SPECULATIVE] Markets that price the probability of future events, a derivative structure (§9.1) specialized for binary or categorical outcomes.

**Insurance-linked markets.** [SPECULATIVE] Markets that price and trade coverage for the risks described in the Economic Security Framework's insurance section (`ECONOMIC-SECURITY-FRAMEWORK.md` §10), connecting risk pricing directly to the participants who bear it.

**Cross-chain netting infrastructure.** [SPECULATIVE] Systems that identify and net offsetting flow across multiple bridge domains before it reaches Settlement, reducing gross settlement volume network-wide.

**Programmable credit lines.** [SPECULATIVE] Credit facilities expressed as on-chain logic, extending the solver-fronting pattern (§7.3) into a general-purpose, market-priced credit primitive.

**Real-world asset markets.** [SPECULATIVE] Markets for tokenized real-world assets, requiring market structures (and legal/regulatory trust models, per `ECONOMIC-SECURITY-FRAMEWORK.md` §11) distinct from purely crypto-native assets.

**A dedicated Liquidity Domain Framework.** The concept introduced and deliberately left unspecified in §15.5 is the most direct candidate for the next Frontier document in this series: a full architectural treatment of what a Liquidity Domain is, what properties it should have, and how it relates to the market structures enumerated in §9, written with the same boundary discipline as every document in this series.

---

## 18. Closing

This document has defined markets as the structures through which independent participants discover what Settlement's deterministic truth is worth. It has separated capital, liquidity, credit, and inventory as distinct concepts with distinct risks. It has enumerated the market structures the network may host or interact with, none of them a protocol structure. It has shown that Execution Providers, Intents, and Service Domains each touch markets without absorbing them, and that even a market implemented entirely on-chain as a Service Domain remains, categorically, a market rather than Settlement.

The six-document architecture now reads:

```
SPEC.md                          ← The truth machine
    ↓
BRIDGE-FRAMEWORK-SPEC.md         ← How value crosses chains
    ↓
EXECUTION-PROVIDER-FRAMEWORK.md  ← How truth becomes action
    ↓
INTENT-ORDERFLOW-FRAMEWORK.md    ← How users express outcomes
    ↓
ECONOMIC-SECURITY-FRAMEWORK.md   ← Why everyone behaves
    ↓
SERVICE-DOMAIN-FRAMEWORK.md      ← How the network grows
    ↓
MARKET-FRAMEWORK.md              ← How the network prices (this document)
```

As with the Service Domain Framework, this is not a pipeline. It is a layered architecture; each document answers a different question, and each can be read on its own. This document's question, how does value get priced once domains produce truth, sits alongside the others rather than after them.

The closing principle:

> **Settlement determines what is true. Markets determine what it is worth. Keeping those responsibilities separate is what allows an open, competitive, programmable financial ecosystem to emerge around a minimal settlement layer.**

---

**Document end.**

This document is Frontier research. It does not commit to any implementation, any specific market design, or any Liquidity Domain specification. It defines the architectural role markets play around the Domain Settlement Layer and the boundary that keeps them separate from it. The controlling authority for all on-chain rules remains `SPEC.md` v1.3.0. Where this document speculates, it says so.
