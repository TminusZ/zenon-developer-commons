# Rebuilding the Stack: The Architecture Zenon Was Quietly Designing


For years, Zenon's architecture existed primarily as design — fragments of technical direction scattered across public messages, forum threads, and unfinished implementation surfaces. The vision was unusually ambitious. The constraint was obvious: infrastructure of this scope requires coordination, engineering depth, and sustained execution bandwidth.

Kaine acknowledged that reality directly, on April 6, 2023:

> "Resources will probably be limited, as AI will implement most of it."

At the time, that line read as a forward-looking observation about tooling. Today it reads differently. Small teams and independent builders are beginning to prototype pieces of an architecture that once existed almost entirely as theory — lightweight verification, SPV systems, interoperability rails, peer infrastructure, execution surfaces that map closely to the original design direction. The cost of implementation has shifted. The leverage available to builders has changed. Tasks that once required coordinated protocol teams can now be prototyped by small builder groups using AI-assisted engineering, shrinking the gap between architecture and implementation.

What once looked like architectural overreach may have simply been early timing.

This matters because it changes how Phase 1 should be read — not as a roadmap that overreached its moment, but as a technical stack that is only now entering its implementable era.

There is also a practical reason to revisit Phase 1 now.

Zenon is approaching a threshold where community implementation is no longer theoretical. Builders are beginning to explore SPV verification, interoperability surfaces, peer infrastructure, and broader execution design. As that work accelerates, roadmap decisions will follow — what gets prioritized, what gets deferred, what gets simplified, what gets built first. Those decisions are too consequential to make from fragments, assumptions, or incomplete memory of what was originally designed.

They should be made with a clear understanding of the architectural direction that was laid down — not as doctrine, but as design context. What problems was Phase 1 actually trying to solve? Which components were foundational? Which were downstream? Which ideas were exploratory, and which were structural commitments?

That is the purpose of this reconstruction.

Not to preserve history for its own sake. To remap the architecture clearly enough that the community can decide — with modern tooling, fresh implementation capacity, and a changed technological landscape — what deserves to be carried forward into the roadmap now.


## The Nature of Phase 1

Some network upgrades add features. Others change what a network is capable of becoming. Phase 1 belongs to the second category.

The architecture proposed for Zenon's next major network phase was not a conventional product roadmap. It was a systematic refactoring of the network's foundations: how nodes verify, how they synchronize, how they communicate with each other, how they coordinate with Bitcoin. The application layer was explicitly downstream. What came first was the infrastructure that makes serious applications possible.

That distinction — substrate before application, verification before execution — was stated plainly and repeated consistently in the record. It also made Phase 1 difficult to grasp from any single message or discussion thread. Components surfaced individually: a note about libp2p here, a comment about hash locks and time locks there, references to threshold signing, zero-knowledge proofs for bootstrapping, Sentinel nodes, dynamic Plasma. Each piece was real. The connective tissue between them rarely came into focus.

This essay attempts to bring that picture together. The reconstruction draws on several hundred public messages from Kaine, the pseudonymous lead architect behind Zenon, spanning 2021 and 2022. Where his statements are clear, they are treated as established record. Where the record requires inference, that inference is labeled. Where the architecture remains genuinely unresolved, that is stated plainly.

The central thesis: Phase 1 was a verification-first network refactor designed to make cheap independent verification, resilient peer infrastructure, and Bitcoin-native interoperability foundational properties of the network — not add-ons, but structural commitments built into the foundation.

Everything else in Phase 1 flows from that design choice.


## The North Star: Cheap Independent Verification

Before examining individual components, the design constraint running through all of them needs to be stated clearly.

Kaine stated it directly: "The embedded node is a full node. You just need to keep the wallet open." The design goal for Syrius, Zenon's wallet application, was to incorporate a full verification node the way Bitcoin Core does — not a thin client that trusts external infrastructure, but an independent verifier that also manages keys. "Full nodes are first class citizens in NoM."

The implication is significant. If the scale target for independent verification is not dozens of dedicated operators but potentially millions of wallet-running participants, the network substrate has to be built to make that cheap. Every component of Phase 1 can be read against that constraint: what does the infrastructure have to look like for a wallet-embedded full node to be accessible enough for mass deployment?

The answer Phase 1 proposes is a layered one. Public-IP Sentinel nodes form the backbone — dedicated, publicly addressable infrastructure that the rest of the network bootstraps against. Wallet-embedded full nodes form an encouraged intermediate layer for engaged participants who want to verify independently without running dedicated infrastructure. Lightweight clients serve the mass-scale ceiling. Kaine cited Satoshi's framing approvingly: "The rest will be lightweight clients, which could be millions."

This is not a model in which every user runs a full node. It is a model in which independent verification is cheap enough that the full-node layer is densely populated, with lightweight clients building on top of it rather than replacing it. The goal is to prevent the verifier population from stratifying toward well-resourced operators — which is precisely what happens when joining the verifier set is expensive.

That framing transforms IBD (Initial Block Download) from a performance question into a decentralization question. Kaine said as much: "IBD is a very important topic for network decentralization." A network where syncing from genesis is computationally prohibitive is a network where the verifier set shrinks toward those who can afford it. Keeping sync cheap is how the verifier set stays broad. Everything that follows is built on top of that constraint.


## Part One: What the Record Clearly Establishes

### Bitcoin Interoperability via Cryptographic Primitives

"In NoM Phase 1, we will focus on interoperability with Bitcoin using novel cryptographic approaches that will leverage signatures, hash locks, and time locks."

Three constructs are named. Hash locks are cryptographic commitments: a party reveals a secret preimage to satisfy a condition. Time locks are temporal constraints: an output that cannot be spent until a specified block height or timestamp. Together, they compose the foundational building blocks of conditional, time-bounded settlement between parties that do not trust each other. Both are native Bitcoin scripting primitives.

Signatures, in this context, refers to the broader family of cryptographic authorization constructs: ECDSA, threshold ECDSA, Schnorr, adaptor signatures, multi-party constructions. The record does not narrow further at this level of the statement.

What the statement establishes is the orientation of the interoperability goal: it is cryptographic, not operational. The tools named are instruments of trustless coordination, not instruments of trusted custody. Kaine distinguished this explicitly: "Multi-chain wallet != interoperability." Presenting assets from multiple chains in a unified wallet interface is not the same thing as protocol-level interoperability. Phase 1 was targeting the latter — and Kaine set the ceiling accordingly: "Interoperability with Bitcoin can go beyond value transfer. Every detail must be taken into account."

The record also shows a clear preference ordering on settlement primitives. On HTLCs: "For a HTLC you'll need timelocks + hashlocks => znn x btc atomic swaps." Then, later: "HTLC is good, but PTLC is better" — PTLCs replace hash locks with adaptor signatures, providing better privacy and composability properties. HTLC was the near-term implementation target; PTLC was the named superior successor.

Bitcoin state access was addressed separately. The purpose of integrating btcd, the Go Bitcoin library, was stated plainly: "to provide interoperability by having access to the state of Bitcoin's blockchain." This is a read interface to Bitcoin's chain state — not a mining integration, not a consensus mechanism.

### Threshold Signing and Native Bitcoin Custody

One of the most architecturally specific statements in the record on interoperability: "Pillars can act as TSS signers and hold native btc vaults."

TSS (Threshold Signature Scheme) is the mechanism. Pillars are the named signing participants. The vault holds native bitcoin, not a synthetic representation. The statement implies distributed signing custody: no single party controls the vault. Quorum mechanics, rotation policy, fault tolerance model, and threshold parameters are not specified at this level. Kaine noted that "a TSS scheme" is his recommendation without naming a specific protocol, and separately pointed to the secp256k1 curve — shared by both Ethereum and Bitcoin — as "looks very promising" for interoperability, citing cross-chain signature scheme compatibility as a structural asset.

### The P2P Layer: Why "First" Matters

"zk-telemetry. There are many ways to map the p2p network. But first we'll need to upgrade the p2p layer and using libp2p is a big step forward."

The word "first" is load-bearing. In an architectural context, "first" is prerequisite language — it identifies a dependency, not a preference. The existing p2p layer is insufficient; libp2p is the upgrade target; everything that depends on a healthy peer substrate has to wait for this.

The coupling to IBD is explicit in the record: "We've made excellent progress on the p2p layer and this will improve both connectivity and IBD." P2P health and sync cost are not independent variables. Fixing one improves the other; neglecting one constrains the other.

Kaine described what a more resilient bootstrap mechanism would require: "Ideally we need a mechanism for auto peer discovery without relying on trusted third parties," with Tor integration named as a near-term step. For off-chain coordination between swap participants specifically, the Signal protocol library (libsignal) was proposed as a candidate channel: "For p2p messages between network participants we can use libsignal. It can be used to coordinate users that engage in atomic swaps." This is distinct from Zenon's p2p gossip layer and represents a named direction for swap negotiation — not a finalized specification.

Zk-telemetry — zero-knowledge proofs applied to mapping or measuring the p2p network — is named but not elaborated. What is being proven, who generates or verifies the proofs, and how results feed into network operation remain open.

### Sentinel Nodes: A Named Answer to a Specific Problem

Two messages, sent six minutes apart, March 10, 2022:

"We need more public IP nodes. Recently we've made excellent progress on the p2p layer and this will improve both connectivity and IBD."

Followed by: "Sentinel nodes is the answer. How can you ensure they are running a full node with a public IP?"

The connection is direct. The public-IP node shortage is the problem; Sentinels are the incentive mechanism designed to solve it. They are not an abstract node type — they are the answer to a specific infrastructure gap, stated explicitly in sequence.

What the record confirms:

- Sentinels are the direct answer to the public-IP full node shortage
- They must run a full node with a public IP address
- They process and relay information; PoW computation is explicitly excluded from their role
- They can serve as protocol-level oracles
- DLC support via Schnorr signatures was flagged as desirable: "An embedded with Schnorr signatures to enable DLC for Sentinels would be nice"
- They are a Phase 1 deliverable
- They were not yet implemented as of April 2022

What remains unresolved: incentive and reward structure; staking requirements and slashing conditions; oracle attestation governance; whether their oracle functions are central to the interoperability layer or optional extensions; and the relationship between Sentinels and zk-telemetry.

On the DLC function: Discreet Log Contracts allow two parties to settle on an observable outcome using a pre-committed adaptor signature from an attesting oracle. If Sentinels serve as DLC attestors, they could form part of a protocol-level attestation layer for Bitcoin-anchored conditional contracts. The record describes this as desirable. It does not establish whether that role was intended to be central, peripheral, or exploratory.

### The Execution Constraint

The Phase 1 record contains an explicit and repeatedly stated position on where computation belongs: not at L1.

"From an architectural point of view, one of the best decisions so far was avoiding the implementation of a heavy VM at L1/on-chain." And: "Networks that implemented a heavy VM (EVM/WASM) at L1 will always be plagued by scalability issues in the long run."

Transaction processing time and the embedded VM are listed in Kaine's long-term problem set — not as Phase 1 deliverables, but as downstream concerns. The L1 should be "minimal, robust and as efficient as possible." This is a deliberate design choice, not a gap, and it has direct consequences for what the verification layer has to do and how expensive it is to run. The restraint at L1 is the precondition for everything built above it.

### Dynamic Plasma

"The next challenge is to implement Dynamic Plasma (similar to Bitcoin's difficulty adjustment mechanism)."

The analogy is instructive. Bitcoin's difficulty adjustment is a network-level control mechanism — not a reward distribution mechanism. Kaine applied the same framing to Plasma: throughput control, not tokenomics. The current network operates under a static cap. Dynamic Plasma removes that cap by adjusting resource parameters in response to observed conditions. "For the moment the network is capped, that's why dynamic Plasma is the next logical step."

The record also surfaces a coupling between PoW links and Plasma that received limited attention at the time. "It may be possible to use the PoW links to merge mine Bitcoin; the other way around is to merge mine ZNN and create Plasma for Bitcoin feeless txs." The planned PoW link algorithm migration — from SHA-3 to SHA-256d and RandomX as named candidates — is relevant here: SHA-256d is Bitcoin's proof-of-work algorithm. Algorithm alignment is the precondition for merge-mining compatibility.

### ZK Proofs: Two Distinct Applications

The archive contains two separate ZK proof applications that have often been treated as the same thing.

The first is ZK proof compression for bootstrapping. In December 2021, Kaine noted that "recursive ZK-SNARKS/STARKS can solve some issues" in the context of sync difficulties. This points toward proof-verified state bootstrapping — compressing historical chain state into a succinct proof that a new node can verify without replaying the full ledger.

The second is ZK rollups as a throughput layer above L1. This was elaborated in late 2022: "ZK-proof rollups are part of the strategy to keep the L1 minimal and robust." "The state of the rollup will be posted and verified on-chain." "Unikernels can be implemented on top, as well as other ZK rollup solutions that will support Turing-complete smart contracts."

These are different engineering problems with different proof systems. The first compresses history to reduce sync cost. The second compresses execution to enable programmability without burdening the base layer. Both are ZK applications. Neither is the same thing.

### The Phase 1 Milestone List

The official milestone list:

1. Narwhal and Tusk
2. Dynamic / Adaptive Plasma
3. Interop solutions
4. IBD with ZK proofs (ZeroSync)
5. libp2p layer (upgraded)
6. Sentinel support

A necessary note on entries one and four: Narwhal and Tusk are explicitly listed in the published Phase 1 milestone set, but were not materially elaborated in the message corpus analyzed for this essay. Their inclusion is architecturally consistent with Kaine's broader direction — particularly around networking, synchronization, and scalable consensus — but the record reviewed here does not contain detailed commentary from him on how he intended to apply them within NoM.

For orientation: Narwhal functions as a dissemination layer, separating data availability from ordering; Tusk is the ordering and asynchronous BFT layer built above it. Together, they represent a DAG-based approach to consensus that maps plausibly onto Zenon's dual-ledger structure. The combination is included in the milestone list as a confirmed target; the specifics of Kaine's intended application remain to be established from additional source material.

The ZeroSync attribution carries similar weight. The ZK proof direction for IBD is supported by the archive; the specific ZeroSync attribution requires independent source verification before it can be confirmed.


## Part Two: What Follows from the Record

Each inference below is grounded in its source statements and bounded by what it does not establish.

### The Architectural Stack

One coherent reading of Phase 1 produces the following dependency ordering, from foundation to surface. Where Kaine used explicit sequencing language, that is noted. Elsewhere, the ordering reflects the strongest inference from problem statements, coupling signals, and architectural logic in the record.

**Verification** (IBD, ILD, ZK proofs) is the base. Nodes must be able to independently confirm ledger state without trusting other participants. Without this, every layer above it rests on an assumption of honesty.

**Synchronization** (ILD, dual-ledger growth management) sits just above it. New participants must be able to bootstrap a correct view of the network at reasonable cost. A network where full historical replay is required to join the verifier set is a network where the verifier population stratifies toward well-resourced operators.

**The networking foundation** (libp2p, Tor, peer discovery) must precede the layers that depend on it. Kaine's own word — "first" — establishes this explicitly. The peer layer needs to reliably propagate data, discover nodes, and sustain connectivity across diverse conditions. IBD cost is explicitly coupled to p2p health: one cannot be fixed without the other.

**Cryptographic interoperability and custody** (HTLC/PTLC, TSS Pillar vaults, btcd, libsignal as a candidate coordination layer) sits closer to the architectural center than the milestone list order suggests. Kaine called Bitcoin interoperability the Phase 1 focus. The primitives he named are foundational settlement constructs, not application features.

**Infrastructure participants** (Sentinel support) depend on the libp2p upgrade being in place. The "first" sequencing signal makes this dependency explicit. Sentinels are likely also coupled to the interoperability layer through their oracle function — which requires Bitcoin state access as a precondition.

**Throughput control** (Dynamic Plasma) is the resource allocation layer that makes broad participation viable under real load. The static cap is incompatible with production-scale operation.

**ZK rollup verification** is the scale layer above the foundation. Turing-complete computation lives here, verified by L1, not executed at L1.

**Execution** (embedded VM, WASM runtime, unikernels) sits at the top — explicitly downstream. The heavy computation that application developers need belongs here, not at the base layer.

This is not a list of features on a timeline. It is a dependency ordering. Phase 1 was building the stack that everything else would run on.

### The Interoperability Layer Is Staged, Not Monolithic

The record shows a progression, not a single deployment. HTLC atomic swaps are the intended first operational interoperability primitive — timelocks plus hash locks, enabling cross-chain settlement between parties without shared trust. PTLC with adaptor signatures is the stated superior successor, replacing hash locks with cryptographic point commitments that provide better privacy and composability.

TSS-held native BTC vaults operated by Pillars represent a distinct custody mechanism — parallel to or above the swap layer. The proposed user circuit — BTC in via atomic swap, feeless transactions on Zenon, BTC out via atomic swap — describes a complete flow that layers HTLC/PTLC settlement with Zenon's native fee model.

Off-chain swap negotiation has a named candidate channel: libsignal, proposed explicitly for coordinating participants before on-chain settlement. The architecture this implies has three layers: negotiate via libsignal (encrypted, off-chain), settle via HTLC or PTLC (cryptographic, on-chain), transact via Zenon account chains (feeless, fast). The specific channel remains a named candidate, not a confirmed specification.

### On Finality

The settlement primitives Kaine named — timelocks, hash locks, adaptor signatures, TSS-held vaults — all operate correctly under probabilistic finality models. They use temporal bounds and cryptographic commitments to manage settlement uncertainty across chains without requiring instant absolute settlement.

One bounded inference: settlement design and verification architecture were co-designed around a probabilistic convergence model. Systems that do not require deterministic finality can scale the verifier population horizontally, distributing settlement confidence across many independent participants rather than concentrating it in a small validator class with strict agreement requirements. That is consistent with the broader pattern in Phase 1 — lower the cost of joining the verifier set, sustain the public-IP backbone, make bootstrapping cheap, keep the base layer minimal.

The same primitives function under deterministic-finality systems as well. This is a plausible reading of the design choices, not the only one consistent with the record.

### The PoW Link Migration

The planned migration from SHA-3 to SHA-256d and RandomX as PoW link algorithms is not a routine upgrade. SHA-256d is Bitcoin's proof-of-work algorithm. If Zenon's PoW links use SHA-256d, they become directly recyclable for Bitcoin mining — and Bitcoin mining becomes directly recyclable for Plasma generation. The merge-mining proposal depends on this algorithm alignment.

The proposed PoW link migration opens a technical path toward bidirectional merge-mining compatibility with Bitcoin. Whether that path leads to a deployed mechanism, and how protocol-level coordination between Bitcoin miners and Zenon nodes would work, remains open.


## Part Three: What Remains Unresolved

Several questions are genuinely open — either because the record does not address them or because the design decisions required have not been made.

**Sentinel incentive structure.** The record establishes the problem Sentinels solve and the functions they are designed to perform. The economic architecture — incentive model, staking requirements, slashing conditions, oracle attestation governance — is unresolved.

**TSS protocol selection.** "I recommend a TSS scheme." No scheme is named. FROST, MuSig2, GG20, and others have materially different tradeoffs on round complexity, key generation, fault tolerance, and Bitcoin script compatibility. The choice has significant engineering implications.

**ZK proof application in IBD/ILD.** ZK proofs are named for two distinct purposes: bootstrapping (proof-compressed state verification) and Bitcoin state access (succinct Bitcoin chain verification). These are different circuit designs addressing different problems. Both could be in scope; the record does not resolve which direction is primary.

**The adaptive Plasma algorithm.** Dynamic Plasma is modeled on Bitcoin's difficulty adjustment. No feedback metric, adjustment interval, or formula is specified. What drives adaptation, how the adjustment function is parameterized, and how staking economics respond to dynamic parameters are all unspecified.

**Zk-telemetry.** Named as a mechanism for mapping the p2p network. What is being proven, how proofs are generated and verified, and whether results feed into Sentinel incentives, Plasma allocation, or something else: entirely open.

**ILD mechanism.** Zenon's dual-ledger architecture — separating account chain state from momentum chain state — creates a bootstrapping challenge distinct from single-ledger IBD. How these two layers are handled during initial sync, what commitments are verified, and how dual-ledger growth shapes verification architecture are unresolved.

**Narwhal/Tusk and ZeroSync sourcing.** As noted in Part One, neither appears with material elaboration in the message corpus analyzed here. Both require independent source verification before their intended application within NoM can be established with confidence.


## Part Four: What a Completed Phase 1 Network Would Look Like

The picture the architectural stack implies — labeled as inference from the record, not confirmed specification.

**Cheap node entry.** New participants can join the verifier set without replaying full chain history. Succinct ZK proofs compress historical state into verifiable commitments. IBD cost is low enough that the verifier population is not determined by resource access.

**Resilient peer infrastructure.** The libp2p-upgraded network supports auto-discovery without trusted third parties, Tor-routed connectivity for censorship resistance, and a public-IP backbone sustained by Sentinel incentives. The peer layer functions across diverse conditions and adversarial environments.

**Trust-minimized Bitcoin coordination.** The network has read access to Bitcoin's chain state via btcd integration. HTLC atomic swaps are the intended first operational interoperability primitive; PTLC with adaptor signatures is the upgrade target. Pillars are potential TSS signers for native BTC vaults. The proposed user-facing circuit — BTC in, feeless Zenon transactions, BTC out — is the full intended flow. Bitcoin-anchored conditional contracts become possible if Sentinel oracle roles are implemented as described.

**Elastic throughput.** Dynamic Plasma replaces the static throughput cap with a network-level control mechanism. Resource pricing responds to observed conditions. The PoW link algorithm migration opens the technical path toward merge-mining compatibility with Bitcoin.

**Minimal base layer.** The L1 verifies state and rollup commitments but does not execute complex computation natively. ZK rollup state is posted and verified on-chain. The design is deliberately minimal by architecture, not by resource constraint — and that constraint is what enables the execution layers above it.

**Layered participation.** Sentinels and dedicated full nodes provide the public-IP backbone. Wallet-embedded full nodes form an encouraged full-verifier layer for engaged participants. Lightweight clients serve the broad user base. Independent verification is available to anyone running the wallet; it does not require dedicated infrastructure.

At completion, Zenon is designed to be a lightweight-verifiable network with cheap node bootstrap, resilient peer discovery, adaptive throughput, Bitcoin-native settlement rails, distributed BTC custody primitives, and a base layer focused on verification rather than execution. In practical terms: a network that can independently verify cheaply, coordinate trustlessly with Bitcoin, and serve as a settlement foundation for higher execution layers built above it.


## Part Five: What This Foundation Enables

Phase 1 is a foundation, not an end state. The capabilities it establishes are prerequisites for higher-order constructs that are not Phase 1 deliverables but become achievable once Phase 1 is in place. These are capability horizons, not committed deliverables.

**Programmable Bitcoin settlement rails.** With HTLC/PTLC primitives, TSS-held native vaults, Bitcoin state visibility, and Sentinel oracle capacity in place, the building blocks exist for programmable settlement protocols that span both chains. What can be expressed on those rails — conditional transfers, time-bounded agreements, multi-party coordination — extends well beyond simple atomic swaps.

**Trust-minimized bridges.** The TSS vault architecture provides a foundation for bridge designs with cryptographically distributed custody rather than federated operator trust. The specific trust model remains open, but the architecture points toward bridges that do not concentrate custody in a single party or small operator group.

**Oracle-driven contracts.** If Sentinels serve as protocol-level attestors for DLCs, contracts that resolve based on observable real-world outcomes become possible. The range of what can be attested to depends on oracle governance architecture, which remains open.

**ZK execution layers.** With L1 rollup verification in place, external teams can build ZK execution environments verified by Zenon's base layer without requiring changes to the L1 itself. The unikernel and WASM paths Kaine described are instances of this. The execution ceiling is not fixed — it expands as rollup technology matures.

**High-scale lightweight networks.** With cheap bootstrapping, elastic throughput, and a resilient peer layer, the lightweight client population the network can support grows substantially. Applications requiring millions of lightweight participants become architecturally feasible in ways they are not on a network with expensive bootstrapping and a static throughput cap.

**Decentralized compute coordination.** This is the most speculative horizon and the one least directly supported by the record. Kaine's statements about unikernels, minimal L1, and execution offloading are consistent with a network that could eventually coordinate specialized compute environments — but the path from Phase 1 foundation to that outcome passes through many unspecified design decisions. It belongs at the edge of what the architecture could eventually support, and should be labeled accordingly.

### What Phase 1 Is Not

For readers approaching this from adjacent ecosystems, the negative boundary is clarifying. Phase 1 is not:

- an application launch phase
- an L1 smart contract phase
- an EVM compatibility phase
- a pivot toward a heavy VM chain model
- a custodial wrapped-BTC shortcut
- a thin-client-only network
- a concentrated validator set model

Each of these is either explicitly rejected in the record or structurally incompatible with the design choices the record confirms. The architecture Kaine described is specifically not those things — and that specificity is not incidental. It follows directly from the verification-first constraint that shapes everything else.


## Conclusion

The open questions are real and significant. Sentinel incentive mechanics, TSS protocol selection, the ZK proof direction for bootstrapping, the adaptive Plasma algorithm, zk-telemetry specification, and the sourcing of Narwhal/Tusk and ZeroSync all require either additional source material or explicit design decisions. Treating any of them as settled would misrepresent the record.

What the record does establish, read as a system stack rather than a feature list: verify first, sync efficiently, build a resilient peer layer, incentivize the participants who sustain it, remove the throughput cap, coordinate trustlessly with Bitcoin, verify off-chain computation at the base layer, execute anything above all of it.

The limiting factor was never vision. It was execution bandwidth. And execution bandwidth has changed.

Kaine's observation that "only the vision and architecture design will matter" was a thesis about where value concentrates in protocol development. Phase 1, read as a coherent stack, is that thesis rendered in engineering terms. The components that appear unrelated in isolation — p2p upgrades, IBD optimization, Sentinel incentives, threshold signing, dynamic Plasma, ZK bootstrapping — resolve into a single consistent argument when read against the verification-first constraint.

Each layer addresses a dependency of the layer above it. Cheap verification enables a broad verifier population. Resilient synchronization enables cheap verification. A robust peer layer enables resilient synchronization. Sentinel infrastructure sustains the peer layer. Bitcoin interoperability gives that substrate a native settlement surface. Dynamic Plasma makes it elastic under real load. ZK rollup verification opens it to execution above, without burdening it below. The stack is coherent because the constraint is coherent.

In that framing, Zenon is best understood as a verification-first settlement substrate, not an execution-first Layer 1.

If this stack is implemented coherently, Zenon stops being valued as a dormant Layer 1 and starts being valued as infrastructure — verification infrastructure, Bitcoin settlement infrastructure, and execution infrastructure built above a minimal base layer. That is a fundamentally different market category.

Phase 1 was less a feature release than a redesign of the network's foundations. Verification first. Synchronization made cheap. Connectivity made resilient. Bitcoin treated as a native interoperability target rather than an external asset to wrap. Execution moved above settlement instead of embedded inside it.

That is not a typical Layer 1 roadmap. It is a different model of what a network can be.
