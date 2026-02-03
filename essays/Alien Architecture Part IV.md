# Alien Architecture Part IV: The Verification Map

**ZENON ALIEN COMMONS**  
*January 14, 2026*

Part III showed what it feels like when verification becomes ambient.

Part IV is the quieter diagram: who does what in a verification-first world — using Zenon's actor names so it's easier to map the idea to the network.

Because nothing "magical" happened.

Jobs just moved.

---

## Quick Map: The Cast

**Zenon role summary:**
- **Pillars/Momentum:** agree on ordering + availability constraints
- **Sentinels:** verify claims and publish validity signals
- **Sentries:** provide proof generation and reliable submission
- **ZApps:** execute anywhere, output claims + receipts
- **Clients:** choose acceptance/finality thresholds
- **Anchors:** harden the timeline externally

In practice, wallets stop saying "confirmed" and start showing: **Ordered / Verified / Anchored**.

---

## The Two Agreements Everyone Confuses

There are two different things a network can agree on:

### 1) Agreement on Order

"This claim happened before that one."

A public timeline. A shared sequence. A global notebook where everyone can point to the same page numbers.

This is consensus in the traditional sense: establishing the exact sequence everyone references. Without ordering, you have chaos — double-spends, conflicting histories, no shared reality.

But ordering alone tells you nothing about validity.

### 2) Agreement on Truth

"This claim is actually valid."

Not "someone says so." Not "a server told me." Valid as in: the evidence verifies under the rules.

This is verification: establishing that what was ordered actually satisfies the claimed properties. That the state transition was legitimate. That the proof checks out.

In execution-first systems, consensus tries to do both: order and truth — by re-executing everything.

The same nodes that decide sequence also validate semantics. They run the computation. They become the bottleneck. They couple ordering capacity to execution complexity.

In verification-first systems, consensus mostly handles order, and truth comes from verification.

Different jobs. Different actors. Different scaling properties.

**Ordered ≠ true.** Ordered means "recorded." Truth means "proven."

Hold that. Everything below is just consequences.

---

## The City Metaphor

A verification-first network is a city:
- Workshops do work (execution)
- A registry timestamps and files claims (ordering / consensus)
- Everyone can inspect receipts (verification)

In a traditional city, you trust the registry because the government enforces it.

In a verification-first city, you trust the registry because you can check the receipts yourself.

Zenon's twist is that the "registry" and the "receipt-checking" aren't the same job.

They're not even done by the same actors.

---

## The Actors

> **Note:** Zenon's terminology is used here as a conceptual mapping. Exact implementation details may vary across clients/spec drafts.

Each actor has:
- **Job:** what they do
- **Not allowed:** what they can't do

Assuming a permissionless setting, you can always route around single service chokepoints.

### 1) Users / Clients

**Zenon label:** Users / Clients

**Job:**
- Sign intent ("send," "buy," "transfer")
- Choose what evidence is "enough" (fast vs strict)
- Set finality policies (when to act)

**Not allowed:**
- Force the network to accept invalid claims
- Skip the acceptance policy the other side requires

#### The Wallet as Policy Engine

In a verification-first world, a wallet isn't just keys.

It's a policy engine.

For small stuff, your wallet might treat "Ordered" as usable. For big stuff, it waits for "Verified." For irreversible stuff, it waits for "Anchored."

Different users can have different thresholds:
- A coffee shop accepts fast finality (ordered is enough)
- An exchange waits for verified + anchored
- A DAO treasury requires multiple independent verifications

Most people never touch these settings. They inherit defaults from their wallet, their community, or common "recommended" profiles.

But the choice exists.

### 2) Executors / ZApps

**Zenon label:** ZApps / External Execution

**Job:**
- Execute (produce state transitions)
- Produce claims ("state moved from X to Y")
- Attach receipts (evidence that makes verification cheap)

**Not allowed:**
- Claim validity without providing evidence
- Decide ordering (they produce claims; consensus orders them)
- Decide truth (they produce evidence; verifiers check it)

#### What Is a ZApp?

A ZApp is any application that produces verifiable state transitions.

Think of it as: a program that shows its work.

It's not running "on the blockchain." It's running wherever makes sense — your phone, a server, a specialized machine, a private enclave — and then proving to the network that it did what it claims.

The "Z" doesn't stand for anything official. Conceptually, it signals: "this app produces claims the Zenon network can order and verify."

A ZApp could be:
- A payment processor that signs transfers
- A marketplace that tracks asset ownership
- A social platform that timestamps posts
- A game server that commits to game state
- An escrow service that releases funds on conditions

The key property: execution happens, then evidence is produced.

Not: execution happens inside consensus.

#### What Does "Execution" Mean Here?

Execution is the act of changing state.

In a verification-first architecture, execution has three parts:

1. **Produce a state transition** — "Alice had 100 tokens. Now Alice has 90 and Bob has 10."
2. **Produce a claim** — "This transition happened according to rules R."
3. **Attach a receipt** — Evidence that the claim is valid: a signature, a proof, a Merkle witness, anything where verification is far cheaper than execution.

The executor doesn't ask permission to execute. It just executes, produces the claim, and submits it.

The network orders the claim. (Ordering only; validity comes later.)

Verifiers check the receipt.

If the receipt is valid, the claim is recognized. If not, it's ignored.

#### Two Concrete Examples

**Example 1: A Simple Payment**

Alice wants to send Bob 10 ZNN.

She opens a ZApp (maybe her wallet, maybe a payment service).

The ZApp:
- Checks Alice's balance (reads current state)
- Creates a signed transaction: "Alice → Bob, 10 ZNN"
- Packages the claim with evidence (signature, balance proof)
- Submits to the network

The network orders it. Verifiers check the signature and balance proof. If valid, Bob's wallet recognizes the payment.

The ZApp didn't need to ask consensus for permission. It just produced a valid claim.

**Example 2: A Marketplace Asset Transfer**

A game item changes hands.

The marketplace ZApp:
- Reads current ownership (Alice owns Sword #42)
- Executes transfer logic (Alice signs transfer to Bob, Bob pays 50 ZNN)
- Produces claim: "Ownership of Sword #42: Alice → Bob"
- Attaches receipts: signatures from both parties, payment proof, ownership Merkle witness
- Submits

The network orders the claim. Verifiers check the signatures and proofs. If valid, Bob's game client recognizes the new ownership.

The marketplace didn't run "on-chain." It ran wherever made sense, produced evidence, and let verification decide truth.

#### The Workshop Analogy

Think of a ZApp as a contractor's workshop.

You hire a contractor to build a cabinet.

The contractor doesn't build it in your living room. They build it in their workshop — using their tools, their process, their expertise.

When they deliver, they don't ask you to trust them.

They show you the inspection report.

The report says: "This cabinet meets specifications S, as verified by measurements M."

You check the report. If it's valid, you accept the cabinet.

The ZApp is the workshop. The inspection report is the receipt.

You don't need to watch the contractor work. You need to verify the result.

#### Execution Environments Can Vary

ZApps can run in:
- Standard virtual machines (EVM-compatible, WASM, etc.)
- Rollup execution layers (optimistic or ZK rollups that batch many transactions)
- Specialized hardware (secure enclaves, FPGAs)
- Your own device (local execution with remote verification)

The architecture doesn't care where execution happens.

It cares that execution produces verifiable claims.

The workshop makes things. It doesn't make them true.

ZApps are liberated to execute however they want — fast, specialized, private — as long as they produce verifiable claims.

That's the trade.

**Freedom in execution. Accountability through verification.**

### 3) Sentries: Proof + Relay Services

**Job:**
- Generate proofs (turn heavy computation receipts from ZApps into light checkable objects)
- Package and relay claims to ordering
- Handle mempool optimization, retries, routing

**Not allowed:**
- Modify claims or proofs in transit
- Claim that delivery equals validity

Relayers can't be the gate, because users can route around them.

#### Two Related Roles

This is actually two related but distinct functions:

**Proof Services:**

Verification needs an asymmetry:
- Generating evidence can be expensive
- Checking evidence must be cheap

A prover turns heavy computation into a light, checkable object: a zero-knowledge proof, a Merkle commitment + verification path, a fraud proof challenge format, a cryptographic attestation — anything where verification is far cheaper than execution.

Your phone shouldn't need to redo the computation. It should need to check a receipt.

That asymmetry is what makes verification ambient.

**Relay Services:**

Relayers do the boring logistics:
- Package claims with their proofs
- Submit and retry under congestion
- Broadcast to multiple endpoints
- Ensure the claim reaches ordering

They don't decide truth. They don't decide order.

They deliver sealed envelopes.

### 4) Consensus Nodes: Pillars / Momentum

**Job:**
- Order claims (the exact sequence everyone references)
- Preserve availability (data can be retrieved)
- Enforce bounds (size limits, rate limits, fee structures)

**Not allowed:**
- Claim that ordering equals validity
- Modify claim contents
- Decree what verifiers must accept

Consensus nodes are not there to run your app.

They are there to keep the shared notebook.

Think "court clerk," not "judge."

#### What Consensus Actually Does

The registry (Pillars / Momentum) agrees on:
- Which claims made it into the ledger — sequence number, inclusion proof
- What order they're in — a shared ordering you can't equivocate on
- What data references are required — minimum evidence, data availability guarantees
- What constraints prevent spam and verification bombs — size limits, rate limits, fee structures

Consensus produces a timeline.

That timeline is:
- **Public** (anyone can read it)
- **Ordered** (claims have positions)
- **Available** (the data can be retrieved)
- **Bounded** (there are limits on what can be included)

#### Admission Checks, Not Truth Checks

When a claim arrives, consensus performs admission checks:
- Is the format valid?
- Is the fee paid?
- Does it fit within size/rate bounds?
- Is the required data included?

These are not semantic truth checks.

Consensus doesn't ask: "Is this claim logically valid according to app rules?"

It asks: "Is this claim admissible to the ordered ledger?"

Think of it as: the clerk checks if your paperwork is complete, not whether your case is correct.

#### The Critical Separation

- In Bitcoin, ordering is verification: miners order by validating.
- In Ethereum, ordering is execution: validators order by running the EVM.
- In Zenon, ordering is sequencing: Pillars order by building Momentum.

Verification happens elsewhere.

This separation is what makes the architecture scale:
- Ordering doesn't bottleneck on execution complexity
- Verification doesn't bottleneck on consensus latency
- Different apps can have different verification requirements
- Users can run different verification policies

Momentum stamps the envelope. Verification reads it.

### 5) Verifiers / Watchers: Sentinels

**Zenon label:** Sentinels

**Job:**
- Check claims against verification rules
- Test evidence (run proof verifiers, check signatures, validate Merkle paths)
- Detect missing data (catch data withholding attacks)
- Flag invalid proofs and publish disputes

**Not allowed:**
- Prevent valid claims from being ordered
- Force users to accept their verification results
- Claim authority they don't have

Sentinels aren't cops.

They don't control ordering. They don't decree reality.

They verify.

#### What Sentinels Do

They:
- Check claims against verification rules
- Test evidence (run proof verifiers, check signatures, validate Merkle paths)
- Detect missing data (catch data withholding attacks)
- Flag invalid proofs (publish disputes)
- Publish warnings (broadcast fraud alerts)
- Maintain reputations (track which executors produce valid vs invalid claims)

Sentinels are verification infrastructure.

They can be:
- Public services (open verification nodes)
- Private services (your own verification backend)
- Embedded in wallets (client-side verification)
- Specialized by domain (a Sentinel that only verifies a specific app)

#### The Economics of Watching

In execution-first systems, everyone watches by re-executing.

In verification-first systems, watching is specialized:
- Some Sentinels watch everything (general audit services)
- Some watch specific apps (domain specialists)
- Some watch specific users (personal verification)

Watching can be:
- **Altruistic** — "I run a Sentinel to help secure the network"
- **Incentivized** — "I get rewards for catching invalid claims"
- **Self-interested** — "I watch because I have assets at risk"
- **Delegated** — "I pay a service to watch for me"

Incentive compatibility matters: Sentinels need sustainable reasons to watch. In many implementations, this comes from dispute resolution rewards (catching invalid claims pays), service fees (users pay for verification-as-a-service), or stake-based returns (verifiers bond capital and earn yield). The architecture doesn't mandate one model — it allows different verification markets to emerge based on what participants value.

The important thing is: watching is permissionless.

Anyone can verify. Anyone can dispute. Anyone can publish warnings.

**Verification makes lies expensive.**

In an execution-first system, invalid claims are prevented at ordering time.

In a verification-first system, invalid claims are detected after ordering.

The invalid claim still got ordered (it's in the timeline), but:
- No honest verifier accepts it
- Disputes are published
- The executor's reputation is damaged
- Dependent claims are invalidated
- Users are warned

They provide evidence. You decide.

### 6) Anchors: External Gravity

**Zenon label:** External timestamp ledgers (e.g., Bitcoin, Ethereum)

**Job:**
- Provide external timestamps (proof a commitment existed before block B)
- Harden the timeline (rewriting requires rewriting the anchor)
- Enable cross-domain finality witnesses

**Not allowed:**
- Control your system
- Dictate local validity rules
- Censor local claims

Sometimes you want more than local ordering.

You want an external timestamp. A deeper finality witness.

#### Why Anchor?

Anchoring provides:
- Proof that a commitment existed before an external timestamp — "this claim existed before Bitcoin block 800000"
- An irreversibility witness — "if this anchor is buried, rewriting requires rewriting Bitcoin"
- A cross-domain finality signal — "external observers can verify this timestamp"
- Defense against long-range attacks — "you can't rewrite history without rewriting the anchor chain"

So systems anchor:
- Post a commitment (Merkle root, state hash) to an external timestamp ledger like Bitcoin
- Reference the block height/hash from that ledger
- Anyone can verify the commitment existed before that block

Anchors don't decide local truth.

They harden the timeline.

#### The Anchor Relationship

Zenon might anchor to an external timestamp ledger every N blocks:
- Zenon produces local ordering (fast, flexible)
- Periodically, a commitment is posted to the external ledger
- That ledger's finality backs the commitment
- External observers can verify the anchor

This assumes the external ledger's liveness (it continues producing blocks) and irreversibility (its consensus makes rewriting economically prohibitive). If the anchor ledger halts or reorganizes deeply, local ordering continues — the anchor is a witness, not a dependency.

This creates a finality gradient:
- **Locally ordered** (fast, reversible under network conditions)
- **Locally verified** (fast, probabilistically final)
- **Externally anchored** (slow, deeply final)

Different use cases need different finality:
- A game move needs local ordering
- A large transfer needs local verification
- A legal contract needs external anchoring

They provide timestamps. Not truth.

---

## The Three States Your Wallet Must Learn

Execution-first wallets use one word: "confirmed."

That word is too vague to be honest.

It conflates:
- Ordering (the claim is in a block)
- Execution (the claim was computed)
- Finality (the block won't reorg)
- Validity (the claim is actually correct)

Verification-first systems need honest labels:

### 1) Ordered

On the public timeline (Momentum ordered it). It may still be wrong.

**What this means:**
- The claim has a position in the sequence
- The data is available
- Other claims can reference it
- It's not final

**What this doesn't mean:**
- The claim is valid
- You should act on it
- It won't be proven invalid later

**Visual:** ⏳ Ordered / Pending

### 2) Verified

The evidence verifies under the rules. Now it becomes "real" to you — because you checked the receipt.

**What this means:**
- The proof was checked
- The evidence satisfies the rules
- The claim is valid under the verification policy you chose
- You can act on it with confidence

**What this doesn't mean:**
- Everyone verified it the same way (different policies exist)
- It's anchored externally
- It's absolutely irreversible (if the ordering layer reorgs, verification follows)

**Visual:** ✅ Verified

### 3) Anchored (optional)

A commitment is recorded on an external timestamp ledger. This hardens the record.

**What this means:**
- The claim (or its containing batch) was posted to an anchor ledger
- External observers can verify the timestamp
- Rewriting requires rewriting the anchor
- Deep finality is established

**What this doesn't mean:**
- The anchor ledger validated the claim's semantics
- Local verification is unnecessary
- The anchor ledger controls the system

**Visual:** ⚓ Anchored

### Progressive Truth

Your grandma doesn't need Merkle trees.

She needs truth labels:
- 🟢 green check = verified
- ⏳ clock = ordered/pending
- 🔴 red X = refused
- ⚓ anchor = externally final

Her wallet shows:

> "Payment received ✅ Verified"

Behind the scenes:
- The claim was ordered by Momentum
- Evidence was checked by a Sentinel
- Her wallet verified the proof locally
- Policy was satisfied

She didn't need to know.

The architecture handled it.

---

## One Transaction, End-to-End (Zenon Framed)

Sarah pays a contractor for website work.

Let's trace the claim from intent to verified reality.

### Step 1 — User / Wallet

Sarah opens her wallet and signs intent:

> "send 1000 ZNN to `<contractor_address>`"

Her wallet:
- Creates the claim
- Signs it with her private key
- Packages any required evidence (balance proofs, etc.)
- Submits to a Sentry

She doesn't submit directly to Momentum. She submits to infrastructure that will handle the logistics.

### Step 2 — Sentries (relay/proof services)

The Sentry receives Sarah's claim.

It might:
- Generate a proof (if the claim requires one)
- Package the claim with other claims (batching)
- Pay the fee to get it ordered
- Submit to Momentum nodes
- Retry if submission fails

The Sentry gets the claim into the ordering queue.

### Step 3 — Pillars / Momentum (ordering)

Momentum consensus runs.

Pillars:
- Receive the claim
- Check admission validity (format, size, fee, bounds)
- Include it in a block
- Assign it a position: "this claim exists at Momentum height H, position P"

The claim is now ordered.

(Ordering only; validity comes later.)

Momentum publishes the block. The claim is now part of the canonical sequence.

### Step 4 — Sentinels (verification)

Sentinels watch Momentum.

When they see Sarah's claim, they:
- Retrieve the claim data
- Retrieve the associated evidence
- Run the verification algorithm
- Check the proof, signatures, state transitions

**If it verifies:** ✅ Verified
- Sentinels publish: "claim C at position P is valid"
- Sarah's wallet sees the verification signal
- The contractor's wallet sees it too

**If evidence is missing/broken:** ❌ Refused
- Sentinels publish: "claim C at position P is invalid"
- Sarah's wallet shows: "Payment failed — invalid proof"
- The contractor's wallet doesn't recognize the payment

**If it's still pending:** ⏳ Ordered/Pending
- Maybe evidence hasn't arrived yet
- Maybe proof generation is slow
- Maybe Sentinels are catching up

### Step 5 — Anchoring (optional)

For high-stakes actions, a commitment may be anchored to an external timestamp ledger to harden the timeline.

If Sarah's payment is part of a large batch that gets anchored:
- A Merkle root covering her claim is posted to the external ledger (e.g., Bitcoin)
- That ledger's finality backs the commitment
- External observers can verify: "this claim existed before block B"

Sarah's wallet now shows: **⚓ Anchored**

Nobody needed customer support. Nobody needed an explorer (though explorers are helpful). Nobody needed to re-execute the world.

**Reality came from receipts.**

---

## What Anchoring to Bitcoin Actually Means

Anchoring to Bitcoin does not mean running Zenon on Bitcoin. It does not mean replaying transactions. It does not mean Bitcoin validates Zenon logic.

It means using Bitcoin as a public, irreversible clock.

Here's how that works in practice.

### Step 1: Zenon Has Local History

At some Momentum height H, Zenon already has an ordered history:
- Sarah's payment
- Other claims in the same block
- A canonical sequence agreed on by Pillars

This history is already usable locally. Anchoring does not change Zenon's operation.

### Step 2: Zenon Computes a Commitment

From that ordered history, Zenon computes a commitment.

Concretely, this is something like:
- A Merkle root over recent Momentum blocks, or
- A hash of the block headers up to height H

Think of it as:

> "A 32-byte fingerprint that uniquely represents Zenon history up to this point."

No transaction data. No proofs. No semantics.

Just a cryptographic summary.

### Step 3: A Bitcoin Transaction Is Created

A normal Bitcoin transaction is created that includes this commitment.

Typically:
- The commitment is embedded in the transaction (e.g. OP_RETURN)
- The transaction spends real BTC
- It follows normal Bitcoin rules

Nothing special happens on Bitcoin's side.

To Bitcoin, this looks like:

> "Someone posted some arbitrary data."

Bitcoin does not know it's Zenon. Bitcoin does not validate Zenon. Bitcoin does not care.

### Step 4: Bitcoin Timestamps the Commitment

That Bitcoin transaction:
- Enters the mempool
- Gets mined into a block
- Becomes part of Bitcoin's chain

Now the commitment is associated with:
- A specific Bitcoin block hash
- A specific block height
- A specific point in Bitcoin's timeline

This is the critical moment.

From now on, anyone can say:

> "This Zenon history existed before Bitcoin block B."

That statement is objectively checkable.

### Step 5: Zenon Records the Bitcoin Reference

Zenon records:
- The commitment it posted
- The Bitcoin transaction ID
- The Bitcoin block hash / height

This reference becomes part of Zenon's own history.

Anchoring is now complete.

### Step 6: Anyone Can Verify the Anchor

Later, any verifier can independently check anchoring:

1. Recompute the Zenon commitment from local data
2. Confirm it matches the committed fingerprint
3. Look up the Bitcoin transaction
4. Verify it exists in Bitcoin block B
5. Confirm block B is deeply buried

If all of that holds:

**Zenon history up to height H cannot be rewritten unless Bitcoin itself is rewritten.**

No trust required. No intermediaries. Just math and public data.

### What Bitcoin Is (and Is Not) Doing Here

**Bitcoin is acting as:**
- A global timestamp
- An irreversibility witness
- A public reference clock

**Bitcoin is not:**
- Executing Zenon transactions
- Validating Zenon proofs
- Participating in Zenon consensus
- Controlling Zenon in any way

Zenon could continue operating even if Bitcoin stopped producing blocks.

The anchor is a witness, not a dependency.

### Why This Matters for Finality

After anchoring:
- Zenon history before height H is locally ordered ✔
- Locally verified claims remain valid ✔
- Rewriting history would now require:
  - Rewriting Zenon **and**
  - Rewriting Bitcoin

That's what wallets label as:

**⚓ Anchored**

Not "more correct." Not "more valid." Just harder to undo.

---

## So Who Decides What's True?

In execution-first systems, truth is produced by a committee that executes.

If the validator set says "this is valid," it's valid — because they ran the computation.

In verification-first systems, truth is produced by evidence.

Different wallets can run different policies, which means recognition can differ temporarily:
- One wallet accepts quickly (ordered is enough for this user)
- Another waits for stricter verification (multiple Sentinel confirmations)
- Another waits for anchoring (needs external finality)

Truth is still objective (the evidence either verifies or it doesn't), but when you recognize it can vary.

That's not a bug.

It's what happens when verification becomes local again.

### The Convergence Property

Eventually, all honest verifiers converge:
- Invalid claims are rejected
- Valid claims are accepted
- Disputes are resolved

But convergence can happen at different speeds for different users.

A merchant might accept "ordered" for a coffee. An exchange might require "verified + anchored" for a withdrawal.

Both are rational. Both are using the same underlying reality. They just have different risk tolerances.

### The Trust Model Shift

**Execution-first:** "I trust the validator set to execute correctly."

**Verification-first:** "I trust math to verify evidence correctly."

You still need to trust:
- That the evidence you received is the real evidence (data availability)
- That your verification implementation is correct (software trust)
- That your hardware isn't compromised (local trust)

But you don't need to trust:
- That a specific set of nodes executed correctly
- That a committee was honest
- That a validator set didn't collude

The trust is local and mathematical, not social and delegated.

---

## The Quiet End

If Part III was the future you can feel…

Part IV is the map.

Zenon works (as a verification-first architecture) because roles are separated:
- Pillars/Momentum order
- Sentinels verify
- Sentries help move/produce evidence
- Clients decide acceptance policies
- Executors produce claims and receipts
- Anchors provide external finality witnesses

Execution can be anywhere.

ZApps can run on specialized hardware, in private enclaves, on rollups, in games — anywhere that can produce a verifiable claim.

Verification can be everywhere.

Wallets verify. Sentinels verify. Users verify. Services verify.

Verification isn't centralized in a validator set. It's ambient.

### The Architecture's Defense

The architecture defends itself through separation of concerns:
- If executors lie, verifiers catch them
- If verifiers are wrong, you can verify yourself
- If ordering censors, you can see what's missing
- If anchors fail, local ordering continues

No single actor has enough power to corrupt the system.

### The Scaling Path

And because roles are separated, each can scale independently:
- Ordering scales by optimizing consensus
- Execution scales by specializing environments
- Verification scales by parallelizing checks
- Evidence scales by improving proof systems

You don't need to scale everything at once.

You scale the bottleneck.
