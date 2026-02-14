Abstract

In 2008, Satoshi Nakamoto proposed “an electronic payment system based on cryptographic proof instead of trust.” The phrasing was precise. Not “instead of banks.” Instead of trust.

The Bitcoin whitepaper articulated a specific architectural constraint: verification must remain accessible to anyone, independent of centralized infrastructure. Nodes could “leave and rejoin the network” and reconstruct canonical state from ordering alone. Light clients could “verify payments without running a full network node.”

Between 2014 and 2016, the dominant path of smart contract design made execution authoritative to consensus, accepting that verification cost would scale with execution complexity. The economic consequence was structural: when independent verification becomes more expensive than delegation, rational users delegate. Delegation reintroduces trust. Trust reintroduces centralization.

The constraint was not a philosophical preference. It was a cost function. Systems either satisfy the inequality—Cost(verification) < Cost(delegation)—or they don’t. The data from 2024–2026 reveals which architectural choices satisfy it and which violate it. The consequences are measurable.



1. Satoshi’s Constraint: Proof Instead of Trust

The Bitcoin whitepaper opens with an economic problem:



“Commerce on the Internet has come to rely almost exclusively on financial institutions serving as trusted third parties… What is needed is an electronic payment system based on cryptographic proof instead of trust.”

The word “trust” appears six times in the abstract and introduction. This was the architectural requirement.

The system’s legitimacy depended on a specific capability: that verification could remain cheaper than delegation. If verification requires specialized hardware, privileged access, or continuous online presence, users rationally delegate. The system becomes based on delegated verification rather than cryptographic proof.

Lightweight Verification as First-Class Constraint

Satoshi made this explicit in the SPV (Simplified Payment Verification) section:



“It is possible to verify payments without running a full network node. A user only needs to keep a copy of the block headers of the longest proof-of-work chain… and obtain the Merkle branch linking the transaction to the block.”

This wasn’t a future optimization. This was a design requirement.

The architectural implication: verification cost must remain bounded independently of transaction volume or state complexity. Otherwise, trust re-enters through economic pressure.

Ordering as Source of Truth

Bitcoin’s breakthrough was recognizing that canonical state emerges from ordering, not from computation:



“Nodes can leave and rejoin the network at will, accepting the proof-of-work chain as proof of what happened while they were gone.”

Truth comes from ordering. Execution—in Bitcoin’s case, simple arithmetic updating account balances—is trivial enough to be independently re-checked by anyone.

This establishes the core properties:





Ordering determines canonical state



Verification operates on ordering (proof-of-work on headers)



Execution is local, deterministic, non-authoritative



Light clients verify through logarithmic-size proofs (Merkle branches)

Bitcoin minimized execution complexity precisely to preserve cheap verification.

The Bounded Vulnerability

The whitepaper acknowledged SPV’s limitation:



“While network nodes can verify transactions for themselves, the simplified method can be fooled by an attacker’s fabricated transactions for as long as the attacker can continue to overpower the network.”

The whitepaper did not deny this vulnerability. It bounded it.

SPV fails only if the attacker overpowers the network—controls majority hash power and sustains that control. That constraint is measurable, transparent, expensive to violate.

Most subsequent systems pursued a different architecture. Many still allow full verification—users can technically run full nodes and re-execute all state transitions. The critical difference is economic: the cost of independent verification scales with execution complexity. As of January 2025, running an Ethereum full archive node requires ~13TB storage and costs $200–400/month in cloud infrastructure.[^1] Users who technically can verify often rationally choose not to.

The attacker need not overpower anything—merely provide convenient services that users prefer over expensive self-verification.

[^1]: Etherscan node tracker data, Q4 2024. Archive node requirements grew 35% year-over-year.



2. The Dominant Strategy Trap

Consider two validators deciding whether to operate with transparent public orderflow or private exclusive channels.

Payoff structure:





Both public (P, P): Transparent, competitive = (3, 3)



One private, one public (R, P): Private captures MEV, public earns base only = (5, 1)



Both private (R, R): Split MEV market = (4, 4)

Your move if competitor goes public: Go private. 5 > 3.
Your move if competitor goes private: Go private. 4 > 1.

Private orderflow is the dominant strategy. The healthy outcome—(P, P)—is unstable. Equilibrium is (R, R): everyone goes private.

This is not coordination failure. This is architecture.

Systems where execution is authoritative create this trap. They reward information asymmetry about computation. Private orderflow protects that information. Cartels form as rational response to competitive pressure.

By October 2024, Flashbots data showed 92% of Ethereum blocks used private orderflow routing through 4 major builder groups.[^2] This is not market failure—this is architectural equilibrium.

Bitcoin’s architecture avoided this trap through constraint: execution is too simple to generate meaningful information asymmetry. There is no profit in simulating “2 + 2” before others see it.

[^2]: Flashbots Transparency Dashboard, October 2024. Builder concentration increased from 73% (2023) to 92% (2024).



3. At Low Throughput, All Systems Look Decentralized

When transaction volume is low, when state is small, when execution is simple—every blockchain looks decentralized. Differences emerge only under stress.

Under competitive pressure, systems where execution is authoritative fracture into tiers:

Tier 1: Sophisticated validators with superior hardware, better network positioning, private orderflow agreements. They simulate faster, see transactions first, extract maximum value.

Tier 2: Everyone else, who cannot compete on execution speed and increasingly rely on Tier 1 for truth-claims about state.

The system develops what we call a custodial gradient—a continuous spectrum from expensive self-verification to cheap delegation. Most users slide toward delegation because verification becomes more expensive than the value being secured.

Bitcoin demonstrated this tension within bounded parameters. As UTXO sets grew, full node operation became more expensive. By 2024, Bitcoin full nodes cost ~$50–100/month to run (1TB storage, modest CPU), while SPV clients verify with ~80MB of headers.[^3] SPV—the lightweight verification Satoshi designed—worked as intended for Bitcoin’s constrained execution model.

Bitcoin preserved cheap verification for its intended scope: simple value transfer. The architectural constraint held. Extending this constraint to general-purpose computation required fundamentally different mechanisms. When smart contract design made execution authoritative to consensus, verification costs scaled with execution complexity.

[^3]: Bitcoin node survey data, bitnodes.io, January 2025. Full node count decreased 12% from 2023 peak despite price appreciation.



4. The Profit Structure Determines Equilibrium

Architecture determines who profits from what. And who profits from what determines behavior.

When Execution Is Authoritative: Monetizing Information Asymmetry

In systems where execution defines canonical state, validators profit from knowing execution outcomes before others do.

The validator who simulates transactions faster extracts more MEV. The validator who sees the mempool first can front-run. The validator who controls orderflow can optimize sequencing for maximum extraction.

This creates competitive pressures:





Hardware race: Faster CPUs, more memory, parallel execution



Network positioning: Lower latency, privileged connections



Orderflow capture: Private mempools, exclusive relay deals

The system structurally rewards execution knowledge. Validators who fail to monetize it get outcompeted.

When Ordering Is Authoritative: Monetizing Reliability

In systems where consensus commits to ordered state rather than execution traces—where execution is deterministic and local—superior execution capability provides less competitive edge.

The value proposition shifts: “I produce canonical ordering that others can independently verify.” Hardware advantages diminish. Information asymmetry provides less edge.

This is Bitcoin’s original model: ordering determines truth, execution is local, verification remains cheap. Bitcoin’s limitation was achieving this only for simple execution.



5. Two Kinds of MEV

The industry conflates distinct phenomena:

Execution-derived MEV: Value extracted from knowledge of execution outcomes. Requires simulating transactions before ordering finalizes. Examples: liquidations, arbitrage, sandwich attacks.

Ordering MEV: Value extracted from controlling transaction sequence, independent of execution simulation. Examples: priority auctions, time-based advantages.

When execution is authoritative to consensus, execution-derived MEV becomes structural. It is not an exploit—it is expected rational behavior. Ethereum MEV extraction reached $1.38B in 2024, with 73% classified as execution-derived (front-running, sandwiching, liquidations).[^4]

When validators see execution outcomes before others, extracting value from that asymmetry is optimal strategy. The system rewards it. Mechanism design cannot eliminate what architecture makes profitable.

Bitcoin avoided execution-derived MEV by making execution trivial. There is no value in knowing that “Alice sends 1 BTC to Bob” will succeed before others know it—the execution is simple arithmetic.

Systems where ordering is authoritative can reduce execution-derived MEV if consensus commits to state before execution details are known. Ordering MEV persists unless constrained by additional mechanisms.

The claim is narrow: making execution authoritative bakes MEV extraction into the profit function.

[^4]: MEV data aggregated from Flashbots, EigenPhi, and Jito (Solana), 2024. Execution-derived MEV excludes pure priority fee auctions.



6. What Happens Under Load

Scaling Regime Execution-Authoritative Outcome Ordering-Authoritative Outcome Low throughput Everyone keeps up; appears decentralized Everyone keeps up; appears decentralized Medium throughput Builder/relay specialization begins; MEV supply chains form Role specialization begins; ordering services emerge High throughput Cartels dominate; hardware race intensifies If verification stays cheap: specialization without custody Under attack Defection to private lanes is dominant strategy Depends on whether verification remains independently cheap

At low throughput, all systems look decentralized. Under stress, the cost structure reveals itself.

In systems where execution is authoritative, throughput creates a hardware arms race. Only validators with sufficient resources keep up. Those validators extract maximum value through private arrangements. The custodial gradient steepens.

In systems where ordering is authoritative, throughput creates specialization, but specialization need not imply custody—if verification cost remains bounded logarithmically in state size, independent of execution complexity.

Bitcoin centralized around ordering authority (mining power) but preserved cheap verification through SPV. The vulnerability was that attackers controlling majority hash power could fabricate transactions—but detection remained cheap. Light clients could verify proof-of-work on headers without trusting execution results.

When ordering authority misbehaves in systems preserving cheap verification, independent verification allows detection and exit. When execution asymmetry dominates, ordinary users may never detect extraction.



7. The Technical Prerequisites

Preserving cheap verification at scale requires specific mechanisms:





Cryptographic state commitments: Merkle trees or accumulators committing to complete state at ordering points



Succinct inclusion proofs: Logarithmic-size proofs demonstrating state elements appear correctly in committed roots



Bounded proof sizes: Verification cost dominated by cryptographic operations, not execution simulation



Ordering-layer separation: Consensus operates on transaction ordering and state commitments; execution traces are not consensus-critical

Bitcoin implemented all four for simple execution:





Merkle roots in block headers commit to transaction sets



Merkle branches provide logarithmic inclusion proofs



Proof-of-work on headers provides bounded verification cost



Consensus operates on longest chain (ordering); execution is deterministic arithmetic

The question was whether these properties could extend to general-purpose computation.

The cost function:

Execution-authoritative:  O(T × E)  
Ordering-authoritative:   O(T × log N)


Where T = transactions, E = execution complexity, N = state size.

As E grows—as smart contracts become richer, call graphs deeper—systems where execution is authoritative see costs scale linearly. Systems where ordering is authoritative can keep verification logarithmic, bounded by cryptographic operations on compact commitments.

This is the economic formalization of Satoshi’s premise: that proof must remain cheaper than trust.

The architectural direction: Systems that commit to ordered state transitions before execution outcomes are determined—using cryptographic accumulators or Merkle commitments—satisfy the constraint independent of execution complexity. Execution becomes locally deterministic: nodes and light clients re-execute from ordering commitments without relying on validator execution claims. State commitments at ordering points enable logarithmic verification of inclusion.

This is the natural extension of Bitcoin’s SPV model to general-purpose computation. The empirical test is whether implementations maintain logarithmic verification costs under load.



8. Zero-Knowledge Proofs: Redistributing Cost, Not Eliminating It

Zero-knowledge rollups make verification cheaper through proof compression, but they do not escape the constraint that execution defines canonical state.

ZK systems: Execution remains authoritative; verification becomes cheaper through cryptographic proofs at 100x–1000x prover cost. Prover centralization becomes the bottleneck.

Ordering-authoritative systems: Execution is deterministic and local; no proof of correct execution is required because execution is not consensus-critical. Verification operates on state commitments.

Both can achieve sublinear verification. But the architectural relationship differs.

The critical insight: ZK reduces verifier cost but increases total system cost. Economic pressure doesn’t disappear—it shifts from validators to provers. Proof generation becomes expensive and specialized. Where execution-authoritative systems concentrate verification burden on users who must re-execute or trust validators, ZK systems concentrate computational burden on provers who must generate proofs.

By Q1 2025, production ZK rollup prover costs reached 200–800× the corresponding verifier cost per transaction, creating new oligopoly pressure as only 3–4 specialized proving services handle >80% of Ethereum L2 proof generation.[^5] The locus of centralization moves, but the pressure itself remains a function of execution complexity.

ZK rollups say: “We can make execution-authoritative verification cheaper.”
Ordering-authoritative systems say: “We eliminate the requirement for execution-authoritative verification.”

Bitcoin’s architecture achieved the latter for simple execution. ZK systems achieve the former for rich execution. Neither is wrong. But only ordering-authoritative designs preserve the whitepaper’s stated constraint at arbitrary execution complexity without redistributing cost to specialized provers.

[^5]: L2Beat prover concentration data, January 2025. Prover cost estimates from zkSync and Polygon zkEVM public performance reports.



9. The Attack Surfaces Differ

Attack Execution-Authoritative ROI Ordering-Authoritative ROI Execution-derived MEV Very high (structural opportunity) Lower (if state commitment limits simulation advantage) Censorship Medium-High Medium (ordering layer can still censor) Data withholding Medium Medium-High (if DA economics weak) Infrastructure capture High (users need trusted endpoints) Lower (if light clients can verify)

The difference is not that attacks become impossible. The difference is what they cost and what they pay.

In systems where execution is authoritative, reordering for MEV is rational profit-seeking. The architecture rewards it.

In systems where ordering is authoritative, execution-derived MEV requires breaking state commitment mechanisms. Ordering MEV persists, but extraction surface shrinks.

Bitcoin’s SPV already demonstrated this: attackers could fabricate transactions only by overpowering network hash rate—expensive, detectable. Ordinary fraud was cheap to detect through lightweight header verification.

Making execution authoritative weakens this by coupling validity verification to execution complexity. Users cannot distinguish valid from invalid execution without re-executing or trusting provers.



10. The Falsification Criteria

This framework generates concrete predictions:

Systems preserving cheap verification should:





Maintain logarithmic verification costs as state grows



Enable practical light clients verifying state without trusting full nodes



Show lower custodial infrastructure adoption rates than execution-authoritative systems at comparable throughput



Prevent infrastructure concentration from blocking independent verification

The hypothesis is falsified if:





Verification costs scale linearly or superlinearly with state growth



Light clients cannot practically verify without trusting execution results



User behavior converges toward custodial services at similar rates as execution-authoritative chains



Infrastructure concentration prevents meaningful independent verification

Satoshi provided falsification criteria: “the simplified method can be fooled by an attacker’s fabricated transactions for as long as the attacker can continue to overpower the network.”

SPV’s security assumption was explicit and measurable: as long as honest nodes control majority hash power, light clients verify safely.

Modern systems must meet the same empirical standard: can ordinary users verify state independently? Not in theory. In practice. Under load. Under attack.



11. The Mathematical Constraint

The framework reduces to a simple economic inequality:

If: Cost(independent_verification) > Cost(delegation)  
Then: Rational actors delegate  
Therefore: Trust re-enters the system


This is not moral judgment. This is equilibrium analysis.

Systems preserving cheap verification must satisfy:

Cost(verification) ≤ k × log(N)


Where N is state size and k is a small constant dominated by cryptographic operations.

Systems where execution is authoritative produce:

Cost(verification) ∝ T × E


Where T is transactions and E is execution complexity.

As E grows—as smart contracts become richer—the inequality breaks. Verification becomes more expensive than trust. Delegation becomes rational. Centralization becomes equilibrium.

Between 2014 and 2016, smart contract design faced a choice: preserve Bitcoin’s cheap verification constraint, or enable richer computation. The dominant path prioritized expressiveness. In pursuing this, most systems accepted that verification cost would scale with execution complexity. This was a tradeoff with predictable economic consequences.

Architecture is not ideology. It is a cost function. And cost functions determine behavior.

Bitcoin demonstrated one point on the tradeoff spectrum: cheap verification, constrained execution. Most subsequent systems demonstrated another: rich execution, expensive verification.

The consequences are measurable. The custodial gradient exists. The MEV cartels exist. The validator concentration exists. These are not bugs. These are features of the architectural choice.



12. The Live Experiment

Satoshi designed Bitcoin to satisfy the constraint for simple execution. The whitepaper promised that “a user only needs to keep a copy of the block headers.”

Modern systems claiming to preserve cheap verification must meet the same empirical standard: can ordinary users, with ordinary devices, verify state independently? Under load. Under attack.

Either the inequality holds, or it doesn’t.
Either verification remains cheaper than trust, or it doesn’t.
Either the architecture preserves the constraint, or it doesn’t.

The experiment is running.

The data from 2024–2026 reveals clear patterns:





Ethereum full node costs grew 35% year-over-year while node counts declined



Private orderflow routing increased from 73% to 92% as MEV extraction intensified



ZK prover costs reached 200–800× verifier cost, concentrating proof generation among 3–4 specialized providers



Bitcoin SPV maintains sub-100MB verification cost for 15 years of history

The constraint is not a historical curiosity. It is a live empirical test.

Systems that separate ordering commitments from optional local execution—preserving logarithmic verification through compact state accumulators—represent the natural extension of Bitcoin’s constraint to general-purpose computation. Whether implementations succeed is empirical, not philosophical.

If any system can make verification cheaper than trust at arbitrary computation scale, it satisfies Satoshi’s premise. If not, it converges to the same equilibrium: centralized trust under cryptographic decoration.

Incentives respond to cost functions, not intentions.
Systems are either architected to preserve cheap verification, or they are not.
And the data does not lie.



Zenon’s Network of Momentum is fully open-source and community-run. More formal documentation and ongoing community research can be found at:

https://github.com/TminusZ/zenon-developer-commons
