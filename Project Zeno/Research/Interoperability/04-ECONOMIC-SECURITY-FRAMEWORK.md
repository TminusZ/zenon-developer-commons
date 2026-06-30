# Project Zeno: Economic Security Framework

**Document status:** Frontier research. Non-normative.
**Version:** 0.1.0
**Governing documents (in priority order):**

1. `SPEC.md` v1.3.0 (the controlling authority for all on-chain rules)
2. `BRIDGE-FRAMEWORK-SPEC.md` v0.2.0 (the Bridge Framework normative specification)
3. `EXECUTION-PROVIDER-FRAMEWORK.md` v0.1.0 (the Execution Provider architecture)
4. `INTENT-ORDERFLOW-FRAMEWORK.md` v0.1.0 (the Intent and Orderflow architecture)

This document is Frontier research. It does not make implementation claims, introduce new protocol features, propose token economics, or bind any deployment. Every speculative mechanism is explicitly marked. Where this document references a mechanism defined in a governing document, the governing document controls.

**Purpose:** This document is the constitutional reference for the economic security of the Project Zeno interoperability stack. Every future Frontier document should reference this framework rather than redefining trust assumptions, bond models, incentive structures, or participant alignment from scratch.

**Boundary discipline:** This document does not extend Settlement, Execution, or the Intent layer. It describes the economic forces that make each layer's participants behave honestly. It answers "why does this work?" not "how does this work?" The "how" is in the governing documents.

**Commit discipline:** Settlement never prices risk, manages incentives, or chooses counterparties. If any mechanism described here would require Settlement to make an economic decision, the mechanism is wrong. Economic security exists outside Settlement, operates on Settlement's output, and never reaches back in.

---

## 1. Why this document exists

### 1.1 The remaining question

The Bridge Framework explains how cryptographic truth is produced (verification, settlement, authorization). The Execution Provider Framework explains how that truth is fulfilled (execution providers, liquidity, pricing). The Intent Framework explains how users express desired outcomes (intents, quotes, selection). None of these documents answers the question that underlies all of them:

**Why does every participant remain economically aligned?**

A relayer is permissionless. Why does it relay honestly? A solver fronts capital. Why does it deliver? A market maker quotes a price. Why does it honor the quote? A custodian holds real assets. Why does it not steal them? An executor computes state transitions. Why does it compute correctly?

Some of these answers are cryptographic ("it cannot cheat because the math prevents it"). Some are economic ("it will not cheat because the cost exceeds the gain"). Some are legal ("it must not cheat because a regulator will punish it"). Some are reputational ("it should not cheat because it will lose future business"). This document classifies these answers, assigns them to participants, and explains how they compose.

### 1.2 What this document is not

This is not a tokenomics paper. It does not assign token values, emission schedules, staking yields, or governance weights. This is not a governance proposal. It does not specify who votes on what. This is not an implementation roadmap. It does not promise features or timelines.

This is an architectural framework. It describes the categories of trust, the mechanisms that produce honest behaviour, the participants that rely on each mechanism, and the boundaries between them. It is the reference that every future interoperability component should cite when explaining its security model.

---

## 2. Trust versus Incentives

### 2.1 Five categories of assurance

The interoperability stack relies on five distinct categories of assurance. They are not interchangeable. Each has different failure modes, different costs, and different coverage. Conflating them is the most common source of security analysis errors in bridge and interoperability design.

**Cryptographic correctness.** The mechanism cannot produce an incorrect result because the mathematics prevent it. No honest participant is required; the property holds even against a fully adversarial operator. Examples: a validity proof that `postStateRoot = F(preStateRoot, inputs, code_hash)`, a Merkle inclusion proof, a hash preimage lock, a digital signature. Cost: proving/verification computation. Failure mode: broken cryptographic assumption (hash collision, compromised curve). Coverage: the specific property the proof covers and nothing else.

**Economic correctness.** The mechanism is unlikely to produce an incorrect result because cheating is more expensive than behaving honestly. Requires at least one honest participant (or, more precisely, at least one *rational* participant whose cost of misbehaviour exceeds the gain). Examples: a bonded executor whose stake exceeds the maximum extractable value from a single batch, a challenge game where fraud is provable and slashable. Cost: locked capital (the bond). Failure mode: the bond is undersized relative to the attack profit, or the challenge game has a liveness failure (no challenger acts in time). Coverage: bounded by the bond size and the challenge-window liveness.

**Competitive correctness.** The mechanism is unlikely to produce a bad outcome for the user because multiple providers compete, and the user can switch. No individual provider needs to be honest; the market as a whole produces honest outcomes through selection pressure. Examples: solver competition for Intent fills, multiple market makers quoting the same authorization. Cost: market infrastructure (relays, quoting systems, discovery). Failure mode: monopoly, collusion, or information asymmetry that eliminates effective competition. Coverage: the user's ability to compare and switch.

**Legal/regulatory correctness.** The mechanism is unlikely to produce a dishonest outcome because a legal system will punish the dishonest party. Requires a jurisdiction, an identity, and enforcement capability. Examples: a regulated custodian, an institutional market maker under MiFID II, a licensed payment processor. Cost: compliance, licensing, audit. Failure mode: jurisdictional gaps, enforcement delays, regulatory capture. Coverage: the legal system's reach and willingness to act.

**Reputational correctness.** The mechanism is unlikely to produce a dishonest outcome because the party's future business depends on its reputation. Requires repeated interaction, observable performance, and a cost of exit. Examples: a solver with a public track record, a market maker with a brand, a wallet with user reviews. Cost: building and maintaining reputation. Failure mode: exit scams (the party decides the one-time gain exceeds all future reputation value), Sybil attacks (cheap new identities replace damaged ones). Coverage: the party's future expected revenue stream.

### 2.2 Why these must not be merged

Each category has a different trust root. Cryptographic correctness trusts math. Economic correctness trusts incentives. Competitive correctness trusts markets. Legal correctness trusts institutions. Reputational correctness trusts social consequences.

A security analysis that says "the executor is bonded, therefore the execution is correct" is wrong. The bond makes fraud *unprofitable*, not *impossible*. A security analysis that says "the solver has a good reputation, therefore the user is safe" is wrong. Reputation makes misbehaviour *costly in the long run*, not *costly in this transaction*. A security analysis that says "the custodian is regulated, therefore the funds are safe" is wrong. Regulation makes theft *punishable*, not *preventable*.

The correct analysis names the category, states the assumption, bounds the coverage, and identifies the failure mode. This document provides that analysis for every participant in the stack.

---

## 3. Trust Models

### 3.1 Architectural trust models

Each trust model below is a pattern that a specific participant or component may instantiate. A single participant may use multiple models simultaneously (a "hybrid" model). The models are listed from strongest (fewest assumptions) to weakest (most assumptions).

**Pure cryptography.** The property is proven mathematically. No trust in any participant. The strongest model, but the narrowest: it covers only what the proof covers. In the Project Zeno stack, this model secures: hash integrity (SHA3-256), signature validity, Merkle/SMT inclusion and absence, validity proofs under `ZK_VALIDITY`, and conservation invariant enforcement by Settlement Core.

**Bonded security.** A participant posts collateral exceeding the maximum profit from misbehaviour. Misbehaviour is detectable and results in slashing. The model is secure as long as: the bond exceeds the attack profit, the detection mechanism is live (at least one challenger within the window), and the slashing mechanism is sound. In the stack: executor bonds (`SPEC.md` §22), the `OPTIMISTIC` fraud-proof game (`BRIDGE-FRAMEWORK-SPEC.md` §6.3), and [SPECULATIVE] solver bonds.

**Economic incentives (unbonded).** A participant benefits more from honest behaviour than from dishonest behaviour, without explicit collateral. The incentive is future revenue, not locked capital. Weaker than bonded security because there is nothing to slash; the only penalty is lost future income. In the stack: relayers (permissionless, fee-earning; withholding loses fees but costs nothing), permissionless solvers competing on reputation.

**Competition.** Multiple providers serve the same function; the user (or an agent) selects the best. No individual provider needs to be trusted. The model fails only if all providers collude or if the user cannot meaningfully compare options. In the stack: solver competition for Intent fills, multiple market makers, DEX aggregation across venues.

**Insurance.** [SPECULATIVE] A third party underwrites the risk of a specific failure (provider default, smart-contract bug, oracle failure). The participant's honesty is not assumed; the insurer covers the loss. The model is as strong as the insurer's solvency and willingness to pay.

**Legal enforcement.** A jurisdiction, identity, and enforcement mechanism backstop the participant's behaviour. The model is as strong as the legal system's reach. In the stack: regulated custodians, institutional market makers, licensed payment processors.

**Reputation.** Observable history of past behaviour creates an expectation of future behaviour. The model is as strong as the cost of losing the reputation versus the gain from a single defection. In the stack: solver track records, wallet brand trust, market-maker relationships.

**Hybrid.** A combination of two or more models. Most real deployments are hybrid. An executor is bonded (economic) and monitored by watchers (competitive/cryptographic). A solver is bonded (economic), reputable (reputational), and competing (competitive). A custodian is regulated (legal), insured (insurance), and audited (reputational).

### 3.2 Where each model belongs

| Component | Primary trust model | Secondary | Why |
|---|---|---|---|
| Settlement Core | Pure cryptography | N/A | Node-binary logic, hash/signature verification, conservation enforcement |
| SMT state proofs | Pure cryptography | N/A | Inclusion/absence proofs are mathematical |
| `ZK_VALIDITY` batch proof | Pure cryptography | N/A | Proof soundness (assumed) |
| `ATTESTATION` executor | Bonded security | Reputation | Bond sizes the maximum loss; reputation + watcher monitoring |
| `OPTIMISTIC` executor | Bonded + cryptographic | Competition | Bond + fraud proof + watcher liveness |
| Relayer | Economic incentives | Competition | Fee-earning, permissionless, can only withhold |
| Watcher | Economic incentives | Competition | Bounty-earning (under `OPTIMISTIC`), permissionless |
| `ChainVerifier` (code) | Pure cryptography | N/A | Deterministic, pure function inside STF |
| `ReleaseAdapter` (code) | Pure cryptography | Legal (for upgrade governance) | Contract/graph logic; upgrade governance is legal/social |
| Native custody release | Pure cryptography | N/A | The adapter verifies the Zenon proof directly |
| Solver | Bonded + competitive | Reputation | Bond covers default; competition drives honest pricing |
| Market maker | Competitive + legal | Reputation, insurance | Regulated (often); reputation-driven; competition on spread |
| Liquidity provider | Economic incentives | Legal (if regulated pool) | Earns yield; does not interact with Settlement |
| Custodian | Legal + insurance | Reputation | Regulated entity; insured; brand trust |
| Intent relay | Competitive + reputation | N/A | Multiple relays; users switch if censored |
| Wallet | Reputation | Legal (if regulated) | User trusts the wallet's software and brand |

---

## 4. Participant Security Models

For every participant in the interoperability stack, this section answers: **what keeps them honest?**

### 4.1 User

**What keeps them honest?** Self-interest. The user is spending their own assets; misbehaviour (submitting an invalid input, double-spending) is prevented by L1 account-block uniqueness, signature verification, and Settlement contiguity checks. The user cannot forge an authorization, skip replay protection, or violate the conservation invariant.

**What can go wrong?** User error (sending to the wrong address, setting slippage too high, choosing a bad provider). User error is not a protocol failure; it is an interface problem, mitigated by wallet UX, not by Settlement.

### 4.2 Wallet / Intent Provider

**What keeps them honest?** Reputation and competition. A wallet that censors Intents, front-runs users, or selects bad providers loses users to competing wallets. Regulated wallets additionally face legal consequences.

**What can go wrong?** A compromised wallet can sign transactions the user did not authorize. This is a key-management problem, not a Settlement problem. A malicious wallet can route Intents to a preferred (kickback-paying) provider rather than the best one ("payment for order flow"). This is a market-structure problem mitigated by transparency, regulation, and user education.

### 4.3 Execution Provider (general)

**What keeps them honest?** Varies by type (see §4.4 through §4.8). The unifying property: an Execution Provider can never alter a Settlement authorization. It can only fill or not fill. Not filling costs the provider a business opportunity; it never costs the user their assets (the authorization remains available or the timeout/refund path activates).

### 4.4 Solver

**What keeps them honest?** [SPECULATIVE] A bonded solver posts collateral covering potential misbehaviour. If the solver accepts an Intent, fronts the delivery, and then fails to prove delivery for reimbursement, the solver loses its own capital (the fronted delivery) plus any bond slashing. Competition among solvers drives pricing toward fair value. Reputation (fill rate, latency, dispute history) determines future order flow.

**What can go wrong?** Solver insolvency (bond insufficient to cover losses from adverse price movement). Solver collusion (multiple solvers agree not to compete, raising prices). Solver MEV extraction (selectively filling profitable Intents). These are market failures, not Settlement failures.

### 4.5 Market Maker

**What keeps them honest?** Competition (multiple makers quote; the user picks the best), regulation (institutional makers operate under trading rules), reputation (a maker's brand is its primary asset), and optionally bonding (a maker may post collateral for binding quotes).

**What can go wrong?** Market maker withdrawal (all makers stop quoting during a crisis, leaving no liquidity). Adverse selection (makers widen spreads or stop quoting toxic flow). Quote manipulation (last-look, phantom liquidity). These are standard market-microstructure problems, not protocol problems.

### 4.6 Liquidity Provider

**What keeps them honest?** Self-interest (the LP earns yield on deployed capital). LPs do not interact with Settlement; they deposit capital into Execution Provider systems (pools, vaults, bilateral agreements). Settlement has no concept of LP capital.

**What can go wrong?** Impermanent loss, smart-contract risk in the pool, rug-pulls by pool operators, bank-run dynamics. These risks are borne by the LP and managed by the LP's own due diligence and the pool's security model.

### 4.7 Custodian

**What keeps them honest?** Legal enforcement (regulated entity, subject to audit and licensing), insurance (custodial insurance policies), reputation (brand trust built over years), and operational security (multi-sig, HSMs, cold storage).

**What can go wrong?** Insider theft, regulatory seizure, insolvency, operational failure (key loss). These are custodial risks, bounded by the custodian's legal and insurance coverage.

### 4.8 Relayer

**What keeps them honest?** The relayer does not need to be honest. It is permissionless and trustless: it can only withhold, never forge, because the STF and Settlement re-validate every datum it delivers (`SPEC.md` §12; `BRIDGE-FRAMEWORK-SPEC.md` §7.4). A dishonest relayer delays but cannot corrupt. Multiple relayers compete; withholding by one is defeated by open relay from another.

**What can go wrong?** All relayers simultaneously go offline (liveness failure, not safety failure). Censorship of specific inputs (mitigated by permissionless relay and force-inclusion).

### 4.9 Executor

**What keeps them honest?** A bonded executor (`SPEC.md` §22) risks its bond on every batch. Under `ATTESTATION`, the bond is at risk from process faults (equivocation, non-entitlement); under `OPTIMISTIC`, the bond is at risk from any provably incorrect state transition. Under `ZK_VALIDITY`, the executor cannot submit an incorrect batch at all (the proof is verified before acceptance).

**What can go wrong?** Under `ATTESTATION`, the executor can compute incorrectly without on-chain detection (Rail 1: "STF-verifiable does not mean Settlement-verified"). Under `OPTIMISTIC`, the watcher set may fail to challenge in time (DA withholding + all watchers offline). Under `ZK_VALIDITY`, nothing, assuming proof-system soundness. The execution profile ladder (`BRIDGE-FRAMEWORK-SPEC.md` §6.3) is precisely the path from "economic honesty" to "cryptographic honesty."

### 4.10 `ChainVerifier` and `ReleaseAdapter`

**What keeps them honest?** The `ChainVerifier` is pure, deterministic code inside the STF; its correctness is a code-audit and formal-verification problem, not an economic-security problem. The `ReleaseAdapter` is a foreign-chain contract/program whose correctness is a code-audit problem and whose upgrade governance is a legal/social problem. Neither is a participant with economic incentives; both are artifacts whose security is a function of their engineering quality.

### 4.11 Settlement Layer (itself)

**What keeps it honest?** Cryptographic correctness. Settlement Core is node-binary logic: conservation invariant enforcement, contiguity checks, replay protection, finality rules, and version gating. These are mathematical properties, not economic properties. Settlement does not need incentives to be honest; it is honest by construction, assuming the node-binary is correct and L1 consensus is sound.

---

## 5. Bond Models

### 5.1 Why bonds exist

A bond exists when cryptographic correctness is unavailable or too expensive, and the protocol needs a stronger guarantee than reputation or competition alone. The bond makes misbehaviour unprofitable by ensuring the attacker loses more (the slashed bond) than they gain (the attack profit).

The fundamental sizing rule: **the bond MUST exceed the maximum extractable value from a single misbehaviour window.** For an executor, this is `MaxBatchWithdrawal` (`SPEC.md` §22). For a solver, this is the maximum authorization the solver may claim. If the bond is undersized, the participant can profit from misbehaviour, and the economic security claim is void.

### 5.2 When bonds are unnecessary

**When cryptography replaces bonds.** Under `ZK_VALIDITY`, the executor's batch is proven correct before acceptance. No bond is needed for execution correctness (a bond may still exist for liveness or other operational commitments, but not for correctness). Under native custody release, the `ReleaseAdapter` verifies the Zenon proof directly; no bond is needed.

**When competition replaces bonds.** A permissionless relayer needs no bond because it cannot forge; competition among relayers provides liveness. A DEX needs no provider bond because the AMM contract is the counterparty, not a bonded individual.

**When regulation replaces bonds.** A regulated custodian's "bond" is its regulatory capital, insurance coverage, and legal liability. Requiring an additional protocol-level bond on top of regulatory requirements may be redundant and may even deter institutional participation.

**When reputation replaces bonds.** For low-value, high-frequency interactions (small Intent fills, micro-payments), a reputation score may provide sufficient assurance without the capital cost of a bond. The threshold below which reputation suffices and above which a bond is required is a deployment decision, not a protocol decision.

### 5.3 Bond asset options

The bond denomination is an architectural choice. This document does not mandate any specific asset.

| Asset class | Advantages | Risks |
|---|---|---|
| Native protocol token (ZNN/QSR) | Aligned incentives; slashable on L1 | Volatile; may lose coverage during a price drop |
| Bridged stablecoin | Stable coverage value | Introduces stablecoin dependency; depegging risk |
| Native destination-chain asset | Slashable on the chain where the user is harmed | Requires cross-chain bond management |
| ETH/BTC (large-cap) | Deep liquidity, widely held | Volatile (less than protocol tokens, more than stables) |
| Restaked asset | [SPECULATIVE] Capital-efficient (same capital secures multiple protocols) | Restaking introduces systemic correlation risk |
| Insurance policy | [SPECULATIVE] No capital lockup for the participant | Insurer solvency risk; claims adjudication delay |

### 5.4 What this document does not do

This document does not assign a bond denomination, a slashing rate, a staking period, a yield mechanism, or a minimum bond size. These are deployment parameters. The framework defines when bonds are architecturally appropriate and what properties they must satisfy; it does not fill in the numbers.

---

## 6. Reputation

### 6.1 What reputation covers

Reputation fills the gap between cryptographic guarantees (strong but narrow) and bonds (strong but capital-intensive). A participant with a strong reputation is unlikely to misbehave because the long-term cost of lost future business exceeds the short-term gain from a single defection. Reputation is the cheapest form of assurance and the most fragile.

### 6.2 Where reputation applies

| Participant | Reputation signal | Observable metric |
|---|---|---|
| Solver | Fill rate, latency, dispute rate | On-chain delivery proofs, Intent relay logs |
| Market maker | Spread quality, uptime, quote honoring | Quote/fill match rate, historical spreads |
| Wallet | User retention, security incidents | App-store reviews, security audits, incident history |
| Intent relay | Censorship resistance, fairness | Inclusion metrics, MEV extraction evidence |
| Execution Provider (general) | Reliability, cost, speed | Aggregated fill data across Intent relays |

### 6.3 Reputation is never protocol consensus

Reputation scores are application-layer signals, not Settlement state. Settlement does not store, compute, or verify reputation. A wallet may use a reputation feed to rank providers; an Intent relay may use reputation to filter solvers; a user may check a provider's history before accepting a Quote. None of this touches Settlement.

The reason is structural: reputation is subjective, gameable, and context-dependent. What counts as "good reputation" for a low-latency solver differs from what counts for a trust-minimized custodian. Embedding reputation in the protocol would require Settlement to make subjective judgments, violating the boundary discipline.

### 6.4 Sybil resistance

Reputation systems are vulnerable to Sybil attacks: a misbehaving participant creates a new identity and starts fresh. Defenses include:
- **Bonding as Sybil resistance.** Requiring a bond to participate makes new identities expensive. The bond is not primarily for slashing; it is for identity cost.
- **Proof-of-history.** A long track record is inherently Sybil-resistant because it cannot be fabricated. Wallets may require a minimum history before trusting a provider.
- **Social attestation.** Other reputable participants vouch for a new entrant. Useful for institutional onboarding; less useful for permissionless systems.

---

## 7. Competition

### 7.1 Why competition is a security mechanism

Competition is not just a market-efficiency property; it is a security property. When multiple providers serve the same function, no single provider can extract monopoly rents, censor users, or degrade service without losing business to competitors. The user's ability to switch is the enforcement mechanism.

### 7.2 What competition improves

**Pricing.** Multiple solvers quoting the same Intent drive fees toward the cost of capital and execution. A single provider would charge monopoly rents.

**Latency.** Solvers compete to fill first, investing in infrastructure (pre-positioned inventory, fast relays, optimized routing) that benefits users.

**Reliability.** If one provider fails, another fills. The system's liveness does not depend on any single provider.

**Capital efficiency.** Competition incentivizes providers to optimize inventory, reduce idle capital, and find cheaper liquidity sources.

**User experience.** Competition drives wallets and applications to build better interfaces, clearer fee disclosure, and more reliable execution.

### 7.3 Where competition operates

| Layer | Competitors | What they compete on |
|---|---|---|
| Execution | Solvers, market makers, custodians, DEXes | Price, speed, trust, reliability |
| Quoting | Multiple providers per Intent | Fee, exchange rate, latency, binding commitment |
| Routing | DEX aggregators, multi-hop optimizers | Total cost, path efficiency |
| Intent relay | Multiple relay services | Censorship resistance, fairness, latency |
| Wallet | Multiple wallet applications | UX, security, provider selection quality |

### 7.4 When competition fails

Competition fails under monopoly (one provider dominates), collusion (providers agree not to compete), or information asymmetry (the user cannot meaningfully compare options). These failures are market-structure problems. The protocol's defense is to keep participation permissionless (so new entrants can always challenge incumbents) and to keep the Intent format standardized (so switching costs are low).

---

## 8. Risk Allocation

### 8.1 Principle

Every risk has an owner. The owner is the party best positioned to manage the risk, not the party the protocol finds most convenient. Settlement is not a risk dump. It owns the risks it can cryptographically eliminate (replay, conservation, contiguity) and explicitly disclaims everything else.

### 8.2 Risk ownership table

| Risk | Owner | Why | Settlement involvement |
|---|---|---|---|
| **Price risk** | Execution Provider | The provider chooses when and at what price to fill | None. Settlement records amount, not price. |
| **Execution risk** | Execution Provider | The provider performs the delivery transaction | None. Settlement authorizes; it does not execute. |
| **Liquidity risk** | Execution Provider / LP | The provider sources capital; the LP provides it | None. Settlement has no concept of liquidity. |
| **Custody risk** | Custodian / `ReleaseAdapter` | The custodian or adapter holds real assets | Settlement bounds aggregate custody via conservation. |
| **Oracle risk** | Execution Provider / pricing layer | The provider consults oracles for conversion | None. Settlement does not embed oracles. |
| **Settlement risk** | Settlement (cryptographic) | Conservation, replay, contiguity, finality | Full ownership. This is Settlement's job. |
| **User error** | User / wallet | Wrong address, wrong amount, bad provider choice | None. Settlement processes valid inputs; it does not validate user intent. |
| **Counterparty risk** | User ↔ Execution Provider | The provider may not deliver; the user may not pay | None. Settlement guarantees the authorization, not the counterparty's performance. |
| **Regulatory risk** | Participant in the jurisdiction | Compliance, licensing, sanctions | None. Settlement is agnostic to jurisdiction. |
| **Smart-contract risk** | Deployer / auditor | Bugs in `ReleaseAdapter`, pool contracts, DEXes | Settlement bounds per-domain damage via isolation and conservation. |

### 8.3 Settlement's explicit disclaimers

Settlement does NOT guarantee:
- That an authorization will be filled.
- That the fill will happen at any particular price.
- That the fill will happen within any particular time.
- That the Execution Provider is solvent.
- That the liquidity exists to fulfill the authorization.
- That the user chose wisely.

These disclaimers are features, not gaps. Each disclaimed risk is owned by the party that can actually manage it. Assigning them to Settlement would not make the user safer; it would make Settlement less trustworthy, because Settlement would be making guarantees it cannot enforce.

---

## 9. Failure Economics

### 9.1 The isolation principle

When a participant fails, the damage is contained to the participant's own layer and, at most, to the specific domain the participant serves. A solver's insolvency does not drain Settlement's escrow. A market maker's withdrawal does not alter any finalized authorization. A liquidity pool's depletion does not violate the conservation invariant. Failures remain isolated because responsibilities remain isolated.

### 9.2 Failure scenarios

**Provider insolvency.** A solver or market maker runs out of capital. Impact: the provider stops filling Intents. Other providers fill instead. Users experience temporary delay, not loss. Settlement is unaffected.

**Liquidity collapse.** All liquidity on a destination chain dries up (market crash, bank run). Impact: no Execution Provider can source delivery capital. Authorizations remain finalized but unfilled. Users wait or invoke the timeout/refund path. Settlement is unaffected.

**Provider disappearance.** A provider goes offline permanently. Impact: Intents routed to that provider are unfilled. The wallet rebroadcasts to other providers. Bonded providers may have their bond slashed for non-performance (if a bond exists). Settlement is unaffected.

**Oracle failure.** A price oracle goes stale, is manipulated, or goes offline. Impact: Execution Providers that depend on that oracle cannot price conversions accurately. Providers switch to alternative oracles, widen spreads, or pause quoting. Settlement is unaffected (Settlement does not use oracles).

**DEX failure.** A DEX contract is exploited or drained. Impact: Execution Providers that route through that DEX lose the routed amount. Other DEXes and routing paths remain available. Settlement is unaffected.

**Market crash.** A broad market decline makes bonded assets worth less in real terms. Impact: bonds may become undersized relative to attack profit. This is a bond-denomination and collateralization-ratio problem, mitigated by overcollateralization, dynamic bond adjustments, or stable-denominated bonds (§5.3).

**Network congestion.** A destination chain's gas fees spike, making delivery expensive. Impact: Execution Providers pass the cost to users (higher fees) or delay until congestion clears. Authorizations remain valid. Settlement is unaffected.

**Execution delay.** A provider fills but the destination transaction takes longer than expected. Impact: the user waits. If the delay exceeds the Intent's timeout, the timeout/refund path activates. Settlement is unaffected.

### 9.3 The common pattern

In every scenario above, "Settlement is unaffected" is not a coincidence. It is the design. Settlement produces deterministic truth that does not depend on market conditions, provider solvency, or oracle liveness. The failures above are market failures, handled by market mechanisms (competition, bonding, insurance, refunds). Settlement's contribution to failure handling is: the authorization remains correct, final, and available for whoever is able to fill it.

---

## 10. Insurance

### 10.1 Architectural role

[SPECULATIVE] Insurance is a trust model (§3.1) that covers risks that cryptography, bonds, and competition cannot eliminate: smart-contract bugs, unprecedented market events, operational failures, and black-swan scenarios. Insurance does not prevent failures; it compensates for them.

### 10.2 Insurance models

**Self-insurance.** The Execution Provider retains a reserve fund to cover losses. Simple but capital-intensive and limited to the provider's own solvency.

**Third-party insurance.** An insurance protocol or traditional insurer underwrites specific risks (smart-contract exploit coverage, slashing coverage, custody loss). The insurer assesses risk, sets premiums, and pays claims. The insurer's solvency and claims process are the trust dependencies.

**Insurance pools.** [SPECULATIVE] A shared pool funded by multiple participants (providers, LPs, users) covers losses across the pool. Socializes risk but introduces pool-governance and underfunding risks.

**Coverage markets.** [SPECULATIVE] A market where participants buy and sell coverage for specific risks (a CDS-like market for smart-contract exploits, oracle failures, or provider defaults). Price discovery for risk.

**Restaking as insurance.** [SPECULATIVE] Restaked assets (capital staked in one protocol and re-committed to secure another) can serve as insurance collateral. Capital-efficient but introduces systemic correlation: a failure in one protocol may trigger slashing across all protocols the restaker secures.

### 10.3 Insurance boundaries

Insurance is entirely external to Settlement. Settlement does not hold insurance reserves, pay premiums, adjudicate claims, or assess risk. An insurer may cover losses from an Execution Provider's failure, a `ReleaseAdapter` exploit, or a liquidity-pool drain, but the coverage is a bilateral contract between the insurer and the insured party. Settlement's contribution is that its deterministic, auditable authorization trail makes claims adjudication easier: "the authorization was correct; the failure was in execution" can be proven from on-chain data.

---

## 11. Regulatory Models

### 11.1 Settlement supports all models

Settlement is agnostic to the regulatory environment of its participants. It does not require KYC, AML, sanctions screening, or licensing. It also does not prohibit them. The regulatory model is a deployment parameter, not a protocol parameter.

### 11.2 Regulatory configurations

**Fully permissionless.** No identity requirements. Any participant may relay, execute, provide liquidity, or create Intents. Regulatory compliance is the participant's own responsibility. This is the default configuration for public deployments.

**Permissioned execution.** The `ReleaseAdapter` or a solver registry restricts Execution Providers to a known, vetted set. Settlement remains permissionless; only the execution layer is gated. Useful for high-value bridges or regulated-asset bridges.

**Institutional.** Execution Providers are regulated entities (banks, broker-dealers, custodians). KYC/AML is performed at the Intent layer (the wallet or application checks the user's identity before creating the Intent). Settlement sees only valid, signed inputs; it does not know or care whether the user passed KYC.

**Enterprise.** A private deployment where all participants are known, contracted, and legally bound. Settlement is the same protocol; the permissioning layer sits above it.

### 11.3 Why Settlement does not enforce compliance

Settlement is a deterministic state machine. It processes valid inputs and produces correct outputs. It does not make judgments about the identity, jurisdiction, or compliance status of the input creator. Embedding compliance in Settlement would:
- Require Settlement to maintain identity registries (a single point of failure and a privacy risk).
- Make Settlement jurisdiction-specific (incompatible with global, permissionless deployment).
- Create a censorship vector (a compromised compliance module could block valid inputs).

Instead, compliance is enforced at the application layer (wallets, Intent providers, Execution Provider registries) where it can be tailored to the deployment's jurisdictional requirements without affecting the protocol's universality.

---

## 12. Incentive Alignment

### 12.1 Why everyone benefits without Settlement coordinating them

Settlement does not coordinate incentives. It produces a deterministic authorization. Every other participant aligns around that authorization because it is in their self-interest to do so:

**Users** benefit because the authorization is correct, final, and unforgeable. They can trust it without trusting any Execution Provider, and they can switch providers if one underperforms.

**Execution Providers** benefit because the authorization is deterministic and public. They can verify it independently, price it accurately, and fill it profitably. They do not need to trust the user, the relayer, or any other provider.

**Liquidity Providers** benefit because the Execution Providers they supply capital to can verify authorizations, reducing counterparty risk. LPs earn yield on deployed capital without interacting with Settlement.

**Market Makers** benefit because the authorization trail is auditable and the conservation invariant bounds aggregate risk. They can quote with confidence that the authorization will not be double-spent.

**Custodians** benefit because Settlement's conservation invariant bounds the maximum outflow. A custodian holding assets for a bridge domain knows the protocol cannot authorize releases exceeding deposits.

**Builders** (wallet developers, SDK authors, application teams) benefit because the Intent format is standardized and the execution layer is competitive. They can integrate once and access multiple providers.

### 12.2 The self-reinforcing loop

Competition among Execution Providers drives down fees and drives up reliability. Lower fees and higher reliability attract more users. More users attract more providers. More providers intensify competition. The loop is self-reinforcing and does not require protocol-level subsidies, token incentives, or governance coordination. Settlement's contribution is to produce the truthful, deterministic authorization that every participant in the loop depends on.

---

## 13. Economic Profiles

An **Economic Profile** describes the combination of trust models that secure a specific deployment or configuration. Different deployments may select different profiles based on their users, regulatory environment, and risk tolerance.

### 13.1 Example profiles

| Profile | Primary trust models | Bond required? | Regulation? | Typical use case |
|---|---|---|---|---|
| **Pure cryptographic** | Cryptography (ZK proofs, native custody) | No | No | `ZK_VALIDITY` + native custody release; highest assurance, highest latency/cost |
| **Bonded** | Bonded security + competition | Yes | No | `OPTIMISTIC` + bonded solvers; trust-minimized with economic guarantees |
| **Market-driven** | Competition + reputation | Optional | No | Permissionless solver competition; lowest fees, reputation-gated |
| **Institutional** | Legal + insurance + reputation | Regulatory capital | Yes | Regulated custodians, institutional market makers; highest compliance |
| **Hybrid** | Cryptography + bonded + competitive | Yes | Optional | `OPTIMISTIC` + bonded solvers + competing market makers; the general-purpose configuration |
| **Fully permissionless** | Competition + economic incentives | No | No | Anyone can relay, solve, provide; lowest barrier, highest variance |
| **Enterprise** | Legal + contractual | Contractual | Yes | Private deployment; all participants known and contracted |

### 13.2 Profile selection

The profile is a deployment decision, not a protocol decision. A BTC bridge targeting DeFi-native users may choose "Bonded" or "Hybrid." A stablecoin bridge targeting institutional users may choose "Institutional." A payment rail targeting merchants may choose "Enterprise." Settlement is the same in all cases; only the execution and economic layers differ.

---

## 14. Relationship to Settlement

### 14.1 What Settlement guarantees

Settlement guarantees five properties, all cryptographic:

- **Truth.** The authorization was produced by a valid STF execution over canonical inputs.
- **Finality.** The authorization will not be reverted (absent L1 consensus failure).
- **Replay protection.** Each `outboxId` is consumed at most once.
- **Conservation.** Authorized outflow never exceeds accounted inflow per (domain, asset).
- **Determinism.** The authorization is a pure function of L1-anchored data.

### 14.2 What Settlement never guarantees

Settlement never guarantees:

- **Profitability.** Whether filling the authorization is profitable for any Execution Provider.
- **Liquidity.** Whether the capital to fill the authorization exists anywhere.
- **Price.** What the authorized asset is worth in terms of any other asset.
- **Counterparty honesty.** Whether the Execution Provider will deliver.
- **Market conditions.** Whether the market is stable, liquid, or functioning.

These are economic properties, owned by the economic layer (this document), not by Settlement.

### 14.3 The boundary

Settlement's boundary is the boundary between cryptographic truth and economic reality. Inside the boundary, everything is deterministic, provable, and final. Outside the boundary, everything is probabilistic, competitive, and market-driven. This document describes the economic layer outside the boundary. The governing documents describe the cryptographic layer inside it. The boundary is not blurry; it is the cleanest separation in the architecture.

---

## 15. Relationship to Execution

### 15.1 What Execution consumes

Execution consumes four inputs, one from Settlement and three from the economic layer:

**Truth (from Settlement).** The finalized, deterministic authorization. This is the Execution Provider's operating license: "Settlement says this release is authorized."

**Economic incentives (from this framework).** The bond, the reputation, the regulatory license, or the competitive pressure that makes the provider behave honestly.

**Competition (from the market).** The presence of other providers that prevents any single provider from extracting monopoly rents or degrading service.

**Capital (from Liquidity).** The actual asset the provider delivers to the user. Sourced from inventory, pools, OTC, or other bridges.

### 15.2 How they combine

Truth without incentives produces correct authorizations that nobody fills (no motivation). Incentives without truth produces motivated providers that cannot verify what they are filling (unsafe). Competition without capital produces many willing providers with nothing to deliver (empty). Capital without competition produces a monopoly (overpriced).

All four must be present. Settlement provides the first. This framework provides the second. The market provides the third and fourth. The complete stack is: deterministic truth, economic alignment, competitive pressure, and available capital, composed but never merged.

---

## 16. Future Research

The following topics are identified as potential future work. They are explicitly speculative and do not commit any implementation or roadmap.

**Shared collateral.** [SPECULATIVE] Multiple providers share a collateral pool, reducing individual capital requirements. Introduces correlation risk (one provider's failure may trigger pool-wide slashing).

**Cross-domain bonds.** [SPECULATIVE] A bond posted on one domain secures obligations across multiple domains. Capital-efficient but requires cross-domain slashing coordination.

**Restaking.** [SPECULATIVE] Assets staked in Zenon (or another protocol) are re-committed to secure execution-layer obligations. Capital-efficient but introduces systemic risk.

**Insurance markets.** [SPECULATIVE] A market for risk coverage: participants buy and sell protection against specific failures (smart-contract exploit, oracle failure, provider default).

**Capital efficiency.** Techniques to reduce the idle capital required by Execution Providers and LPs: just-in-time liquidity, predictive inventory, netting, and batch execution.

**Liquidity insurance.** [SPECULATIVE] Insurance against liquidity withdrawal: an LP commits to maintaining a minimum position for a defined period, earning a premium.

**Decentralized underwriting.** [SPECULATIVE] A protocol for decentralized risk assessment and coverage issuance, replacing centralized insurers.

**Reputation markets.** [SPECULATIVE] Tradeable reputation tokens: a provider's reputation score is an on-chain asset that can be staked, delegated, or traded. Creates a market price for trustworthiness.

**Execution credit.** [SPECULATIVE] A provider with sufficient reputation or collateral may execute against credit rather than pre-funded capital, improving capital efficiency at the cost of credit risk.

**Credit delegation.** [SPECULATIVE] A capital provider delegates its capital to a solver/provider, earning yield while the solver uses the capital to fill Intents. The capital provider bears the solver's performance risk.

---

## 17. Closing

This document has described the economic security architecture of the Project Zeno interoperability stack. It has classified the five categories of assurance (cryptographic, economic, competitive, legal, reputational), assigned them to every participant, defined when bonds are necessary and when they are not, and shown how failures remain isolated across layers.

The four Frontier documents now form a complete architecture:

```
INTENT-ORDERFLOW-FRAMEWORK      ← Users express outcomes
    ↓
BRIDGE-FRAMEWORK-SPEC           ← Settlement produces truth
    ↓
EXECUTION-PROVIDER-FRAMEWORK    ← Providers compete to fulfill truth
    ↓
ECONOMIC-SECURITY-FRAMEWORK     ← Economic forces secure every participant
```

Each document has one job. Each layer has one boundary. No layer does another layer's work.

The closing principle:

> **Settlement secures truth. Markets secure execution. Economic incentives secure participants. The protocol provides certainty. The market provides capital. Participants provide execution. Each layer remains independent.**

This is the economic constitution of the interoperability stack. Every future Frontier document should reference this framework rather than re-deriving these principles from scratch.

---

**Document end.**

This document is Frontier research. It does not commit to any implementation, any token model, or any specific bond, insurance, or reputation mechanism. It defines the categories of economic assurance, the participants they secure, and the boundaries between them. The controlling authority for all on-chain rules remains `SPEC.md` v1.3.0. Where this document speculates, it says so.
