Browser Light Client Architecture — Research Draft 

A research-oriented description of how a browser becomes a verifiable peer in a deterministic, proof-first blockchain architecture using Sentries, Supervisors, and Sentinels.



1. Purpose of the Browser Light Client

The browser light client is the minimal, universal verification node in the system.
It holds:

	•	no global state,
	•	no execution responsibilities,
	•	no historical data,
	•	no consensus role.

Instead, the browser performs local verification of compact proof bundles produced by Supervisors and anchored by Sentinels.
This enables trustless participation without RPC servers or centralized gateways.

The browser becomes a peer—not a full node—but a cryptographically independent verifier.



2. Operating Constraints

Because browsers operate under strict system limitations, the architecture pushes complexity upward:

Constraints:

	•	limited CPU and memory
	•	sandboxed execution model
	•	restricted networking (WebRTC/WebSocket)
	•	small persistent storage (IndexedDB)
	•	intermittent connectivity
	•	mobile-class hardware

The browser can only validate bounded, compact cryptographic commitments, not global state.

Thus:

	•	Sentries handle execution,
	•	Supervisors handle verification assembly,
	•	Sentinels handle anchoring,
	•	Browsers handle lightweight final validation.



3. Verification Responsibilities

The browser receives three categories of verifiable data:

3.1 Momentum Headers

The browser downloads:

	•	Momentum headers
	•	The Sentinel-provided bundle hash for that window

It verifies chain continuity without replaying state transitions.



3.2 State Proof Bundles

Bundles contain:

	•	account-chain block headers
	•	micro-PoW links
	•	zApp receipts
	•	deterministic ordering constraints

The browser recomputes the hash of the bundle and checks it against the Sentinel anchor.

No global state required.



3.3 Local Account State

For any account or zApp the user cares about, the browser:

	•	fetches only its frontier
	•	validates its transitions using the bundle
	•	reconstructs minimal local state

This eliminates global syncing and makes the browser a highly scalable verifier.



4. Networking Requirements

The browser uses a peer-to-peer networking layer, not RPC servers.

Transports:

	•	WebRTC
	•	WebSocket
	•	browser-compatible libp2p streams

Discovery:

	•	initial signaling via non-trusted bootstrap servers
	•	decentralized peer discovery thereafter
	•	direct access to Sentinel nodes for anchor data

Since all data is verifiable, peers need not be trusted.



5. Interaction With Node Layers

5.1 Sentries

Browsers do not accept unsolicited activity from Sentries.
Browsers only request historical data when needed:

	•	account-block chains
	•	PoW links
	•	zApp receipts

The browser verifies all of this against Supervisor bundles.



5.2 Supervisors

Browsers fetch Supervisor-generated bundles for each momentum window.

They validate:

	•	signatures
	•	ordering
	•	zApp input/output commitments
	•	linkage to Momentum anchors



5.3 Sentinels

Sentinels provide:

	•	canonical bundle hashes
	•	compressed proof availability
	•	discovery of final state transitions

The browser trusts no Sentinel; it only validates their commitments.



6. State Reconstruction Model

State reconstruction is:

	•	local
	•	on-demand
	•	proof-limited

The browser maintains:

	•	only accounts it cares about
	•	only proofs relevant to its interactions

This ensures:

	•	extremely low resource usage
	•	fast onboarding
	•	sustainable verification even on mobile devices



7. zApp Verification Model

zApps execute off-chain (Sentries) and produce local receipts. The browser:

	•	prepares inputs
	•	verifies outputs
	•	signs transitions
	•	submits them via Sentries

No global VM replay occurs.
The browser verifies commitments, not execution.



8. Momentum Window Handling

Momentum windows define the verification interval.

For each window the browser:

	1.	downloads the header
	2.	fetches the anchored hash
	3.	retrieves the state proof bundle
	4.	recomputes its commitments
	5.	applies only relevant account changes

This gives predictable, bounded verification costs.



9. Reorg Handling

If the canonical momentum changes:

	•	the anchor changes
	•	the browser invalidates the affected window
	•	it fetches the correct bundle
	•	re-verifies deterministically

Because bundles are compact, recovery is cheap.



10. Security Model

The browser trusts only:

	•	cryptographic commitments
	•	deterministic Supervisor rules
	•	cross-verified Sentinel anchors

The browser does not trust:

	•	peers
	•	relays
	•	Sentries
	•	Supervisors
	•	Sentinels
	•	application providers

All verification is local and deterministic.

This is true light-client sovereignty.



11. Why Browser Light Clients Matter

Browser-based verification enables:

	•	instant onboarding
	•	millions of verifiers instead of thousands
	•	no reliance on RPC servers
	•	censorship-resistant architectures
	•	decentralized application models
	•	global access without downloads
	•	a peer-to-peer network secured by cryptography, not infrastructure

This architecture is fundamentally different from classical blockchains.

It is not a “browser-friendly blockchain.”
It is a browser-native blockchain.
