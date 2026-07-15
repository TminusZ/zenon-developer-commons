# Ethereum Asset Authorization Domain

**Document status:** Chain specialization specification; forward-looking and not activation-ready  
**Version:** 0.3.0  
**Framework baseline:** `01-BRIDGE-FRAMEWORK-SPEC.md` v0.3.2  
**Domain identifier:** `d_eth_asset` (symbolic until registration)  
**Purpose:** Specialize the Generalized Authorization and Bridge Framework for poolless ETH and allowlisted ERC-20 custody in an Ethereum lockbox.

## 0. Authority and conformance

The active `SPEC.md` governs consensus-visible behavior. `01-BRIDGE-FRAMEWORK-SPEC.md` v0.3.2 governs Authorization Domains, claims, Settlement handlers, bridge accounting, peg-out records, and foreign enforcement. This document supplies only Ethereum-specific verifier state, evidence schemas, claim normalization, asset bindings, and deployment parameters.

On conflict, the governing framework controls. This document MUST NOT be interpreted to add an Ethereum-specific accounting path or a second bridge ledger.

The canonical governing invariant is:

> **Consensus orders. Execution computes. Authorization admits. Settlement accounts.**

The external boundary is:

> **Ethereum enforces through the `ReleaseAdapter` defined by the hash-pinned Ethereum Interop Enforcement Specification.**

The key words MUST, MUST NOT, REQUIRED, SHALL, SHALL NOT, SHOULD, SHOULD NOT, RECOMMENDED, MAY, and OPTIONAL are interpreted as RFC 2119 and RFC 8174 requirement terms when written in all capitals.

## 1. Status

This specialization cannot activate under the current Phase 1 profile. It depends on framework assumptions and artifacts that are reserved, deferred, or deployment-specific:

- **A1:** registration of additional domains;
- **A2:** activation of `L1_RELAYED`;
- **A4:** the `OPTIMISTIC` execution profile and fraud-proof referee;
- **A6:** Settlement issuance authority for `MINTED` representation assets;
- **A7:** a deployed Ethereum `ReleaseAdapter` and complete Interop Enforcement Specification;
- **A11:** the required canonical state and proof APIs;
- **A12:** the generalized `DomainRecord`;
- **A14:** the versioned foreign-destination timeout encoding;
- **A15:** claim encodings, `claimRoot`, and claim receipts;
- **A16:** the Settlement claim dispatcher and `BridgeLedger` handlers; and
- **OD-1:** resolution and activation of the MINTED Settlement Extension Specification.

Activation also requires the Ethereum verifier implementation, exact claim-schema artifacts, Core handler IDs, asset registry entries, value caps, chain-specific conformance vectors, and all fields of `ChainBinding` to be fixed and published.

This document does not claim a live ETH bridge, mainnet custody, native ETH on Zenon, deployed Ethereum light-client verification, or available solver liquidity.

## 2. Specialization thesis

The Ethereum asset bridge is the composition of four separately owned components:

1. an Ethereum lockbox that holds ETH or an allowlisted ERC-20;
2. `d_eth_asset`, an `AUTHORIZATION` domain that verifies finalized Ethereum evidence and emits typed claims;
3. Settlement's registered MINTED handlers, which alone mint, burn, account, and create peg-out records; and
4. the Ethereum `ReleaseAdapter`, which verifies a finalized Zenon `PegOutRecord` and releases custody exactly once.

`d_eth_asset` is only the second component. It is not the lockbox, bridge ledger, representation token contract, peg-out producer, or destination adapter.

The design is poolless because canonical redemption uses the lockbox's custody rather than a Zenon-operated liquidity pool. It is not custodyless.

## 3. Responsibility map

```text
Ethereum consensus and lockbox
    finalizes a lock or release event
        |
Permissionless relayer
    posts Ethereum light-client updates and evidence to Zenon L1
        |
d_eth_asset Authorization Domain
    verifies Ethereum finality and evidence
    updates verifier-local state
    emits AuthorizedClaim
        |
Settlement RelayClaim
    checks finality, policy, schema, replay, caps, handler, conservation
        |
Settlement BridgeLedger handler
    performs mint, release reconciliation, or refund accounting
        |
Local user redemption through Settlement
    burns representation and creates PENDING PegOutRecord
        |
Ethereum ReleaseAdapter
    verifies PENDING record, deadline, binding, and replay
    releases ETH/ERC-20 exactly once
```

Optional solvers and market makers sit outside this path. They may accelerate fulfillment under the Execution Provider Framework, but they do not change any claim, Settlement transition, or adapter rule in this specification.

## 4. Domain registration

### 4.1 Required `DomainRecord`

The target registration profile is:

```text
domainId       = d_eth_asset
domainClass    = AUTHORIZATION
runtimeKind    = WASM or another registered deterministic runtime
inputSource    = L1_RELAYED
execProfile    = OPTIMISTIC
foreignProfile = LIGHT_CLIENT
finalityModel  = CHALLENGE_WINDOW
chainBinding   = non-null Ethereum ChainBinding
claimPolicy    = non-null ASSET ClaimPolicy
status         = PAUSED until every activation condition is satisfied
```

`profileConfig` MUST identify the registered fraud referee and challenge window for `OPTIMISTIC`, plus the Ethereum sync-committee light-client kind and finality-rule hash for `LIGHT_CLIENT`. All remaining inherited fields, including executor set, proposer policy, value caps, and delays, MUST be fixed within Core bounds before activation.

This profile matches the framework's ETH worked example. A committee-backed demonstration or an attested execution variant is a different registered profile with a different `stfSpecHash`; it MUST NOT be presented as this `OPTIMISTIC` plus `LIGHT_CLIENT` profile.

### 4.2 Required output contract

Every batch from `d_eth_asset` MUST satisfy:

- `claimRoot` commits only policy-permitted `AuthorizedClaim` values;
- `ClaimEffectSummary` bounds the claim count and value by type and asset;
- `outboxRoot` is empty;
- `assetFlowSummary` is empty;
- `StateDiff` writes only the domain's verifier and claim-emission namespaces; and
- no effect credits, debits, mints, burns, reserves, escrows, releases, or modifies Settlement replay state.

A forbidden state write is a class violation and MUST halt the domain under the framework's failure rules.

### 4.3 Separate message domain

This domain has `claimPolicy.purpose=ASSET`. It MUST NOT emit `FOREIGN_MESSAGE`.

Ethereum-to-Zenon application messaging, if introduced, requires a separate `AUTHORIZATION` domain such as `d_eth_message`, with `purpose=MESSAGE`, separate capabilities, caps, replay scope, and `stfSpecHash`. Verifier code may be reused; policy authority may not.

## 5. Ethereum `ChainBinding`

The registered binding MUST define:

```text
ChainBinding {
    foreignChainId      = canonical Ethereum network identity
    chainVerifierId     = hash/registry ID of the ETH light-client verifier
    genesisAnchor       = canonical trusted light-client checkpoint
    releaseAdapterRef   = canonical Ethereum lockbox/adapter reference
    enforcementSpecHash = SHA3-256(exact Ethereum enforcement-spec bytes)
    finalityParams      = canonical Ethereum finality configuration
}
```

### 5.1 Network identity

`foreignChainId` MUST bind at least the EIP-155 chain ID and Ethereum genesis identity under the framework's canonical `ChainId` encoding. Chain ID alone is insufficient for a deployment that could be replayed against a fork or test network.

### 5.2 Verifier identity

`chainVerifierId` MUST identify the exact verifier implementation and schema version. It MUST cover:

- light-client update verification;
- supported Ethereum fork rules;
- execution-payload binding;
- receipt and log proof verification;
- account and storage proof verification for non-delivery;
- event ABI and topic hashes;
- amount normalization;
- recipient validation; and
- all canonical evidence and finality-reference encodings.

### 5.3 Genesis anchor

`genesisAnchor` MUST contain the bootstrap data required by the selected Ethereum light-client implementation. Its exact bytes are an activation parameter and MUST be reproducible from a finalized Ethereum checkpoint.

Changing the checkpoint outside the verifier's specified update rules is a `ChainBinding` and `stfSpecHash` migration, not an operator convenience.

### 5.4 Adapter reference and enforcement hash

`releaseAdapterRef` MUST identify the deployed Ethereum contract or immutable adapter entry point. If a proxy is used, the Ethereum Interop Enforcement Specification MUST identify the proxy, implementation, administrator, storage layout, upgrade rules, and all custody powers.

`enforcementSpecHash` MUST be non-zero and equal the hash of the exact reviewed artifact bytes. The domain MUST remain inactive when the artifact is missing, incomplete, inconsistent with `releaseAdapterRef`, or not substantively reviewed.

The hash proves artifact identity. It does not prove semantic adequacy, deployed-code correspondence, or reviewer diligence.

### 5.5 Finality parameters

`finalityParams` MUST pin:

- supported network and fork schedule or fork-rule registry;
- genesis validators root or equivalent immutable consensus identity;
- accepted light-client update rules;
- sync-committee participation threshold;
- finalized-checkpoint predicate;
- execution-payload-header binding;
- maximum accepted proof age;
- proof size and resource bounds; and
- the finality reference encoding used by each claim schema.

Any semantics-changing update requires a delayed domain migration and new `stfSpecHash`.

## 6. Claim policy

### 6.1 Policy shape

The initial policy is:

```text
ClaimPolicy {
    policyVersion    = ETH_ASSET_POLICY_V1
    purpose          = ASSET
    capabilities     = [
        ETH_FOREIGN_LOCK_V1,
        ETH_FOREIGN_RELEASE_V1,
        ETH_FOREIGN_NON_DELIVERY_V1
    ]
    activationHeight = deployment parameter
    exitDelay        = deployment parameter within Core bounds
}
```

`FOREIGN_MISCONDUCT` is intentionally absent from the initial policy. Adding it requires a policy-version bump, a registered bounded handler, a canonical evidence schema, and the full broadening delay. Stronger proof verification does not add the capability automatically.

The symbolic policy and capability labels in this document MUST be assigned their canonical `u32` or `bytes32` values in the deployment manifest. Symbolic names are not consensus-visible encodings.

### 6.2 Capability table

| Capability | `claimType` | `handlerId` | Asset scope | Settlement effect |
|---|---|---|---|---|
| `ETH_FOREIGN_LOCK_V1` | `FOREIGN_LOCK` | registered MINTED lock handler | allowlisted representation `AssetID` values | Record verified collateral and mint/credit atomically |
| `ETH_FOREIGN_RELEASE_V1` | `FOREIGN_RELEASE` | registered MINTED release handler | same allowlist | Move matching `PegOutRecord` from `PENDING` to `RELEASED` and reconcile collateral |
| `ETH_FOREIGN_NON_DELIVERY_V1` | `FOREIGN_NON_DELIVERY` | registered MINTED refund handler | same allowlist | Move matching `PegOutRecord` from `PENDING` to `REFUNDED` and remint to recorded refund recipient |

The exact `handlerId`, `claimSchemaHash`, value caps, and `finalityRuleHash` are deployment parameters. Each `handlerId` MUST resolve to an existing closed Core handler whose claim type and schema hash match. The domain cannot supply or select executable handler code.

### 6.3 Caps

Each capability MUST define:

- maximum amount per claim;
- maximum total amount per batch;
- maximum count per batch;
- maximum amount per policy window;
- supported `AssetID` values; and
- any per-asset concentration limit.

Caps bound effects but do not grant standing. A claim must still pass every dispatch check.

## 7. Ethereum lockbox event contract

The authoritative event ABI, contract address, code version, and topic hashes MUST be pinned by `chainVerifierId`, `stfSpecHash`, and the Ethereum Interop Enforcement Specification.

The logical event schemas are:

```solidity
event Locked(
    bytes32 indexed depositId,
    address indexed foreignAsset,
    bytes20 indexed zenonRecipient,
    uint256 amount
);

event Released(
    bytes32 indexed outboxId,
    address indexed foreignAsset,
    address indexed ethereumRecipient,
    uint256 amount
);
```

The actual deployed ABI MAY add non-authoritative fields, but changing any field used by a claim requires a new claim schema and semantic pin.

### 7.1 `Locked`

The lockbox MUST emit `Locked` only after custody has received the exact amount represented by the event. `depositId` MUST be unique for that adapter deployment and MUST NOT be reusable after refund, upgrade, or custody migration.

For native ETH, `foreignAsset` uses the canonical native-ETH sentinel defined by the enforcement specification. For ERC-20, it is the exact token contract address.

### 7.2 `Released`

The adapter MUST emit `Released` only in the same successful Ethereum transaction that:

- verifies the matching finalized Zenon `PegOutRecord{state=PENDING}`;
- validates binding, asset, amount, recipient, `burnRef`, and timeout;
- confirms `outboxId` is unconsumed;
- writes the destination replay state; and
- transfers the exact custody amount.

If the transaction reverts, neither the transfer, replay write, nor event may persist.

## 8. Asset bindings

### 8.1 Registry rule

Every supported foreign asset MUST have one injective registry binding:

```text
(d_eth_asset, foreignChainId, foreignAssetRef, decimalsPolicy)
    -> representation AssetID
```

The representation `AssetID` MUST be a canonical ZTS identifier controlled exclusively by the activated MINTED Settlement handler.

### 8.2 Initial asset classes

**Native ETH.** Amount is denominated in wei and converted under a pinned exact policy.

**ERC-20.** Each token requires an explicit allowlist entry containing:

- contract address;
- expected decimals;
- representation `AssetID`;
- exact normalization rule;
- minimum and maximum amount;
- token code and upgrade-governance assumptions;
- pause, blacklist, and seizure behavior; and
- monitoring requirements.

### 8.3 Unsupported token behavior

The initial profile MUST reject fee-on-transfer, rebasing, callback-dependent, reflection, or otherwise non-exact-transfer tokens. Upgradeable, pausable, or blacklistable tokens SHOULD be excluded unless their additional trust and migration rules are explicitly approved in both the asset registry and enforcement specification.

The amount in a `FOREIGN_LOCK` claim MUST be the amount actually received into custody, not an unverified user parameter.

### 8.4 Decimal normalization

Conversion between foreign units and the representation asset's canonical units MUST be deterministic, exact, overflow-checked, and unable to round upward. Dust that cannot be represented exactly MUST NOT become verified collateral or minted supply.

## 9. Ethereum verifier state

`d_eth_asset` MAY maintain only verifier and claim-emission state. The logical state is:

```text
EthAuthorizationState {
    schemaVersion
    finalizedBeaconRoot
    finalizedBeaconSlot
    currentSyncCommitteeRoot
    nextSyncCommitteeRoot
    finalizedExecutionBlockHash
    finalizedExecutionStateRoot
    processedDepositIds
    resolutionSeenByOutboxId
}
```

`processedDepositIds` prevents duplicate claim emission for one lockbox deposit. `resolutionSeenByOutboxId` is `NONE | RELEASE | NON_DELIVERY` and prevents the domain from emitting contradictory resolution claims.

These sets are not Settlement replay protection. Settlement independently enforces `claimId`, `(domainId, ForeignEventID)`, and `PegOutRecord` terminal state. The Ethereum adapter independently enforces destination replay on `outboxId`.

The state MUST NOT contain:

- user balances;
- representation supply;
- verified collateral counters owned by Settlement;
- pending release amounts;
- mint or burn authority;
- Settlement claim receipts;
- `ProcessedClaim` or `ProcessedForeignEvent`; or
- adapter custody or replay state.

## 10. Canonical domain inputs

Under `L1_RELAYED`, each input is posted to Zenon L1 and ordered by momentum order. The domain input envelope is a versioned tagged union:

```text
ETH_LIGHT_CLIENT_UPDATE
ETH_LOCK_PROOF
ETH_RELEASE_PROOF
ETH_NON_DELIVERY_PROOF
```

The exact binary encoding MUST use the framework's canonical fixed-width and length-prefixed rules and MUST be pinned by `stfSpecHash`.

### 10.1 Light-client update

The input carries the data required to advance finalized Ethereum light-client state. `Apply` MUST reject an update that:

- targets another network or fork domain;
- fails the selected sync-committee or consensus checks;
- does not extend the accepted finalized view under the pinned rules;
- regresses finalized slot or checkpoint state;
- omits required execution-payload binding; or
- exceeds canonical size or resource limits.

### 10.2 Lock proof

The input carries:

- a reference to accepted finalized light-client state;
- execution receipt inclusion proof;
- receipt and log index;
- lockbox address;
- `Locked` event bytes; and
- any auxiliary trie nodes required by the pinned verifier.

### 10.3 Release proof

The input carries the corresponding finalized receipt and `Released` log proof.

### 10.4 Non-delivery proof

The input carries the exact `PegOutAuthorization` projection plus a finalized Ethereum account/storage proof establishing that:

- the authorization's `chainBindingHash`, `outboxId`, asset, amount, and timeout are canonical;
- destination height or time is at or beyond the authorization deadline;
- the exact adapter deployment is active under the binding;
- the adapter's canonical processed mapping has no consumed entry for `outboxId`; and
- the adapter's pinned logic rejects every release at or after that deadline.

The storage slot derivation, code identity, account proof, storage proof, and timeout comparison MUST be defined by the Ethereum Interop Enforcement Specification. The processed mapping MUST be monotonic and non-clearable for the lifetime of the binding. Absence from an arbitrary RPC response is not proof of non-delivery.

## 11. Ethereum `ChainVerifier`

### 11.1 Finalized view

The `LIGHT_CLIENT` verifier MUST validate Ethereum consensus and finality under the pinned rules, bind the finalized beacon state to the relevant execution payload header, and expose the finalized execution receipts and state roots required by evidence verification.

### 11.2 Receipt and log inclusion

For `Locked` and `Released`, the verifier MUST:

1. verify the receipt trie path against the receipts root of the accepted finalized execution block;
2. decode the canonical receipt form supported by the schema;
3. select the exact log by index;
4. require the emitting address to equal `releaseAdapterRef` or its lockbox event source named by the enforcement specification;
5. require the exact registered topic hash;
6. decode fields canonically with no trailing or ambiguous data;
7. validate asset, amount, recipient, deposit ID, or `outboxId`; and
8. reject evidence already consumed in verifier-local claim-emission state.

### 11.3 State absence

For `FOREIGN_NON_DELIVERY`, the verifier MUST validate the adapter account and storage proof against the finalized execution state root. It MUST derive the processed-set slot exactly as specified and prove the unconsumed value at or after the deadline.

### 11.4 Determinism

The verifier MUST be pure and deterministic. It MUST NOT call an Ethereum RPC endpoint, read wall-clock time, use an environment-dependent fork table, or depend on node-local caches during `Apply`.

All headers, proofs, fork data, and evidence used by `Apply` must come from canonical inputs, pinned configuration, or witnessed state.

## 12. Claim schemas

All three initial schemas require `PayloadHash = bytes32(0)` and empty `ClaimDispatchData.Payload`. Settlement does not need Ethereum proof bytes to run the registered handlers. The evidence remains in the replayable domain input and DA bundle.

For positive Ethereum log events, the canonical occurrence identifier is:

```text
EthereumLogEventID = SHA3-256(
    "ETH_LOG_V1" ||
    chainBindingHash ||
    executionBlockHash ||
    transactionIndex:u32 ||
    logIndex:u32
)
```

The exact integer encoding is fixed-width big-endian. `depositId` and `outboxId` remain separately validated event fields and verifier-local replay keys; they do not replace the framework-required chain-canonical occurrence identifier.

### 12.1 `ETH_FOREIGN_LOCK_V1`

```text
DomainID        = d_eth_asset
PolicyVersion   = ETH_ASSET_POLICY_V1
ClaimType       = FOREIGN_LOCK
ClaimSchemaHash = SHA3-256(exact canonical ETH_FOREIGN_LOCK_V1 schema artifact bytes)
ForeignEventID  = EthereumLogEventID
Subject         = canonical 20-byte Zenon recipient
Asset           = bound representation AssetID
Amount          = exact normalized amount > 0
PayloadHash     = bytes32(0)
FinalityRef     = EthereumEventFinalityRef
ObservedAt      = finalized beacon slot
```

The domain MUST emit this claim only after proving the registered `Locked` event under finalized Ethereum state, validating the asset binding and recipient, and inserting `depositId` into verifier-local processed state atomically with claim emission.

### 12.2 `ETH_FOREIGN_RELEASE_V1`

```text
DomainID        = d_eth_asset
PolicyVersion   = ETH_ASSET_POLICY_V1
ClaimType       = FOREIGN_RELEASE
ClaimSchemaHash = SHA3-256(exact canonical ETH_FOREIGN_RELEASE_V1 schema artifact bytes)
ForeignEventID  = EthereumLogEventID
Subject         = outboxId:bytes32
Asset           = bound representation AssetID
Amount          = exact released amount > 0
PayloadHash     = bytes32(0)
FinalityRef     = EthereumEventFinalityRef
ObservedAt      = finalized beacon slot
```

This claim reports an already finalized Ethereum release. It does not create or retroactively justify release authority. Settlement MUST require the matching `PegOutRecord` to be `PENDING` with identical binding, asset, amount, and `outboxId`.

### 12.3 `ETH_FOREIGN_NON_DELIVERY_V1`

```text
DomainID        = d_eth_asset
PolicyVersion   = ETH_ASSET_POLICY_V1
ClaimType       = FOREIGN_NON_DELIVERY
ClaimSchemaHash = SHA3-256(exact canonical ETH_FOREIGN_NON_DELIVERY_V1 schema artifact bytes)
ForeignEventID  = SHA3-256("NON_DELIVERY" || chainBindingHash || outboxId || finalizedCheckpoint)
Subject         = outboxId:bytes32
Asset           = asset from the pending authorization
Amount          = amount from the pending authorization
PayloadHash     = bytes32(0)
FinalityRef     = EthereumStateFinalityRef
ObservedAt      = finalized beacon slot at or after deadline
```

The domain MUST emit this claim only after verifying the canonical storage absence proof at or after the destination-enforced deadline. It MUST reject non-delivery if `resolutionSeenByOutboxId[outboxId] = RELEASE`.

For this schema, `finalizedCheckpoint` in the `ForeignEventID` formula is the `finalizedBeaconRoot` carried by `EthereumStateFinalityRef`.

Settlement obtains the refund recipient and original burn from the immutable `PegOutRecord`; neither the relayer nor this claim may replace them.

### 12.4 Finality-reference encodings

The schema artifacts MUST define exact encodings for:

```text
EthereumEventFinalityRef {
    finalizedBeaconRoot : bytes32
    finalizedBeaconSlot : u64
    executionBlockHash  : bytes32
    transactionIndex    : u32
    logIndex            : u32
}

EthereumStateFinalityRef {
    finalizedBeaconRoot : bytes32
    finalizedBeaconSlot : u64
    executionBlockHash  : bytes32
}
```

All integers use the framework's fixed-width big-endian encoding. The fields appear in the order shown with no trailing bytes. Any future fork-domain field changes the schema artifact and `claimSchemaHash`.

## 13. Domain `Apply` behavior

The following pseudocode is illustrative of the required ownership boundary:

```text
Apply(state, input):
    switch input.tag:
      ETH_LIGHT_CLIENT_UPDATE:
        next = VerifyHeaderChain(input.update, state.headerState)
        return verifierStateOnly(next)

      ETH_LOCK_PROOF:
        event = VerifyFinalizedLock(input.proof, state.headerState)
        require(!state.processedDepositIds[event.depositId])
        binding = RequireAllowedAsset(event.foreignAsset)
        amount = NormalizeExactly(binding, event.amount)
        recipient = ValidateZenonRecipient(event.zenonRecipient)
        claim = BuildForeignLockClaim(event, binding, amount, recipient)
        state.processedDepositIds[event.depositId] = true
        return AuthorizationEffects{StateDiff: verifierOnly(state), Claims: [claim]}

      ETH_RELEASE_PROOF:
        event = VerifyFinalizedRelease(input.proof, state.headerState)
        require(state.resolutionSeenByOutboxId[event.outboxId] == NONE)
        claim = BuildForeignReleaseClaim(event)
        state.resolutionSeenByOutboxId[event.outboxId] = RELEASE
        return AuthorizationEffects{StateDiff: verifierOnly(state), Claims: [claim]}

      ETH_NON_DELIVERY_PROOF:
        proof = VerifyFinalizedNonDelivery(input.proof, state.headerState)
        require(state.resolutionSeenByOutboxId[proof.outboxId] == NONE)
        claim = BuildForeignNonDeliveryClaim(proof)
        state.resolutionSeenByOutboxId[proof.outboxId] = NON_DELIVERY
        return AuthorizationEffects{StateDiff: verifierOnly(state), Claims: [claim]}
```

Any failure returns no state change and no claim. Claim emission and verifier-local replay-state update MUST be atomic.

## 14. Deposit lifecycle

1. The user locks ETH or an allowlisted ERC-20 in the registered Ethereum lockbox and specifies a canonical Zenon recipient.
2. The lockbox receives the asset and emits `Locked`.
3. A relayer waits for Ethereum finality and posts the required light-client update and receipt proof through `L1_RELAYED`.
4. `d_eth_asset` verifies Ethereum finality, receipt inclusion, lockbox address, topic, event fields, asset binding, amount, recipient, and deposit replay.
5. `Apply` emits one `FOREIGN_LOCK` claim and changes only verifier-local state.
6. The Authorization batch commits the claim under `claimRoot` with empty `outboxRoot` and empty `assetFlowSummary`.
7. After batch finality, any relayer calls `RelayClaim` with the claim inclusion proof.
8. Settlement checks provenance, policy version, schema, `claimId`, `(domainId, ForeignEventID)`, caps, budget, handler identity, and conservation.
9. The registered MINTED lock handler atomically increases verified collateral and representation outstanding, then credits or mints the representation asset to `Subject`.
10. Settlement records the claim receipt and both replay keys.

No domain balance changes before Step 9.

## 15. Peg-out lifecycle

1. The holder invokes the registered local Settlement redemption path with representation asset, amount, Ethereum recipient, refund recipient, and timeout.
2. The framework's local debit/burn and authorization path reaches its required finality. At the framework-defined atomic transition, Settlement validates the finalized burn, decreases `representationOutstanding`, increases `pendingForeignRelease`, and creates the binding-pinned `PegOutRecord{state=PENDING}` and foreign-facing `PegOutAuthorization`.
3. The authorization is consumable only through a proof of that finalized `PENDING` record.
4. A relayer submits the authorization and `ZenonProof` to the registered Ethereum adapter before the deadline.
5. The adapter verifies the exact `PENDING` record, `chainBindingHash`, adapter/spec version, `burnRef`, asset, amount, recipient, finality, deadline, and unconsumed `outboxId`.
6. The adapter atomically transfers the exact asset, records `outboxId`, and emits `Released`.
7. A relayer posts the finalized Ethereum release proof to `d_eth_asset`.
8. The domain emits `FOREIGN_RELEASE`, changing no accounting state.
9. After claim finality, Settlement dispatch moves the matching record from `PENDING` to `RELEASED`, decreases `pendingForeignRelease`, and decreases verified locked collateral.

The `FOREIGN_RELEASE` claim in Step 8 records what Ethereum already finalized. The release authority was created in Step 2.

## 16. Timeout and refund lifecycle

1. The adapter rejects release at or after the destination deadline encoded in the authorization.
2. At a finalized Ethereum state at or after the deadline, a relayer obtains the canonical proof that the adapter has not consumed `outboxId`.
3. `d_eth_asset` verifies the adapter account, code/version binding, processed-set storage slot, absence value, finalized state root, and deadline.
4. The domain emits `FOREIGN_NON_DELIVERY` and marks the verifier-local resolution as non-delivery.
5. After claim finality, Settlement requires the matching record to remain `PENDING`, dispatches the registered refund handler, moves it to `REFUNDED`, decreases `pendingForeignRelease`, and remints to the immutable recorded refund recipient.

Release and refund MUST be mutually exclusive on both sides:

- Ethereum rejects release after the deadline and consumes its own replay key on release;
- `d_eth_asset` will not emit contradictory resolution claims;
- Settlement accepts only one terminal transition from `PENDING`; and
- claim and foreign-event replay keys are consumed independently.

Elapsed time or a missing acknowledgement alone is not sufficient for refund.

## 17. Settlement accounting

This document does not define a separate ETH ledger. The framework's MINTED conservation predicate applies per `(d_eth_asset, AssetID)`:

```text
representationOutstanding + pendingForeignRelease
    <= verifiedLockedCollateral
```

Only Settlement applies the framework's four transitions:

| Event | Outstanding | Pending release | Verified collateral |
|---|---:|---:|---:|
| dispatched `FOREIGN_LOCK` | `+ amount` | unchanged | `+ amount` |
| finalized local burn and authorization | `- amount` | `+ amount` | unchanged |
| dispatched `FOREIGN_RELEASE` | unchanged | `- amount` | `- amount` |
| dispatched `FOREIGN_NON_DELIVERY` | `+ amount` | `- amount` | unchanged |

Authorization batches carry no mint `AssetFlowSummary`. Stronger execution or Ethereum verification never changes these transitions or widens the active `ClaimPolicy`.

The predicate proves consistency of admitted claims and Settlement accounting. It does not independently prove that the lockbox remains solvent, correctly governed, upgrade-safe, or able to release.

## 18. Ethereum Interop Enforcement Specification

This domain MUST remain inactive until a separate `ETH-INTEROP-ENFORCEMENT-SPEC.md` satisfies every framework Section 18.3 obligation and its exact bytes hash to `ChainBinding.enforcementSpecHash`.

That artifact, not this document, MUST define:

1. lockbox custody location, ETH/ERC-20 mapping, and every principal able to move, pause, freeze, seize, or upgrade custody;
2. canonical `chainBindingHash`, `PegOutAuthorization`, `ZenonProof`, `ReleaseReceipt`, event ABI, storage layout, and non-delivery encodings;
3. the exact Ethereum verification mode for Zenon finality and inclusion of the matching `PENDING` `PegOutRecord`;
4. persistent `outboxId` storage and atomic verify-release-replay ordering;
5. destination deadline, release-refund exclusion, finality, and storage-absence proof;
6. deployed addresses, initialization, source/build hashes, audit artifacts, vectors, monitoring, pause, and recovery; and
7. upgrade keys, thresholds, time locks, exit window, old-version settlement period, and custody migration.

Committee, optimistic, direct-proof, and third-party modes are not interchangeable choices inside this domain specification. The enforcement artifact MUST select and fully specify one deployed mode. Changing it requires a new artifact hash, `ChainBinding`, `chainBindingHash`, and delayed domain migration.

The destination processed set MUST be monotonic for the lifetime of a binding. An upgrade or custody migration MUST preserve every consumed `outboxId`; clearing or re-keying replay state without a proven migration is non-conformant.

## 19. Optional solver acceleration

A solver MAY pay the Ethereum recipient from its own inventory and later receive the canonical adapter release if the user explicitly assigns that right.

Solver behavior is governed by the Execution Provider and Intent frameworks. It MUST NOT:

- change the `PegOutRecord`;
- bypass the adapter;
- create a second release path;
- alter the destination replay key;
- make an unfinalized record final; or
- turn provider failure into a Settlement refund condition.

The canonical lockbox path must remain defined without a solver.

## 20. Trust model

The end-to-end outcome depends on distinct assumptions:

| Layer | Target profile or mechanism | Principal assumption |
|---|---|---|
| Zenon ordering | Zenon consensus | Canonical L1 order and finality |
| Authorization execution | `OPTIMISTIC` | At least one honest, live watcher with DA and a sound referee |
| Ethereum foreign fact | `LIGHT_CLIENT` | Correct Ethereum light-client, fork, finality, receipt, and storage verification |
| Claim standing | `ClaimPolicy` and Core dispatcher | Correct schema, capability, handlers, caps, and governance configuration |
| Settlement accounting | MINTED handlers | Correct issuance authority, atomic transitions, replay, and conservation |
| Ethereum custody | Lockbox | Solvency, token behavior, code correctness, and custody governance |
| Destination enforcement | Hash-pinned adapter specification | Correct Zenon proof verification, deadline, replay, and atomic release |
| Activation review | Governance and validators | Competent semantic review and deployed-code correspondence |
| Optional fast fulfillment | Solver/provider | Capital, quote, assignment, and delivery performance |

The admitted claim is no stronger than the weaker of the execution and foreign-fact profiles. The complete bridge is additionally limited by Settlement, custody, adapter, Ethereum, and governance assumptions.

## 21. Failure model

| Failure | Required response | Residual |
|---|---|---|
| Invalid light-client update | Reject with no state change | Liveness if no valid update arrives |
| Invalid receipt, log, or storage proof | Reject with no claim | Liveness if proof construction fails |
| Duplicate deposit ID | Reject in domain; Settlement also checks replay | None for conformant keyed surfaces |
| Claim outside policy or cap | Reject atomically at `RelayClaim` | Valid evidence has no effect |
| Authorization state writes accounting namespace | Reject batch and halt domain | Implementation defect requires repair/migration |
| Settlement handler or conservation failure | Revert dispatch | Core bug remains protocol risk |
| Unsupported or pathological ERC-20 | Reject by asset binding | Governance may still approve a risky token |
| Adapter release transaction reverts | No transfer and no destination replay write | Retry before deadline |
| Duplicate destination release | Adapter rejects `outboxId` | Adapter bug can lose custody |
| Valid release proof never relayed back | Settlement record remains `PENDING` | Accounting liveness delay; foreign asset already moved |
| Release absent at deadline | Prove non-delivery, then refund | No refund if sound absence proof is unavailable |
| Lockbox insolvent, frozen, or seized | Halt new activity and execute published recovery | Zenon cannot restore foreign custody |
| Adapter or verifier version skew | Reject mismatched binding/proof | Old adapter must settle or expire old records |
| Governance approves bad enforcement artifact | Low caps, independent review, monitoring, pause | Hash does not prove adequacy |
| Solver fails | Use canonical path or provider remedy | Provider-specific loss under signed terms |

## 22. MUST-fail conditions

In addition to every framework failure condition, this specialization MUST reject:

- wrong Ethereum network, genesis identity, fork domain, lockbox, adapter, event topic, or event ABI;
- an update that does not extend the accepted finalized Ethereum view;
- a receipt or storage proof not rooted in accepted finalized execution state;
- malformed, ambiguous, trailing, oversized, or unsupported evidence encoding;
- duplicate `depositId` or contradictory `outboxId` resolution;
- zero, overflowing, inexactly normalized, unsupported, or cap-exceeding amount;
- malformed Zenon recipient or Ethereum recipient;
- token outside the active asset binding;
- a claim whose schema, zero-field rules, policy version, or finality reference is wrong;
- non-delivery before the destination deadline or without canonical storage absence;
- batch output with non-empty `outboxRoot` or `assetFlowSummary`;
- any domain state write outside the verifier and claim-emission namespaces;
- activation with zero or unreviewed `enforcementSpecHash`; and
- a profile, handler, schema, or binding not folded into `stfSpecHash`.

Every failure MUST leave domain and Settlement state unchanged, except a framework-defined halt on internal corruption or forbidden namespace access.

## 23. Conformance tests

### 23.1 Domain class and output

1. Valid verifier update changes only verifier state.
2. Valid lock evidence emits one claim, no outbox message, and no asset-flow entry.
3. A fixture attempting balance, mint, burn, reserve, or Settlement replay writes halts the domain.
4. An `AUTHORIZATION` batch with non-empty `outboxRoot` or `assetFlowSummary` is rejected.

### 23.2 Ethereum finality and evidence

1. Valid finalized light-client update advances state.
2. Wrong network, fork domain, signature, committee, or non-extending update fails.
3. Valid finalized `Locked` receipt proof emits the expected claim.
4. Wrong receipts root, trie node, transaction index, log index, address, topic, or ABI fails.
5. Unfinalized or stale evidence fails under `finalityParams`.
6. Valid finalized `Released` proof emits the expected release claim.
7. Valid finalized adapter storage absence at or after deadline emits non-delivery.
8. Absence before deadline or against a wrong adapter/storage slot fails.

### 23.3 Claim normalization and replay

1. Every fixture produces the exact expected canonical `AuthorizedClaim` bytes and `claimId`.
2. Repeating one `depositId` emits no second claim.
3. Repeating one release or presenting release after non-delivery emits no contradictory claim.
4. Asset and decimal boundary vectors reject upward rounding, overflow, and unsupported dust.
5. `ClaimEffectSummary` exactly matches emitted claims and caps.

### 23.4 Settlement dispatch

1. A finalized valid `FOREIGN_LOCK` dispatch mints once and preserves conservation.
2. Reusing either `claimId` or `(domainId, ForeignEventID)` is rejected.
3. Wrong policy version, schema, handler, asset, amount, cap, or budget is rejected atomically.
4. Stronger proof fixtures do not permit an unregistered capability.
5. Settlement never decodes Ethereum proof bytes during dispatch.

### 23.5 Peg-out and destination enforcement

1. Local burn and `PENDING` record creation are atomic.
2. Missing burn, mismatched binding, asset, amount, recipient, or `burnRef` fails.
3. Adapter release succeeds once before deadline and records `outboxId` atomically.
4. Reverted transfer leaves `outboxId` unconsumed and can be retried.
5. Duplicate release is rejected.
6. Release at or after deadline is rejected.
7. Finalized release claim moves only the matching record to `RELEASED`.
8. Valid non-delivery moves only the matching record to `REFUNDED` and remints to the recorded recipient.
9. Release and refund race vectors produce exactly one terminal state.

### 23.6 Deployment and governance

1. Zero, unavailable, or byte-mismatched `enforcementSpecHash` prevents activation.
2. Adapter address or code inconsistent with the artifact prevents activation.
3. Schema or binding change without `stfSpecHash` migration is rejected.
4. Old adapter records remain settleable or expirable through migration.
5. Review fixtures include a syntactically complete but semantically wrong enforcement artifact and require governance rejection.

## 24. Activation checklist

- [ ] The active protocol satisfies A1, A2, A4, A6, A7, A11, A12, A14, A15, and A16.
- [ ] OD-1 is resolved by an activated MINTED Settlement Extension Specification.
- [ ] The exact Ethereum network identity and finality rules are pinned.
- [ ] `chainVerifierId` identifies an implemented and tested light client.
- [ ] Every input, evidence, finality-reference, and claim schema has canonical bytes and a published hash.
- [ ] The ASSET policy contains only intended capabilities and registered Core handlers.
- [ ] ETH and ERC-20 asset bindings, decimals, caps, and token assumptions are approved.
- [ ] The Ethereum lockbox and adapter are deployed and initialized.
- [ ] The Ethereum Interop Enforcement Specification is complete, independently reviewed, and hash-pinned.
- [ ] Source, build, deployment, audit, and test-vector artifacts correspond.
- [ ] Domain, Settlement, destination, timeout, migration, and adversarial tests pass.
- [ ] Initial value caps reflect the residual implementation and semantic-review risk.
- [ ] Governance and validators keep the domain `PAUSED` until every item is complete.

## 25. Honest naming

Before activation, the artifact is an **Ethereum Asset Authorization Domain study** or **ETH lockbox bridge specialization**.

It may be called an operational ETH bridge only when the complete composition exists: active Authorization Domain, active claim policy and MINTED handlers, deployed and funded lockbox, conformant hash-pinned adapter, tested timeout path, governance, and monitoring.

Do not describe it as bridgeless, custodyless, trustless, native ETH on Zenon, or enabled by EVM compatibility.

## 26. Summary

`d_eth_asset` understands Ethereum and emits three bounded claims. It does nothing else.

- `FOREIGN_LOCK` reports finalized lockbox custody eligible for Settlement minting.
- `FOREIGN_RELEASE` reports a finalized release that Settlement may reconcile.
- `FOREIGN_NON_DELIVERY` reports finalized absence after the adapter deadline so Settlement may refund.

Settlement alone owns zETH and zERC-20 issuance, burn, bridge counters, claim replay, conservation, and `PegOutRecord` state. Ethereum alone owns lockbox custody and destination enforcement under the pinned adapter specification. Relayers transport evidence. Solvers are optional fulfillment providers.

That division makes the ETH specialization fit the generalized framework without introducing a second ledger, a domain-local mint path, or an ambiguous release mode.
