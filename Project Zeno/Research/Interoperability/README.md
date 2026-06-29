# Project Zeno Interoperability Research

**Status:** Research folder  
**Purpose:** Chain-specific interoperability design studies for Project Zeno  
**Governing boundary:** `../Frontier/` defines the safety rails for this folder  
**Commit discipline:** This folder is not a roadmap, product claim, bridge announcement, or implementation guarantee.

---

## 1. Purpose

This folder contains interoperability research for Project Zeno.

The goal is to study how Project Zeno Domain Settlement could interact with external networks such as Bitcoin, Ethereum, Solana, Move-based chains, Cosmos chains, and other systems.

These documents are not bridge announcements.

They are design studies.

Each study asks:

- what external facts can be verified;
- what evidence can be relayed;
- what a domain STF can check;
- what Settlement can account for;
- what assets Settlement can release;
- what requires external custody;
- what requires future proof systems;
- what remains out of scope.

The purpose is to decompose interoperability honestly.

---

## 2. Relationship to Frontier

The `../Frontier/` folder defines the boundary rules.

This `Interop/` folder applies those rules to specific chains.

The distinction is:

```text
Frontier/ = boundary discipline
Interop/  = chain-specific design studies
```

Before any interoperability document in this folder makes a claim, it must respect the Frontier boundaries:

- relayers transport evidence; they are not custodians;
- proof-shaped data is not the same as observed data;
- event verification is not custody;
- messaging is not bridging;
- `DAHash` is not availability;
- relay proof verification is inclusion verification, not root correctness;
- runtime compatibility is not external-chain custody;
- Sentinel suitability is not protocol assignment;
- QSR service collateral is speculative unless specified;
- Phase 1 is bonded attestation, not trustless execution.

If an Interop document conflicts with a Frontier boundary document, the Frontier boundary wins.

If any document conflicts with `SPEC.md`, `SPEC.md` wins.

---

## 3. Core interoperability model

Every interoperability design should be decomposed into five separate layers:

```text
Verification
Accounting
Messaging
Custody
Enforcement
```

These layers must not be collapsed.

### Verification

Verification asks:

```text
Can a Project Zeno domain verify that something happened externally?
```

Examples:

- a Bitcoin transaction was included in a block;
- an Ethereum event was emitted;
- a receipt exists under a finalized root;
- a Solana account changed state;
- a validator set signed a checkpoint;
- an oracle observed a value.

Verification produces evidence.

It does not produce asset control.

### Accounting

Accounting asks:

```text
Can a domain update internal state based on verified or observed evidence?
```

Examples:

- minting a wrapped claim after a verified deposit;
- recording a burn request;
- tracking processed deposits;
- tracking withdrawal authorizations;
- updating an internal balance.

Accounting records claims.

It is not the external asset itself.

### Messaging

Messaging asks:

```text
Can a message, proof, claim, or authorization move through Settlement?
```

Examples:

- outbox messages;
- relay proofs;
- withdrawal authorizations;
- proof-shaped inputs;
- cross-domain messages.

Messaging routes evidence or instructions.

It does not automatically imply external-chain asset movement.

### Custody

Custody asks:

```text
Who controls the external asset?
```

Examples:

- Settlement custody for ZTS assets deposited into Settlement;
- Bitcoin script custody;
- Ethereum lockbox contract custody;
- threshold-signer custody;
- multisig federation custody;
- custodial operator custody;
- BitVM-style optimistic enforcement custody.

Custody is control.

It is not knowledge.

### Enforcement

Enforcement asks:

```text
What happens when someone lies, withholds data, refuses service, or tries to steal?
```

Examples:

- Settlement rejecting an invalid withdrawal;
- `processedOutbox` blocking replay;
- conservation invariant preventing aggregate over-release;
- Phase 2 fraud proofs;
- Phase 3 validity proofs;
- external-chain challenge games;
- slashing or bond loss;
- signer-set accountability.

Enforcement is where the trust model becomes concrete.

---

## 4. Naming discipline

This folder should use the term **Authorization Domain** for early chain-specific designs.

Preferred names:

```text
BTC Authorization Domain
ETH Authorization Domain
SOL Authorization Domain
Move Authorization Domain
Cosmos Authorization Domain
```

Avoid naming early studies as bridges.

Do not use:

```text
BTC Bridge
ETH Bridge
SOL Bridge
Zeno Bridge
Trustless Bridge
Non-custodial Bridge
```

unless the document actually specifies the full bridge stack:

```text
verification + accounting + custody + release + enforcement
```

Most early designs are not full bridges.

They are authorization layers.

A chain-specific authorization domain may verify external evidence, update internal accounting, and emit withdrawal authorizations. That is meaningful. But it is not the same as controlling native external-chain assets.

---

## 5. Required status language

Every document in this folder must include a status block.

Use this pattern:

```md
**Status:** Interoperability research  
**Phase status:** Forward-looking; depends on machinery reserved or out of scope today  
**Purpose:** Define a chain-specific authorization-domain design and its trust boundaries  
**Governing document:** `SPEC.md` governs on any conflict  
**Boundary discipline:** `../Frontier/` governs interoperability safety claims  
**Commit discipline:** This file is not a roadmap, bridge announcement, product claim, or implementation guarantee.
```

If the document depends on reserved Project Zeno machinery, say so explicitly.

Examples:

- `inputSource = L1_RELAYED` is reserved in Phase 1.
- `EXTERNAL_OBSERVED` is reserved in Phase 1.
- bridge-token issuance is out of Phase 1 scope.
- external-chain custody is out of current Settlement scope.
- relayer/watchtower tooling may not exist in-tree.
- Phase 2 fraud proofs are deferred.
- Phase 3 validity proofs are deferred.
- Sentinel service markets are not specified.
- QSR service bonding is not assigned by the spec.

---

## 6. Required sections for chain-specific studies

Each chain-specific interoperability document should use this structure unless there is a strong reason not to.

```text
1. Status and purpose
2. One-sentence thesis
3. What this design can verify
4. What this design can account for
5. What this design cannot custody
6. Deposit or inbound flow
7. Withdrawal or outbound authorization flow
8. Custody model
9. Relay model
10. DA and proof-serving assumptions
11. Watcher / challenger assumptions
12. Phase status
13. Security assumptions
14. Failure modes
15. Unsafe claims
16. Open questions
17. Minimal implementation boundary
18. Acceptance tests
19. Summary
```

The most important sections are:

```text
What this design cannot custody
Custody model
Failure modes
Unsafe claims
Minimal implementation boundary
```

Those sections prevent design studies from turning into bridge marketing.

---

## 7. Chain study categories

Interop studies should be grouped by the type of evidence the external chain can provide.

### SPV-friendly chains

Chains where inclusion proofs and header verification can plausibly be checked inside a domain STF.

Example:

```text
Bitcoin
```

Typical design shape:

```text
header relay
proof-of-work verification
Merkle transaction inclusion
confirmation depth
deposit descriptor matching
wrapped claim accounting
external custody mechanism required for withdrawal
```

### Finality-proof chains

Chains where finalized checkpoints, validator signatures, or consensus proofs may be relayed.

Example:

```text
Ethereum
```

Typical design shape:

```text
finalized header / checkpoint verification
receipt or storage proof verification
event verification
lockbox event detection
wrapped claim accounting
external contract or signer custody required for redemption
```

### High-throughput account-state chains

Chains where proof formats, validator-set dynamics, and account-state verification may be harder to fit into a simple domain STF.

Example:

```text
Solana
```

Typical design shape:

```text
feasibility study first
account proof research
finality and fork-choice analysis
proof-size analysis
custody model deferred
```

### Runtime-compatible chains

Chains whose execution environments could be implemented as Zeno domains.

Examples:

```text
EVM
Move
SVM
CosmWasm
Cairo
```

Important boundary:

Runtime compatibility is not asset custody.

An EVM domain on Zeno does not inherit Ethereum liquidity, Ethereum finality, Ethereum security, or Ethereum custody.

---

## 8. Required unsafe-claim table

Every chain-specific document must include an unsafe-claim table.

Minimum entries:

| Unsafe claim | Correct framing |
|---|---|
| This is a bridge | This is an authorization-domain study unless custody and release are specified |
| External event verification gives native asset custody | Verification produces evidence; custody requires external-chain control |
| Deposit detection solves withdrawal | Deposit verification and withdrawal release are separate problems |
| Wrapped assets are redeemable by default | Redeemability depends on the custody mechanism |
| Relayers secure the bridge | Relayers transport evidence; validity comes from STF verification and custody comes from the custody mechanism |
| Runtime compatibility gives asset liquidity | Runtime compatibility is execution compatibility only |
| Cross-domain messaging replaces bridges | Internal messaging is not external-chain asset custody |
| Sentinels provide the service by default | Sentinel role assignment requires explicit spec definition |
| QSR bonds the service | QSR bonding is speculative unless specified |
| Phase 1 is trustless | Phase 1 is bonded attestation |

Documents may add chain-specific unsafe claims.

---

## 9. Minimal implementation discipline

Every Interop study should separate:

```text
demo
testnet
signet/devnet
production
```

Do not collapse them.

A minimal implementation should usually prove the smallest useful claim first.

For Bitcoin, that may be:

```text
deposit verification + burn authorization
```

not a production BTC bridge.

For Ethereum, that may be:

```text
event verification + authorization accounting
```

not an ETH bridge.

For Solana, that may be:

```text
proof feasibility analysis
```

not a working SOL bridge.

The first implementation should avoid production custody until verification, accounting, proof formats, replay protection, and disclosure are stable.

---

## 10. Suggested file map

Suggested starting layout:

```text
Interop/
  README.md
  00_INTEROP_DESIGN_PRINCIPLES.md
  01_BTC_AUTHORIZATION_DOMAIN.md
  02_ETH_AUTHORIZATION_DOMAIN.md
  03_SOL_AUTHORIZATION_DOMAIN.md
  04_INTEROP_COMPARISON_MATRIX.md
```

Possible later additions:

```text
05_MOVE_AUTHORIZATION_DOMAIN.md
06_COSMOS_AUTHORIZATION_DOMAIN.md
07_EVM_RUNTIME_COMPATIBILITY_BOUNDARY.md
08_EXTERNAL_CUSTODY_MODELS.md
09_INTEROP_FAILURE_MODES.md
10_INTEROP_DISCLOSURE_REQUIREMENTS.md
```

Keep the folder small at first.

The first goal is not to cover every chain.

The first goal is to create a repeatable template that prevents overclaiming.

---

## 11. Current priority

The recommended first sequence is:

```text
00_INTEROP_DESIGN_PRINCIPLES.md
01_BTC_AUTHORIZATION_DOMAIN.md
02_ETH_AUTHORIZATION_DOMAIN.md
03_SOL_AUTHORIZATION_DOMAIN.md
04_INTEROP_COMPARISON_MATRIX.md
```

Bitcoin should come first because it provides the cleanest separation between:

```text
SPV verification
wrapped accounting
burn authorization
external custody
BitVM-style enforcement
```

Ethereum should come second because it clarifies a different model:

```text
finality proofs
receipt proofs
contract lockboxes
ERC-20 custody
EVM compatibility boundary
```

Solana should come third because it is more likely to require a feasibility-first approach.

---

## 12. Summary

This folder studies interoperability.

It does not announce bridges.

The design discipline is simple:

```text
Verification is not custody.
Accounting is not redemption.
Messaging is not bridging.
Runtime compatibility is not external-chain liquidity.
Relay is not signing.
Wrapped assets are claims.
Custody requires control.
Enforcement requires a specified mechanism.
```

Project Zeno's Domain Settlement architecture may support powerful interoperability patterns over time. But each pattern must be decomposed into its actual parts: what is verified, what is accounted for, what is messaged, what is custodied, and what is enforced.

That decomposition is the purpose of this folder.

Do not collapse the layers.
