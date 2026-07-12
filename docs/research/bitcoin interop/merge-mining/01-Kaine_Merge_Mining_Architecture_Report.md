# Reconstructing Kaine's Merge-Mining Architecture: A Process-of-Elimination Report

*Based on the `mrkainez` Telegram archive (Zenon Network public group, `t.me/zenonnetwork`), 882 posts exported 2025-09-14, spanning 2021-10-01 to 2024-12-07.*

**Epistemic labels used throughout:**
- **[LOCKED]**: directly supported by Kaine's own words, quoted or closely paraphrased.
- **[STRONG INFERENCE]**: the best explanation fitting multiple independent statements.
- **[WEAK INFERENCE]**: plausible but not well constrained by the archive.
- **[SPECULATION]**: an interesting possibility with insufficient evidence.
- **[VERIFIED EXTERNALLY]**: a claim I checked against a source outside the archive (used sparingly, and flagged as a deliberate departure from the "archive-only" method, never silently blended into the other four labels).

---

## 0. Method and Source Note

### What the archive actually is

The export contains 882 messages attributed to the Telegram handle `mrkainez`. Two distinct Telegram user IDs used that handle over the archive's life:

- **Account A** (`id 1992970673`, display name "Mr Kaine v2.0"): 876 of 882 messages, continuously active 2021-10-01 through 2023-07-18.
- **Account B** (`id 6023904619`, display name "Wen" / "mrkainezz"): 6 messages, first appearing 2023-06-20 (about four weeks *before* Account A's last message, i.e. an overlap, not a clean handoff) and continuing sporadically through 2024-12-07.

All six of Account B's messages are link-sharing or moderation asides (Zenon community Twitter/X announcements, and one comment: "Having this on main chat is a bad idea."). None of them touch btcd, merge-mining, PoW, Plasma, RandomX, or any term this report investigates. Every message this report relies on comes from Account A. I flag the identity discontinuity as a methodological fact, not as a claim about what happened to the account; I have no evidence in this archive about why the ID changed, so I don't speculate about it. For the remainder of this report, "Kaine" means Account A only.

### A structural limitation worth stating plainly

This is a single-user export. I have Kaine's own messages and, where `reply_to_id` points at another message *also* authored by him, I can reconstruct a self-contained thread. Where it points outside the export, I only have his half of the exchange. I've noted this wherever it materially affects a reading (mainly the merge-mining seed message and a handful of one-line replies).

### The one finding that should discipline everything below

Before getting into the ten questions, one pattern recurs often enough that it has to be treated as a governing fact rather than a footnote: Kaine repeatedly and explicitly resists being pinned to a single architecture. "A bridge is just one possibility" (Mar 9, 2022). "Look. There are many paths to achieve Bitcoin interoperability. Hyperspace will support all these efforts" (Mar 22, 2022). This is **[LOCKED]**, stated twice, two weeks apart, in direct response to people asking him to commit to one design. Any reconstruction that forces everything into one tidy pipeline is fighting the source material. I've tried to let that shape the conclusions rather than override it for the sake of a cleaner narrative.

---

## 1. Chronological Reconstruction

**Oct 2021 – early 2022.** Kaine's earliest messages are operational, not architectural: SwapDrop snapshot hashes, Alphanet migration instructions, Pillar deployment tutorials, spork-activation timing. He is answering questions about running nodes and moving tokens, not theorizing. This matters for how to read what follows: by the time he starts speculating about merge-mining and Bitcoin interoperability, he has an established track record of being the person who actually ships and coordinates releases, not an outside commentator.

**Feb 22, 2022.** The first btcd statement, unprompted elaboration in a Q&A: *"The idea of integrating btcd is to provide interoperability by having access to the state of Bitcoin's blockchain."* In the same conversation he adds, unprompted: *"Multi-chain wallet != interoperability,"* ruling out the shallow reading before anyone proposed it.

**Mar 9, 2022.** The seed. In a thread that starts about Sentinel-node design ("Sentinel nodes is the answer. How can you ensure they are running a full node with a public IP?"), Kaine pivots. He posts "Atomic swaps, DLCs" as a bare fragment, then a moment later replies to his *own* message: **"Merge mining.. Can we recycle PoW? Plasma.."** Three unfinished fragments, both trailing in ellipses. Nothing closes the thought that day; the thread simply stops. A parallel bookend ("Now back to work, we need to ship code and make new releases") appears twelve days later, closing a similar tangent in the March 21 cluster below. The tone here is consistent throughout: a working note dropped mid-conversation, not a proposal being pitched.

**Mar 21–22, 2022.** The richest single window in the archive, and the one that does the most disambiguating work. On "Happy NoM day," amid general celebration, Kaine posts several passages in quotation marks. Independently verified **[VERIFIED EXTERNALLY]**: this text is Satoshi Nakamoto's own December 9, 2010 Bitcointalk post "Re: BitDNS and Generalizing Bitcoin." It is the historical origin of what later became known as merged mining, written when "BitDNS" was Satoshi's hypothetical example of a companion chain, a full year before its ideas were actually implemented as Namecoin. Kaine posts this material, then his own words: *"Interoperability with Bitcoin can go beyond value transfer. Every detail must be taken into account."* Nine minutes later, replying to that: *"We can recycle Plasma generation via PoW for example. Or the other way around."* Five minutes after that, replying to *that*: **"You need to compute a PoW link in order to generate Plasma required by transactions on NoM. It may be possible to use the PoW links to merge mine Bitcoin; the other way around is to merge mine ZNN and create Plasma for Bitcoin feeless txs."** Then: "Now back to work, we need to ship code and make new releases." The tangent opens and closes inside a single celebratory chat session.

The next day, a different thread produces the closest thing in the archive to an actual diagram: **"btc -> atomic swap to zbtc -> (feeless transactions) zbtc -> atomic swap back to btc,"** glossed a message later as wanting to "bypass btc fees." In the same conversation, Kaine separately floats a non-atomic-swap alternative: *"Pillars can act as TSS signers and hold native btc vaults,"* immediately conceding *"Not quite decentralized. But still good enough."* The window closes with the "many paths" statement quoted in Section 0.

**Apr 15, 2022.** A plain architecture statement, not part of the merge-mining thread at all: *"Tx -> full nodes -> Pillars processing txs -> consensus -> appended to the block-lattice. Sentinels are not implemented yet. Plasma is used as network gas and can be generated either by locking (fusing) QSR or by generating PoW (there is a hard limit for Plasma via PoW)."* This is the baseline the rest of the archive builds on.

**Apr 29, 2022.** Confirms the PoW mechanism is not speculative: *"You can use the PoW links implementation from go-zenon (pow folder). It's about 2-3 times slower than the C implementation, but it works."* PoW-links already exist and ship in the codebase.

**Nov – Dec 2022.** Sentinels are clarified as not needing to compute PoW themselves: *"Sentinels won't need to compute PoW. Just process and relay information"* and *"Sentinels can outsource the PoW generation to other sources."* On Dec 9: *"PoW secures the block-lattice ledger by adding weight. This prevents some PoS attack vectors such as long range attacks."*

**Dec 20, 2022.** An impromptu design-principles session, roughly forty messages long, the single densest cluster in the archive. The through-line: L1 minimalism ("A simple and robust L1 with minimal features will always outperform over-engineered and complex designs"); Sybil-resistance taxonomy (PoW as "the most pure form," PoS as weaker but useful combined with classical consensus); PoW's two flavors ("ASIC-friendly and ASIC-resistant... I think it's safe to say SHA-256d and RandomX are the best candidates (reminder: we currently have SHA-3 as pow-links)"); a historical aside ("1 CPU = 1 vote was just an assumption of Satoshi. Hal clearly envisioned a widespread Bitcoin adoption at industrial scale."); and the dual-ledger principle stated directly: *"The idea behind a dual ledger system is to decouple consensus from chain weight… Bitcoin has consensus coupled with chain weight… NoM has consensus decoupled from chain weight (added when users are performing tx with PoW)."* Dynamic Plasma is named for the first time as "the next logical step," and the transaction cap is called "just an artificial limit."

**Mar 21, 2023.** A bridge/HTLC review day. *"The self-custody of funds is the most important aspect to be taken care of."* btcd reappears, now for a different job: *"And btcd for Schnorr signatures,"* inside a cluster about ChainSafe's adaptor-signature library, described (quoting the linked repo) as generalized "over any curve… based off the DLC spec."

**Mar 27–29, 2023.** Dynamic Plasma gets an explicit development plan: *"1 order txs (sorted by plasma) 2 replace the current PoW with RandomX 3 find a way to balance PoW and QSR fusing,"* followed by a front-running-resistance goal. In parallel, the consensus layer gets its own, separately-tracked treatment: the "meta-DAG" (soon tied to the Narwhal-Tusk protocol, cited by submission date) is described via a quoted technical definition and Kaine's own gloss, **"separated from the block-lattice."** The load-bearing sentence for this whole report appears here: **"The key is to balance both types of PoW, (again) as stated in the whitepaper. CPU PoW is important for txs. ASIC PoW can be merge-mined."** He explicitly frames this as a restatement of existing design ("again… as stated in the whitepaper"), not a new idea.

**Apr 5, 2023.** The cleanest single restatement: *"For the moment we only have ASIC friendly PoW, but once Dynamic/Adaptive Plasma is implemented, we will have the RandomX CPU friendly PoW"* and *"Replace SHA-3 with RandomX for Plasma. And ASIC friendly PoW can be obtained from merge-mining."* Immediately after: *"This is another idea.. if properly implemented and understood can reshape an entire industry."* That is Kaine's own assessment of the idea's significance.

**Apr 24, 2023.** Extension-chains appear, answering a different but adjacent question: *"How to deploy smart contracts without touching the L1? Using an extension-chain. Basically a type of sidechain that can run in parallel and have a dual-pegging mechanism."* Compared to Liquid Network; validator set "can be configured to run directly on Pillars."

**May 6 – May 29, 2023.** Sequencing solidifies across three separate statements over six weeks: interop solutions first, then Dynamic Plasma, then extension chains, which "can work in parallel" afterward. The canonical, final-form definition: *"Dynamic Plasma has 2 implementation steps: 1. Order transactions by Plasma amount and remove the cap. 2. Switch to CPU friendly PoW (RandomX)."* A May 9 aside adds a pricing dimension not seen elsewhere: *"Bitcoin fees: satoshi/vbyte (storage). Ethereum fees: wei/computational step (processing). Plasma should consider both."* The May 29 capstone: *"Dynamic Plasma (core upgrade) - we need to remove the hardcoded cap to provide **a robust feeless mechanism**."*

**Jul 11, 2023.** A single link, no commentary: `nakamotoinstitute.org/finney/rpow/index.html`, Hal Finney's Reusable Proof of Work. Posted as a reply to a message not present in this export, in a short thread otherwise about minimal-L1 data structures (ZAS/ZTS, a verkle-trees documentation link). Tempting to read as a direct callback to "can we recycle PoW" from sixteen months earlier; the surrounding, visible context is about state-proof minimalism, not hashrate-recycling, and the connecting message is missing. I flag it in Section 5 rather than resolve it here.

**Jul 18, 2023.** Kaine's last messages under this identity: continued PTLC/HTLC review, a Szabo-flavored aphorism ("Trusted third parties are security holes"), a PoW analogy applied to developer reputation ("hard to create, but easy to verify"), and a closing line: "Hope everything is clear now."

---

## 2. Process of Elimination: The Ten Questions

### Q1. What did Kaine actually mean by integrating btcd?

Two **[LOCKED]** statements anchor this, sixteen months apart: "interoperability by having access to the state of Bitcoin's blockchain" (Feb 2022), and "btcd for Schnorr signatures," embedded in a discussion of an adaptor-signature library generalized "over any curve… based off the DLC spec" (Mar 2023).

Testing the prompt's candidate readings against the archive:

- **Custody**: eliminated. Custody is a separately named concern with its own vocabulary. "The self-custody of funds is the most important aspect to be taken care of" and "Pillars can act as TSS signers and hold native btc vaults" (explicitly conceded as "not quite decentralized") never once appear alongside btcd. Custody and state-access are handled as two different problems.
- **Bridge** (the actual product, "Multiverse Bridge"/Orbital Program): eliminated on vocabulary grounds. That cluster uses TSS, HTLC, sporks, Orbital Program, and liquidity-pool language over two dozen times; btcd never appears inside it.
- **"Authorization layer"**: eliminated immediately. The string "authoriz" appears zero times anywhere in 882 messages.
- **Settlement**: weak. Kaine discusses settlement as a general concept (Lightning's on-chain settlement, Bitcoin's probabilistic finality) but never ties it to btcd specifically.
- **SPV / light client**: neither term ever appears verbatim, but "access to the state of Bitcoin's blockchain" is functionally what a state-verification component does. **[STRONG INFERENCE]**, not [LOCKED], precisely because the label itself is never used.
- **Bitcoin state verification**: **[LOCKED]**, this is the literal wording.
- **Cryptographic-primitive reuse**: **[LOCKED]** from the Schnorr statement; reinforced by a separate, earlier aside about wanting "an embedded with Schnorr signatures to enable DLC for Sentinels."

**Surviving interpretation**: btcd is plumbing, not a product. It supplies two things Kaine names explicitly and never conflates with each other or with custody: read access to Bitcoin's chain state, and reuse of Bitcoin-native cryptography (Schnorr) for building compatible contracts elsewhere (HTLC, PTLC, DLC, adaptor signatures). One piece of background worth flagging as outside the archive: btcd is Conformal Systems' Go-language full-node Bitcoin implementation, and go-zenon is also written in Go. A same-language dependency is an ordinary engineering reason to prefer btcd over Bitcoin Core's C++ codebase, but Kaine never states this reasoning himself, so it stays as context, not evidence.

### Q2. Why did Kaine repeatedly point people toward BitDNS?

The quoted passage is, **[VERIFIED EXTERNALLY]**, Satoshi Nakamoto's own December 2010 explanation of merged mining, using BitDNS as the hypothetical example, a year before those ideas were actually implemented as Namecoin.

Falsifying the literal reading first: if Kaine were proposing BitDNS-the-application (domain-name service) for Zenon, we'd expect at least one mention of domains, DNS, or naming anywhere in the other 881 messages. There are none. The topic is not BitDNS-as-a-product; it's BitDNS-as-Satoshi's-thought-experiment-for-explaining-merged-mining.

Why not cite Namecoin directly, the actual working implementation? The archive doesn't say; Namecoin is never mentioned. **[WEAK INFERENCE]**: this is consistent with a pattern that shows up at least twice more in the archive (two other verbatim historical Bitcoin-community quotes, on unrelated topics), of reaching for primary-source, principle-level material over case studies of derivative implementations.

Why not IBC or Lightning? Both are eliminated as candidates for "why BitDNS," for different reasons. IBC never appears (0 mentions); it isn't a live comparison in Kaine's mind here. Lightning is discussed, but explicitly as a *contrast*: locked funds, payment channels, on-chain settlement, "avoiding on-chain fees" through a completely different mechanism than merged mining. He isn't confusing the two; he's using LN elsewhere in the same window as the thing merge-mining and atomic swaps are alternatives *to*.

**Architectural lesson Kaine draws**: independent chains can share raw proof-of-work with zero coordination overhead and zero pooling of state, tokens, or trust. That lesson maps directly onto his own words nine minutes later: "the other way around is to merge mine ZNN."

### Q3. "Merge mining.. Can we recycle PoW? Plasma.."

Taking the fragments in order:

**"Merge mining"**: the mechanism, confirmed by the BitDNS-quote context twelve days later and every 2023 restatement: literal Bitcoin merged mining, where solving Bitcoin's PoW puzzle simultaneously satisfies a second network's PoW requirement.

**"Can we recycle PoW?"**, ranked:
1. **Resource generation**: **[LOCKED]**. Confirmed nine minutes later in the same conversation: "We can recycle Plasma generation via PoW."
2. **Security / hashrate borrowing**: **[LOCKED]** via the 2023 statements ("ASIC friendly PoW can be obtained from merge-mining") and the "chain weight… added when users are performing tx with PoW" framing.
3. **Proof reuse in the cryptographic sense** (the same work satisfying two puzzles at once via a shared Merkle root): **[STRONG INFERENCE]**. This is how merged mining mechanically works, per the verified Satoshi source, but Kaine never spells out the Merkle-tree mechanics himself anywhere in this archive.
4. **Difficulty recycling**: no support; never mentioned.
5. **Plasma creation**: not a separate item; it is item 1 under another name.

**"Plasma.."**: **[LOCKED]** as the generated resource, "network gas," confirmed in the April 2022 baseline (locking QSR or generating PoW) and every subsequent Dynamic Plasma statement.

**Reading the whole fragment**: a three-word compression of the exact architecture spelled out fourteen minutes later in his own hand. The trailing ellipses on both clauses read as a working note left open, not a proposal being pitched.

### Q4. Why did he separate CPU PoW and ASIC PoW?

**[LOCKED]**, Dec 20, 2022: "you need both: ASIC-friendly for security and ASIC-resistant for participation." The two flavors optimize for opposite goals: ASIC-friendly converts energy as efficiently as possible (his description of Bitcoin's actual purpose); ASIC-resistant keeps mining broadly accessible on ordinary hardware.

Falsifying "why not just switch everything to RandomX": directly falsified by his own words. RandomX is scoped, every time it appears, to the Plasma/participation half only ("Switch to CPU friendly PoW (RandomX)" as one of two Dynamic Plasma steps). It is never proposed as a replacement for the security half. Instead, the security half is proposed to be sourced externally, via Bitcoin merge-mining, rather than run as a native algorithm at all. The two lanes are not symmetric: CPU/RandomX is native and tied to Plasma; ASIC/SHA-256d is imported and tied to chain weight, without NoM needing to bootstrap its own ASIC ecosystem.

**[STRONG INFERENCE]**, historical framing: the "1 CPU = 1 vote was just an assumption of Satoshi. Hal clearly envisioned a widespread Bitcoin adoption at industrial scale" aside, posted in the same design session, reads as Kaine reconciling both historical visions rather than choosing between them: Satoshi's CPU-democratic ideal survives natively via RandomX/Plasma, and Hal's foreseen industrial-ASIC reality is honored by importing it rather than fighting it.

### Q5. Why did he say "CPU PoW is important for txs"?

**[LOCKED]**, the clearest single sentence in the archive for this purpose, and the reasoning chain behind it is entirely reconstructable from his own separately-stated words:

- "Tx -> full nodes -> Pillars processing txs -> consensus -> appended to the block-lattice" (Apr 2022): Pillars and consensus are a downstream stage from wherever PoW actually sits.
- "Plasma is used as network gas and can be generated either by locking (fusing) QSR or by generating PoW" (Apr 2022): PoW's output is the tx-admission resource, an alternative to QSR-fusion, not a role in ordering or voting.
- "NoM has consensus decoupled from chain weight (added when users are performing tx with PoW)" (Dec 2022): chain weight, not block production or vote-counting, is what tx-level PoW contributes.
- "meta-DAG for consensus (separated from the block-lattice)" (Apr 2023): consensus is an explicitly different subsystem from the block-lattice where tx-level PoW and Plasma live.
- "It's limited to the transaction layer at the moment" (Mar 2023): PoW's scope, stated directly and tersely.

**Eliminating the alternatives the prompt raises**: not consensus (explicitly decoupled, repeatedly, in his own words); not blocks or momentum production (never once linked to PoW anywhere in the archive; the one hard cap on momentum size is discussed as a wholly unrelated topic); not Pillars themselves (Pillars process transactions and run consensus, but don't compute PoW; the Sentinel "outsource the PoW generation" comment shows PoW computation is treated as separable from any specific node role).

Why this makes sense on his own terms: pure PoS is called out, in the same design session, as economically and socially flawed and as opening "long range attack" vectors; a PoW-based weight requirement is his stated defense against exactly that ("PoW secures the block-lattice ledger by adding weight. This prevents some PoS attack vectors such as long range attacks."). That defense is only needed at the point new weight is added to the ledger, i.e. at the transaction layer, not at the separately-BFT-secured ordering layer.

### Q6. What is Dynamic Plasma actually trying to become?

Using Kaine's own language rather than the prompt's suggested labels, several of which never appear verbatim ("economic scheduler" and "security layer" are not his phrasing, so I don't force them):

- **[LOCKED]**, most direct, chronologically final characterization: "a robust feeless mechanism" (May 2023), reached by removing the hardcoded PoW-Plasma cap and ordering transactions by Plasma amount.
- **[LOCKED]**, earlier and repeated: throughput ("Increased throughput via dynamic Plasma"; named "the next logical step" right after noting the network is artificially capped).
- **[LOCKED]**: front-running resistance ("limiting front-running").
- **[LOCKED]**: the underlying algorithm swap, SHA-3 pow-links replaced by RandomX.
- **Spam resistance / resource market**: never his exact words, but functionally the closest single category for "network gas," "hard limit… removed," and "order transactions by Plasma amount." **[STRONG INFERENCE]** to name it that; he doesn't use "spam resistance" or "fee market" himself.
- **Rejected**: "execution fuel" in the smart-contract-gas sense. Plasma predates and is orthogonal to the later extension-chain proposals, which get their own, separate gas-like economics on separate VMs ("EVM, WASM, AMMs, etc will be available on the extension chains"). Plasma gates transaction admission on the existing minimal L1; it doesn't fuel contract execution.

**Endpoint, synthesized strictly from his own words**: an uncapped, RandomX-secured, Plasma-amount-ordered transaction-admission market, replacing NoM's own artificial throughput ceiling, aimed explicitly at feeless transactions, with a possible future pricing dimension (the May 9 aside about accounting for both storage-like and compute-like costs) that is mentioned once and never developed further in this archive. Its ASIC/security counterpart is sourced externally via Bitcoin merge-mining rather than built natively.

### Q7. Was Kaine redesigning NoM, or building something beside it?

The best-evidenced question of the ten. **[LOCKED]**, repeatedly, across five independent statements spanning sixteen months, the block-lattice/transaction layer and the consensus/meta-DAG layer are described as architecturally separate: "The dual-ledger has a very important property: separate consensus from other business logic" (Nov 2022); "decouple consensus from chain weight" (Dec 2022); "meta-DAG for consensus (separated from the block-lattice)" (Apr 2023); "The block-lattice is just for mapping accounts. The ultimate decision is still made by the consensus protocol" (Nov 2022); and the framing of the whole PoW-balance effort as "a bonus feature" on an existing component (Apr 2023) rather than a redesign of it.

**Falsification check**: if this were a consensus redesign, PoW/merge-mining vocabulary should show up inside the meta-DAG/Narwhal-Tusk conversations. It doesn't. Those threads (Mar 28–29, Apr 5, 2023) discuss BFT voting, garbage-collected DAG rounds, and shared randomness with zero mention of PoW, merge-mining, or Plasma, and the reverse holds too.

**Surviving interpretation**: Kaine is extending an already-existing, already-modular subsystem (PoW-links generating Plasma, live in go-zenon since at least April 2022) with a new algorithm and a removed cap, while treating consensus as a parallel, independently-evolving track. "Redesigning NoM" is the wrong frame; he is redesigning one clearly-bounded subsystem of a network he repeatedly describes as already modular.

### Q8. Where does btcd fit relative to merge-mining?

Direct textual co-occurrence is thin and should be reported as such rather than papered over: btcd and "merge mining" never appear in the same message. The honest answer comes from relative role and sequencing, not a single locked quote.

**[STRONG INFERENCE]**, by function: btcd's two stated jobs (state access, Feb 2022; Schnorr signatures, Mar 2023) are prerequisites for *verifying and constructing* Bitcoin-native transactions and contracts (HTLC, PTLC, DLC, adaptor signatures). Merged mining is a different problem entirely, about proof-of-work being simultaneously valid on two chains, and per the verified Satoshi source, requires the two networks to need "no coordination" at all, no state-reading included.

**Sequencing evidence**: across three separate 2023 statements (Mar 29, Apr 14, May 29), Kaine places "interop solutions" (the bridge/HTLC/PTLC cluster btcd's Schnorr role belongs to) ahead of Dynamic Plasma/merge-mining work in his own prioritization, though this reads as engineering-attention sequencing ("let's implement X first," "we can focus on Y next") rather than a stated hard technical dependency.

**Surviving interpretation**: btcd sits inside the interoperability/verification cluster, prioritized ahead of and functionally independent from the merge-mining/Plasma cluster, not a component inside it.

### Q9. Could these ideas describe a future execution architecture?

Addressing the prompt's own four-part chain directly (btcd = knowledge, merge-mining = recycled work, RandomX = CPU participation, Dynamic Plasma = resource pricing), while keeping faith with Kaine's own "many paths" framing rather than forcing a single answer, per the prompt's explicit instruction not to.

**[LOCKED]**, the closest thing to an actual sketch in his own hand: "btc -> atomic swap to zbtc -> (feeless transactions) zbtc -> atomic swap back to btc." BTC enters via atomic swap, not custody and not merge-mining; transacts feeless on the NoM side (Plasma-gated, later RandomX-secured, uncapped); exits via atomic swap. Merge-mining is offered, in the same conversation, as one possible source of the work funding the feeless side ("merge mine ZNN and create Plasma for Bitcoin feeless txs"), but Kaine never draws that connecting arrow explicitly. Treating merge-mining output as *directly* feeding the zbtc flow is **[WEAK INFERENCE]**: plausible, thematically adjacent, unconfirmed.

**What does emerge, without overreaching**: a Bitcoin-adjacent transaction environment where BTC moves in and out via primitives that need no custody or bridge trust (atomic swaps, HTLCs, later PTLCs/DLCs, all needing btcd-class access to construct and verify), settling on NoM's own minimal, consensus-decoupled ledger using a resource (Plasma) generated either by locking QSR or by computing PoW, where the PoW route is itself split so its CPU/participation half runs natively (RandomX) and its ASIC/security half is imported rather than built (Bitcoin merge-mining), addressed as one bounded subsystem alongside, not instead of, NoM's existing consensus and its later, separately-tracked extension-chain layer.

I want to flag directly, per the prompt's own ground rules, that this reads less like a single "execution architecture" in the smart-contract-VM sense and more like a resource-and-settlement layer other execution environments could plug into later. The archive's own vocabulary for the VM/execution layer is "extension chains," introduced over a year later with its own distinct rationale and no textual link back to merge-mining or btcd. I'm declining to force those two threads together, because the evidence doesn't support it.

### Q10. What ideas was Kaine decades early on?

This is the weakest-evidenced section of the ten, and should be read that way: it requires comparing the archive against the wider industry, which the archive-only method doesn't support well, and I have not done an exhaustive literature search.

**Already common, even by 2022**: PoW/PoS hybrid designs; general "modularity" rhetoric; atomic swaps (roughly eight years old by 2022, and Kaine says as much himself: "Decred and Litecoin had the first cross-chain atomic swap"); HTLCs, standard in Lightning by then.

**Uncommon at the time**: re-deriving merged mining from Satoshi's *original* 2010 text, rather than citing an existing merge-mined coin, as the template for a resource-*generation* mechanism rather than a chain-*security* mechanism. Most 2022-era merge-mining discussion in the wider industry (Namecoin, Rootstock, Syscoin) frames it as securing a second chain's own blocks, not as bootstrapping an internal, non-monetary metered resource for a chain that already has independent BFT consensus.

**[SPECULATION]**, flagged as such: the specific decomposition, ASIC PoW imported via merge-mining for chain weight, CPU PoW native and tied to a per-transaction resource rather than to consensus, may be an uncommon framing. I have not verified this against the broader merge-mining literature comprehensively, so this should be read as a hypothesis, not a priority claim.

**Still not widely explored, as of Kaine's own 2023 horizon and arguably today**: using merge-mining's recycled hashpower specifically to subsidize feeless transactions on an already-BFT-secured, otherwise-independent ledger, as opposed to using merge-mining for a second chain's own block-level security. This is the single most "decades early" candidate in the archive, but it is my own synthesis across scattered statements, not something Kaine states about himself anywhere, and it should be weighted accordingly.

---

## 3. Five Candidate Architectures

Per the brief, the point of this section is the eliminations, not the survivor. Each candidate is graded on description, supporting evidence, contradicting evidence, missing evidence, technical feasibility, historical analogues, and a probability estimate.

### Candidate A: Merge-Mined Security Import

**Description**: NoM's chain-weight is bootstrapped by importing Bitcoin's ASIC hashrate through merge-mining; RandomX/CPU-PoW is a separate, decentralization-preserving participation channel; Plasma is the ticket tying transaction admission to both.

**Supporting evidence**: nearly all of Q3 through Q6. This candidate is less a hypothesis to test than a restatement of what's already [LOCKED].

**Contradicting evidence**: none direct.

**Missing evidence**: the actual mechanism. No message anywhere describes a merged-mining header format, an AuxPoW-style structure, a shared Merkle root, or how a Bitcoin miner would even discover NoM to merge-mine it. This is a real, material gap, not a nitpick.

**Technical feasibility**: high in principle (merge-mining is a solved, working pattern elsewhere); the missing plumbing above is the actual risk.

**Similar historical systems**: Namecoin (BTC merge-mining, 2011), Rootstock, Syscoin.

**Probability: 70%.** Best-supported single reading; under-specified at the implementation level.

### Candidate B: Bitcoin-Native Feeless Payment Channel

**Description**: the zbtc atomic-swap flow is the actual product; merge-mining is a nice-to-have, floated the day before, not integrated into the diagram itself.

**Supporting evidence**: the diagram itself, "bypass btc fees," the self-custody-first framing, and a preference for atomic swaps and scriptless scripts over the older HTLC-only approach described in the quoted historical material.

**Contradicting evidence**: the diagram message never names merge-mining, RandomX, or Plasma. The link to Plasma is an inference (Plasma is elsewhere described as NoM's only stated feeless mechanism), not a stated fact in that message.

**Missing evidence**: no message directly states "the zbtc flow uses Plasma."

**Technical feasibility**: high, arguably the highest of the five. Atomic swaps between BTC and a Zenon-side asset are cryptographically well understood (HTLC/PTLC-based) and closest operationally to Zenon's actual, shipped bridge work.

**Similar systems**: contrasted, not matched, against Lightning's channel model (locked funds plus on-chain settlement, a different mechanism from atomic-swap in/out).

**Probability: 55%.** Strong support for the shape of the flow; weaker on whether merge-mining is load-bearing inside it, versus merely adjacent to it.

**Verdict: not eliminated, but absorbed.** This candidate is real and well evidenced. It's best understood as one concrete application of Candidate A's resource layer, not an independent competing architecture, so it is not falsified so much as folded in.

### Candidate C: Unified Bitcoin-Recycling Execution Layer

**Description**: the prompt's own Question 9 framing taken literally, btcd (knowledge) plus merge-mining (recycled work) plus RandomX (CPU participation) plus Dynamic Plasma (pricing), combined into one coherent new execution platform superseding NoM's existing design.

**Supporting evidence**: superficial. All four pieces individually appear in the archive.

**Contradicting evidence**: strong, and this is the candidate the evidence works hardest against. No message ever places all four components in one explanatory sentence or diagram. btcd and "merge mining" never co-occur anywhere. The meta-DAG/consensus material and the PoW/Plasma material are explicitly and repeatedly kept separate (Q7). "There are many paths" and "a bridge is just one possibility" directly undercut the premise of one unified architecture superseding the rest.

**Missing evidence**: total. There is no synthesis statement anywhere across sixteen months of messages.

**Technical feasibility**: moot given the evidentiary problem; as a pure hypothetical, four largely independent primitives fused into one system would carry real integration and attack-surface costs.

**Similar systems**: this resembles the kind of hindsight-driven "grand unified roadmap" outside observers sometimes narrate onto other L1s after the fact. Naming it and eliminating it explicitly matters, because it's the most tempting misreading of this archive: a researcher who reads only Question 9's four terms without the intervening sixteen months of context would land here.

**Probability: 10%.** Named to be falsified; the falsification is one of the more important results in this report.

### Candidate D: Sentinel-Fed PoW Marketplace

**Description**: Sentinels "outsource the PoW generation to other sources," hinting at a PoW-as-a-service model, possibly tied to merge-mined work being allocated to whichever subsystem needs chain-weight at a given moment.

**Supporting evidence**: "Sentinels can outsource the PoW generation to other sources" and "Sentinels can also serve as protocol level oracles," both Dec 2022.

**Contradicting evidence**: this idea appears in exactly one short exchange and is never revisited, developed, or connected to the merge-mining/Plasma cluster in any of the remaining seven months of the archive.

**Missing evidence**: heavy. No description of what "other sources" means, no pricing mechanism, no stated connection to merge-mining.

**Technical feasibility**: unassessable given how underspecified it is.

**Similar systems**: generic PoW-outsourcing or hash-marketplace models exist in the wider industry, but Kaine draws no such comparison himself.

**Probability: 15%.** A real but minor, undeveloped side branch rather than a competing main architecture, worth naming precisely because a less careful researcher would either miss it entirely or over-weight it into something it isn't.

### Candidate E: Dual-Track Modular Substrate

**Description**: not a specific feature but a cross-domain design pattern visible in Kaine's writing: every subsystem he touches (consensus/ledger, PoW/Plasma, Bitcoin interop, smart contracts) gets kept modular and linked through a narrow, well-defined interface rather than fused. "Recycle PoW" is this pattern's specific instance applied to hashpower.

**Supporting evidence**: the recurring separations found independently at least four times (consensus/chain-weight, block-lattice/meta-DAG, L1/extension-chain, verification-via-btcd versus custody-via-TSS-vaults), plus the explicit design-philosophy statement, "A simple and robust L1 with minimal features will always outperform over-engineered and complex designs."

**Contradicting evidence**: this is a structural, higher-order claim, harder to falsify directly than a specific proposal, which is itself worth naming as a limitation. The check against over-reading it: it has to show up independently in at least three unrelated subsystems to count, which it does (consensus/ledger, custody/verification, L1/smart-contracts), rather than being pulled from a single example.

**Missing evidence**: Kaine never states this as a named principle about himself; it's a pattern I'm naming across his statements, not a claim he makes.

**Technical feasibility**: not applicable in the implementable sense; it's a descriptive regularity, not a proposal.

**Similar systems**: resembles the "modular blockchain" design philosophy that became common mainstream framing from roughly 2023 onward. Worth flagging carefully that Kaine's 2022 statements predate that framing becoming standard vocabulary, without claiming he originated it.

**Probability: 80%** as a descriptive finding about how to read everything else in this report. "Probability" is an odd frame for a meta-pattern rather than a specific technical proposal, and I'd rather say that plainly than force a false precision.

### Elimination Summary

| Candidate | Verdict | Probability |
|---|---|---|
| A. Merge-Mined Security Import | Survives; best single technical reading | 70% |
| B. Bitcoin-Native Feeless Payment Channel | Survives, but absorbed into A | 55% |
| C. Unified Bitcoin-Recycling Execution Layer | Eliminated; the evidence actively contradicts it | 10% |
| D. Sentinel-Fed PoW Marketplace | Survives as a minor, undeveloped side thread | 15% |
| E. Dual-Track Modular Substrate | Survives as the governing pattern behind A, B, and the rest | 80% |


## 4. The Strongest Surviving Interpretation

NoM already has, per Kaine's own repeated framing and per the whitepaper he cites but never quotes at length, a bounded, separately-secured resource-and-weight subsystem: Plasma, generated either by fusing QSR or by computing PoW, sitting alongside, not inside, its BFT/meta-DAG consensus. Kaine's 2022-2023 messages describe evolving that one subsystem through two coordinated moves.

First, replace its native PoW algorithm (SHA-3) with RandomX, keeping the participation half CPU-accessible and tied directly to per-transaction Plasma generation, uncapped, ordered by Plasma amount, aimed explicitly at "a robust feeless mechanism." Second, stop trying to natively run the security half of that balance at all, and instead import it by merge-mining with Bitcoin, recycling Bitcoin's already-existing ASIC hashrate as NoM's chain-weight contribution instead of bootstrapping a competing ASIC ecosystem. Both moves are explicitly framed as a "bonus feature" on an existing PoW component, not a consensus redesign.

Separately, and not because the archive claims they are the same project, Kaine explores Bitcoin-native, non-custodial value transfer via atomic swaps (the zbtc flow) and, with an explicit caveat about reduced decentralization, a Pillar-operated TSS-custody alternative. Both would benefit from, but are not defined by, the btcd-supplied state-access and Schnorr-signature capability he describes independently.

The throughline across all of it, borne out independently in at least three unrelated subsystems (consensus versus ledger, custody versus verification, base layer versus smart contracts), is a preference for narrow, well-defined links between minimal, separately-secured components over any single fused system. That is also why "five candidate architectures, pick one" is somewhat the wrong shape of question to ask of this material. Kaine's own words, "a bridge is just one possibility," "there are many paths… Hyperspace will support all these efforts," predict a plural outcome rather than resist it.

## 5. What Future Researchers Would Probably Miss

**The two-account identity switch, and its clean resolution.** Easy to miss entirely if the archive isn't checked for user-ID consistency; equally easy to over-read into something sinister if checked carelessly. The resolution here is mundane and important: zero technical contamination. Every substantive claim in this report traces to one continuous identity.

**The Satoshi provenance of the BitDNS quote.** Without recognizing the quotation marks and checking the source, a researcher could misattribute Kaine's own inventiveness to material he was actually curating and teaching from, and would likely miss *why* he reached for the 2010 original over Namecoin, IBC, or Lightning: the point was the invariant (shared work, zero coordination), not any particular implementation.

**The July 2023 RPOW link.** Genuinely tantalizing, genuinely ambiguous. It doesn't contain the word "PoW" itself, just a URL, so it's easy to scroll past entirely; it's equally easy to overweight into a confirmed callback to "can we recycle PoW" that the surrounding, visible context (minimal-L1 data structures) doesn't actually support, given the missing parent message.

**"It's limited to the transaction layer at the moment."** Five words, replying to a message not in this export, dated March 29, 2023. Easy to skip past entirely because it's so terse. Arguably the single most direct confirmation in the whole archive of where PoW's scope stops, precisely because its brevity makes it look unimportant.

**The Sentinel PoW-outsourcing aside.** A real, distinct idea (Candidate D) that never got developed and is easy to lose inside the much louder RandomX/merge-mining conversation, which is exactly why it's worth naming on its own rather than folding it silently into the main thread.

**The modular-separation pattern itself (Candidate E).** Invisible in any single quote; only visible by reading the whole archive and noticing the same move (separate the concerns, link them narrowly) recur in at least four unrelated places. A researcher stopping at any one cluster would miss that it's a pattern at all, rather than four unrelated design choices.

**The sequencing statements, as a set.** Individually unremarkable ("let's do X first"), but taken together (three separate statements over six weeks, all agreeing on the same order) they're the best evidence that Kaine thought of interop, Plasma, and extension chains as separate workstreams with a real ordering, not simultaneous facets of one master plan conceived all at once.

## 6. If Kaine Could Read This Report

**Strongly supported, would likely recognize without correction**: the CPU-PoW-for-transactions / ASIC-PoW-via-merge-mining split; Dynamic Plasma as an uncapped, RandomX-secured, Plasma-ordered feeless mechanism; the consensus/block-lattice separation; ruling out custody, the bridge product, and "authorization layer" as readings of btcd.

**Plausible inferences he might accept, but likely wouldn't have phrased this way himself**: the Satoshi/Hal Finney reconciliation reading of the CPU/ASIC split; the "modular substrate" pattern named explicitly across domains; treating the zbtc atomic-swap flow and the merge-mining/Plasma idea as related but distinct rather than one pipeline.

**Likely to get a "no, that's not what I meant"**: Candidate C, the unified four-piece execution architecture, is close to exactly the kind of over-integration his own words push back against. Any attempt to definitively resolve the July 2023 RPOW link as a confirmed callback to the March 2022 "recycle PoW" note would likely get corrected, given how thin that specific connection actually is once the missing parent message is accounted for. And probably any framing of this material as a finished architecture at all, rather than a running, evolving set of engineering notes: his own words, in real time, on March 27, 2023, are "... Dynamic Plasma. What's missing?" That is Kaine treating the thing as unfinished while writing it. This report shouldn't paper over that with more confidence than the source material earns.

---

## Appendix: Primary Source Index

Every row below is a message authored by Kaine (Telegram ID `1992970673`), quoted or referenced in this report. Dates and links are pulled directly from the export for independent verification.

| Date | Message ID | What it shows | Link |
|---|---|---|---|
| 2022-02-22 | 221917 | btcd = interoperability via access to Bitcoin state | [link](https://t.me/zenonnetwork/221917) |
| 2022-02-22 | 221918 | "Multi-chain wallet != interoperability" | [link](https://t.me/zenonnetwork/221918) |
| 2022-03-09 | 225381 | "A bridge is just one possibility" | [link](https://t.me/zenonnetwork/225381) |
| 2022-03-09 | 225389 | "Atomic swaps, DLCs" (seed context) | [link](https://t.me/zenonnetwork/225389) |
| 2022-03-09 | 225395 | "Merge mining.. Can we recycle PoW? Plasma.." (the seed) | [link](https://t.me/zenonnetwork/225395) |
| 2022-03-09 | 225398 | Decred/Litecoin first atomic swap; HTLC state of the art | [link](https://t.me/zenonnetwork/225398) |
| 2022-03-21 | 228634 | Quoted passage (verified: Satoshi, BitDNS/merged mining, Dec 2010) | [link](https://t.me/zenonnetwork/228634) |
| 2022-03-21 | 228647 | Quoted: merge-mining incentive (reward for same work) | [link](https://t.me/zenonnetwork/228647) |
| 2022-03-21 | 228652 | Quoted: risk-free two-party trade (atomic-swap logic) | [link](https://t.me/zenonnetwork/228652) |
| 2022-03-21 | 228663 | Quoted: avoiding CPU power fragmentation | [link](https://t.me/zenonnetwork/228663) |
| 2022-03-21 | 228668 | "Interoperability with Bitcoin can go beyond value transfer" | [link](https://t.me/zenonnetwork/228668) |
| 2022-03-21 | 228712 | "We can recycle Plasma generation via PoW... Or the other way around" | [link](https://t.me/zenonnetwork/228712) |
| 2022-03-21 | 228726 | PoW link defined; merge-mine Bitcoin / merge-mine ZNN for feeless BTC txs | [link](https://t.me/zenonnetwork/228726) |
| 2022-03-21 | 228732 | "Now back to work" (closes the Mar 21 tangent) | [link](https://t.me/zenonnetwork/228732) |
| 2022-03-22 | 229157 | "btc -> atomic swap to zbtc -> (feeless) -> atomic swap back to btc" | [link](https://t.me/zenonnetwork/229157) |
| 2022-03-22 | 229166 | "You basically want to bypass btc fees" | [link](https://t.me/zenonnetwork/229166) |
| 2022-03-22 | 229211 | Lightning Network settlement model, contrasted | [link](https://t.me/zenonnetwork/229211) |
| 2022-03-22 | 229232 | "Not quite decentralized. But still good enough" | [link](https://t.me/zenonnetwork/229232) |
| 2022-03-22 | 229234 | "Pillars can act as TSS signers and hold native btc vaults" | [link](https://t.me/zenonnetwork/229234) |
| 2022-03-22 | 229240 | "There are many paths to achieve Bitcoin interoperability" | [link](https://t.me/zenonnetwork/229240) |
| 2022-04-15 | 234871 | Baseline: Tx -> full nodes -> Pillars -> consensus -> block-lattice; Plasma = gas via QSR or PoW, hard cap noted | [link](https://t.me/zenonnetwork/234871) |
| 2022-04-29 | 238620 | PoW-links already implemented in go-zenon (pow folder) | [link](https://t.me/zenonnetwork/238620) |
| 2022-11-03 | 259913 | "The block-lattice is just for mapping accounts" | [link](https://t.me/zenonnetwork/259913) |
| 2022-11-03 | 259914 | "The dual-ledger... separate consensus from other business logic" | [link](https://t.me/zenonnetwork/259914) |
| 2022-12-09 | 265288 | PoW secures block-lattice by adding weight; prevents PoS long-range attacks | [link](https://t.me/zenonnetwork/265288) |
| 2022-12-09 | 265294 | "Sentinels won't need to compute PoW" | [link](https://t.me/zenonnetwork/265294) |
| 2022-12-10 | 265526 | "Sentinels can outsource the PoW generation to other sources" | [link](https://t.me/zenonnetwork/265526) |
| 2022-12-20 | 267372 | "The whitepaper points out two sources of PoW" | [link](https://t.me/zenonnetwork/267372) |
| 2022-12-20 | 267374 | "A simple and robust L1 with minimal features will always outperform..." | [link](https://t.me/zenonnetwork/267374) |
| 2022-12-20 | 267377 | "PoW is the most pure form of Sybil-resistance" | [link](https://t.me/zenonnetwork/267377) |
| 2022-12-20 | 267379 | PoW's two flavors: ASIC-friendly vs ASIC-resistant | [link](https://t.me/zenonnetwork/267379) |
| 2022-12-20 | 267383 | "1 CPU = 1 vote was just an assumption of Satoshi. Hal clearly envisioned..." | [link](https://t.me/zenonnetwork/267383) |
| 2022-12-20 | 267387 | "The idea behind a dual ledger system is to decouple consensus from chain weight" | [link](https://t.me/zenonnetwork/267387) |
| 2022-12-20 | 267388 | Bitcoin: consensus coupled with chain weight | [link](https://t.me/zenonnetwork/267388) |
| 2022-12-20 | 267389 | NoM: consensus decoupled from chain weight (added via tx PoW) | [link](https://t.me/zenonnetwork/267389) |
| 2022-12-20 | 267396 | Users pay with Plasma, adding weight, "effectively securing" the ledger | [link](https://t.me/zenonnetwork/267396) |
| 2022-12-20 | 267406 | "SHA-256d and RandomX are the best candidates (...we currently have SHA-3 as pow-links)" | [link](https://t.me/zenonnetwork/267406) |
| 2022-12-20 | 267426 | "dynamic Plasma is the next logical step" | [link](https://t.me/zenonnetwork/267426) |
| 2022-12-20 | 267431 | "this is just an artificial limit" (the tx cap) | [link](https://t.me/zenonnetwork/267431) |
| 2023-03-21 | 274657 | "The self-custody of funds is the most important aspect" | [link](https://t.me/zenonnetwork/274657) |
| 2023-03-21 | 274660 | "And btcd for Schnorr signatures" | [link](https://t.me/zenonnetwork/274660) |
| 2023-03-21 | 274663 | Link: ChainSafe go-signature-adaptor | [link](https://t.me/zenonnetwork/274663) |
| 2023-03-21 | 274664 | Quoted: adaptor sigs "generalized...over any curve...based off the DLC spec" | [link](https://t.me/zenonnetwork/274664) |
| 2023-03-27 | 275773 | Dynamic Plasma 3-stage plan (order txs / RandomX / balance QSR fusing) | [link](https://t.me/zenonnetwork/275773) |
| 2023-03-27 | 275776 | "Improving Dynamic Plasma with RandomX...while also limiting front-running" | [link](https://t.me/zenonnetwork/275776) |
| 2023-03-27 | 275777 | "...Dynamic Plasma. What's missing?" | [link](https://t.me/zenonnetwork/275777) |
| 2023-03-28 | 275986 | Roadmap: Narwhal and Tusk / Dynamic Plasma / Interop / ZeroSync / libp2p | [link](https://t.me/zenonnetwork/275986) |
| 2023-03-28 | 275990 | "The tx cap can be safely removed after Dynamic Plasma is implemented" | [link](https://t.me/zenonnetwork/275990) |
| 2023-03-29 | 276757 | Quoted DAG-consensus definition; "exactly the meta-DAG stated in the whitepaper" | [link](https://t.me/zenonnetwork/276757) |
| 2023-03-29 | 276762 | "meta-DAG will be represented by the Narwhal-Tusk implementation" | [link](https://t.me/zenonnetwork/276762) |
| 2023-03-29 | 276768 | "...dual-ledger, block-lattice structure with independent account-chains" | [link](https://t.me/zenonnetwork/276768) |
| 2023-03-29 | 276772 | "Also using PoW is critical for any public ledger" | [link](https://t.me/zenonnetwork/276772) |
| 2023-03-29 | 276780 | "It's limited to the transaction layer at the moment" | [link](https://t.me/zenonnetwork/276780) |
| 2023-03-29 | 276781 | "Let's implement the Adaptive/Dynamic Plasma first..." | [link](https://t.me/zenonnetwork/276781) |
| 2023-03-29 | 276784 | "Please let them finish the interoperability solutions first" | [link](https://t.me/zenonnetwork/276784) |
| 2023-03-29 | 276790 | "CPU PoW is important for txs. ASIC PoW can be merge-mined" (load-bearing) | [link](https://t.me/zenonnetwork/276790) |
| 2023-03-29 | 276791 | "We need Adaptive Plasma with CPU PoW aka RandomX" | [link](https://t.me/zenonnetwork/276791) |
| 2023-04-05 | 278348 | "Bullshark is the partially synchronous variant of Narwhal and Tusk" | [link](https://t.me/zenonnetwork/278348) |
| 2023-04-05 | 278352 | "meta-DAG for consensus (separated from the block-lattice)" | [link](https://t.me/zenonnetwork/278352) |
| 2023-04-05 | 278356 | PoW "crucial for decentralization and security"; ASIC/CPU balance a "bonus feature" | [link](https://t.me/zenonnetwork/278356) |
| 2023-04-05 | 278357 | "For the moment we only have ASIC friendly PoW..." | [link](https://t.me/zenonnetwork/278357) |
| 2023-04-05 | 278359 | "Replace SHA-3 with RandomX for Plasma. And ASIC friendly PoW can be obtained from merge-mining" | [link](https://t.me/zenonnetwork/278359) |
| 2023-04-05 | 278361 | "...if properly implemented and understood can reshape an entire industry" | [link](https://t.me/zenonnetwork/278361) |
| 2023-04-14 | 280665 | "Now that the interop solutions are almost ready...we can focus on Dynamic/Adaptive Plasma next" | [link](https://t.me/zenonnetwork/280665) |
| 2023-04-24 | 283563 | "main focus now should be Adaptive Plasma and smart contracts" | [link](https://t.me/zenonnetwork/283563) |
| 2023-04-24 | 283564 | Extension-chain defined: sidechain, dual-pegging, avoids touching L1 | [link](https://t.me/zenonnetwork/283564) |
| 2023-04-24 | 283577 | "...similar to Liquid Network...more like a sidechain" | [link](https://t.me/zenonnetwork/283577) |
| 2023-04-24 | 283579 | "The validator set can be configured to run directly on Pillars" | [link](https://t.me/zenonnetwork/283579) |
| 2023-05-06 | 285660 | "Basic PTLC integration is a good start" | [link](https://t.me/zenonnetwork/285660) |
| 2023-05-06 | 285662 | Dynamic Plasma, final 2-step definition | [link](https://t.me/zenonnetwork/285662) |
| 2023-05-09 | 286427 | Bitcoin (storage) vs Ethereum (compute) fee models; "Plasma should consider both" | [link](https://t.me/zenonnetwork/286427) |
| 2023-05-29 | 289841 | Capstone: Dynamic Plasma = "a robust feeless mechanism" | [link](https://t.me/zenonnetwork/289841) |
| 2023-07-11 | 302303 | "In the context of a minimal L1, ZAS should be minimal, too" | [link](https://t.me/zenonnetwork/302303) |
| 2023-07-11 | 302306 | Link: Nakamoto Institute, Hal Finney's RPOW (ambiguous, see Section 5) | [link](https://t.me/zenonnetwork/302306) |
| 2023-07-18 | 303963 | "...like PoW: hard to create, but easy to verify" (reputation analogy) | [link](https://t.me/zenonnetwork/303963) |
| 2023-07-18 | 303965 | "Trusted third parties are security holes" | [link](https://t.me/zenonnetwork/303965) |
| 2023-07-18 | 303972 | "Hope everything is clear now" (final message, this identity) | [link](https://t.me/zenonnetwork/303972) |
