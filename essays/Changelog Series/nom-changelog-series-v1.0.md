# NoM Changelog Series: V1.0

### May 30 to July 30, 2026

---

## What this is

Zenon development happens in public, on GitHub, in repositories anyone can clone. It is not visible, because it lives in diffs and almost nobody reads diffs.

This series closes that gap. Intermittently, whenever enough has accumulated, it goes into the repositories, pulls out what changed, and writes it down in plain language. Every entry links to the commit or pull request it came from.

## Why

Months of protocol work pass with the community knowing roughly nothing about it. That is a communication failure, not a development one. The work below was done in the open by people who were not asked to announce it, and it deserves a record that does not require you to read Go.

Nothing here has to be taken on faith. Every link is permanent. Check the ones you doubt.

## Contributors this period

**Wrote code or specifications in this period:**

| Contributor | Where |
|---|---|
| [digitalSloth](https://github.com/digitalSloth) | go-zenon, TypeScript SDK, nom-ui, web wallet, design system |
| [maznnwell](https://github.com/maznnwell) | Syrius desktop wallet, Dart SDK |
| [0x3639](https://github.com/0x3639) | Governance and Multisig ZIPs, go-zenon, devnet, web wallet |
| [TminusZ](https://github.com/TminusZ) | Project Zeno specification corpus |
| [coinselor](https://github.com/coinselor) | Taproot artifact verification in the commons |

**Code that landed in this period but was written earlier.** Worth stating separately, because a merge date is not an authorship date and the difference here is measured in years:

| Contributor | Work | Authored | Merged |
|---|---|---|---|
| [vilkris](https://github.com/vilkris4) | account pool performance | May 2024 | July 2026 |
| [vilkris](https://github.com/vilkris4) | chain cache | May 2024 | July 2026 |
| [vilkris](https://github.com/vilkris4) | dynamic plasma implementation | May 2025 | July 2026 |
| [georgezgeorgez](https://github.com/georgezgeorgez) | RPC unmarshal fixes | December 2024 | July 2026 |
| [mehowz](https://github.com/mehowz) | x/crypto dependency bump | April 2026 | July 2026 |

Two years of finished work sat unmerged. Part of what happened in this period is that someone went and merged it.

## Branch key

`master` is the release line. `dev` is the development line, where work lands first. Every entry names its branch.

---

# go-zenon

## Protocol

**Merkle state root**
[`56ce2c3`](https://github.com/digitalSloth/go-zenon/commit/56ce2c384966f2f1940967257a0788d3998a5eef) · 56 files, +11,076 · `feature/merkle-state-root`, spork gated

A sparse Merkle tree over the chain's entire key value state. The 32 byte root is written into the momentum header from version 3 onward, so it is covered by the pillar's signature. Every node recomputes it and rejects the momentum on mismatch. Hashing rules are frozen and consensus visible in [`common/trie/hash.go`](https://github.com/digitalSloth/go-zenon/blob/56ce2c384966f2f1940967257a0788d3998a5eef/common/trie/hash.go): SHA3 256, full depth, constant zero empties.

*What it does:* makes state verifiable rather than merely reported. A node that corrupts state is caught at the next block by everyone.

**State proof RPCs**
[`rpc/api/ledger.go`](https://github.com/digitalSloth/go-zenon/blob/56ce2c384966f2f1940967257a0788d3998a5eef/rpc/api/ledger.go)

`getStateRoot` and `getProof`. Returns a compact receipt proving a key held a value at a height, or was absent. Roughly 100 bytes plus the value.

*What it does:* lets anyone check a balance against a signed header with a hash function and nothing else.

**Storage free proof verifier**
[`common/trie/proof.go`](https://github.com/digitalSloth/go-zenon/blob/56ce2c384966f2f1940967257a0788d3998a5eef/common/trie/proof.go)

Verification depends only on crypto and types. No database, no chain access.

*What it does:* the same verifier can run in a phone wallet, in a contract on another chain, or in a dispute referee.

**Light client example**
[`cmd/prove-balance/main.go`](https://github.com/digitalSloth/go-zenon/blob/56ce2c384966f2f1940967257a0788d3998a5eef/cmd/prove-balance/main.go)

About 150 lines. Fetches a momentum and a balance proof from a node, verifies against the header.

*What it does:* demonstrates the primitive end to end. Runnable today.

**Offline state tree prebuild**
[`app/action_state_tree.go`](https://github.com/digitalSloth/go-zenon/blob/56ce2c384966f2f1940967257a0788d3998a5eef/app/action_state_tree.go) · [`docs/STATE_TREE_PREBUILD.md`](https://github.com/digitalSloth/go-zenon/blob/56ce2c384966f2f1940967257a0788d3998a5eef/docs/STATE_TREE_PREBUILD.md)

`znnd state-tree prebuild` builds the tree from a frozen database copy while the old binary stays online.

*What it does:* lets operators prepare for activation without downtime.

**libp2p networking**
[PR #59](https://github.com/zenon-network/go-zenon/pull/59) → [`9d566c0`](https://github.com/zenon-network/go-zenon/commit/9d566c0589c34da63d0dd7a4ccfc4424a60518b7) · `dev`, spork gated

Replaces the peer to peer layer, running alongside the legacy stack with a spork controlled switch. Includes persistent peerstore in LevelDB, DHT discovery, NAT port mapping, shutdown race and message size fixes, and a reinstated `Libp2pSpork` in the implemented sporks map.

*What it does:* a transport reachable from a browser, which removes the requirement that every user go through somebody's server.

**Dynamic plasma**
[PR #63](https://github.com/zenon-network/go-zenon/pull/63) → [`4e3ee65`](https://github.com/zenon-network/go-zenon/commit/4e3ee659620064758f639f54c032c07e73469f42) · `dev` · base implementation by [vilkris](https://github.com/vilkris4), authored May 2025; hardening by [digitalSloth](https://github.com/digitalSloth) this period

Fusion and proof of work prices adjust per momentum instead of sitting at fixed constants. Version 2 momentums carry next prices in the header. This period hardened the fusion required plasma calculation against overflow, moved price clamps to big integer arithmetic, recomputed canonical base plasma inside the momentum verifier, read spork status from the chain cache, and closed pricing test coverage gaps.

*What it does:* makes throughput cost respond to demand, so a feeless network is not a free denial of service surface.

**Protocol native multisig accounts**
[PR #72](https://github.com/zenon-network/go-zenon/pull/72) → [`8f2eddb`](https://github.com/digitalSloth/go-zenon/commit/8f2eddb2b4790e022fe8057aac739c4c99788e8d) · `feature/multisig-addresses` · implementation [digitalSloth](https://github.com/digitalSloth), specification [0x3639](https://github.com/0x3639)

A third address type beside user and embedded contract, whose blocks are valid only when carrying exactly N of M ed25519 signatures. A new registry contract at `z1qxemdeddedxmultysygxxxxxxxxxxxxx42zwd4` holds each account's threshold, signer set and lock state, with two methods: `CreateMultisig` and `ChangePolicy`. The address derives from the creation event rather than the policy, so rotating signers never changes the address. Policy changes stage for 60 momentums before taking effect, so a change is publicly visible before it is live. No key ceremony and no aggregate key: this is plain signature counting over ordinary wallet keys.

*What it does:* lets the protocol itself understand a committee. Every operational authority on the network today is a single keypair, and a single keypair fails absolutely. This is the account type that can replace them.

## Correctness

**Verify before broadcast**
[PR #60](https://github.com/zenon-network/go-zenon/pull/60) → [`d41d0b5`](https://github.com/zenon-network/go-zenon/commit/d41d0b55106959f22611a8ad7ad730f055ff821b) · `dev`

A momentum is fully verified before it is propagated to peers.

*What it does:* stops a node relaying something it has not finished checking.

**Canonical chain rollback on failed insert**
[`990cac2`](https://github.com/zenon-network/go-zenon/commit/990cac2eeea662dbb545625e0cae42882b46480d) · `dev`

Failed momentum insertion rolls the canonical chain back rather than leaving it half applied.

**Insert validation before listener notification**
[`2a63b9c`](https://github.com/zenon-network/go-zenon/commit/2a63b9c9b97683cd782158a071d94ea16872d6b3) · `dev`

Validation completes before any listener is told a momentum landed.

**Atomic chain and cache transitions**
[fork PR #2](https://github.com/digitalSloth/go-zenon/pull/2) → [`34e9df9`](https://github.com/zenon-network/go-zenon/commit/34e9df9abff6b805304ec81a89d3fd670237414b) · [0x3639](https://github.com/0x3639) · `dev`

Chain and cache state transitions are atomic. An interrupted rollback fails closed instead of continuing optimistically.

*What it does:* a node that loses power mid write comes back knowing what it does and does not know.

**Account block presence check in content verification**
`dev`

Checks account block presence before the batch check during momentum content verification.

**Governance voting ratchet**
[`2fb402a`](https://github.com/0x3639/go-zenon/commit/2fb402a5da17af204769a0702d755c40e26bb503) and [`81c2474`](https://github.com/0x3639/go-zenon/commit/81c2474088596d0ae59d935fbc5ba941fa02e98a) · [0x3639](https://github.com/0x3639) · `codex/governance-ratchet`, with devnet validation on `codex/governance-ratchet-devnet`

Implements the rising vote threshold described in the Governance ZIP, on top of the earlier governance v1 work, plus hardened action validation and an updated spork identifier.

**Node crashing nil dereference in the InsertChain side chain path**
[`b304d10`](https://github.com/0x3639/go-zenon/commit/b304d10596b7a3f246e154229cf60bf942b9b0ee) · [0x3639](https://github.com/0x3639) · `bugfix/catalogue-batch-1`

*What it does:* removes a way to crash a node.

## Performance and caching

**Account pool performance**
[PR #43](https://github.com/zenon-network/go-zenon/pull/43) → [`70ad9ce`](https://github.com/zenon-network/go-zenon/commit/70ad9ce61a99a2f5d384fcc02602c57e4b12fb37) · [vilkris](https://github.com/vilkris4) · authored May 2024, merged July 2 · `dev`

Rebuild and by-address lookups became unacceptably slow with many account chains holding hundreds of pending blocks each.

**Chain cache**
[PR #44](https://github.com/zenon-network/go-zenon/pull/44) → [`040c51f`](https://github.com/zenon-network/go-zenon/commit/040c51fbd52ae8a38c88d4b3d9637a2bb4d52e0e) · [vilkris](https://github.com/vilkris4) · authored May 2024, merged July 10 · `dev`

Stores the state needed to validate an account block that acknowledges an old momentum, so the node no longer has to roll the database back to that height to check it.

**Account pool cache hardening**
[PR #64](https://github.com/zenon-network/go-zenon/pull/64) → [`0498746`](https://github.com/zenon-network/go-zenon/commit/04987467549b26286b8056c14111f37ab43005a5) · [0x3639](https://github.com/0x3639) · `dev`

Defensive copies of cached blocks, `getAccountManager` hoisted out of the per height loop, and copy tests covering slice and pointer fields plus descendants.

*What it does:* a caller holding a reference can no longer mutate shared node state underneath it.

**Chain cache fix and height 1 spork guard**
[PR #67](https://github.com/zenon-network/go-zenon/pull/67) → [`0f87f0f`](https://github.com/zenon-network/go-zenon/commit/0f87f0fe86a012ba9dd536d4671724049f98e08b) · `dev`

## RPC fixes

**`GetAccountBlocksByPage` more property**
[PR #51](https://github.com/zenon-network/go-zenon/pull/51) → [`834971a`](https://github.com/zenon-network/go-zenon/commit/834971a2cd48af17795fde07518144bb11faae8f) · [0x3639](https://github.com/0x3639)

**Plasma `isRevocable` field in `getEntriesByAddress`**
[PR #52](https://github.com/zenon-network/go-zenon/pull/52) → [`abeeb06`](https://github.com/zenon-network/go-zenon/commit/abeeb06ae8ed3b396cabc7ef406d1f9c374b15c0) · [0x3639](https://github.com/0x3639)

**Unwrap request sorting**
[PR #57](https://github.com/zenon-network/go-zenon/pull/57) → [`1575e6b`](https://github.com/zenon-network/go-zenon/commit/1575e6b50aab286f3aa6794c9e85eb79d4b0bc9c) · [0x3639](https://github.com/0x3639)

`GetAllUnwrapTokenRequests` now sorts by registration momentum height, with a regression test that exercises stability rather than relying on Go's sort internals.

**Dependency trim to x/crypto only**
[PR #56](https://github.com/zenon-network/go-zenon/pull/56) → [`e01f5c2`](https://github.com/zenon-network/go-zenon/commit/e01f5c2560c1a9af0f30ea560e09fb5205077772) · [mehowz](https://github.com/mehowz)

**RPC JSON unmarshal fixes**
[PR #49](https://github.com/zenon-network/go-zenon/pull/49) → [`b237996`](https://github.com/zenon-network/go-zenon/commit/b2379964fefec98f5c18581f5706540d38ecaf5c) · [georgezgeorgez](https://github.com/georgezgeorgez) · authored December 2024

**Catalogue batch 1**
[`bugfix/catalogue-batch-1`](https://github.com/0x3639/go-zenon/tree/bugfix/catalogue-batch-1) · [0x3639](https://github.com/0x3639) · 62 commits

A batch of RPC and protocol fixes filed together with a per commit review guide. Page size limits enforced on bridge wrap and unwrap listings and on accelerator `GetAll`; checksummed address matching in wrap request filters; stable unconditional sorting for unwrap requests; removed pair unwraps filtered before counting and pagination; consistent error policy across bridge listings; subscriptions fail after stop instead of blocking; frontier errors no longer swallowed in sentinel info conversion; dead code and unused struct fields removed.

## Test infrastructure

**Dockerized devnet**
[PR #58](https://github.com/zenon-network/go-zenon/pull/58) → [`39baf89`](https://github.com/zenon-network/go-zenon/commit/39baf89d24d164f814e2db65b9fa4db591429bab) · `dev`

Multi node local network in one command, with funded test accounts and an explorer service.

*What it does:* anyone can test a protocol change without privileged access to somebody's infrastructure.

**Devnet sync node**
[`d334e0b`](https://github.com/zenon-network/go-zenon/commit/d334e0b6bdf310115137464b086f63c9bdefde85) · `dev`

A dedicated node for observing how a late joiner behaves.

**Devnet topology hardening, explorer service, additional funded accounts**
[fork PR #1](https://github.com/digitalSloth/go-zenon/pull/1) → [`df93ea9`](https://github.com/zenon-network/go-zenon/commit/df93ea99cf9cd3c0c1d6ca52ef2a7eca7d194a3d) · [0x3639](https://github.com/0x3639) · `dev`

**Devnet bootstrap peers and minimum connection settings**
[`22e2938`](https://github.com/zenon-network/go-zenon/commit/22e2938753fd592fad627e46196818faa78c61e8) · `dev`

## CI

**PR test workflow**
[`868af12`](https://github.com/digitalSloth/go-zenon/commit/868af12cc2ed295deee838faed1e01cdc9b1bcef) · [PR #70](https://github.com/zenon-network/go-zenon/pull/70)

**Workflow permissions and concurrency hardening**
[`7bd0858`](https://github.com/digitalSloth/go-zenon/commit/7bd0858bd3768682fba86cce971e8969bc9b9570)

**Pre release builds from dev and testnet**
[`59ec3c6`](https://github.com/digitalSloth/go-zenon/commit/59ec3c68f2b1af3789f6caec5f1cfc0f0bf34e09)

*What it does:* anyone can grab a binary and test the above without compiling anything.

## Experimental branches

**Vested pillars**
[`25430de`](https://github.com/digitalSloth/go-zenon/commit/25430de8d7b69543f618194921a819f2915234a5) · `feature/vested-pillars`

**Embedded WASM prototype**
[`0c363b9`](https://github.com/digitalSloth/go-zenon/commit/0c363b927f8f0ef08757a0cfae17409750d492a0) · `feature/wasm-embedded`

In core WASM execution with deterministic replay tooling. Established what in core execution costs and fed into the separate executor architecture the specification adopted.

---

# Syrius desktop wallet

**Feature oriented rearchitecture**
[PR #148](https://github.com/zenon-network/syrius/pull/148), [PR #150](https://github.com/zenon-network/syrius/pull/150), [PR #152](https://github.com/zenon-network/syrius/pull/152) → [`27091e2a`](https://github.com/zenon-network/syrius/commit/27091e2a5d1e16ae566220950f0b2ca3348caa38) · [maznnwell](https://github.com/maznnwell) · 153 commits · [`zenon-network/syrius`](https://github.com/zenon-network/syrius/tree/develop) `develop`

Pillars, sentinels, staking, plasma, tokens and transfer each become their own module with their own state handling, tests and documentation, replacing state scattered through the interface. The current head of `develop` in the official repository is this work.

*What it does:* makes the wallet a codebase a stranger can contribute to.

**Integration tests against a live devnet**

The suite starts a real devnet, waits until the node is synced and producing momentums, then drives the wallet through creating a pillar, depositing pillar QSR, registering a sentinel, opening a stake and fusing plasma.

*What it does:* tests the wallet against the chain rather than against mocks.

**`NodeNotSyncedException`**

*What it does:* the wallet stops answering questions its node cannot actually answer.

**CI for code quality and test coverage on every pull request**

**macOS packaging fix**

**Dart SDK adjustments**
[`16bf294`](https://github.com/maznnwell/znn_sdk_dart/commit/16bf294b3e347cb4f9c1f47a7da5d60034724f95), [`e419eec`](https://github.com/maznnwell/znn_sdk_dart/commit/e419eec4f6c22f68adb31eb56b24c6a71f93a5a4) · [znn_sdk_dart](https://github.com/maznnwell/znn_sdk_dart) `refactor` branch

Serialization additions and an unused field removed, supporting the wallet work above.

Note: the wider rearchitecture line also carries roughly 80 commits from [kossmmos](https://github.com/kossmmos) and CryptoFish laid down before this period. Against `master`, `develop` now stands at 979 files changed and +60,951 lines.

---

# Governance and Multisig ZIPs

Written by [0x3639](https://github.com/0x3639) and published for community comment on the HyperCore forum. These are formal specifications, not code, and they are what PR #72 above implements.

**Governance ZIP, created May 31, revised to v2.3**
[Draft](https://forum.hypercore.one/t/draft-governance-zip-working-draft-for-comment/935) · [changelog and implementation notes](https://forum.hypercore.one/t/governance-zip-changelog/941) · [tl;dr](https://forum.hypercore.one/t/governance-zip-v1-tl-dr-and-what-changed/936)

Adds a `GovernanceContract` at `z1qxemdeddedxg0vernancexxxxxxxxxxxklyh23` in which Pillars propose and Pillars vote, on exactly two classes of action: creating and activating sporks, and setting a single `networkAdmin` address. Proposals require an active Pillar's registered owner address and a refundable 100 ZNN deposit. Undecided votes enter a bounded ratchet where each round lowers the participation bar and raises the approval bar. Written from May 31 and revised five times inside this period. The original implementation is [PR #47](https://github.com/zenon-network/go-zenon/pull/47) by sumoshi21.

The core problem it addresses: every privileged role on the network is a single key, and two of those keys have already failed. The legacy spork signer's whereabouts are unknown, which means no spork can currently be activated at all. The plasma `GovernanceAddress` is a placeholder gating live consensus parameters on one holder.

*What it does:* moves spork authority and administrative authority to a Pillar vote, and replaces the per contract administrator roles on Bridge, Liquidity and Plasma with a single `networkAdmin` that Pillars can repoint.

Notable revisions in the window:

- **v2** redefined the second action type as `SetNetworkAdministrator` after review found the v1 design infeasible against the actual multisig implementation. Plasma parameters joined the migration, closing the placeholder backdoor.
- **v2.1** addressed an independent adversarial review, including a spork activation sequence that would otherwise have terminated every upgraded node at enforcement, and two administrative methods found to be already stranded behind the unreachable legacy signer.
- **v2.2** moved multisig activation from a spork to a hard fork height, and specified how Pillars signal readiness: an automated once per epoch zero amount block carrying a feature marker, consensus neutral under pre fork rules and measurable by anyone. The chain never evaluates the signal; it is measurement for human scheduling, not a consensus trigger.
- **v2.3** editorial, following an external review that confirmed cross ZIP consistency, the threshold arithmetic, and that the activation dependency graph is acyclic.

**Multisig ZIP, v1**
[Draft](https://forum.hypercore.one/t/draft-multisig-zip-working-draft-for-comment/940)

The specification behind PR #72, verified against commit `8f2eddb2`. Covers address derivation, the registry contract, verifier rules, capability limits, RPC visibility and activation, with a pre merge review checklist of six items the implementation still needs.

*What it does:* pins the behaviour precisely enough that a second implementation could be written from the document and agree with the first.

---

# Zenon developer commons

**Taproot artifact rendering restored, with a byte level verifier**
[`7594569`](https://github.com/TminusZ/zenon-developer-commons/commit/75945697c414fa58d045c0f68a10d90aa09e35ca) · [PR #38](https://github.com/TminusZ/zenon-developer-commons/pull/38) · [coinselor](https://github.com/coinselor)

Corrects the canonical rendering of the on-chain Taproot artifact in the commons puzzle documentation: exact `OP_RETURN` spacing, canopy and trunk ASCII rows fixed against the on-chain data, and updated canopy measurements. Adds a Go verifier that checks the machine specification claims byte for byte rather than asking readers to trust the transcription.

*What it does:* makes a documented on-chain artifact independently checkable instead of visually reproduced.

---

# Project Zeno specification

**Corpus v1.3 to v1.6.0, executor document to v0.3.0**
[Project Zeno corpus](https://github.com/TminusZ/zenon-developer-commons/tree/main/Project%20Zeno) · published by [TminusZ](https://github.com/TminusZ)

Describes an off chain WASM execution layer settled on Zenon L1 under one invariant: consensus orders, executors compute, settlement anchors.

**Generalized bridge framework as reserved schema**

Two independent trust ladders per domain, domain classes for execution, bridge and messaging, custody modes, and abstractions for chain verification and release. Phase 1 pins a single active configuration.

*What it does:* fixes the shape of bridge support in the schema now, so it arrives through a spork gated release rather than an improvised one.

**21 ticket engineering plan**

Each ticket scoped, sequenced and pinned to the specification section it implements.

---

# TypeScript and JavaScript stack

**SDK migrated to native `bigint`**
[`c1c17cf`](https://github.com/digitalSloth/znn-typescript-sdk/commit/c1c17cfb28d0b3274259446ed0778eed5b95c081) · [znn-typescript-sdk](https://github.com/digitalSloth/znn-typescript-sdk)

Off a big number library and onto the language primitive.

**Key derivation parameters and keyfile encryption**
[`4eebf6e`](https://github.com/digitalSloth/znn-typescript-sdk/commit/4eebf6e83b97ce1ee6c9a04a62bee9ca056854c1)

**Secure key destruction**
[`68dad0e`](https://github.com/digitalSloth/znn-typescript-sdk/commit/68dad0e3aca47437f7f3cab1d4ad63b0617c7dd8)

Wipes key material from memory on command.

**Proof of work handling**
[`83eafc2`](https://github.com/digitalSloth/znn-typescript-sdk/commit/83eafc224c4a0e0ebad3506c3349cec0126da4dd)

**nom-ui component library**
[`4e3009f`](https://github.com/digitalSloth/nom-ui/commit/4e3009fb54f4b214aea31c43f155cfbabe0416e0) and 8 further commits · [nom-ui](https://github.com/digitalSloth/nom-ui)

Vue component library, created this period.

**nom-webwallet**
[nom-webwallet](https://github.com/digitalSloth/nom-webwallet) · 14 commits, 4 by [0x3639](https://github.com/0x3639)

Network configuration persistence, adoption of the nom-ui primitives, a service class refactor, a plasma level feature, wallet encryption hardening, plasma bot integration and deploy hardening.

**zenon-design-system**
[`8d2f76d`](https://github.com/digitalSloth/zenon-design-system/commit/8d2f76d74a286bd722f1fb62f280d89740ca29a8) · [zenon-design-system](https://github.com/digitalSloth/zenon-design-system)

*What this stack does:* a proof is only useful where a person can check it. This is the layer that reaches the browser.

---

*NoM Changelog Series V1.0, covering May 30 to July 30, 2026. Every commit hash was independently resolved against a fresh clone of the repository named before publication. Each entry names the branch its work lives on. A record of what was written and where it lives, not financial advice or a commitment about timing.*
