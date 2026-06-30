# Project Zeno: Intent and Orderflow Framework

**Document status:** Frontier research. Non-normative.
**Version:** 0.1.0
**Governing documents (in priority order):**

1. `SPEC.md` v1.3.0 (the controlling authority for all on-chain rules)
2. `BRIDGE-FRAMEWORK-SPEC.md` v0.2.0 (the Bridge Framework normative specification)
3. `EXECUTION-PROVIDER-FRAMEWORK.md` v0.1.0 (the Execution Provider architecture)

This document is Frontier research. It does not make implementation claims, advertise future features, or bind any deployment. Every speculative mechanism is explicitly marked. Where this document references a mechanism defined in a governing document, the governing document controls.

**Boundary discipline:** This document does not redefine Settlement, Bridges, or Execution Providers. Those are specified. This document defines the layer that sits *above* all three: how users express what they want, how Execution Providers discover and compete to fulfill those wants, and how orderflow moves through the system.

**Commit discipline:** Intents live entirely above Settlement. If any mechanism described here would require Settlement to interpret user preferences, choose an Execution Provider, or make a pricing decision, the mechanism is wrong and must be redesigned. Settlement authorizes what is true. It never decides who wins.

---

## 1. Why this document exists

### 1.1 The remaining gap

The Bridge Framework explains how truth is produced:

```
Foreign event → Verification → Settlement → Finalized authorization
```

The Execution Provider Framework explains how truth is fulfilled:

```
Finalized authorization → Execution Provider → Delivered asset
```

Neither document answers the question that comes first: **how does a user express what they actually want?**

A user does not think in terms of `PegOutAuthorization` objects, `outboxId` replay keys, or conservation invariants. A user thinks: "I have BTC and I want ETH." Or: "I want to pay someone on Solana." Or: "Move my position to the cheapest L2."

The gap between what a user wants and what Settlement can authorize is the intent layer. This document fills that gap.

### 1.2 What this document is for

This document is for the people who build the surfaces users actually touch: wallet developers, SDK builders, application teams, and protocol integrators. It defines a shared vocabulary for expressing user desires, discovering Execution Providers, soliciting quotes, selecting execution, and tracking fulfillment, all without modifying Settlement or blurring the separation of concerns.

### 1.3 What this document is not

This is not a Settlement specification (Settlement is specified). This is not an Execution Provider specification (that is specified). This is not a token-economics proposal, a governance framework, or a product roadmap. It is a developer-facing architecture for the intent layer that sits above the protocol.

---

## 2. Intent Model

### 2.1 What is an Intent?

An **Intent** is an authenticated description of a desired outcome. It says *what* the user wants, not *how* to achieve it.

An Intent does not specify which bridge to use, which liquidity pool to route through, which DEX to swap on, or which Execution Provider to select. It describes the destination, the constraints, and the preferences. Everything else is the Execution Provider's problem.

### 2.2 Examples

| User says | Intent captures |
|---|---|
| "I want 5 BTC on Ethereum" | source asset, destination chain, destination asset, amount |
| "I want 1000 USDC on Solana" | source asset, destination chain, destination asset, amount |
| "I want the cheapest route" | optimization preference: minimize fees |
| "I want delivery in under 30 seconds" | time constraint: maximum latency |
| "I will accept 0.5% slippage" | price constraint: slippage tolerance |
| "I prefer trust-minimized execution" | profile preference: minimize trust assumptions |
| "Move everything to Arbitrum" | multi-asset intent with destination chain |

### 2.3 Intent structure

[SPECULATIVE] An Intent contains the following fields. The exact encoding is not specified here (it is an application-layer choice, not a protocol choice).

```
Intent {
    intentId       : unique identifier (hash of the canonical encoding)
    creator        : authenticated identity (address, pubkey, or session key)
    sourceChain    : where the user's assets currently are
    sourceAsset    : what asset the user is spending
    sourceAmount   : how much the user is spending (may be "all" or exact)
    destChain      : where the user wants the outcome delivered
    destAsset      : what asset the user wants to receive (may equal sourceAsset)
    destRecipient  : who receives the delivered asset (defaults to creator)
    minDestAmount  : minimum acceptable output after all fees and slippage
    constraints    : Constraints (see §2.4)
    preferences    : Preferences (see §2.5)
    expiry         : when this Intent expires (block height or timestamp)
    nonce          : replay protection
    signature      : creator's authentication over all fields above
}
```

### 2.4 Constraints (hard requirements)

Constraints are conditions the execution MUST satisfy. If any constraint is violated, the execution is invalid and the user should be refunded or the Intent should remain unfulfilled.

```
Constraints {
    maxSlippage    : maximum acceptable price deviation (basis points)
    maxLatency     : maximum acceptable time to delivery (seconds or blocks)
    maxFee         : maximum total fee the user will pay
    requiredProfile: execution profile the user requires (e.g. "trust-minimized")
    excludeProviders: providers the user refuses (optional blacklist)
}
```

### 2.5 Preferences (soft requirements)

Preferences guide provider selection but do not invalidate execution. A preference for "fast" does not reject a fill that took 60 seconds; it tells the selection algorithm to prefer providers that quote lower latency.

```
Preferences {
    optimizeFor    : COST | SPEED | TRUST | PRIVACY
    preferProviders: providers the user favors (optional whitelist)
    preferProfile  : preferred execution profile (non-binding)
    preferRouting  : preferred routing hint (e.g. "avoid chain X")
}
```

### 2.6 What an Intent is NOT

An Intent is not a transaction. It does not specify gas, nonce, calldata, or target contract. A transaction is an implementation artifact; an Intent is an outcome description. The Execution Provider translates the Intent into whatever transactions are needed.

An Intent is not a Settlement input. Settlement never sees the Intent object. Settlement sees a `Deposit`, `CallL2`, or `RelayMessage`, all of which are produced by the Execution Provider or the user's wallet after the Intent has been matched and accepted. The Intent layer is invisible to Settlement.

An Intent is not an order. An order specifies a price and a direction on a specific venue. An Intent specifies an outcome across any number of venues, chains, and providers. Orders may be generated *from* an Intent by the Execution Provider, but the Intent itself is venue-agnostic.

---

## 3. Intent Lifecycle

### 3.1 The stages

```
Create  →  Broadcast  →  Discovery  →  Quote  →  Selection  →  Commit  →  Settlement  →  Execution  →  Completion
```

Each stage is independent and may be implemented differently by different wallets, SDKs, or applications. The framework defines the stages and their boundaries; it does not mandate a specific implementation.

### 3.2 Stage descriptions

**Create.** The user (or their agent) constructs an Intent object, signs it, and makes it available for discovery. This happens in the user's wallet, application, or SDK.

**Broadcast.** The signed Intent is published to one or more discovery channels (a public relay, a private RFQ endpoint, a solver network, or a direct connection to a specific provider). The broadcast mechanism is not protocol-defined; it is an application choice.

**Discovery.** Execution Providers observe the broadcast Intent and evaluate whether they can fill it. Providers check their inventory, pricing, risk tolerance, and capacity. Providers that cannot fill (wrong chain, insufficient liquidity, exceeds risk limits) ignore the Intent.

**Quote.** Providers that can fill respond with a Quote (§5): a binding or indicative offer specifying the exchange rate, fee, estimated latency, and expiry. Multiple providers may quote the same Intent, creating competition.

**Selection.** The user (or their wallet/agent) selects one Quote from the competing offers. Selection may be manual ("the user picks"), automatic ("the wallet picks the cheapest"), or auction-based ("the Intent relay picks the best bid"). See §8.

**Commit.** The selected provider and the user enter a commitment. For permissionless execution, this may be as simple as the provider beginning to fill. For bonded execution, the provider may lock collateral. For user-committed execution, the user may lock their source asset. The commit mechanism depends on the execution profile (§9).

**Settlement.** The user's source asset enters the Settlement pipeline: it is deposited, processed by the domain's STF, and produces a finalized `kind=1` authorization. This is the Bridge Framework's concern, not the Intent layer's. The Intent layer only needs to know that this step happened.

**Execution.** The selected Execution Provider fulfills the authorization. This is the Execution Provider Framework's concern. The Intent layer only needs to know whether the execution succeeded, failed, or timed out.

**Completion.** The user receives the desired outcome. The Intent is marked fulfilled. If the execution failed, the Intent enters the resolution flow (§10).

### 3.3 What the Intent layer owns

The Intent layer owns stages 1 through 6 (Create through Commit). Stages 7 and 8 (Settlement and Execution) are owned by their respective frameworks. Stage 9 (Completion) is shared: the Intent layer tracks status, while the Execution Provider performs the delivery.

---

## 4. Intent Providers

An **Intent Provider** is any system that creates Intents on behalf of users. The Intent layer does not restrict who may create Intents; it only requires that the Intent be authentically signed by the spending identity.

### 4.1 Who creates Intents

| Creator | How it works |
|---|---|
| **Wallet** | The user's wallet (browser extension, mobile app, hardware signer) constructs and signs the Intent directly. This is the most common path. |
| **Application** | A dApp constructs the Intent from the user's UI input (e.g. a bridge frontend, a portfolio manager, a payment app) and asks the user's wallet to sign. |
| **SDK** | A developer library (TypeScript, Rust, Python) provides programmatic Intent construction for bots, aggregators, and backend services. |
| **API** | A hosted service exposes an Intent creation endpoint, authenticated by API key or session token. For institutional integrations. |
| **DAO** | A governance proposal authorizes an Intent (e.g. "move the treasury's BTC to Ethereum"). The DAO's multisig or governance contract signs. |
| **Enterprise** | A corporate treasury, fund administrator, or payment processor creates Intents in batch, signed by authorized signers. |
| **AI agent** | [SPECULATIVE] An autonomous agent creates Intents based on programmed rules, market conditions, or portfolio strategy. The agent is authorized by a delegated session key. |

### 4.2 Authentication

Every Intent MUST be signed by the identity that controls the source asset. Without authentication, an Intent is a suggestion, not a commitment. The signature format depends on the source chain (ECDSA for EVM, Ed25519 for Solana, Schnorr for Bitcoin), and the Intent layer is agnostic to the specific signature scheme as long as the Execution Provider can verify it.

---

## 5. Quote System

### 5.1 What is a Quote?

A **Quote** is an Execution Provider's response to an Intent. It says: "I can fill your Intent under these terms."

[SPECULATIVE] A Quote contains:

```
Quote {
    quoteId         : unique identifier
    intentId        : the Intent this Quote responds to
    provider        : the Execution Provider's identity
    destAmount      : the amount the user will receive after all fees
    fee             : the provider's total fee (broken down if possible)
    exchangeRate    : the effective exchange rate (if cross-asset)
    estimatedLatency: expected time from commit to delivery
    expiry          : when this Quote expires (short-lived, typically seconds to minutes)
    executionProfile: which profile the provider will use (§4 of Exec Provider Framework)
    binding         : whether the Quote is firm (the provider commits to these terms)
                      or indicative (the provider may revise at execution time)
    providerSig     : the provider's signature over the Quote
}
```

### 5.2 Binding versus indicative quotes

A **binding** Quote means the provider commits to filling at the quoted terms (destAmount, fee, exchangeRate) if the user accepts within the expiry window. If the provider fails to honor a binding Quote, the provider's bond (if any) is at risk.

An **indicative** Quote means the provider's best estimate, subject to change. The actual execution terms may differ due to price movement, liquidity changes, or gas spikes. Indicative quotes are useful for discovery and comparison but do not create a commitment.

The user's wallet or application should clearly distinguish binding from indicative quotes.

### 5.3 Quote expiry

Quotes are short-lived. An exchange rate quoted now may be stale in 30 seconds. Providers set expiry times based on their risk tolerance and the volatility of the asset pair. The Intent layer does not mandate an expiry duration; it only requires that the Quote carry an explicit expiry so the user's wallet can discard stale offers.

### 5.4 Fee decomposition

A Quote's fee ideally decomposes into visible components so the user can understand what they are paying for:

| Component | Who receives it | Set by |
|---|---|---|
| Source gas (L1 inclusion) | L1 validators | L1 fee market |
| Execution gas (L2) | Domain executor | Metering schedule |
| Destination gas | Destination validators | Destination fee market |
| Provider fee | Execution Provider | Market competition |
| Solver premium (if applicable) | Solver | Solver's risk model |
| DEX/swap fee (if applicable) | DEX LPs | DEX protocol |

The total fee is the sum. The user compares total fees across Quotes; the decomposition is transparency, not a protocol requirement.

---

## 6. Solver Competition

### 6.1 Why competition matters

When multiple Execution Providers quote the same Intent, the user benefits from competition: lower fees, faster delivery, better rates. The Intent layer's primary architectural contribution is making this competition possible. Without a shared Intent format and a discovery mechanism, each provider would need a bilateral integration with each application, killing composability and market efficiency.

### 6.2 Competition mechanics

[SPECULATIVE] Competition may take several forms:

**Open quoting.** The Intent is broadcast publicly; any provider may respond with a Quote. The user (or wallet) picks the best. Simple, transparent, and susceptible to front-running (see §7).

**Sealed-bid auction.** Providers submit encrypted Quotes to a relay; the relay reveals them simultaneously after a deadline. The user picks from the revealed set. Resists front-running but adds latency.

**Dutch auction.** [SPECULATIVE] The Intent starts with an aggressive (high-fee, tight-slippage) requirement and gradually relaxes over time. The first provider to fill at the current terms wins. Discovers the market-clearing price dynamically.

**First-come-first-served.** No quoting phase; the first provider to fill the Intent wins. Fast but may result in suboptimal pricing.

### 6.3 Inventory and capital efficiency

Solvers compete not just on price but on capital efficiency. A solver with pre-positioned inventory on the destination chain can fill faster (no sourcing delay) and cheaper (no intermediate swap). Inventory management, rebalancing, and predictive pre-positioning are competitive advantages, not protocol concerns.

### 6.4 Bonding and reputation

[SPECULATIVE] A solver registry (external to Settlement) may track:
- **Bond size:** how much collateral the solver has posted, covering potential misbehaviour.
- **Fill rate:** what percentage of accepted Quotes the solver successfully filled.
- **Average latency:** how quickly the solver typically delivers.
- **Dispute history:** how many fills were disputed or rolled back.

Reputation is an application-layer signal, not a protocol guarantee. A wallet may use reputation to filter or rank Quotes. Settlement has no concept of solver reputation.

---

## 7. Orderflow

### 7.1 What is orderflow?

Orderflow is the stream of user Intents flowing from creators to Execution Providers. How that stream is routed, who can see it, and when, determines the fairness and efficiency of execution.

### 7.2 Public orderflow

The Intent is broadcast to a public relay visible to all providers. Anyone can see it, quote it, or attempt to fill it.

**Advantage:** maximum competition, simple infrastructure.
**Risk:** front-running (a provider or MEV searcher sees the Intent and trades ahead of it), information leakage (the market learns about the user's position before execution).

### 7.3 Private orderflow

The Intent is sent directly to one or a small set of trusted providers, bypassing public broadcast.

**Advantage:** no front-running, no information leakage.
**Risk:** reduced competition (fewer providers see the Intent), potential for provider collusion, opacity (the user cannot verify they received the best price).

### 7.4 Encrypted orderflow

[SPECULATIVE] The Intent is broadcast publicly but encrypted so that only authorized parties (registered solvers, a threshold decryption committee, or a TEE-based relay) can read it. Quotes are submitted blindly or against a commitment scheme.

**Advantage:** combines public competition with front-running resistance.
**Risk:** complexity, key management, latency (decryption round), TEE trust assumptions.

### 7.5 Intent relays

[SPECULATIVE] An **Intent relay** is a service (centralized or decentralized) that aggregates Intents from multiple sources and distributes them to Execution Providers. The relay may filter, batch, or auction Intents. It is not a Settlement component; it is middleware.

Relay designs range from a simple WebSocket server (centralized, fast, censorship-prone) to a p2p gossip network (decentralized, slower, censorship-resistant) to a committed orderflow auction (CoFA, where the relay commits to a fair ordering before revealing Intents to providers).

The Intent layer does not mandate a specific relay design. It only requires that the relay faithfully deliver Intents to providers and Quotes back to users, without altering either.

### 7.6 MEV resistance

MEV in the intent layer arises from information asymmetry: a party that sees the Intent before the Execution Provider can trade ahead of the fill. Defenses include:

- **Encrypted broadcast** (§7.4): the Intent is unreadable until decryption.
- **Commit-reveal quotes** (§6.2): providers commit to prices before seeing competitors.
- **Time-priority fairness:** the relay processes Intents in arrival order with no reordering.
- **Private routing** (§7.3): the Intent never enters a public mempool.

None of these are Settlement mechanisms. Settlement does not see Intents, does not process orderflow, and is not affected by MEV in the intent layer. MEV resistance in the intent layer is an application-architecture problem.

---

## 8. Execution Selection

### 8.1 Who selects?

After Quotes arrive, someone must pick one. The Intent layer supports multiple selection models:

**User-selected.** The user reviews Quotes in their wallet UI and manually picks. Full control, but slow and requires engagement.

**Wallet-selected.** The wallet applies a policy (cheapest, fastest, highest-reputation, or a weighted score) and auto-selects. The user approves with a single confirmation. This is the expected default for consumer wallets.

**Application-selected.** The dApp selects on behalf of the user, applying application-specific logic (e.g. a payment app selects the fastest provider because the merchant requires quick settlement). The user has pre-authorized the application to select.

**Auction-selected.** [SPECULATIVE] The Intent relay runs an auction among Quotes and selects the winner by a predefined rule (lowest fee, best rate, highest bond). The user trusts the relay's auction mechanism.

### 8.2 Selection criteria

| Criterion | What it measures |
|---|---|
| **Lowest fee** | Total cost to the user (provider fee + gas + swap fees) |
| **Fastest** | Estimated time from commit to delivery |
| **Highest trust** | Most trust-minimized execution profile (native custody > solver > institutional) |
| **Best execution** | A composite score balancing fee, speed, trust, and provider reputation |
| **Maximum privacy** | The provider or route that leaks the least information |

### 8.3 Best execution

[SPECULATIVE] "Best execution" is a loaded term from traditional finance (MiFID II, SEC Rule 606). In this context, it means the selection that best satisfies the user's stated constraints and preferences across all available Quotes. The wallet or application defines what "best" means for its users; the Intent layer provides the Quotes and the selection interface, not the definition.

---

## 9. Intent Profiles

An **Intent Profile** is a preset combination of constraints and preferences that a wallet or application offers as a one-tap option. Profiles simplify the user experience: instead of setting maxSlippage, maxLatency, and optimizeFor individually, the user picks "Fast" or "Cheap" and the profile fills in the details.

### 9.1 Example profiles

| Profile | optimizeFor | maxLatency | maxSlippage | requiredProfile | Notes |
|---|---|---|---|---|---|
| **Fast** | SPEED | 30s | 1.0% | any | Accepts higher fees for speed |
| **Cheap** | COST | 10min | 0.5% | any | Accepts higher latency for lower fees |
| **Trust-minimized** | TRUST | 30min | 0.3% | native custody | Requires trust-minimized execution |
| **Institutional** | COST | 1hr | 0.1% | institutional | Low slippage, regulatory compliance |
| **Maximum privacy** | PRIVACY | 5min | 1.0% | any | Prefers encrypted orderflow, private routing |
| **Same asset** | COST | 5min | 0 | any | BTC to BTC, ETH to ETH; no conversion |
| **Cross-asset** | COST | 5min | 0.5% | any | Conversion required; slippage expected |
| **Payment** | SPEED | 15s | 0.5% | any | Optimized for point-of-sale and remittance |
| **Settlement only** | TRUST | no limit | 0 | native custody | Wait for native custody release; no solver |
| **Bridge** | COST | 10min | 0.3% | any | Standard cross-chain asset movement |
| **DEX** | COST | 1min | 0.5% | DEX swap | Route through on-chain DEXes only |

### 9.2 Custom profiles

Profiles are not protocol-defined. Any wallet, SDK, or application may define its own profiles. The profiles above are examples, not a specification.

---

## 10. Intent Resolution

### 10.1 The happy path

The selected provider fills the Intent within the stated constraints. The user receives `destAmount` on `destChain`. The Intent is marked `FULFILLED`. Done.

### 10.2 Partial fills

[SPECULATIVE] If a provider can only fill part of the Intent (insufficient liquidity for the full amount), the provider may offer a partial fill. The user's wallet decides whether to accept partial fills (a constraint in the Intent) or to reject and wait for a full fill from another provider.

If partial fills are accepted, multiple providers may fill portions of the same Intent. The Intent layer tracks cumulative fills against the total `sourceAmount`. When the sum of fills meets or exceeds the Intent's requirement, the Intent is marked `FULFILLED`.

### 10.3 Multi-provider fills

[SPECULATIVE] A single Intent may be filled by multiple providers in cooperation or competition. For example, Provider A fills 60% from its inventory and Provider B fills 40% via a DEX swap. Multi-provider fills require coordination (who fills what portion?) that is managed by the Intent relay or the wallet, not by Settlement.

### 10.4 Fallback execution

If the selected provider fails (timeout, reverted transaction, insolvency), the Intent falls back:
1. The wallet rebroadcasts the Intent for new Quotes.
2. If a bond was posted, the bond may cover the user's delay cost.
3. If no provider fills within the Intent's expiry, the Intent enters the expired/refund path.
4. The native custody path (waiting for the Settlement finalization + `ReleaseAdapter` release) is always available as the fallback of last resort.

### 10.5 Expired Intents

An Intent past its `expiry` is no longer fillable. If the user's source asset was already deposited into Settlement, the timeout/refund mechanism of the Bridge Framework applies (`BRIDGE-FRAMEWORK-SPEC.md` §7.6, §10.4). If the source asset was not yet deposited (the Intent expired during the quoting phase), nothing happened on-chain and the user simply retains their asset.

### 10.6 Failed execution and refunds

If execution fails after commit (the provider accepted but could not deliver), the resolution depends on how far the process advanced:
- **Before Settlement deposit:** nothing happened on-chain. The user retries or abandons. No refund needed.
- **After Settlement deposit, before finalization:** the deposit is in the Settlement pipeline. The user waits for finalization and either selects another provider or waits for native custody release.
- **After finalization, execution failed:** the authorization is finalized and available. Another provider can fill it, or the native custody path delivers. The authorization does not expire (it is a finalized fact).
- **After finalization, timeout elapsed:** the Bridge Framework's timeout/refund path activates, and the source asset is re-credited to the user.

### 10.7 Replay protection

Intents carry a `nonce` and a `signature` for client-side replay protection. On-chain replay protection is Settlement's job (via `outboxId` and `processedOutbox`). The Intent layer's nonce prevents the same signed Intent from being submitted to providers multiple times without the user's re-authorization; it does not interact with Settlement's replay mechanism.

---

## 11. Cross-Domain Intents

### 11.1 The multi-hop case

A user's desired outcome may span multiple chains and multiple Authorization Domains:

```
User has BTC on Bitcoin
    → wants to end up with MOVE tokens on Movement
```

This requires:
1. BTC locked on Bitcoin (source chain input).
2. BTC bridge domain verifies and authorizes a zBTC mint on Zenon.
3. zBTC swapped for MOVE (or an intermediate) via a DEX or solver on Zenon.
4. MOVE authorized for release to Movement via the Movement bridge domain.
5. MOVE released on Movement via that domain's `ReleaseAdapter`.

Steps 2 through 4 cross multiple Authorization Domains. The user does not care about this decomposition. The user cares about: "I have BTC, I want MOVE."

### 11.2 Decomposition is the Execution Provider's job

The Intent layer does not decompose cross-domain Intents into per-domain steps. The Execution Provider does. The provider evaluates the Intent, determines the optimal route (which domains to cross, which assets to swap, which liquidity sources to tap), and executes each step. The user sees one Intent; the provider sees (and manages) multiple Settlement operations.

### 11.3 Multi-provider cooperation

[SPECULATIVE] For complex cross-domain Intents, multiple providers may cooperate: Provider A handles the BTC-to-Zenon leg (because it has a BTC `ChainVerifier` and custody infrastructure), Provider B handles the Zenon-internal swap (because it has DEX routing infrastructure), and Provider C handles the Zenon-to-Movement leg (because it operates the Movement `ReleaseAdapter`). Coordination among providers is a market/protocol-layer problem above Settlement.

### 11.4 Cross-domain optimization

[SPECULATIVE] When many Intents cross the same domain boundaries in both directions (BTC→ETH and ETH→BTC), a netting opportunity exists: instead of executing each Intent individually, offsetting Intents cancel to the net flow, reducing gross capital requirements and gas costs. Netting is an optimization within the Execution Provider layer (or across cooperating providers); Settlement sees only the net authorized flows, each individually conservation-bounded.

---

## 12. Relationship to Settlement

Settlement never sees an Intent.

Settlement sees deposits, inputs, batch commitments, and outbox messages. All of these are produced by the user's wallet, the executor, or the relayer after the Intent has been matched, quoted, selected, and committed. The Intent layer is upstream of Settlement, not inside it.

This separation is not incidental. It is the structural guarantee that Settlement remains a deterministic truth oracle. If Settlement had to interpret Intents, it would need to understand user preferences, pricing, and execution strategy. It would cease to be chain-agnostic and would become a market participant. Every bridge exploit that traces back to "the bridge made a pricing/routing/execution decision" is an instance of this boundary violation.

Settlement authorizes. It does not interpret.

---

## 13. Relationship to Execution Providers

Execution Providers sit between the Intent layer and Settlement. They consume Intents (from users/wallets/relays), produce Settlement inputs (deposits, contract calls), and fulfill authorizations (delivery on the destination chain).

The flow:

```
Intent (from user)
    ↓
Execution Provider evaluates, quotes, accepts
    ↓
Provider initiates Settlement inputs (deposit, CallL2)
    ↓
Settlement produces finalized authorization
    ↓
Provider fulfills authorization (delivers asset)
    ↓
User receives outcome
```

Execution Providers never modify Settlement. They consume its output. They compete on price, speed, trust, and reliability, all of which are market properties, not protocol properties.

---

## 14. Relationship to Liquidity

Liquidity does not fulfill Intents directly. The chain of responsibility is:

```
Intent → Execution Provider → Liquidity
```

Never:

```
Intent → Liquidity
```

The user does not interact with a liquidity pool, a market maker's inventory, or an LP position. The user expresses an Intent; an Execution Provider accepts it; the provider sources the liquidity needed to fulfill it. Where the provider finds that liquidity (its own inventory, a DEX, an LP pool, an OTC desk, another bridge) is the provider's business, invisible to the user and invisible to Settlement.

If the Intent layer directed liquidity, it would need to understand pool mechanics, AMM curves, LP positions, and rebalancing. It would cease to be a simple outcome-description layer and become a DeFi protocol. That is not its job.

---

## 15. Future Research

The following topics are identified as potential future work. They are explicitly speculative and do not commit any implementation or roadmap.

**Execution auctions.** A formal auction mechanism where Intents are auctioned to Execution Providers, with structured bidding, commitment rules, and penalty for non-performance.

**Dutch auctions for intents.** An Intent that starts with tight constraints (low fee, low slippage) and relaxes over time until a provider fills. Discovers the market-clearing execution price dynamically.

**Solver reputation systems.** A decentralized reputation layer that tracks solver performance (fill rate, latency, dispute rate) and makes it available to wallets and applications as a selection signal.

**Shared inventory.** [SPECULATIVE] Multiple providers share a common liquidity pool, reducing individual capital requirements and improving fill rates. Capital-efficiency gain vs coordination overhead.

**Intent batching.** Grouping multiple small Intents into a single batch fill, amortizing gas and execution costs. Useful for payment use cases with many small-value transfers.

**Intent marketplaces.** A venue where Intents are listed, quoted, and traded as standardized objects. An order book for outcomes.

**Intent delegation.** A user authorizes an agent (a smart contract, an AI, a portfolio manager) to create and manage Intents on their behalf, within bounded parameters.

**AI-generated intents.** [SPECULATIVE] Autonomous agents that monitor portfolio conditions, market events, or user-defined triggers and generate Intents automatically. An AI rebalancer that expresses "move 10% of portfolio from ETH to stables" as an Intent.

**Autonomous execution.** [SPECULATIVE] An Execution Provider that is itself an AI agent, evaluating Intents, sourcing liquidity, and executing fills without human intervention.

**Cross-domain routing optimization.** Algorithms that find the optimal path across multiple domains and chains for complex multi-hop Intents, minimizing total cost and latency.

**Intent compression.** Compact encoding of Intents for bandwidth-constrained environments (mobile, embedded, IoT payment devices).

**Cross-domain settlement optimization.** Netting, batching, and aggregation across domains to reduce the gross number of Settlement operations for a given set of Intents.

---

## 16. Closing

This document has described the layer that sits above Settlement and above Execution: the intent layer, where users express what they want and Execution Providers compete to deliver it.

The three Frontier documents now form a complete stack:

```
INTENT-ORDERFLOW-FRAMEWORK    ← user wants an outcome
    ↓
BRIDGE-FRAMEWORK-SPEC         ← Settlement produces a finalized authorization
    ↓
EXECUTION-PROVIDER-FRAMEWORK  ← Execution Provider delivers the outcome
```

Each layer has one job, one product, and clear boundaries. Settlement does not interpret Intents. Execution does not alter Settlement. Intents do not direct Liquidity.

The closing principle:

> **Users express outcomes. Settlement authorizes truth. Execution Providers compete to fulfill that truth. Markets supply capital.**

That is the complete separation of concerns.

---

**Document end.**

This document is Frontier research. It does not commit to any implementation, any token model, or any specific Intent relay design. It defines the layer, the vocabulary, and the design space. The controlling authority for all on-chain rules remains `SPEC.md` v1.3.0; for the Bridge Framework, `BRIDGE-FRAMEWORK-SPEC.md` v0.2.0; for Execution Providers, `EXECUTION-PROVIDER-FRAMEWORK.md` v0.1.0. Where this document speculates, it says so.
