# Project Zeno: Execution Provider Framework

**Document status:** Frontier research. Non-normative.
**Version:** 0.1.0
**Governing documents (in priority order):**

1. `SPEC.md` v1.3.0 (the controlling authority for all on-chain rules)
2. `BRIDGE-FRAMEWORK-SPEC.md` v0.2.0 (the Bridge Framework normative specification)

This document is Frontier research. It does not make implementation claims, advertise future features, or bind any deployment. Every speculative component is marked. Where this document references a mechanism defined in `SPEC.md` or `BRIDGE-FRAMEWORK-SPEC.md`, the governing document controls; this document restates only for architectural context and never relaxes any active rule.

**Boundary discipline:** This document begins where the Bridge Framework ends. The Bridge Framework specifies how a settlement authorization is produced, committed, finalized, and proven. This document specifies the architectural layer that consumes that finalized authorization and turns it into a real-world outcome: an asset moved, a payment completed, a position opened. Everything before finalization is Settlement's concern. Everything after finalization is Execution's concern.

**Commit discipline:** The separation between Settlement and Execution is the load-bearing structural claim of this document. If a mechanism described here would require Settlement to know about liquidity, pricing, or execution strategy, the mechanism is wrong and MUST be redesigned to consume Settlement output without altering Settlement logic.

---

## 1. Why this document exists

### 1.1 The architectural gap

The Bridge Framework ends with a clean, well-defined object: a finalized settlement authorization.

Concretely, a `kind=1` outbox message, committed in `outboxRoot`, enclosed in a batch that has reached its finality condition (withdrawal delay elapsed under `ATTESTATION`, challenge window clear under `OPTIMISTIC`, validity proof verified under `ZK_VALIDITY`), and relayed via `RelayMessage` with an inclusion proof that Settlement has accepted and recorded in `ProcessedOutbox`. At this point, Settlement has produced its product: a deterministic, replay-protected, conservation-bounded authorization to release a specific amount of a specific asset to a specific recipient.

The Bridge Framework then says: "the `ReleaseAdapter` releases the real foreign asset" (`BRIDGE-FRAMEWORK-SPEC.md` §7.5). And it stops.

That sentence hides an entire architectural layer. "Releases the real foreign asset" is not a single operation. It is a market problem, a liquidity problem, a custody problem, a pricing problem, and a risk problem. The Bridge Framework correctly declines to specify any of these because they are not Settlement concerns. But they must be specified somewhere, because without them, a finalized authorization is a provably valid instruction that nobody executes.

This document fills that gap.

### 1.2 What this document is not

This is not a bridge specification. The bridge is specified. This is not a Settlement specification. Settlement is specified. This is not a liquidity protocol. Liquidity is external.

This document is an architectural framework for the systems that sit between a finalized settlement authorization and its real-world fulfillment. These systems are called **Execution Providers**.

### 1.3 The guiding philosophy

> **Settlement produces truth. Execution fulfills truth.**

Settlement's output is a deterministic fact: "domain `d` has authorized the release of `amount` of `asset` to `recipient`, and this authorization is finalized, replay-protected, and conservation-bounded." Settlement does not know whether anyone has the liquidity to fulfill it. Settlement does not know the current price of the asset. Settlement does not know which custodian holds the real collateral. Settlement does not care. Its job is to produce an authorization that is correct, final, and unforgeable. Everything else is someone else's problem.

Execution's job is to solve that someone-else's-problem: find the liquidity, price the conversion (if any), manage the custody, bear the risk, and deliver the asset. Execution consumes Settlement's truth and produces a real-world outcome.

These two responsibilities must remain completely separated. Merging them is the central architectural error of most bridge designs, and the source of most bridge exploits. The Domain Settlement Layer never moves assets. It creates deterministic truth that specialized execution systems can safely consume.

---

## 2. Separation of responsibilities

### 2.1 The pipeline and its separable concerns

The path from a foreign event to a delivered asset passes through a strict pipeline of three stages. Each stage produces exactly one product and consumes exactly one input:

```
Verification       → Foreign-fact truth      (input: raw foreign data)
    ↓
Settlement         → Finalized authorization (input: verified foreign fact)
    ↓
Execution          → Fulfilled intent        (input: finalized authorization)
```

Execution, in turn, may depend on several separable concerns that are not stages in the pipeline but resources and services Execution draws on:

```
Execution may depend on:
    Liquidity   : capital to deliver (inventory, pools, OTC, other bridges)
    Pricing     : valuation for asset conversion (oracles, DEXes, RFQ, negotiated)
    Custody     : where the deliverable asset is held (protocol, custodian, solver)
    Routing     : which venue or path to use (DEX aggregation, multi-hop)
    Risk        : exposure management (hedging, bond sizing, timeout policy)
```

These five concerns are not ordered. An Execution Provider may need pricing before it sources liquidity (to decide whether the fill is profitable) or may need liquidity before it can price (to know what pool depth is available). They are separable in the sense that each can be changed independently: swapping the pricing source does not require changing the liquidity source, and changing the custody model does not require changing the routing logic.

### 2.2 Why these responsibilities must never be merged

**Verification + Settlement:** If Settlement had to verify foreign facts itself, it would need to understand every foreign chain's consensus, finality, and data format. The Bridge Framework solved this by making the `ChainVerifier` a plugin inside the executor's STF, keeping Settlement chain-agnostic (`BRIDGE-FRAMEWORK-SPEC.md` §7.3). Merging them would destroy the class/instance separation that lets a single Settlement serve BTC, ETH, and SOL.

**Settlement + Execution:** If Settlement had to know about execution, it would need to know about liquidity, pricing, and custody. It would need to select an Execution Provider, manage their collateral, adjudicate their performance, and handle their failures. Every one of these concerns is market-dependent, chain-dependent, latency-sensitive, and changes faster than any on-chain protocol can adapt. Merging them would make Settlement a market participant instead of a truth oracle, introducing exactly the counterparty risk Settlement exists to eliminate.

**Execution + Liquidity (separable concern):** If Execution were coupled to a specific liquidity source, the system would be captive to that source's depth, pricing, and availability. By keeping Liquidity as a separable concern, an Execution Provider can source from any combination of its own inventory, external LPs, DEXes, OTC desks, or other bridges, choosing the best available option per authorization without any protocol change.

**Pricing as a separable concern:** If the protocol determined price, it would need an oracle, and that oracle would become a trust dependency and an attack surface. By keeping Pricing separable, the protocol has no opinion on what an asset is worth; it only knows what amount was authorized, what amount was delivered, and whether the authorization was consumed. Price discovery happens in the market, where it belongs.

### 2.3 The product of each responsibility

**Pipeline stages:**

| Stage | Product | Consumer |
|---|---|---|
| **Verification** | A proven foreign fact ("this lock happened on chain C at block H") | The domain's STF / `ChainVerifier` |
| **Settlement** | A finalized authorization ("release `amount` of `asset` to `recipient`") | Execution Providers |
| **Execution** | A fulfilled intent ("the asset was delivered to the recipient") | The end user |

**Separable concerns (consumed by Execution):**

| Concern | Product | Nature |
|---|---|---|
| **Liquidity** | Capital ("the asset to deliver exists and is available") | Economic resource |
| **Pricing** | Valuation ("the exchange rate between A and B at time T") | Market information |
| **Custody** | Safekeeping ("the asset is held here and releasable under these rules") | Operational infrastructure |
| **Routing** | Path selection ("swap through this pool, then this pool") | Optimization |
| **Risk** | Exposure management ("bond this much, hedge this way, timeout at T") | Risk policy |

Settlement never determines price. Settlement never provides liquidity. Settlement never selects an Execution Provider. Settlement's sole product is a finalized, deterministic, conservation-bounded authorization. Everything else is downstream.

---

## 3. Execution Providers

### 3.1 Definition

An **Execution Provider** is any system, entity, or protocol that observes finalized settlement authorizations, determines how to fulfill them, and performs the fulfillment. Execution Providers are external to the Domain Settlement Layer. They consume Settlement's product; they do not alter it.

An Execution Provider:
- Reads finalized `kind=1` outbox authorizations from Settlement (or from a relay that mirrors them).
- Determines whether it can fulfill the authorization (liquidity, pricing, risk, collateral).
- Performs the fulfillment on the destination chain (the "last mile" delivery).
- Optionally proves fulfillment back to Settlement or to a separate accounting layer.

An Execution Provider does NOT:
- Alter the settlement authorization.
- Influence which authorizations are produced.
- Participate in verification or consensus.
- Control replay protection (that is Settlement's job via `processedOutbox` and the foreign-side per-`outboxId` set).

### 3.2 Taxonomy of Execution Providers

Execution Providers vary along three axes: **custody model** (who holds the deliverable asset), **pricing model** (how conversion rates are determined, if applicable), and **trust model** (what trust the user places in the provider beyond Settlement's guarantee).

| Provider type | Custody | Pricing | Trust model | Example |
|---|---|---|---|---|
| **Native custody** | The protocol's own collateral pool (BitVM graph, lock contract, program) | N/A (same asset) | Trust-minimized: the `ReleaseAdapter` verifies the Zenon proof directly | A BitVM operator releasing BTC from the custody UTXO |
| **Institutional custodian** | A regulated entity holding real assets | Negotiated / OTC | Counterparty trust in the custodian | A licensed custodian releasing fiat or regulated securities |
| **Decentralized solver** | Solver's own inventory or sourced on demand | Market / DEX / RFQ | Bonded: solver posts collateral covering potential loss | A permissionless solver racing to fill authorizations |
| **Market maker** | MM's inventory | MM's quoted spread | Counterparty trust, optionally bonded | A professional firm providing continuous liquidity |
| **DEX execution** | The DEX's liquidity pools | AMM pricing / order book | Smart-contract trust (the DEX itself) | Uniswap, Raydium, or any on-chain exchange |
| **RFQ system** | Responder's inventory | Competitive quote | Quote binding (optionally on-chain) | An RFQ platform soliciting quotes from multiple makers |
| **External bridge** | The bridge's own custody | Bridge's pricing | Trust in the external bridge's security model | Using Wormhole or CCIP as an Execution Provider for a specific leg |
| **Payment processor** | Processor's settlement account | Fiat conversion rate | Regulatory trust | A payment rail converting crypto authorization to fiat delivery |

### 3.3 The Execution Provider is not a protocol role

Unlike the relayer (permissionless, trustless, can only withhold) or the executor (bonded, entitled, runs the STF), an Execution Provider is **not a protocol-defined role**. The protocol does not select, bond, schedule, or adjudicate Execution Providers. The protocol produces a finalized authorization; any entity that can read that authorization and deliver the asset to the recipient is an Execution Provider.

This is the key structural decision. By keeping Execution Provider selection out of the protocol, the system avoids:
- Protocol-level liquidity requirements (the protocol does not need to know if anyone can fill an authorization).
- Protocol-level pricing oracles (the protocol does not need to know the current exchange rate).
- Protocol-level counterparty risk (the protocol does not vouch for any provider's solvency).
- Protocol-level market structure (the protocol does not mandate AMMs, order books, or any specific execution venue).

The protocol's guarantee to the user is: "your authorization is correct, final, and unforgeable." The market's guarantee to the user is: "someone will fill it, at a price, with a latency." These are different guarantees from different systems, and conflating them is the design error this architecture avoids.

### 3.4 Permissionless observation

[SPECULATIVE] Execution Providers observe finalized authorizations by reading Settlement state (committed batches, finalized outbox messages, and their proofs). This observation is permissionless: the data is public on L1 (Zenon momentum chain), and any party can read it, verify the proofs, and decide whether to execute. There is no Execution Provider registry, no KYC gate, and no protocol-level approval process. Competition among providers is a market property, not a protocol property.

> Whether a specific deployment chooses to restrict Execution Provider access (for example, by requiring bonds, by restricting the `ReleaseAdapter` to a known set of operators, or by requiring regulatory compliance) is a deployment decision, not a protocol decision. The framework supports both permissionless and permissioned execution models without protocol changes.

---

## 4. Execution Profiles

An **Execution Profile** describes a specific combination of custody model, pricing model, trust model, latency envelope, oracle requirements, collateral requirements, and failure modes. Different Authorization Domains may use different Execution Profiles, and a single domain may support multiple profiles simultaneously (for example, a BTC bridge that supports both native custody release and solver-fronted fast release).

### 4.1 Native Custody

The `ReleaseAdapter` itself is the Execution Provider. It verifies the Zenon finalized-batch proof, checks replay protection, and releases the real asset from protocol-controlled custody (a BitVM transaction graph, a lock contract, a program account).

| Property | Value |
|---|---|
| **Trust** | Trust-minimized: correctness follows from the `ReleaseAdapter` contract/graph logic and the Zenon proof |
| **Latency** | Settlement finality + foreign-chain confirmation of the release transaction |
| **Oracle** | None (same-asset release, no conversion) |
| **Collateral** | The locked collateral itself; no additional bond |
| **Failure modes** | `ReleaseAdapter` bug, foreign-chain congestion, operator liveness (BitVM Tier-1 only) |

This is the baseline profile. It is the only profile that is fully trust-minimized (given a correct `ReleaseAdapter` and a sound Zenon proof). Every other profile introduces some form of additional trust, latency improvement, or market interaction.

### 4.2 Wrapped Asset

The destination receives a wrapped/representation token rather than the real underlying asset. The wrapped token is minted on the destination chain, backed by the locked collateral on the source chain, and redeemable through the reverse path.

| Property | Value |
|---|---|
| **Trust** | Trust in the wrapping contract's correctness and the backing ratio |
| **Latency** | Settlement finality + mint transaction confirmation |
| **Oracle** | None (1:1 backing, no conversion) |
| **Collateral** | The locked source asset backs the minted representation |
| **Failure modes** | Wrapping contract bug, de-peg risk if backing is fractional or perception-driven |

### 4.3 Atomic Swap

[SPECULATIVE] The Execution Provider and the user perform a hash-time-locked or signature-locked atomic swap: the provider delivers the real asset on the destination chain, and the user releases payment on the source chain, with both legs cryptographically bound so neither party can cheat.

| Property | Value |
|---|---|
| **Trust** | Trust-minimized (cryptographic binding) |
| **Latency** | Both chains' confirmation times + lock/reveal round trips |
| **Oracle** | None if same-asset; price oracle if cross-asset |
| **Collateral** | Both parties lock their respective assets for the swap duration |
| **Failure modes** | Timeout (both parties refunded), latency (multi-round), liquidity fragmentation |

### 4.4 DEX Swap

The Execution Provider routes the authorized amount through one or more on-chain DEXes on the destination chain, converting the released asset to the desired output asset.

| Property | Value |
|---|---|
| **Trust** | Trust in the DEX contract(s); slippage risk |
| **Latency** | Settlement finality + DEX transaction confirmation |
| **Oracle** | DEX AMM pricing or order-book pricing (endogenous to the DEX) |
| **Collateral** | None beyond the released asset itself (the DEX is the counterparty) |
| **Failure modes** | Slippage exceeding tolerance, insufficient DEX liquidity, front-running/sandwich attacks, partial fills |

### 4.5 Solver Fill

[SPECULATIVE] A bonded solver observes the finalized authorization, fronts the delivery from its own inventory (delivering immediately to the user on the destination chain), and later claims reimbursement by presenting proof of delivery against the finalized authorization.

| Property | Value |
|---|---|
| **Trust** | User trusts the solver to deliver (low risk: user receives first); Settlement trusts the solver's proof of delivery for reimbursement |
| **Latency** | Near-instant on the destination chain (solver fronts); reimbursement latency is Settlement finality |
| **Oracle** | If cross-asset: solver sets the exchange rate (competitive market) |
| **Collateral** | Solver's bond (covers potential misbehaviour); solver's inventory (the fronted capital) |
| **Failure modes** | Solver insolvency, inventory exhaustion, reimbursement dispute, timeout without fill |

### 4.6 Institutional Settlement

[SPECULATIVE] A regulated institution observes the finalized authorization and performs settlement through traditional financial rails (wire transfer, securities settlement, fiat payment).

| Property | Value |
|---|---|
| **Trust** | Full counterparty trust in the institution; regulatory compliance |
| **Latency** | Hours to days (fiat settlement cycles) |
| **Oracle** | Institutional pricing (negotiated rates, FX feeds) |
| **Collateral** | Regulatory capital requirements; no protocol-level bond |
| **Failure modes** | Counterparty default, regulatory freeze, compliance rejection |

### 4.7 Liquidity Pool

[SPECULATIVE] A protocol-managed or independently managed liquidity pool on the destination chain holds reserves that Execution Providers draw from. The pool earns fees for providing capital; providers route through it when their own inventory is insufficient.

| Property | Value |
|---|---|
| **Trust** | Trust in the pool contract; impermanent-loss and utilization risk for LPs |
| **Latency** | Settlement finality + pool withdrawal transaction |
| **Oracle** | Pool pricing (AMM curve or external feed) |
| **Collateral** | LP deposits; pool reserves |
| **Failure modes** | Pool depletion, oracle manipulation, smart-contract bug, bank run |

### 4.8 Future profiles

This taxonomy is not closed. Any system that can observe a finalized Settlement authorization, fulfill it, and (optionally) prove fulfillment is a valid Execution Profile. The framework imposes no constraint on what form execution takes, only that it consumes Settlement output without altering Settlement logic.

---

## 5. Liquidity

### 5.1 Settlement intentionally knows nothing about liquidity

This is a feature, not a gap.

If Settlement required liquidity to finalize, then finalization would depend on market conditions. A liquidity crunch would stall finalization. A liquidity provider's insolvency would compromise Settlement's safety guarantees. A pricing dispute would block authorization. Settlement would cease to be a deterministic truth oracle and become a market participant, with all the counterparty risk that entails.

By making Settlement liquidity-agnostic, the system preserves Settlement's core property: a finalized authorization is correct regardless of whether anyone can currently fill it. The authorization does not expire because no one has liquidity. It does not become invalid because the price moved. It is a fact, recorded on-chain, provable, and consumable whenever an Execution Provider is ready.

### 5.2 Where liquidity lives

Liquidity is external to the Domain Settlement Layer. It lives in:

**Execution Provider inventory.** A solver, market maker, or institutional provider holds assets in their own custody and deploys them to fill authorizations. The provider's capital management, risk hedging, and inventory optimization are their business, not the protocol's.

**On-chain liquidity pools.** AMM pools, lending protocols, and other DeFi primitives on the destination chain provide liquidity that Execution Providers can route through. The protocol does not manage these pools; it does not deposit into them, withdraw from them, or set their parameters.

**OTC and institutional capital.** Professional market makers, OTC desks, and institutional investors provide large-block liquidity through bilateral agreements. These are entirely off-protocol.

**Other bridges.** An Execution Provider may use a third-party bridge to source liquidity if it is cheaper or faster than its own inventory. The authorization from Settlement is agnostic to how the provider sources its capital.

### 5.3 Why LPs do not interact with Settlement

A liquidity provider deposits capital into an Execution Provider's system (or into a destination-chain pool), not into Settlement. Settlement has no LP interface, no deposit/withdraw for liquidity purposes, no yield mechanism, and no impermanent-loss exposure. Settlement holds escrow for domain assets (under the conservation invariant); that escrow is not a liquidity pool and is not available for market-making, lending, or any other use.

The separation is structural: Settlement's escrow is a custody mechanism bounded by conservation (`totalReleased + pendingWithdrawalReserve ≤ totalDeposited`); an LP pool is a capital mechanism bounded by market dynamics. Merging them would either weaken the conservation invariant (by allowing LP withdrawals that reduce custody below authorized outflows) or freeze LP capital (by subjecting it to conservation constraints designed for custody, not for market-making). Neither outcome is acceptable.

---

## 6. Pricing

### 6.1 When pricing matters

Many authorizations involve same-asset delivery: BTC locked on Bitcoin, BTC (or zBTC) released on the destination. No conversion, no pricing. The Execution Provider delivers exactly what Settlement authorized.

Pricing enters the picture when execution requires asset conversion:
- BTC authorization, but the user wants ETH on Ethereum.
- ZNN authorized for release, but the destination chain uses SOL for gas.
- A stablecoin-denominated authorization fulfilled in a volatile asset.

In these cases, someone must determine the exchange rate. That someone is never Settlement.

### 6.2 Settlement truth versus market pricing

| Concern | Owner | Mechanism |
|---|---|---|
| "How much was authorized?" | Settlement | The `amount` field in `PegOutAuthorization`, conservation-bounded, finalized |
| "What is the asset worth in terms of another asset?" | The market | Oracle feeds, DEX prices, RFQ quotes, negotiated rates |
| "What exchange rate does the user receive?" | The Execution Provider | Competitive quoting, slippage protection, user-selected tolerance |

Settlement records `amount` and `asset`. It does not record price, exchange rate, or market conditions. A finalized authorization for 1.0 BTC is always an authorization for 1.0 BTC, regardless of whether BTC is worth $30,000 or $100,000 at the moment of execution. The price risk between authorization and execution is borne by the Execution Provider (or shared with the user, depending on the execution profile).

### 6.3 Pricing mechanisms

**Oracle-based pricing.** The Execution Provider consults an external price oracle (Chainlink, Pyth, a TWAP from a reference DEX) to determine the conversion rate. Oracle risk: stale data, manipulation, flash-loan attacks.

**DEX pricing.** The Execution Provider routes through an on-chain DEX and accepts the AMM's effective price, including slippage. DEX risk: front-running, sandwich attacks, insufficient depth.

**RFQ (Request for Quote).** The Execution Provider solicits competitive quotes from multiple market makers and selects the best offer. RFQ risk: quote expiry, last-look, counterparty performance.

**Market-maker pricing.** A professional market maker quotes a spread and commits to fill at the quoted price for a limited time. MM risk: inventory risk, adverse selection.

**Negotiated pricing.** For large or institutional authorizations, the Execution Provider and the user (or the user's agent) negotiate terms bilaterally. No protocol involvement.

### 6.4 The protocol's non-opinion

The protocol has no opinion on which pricing mechanism is correct. It does not embed an oracle. It does not mandate a DEX. It does not require RFQ. The Execution Provider selects the pricing mechanism appropriate to the authorization's size, urgency, and asset pair. The protocol's contribution to pricing safety is indirect: by making the authorization deterministic and conservation-bounded, it ensures the Execution Provider knows exactly what it is filling and can price accordingly without worrying that the authorization amount might change or that a double-spend might occur.

---

## 7. Solvers

### 7.1 What a solver is

[SPECULATIVE] A solver is a permissionless Execution Provider that competes to fill finalized authorizations. Solvers observe Settlement state, evaluate whether they can profitably fill an authorization (given their inventory, pricing, and risk tolerance), and if so, front the delivery to the user on the destination chain. The solver then claims reimbursement from the protocol-controlled custody by presenting proof of delivery.

Solvers are the mechanism by which permissionless competition enters the execution layer. Unlike a native custody release (which is deterministic and trust-minimized), solver execution is market-driven: multiple solvers may compete for the same authorization, and the fastest or cheapest solver wins.

### 7.2 Solver architecture

**Inventory.** A solver maintains a balance of deliverable assets on destination chains. This is the solver's own capital, not protocol capital. The solver manages its inventory across chains, rebalancing as needed. Inventory exhaustion is a solver problem, not a protocol problem; an empty solver simply does not fill, and another solver (or the native custody path) takes over.

**Bonding.** [SPECULATIVE] A solver MAY be required to post a bond (in ZNN, QSR, a stablecoin, or the bridged asset) that covers the maximum potential loss from misbehaviour. The bond is NOT required by Settlement (Settlement does not know about solvers); it is required by a solver-coordination contract or a solver registry deployed on the destination chain or on Zenon L1 as a separate module. Bond mechanics (staking, slashing, unstaking delay) are solver-layer concerns, not Settlement concerns.

**Risk.** The solver bears: inventory risk (holding assets that may depreciate), execution risk (the delivery transaction may fail), reimbursement risk (the proof-of-delivery mechanism may have bugs), and competition risk (another solver may fill first, leaving the losing solver with an unrecoverable delivery). Managing these risks is the solver's business.

**Latency.** The solver's competitive advantage is speed: by fronting the delivery before the native custody release would complete, the solver provides the user with faster execution. The solver's reimbursement happens later (after Settlement finality + proof verification), so the solver extends credit to the user for the duration. This credit is priced into the solver's fee.

**Settlement reimbursement.** [SPECULATIVE] After delivering to the user, the solver presents a proof-of-delivery (a destination-chain transaction receipt, verified by a `ChainVerifier` or an equivalent mechanism) to claim the authorized amount from custody. The reimbursement path is the reverse of the peg-in path: the solver proves a foreign event (its own delivery), and the protocol releases the escrowed amount. The exact reimbursement mechanism is an OPEN DESIGN question and is not specified in this document.

**Timeouts.** If a solver claims an authorization but fails to deliver within a timeout window, the authorization MUST remain available for another provider (or the native custody path). The authorization itself does not expire (it is a finalized fact); only the solver's claim on it expires. Timeout mechanics are solver-layer concerns.

**Competition.** Multiple solvers observing the same authorization creates a competitive market. The user benefits from this competition (faster, cheaper execution). The protocol benefits because liveness does not depend on any single solver. MEV considerations arise: solvers may be front-run by other solvers or by block builders on the destination chain. These are market-structure problems, not protocol problems.

### 7.3 MEV considerations

[SPECULATIVE] Solver competition creates MEV opportunities:
- **Priority gas auctions:** Solvers compete for inclusion priority on the destination chain, paying higher gas fees, which accrues to destination-chain validators, not to the protocol.
- **Cross-domain MEV:** A solver that also operates as a sequencer, validator, or block builder on the destination chain may extract value from ordering solver transactions relative to other activity. This is a destination-chain MEV problem, not a Settlement problem.
- **Toxic flow:** Solvers may selectively fill profitable authorizations (favorable price movements between authorization and execution) and avoid unprofitable ones (adverse price movements). This is adverse selection, a standard market-making risk, and is managed by the solver's risk model, not by the protocol.

The protocol's defense against MEV is structural: by not participating in execution, it does not create MEV. By keeping authorization deterministic and public, it enables competition. MEV in execution is a market cost, not a protocol vulnerability.

---

## 8. Market Makers

### 8.1 Professional execution

A market maker is a professional Execution Provider that maintains continuous inventory and quotes prices for filling authorizations. Unlike a solver (which is typically permissionless, competitive, and opportunistic), a market maker may operate under a bilateral agreement, a regulated framework, or a protocol-defined commitment.

### 8.2 Observing finalized Settlement

Market makers observe finalized Settlement authorizations through the same public interface as any other Execution Provider. They do not need to trust relayers, because the authorization is a finalized on-chain fact, provable from L1 state. A market maker can independently verify:
- The batch is finalized (by checking `submittedAtHeight` + withdrawal delay, or challenge-window status, or proof verification).
- The authorization is unspent (by checking `processedOutbox`).
- The conservation invariant holds (by checking the domain's custody counters).

This is the key property that makes market makers viable as Execution Providers without protocol-level integration: they can verify the authorization's validity themselves, without trusting any intermediary. The trust model between the market maker and the user is then a bilateral concern, not a protocol concern.

### 8.3 Why market makers never need to trust relayers

The relayer is permissionless and trustless (`SPEC.md` §12; `BRIDGE-FRAMEWORK-SPEC.md` §7.4): it can only withhold, never forge. A market maker does not consume relayer output; it reads Settlement state directly (or verifies proofs against L1). If the relayer is down, the market maker's delivery is delayed (because the authorization has not been relayed to the destination), but the market maker is never at risk of filling a forged authorization, because it verifies finalization independently.

---

## 9. DEX Integration

### 9.1 DEXes as Execution Providers

A DEX on the destination chain can serve as an Execution Provider (or as a component within a more complex Execution Provider's routing). The released or fronted asset is swapped through the DEX to produce the user's desired output asset.

### 9.2 Routing

An Execution Provider that uses DEX execution must solve a routing problem: given an input asset and a desired output asset, find the sequence of swaps across available pools that minimizes cost (slippage + fees) and meets the user's timing requirements. This is a well-studied problem (DEX aggregators like 1inch, Jupiter, and Paraswap solve it) and is entirely external to Settlement.

### 9.3 Slippage and execution guarantees

The Execution Provider, not Settlement, manages slippage. The user specifies a slippage tolerance (or a minimum output amount) to the Execution Provider. The provider routes accordingly. If the route cannot satisfy the tolerance, the provider does not execute (and the authorization remains available for another provider or for the native custody path).

Settlement has no concept of slippage. Settlement authorized `amount` of `asset`; whether that amount is swapped, at what price, and with what slippage is entirely between the Execution Provider and the user.

### 9.4 Partial fills

[SPECULATIVE] If a DEX cannot fill the entire authorized amount in a single transaction (insufficient pool depth), the Execution Provider may perform partial fills across multiple transactions or multiple pools. The provider is responsible for tracking cumulative fills and ensuring the total delivered matches the authorized amount minus any agreed fee. Settlement knows nothing about partial fills; it authorized a single `outboxId` for a single `amount`, and the `outboxId` is consumed once, regardless of how many destination-chain transactions the Execution Provider uses to fulfill it.

### 9.5 Failure recovery

If a DEX execution fails (reverted transaction, exceeded slippage, pool depleted), the Execution Provider retries, reroutes, or abandons the attempt. Abandonment does not consume the authorization; the authorization remains finalized and available. The user may choose a different Execution Provider, wait for the native custody path, or invoke a timeout/refund mechanism (as defined in `BRIDGE-FRAMEWORK-SPEC.md` §7.6, §10.4).

---

## 10. Execution Bonds

### 10.1 Purpose

[SPECULATIVE] An execution bond is optional collateral that an Execution Provider posts to guarantee performance. It is not a protocol requirement (Settlement does not know about bonds); it is a mechanism that a solver registry, a market-maker agreement, or a destination-chain contract may impose on providers to ensure they deliver.

### 10.2 Collateral options

The bond denomination is an architectural choice, not a protocol decision:

**QSR (Zenon Network utility token).** If the bond is posted on Zenon L1, QSR is a natural denomination. It is native, liquid within the ecosystem, and does not require a foreign asset.

**Native destination-chain asset.** A bond in ETH (for an Ethereum `ReleaseAdapter`), SOL (for Solana), or BTC is useful because the bond can be slashed and paid to the affected user on the same chain where the delivery failed.

**Stablecoin.** A bond in USDC or USDT provides a stable collateral value, avoiding the problem of a bond denominated in a volatile asset losing its coverage during a price drop.

**External collateral.** Restaking, insurance protocols, or credit-default mechanisms may provide bond coverage without the Execution Provider locking up capital directly.

### 10.3 What this document does not do

This document does not assign token economics to execution bonds. It does not mandate a bond denomination, a slashing rate, a staking period, or a yield mechanism. It defines the architectural possibility: an Execution Provider MAY be bonded, the bond MAY be denominated in any asset, and the bond's lifecycle (staking, slashing, unstaking, claiming) is managed by a module external to Settlement.

---

## 11. Failure handling

### 11.1 The failure taxonomy

Execution failures are distinct from Settlement failures. Settlement failures (invalid batch, conservation violation, replay) are handled by Settlement's own MUST-fail conditions (`BRIDGE-FRAMEWORK-SPEC.md` §13.16). Execution failures are handled by the Execution Provider, the user, or a coordination contract external to Settlement.

| Failure | Whose problem | Resolution |
|---|---|---|
| Execution Provider does not fill | Execution Provider / market | Another provider fills; or native custody path; or timeout/refund |
| Delivery transaction reverts | Execution Provider | Retry, reroute, or abandon (authorization remains available) |
| Solver fronts but cannot prove delivery | Solver | Solver eats the loss; authorization is consumed by the delivery, solver's reimbursement claim fails |
| Price moves adversely between authorization and execution | Execution Provider | Provider absorbs the loss or adjusts the quoted fee; Settlement is unaffected |
| Destination chain congested | All parties | Wait; authorization does not expire |
| `ReleaseAdapter` bug | Protocol deployment | Bounded by per-domain isolation and conservation invariant; halted by adapter governance |

### 11.2 Timeouts

A finalized Settlement authorization does not expire on its own (it is a recorded fact). However, the messaging layer supports optional timeout deadlines (`BRIDGE-FRAMEWORK-SPEC.md` §7.6): if the authorization carries a `timeout` and the destination does not process it by the deadline, the source-side refund/rollback path activates. Timeouts are evaluated at the destination, not at the source, and delivery and refund are mutually exclusive on the `outboxId` (`BRIDGE-FRAMEWORK-SPEC.md` §10.6).

From the Execution Provider's perspective, a timeout means: fill before the deadline or lose the opportunity. The timeout does not affect the provider's other operations; it only makes this specific authorization unavailable after expiry.

### 11.3 Retries

Retries are idempotent by construction. On the Zenon side, `RelayMessage` is idempotent on `outboxId` (`SPEC.md` §17.3): re-relaying the same message is a rejected no-op. On the destination side, the `ReleaseAdapter` maintains its own per-`outboxId` set, so a second release attempt for the same `outboxId` is rejected. An Execution Provider that retries a failed delivery transaction is safe: the retry either succeeds (consuming the `outboxId`) or fails again, but never double-delivers.

### 11.4 Cancellation and expiration

Settlement does not support cancellation of a finalized authorization (finalized facts cannot be unfinalized). The user's recourse for an unfilled authorization is the timeout/refund path (if a timeout was specified) or indefinite waiting (if no timeout was specified). The Execution Provider's recourse for a claimed-but-unfilled authorization (solver scenario) is to abandon the claim and let another provider fill.

### 11.5 Partial execution

[SPECULATIVE] If an Execution Provider delivers a partial amount (for example, 0.7 of 1.0 BTC authorized), the authorization is not partially consumed on Settlement (Settlement's `outboxId` is consumed or not, never partially). The provider must deliver the full authorized amount to complete the execution. Any partial-delivery tracking is the provider's internal accounting, not Settlement's.

### 11.6 Replay protection

Replay protection is Settlement's job, not the Execution Provider's. Settlement ensures at-most-once processing of each `outboxId` via `processedOutbox` (Zenon side) and the per-`outboxId` set (foreign side). The Execution Provider relies on this guarantee: if it verifies that the authorization's `outboxId` has not been processed, it can fill with confidence that no other provider has already filled the same authorization on the protocol side. Destination-chain race conditions between providers are market-structure problems (first to confirm wins; losing providers' transactions revert).

---

## 12. Execution Fees

### 12.1 The fee decomposition

The total cost to the user of a cross-chain operation decomposes into independent components, each owned by a different layer:

| Fee component | Paid to | Set by | Settlement involvement |
|---|---|---|---|
| **Source-chain inclusion** | L1 validators (plasma/PoW) | L1 fee market | None (prerequisite for input inclusion, `SPEC.md` §4.1) |
| **Off-chain execution (L2 gas)** | Domain executor | Metering schedule (`SPEC.md` §10.2) | Settlement records gas usage; does not price it |
| **Destination-chain gas** | Destination-chain validators | Destination fee market | None |
| **Execution Provider fee** | Execution Provider (solver, MM, custodian) | Market competition | None |
| **Solver premium** | Solver | Solver's risk model | None |
| **DEX swap fee** | DEX LPs | DEX protocol | None |
| **Custody fee** | Custodian | Custodian's pricing | None |
| **Bridge fee** (if using an external bridge as EP) | External bridge | External bridge's pricing | None |

### 12.2 Settlement does not price execution

Settlement's `FeeQuote` (`BRIDGE-FRAMEWORK-SPEC.md` §7.8) is advisory and covers source inclusion + L2 gas + estimated destination gas. It does not include Execution Provider fees, solver premiums, DEX swap fees, or any market-driven cost. These are quoted by the Execution Provider to the user at the time of execution, not by Settlement at the time of authorization.

The reason is architectural: Settlement does not know which Execution Provider the user will choose, what pricing mechanism the provider will use, or what market conditions will prevail at execution time. Any fee embedded in the authorization would be stale by the time execution occurs, and any protocol-mandated fee would be either too high (driving users away) or too low (driving providers away). The market sets the execution fee, and Settlement stays out of it.

### 12.3 Quote generation

[SPECULATIVE] Execution Providers generate quotes for users before authorization. A quote typically includes: the provider's identity, the exchange rate (if conversion), the provider's fee, the estimated destination gas, the expiry time, and a commitment to fill at the quoted terms. The quote is a bilateral agreement between the user and the provider; Settlement does not validate, enforce, or record it. If the provider does not honor the quote, the user's recourse is against the provider (through the bond, through reputation, or through legal means), not through Settlement.

---

## 13. Future research

The following topics are identified as potential future work. They are not specified in this document and are explicitly marked as speculative. Their inclusion does not commit any roadmap item or implementation plan.

**Intent-based execution.** Users express an intent ("I want 1 ETH on Ethereum for my 0.05 BTC on Bitcoin") rather than a specific execution path. A solver network competes to find the optimal execution path. The intent is recorded on-chain; the solver fills it and proves fulfillment.

**Shared liquidity.** Multiple Authorization Domains share a common liquidity layer, allowing an Execution Provider to source capital from a unified pool rather than maintaining per-domain inventory.

**Cross-domain net settlement.** Instead of settling each authorization individually, a batch of authorizations across domains is netted (BTC→ETH and ETH→BTC cancel to the net), reducing gross capital requirements and gas costs.

**Execution auctions.** Authorizations are auctioned to Execution Providers, with the winning bidder offering the best execution terms (price, speed, fee) to the user.

**Private order flow.** Users submit authorizations through a private channel (encrypted mempool, MEV-protected relay), preventing front-running and adverse selection by Execution Providers.

**Liquidity routing.** A routing layer across multiple liquidity sources (DEXes, pools, OTC, bridges) finds the optimal path for each authorization, analogous to DEX aggregation but across chains and execution venues.

**Batch execution.** Multiple authorizations are batched into a single execution transaction, amortizing gas costs and reducing latency for small authorizations.

**Inventory optimization.** Solvers and market makers use predictive models to pre-position inventory on destination chains where authorizations are expected, reducing fill latency.

**Cross-domain liquidity coordination.** [SPECULATIVE] A coordination mechanism allows Execution Providers to signal demand and supply across domains, enabling more efficient capital allocation without coupling liquidity to Settlement.

---

## 14. Relationship to the Domain Settlement Layer

### 14.1 The five products

| Layer | Product | Nature of the product |
|---|---|---|
| **Settlement** | Finalized authorization | Deterministic truth: "this release is authorized, final, and unforgeable" |
| **Execution** | Fulfilled intent | Real-world outcome: "the asset was delivered to the recipient" |
| **Liquidity** | Capital | Economic resource: "the asset to deliver exists and is available" |
| **Pricing** | Valuation | Market information: "the exchange rate between A and B at time T" |
| **Oracles** | External information | Off-chain truth: "the price feed, the event outcome, the data point" |

None of these products should be merged. Each responsibility's soundness depends on its own invariants, not on the other responsibilities' behaviour. Settlement is correct even if no Execution Provider exists. Execution is correct even if the price moves. Liquidity can remain available even if pricing data is stale; pricing correctness is an oracle and market problem, not a Settlement problem. Each responsibility can be upgraded, replaced, or forked independently.

### 14.2 What Settlement guarantees to Execution

Settlement guarantees to every Execution Provider:
- **Correctness.** The authorization was produced by a valid STF execution over canonical inputs.
- **Finality.** The authorization has passed its finality condition and will not be reverted (absent an L1 consensus failure).
- **Replay protection.** The `outboxId` can be consumed at most once; no double-spend is possible.
- **Conservation.** The authorized amount is covered by the domain's accounted inflow; Settlement will not authorize outflow exceeding inflow.
- **Determinism.** The authorization is a pure function of L1-anchored data; any party can independently verify it.

Settlement does NOT guarantee to any Execution Provider:
- That someone will fill the authorization.
- That the fill will happen at a particular price.
- That the fill will happen within a particular time.
- That the user will be satisfied with the execution.

These are market guarantees, not protocol guarantees. The separation is clean and intentional.

### 14.3 The architectural principle

This document has described the execution layer that sits between Settlement's deterministic truth and the user's real-world outcome. The layer is modular, competitive, and external. It is filled by Execution Providers that observe, evaluate, and fulfill finalized authorizations. They bring their own liquidity, their own pricing, their own risk models, and their own custody. The protocol provides the truth they consume; the market provides everything else.

The closing principle:

> **The Domain Settlement Layer never moves assets. It creates deterministic truth that specialized execution systems can safely consume.**

Settlement's power is precisely that it does not execute. It does not know the price. It does not know the liquidity. It does not know the market. It knows only what was authorized, by whom, for how much, and that the authorization is final. That is enough. That is its entire product. And because that product is deterministic, unforgeable, and conservation-bounded, any sufficiently motivated Execution Provider can build a business on top of it.

---

**Document end.**

This document is Frontier research. It does not commit to any implementation, any token model, or any specific Execution Provider design. It defines the architectural layer, the separation of responsibilities, and the design space. The controlling authority for all on-chain rules remains `SPEC.md` v1.3.0; for the Bridge Framework, `BRIDGE-FRAMEWORK-SPEC.md` v0.2.0. Where this document speculates, it says so.
