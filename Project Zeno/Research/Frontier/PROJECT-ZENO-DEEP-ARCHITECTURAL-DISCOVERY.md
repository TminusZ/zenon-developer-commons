# Project Zeno: Deep Architectural Discovery Report

**Document status:** Discovery analysis. Non-normative. Deliberately non-conservative.
**Method:** Every claim below is derived by following specified mechanisms (`SPEC.md` v1.3.0, `EXECUTOR.md` v0.2.0, `BRIDGE-FRAMEWORK-SPEC.md` v0.2.0, the Frontier and Interoperability series) to conclusions the documents themselves do not state. This report intentionally crosses the line the Frontier discipline draws: it explores what the architecture makes inevitable, not what is shipped.
**Epistemic tags:**

- **[STRUCTURAL]** follows necessarily from mechanisms already specified; no new machinery required, only activation.
- **[EMERGENT]** arises from the interaction of two or more specified mechanisms; the parts are specified, the whole is not stated anywhere.
- **[SPECULATIVE]** plausible extrapolation; requires unspecified machinery, unproven assumptions, or both.
- **[RISK]** a consequence that could damage or invalidate the vision.

Nothing here is a shipping claim. Phase 1 is bonded attestation, not trustless execution. `SPEC.md` governs on any conflict. The point of this document is the opposite of the repo's usual discipline: it is a map of where the logic goes if nothing stops it.

---

## 1. Hidden Architectural Consequences

### 1.1 Settlement is a narrow waist, and narrow waists eat ecosystems [STRUCTURAL]

The Internet's hourglass has one lesson: the layer that wins permanence is the one that does the least. IP survived because it was too simple to be worth replacing, and everything above and below it churned instead. Settlement is engineered into exactly that position. It stores roots and bounded metadata only (§3), never interprets contract code, never verifies execution in Phase 1, and the Service Domain Framework's commit discipline forbids it from ever absorbing new logic. The consequence is not stated anywhere: **Settlement's refusal to grow is its adoption strategy.** Every capability pressure (oracles, identity, storage, AI, bridges) is deflected horizontally into domains, which means the kernel accretes an ecosystem instead of accreting code. Monolithic L1s compete on features; a narrow waist competes on being unarguable. The architecture makes this inevitable because the only extension mechanism that exists is `RegisterDomain` plus a handler; there is no other place for a feature to land.

The historical kin, ranked by structural similarity: (1) Certificate Transparency, because batch commitments are signed tree heads, watchers are monitors, force inclusion is log submission, and the split-view problem CT gossip exists to solve is closed here by construction since commitments anchor into momenta; (2) the microkernel, because domains are userspace processes, the outbox is IPC, and cross-domain calls are message-passing only (§17.1); (3) IP itself; (4) the clearing house (DTCC), because conservation plus caps plus bonds is netting plus margin plus member collateral; (5) the JVM, because a consensus-pinned deterministic runtime is write-once-verify-anywhere. The closest single ancestor is CT, not Ethereum. Project Zeno is Certificate Transparency for computation with custody attached.

### 1.2 The DA bundle is an execution capsule, and the capsule is the real product [EMERGENT]

`SPEC.md` §20 defines the bundle as `BundleInputRecord` sequences: input data, every witnessed read including absent observations, and the per-input `ExecutionResult`, content-addressed by `DAHash`, with exactly one valid encoding. Combine this with the three-import ABI (§8), which makes execution a pure function from witnessed reads plus input to an effects blob. The unstated consequence: **each input's execution is a self-contained, portable, replayable object.** No live chain access, no node, no RPC endpoint is required to re-execute or verify a transition; the capsule carries its entire causal context. Execution stops being a service you request from infrastructure and becomes an artifact you download.

This inverts the topology of verification. Today verification requires connectivity to live infrastructure. Here verification requires only content-addressed static data plus a deterministic runtime that already targets browsers. Static data is what CDNs, torrents, IPFS, mirrors, and caches are good at. Truth becomes cacheable. The read path of the entire system can be served like a website.

### 1.3 The system has one clock, and the clock is an asset [EMERGENT]

`globalInputIndex` (§4.5) is a single, monotone, never-reset, deterministically reconstructible ordinal over every input to every domain, anchored to momentum heights, with a non-decreasing coarse timestamp attached (§9). Nothing in the spec calls this what it is: **a shared logical clock for an arbitrary number of execution environments.** Every cross-domain protocol gets happened-before for free; every dispute reduces to a single index; every audit has a total order to replay against. Distributed systems spend enormous effort approximating this property (vector clocks, hybrid logical clocks, TrueTime). Here it is a side effect of the ordering rule.

The second-order consequence: settlement time can be consumed by systems that have nothing to do with Zenon. Anyone who can read L1 can timestamp against the input sequence with the same finality guarantees the domains get. A notarization industry falls out of the ordering rule without a single line of new protocol.

### 1.4 Assets never move; authority moves [EMERGENT]

The ETH Authorization Domain's poolless lockbox states the pattern for one chain: ETH stays in an Ethereum contract, Zeno verifies deposits, accounts claims, and exports a finalized withdrawal authorization the lockbox honors. The BTC study points the same way. Generalize it and a law appears that the documents circle but never state: **interoperability in this architecture is authority routing, not asset transport.** Bridges historically moved value because nobody could move verifiable authority; wrapped assets were a workaround for the non-exportability of "this chain finalized this decision." The finalized `outboxRoot` plus an inclusion proof is exportable authority. Once authority is exportable, moving the asset is unnecessary; the asset waits at home under whatever custody mechanism its chain supports, and only decisions travel.

This is why the Authorization Domain naming discipline is more than caution. It is the correct primitive. The consequence for the industry is in §3.1 below. The consequence for the architecture is that Settlement's export format, the finalized authorization, becomes the unit every external system integrates against, the way HTTP responses became the unit web systems integrate against.

### 1.5 The upgrade rule is a constitutional right of exit [STRUCTURAL]

`MinRuntimeUpgradeDelay >= WithdrawalDelay` (§6) is stated as a Core hard bound and framed as user protection. Its political meaning is larger: **no rule change can bind a user faster than that user can leave, and even a fully compromised administrator cannot change this** (§23). This is Hirschman's exit guarantee implemented in consensus. Systems with guaranteed cheap exit need much less voice; governance minimization here is structural, not cultural. Domains therefore compete for residents under conditions of free emigration, which is the precondition for jurisdictional competition (§4.6). No blockchain governance literature I am aware of treats "exit latency floor as a constitutional invariant" as a first-class design primitive. This one does, quietly, in one inequality.

### 1.6 Pace layering is implemented in consensus [EMERGENT]

Stewart Brand's shearing layers and Herbert Simon's near-decomposability both observe that durable complex systems separate slow layers from fast ones. This architecture implements the separation mechanically: Settlement Core changes only by release plus spork; Periphery changes under time locks within Core bounds; domain STFs change under the upgrade delay; contract code changes at application speed; markets and intents change continuously and live entirely outside (Market Framework §2.2). Each layer's change cadence is enforced by a different mechanism, and faster layers cannot reach back into slower ones (the Economic Security Framework's commit discipline: economic machinery "never reaches back in"). Longevity in such systems comes from the slow layer being boring. The spec's refusal to make Settlement interesting is the longevity mechanism.

### 1.7 The mempool disappears; the sequencer-as-a-business disappears [STRUCTURAL]

There is no L2 mempool. The queue is the set of account-blocks sent to Settlement, ordered by a rule the executor merely reproduces (§4.4, §4.7). There is no sequencing authority to sell, no block builder to bribe, no private orderflow lane to construct at the execution layer. Force inclusion is not a fallback path bolted on for emergencies; it is the only path (§4.2). Entire product categories that exist in the rollup world (shared sequencers, sequencer marketplaces, builder markets at the L2 layer) have no attachment surface here. What remains is L1 inclusion itself, which is where the residual pressure migrates (§6.5, §13.2).

---

## 2. Emergent Properties

### 2.1 Private interiors with public solvency [EMERGENT, partially SPECULATIVE]

Settlement is balance-blind (§18.1a): it enforces `totalReleased + pendingWithdrawalReserve <= totalDeposited` per (domain, asset) without any knowledge of per-account state. The conservation counters update only at the custody boundary (deposits on L1 receive, releases through `RelayMessage`), both of which are L1-visible regardless of what the domain's internal state looks like. The unstated consequence: **a domain whose internal state is entirely opaque, encrypted, or committed-only still cannot violate aggregate solvency.** The kernel's safety floor does not depend on interior legibility.

That yields a combination the industry treats as a trade-off: privacy inside, provable solvency outside. The boundary stays transparent (withdrawal outbox messages carry recipient, asset, amount by format, §17.2), so this is interior privacy with a public flow ledger, not full-system privacy. The hard part is a deterministic STF over confidential state, which realistically means ZK machinery and lands on the Phase 3 ladder. Marked speculative for that reason. But the settlement floor's indifference to interior representation is structural today, and it means privacy domains do not need a different settlement layer. Exchanges spent years failing to deliver proof-of-reserves with account privacy. Here the shape falls out of balance-blindness.

### 2.2 The trust term structure: doubt acquires an interest rate [EMERGENT]

Three specified mechanisms interact: the withdrawal delay (§21), the solver pattern (Execution Provider Framework §4.5; ETH domain §8), and the execution profile ladder under which the delay shrinks from full delay to challenge window to proof latency (Bridge Framework §6.6). A solver who fronts assets against a finalized-but-delayed authorization is lending across the residual-trust window and pricing every risk inside it: executor honesty, DA availability, profile strength, bond adequacy, cap headroom. The spread solvers charge is therefore **a market-discovered price of residual trust, per domain, per duration.** Plot it across domains and delay lengths and a yield curve appears whose underlying is doubt.

Nobody designed this instrument. It emerges because the architecture standardizes exactly the variables a lender needs (delay length, bond size, cap, profile) as on-chain data, and standardized risk parameters are what make credit markets form. The consequences compound: the curve becomes a live oracle of perceived executor risk (a domain whose spread widens is being downgraded by the market in real time); migrations up the profile ladder become measurable in basis points; and "how much safer is OPTIMISTIC than ATTESTATION" stops being a debate and becomes a printed number. Section 5.2 develops the economics.

### 2.3 Closed-form maximum loss, including under total governance compromise [STRUCTURAL]

Combine the Core hard bounds (§23): the administrator cannot alter finalized roots, cannot bypass the withdrawal delay, cannot exceed cap ceilings, cannot shorten the upgrade delay below the withdrawal delay, and the bond is sized against the Core ceiling of `MaxBatchWithdrawal`, not the configured value (§22). The result is a property that is close to unheard of in this industry: **the worst-case loss of a domain under any adversary, up to and including a fully compromised administrator key, is a closed-form function of on-chain parameters:** roughly caps per window times windows inside the exit delay, bounded again by conservation to at most the domain's deposits, offset by the bond. No diligence on the operator, no code audit of the application, no social trust enters the bound.

Risk that is legible in closed form is risk that can be underwritten mechanically (§5.3). Risk that is bounded even under governance compromise changes what "key risk" means for integrators: the question stops being "can the admin rug" and becomes "what is the ceiling, and is it priced."

### 2.4 Completeness is enforced on-chain, not just validity [EMERGENT]

Almost every verification system checks validity: what was included is correct. Censorship, the omission of what should have been included, is usually unprovable or handled socially. Here the per-domain input-sequence contiguity check (§4.6) makes **omission a consensus-detectable fault**: a batch that skips a canonical input fails a cursor comparison at `SubmitBatch` and is rejected. Force inclusion is not a separate mechanism; it is the same check. And §6.1 extends the identical machinery to external inputs: for `EXTERNAL_OBSERVED` domains the completeness requirement ("no canonical external item omitted") rides on the same contiguity rail.

The emergent property: **censorship resistance is implemented as an arithmetic check rather than as a game.** This is a genuinely uncommon primitive. Oracle manipulation by omission (report the prices you like, skip the ones you do not) becomes a contiguity violation once the domain's finality predicate pins what "canonical" means. The remaining censorship surface is L1 inclusion itself, correctly scoped out (§4.2).

### 2.5 Auditing at O(replica), disputes at O(1) [EMERGENT]

The watcher role runs the identical pipeline as the executor and compares roots (EXECUTOR §11); the capsule makes every input independently replayable; contiguity pins every dispute to a single index whose `preStateRoot` is the previous index's `postStateRoot` (§4.6). Together: total, continuous, byte-exact audit costs one replica, and any disagreement compresses to one input's transition. Traditional assurance samples because full re-performance is impossible; here full re-performance is the cheap default and sampling is obsolete. Phase 1 lacks the on-chain channel to act on divergence (alarm-only, EXECUTOR §5.8), so the property matures with Phase 2, but the cost structure exists now. Security expenditure decouples from value secured: what scales with TVL is the bond and the caps, which are chosen numbers, not an emergent security budget that must be paid for in perpetuity (contrast PoS, where security spend is structurally proportional to value). Security becomes an engineering allocation instead of a thermoeconomic tax.

### 2.6 At-most-once, finality-gated messaging is the whole distributed-systems wishlist [STRUCTURAL]

`outboxId` uniqueness plus the `processedOutbox` set plus finalization gating plus permissionless relay (§17.3) gives cross-boundary effects that are: exactly-once in effect (at-most-once delivery with idempotence enforced by consensus), causally ordered per source, replay-protected globally, and deliverable by anyone. Application developers inherit, from the kernel, the properties that distributed-systems teams spend careers approximating with sagas and outbox tables (the pattern is literally named "outbox" in that literature; here it is consensus-enforced). The consequence: cross-domain protocol correctness becomes model-checkable over a small message algebra (§8.4), and a large class of bridge bugs (replay, double-delivery, ordering confusion) is excluded by construction rather than by review.

### 2.7 MEV is not destroyed; it is conserved and relocated [EMERGENT] [RISK]

The spec removes executor sequencing authority completely (§4.7) and scopes what remains honestly (§26). Following the flows: extraction pressure migrates to the two layers that still make choices. Below: L1 inclusion timing (which momentum an account-block lands in), a pillar-adjacent surface. Above: any actor who batches user intent before it reaches L1 (solvers, aggregators, wallets) chooses composition and timing for the users it serves, becoming a soft sequencer for its own orderflow. The Intent Framework's competitive-solver design is the correct countermeasure, but the conservation law should be stated plainly: **an architecture cannot delete discretion; it can only push discretion to layers where competition, transparency, or physics discipline it.** This design pushes it to exactly those layers. Section 6.4 adds a third, subtler surface inside the ordering rule itself.

---

## 3. Industry Disruptions

For each: what changes, why this architecture specifically causes it, what disappears, what replaces it.

### 3.1 The bridge industry unbundles into five commodity layers [STRUCTURAL]

The Interop decomposition (Verification, Accounting, Messaging, Custody, Enforcement) is presented as analytical discipline. It is also an industrial prophecy. Today a "bridge" is a vertically integrated firm that bundles all five layers and prices the bundle. The moment the middle three layers (verification via `ChainVerifier` profiles, accounting via wrapped-claim modules, messaging via finalized outbox proofs) are kernel-standardized, the bundle loses pricing power: the middle commoditizes, and what remains scarce is the two ends, custody mechanisms on external chains (lockboxes, threshold schemes, BitVM-style enforcement) and fulfillment capital (solvers). Prediction: bridge companies bifurcate into custody networks and solver networks, and "bridge" as a product noun goes the way of "portal site." What disappears: the integrated bridge with its own validator set as the default trust product. What replaces it: authorization routing over standardized proofs, plus competitive custody and competitive fulfillment. The reason it is this architecture that does it: it is the first design that makes exported authority (finalized outbox inclusion under a profile-laddered root) a standard artifact rather than a per-bridge invention.

### 3.2 RPC and node infrastructure splits into capsule CDNs and plasma ISPs [EMERGENT]

Reads: capsules plus browser verification dissolve the read-path chokepoint. Serving truth becomes serving content-addressed static data, a commodity CDN problem (§1.2). Writes: users still need L1 admission, which is plasma, which is fused QSR or PoW (§10.1). The infrastructure business that survives is provisioning admission capacity: leasing fused plasma, sponsoring PoW, managing rate limits. That is an ISP business model (capacity leases, flat rates) rather than a toll business model (per-request fees). Infura-shaped firms do not die; they become bandwidth carriers and cache operators. What disappears: the trusted read endpoint as a systemic dependency. What replaces it: verify-locally-by-default clients fed by dumb caches.

### 3.3 Oracles split into couriers and testimony [STRUCTURAL]

The proof-shaped versus observed distinction (Frontier README) is a cleaver through the oracle industry. Anything machine-verifiable at the source (headers, inclusion proofs, signed checkpoints) makes the relayer a permissionless courier with no trust premium; the STF checks the goods (§6.1). What cannot be verified, only attested (prices, weather, events), remains genuinely scarce, and its value concentrates in accountability: bonds, disclosed committee predicates (Bridge Framework §6.5 forbids "the executor says so" observation domains), replayable commitment of exactly what was claimed and when. The aggregation-network premium collapses; the liability premium survives. Oracles stop selling data and start selling bonded, evidentiary testimony (§7.2).

### 3.4 Clearing, escrow, and payment assurance [EMERGENT]

Conservation plus withdrawal delay plus per-batch caps plus the pause scopes (§23, §27.10) is a programmable clearing house: net settlement with member collateral (bonds), position limits (caps), a dispute window (the delay is functionally a chargeback window), and a circuit breaker that by default halts intake without freezing matured obligations (PAUSE_SUBMIT versus PAUSE_RELAY). Card networks sell exactly this bundle of guarantees at 200 basis points. What disappears: the assumption that payment assurance requires a network operator as counterparty. What replaces it: assurance as kernel parameters, with the interchange margin collapsing into solver spreads (§2.2).

### 3.5 The audit and compliance industry meets total replay [EMERGENT]

Section 2.5's cost structure lands on a profession built around sampling under re-performance impossibility. When re-performance is a download plus a deterministic run, the audit product inverts: continuous, total, byte-exact, with disagreements localized to single inputs. Big-4-shaped work migrates from "sample and opine" to "operate watchers and sign attestations." What disappears: materiality thresholds as a coping mechanism for cost. What replaces it: divergence feeds and attestation logs as subscription products (§12.3).

### 3.6 Cloud, but with slashing instead of SLAs [SPECULATIVE]

The executor market is spot compute with collateralized correctness: bonds are SLAs with automatic penalties (Phase 2), `stfSpecHash` pins the exact image (a consensus-enforced container digest), the unikernel profile points at attestable minimal images, and heterogeneous domains create hardware-specialized niches (a GPU-inference STF, an SGX domain, a plain-CPU WASM domain) without consensus caring. The registry becomes a process table; registration becomes deployment. What could disappear, far out: procurement-by-contract for correctness-critical compute. What replaces it: procurement-by-bond. Marked speculative because pricing, the deliberately absent piece, must come from the market layer, and Phase 1 has exactly one executor.

### 3.7 Timestamping, notarization, and transparency services [STRUCTURAL]

Section 1.3's clock plus §1.1's CT-kinship means RFC 3161 timestamp authorities, notarization startups, and bespoke transparency logs (binary transparency, key transparency) can all be re-expressed as thin domains or even as plain L1 inputs. The differentiated product shrinks to legal recognition, not cryptography.

---

## 4. Unknown Unknowns

Consequences visible only from outside blockchain thinking.

### 4.1 Coase decides the size of a domain [EMERGENT]

Asynchronous-only cross-domain interaction (§17.1) is a hard transaction cost between domains; intra-domain composition is cheap and synchronous-ish at the application layer. Coase's theory of the firm says organizational boundaries form where internal coordination cost crosses market transaction cost. Substitute: **domains will agglomerate until the pain of internal complexity exceeds the pain of outbox latency, and no further.** This predicts, from first principles, the equilibrium granularity of the ecosystem: not one giant domain (internal complexity and shared fate), not thousands of tiny ones (latency-bound), but firm-sized clusters around latency-coupled workloads (a DEX and its liquidation engine co-locate; a DEX and a lending market that can tolerate a finality delay do not). Domain boundaries become economic objects, and domain mergers and spin-offs (state migration under proofs, §4.4) become the M&A of the ecosystem.

### 4.2 Timescale separation is why it will not fall over [EMERGENT]

From dynamical systems: stiff systems are stabilized by separating slow and fast variables; from biology: the genome changes slowly while expression changes fast, and stability lives in the separation. Settlement is deliberately the slow variable (spork-gated Core, time-locked Periphery), domains are fast variables, markets are faster still, and the coupling is one-directional by commit discipline (fast layers never reach back into slow ones). Complex-systems theory predicts exactly this shape for evolvable robustness: near-decomposable hierarchies with rate separation. The architecture is not merely modular; it is rate-modular, which is the property that lets ecosystems explore without destabilizing the substrate.

### 4.3 The registry becomes a phylogeny [SPECULATIVE]

Every domain carries `stfSpecHash` lineage; every upgrade is a recorded, delayed, content-addressed transition; forks of a domain's STF are speciation events with a common ancestor hash. Run this for a decade and the domain registry is a phylogenetic tree of executable institutions, with extinction (escape hatch), heredity (charter reuse), and selection (users emigrating under the exit guarantee). Evolutionary dynamics on institutions, with the fossil record kept by consensus. Nobody builds this; it accretes.

### 4.4 State passports: history becomes a portable asset [EMERGENT]

Per-account state lives in contract SMT leaves; leaves are provable under finalized roots; roots have lineage; proofs travel through messages. Therefore any fact about a user's past inside any domain is exportable as a proof bundle, and any domain can choose to honor foreign history. Identity, reputation, credit history, achievement, tenure: all become Merkle passports the user carries, rather than records the platform holds. The platform-lock-in model of user data inverts. This needs only schema conventions, not protocol work, which is why it will happen before anyone specifies it and why specifying it early matters (§9.6).

### 4.5 Ordering bandwidth is the real scarce resource [EMERGENT] [RISK]

Every domain's inputs share one pipe: L1 account-blocks, at most 16 KiB each (§4.1, plasma constants), ordered by momenta at L1 cadence. Execution scales horizontally without limit; ordering does not scale at all within this design; it is inherited "as given" (§2.1 non-goals). So the binding constraint of the entire multi-domain future is L1 input throughput, and plasma is the auction for it. The feeless story is then precise rather than utopian: zero marginal price for admission within your capacity, capacity acquired by capital lockup (fused QSR) or work (PoW). That is spectrum licensing, not toll roads. The unknown unknown: **as domain count grows, the fiercest economics in the system will be fought over momentum space, a resource almost no current document discusses, and every compression trick (aggregation, intent batching, relayed-proof minimalism) becomes a business.** See §13.1 for the failure mode.

### 4.6 Jurisdictional competition with guaranteed emigration [EMERGENT]

Combining §1.5's exit right with domain plurality: domains are jurisdictions whose residents cannot be trapped. Political economy predicts a Delaware effect (standard charters win because integrators price legibility), regulatory arbitrage in code (domains competing on rule sets), and constitutions as products (charter templates with known closed-form risk, §2.3). The deep point: this is the first execution environment where Tiebout sorting (citizens choosing jurisdictions) has near-zero moving costs enforced by the kernel, which is the condition under which jurisdictional competition actually disciplines rulers.

### 4.7 Delay tolerance makes it off-world compatible [SPECULATIVE]

No mechanism couples execution liveness to consensus tempo: an executor can be silent for a day and resume at its cursor; batches are late, never wrong; messaging is asynchronous and finality-gated; capsules carry verification anywhere data can be carried. This is delay-tolerant networking's contract, met by construction. The essays gesture at interstellar frames; the concrete claim underneath is smaller and testable: a domain can operate across arbitrary link latency (a ship, a station, an air-gapped facility, a satellite relay, which the repo already studies) with degradation only in freshness. Settlement layers that assume synchronous liveness cannot say this.

---

## 5. Hidden Economic Models

### 5.1 The two capital sinks, and the collateral hierarchy [EMERGENT, denominations SPECULATIVE]

The architecture structurally demands two distinct kinds of capital. Admission capital: fused plasma capacity for L1 inputs (spec-grounded L1 mechanic; large inputs exceed PoW-only ceilings). Safety capital: executor bonds sized to Core-ceiling worst cases (§22), plus, in the market layer above, solver float and custody collateral. These have different risk profiles (admission capital is never slashed, only opportunity-costed; safety capital is slashable in Phase 2; solver float is credit-risked against residual trust). A collateral hierarchy emerges with senior (bonds), junior (solver float), and revolving (fused capacity) tranches. Denominations are pre-mainnet parameters and QSR assignment is speculative per the spec; the structure of the demand is not speculative, only its instrument.

### 5.2 Trust becomes a hedgeable commodity with a term structure [EMERGENT]

Extending §2.2: once solver spreads exist per (domain, delay, profile), standard fixed-income machinery applies. Forward trust rates (what will this domain's residual-trust premium be after its OPTIMISTIC migration), basis trades between domains sharing an executor, insurance written against the closed-form ceiling of §2.3 and hedged with the spread curve. The architecture does not just permit this; it standardizes precisely the parameters that make the instruments writable. The Market Framework says Settlement determines truth and markets determine worth; the discovery is that the first thing markets will price here is the gap between the two, and that gap has a term structure.

### 5.3 Actuarial DeFi: underwriting from public parameters alone [STRUCTURAL]

Because worst-case loss is closed-form (§2.3), a coverage market needs no diligence on operators: premium = f(cap, delay, bond, profile, observed spread). Underwriting collapses from investigation to arithmetic. Expect coverage domains whose entire risk model is Settlement state, and expect the existence of cheap mechanical insurance to become a selection pressure on charters (domains tune caps and delays to hit premium targets, the way firms tune balance sheets to hit ratings).

### 5.4 Verification procurement markets [STRUCTURAL]

The profile ladders make verifiers pluggable registry entries: `fraudVerifierRef`, `validityVerifierRef`, `consensusVerifierRef` (Bridge Framework §6.3, §6.4, §7.3). Choosing a proof system becomes a per-domain procurement decision recorded on-chain, and proof systems compete for registry slots the way HSMs compete for FIPS placements. Predictable consequences: a certification economy around verifier contracts, price-per-proof competition once `ZK_VALIDITY` domains exist, and the two ladders as the standard axes on which proof vendors position (execution proofs versus consensus proofs).

### 5.5 Watcher economics: the public-goods gap is the design's honest debt [RISK]

Phase 1 watchers are alarm-only and unpaid; Phase 2 fraud proofs create a bounty on divergence, but steady-state watching between incidents remains a public good. The trust yield curve gives a market answer nobody has proposed: solvers are the natural watcher funders, because their float is the capital most exposed to an undetected divergence inside the delay window. Expect solver consortia to run watchers the way market makers pay for market data, converting the public good into a club good. This should be designed for rather than discovered by accident (§9.4).

### 5.6 Compute as legal tender for machines [EMERGENT]

PoW plasma means an agent with spare cycles can mint its own admission. For machine economies this removes the bootstrapping dependency on acquiring tokens before acting: an IoT device or AI agent pays for ordering with work, holds no balance, and still gets force inclusion and exactly-once effects. The historical rhyme is flat-rate broadband: metered pricing killed usage classes that flat-rate unlocked, and agent-to-agent chatter is the streaming video of settlement; it only exists under zero marginal price.

---

## 6. Hidden Security Properties

### 6.1 One verifier to rule three layers kills a whole exploit class [STRUCTURAL]

The shared SMT core serves the L1 momentum adapter, the L2 executor adapter, and the Phase 2 referee, gated by one vector set (§13.1, ARCHITECTURE §5). Verifier mismatch, two implementations disagreeing about the same proof, is among the most productive bridge-exploit classes in history. It is excluded here by construction: the referee verifies with the same `VerifyProofByPath` the executor used. The honest caveat the repo already carries: the path-native API is a prerequisite, not yet landed, and was once falsely claimed as existing. The property is real once the prerequisite is.

### 6.2 One valid encoding everywhere kills the malleability class [STRUCTURAL]

Commitments reject trailing bytes and non-zero reserved fields; the bundle has exactly one encoding; `AssetID` has exactly one alignment and hashing is forbidden for it (§18.1, §19, §20). Encoding ambiguity, the other historically productive exploit class (signature malleability, alternate serializations of the same object), has no surface. This is the kind of property that is invisible until you list the CVEs it precludes.

### 6.3 Bounded rug: quantified admin compromise [STRUCTURAL]

Restating §2.3 as a security property: full administrator key compromise yields a bounded, computable maximum extraction, rate-limited by caps and raced against a guaranteed user exit window, with guardian recovery as the repair path. Very few systems can state their worst case under total governance failure as a number. Integrators should demand this number per domain; the spec makes it derivable.

### 6.4 Address grinding: a new intra-momentum priority primitive [EMERGENT] [RISK]

Canonical ordering within a momentum is ascending `AccountHeader.Bytes() = Address || Height || Hash` (§4.4), and Address is the leading 20 bytes. Consequence: **an actor who grinds keypairs for numerically low addresses obtains systematic priority over co-momentum competitors, permanently, for a one-time compute cost.** In same-momentum contention (liquidation races, oracle-update front-running at the application layer, mint races), low addresses win ties deterministically. This is a novel MEV primitive specific to lexicographic address ordering. Its severity is bounded: momentum assignment (which momentum you land in) dominates intra-momentum position, co-location is probabilistic, and cross-momentum ordering is untouched. But it is real, it is cheap, and it compounds: expect vanity-low address markets if contention-sensitive applications deploy. Mitigations are constrained because the executor MUST NOT apply any alternative order (§4.4); realistic options are application-level (commit-reveal, batch auctions inside the STF, which the MEV scope note §26 already hints applications must own) or an eventual L1 ordering revision. This finding belongs in the threat model now, while application conventions are still unformed.

### 6.5 Panic-inducement is cheap in Phase 1 [RISK]

Watcher alarms have no on-chain channel; the only user response to a credible divergence claim is exit through the delay window. Therefore a fabricated but credible alarm is a griefing tool: it can trigger a bank-run against an honest domain at near-zero cost to the attacker, congesting the withdrawal path (bounded by caps, which then become the attack's amplifier: caps convert panic into a queue). The defense is social and informational in Phase 1 (signed watcher identities, reproducible capsule evidence attached to alarms, so that a true alarm is cheaply distinguishable from a false one). Alarm formats should be specified with the same rigor as wire formats, precisely because the alarm is Phase 1's only enforcement surface (§9.4).

### 6.6 EXTERNAL_OBSERVED concentrates the remaining discretion [STRUCTURAL]

For observed domains the input-sequence ordinal is executor-committed (§4.5, §6.1). Completeness is contiguity-enforced against the domain's pinned predicate, but fine-grained ordering and timing of observations is executor discretion inside the predicate's slack. Oracle-timing MEV therefore lives exactly here, and nowhere else in the architecture. This is a feature if stated plainly: the design sweeps all residual input discretion into one labeled corner, where disclosure requirements (§6.1's trust-profile surfacing) and Phase 2 fraud enforcement can be aimed at it.

### 6.7 Deposits cannot strand; refunds are STF, not courtesy [STRUCTURAL]

`claimed_deposit` with automatic refund of the remainder, verified as part of the STF that Phase 2 referees must check (§18.5), removes the stranded-funds class (deposits to wrong or absent targets) and makes the refund itself fraud-provable later. Small, quietly excellent, and worth naming because "funds stuck in bridge contract" is a recurring headline this design cannot generate.

---

## 7. Unexpected Applications

### 7.1 Flight recorders for institutions [EMERGENT]

The evidentiary reading of EXTERNAL_OBSERVED (§3.3): a domain that observes an institution's own systems produces a non-repudiable, replayable record of exactly what was claimed and when, with state reconstructible from committed inputs alone (§6.1). The value is not trustlessness; it is attribution. Regulated industries buy attribution. Clinical trials, trading desks, content moderation pipelines, AI-model decision logs: anywhere "what did you know and when" is litigated, an observed domain is a flight recorder with a consensus clock.

### 7.2 Testimony markets [SPECULATIVE]

Following §3.3 to its end: bonded attestors whose every claim is committed, timestamped, and replayable, with slashing (Phase 2) and disclosed committee predicates, constitute a market for accountable testimony, priced by bond and track record (the record itself a state passport, §4.4). Expert opinion as an asset class with an audit trail.

### 7.3 Ship the STF: apps distributed as verifiers [EMERGENT]

Because the browser runs the same WASM the executor ran, the application frontend and the verifier converge into one artifact fetched like a static site (§1.2). "View source" returns, but for money: the page you load is the machine that checks the state it displays. App distribution stops needing app stores or trusted backends for the read path; it needs a CDN and a capsule.

### 7.4 Autonomous firms with limited liability enforced by the kernel [SPECULATIVE]

A domain has a charter (`stfSpecHash`), a treasury (custody pot), officers (bonded executors), liability limits (caps and bond), a public register entry, and a dissolution procedure (escape hatch). An AI agent operating as a domain's executor, under a charter that encodes its policy, is a firm whose bylaws are executable, whose liability is capped by consensus, and whose counterparties can price it from public parameters (§5.3). The corporation took centuries to get limited liability, registries, and audited accounts; the domain model ships all three as schema. This is the "autonomous companies" question answered structurally: not DAOs as chat-governed treasuries, but domains as charter-governed operators.

### 7.5 Games and simulations with portable pasts [SPECULATIVE]

Deterministic replay plus state passports: a game world whose every event is a capsule and whose players carry provable histories across worlds. Cheating becomes divergence; servers become executors; mods become STF forks with recorded lineage (§4.3). The interesting product is not "game on chain" but "history that survives the studio."

### 7.6 Scientific replication as infrastructure [SPECULATIVE]

A computation domain whose inputs are datasets by hash and whose STF is the analysis pipeline yields papers whose results section is a capsule: replication is a download and a deterministic run (§2.5). The replication crisis is partly a cost crisis; this makes re-performance approximately free for the class of analyses that fit deterministic execution.

---

## 8. Research Directions Nobody Is Discussing

### 8.1 Information-flow typing for truth (taint tracking for money) [EMERGENT, formalization open]

The architecture already types truth at domain granularity: `inputSource` and `foreignProfile` classify where facts come from and how they were verified. The missing research: propagate those labels through computation and messaging. A state key derived from `LIGHT_CLIENT`-verified inputs carries that label; an outbox message inherits the join of its causes' labels; a consuming domain declares the minimum label it accepts. This is information-flow control (the security-types literature) applied to settlement: taint tracking where the taint is epistemic provenance. It would let a contract enforce "this vault only accepts collateral whose provenance is at least proof-shaped," mechanically. The two ladders provide the lattice; the propagation semantics through the outbox algebra is an open, publishable problem.

### 8.2 The economics of domain boundaries [EMERGENT]

Formalize §4.1: a model where coordination costs are intra-domain complexity and transaction costs are outbox latency times finality delay, predicting equilibrium domain size and composition. Testable against the ecosystem as it grows. This is a transaction-cost-economics paper wearing a systems paper's clothes.

### 8.3 Estimating the trust term structure [EMERGENT]

Given solver spread data across (domain, delay, profile), identify the residual-trust premium and its determinants; event-study profile migrations (§6.6 of the Bridge Framework) as natural experiments in the price of verification. Empirical finance on an object that has never had prices before.

### 8.4 A process calculus for domains [STRUCTURAL, formalization open]

Message-passing with at-most-once, finality-gated, causally-anchored delivery over a global total order is a small, clean algebra. A pi-calculus variant with these primitives, plus a model-checking story (TLA+ modules for the outbox lifecycle), would make cross-domain protocol verification routine. The kernel's simplicity is what makes the formalism tractable; most chains are too expressive to model this cheaply.

### 8.5 Completeness-by-contiguity as a censorship-resistance primitive [EMERGENT]

Section 2.4 deserves its own treatment: a taxonomy of systems by whether omission is detectable, provable, or punishable, and a proof that cursor-contiguity over a pinned canonical sequence achieves on-chain omission-detection at O(1) verification cost. Then the interesting frontier: what classes of external sequences admit pinnable canonicity predicates (PoW chains: yes; BFT chains with finality: yes; API feeds: only via committed observation), which bounds what the primitive can protect.

### 8.6 Address-ordering games [RISK, open]

Formalize §6.4: the grinding cost curve, the equilibrium distribution of address values among contention-sensitive actors, application-layer countermeasures (batch auctions inside STFs) and their welfare effects. Also the L1-design question for any future ordering revision: what intra-block orders are simultaneously deterministic, ungrindable, and reproducible with no new derivation. (Hash-of-address-and-momentum-seed orders exist but violate the "no new derivation" elegance; the trade-off is worth a paper.)

### 8.7 Capsule archival economics [RISK, open]

Who stores capsules, for how long, at what incentive, once Phase 2 needs them only within challenge windows but history and passports (§4.4) want them forever. Content-addressed archival with verifiable retrieval is a studied field (storage proofs); its intersection with settlement-critical data and DAMode evolution (§20) is not.

---

## 9. Questions That Must Be Answered Before Implementation

Addressed to Domain Settlement implementers, beyond the open parameters the spec already registers.

1. **confirmationDepth** (Q-1 in the inventory): what is the Phase 1 default, is it operational or consensus-relevant, and is it uniform across relayers, executors, and watchers? Divergent frontiers between honest parties create false-alarm surface (§6.5 amplifies the cost of that surface).
2. **Address-grinding posture** (§6.4): accept, document, and push mitigation to applications; or reserve an L1 ordering revision path? Silence will be read as acceptance by whoever grinds first. At minimum, contention-sensitive first-party contracts (the system vault does not race; a future canonical DEX would) should specify commit-reveal or batch semantics.
3. **Alarm format specification** (§6.5): watcher alarms need a canonical, signed, capsule-referencing format so true alarms are cheaply distinguishable from griefing. This is Phase 1's only enforcement surface and it is currently informal.
4. **Relay liveness economics for L2-to-L2 delivery**: withdrawal recipients self-relay; message consumers may not. Who pays for `RelayMessage` on pure messages, and is that the intent layer's job or a protocol-adjacent bounty? At-most-once is guaranteed; at-least-once is nobody's job yet.
5. **Capsule retention horizon** (§8.7): minimum retention normatively tied to challenge windows; archival beyond that assigned to whom, verified how, priced by what? DAMode evolution should anticipate storage-proof backends.
6. **State passport schema** (§4.4): leaf-schema and root-lineage conventions standardized early, or ceded to whoever ships the first wallet SDK? Portability standards are winner-take-most; the neutral moment is now.
7. **domainId retirement semantics**: after an escape hatch drains a domain, is its `domainId` retired forever? Reuse would create cross-era replay ambiguity in anything that keys on `domainId` externally (passports, testimony records). One sentence in Core now saves an incident later.
8. **Plasma capacity planning for the multi-domain future** (§4.5, §13.1): what aggregate input bandwidth does the Phase 1 L1 actually offer, what is the expected input mix per domain class, and at what domain count does fused-capacity contention begin to price out PoW users? The feeless narrative should be published with its capacity envelope.
9. **Solver-watcher coupling** (§5.5): should the protocol-adjacent tooling make it easy for fulfillment capital to fund watching (shared infrastructure, attestation feeds), converting the public-goods gap into a club good by design rather than by accident?
10. **Quantified-compromise disclosure** (§6.3): publish, per domain, the closed-form maximum-loss figure under administrator compromise as part of the trust profile surfaced to users (§6.1 already mandates surfacing the profile; the number is derivable and more legible than the parameters).

---

## 10. Ideas Likely Worth Patent Investigation

Flagged for prior-art review; given the commons ethos, defensive publication may serve better than patents, but these are the mechanisms with genuine novelty character.

1. **Per-domain-subsequence contiguity verification over a shared global index** (§4.6): completeness enforcement for interleaved logical streams via per-stream cursors on a global ordinal, with O(1) on-chain check. The generalization beyond blockchains (multiplexed audit logs) is the interesting claim surface.
2. **Two-axis, independently migratable security profiles** (execution ladder times foreign-fact ladder) with strict-strengthening migration under a mandatory exit-window delay and no commitment-format change (Bridge Framework §6.3, §6.4, §6.6).
3. **Claimed-deposit with STF-enforced automatic remainder refund**, referee-checkable (§18.5): value-delivery semantics where non-acceptance is impossible to weaponize.
4. **Constitutional exit-latency floor**: enforcing rule-change delay greater than or equal to withdrawal latency as an unbypassable kernel bound (§6, §23).
5. **Completeness-enforced observed feeds**: applying input-sequence contiguity to executor-committed external observations under a pinned canonicity predicate (§6.1).
6. **Balance-blind conservation custody**: aggregate-only solvency enforcement enabling opaque-interior domains with public flow accounting (§18.1a, §2.1 of this report).

## 11. Ideas Likely Worth Academic Papers

1. Information-flow types for settlement provenance; label propagation through outbox algebras (§8.1). Venue shape: security (Oakland/CCS) or PL (POPL) crossover.
2. Transaction-cost economics of domain granularity; predictions and later empirics (§8.2). Venue: economics of organization meets systems.
3. The term structure of residual trust: extracting risk premia from solver spreads (§8.3). Venue: empirical finance / crypto-economics.
4. Completeness-by-contiguity: a censorship-detection primitive and its canonicity-predicate limits (§8.5). Venue: distributed computing (PODC/DISC) or security.
5. Lexicographic-address ordering games and grind-resistant deterministic orders (§8.6). Venue: EC / financial cryptography.
6. Certificate Transparency for computation: a formal reduction of anchored batch commitments plus watcher replay to CT's monitor model, with the split-view theorem for free (§1.1). Venue: security.
7. Constitutional exit guarantees in mechanism design: governance minimization via kernel-enforced emigration latency (§1.5, §4.6). Venue: mechanism design / law-and-economics.
8. Pace-layered consensus systems: rate-modularity as an evolvability property, with this architecture as the case study (§1.6, §4.2). Venue: complex systems / SOSP-adjacent position paper.

## 12. Ideas Likely Worth Building First

Ordered by leverage per unit effort, all buildable against Phase 1 surfaces or their immediate activations.

1. **Capsule gateway plus browser verifier** ("view source for state"): fetch bundle by `DAHash`, replay in-tab, render divergence. This single artifact demonstrates §1.2, §2.5, and §7.3 and is the reference client every later claim leans on.
2. **Watcher-as-a-service with a signed alarm feed** (§6.5, §9.3): the canonical alarm format, an attestation log, and a public divergence dashboard. Phase 1's entire enforcement story becomes tangible.
3. **Risk console** (§2.3, §9.10): per-domain closed-form maximum-loss, live cap headroom, delay clocks, bond coverage ratio. Integrators and insurers both need it; it is a query layer, not a protocol.
4. **Withdrawal solver for the first domain** (§2.2): front liquidity against finalized authorizations, publish spreads. This bootstraps the trust yield curve as observable data and funds the first watcher (§5.5).
5. **Plasma capacity service** (§3.2): fused-capacity leasing with flat-rate plans; the ISP business model proven small.
6. **State passport SDK** (§4.4, §9.6): leaf-schema conventions plus proof-bundle export/verify, before fragmentation sets in.
7. **Per-input proving pool prototype** (Phase 3 groundwork): treat `BundleInputRecord` as the work unit, parallelize per-input proofs, aggregate. Validates that the declarative ABI's circuit-minimization promise (§8.2 of SPEC) cashes out.
8. **A flight-recorder pilot** (§7.1): one real institution's process as an observed domain with disclosed predicate; the evidentiary product proves value without any custody claim.

## 13. Risks That Could Invalidate the Vision

1. **Ordering-bandwidth exhaustion** [RISK, structural]: §4.5's constraint inverted. If demand for momentum space outgrows L1 capacity, plasma contention re-creates a fee market at the admission layer, the feeless narrative inverts into a capital-lockup arms race, and aggregators who batch users become the new sequencers with the discretion the design evicted (§2.7). Mitigations exist (compression, relayed-proof minimalism, aggregation with competitive solver discipline, L1 capacity work) but this is the load-bearing scaling assumption and it lives outside the spec's control by declared scope.
2. **Capsule rot** [RISK]: unavailable bundles reduce affected batches to executor honesty (disclosed, §20) and starve Phase 2 disputes, passports, and history. Without archival economics (§8.7), the system's memory is best-effort. This is the quiet dependency under half the discoveries above.
3. **Phase 1 monoculture window** [RISK]: one executor, one domain, admin-keyed Periphery, alarm-only watchers. The design bounds the damage (§2.3, §6.3) but the reputational blast radius of an early incident is not bounded by caps. The panic-inducement surface (§6.5) makes even a non-incident dangerous. Duration of exposure matters more than its ceiling.
4. **Prerequisite drift** [RISK]: the path-native trie API remains a prerequisite once falsely claimed as existing (EXECUTOR v0.2.0 revision note). The one-verifier property (§6.1), the watcher, and the referee all stand on it. A quiet substitution (executor-local driver diverging from `common/trie`) would silently reintroduce the verifier-mismatch class the design exists to kill.
5. **External verification asymmetry** [RISK]: the authority-export thesis (§1.4) requires external chains to verify Zeno authorizations. Mode C (direct proof verification on Ethereum) is hard and possibly Phase 3-gated; Modes A and B import committee or optimistic trust at exactly the boundary the story claims to improve. If Mode C never becomes cheap, the export law degrades from "authority moves" to "committee-attested authority moves," a real but smaller claim.
6. **Address grinding normalization** [RISK]: if early contention-sensitive apps deploy without batch semantics, low-address priority becomes an entrenched, capitalized advantage that later mitigation would expropriate, making mitigation politically hard exactly when it becomes technically warranted (§6.4, §9.2).
7. **Governance backslide** [RISK]: the entire constitutional story (§1.5) rests on Core hard bounds surviving pressure. A single expedient spork that relaxes a bound "temporarily" converts the exit right into a courtesy and collapses §2.3's closed form. The threat is not key compromise; it is a reasonable-sounding emergency.
8. **Regulatory misread of observed domains** [RISK]: flight recorders (§7.1) and testimony markets (§7.2) put legally consequential records under executor commitment. If early deployments overclaim (calling replay-consistency "truth"), the evidentiary product gets discredited before its honest form matures. The Frontier discipline exists for exactly this; it must survive contact with sales.

## 14. Predictions About What People Will Only Understand After It Exists

1. **Feeless was for machines.** Human users never notice zero marginal admission cost; agents transacting thousands of times an hour cannot exist without it. The design's strangest choice will look obvious the year agent traffic first exceeds human traffic (§5.6).
2. **The delay was an interest rate.** The withdrawal delay reads today as a safety inconvenience. Once solver spreads print, it will be understood as the maturity axis of a credit market, and profile migrations will be discussed in basis points (§2.2, §5.2).
3. **The capsule was the app.** Distribution talk today assumes backends. The moment one popular application ships as static verifier plus capsule feed, "which RPC do you trust" will sound as dated as "which portal is your homepage" (§1.2, §7.3).
4. **Frozen was the feature.** Settlement's refusal to gain capabilities will be criticized as stagnation for years, then recognized as the reason everything above it could move fast, the same arc Linux's syscall stability and IP's stupidity traveled (§1.1, §1.6).
5. **Domains were firms.** The registry will be read as a technical table until domain M&A, charter templates, and closed-form underwriting make it legible as a corporate registry. Coase will be cited in a governance forum within two years of multi-domain activation (§4.1, §7.4).
6. **The biggest user was never DeFi.** Attribution, not finance: flight recorders, testimony, passports. The evidentiary economy has more institutions than the trading economy has traders (§7.1, §7.2, §4.4).
7. **Completeness was the moat.** Validity proofs are being commoditized industry-wide. The property competitors cannot cheaply retrofit is consensus-checked omission-detection over pinned sequences, because it requires owning the ordering layer, which is the one thing this architecture kept (§2.4).
8. **The clock outlives the coin.** Whatever happens to any asset narrative, a public, monotone, replayable ordinal with guaranteed inclusion is civil infrastructure, and the last users to leave will be the ones who only ever needed the time (§1.3).

---

*End of discovery report. Every tagged claim is falsifiable against the cited mechanisms; the untagged connective tissue is argument. Where this document conflicts with `SPEC.md`, `SPEC.md` governs, and where it conflicts with the Frontier discipline, that is the point.*
