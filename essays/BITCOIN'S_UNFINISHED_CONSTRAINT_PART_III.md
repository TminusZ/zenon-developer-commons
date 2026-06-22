# Bitcoin’s Unfinished Constraint Part III

## Abstract

Part I established that verification must remain cheaper than execution, and that abandoning this invariant produces SPV fragility and custodial collapse as architectural consequences. Part II demonstrated how verification-first systems resolve these failures by committing to ordered state rather than requiring re-execution.

Part III maps the role partitions that emerge when this invariant is enforced at scale. The analysis proceeds from Zenon’s actor model as a concrete instantiation of verification-first architecture. No claims of novelty are made. The structure is presented as the necessary decomposition of verification-first constraints into operational roles.

This part is intentionally operational and detailed. It is written for readers who want to see how verification-first constraints decompose into implementable system roles. Nothing “magical” occurred. Responsibility simply moved to where the invariant could be preserved.

-----

## I — The Two Agreements

### Section 1: What consensus actually produces

There are two distinct things a distributed system can agree on. Conflating them is the source of most architectural confusion in blockchain design:

**Agreement on Order**

“This claim happened before that one.”

A public timeline. A shared sequence. A global notebook where participants can reference the same positions.

This is consensus in the traditional sense: establishing the exact sequence everyone references. Without ordering, you have chaos—double-spends, conflicting histories, no shared reality.

But ordering alone tells you nothing about validity.

**Agreement on Truth**

“This claim is actually valid.”

Not “someone says so.” Not “a server told me.” Valid as in: the evidence verifies under the rules.

This is verification: establishing that what was ordered actually satisfies the claimed properties. That the state transition was legitimate. That the proof checks out.

In execution-first systems, consensus attempts to produce both agreements simultaneously by re-executing everything. The same nodes that decide sequence also validate semantics. They run the computation. They become the bottleneck. They couple ordering capacity to execution complexity.

In verification-first systems, consensus produces ordering, and truth emerges from verification. Different jobs. Different actors. Different scaling properties.

The distinction is architecturally fundamental:

- **Ordered ≠ true**
- **Ordered** means “recorded in the canonical sequence”
- **True** means “proven valid under verification rules”

Hold this distinction. Everything that follows is merely consequences.

-----

## II — The Actor Partition

### Section 2: Role separation as architectural necessity

When verification must remain cheaper than execution, certain role separations become mandatory. The system cannot function otherwise. These are not design preferences. They are structural requirements.

Consider each actor through two lenses:

- **Job**: What they do
- **Not allowed**: What they cannot do (because allowing it would violate the invariant)

The architecture presented here uses Zenon’s terminology as a conceptual mapping. Exact implementation details may vary across clients and specification drafts. The critical element is the role separation itself, not the naming convention.

### Section 3: Users and clients

**Job:**

- Sign intent (“send,” “transfer,” “execute”)
- Choose what evidence constitutes “sufficient” (fast vs strict verification policies)
- Set finality thresholds (when to treat state as final and act on it)

**Not allowed:**

- Force the network to accept invalid claims
- Skip the acceptance policy required by counterparties

**The wallet as policy engine**

In verification-first architecture, a wallet is not merely a key manager. It is a policy engine for verification thresholds.

For low-value interactions, a wallet might treat “Ordered” (included in consensus) as sufficient to act on. For high-value interactions, it waits for “Verified” (evidence checked, proof valid). For irreversible interactions, it waits for “Anchored” (commitment hardened by external timestamp).

Different users can enforce different thresholds: a coffee shop accepts fast finality (ordered is enough), an exchange waits for verified + anchored, a DAO treasury requires multiple independent verifications from different Sentinel services.

Most users never configure these settings manually. They inherit defaults from their wallet software, their community standards, or common “recommended” profiles.

But the architectural capability exists. The user controls their verification policy.

This represents a fundamental shift from execution-first systems where “confirmed” conflates ordering, execution, finality, and validity into a single opaque state transition controlled by consensus participants.

### Section 4: Executors and state transition producers

**Zenon label:** ZApps / External Execution

**Job:**

- Execute (produce state transitions)
- Produce claims (“state moved from X to Y”)
- Attach receipts (evidence that makes verification cheap)

**Not allowed:**

- Claim validity without providing evidence
- Decide ordering (they produce claims; consensus orders them)
- Decide truth (they produce evidence; verifiers check it)

**What execution means in this context**

Execution is the act of changing state. In verification-first architecture, execution has three parts:

1. **Produce a state transition** — “Alice had 100 tokens. Now Alice has 90 and Bob has 10.”
1. **Produce a claim** — “This transition happened according to rules R.”
1. **Attach a receipt** — Evidence that the claim is valid: a signature, a proof, a Merkle witness, anything where verification is far cheaper than execution.

The executor does not ask permission to execute. It executes, produces the claim, and submits it to ordering. The network orders the claim. Verifiers check the receipt. If the receipt is valid, the claim is recognized. If not, it is ignored.

**The workshop analogy**

Think of execution as a contractor’s workshop. You hire a contractor to build a cabinet. The contractor does not build it in your living room under your supervision. They build it in their workshop—using their tools, their process, their expertise.

When they deliver, they do not ask you to trust them. They show you the inspection report.

The report says: “This cabinet meets specifications S, as verified by measurements M.”

You check the report. If it is valid, you accept the cabinet. If the measurements do not verify, you reject delivery.

The executor is the workshop. The inspection report is the receipt. You do not need to watch the contractor work. You need to verify the result.

**Execution environments can vary**

Executors can run in standard virtual machines (EVM-compatible, WASM), rollup execution layers (optimistic or ZK rollups that batch many transactions), specialized hardware (secure enclaves, FPGAs), or local devices (your phone executes and produces proof). The architecture does not constrain where execution happens. It constrains what execution produces: verifiable claims.

Executors are liberated to execute however they want—fast, specialized, private—as long as they produce verifiable claims. That is the trade. Freedom in execution. Accountability through verification.

**Two concrete examples**

*Example 1: Simple payment*

Alice wants to send Bob 10 ZNN. She opens a wallet application (itself a lightweight executor). The application reads Alice’s current balance from committed state, creates a signed transaction (“Alice → Bob, 10 ZNN”), packages the claim with evidence (signature, balance proof), and submits to ordering infrastructure. The network orders the claim. Verifiers check the signature and balance proof. If valid, Bob’s wallet recognizes the payment. The executor did not ask consensus for permission. It produced a valid claim.

*Example 2: Marketplace asset transfer*

A game item changes hands. The marketplace executor reads current ownership state (Alice owns Sword #42), executes transfer logic (Alice signs transfer to Bob, Bob pays 50 ZNN), produces claim (“Ownership of Sword #42: Alice → Bob”), attaches receipts (signatures from both parties, payment proof, ownership Merkle witness), and submits to ordering. The network orders the claim. Verifiers check the signatures and proofs. If valid, Bob’s game client recognizes the new ownership. The marketplace did not run “on-chain.” It ran wherever made sense, produced evidence, and let verification decide truth.

### Section 5: Proof generation and relay services

**Zenon label:** Sentries

**Job:**

- Generate proofs (turn heavy computation receipts into light checkable objects)
- Package and relay claims to ordering infrastructure
- Handle mempool optimization, retries, routing

**Not allowed:**

- Modify claims or proofs in transit
- Claim that delivery equals validity

Relayers cannot be gatekeepers, because users can route around them. This is a permissionless assumption.

**The asymmetry requirement**

Verification requires an asymmetry: generating evidence can be expensive, but checking evidence must be cheap. A prover turns heavy computation into a light, checkable object: a zero-knowledge proof, a Merkle commitment with verification path, a fraud proof challenge format—anything where verification is far cheaper than execution.

Your phone should not need to redo the computation. It should need to check a receipt. That asymmetry is what makes verification ambient.

Relayers handle the logistics: package claims with proofs, submit and retry under congestion, broadcast to multiple ordering endpoints, ensure claims reach consensus. They do not decide truth. They do not decide order. They deliver sealed envelopes.

### Section 6: Consensus nodes and ordering

**Zenon label:** Pillars / Momentum

**Job:**

- Order claims (produce the exact sequence everyone references)
- Preserve availability (data can be retrieved)
- Enforce bounds (size limits, rate limits, fee structures)

**Not allowed:**

- Claim that ordering equals validity
- Modify claim contents
- Decree what verifiers must accept

Consensus nodes are not there to run applications. They are there to keep the shared notebook.

Think “court clerk,” not “judge.”

**What consensus actually does**

The ordering layer (Pillars producing Momentum blocks) agrees on:

- **Which claims made it into the ledger** — sequence number, inclusion proof
- **What order they are in** — a shared ordering no party can equivocate on
- **What data references are required** — minimum evidence, data availability guarantees
- **What constraints prevent spam and verification bombs** — size limits, rate limits, fee structures

Consensus produces a timeline. That timeline is:

- **Public** (anyone can read it)
- **Ordered** (claims have positions)
- **Available** (the data can be retrieved)
- **Bounded** (there are limits on what can be included)

**Admission checks, not truth checks**

When a claim arrives, consensus performs admission checks:

- Is the format valid?
- Is the fee paid?
- Does it fit within size and rate bounds?
- Is the required data included?

These are not semantic truth checks. Consensus does not ask: “Is this claim logically valid according to application rules?”

It asks: “Is this claim admissible to the ordered ledger?”

The clerk checks if your paperwork is complete, not whether your case is correct.

**The critical separation**

- In Bitcoin, ordering is verification: miners order by validating under simple rules
- In Ethereum, ordering is execution: validators order by running the EVM
- In Zenon, ordering is sequencing: Pillars order by building Momentum

Verification happens elsewhere.

This separation is what makes the architecture scale:

- Ordering does not bottleneck on execution complexity
- Verification does not bottleneck on consensus latency
- Different applications can have different verification requirements
- Users can enforce different verification policies

Momentum stamps the envelope. Verification reads it.

### Section 7: Verifiers and watchers

**Zenon label:** Sentinels

**Job:**

- Check claims against verification rules and test evidence (proof verifiers, signatures, Merkle paths)
- Detect missing data and flag invalid proofs
- Publish disputes and maintain executor reputations

**Not allowed:**

- Prevent valid claims from being ordered
- Force users to accept their verification results
- Claim authority they do not have

Sentinels are not enforcement agents. They do not control ordering. They do not decree reality. They verify.

Sentinels are verification infrastructure. They can be public services (open verification nodes), private services (your own verification backend), embedded in wallets (client-side verification), or specialized by domain (a Sentinel that only verifies a specific application).

**The economics of watching**

In execution-first systems, everyone watches by re-executing. In verification-first systems, watching is specialized. Some Sentinels watch everything (general audit services), some watch specific applications (domain specialists), some watch specific users (personal verification).

Watching can be altruistic (“I run a Sentinel to help secure the network”), incentivized (rewards for catching invalid claims), self-interested (assets at risk), or delegated (paid verification-as-a-service).

The architecture does not mandate one model. It allows different verification markets to emerge based on what participants value.

The important property: watching is permissionless. Anyone can verify. Anyone can dispute. Anyone can publish warnings.

**Verification makes lies expensive**

In an execution-first system, invalid claims are prevented at ordering time. In a verification-first system, invalid claims are detected after ordering.

The invalid claim still got ordered (it is in the timeline), but no honest verifier accepts it, disputes are published, the executor’s reputation is damaged, dependent claims are invalidated, and users are warned.

Sentinels provide evidence. Users decide what evidence satisfies their policy.

### Section 8: Anchors and external timestamps

**Zenon label:** External timestamp ledgers (e.g., Bitcoin, Ethereum)

**Job:**

- Provide external timestamps (proof a commitment existed before block B)
- Harden the timeline (rewriting requires rewriting the anchor)
- Enable cross-domain finality witnesses

**Not allowed:**

- Control the local system
- Dictate local validity rules
- Censor local claims

Sometimes you want more than local ordering. You want an external timestamp. A deeper finality witness.

**Why anchor?**

Anchoring provides:

- **Proof that a commitment existed before an external timestamp** — “this claim existed before Bitcoin block 800000”
- **An irreversibility witness** — “if this anchor is buried, rewriting requires rewriting Bitcoin”
- **A cross-domain finality signal** — “external observers can verify this timestamp”
- **Defense against long-range attacks** — “you cannot rewrite history without rewriting the anchor chain”

Systems anchor by:

- Posting a commitment (Merkle root, state hash) to an external timestamp ledger like Bitcoin
- Referencing the block height and hash from that ledger
- Allowing anyone to verify the commitment existed before that block

Anchors do not decide local truth. They harden the timeline.

**The anchor relationship**

A verification-first system might anchor to an external timestamp ledger every N blocks:

- Local system produces local ordering (fast, flexible)
- Periodically, a commitment is posted to the external ledger
- That ledger’s finality backs the commitment
- External observers can verify the anchor

This assumes the external ledger’s liveness (it continues producing blocks) and irreversibility (its consensus makes rewriting economically prohibitive). If the anchor ledger halts or reorganizes deeply, local ordering continues—the anchor is a witness, not a dependency.

This creates a finality gradient: locally ordered (fast, reversible under network conditions), locally verified (fast, probabilistically final), externally anchored (slow, deeply final). Different use cases require different finality: a game move needs local ordering, a large transfer needs local verification, a legal contract needs external anchoring.

Anchors provide timestamps, not truth.

-----

## III — The Three States

### Section 9: What wallets must learn to display

Execution-first wallets use one word: “confirmed.”

That word is too vague to be honest. It conflates:

- Ordering (the claim is in a block)
- Execution (the claim was computed)
- Finality (the block will not reorganize)
- Validity (the claim is actually correct)

Verification-first systems require honest labels:

**1) Ordered**

On the public timeline (Momentum ordered it). It may still be wrong.

What this means:

- The claim has a position in the sequence
- The data is available
- Other claims can reference it
- It is not final

What this does not mean:

- The claim is valid
- You should act on it
- It will not be proven invalid later

Visual indicator: ⏳ Ordered / Pending

**2) Verified**

The evidence verifies under the rules. Now it becomes “real” to you—because you checked the receipt.

What this means:

- The proof was checked
- The evidence satisfies the rules
- The claim is valid under the verification policy you chose
- You can act on it with confidence

What this does not mean:

- Everyone verified it the same way (different policies exist)
- It is anchored externally
- It is absolutely irreversible (if the ordering layer reorganizes, verification follows)

Visual indicator: ✅ Verified

**3) Anchored (optional)**

A commitment is recorded on an external timestamp ledger. This hardens the record.

What this means:

- The claim (or its containing batch) was posted to an anchor ledger
- External observers can verify the timestamp
- Rewriting requires rewriting the anchor
- Deep finality is established

What this does not mean:

- The anchor ledger validated the claim’s semantics
- Local verification is unnecessary
- The anchor ledger controls the system

Visual indicator: ⚓ Anchored

**Progressive truth**

Users do not need to understand Merkle trees. They need truth labels:

- 🟢 green check = verified
- ⏳ clock = ordered/pending
- 🔴 red X = refused
- ⚓ anchor = externally final

A wallet displays: “Payment received ✅ Verified”

Behind the scenes:

- The claim was ordered by Momentum
- Evidence was checked by a Sentinel
- The wallet verified the proof locally
- Policy was satisfied

The user did not need to know. The architecture handled it.

-----

## IV — One Transaction, End-to-End

### Section 10: Concrete walkthrough (optional detail)

*This section traces a single payment through all actor roles. Readers who prefer abstract architectural reasoning may skip to Section 11.*

Sarah pays a contractor for website work. Let us trace the claim through the full actor partition.

**Step 1 — User / Wallet**

Sarah opens her wallet and signs intent: “send 1000 ZNN to <contractor_address>”

Her wallet:

- Creates the claim
- Signs it with her private key
- Packages any required evidence (balance proofs, etc.)
- Submits to a Sentry

She does not submit directly to Momentum. She submits to infrastructure that will handle logistics.

**Step 2 — Sentries (relay/proof services)**

The Sentry receives Sarah’s claim. It might:

- Generate a proof (if the claim requires one)
- Package the claim with other claims (batching)
- Pay the fee to get it ordered
- Submit to Momentum nodes
- Retry if submission fails

The Sentry gets the claim into the ordering queue.

**Step 3 — Pillars / Momentum (ordering)**

Momentum consensus runs. Pillars:

- Receive the claim
- Check admission validity (format, size, fee, bounds)
- Include it in a block
- Assign it a position: “this claim exists at Momentum height H, position P”

The claim is now ordered. (Ordering only; validity comes later.)

Momentum publishes the block. The claim is now part of the canonical sequence.

**Step 4 — Sentinels (verification)**

Sentinels watch Momentum. When they see Sarah’s claim, they:

- Retrieve the claim data
- Retrieve the associated evidence
- Run the verification algorithm
- Check the proof, signatures, state transitions

If it verifies: ✅ Verified

- Sentinels publish: “claim C at position P is valid”
- Sarah’s wallet sees the verification signal
- The contractor’s wallet sees it too

If evidence is missing or broken: ❌ Refused

- Sentinels publish: “claim C at position P is invalid”
- Sarah’s wallet shows: “Payment failed—invalid proof”
- The contractor’s wallet does not recognize the payment

If it is still pending: ⏳ Ordered/Pending

- Maybe evidence has not arrived yet
- Maybe proof generation is slow
- Maybe Sentinels are catching up

**Step 5 — Anchoring (optional)**

For high-stakes actions, a commitment may be anchored to an external timestamp ledger to harden the timeline.

If Sarah’s payment is part of a large batch that gets anchored:

- A Merkle root covering her claim is posted to the external ledger (e.g., Bitcoin)
- That ledger’s finality backs the commitment
- External observers can verify: “this claim existed before block B”

Sarah’s wallet now shows: ⚓ Anchored

Nobody needed customer support. Nobody needed an explorer (though explorers are helpful). Nobody needed to re-execute the world.

Reality emerged from receipts.

-----

## V — What Anchoring to Bitcoin Actually Means

### Section 11: Bitcoin as public clock, not execution layer

Anchoring to Bitcoin does not mean running the verification-first system on Bitcoin. It does not mean replaying transactions. It does not mean Bitcoin validates application logic.

It means using Bitcoin as a public, irreversible clock.

**Step 1: Local history exists**

At some Momentum height H, the verification-first system already has an ordered history:

- Sarah’s payment
- Other claims in the same block
- A canonical sequence agreed on by Pillars

This history is already usable locally. Anchoring does not change operation.

**Step 2: Compute a commitment**

From that ordered history, the system computes a commitment. Concretely:

- A Merkle root over recent Momentum blocks, or
- A hash of the block headers up to height H

Think of it as: “A 32-byte fingerprint that uniquely represents history up to this point.”

No transaction data. No proofs. No semantics. Just a cryptographic summary.

**Step 3: Create a Bitcoin transaction**

A normal Bitcoin transaction is created that includes this commitment. Typically:

- The commitment is embedded in the transaction (e.g., OP_RETURN)
- The transaction spends real BTC
- It follows normal Bitcoin rules

Nothing special happens on Bitcoin’s side. To Bitcoin, this looks like: “Someone posted some arbitrary data.”

Bitcoin does not know it is Zenon. Bitcoin does not validate Zenon. Bitcoin does not care.

**Step 4: Bitcoin timestamps the commitment**

That Bitcoin transaction:

- Enters the mempool
- Gets mined into a block
- Becomes part of Bitcoin’s chain

Now the commitment is associated with:

- A specific Bitcoin block hash
- A specific block height
- A specific point in Bitcoin’s timeline

This is the critical moment. From now on, anyone can say: “This Zenon history existed before Bitcoin block B.”

That statement is objectively checkable.

**Step 5: Record the Bitcoin reference**

The verification-first system records:

- The commitment it posted
- The Bitcoin transaction ID
- The Bitcoin block hash and height

This reference becomes part of the system’s own history. Anchoring is now complete.

**Step 6: Anyone can verify the anchor**

Later, any verifier can independently check anchoring:

1. Recompute the commitment from local data
1. Confirm it matches the committed fingerprint
1. Look up the Bitcoin transaction
1. Verify it exists in Bitcoin block B
1. Confirm block B is deeply buried

If all of that holds: history up to height H cannot be rewritten unless Bitcoin itself is rewritten.

No trust required. No intermediaries. Just math and public data.

**What Bitcoin is (and is not) doing here**

Bitcoin is acting as:

- A global timestamp
- An irreversibility witness
- A public reference clock

Bitcoin is not:

- Executing transactions
- Validating proofs
- Participating in consensus
- Controlling the system in any way

The verification-first system could continue operating even if Bitcoin stopped producing blocks. The anchor is a witness, not a dependency.

**Why this matters for finality**

After anchoring:

- Local history before height H is locally ordered ✔
- Locally verified claims remain valid ✔
- Rewriting history would now require:
  - Rewriting the verification-first system **and**
  - Rewriting Bitcoin

That is what wallets label as: ⚓ Anchored

Not “more correct.” Not “more valid.” Just harder to undo.

-----

## VI — Who Decides What Is True?

### Section 12: From objective truth to subjective recognition

In execution-first systems, truth is produced by a committee that executes. If the validator set says “this is valid,” it is valid—because they ran the computation.

In verification-first systems, truth is produced by evidence. Different wallets can enforce different policies, which means recognition can differ temporarily:

- One wallet accepts quickly (ordered is enough for this user)
- Another waits for stricter verification (multiple Sentinel confirmations)
- Another waits for anchoring (needs external finality)

Truth is still objective (the evidence either verifies or it does not), but when you recognize it can vary.

That is not a bug. It is what happens when verification becomes local again.

**The convergence property**

Eventually, all honest verifiers converge:

- Invalid claims are rejected
- Valid claims are accepted
- Disputes are resolved

But convergence can happen at different speeds for different users.

A merchant might accept “ordered” for a coffee. An exchange might require “verified + anchored” for a withdrawal.

Both are rational. Both are using the same underlying reality. They just have different risk tolerances.

**The trust model shift**

Execution-first: “I trust the validator set to execute correctly.”

Verification-first: “I trust math to verify evidence correctly.”

You still need to trust:

- That the evidence you received is the real evidence (data availability)
- That your verification implementation is correct (software trust)
- That your hardware is not compromised (local trust)

But you do not need to trust:

- That a specific set of nodes executed correctly
- That a committee was honest
- That a validator set did not collude

The trust is local and mathematical, not social and delegated.

-----

## Conclusion

### Section 13: The architecture’s defense through separation

Verification-first architecture functions because roles are separated:

- Pillars/Momentum order
- Sentinels verify
- Sentries produce and relay evidence
- Clients decide acceptance policies
- Executors produce claims and receipts
- Anchors provide external finality witnesses

Execution can be anywhere—specialized hardware, private enclaves, rollups, games—anywhere that can produce a verifiable claim. Verification can be everywhere—wallets, Sentinels, users, services. Verification is not centralized in a validator set. It is ambient.

The architecture defends itself through separation of concerns: if executors lie, verifiers catch them; if verifiers are wrong, you can verify yourself; if ordering censors, you can see what is missing; if anchors fail, local ordering continues.

No single actor has enough power to corrupt the system.

**The scaling path**

Because roles are separated, each can scale independently: ordering scales by optimizing consensus, execution scales by specializing environments, verification scales by parallelizing checks, evidence scales by improving proof systems.

You do not need to scale everything at once. You scale the bottleneck.

This is not innovation. This is consistency—consistency with the invariant that Bitcoin introduced and that the industry abandoned.

The question is not whether this represents a new paradigm. The question is whether it represents resumption of an unfinished architectural line of thought.

The answer is evident in the constraints.

-----

*Zenon’s Network of Momentum is fully open-source and community-run. More formal documentation and ongoing community research can be found at: https://github.com/TminusZ/zenon-developer-commons*
