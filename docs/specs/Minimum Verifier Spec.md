# Minimum Verifier Spec — Zenon Network

**Epistemological key:**

- **[CODE]** — Fact derived directly from source code with file and function citations.
- **[INFERRED]** — Behavior inferred from combining two or more code-derived facts. The inference chain is stated.
- **[UNKNOWN]** — Not derivable from the available codebase. The gap is characterized precisely.

---

## Scope and Verifier Tiers

This document specifies what is required to independently verify Zenon blocks at two tiers:

**Structural verifier** — Checks hash correctness, field constraints, linking rules, and signatures. Does not require state execution. A structural verifier MUST NOT execute the VM, enforce plasma limits, or attempt to validate `ChangesHash`. These are full-state concerns; applying them in a structural context will produce incorrect results.

**Full state verifier** — All structural checks, plus VM application, plasma enforcement, embedded contract execution, and `ChangesHash` validation for momentum and contract-receive blocks.

Sections and fields marked **(full state only)** are not part of the structural verifier.

---

## 1. Primitives

### 1.1 Hash Function

**[CODE]** `common/crypto/hash.go` → `Hash()`; `common/types/hash.go` → `NewHash()`:

```
types.NewHash(data []byte) = SHA3-256(data)
types.Hash               = [32]byte
```

All hashes in this protocol are exactly 32 bytes.

### 1.2 Byte Concatenation

**[CODE]** `common/bytes.go` → `JoinBytes(data ...[]byte)`:

All hash inputs are concatenated by appending byte slices in the given order. There are no length prefixes, no delimiters, and no separators between fields. The result is the raw concatenation.

### 1.3 Integer Encoding

**[CODE]** `common/bytes.go`:

| Encoding | Rule |
|---|---|
| `uint64` → bytes | 8 bytes, big-endian |
| `*big.Int` → bytes | 32 bytes, left-padded, big-endian; `nil` treated as 32 zero bytes |

### 1.4 Address Format

**[CODE — current implementation]** `common/types/address.go`:

```
types.Address = [20]byte
  byte[0]    = prefix byte
  byte[1..19] = 19 core bytes

UserAddrByte     = 0x00   (user accounts)
ContractAddrByte = 0x01   (embedded contracts)

IsEmbeddedAddress(addr) ⟺ addr[0] == 0x01
```

The prefix byte is included verbatim in all hash inputs. These values are current implementation constants, not formal protocol guarantees; future protocol versions could introduce additional prefixes.

### 1.5 Token Standard

**[CODE]** `common/types/tokenstandard.go`:

```
types.ZenonTokenStandard = [10]byte
.Bytes() = raw 10 bytes (no encoding)
```

### 1.6 HashHeight Equality

**[CODE]** `common/types/hash_height.go`. A `HashHeight` is a pair `{Hash [32]byte, Height uint64}`. Two `HashHeight` values are equal if and only if all 40 bytes are equal:

```
HashHeight.Bytes() = Hash[32] || Uint64BE(Height)[8]   (40 bytes total)
```

Equality is exact byte equality on both fields.

---

## 2. Data Structures

### 2.1 Momentum

**[CODE]** `chain/nom/momentum.go`

| Field | Type | Hash-included | Notes |
|---|---|---|---|
| `Version` | `uint64` | Yes | Must equal `1` |
| `ChainIdentifier` | `uint64` | Yes | Non-zero; must match store's chain ID |
| `Hash` | `types.Hash` | No (stored) | Must equal `ComputeHash()` |
| `PreviousHash` | `types.Hash` | Yes | Non-zero for all non-genesis momentums |
| `Height` | `uint64` | Yes | `> 1` in non-genesis verifier path |
| `TimestampUnix` | `uint64` | Yes | See §6.1 |
| `Timestamp` | `*time.Time` | **No** | Cache only (`rlp:"-"`); populated from `TimestampUnix`; never transmitted or hashed |
| `Data` | `[]byte` | Yes (hash-of-data) | Must be empty for non-genesis momentums |
| `Content` | `MomentumContent` | Yes (hash-of-content) | ≤ 100 entries; **ordering is consensus-critical** |
| `ChangesHash` | `types.Hash` | Yes | See §10 |
| `producer` | `*types.Address` | **No** | Cache only (`rlp:"-"`) |
| `PublicKey` | `ed25519.PublicKey` | **No** | Non-empty for non-genesis |
| `Signature` | `[]byte` | **No** | Non-empty for non-genesis; ed25519 over `momentum.Hash.Bytes()` |

**[CODE]** `ComputeHash()` — exact field order, raw concatenation:

```
SHA3-256(
  Uint64BE(Version)[8]          ||
  Uint64BE(ChainIdentifier)[8]  ||
  PreviousHash[32]              ||
  Uint64BE(Height)[8]           ||
  Uint64BE(TimestampUnix)[8]    ||
  SHA3-256(Data)[32]            ||   ← hash of raw Data bytes; applied even when Data is []byte{}
  Content.Hash()[32]            ||
  ChangesHash[32]
)
```

`chain/nom/momentum.go` → `ComputeHash()`

**[CODE]** Hash must be verified before signature: the signature is `ed25519.Verify(PublicKey, momentum.Hash.Bytes(), Signature)`, which uses `Hash` as the message. `Hash` is only trustworthy after `ComputeHash() == Hash` is confirmed.

### 2.2 MomentumContent and AccountHeader

**[CODE]** `chain/nom/momentum_content.go`, `common/types/account_header.go`:

```
MomentumContent = []*AccountHeader   (slice; position-significant)

AccountHeader = {
  Address    [20]byte
  Hash       [32]byte
  Height     uint64
}
```

**AccountHeader canonical byte encoding** — used for content hashing and sort comparisons:

```
Address[20] || Uint64BE(Height)[8] || Hash[32]   = 60 bytes total
```

`common/types/account_header.go` → `Bytes()`

**AccountHeader.Identifier()** returns `HashHeight{Hash, Height}` — address is not part of the identifier. `common/types/account_header.go` → `Identifier()`.

**Content hash:**

```
Content.Hash() = SHA3-256( concat( header.Bytes() for each header in slice order ) )
```

`chain/nom/momentum_content.go` → `Hash()`

**Content ordering:** `NewMomentumContent` sorts using `sort.Slice` with comparator `bytes.Compare(a.Bytes(), b.Bytes()) <= 0`. Primary sort key is `Address[20]`, secondary is `Uint64BE(Height)[8]`, tertiary is `Hash[32]`.

**[CODE]** A verifier does not need to independently check that the provided `Content` slice is sorted. Correct sort order is verified implicitly: `Content.Hash()` is computed from the slice in the order given and compared against the committed hash inside `Momentum.ComputeHash()`. Any reordering produces a different `Content.Hash()` and fails momentum hash verification. The sort constraint is enforced by the hash commitment, not by a separate sort check.

**[INFERRED]** Go's `sort.Slice` is not stable. Two headers with identical `Bytes()` output (same Address, Height, and Hash) have undefined relative order. Under the protocol's validity rules, two headers at the same `{Address, Height, Hash}` are duplicates and are independently rejected (see §2.3). Two headers with the same `{Address, Height}` but different `Hash` values would be distinct entries with stable sort order at the hash level, but the presence of two blocks at the same height for the same account chain is invalid per §6.3 previous-link rules.

**[INFERRED]** Because `Momentum.Hash` commits to `Content.Hash()` over the full concatenation (not a Merkle tree), a verifier performing momentum inclusion proofs must obtain the complete `Content` list for every verified momentum. There is no compact inclusion path.

### 2.3 Header↔Block Binding

**[CODE]** During momentum content verification, the lookup binding headers to blocks is:

```
blocksLookup = map[HashHeight → *AccountBlock]    built from prefetched blocks via block.Identifier()
block        = blocksLookup[header.Identifier()]   keyed by {Hash, Height} only
```

`verifier/momentum.go` → `rawMomentumVerifier.content()`

**Prefetched block completeness:** The set of AccountBlocks supplied to the verifier for a momentum MUST be exactly the set referenced by `Momentum.Content` — one block per header, matched by `header.Identifier()`. No additional blocks may be included; no referenced block may be absent. This is enforced by:

```
len(blocksLookup) == len(Momentum.Content)
```

Because `blocksLookup` is a map keyed by `HashHeight`, duplicate headers (same `{Hash, Height}`) collapse to one map entry, reducing the map size below `len(Content)` and triggering an error. Two headers with the same `{Address, Height}` but different `Hash` values occupy distinct map entries and are not caught here; their invalidity relies on account-chain linking rules enforced elsewhere.

**Required validation order and address binding:** The binding of `header.Address` to `block.Address` is transitive and depends on a specific verification order:

```
REQUIRED ORDER:
Step 1. Verify block.ComputeHash() == block.Hash
Step 2. ONLY AFTER step 1: use block.Hash as a binding commitment to block.Address
Step 3. The header-to-block lookup (keyed by Hash+Height) then carries the address binding
        by transitivity: header.Hash == block.Hash (from lookup), block.Hash commits to
        block.Address (from step 1).
```

**[CODE]** `AccountBlock.ComputeHash()` includes `block.Address` in its hash input (see §2.4). If step 1 is skipped, an attacker can supply a block with a correct `{Hash, Height}` (matching the header) but incorrect fields — including `Address` — and the address binding is not guaranteed.

The momentum content verifier does not independently check `header.Address == block.Address`; this equality holds only after the block's own hash has been verified. Implementations MUST verify `block.ComputeHash() == block.Hash` for each block before using that block's fields in any further check.

**Explicit binding invariants** (jointly enforced by content verifier + block hash verifier):

```
For each AccountHeader H and matched AccountBlock B:

H.Hash   == B.Hash      (enforced by blocksLookup key match)
H.Height == B.Height    (enforced by blocksLookup key match)
H.Address == B.Address  (enforced transitively: B.Hash commits to B.Address via ComputeHash,
                         which must be verified before the lookup result is trusted)
```

### 2.4 AccountBlock

**[CODE]** `chain/nom/account_block.go`

| Field | Type | Hash-included | Notes |
|---|---|---|---|
| `Version` | `uint64` | Yes | Must equal `1` |
| `ChainIdentifier` | `uint64` | Yes | Must match store's chain ID |
| `BlockType` | `uint64` | Yes | See §2.5 |
| `Hash` | `types.Hash` | No (stored) | Must equal `ComputeHash()` |
| `PreviousHash` | `types.Hash` | Yes | Zero iff `Height == 1` |
| `Height` | `uint64` | Yes | Must be `> 0` |
| `MomentumAcknowledged` | `types.HashHeight` | Yes | `Hash[32] \|\| Uint64BE(Height)[8]` = 40 bytes |
| `Address` | `types.Address` | Yes | Determines embedded vs. user path |
| `ToAddress` | `types.Address` | Yes | Send-only; `ZeroAddress` for receive blocks |
| `Amount` | `*big.Int` | Yes (32-byte padded) | Send-only; zero/nil for receive blocks |
| `TokenStandard` | `ZenonTokenStandard` | Yes | Send-only; zero for receive blocks |
| `FromBlockHash` | `types.Hash` | Yes | Receive-only; zero for send blocks |
| `DescendantBlocks` | `[]*AccountBlock` | Yes (via hash) | Contract receive only; **order is consensus-critical** |
| `Data` | `[]byte` | Yes (hash-of-data) | Max 16 384 bytes (full state only) |
| `FusedPlasma` | `uint64` | Yes | |
| `Difficulty` | `uint64` | Yes | PoW checked if non-zero |
| `Nonce` | `[8]byte` | Yes (raw 8 bytes) | |
| `BasePlasma` | `uint64` | **No** | Computed during VM application (full state only) |
| `TotalPlasma` | `uint64` | **No** | Computed during VM application (full state only) |
| `ChangesHash` | `types.Hash` | **No** | Used in contract receive regeneration (full state only) |
| `producer` | `*types.Address` | **No** | Cache only |
| `PublicKey` | `ed25519.PublicKey` | **No** | User blocks: non-empty; contract blocks: must be empty |
| `Signature` | `[]byte` | **No** | User blocks: non-empty; contract blocks: must be empty |

**[CODE]** `ComputeHash()` — exact field order, raw concatenation:

```
SHA3-256(
  Uint64BE(Version)[8]                     ||
  Uint64BE(ChainIdentifier)[8]             ||
  Uint64BE(BlockType)[8]                   ||
  PreviousHash[32]                         ||
  Uint64BE(Height)[8]                      ||
  MomentumAcknowledged.Hash[32]            ||   ← Hash first
  Uint64BE(MomentumAcknowledged.Height)[8] ||   ← then Height
  Address[20]                              ||
  ToAddress[20]                            ||
  BigInt32(Amount)[32]                     ||   ← 32-byte left-padded; nil → 32 zero bytes
  TokenStandard[10]                        ||
  FromBlockHash[32]                        ||
  DescendantBlocksHash()[32]               ||
  SHA3-256(Data)[32]                       ||   ← hash of raw Data bytes
  Uint64BE(FusedPlasma)[8]                ||
  Uint64BE(Difficulty)[8]                 ||
  Nonce[8]                                    ← raw 8 bytes, not encoded
)
```

`chain/nom/account_block.go` → `ComputeHash()`

**[CODE]** Hash must be verified before signature: the signature is `ed25519.Verify(block.PublicKey, block.Hash.Bytes(), block.Signature)`. `block.Hash` is only trustworthy after `ComputeHash() == block.Hash` is confirmed.

**[CODE]** `DescendantBlocksHash()`:

```
SHA3-256( concat( dBlock.Hash[32] for each descendant in slice order ) )
```

Reordering `DescendantBlocks` changes this hash and invalidates `block.Hash`.

**Amount constraint: [CODE]** Verifier enforces `Amount.BitLen() <= 255`. Maximum accepted value is `2^255 − 1`. `verifier/account_block.go:209`.

### 2.5 Block Types

**[CODE]** `chain/nom/account_block.go`:

| Constant | Value | `IsSendBlock()` | `IsReceiveBlock()` | Signer |
|---|---|---|---|---|
| `BlockTypeGenesisReceive` | 1 | false | true | — (genesis only) |
| `BlockTypeUserSend` | 2 | true | false | User (ed25519) |
| `BlockTypeUserReceive` | 3 | false | true | User (ed25519) |
| `BlockTypeContractSend` | 4 | true | false | Contract (no key/sig) |
| `BlockTypeContractReceive` | 5 | false | true | Contract (no key/sig) |

```
IsSendBlock(type)    ⟺  type ∈ {UserSend, ContractSend}
IsReceiveBlock(type) ⟺  type ∈ {UserReceive, ContractReceive, GenesisReceive}
```

Type constraints:
- `BlockTypeGenesisReceive` is rejected by all external verifier entry points.
- `BlockTypeContractSend` is rejected by all external verifier entry points. These blocks appear only as entries in `block.DescendantBlocks` of a `ContractReceive` block.
- `IsEmbeddedAddress(block.Address)` ⟺ `BlockType ∈ {ContractSend, ContractReceive}`.
- User address ⟺ `BlockType ∈ {UserSend, UserReceive}`.

**[CODE]** Blocks appearing as top-level entries in `Momentum.Content` are therefore limited to: `UserSend`, `UserReceive`, `ContractReceive`. `ContractSend` blocks never appear at the top level of Content; they appear only as descendants.

### 2.6 Previous() — Batch-Sensitive Link

**[CODE]** `chain/nom/account_block.go` → `Previous()`:

```
if len(block.DescendantBlocks) != 0:
    return block.DescendantBlocks[0].Previous()
else:
    return HashHeight{ Hash: block.PreviousHash, Height: block.Height - 1 }
```

**[INFERRED]** For a `ContractReceive` block with descendants, `Previous()` traverses into the first descendant's `Previous()`. The per-address continuity check in the momentum verifier uses this method, making the effective ordering unit for embedded batches the entire `(DescendantBlocks…, ContractReceive)` sequence.

---

## 3. Embedded Contract Addresses

**[CODE]** `common/types/address.go`:

| Contract | Address (bech32) |
|---|---|
| `PillarContract` | `z1qxemdeddedxpyllarxxxxxxxxxxxxxxxsy3fmg` |
| `PlasmaContract` | `z1qxemdeddedxplasmaxxxxxxxxxxxxxxxxsctrp` |
| `TokenContract` | `z1qxemdeddedxt0kenxxxxxxxxxxxxxxxxh9amk0` |
| `SentinelContract` | `z1qxemdeddedxsentynelxxxxxxxxxxxxxwy0r2r` |
| `SwapContract` | `z1qxemdeddedxswapxxxxxxxxxxxxxxxxxxl4yww` |
| `StakeContract` | `z1qxemdeddedxstakexxxxxxxxxxxxxxxxjv8v62` |
| `SporkContract` | `z1qxemdeddedxsp0rkxxxxxxxxxxxxxxxx956u48` |
| `LiquidityContract` | `z1qxemdeddedxlyquydytyxxxxxxxxxxxxflaaae` |
| `AcceleratorContract` | `z1qxemdeddedxaccelerat0rxxxxxxxxxxp4tk22` |
| `HtlcContract` | `z1qxemdeddedxhtlcxxxxxxxxxxxxxxxxxygecvw` |
| `BridgeContract` | `z1qxemdeddedxdrydgexxxxxxxxxxxxxxxmqgr0d` |

`IsEmbeddedAddress(addr)` checks `addr[0] == 0x01`.

---

## 4. Chain Parameters

**[CODE]** Mainnet embedded genesis: `chain/genesis/embedded_genesis_string.go`

| Parameter | Value |
|---|---|
| `ChainIdentifier` | `1` |
| `GenesisTimestampSec` | `1637755200` (Unix) |
| Genesis momentum hash | `9e204601d1b7b1427fe12bc82622e610d8a6ad43c40abf020eb66e538bb8eeb0` |
| `ExtraData` (genesis `Data` field) | `000000000000000000004dd040595540d43ce8ff5946eeaa403fb13d0e582d8f#We are all Satoshi#Don't trust. Verify` |
| `SporkAddress` | `z1qpxswrfnlll355wrx868xh58j7e2gu2n2u5czv` |

### 4.1 Genesis Trust Anchor

**[CODE]** `chain/genesis/momentum.go` bypasses the normal verifier for the genesis momentum. The genesis momentum has:

- `Height = 1`; `PreviousHash = ZeroHash`.
- `Data = []byte(GenesisConfig.ExtraData)` — the only momentum where `Data` is non-empty.
- `PublicKey = empty`; `Signature = empty` — unsigned.
- `ChangesHash` is computed from the genesis state patch but cannot be independently verified without replaying genesis account block construction.

**[UNKNOWN]** There is no code-defined canonical procedure for genesis verification. The normal momentum verifier explicitly rejects `Height == 1` with `ErrMNotGenesis`. A verifier must be initialized with one of:

1. The canonical genesis momentum hash (`9e204601…`) accepted as an out-of-band trust anchor, or
2. The complete embedded genesis config JSON, replayed through genesis account block construction to independently derive the genesis momentum hash.

Without a trust anchor, there is no code-defined entry point into the verified chain.

---

## 5. Consensus Constants

**[CODE]** `vm/constants/consensus.go`

| Constant | Value |
|---|---|
| `BlockTime` | 10 seconds |
| `NodeCount` | 30 |
| `RandCount` | 15 |
| `CountingZTS` | ZNN (`zts1znnxxxxxxxxxxxxx9z4ulx`) |

Tick duration: `BlockTime × NodeCount = 300 seconds`.

---

## 6. Validation Rules

### 6.1 Momentum — Raw Validation

Applies to non-genesis momentums (Height > 1). Checked in order by `rawMomentumVerifier.all()`. `verifier/momentum.go`.

**Chain identifier:**
- `ChainIdentifier != 0` → else `ErrMChainIdentifierMissing`
- `ChainIdentifier == momentumStore.ChainIdentifier()` → else `ErrMChainIdentifierMismatch`

**Version:**
- `Version != 0` → else `ErrMVersionMissing`
- `Version == 1` → else `ErrMVersionInvalid`

**[CODE]** `Version` is compared against the hardcoded value `1` with no spork gate. No code path accepts any other value for non-genesis momentums.

**Timestamp:**
- `Timestamp.Unix() != 0` → else `ErrMTimestampMissing`
- `!Timestamp.After(time.Now().Add(10s))` → else `ErrMTimestampInTheFuture`
- `TimestampUnix > previousFrontier.TimestampUnix` (strictly greater) → else `ErrMTimestampNotIncreasing`

**[INFERRED]** The `time.Now() + 10s` guard is only meaningful for live nodes. For archival or historical replay, this check must be skipped or substituted; applying it to blocks produced in the past causes all historical blocks to appear invalid.

**Previous linkage:**
- `Height != 1` → else `ErrMNotGenesis`
- `PreviousHash != ZeroHash` → else `ErrMPrevHashMissing`
- `momentum.Previous() == momentumStore.GetFrontierMomentum().Identifier()` → else `ErrMPreviousMissing`
  - `momentum.Previous()` = `HashHeight{ Hash: PreviousHash, Height: Height − 1 }`

**Data field:**
- `len(Data) == 0` → else `ErrMDataMustBeZero`

**Content:**
- `len(Content) <= 100` → else `ErrMContentTooBig`
- Build `blocksLookup = map[HashHeight → *AccountBlock]` from prefetched blocks.
- `len(blocksLookup) == len(Content)` → else error. Duplicates by `{Hash, Height}` collapse the map; uniqueness by `{Address, Height}` is not locally enforced here.
- Per-address continuity: for each `header` in `Content` (in list order):
  - Look up `block = blocksLookup[header.Identifier()]`.
  - If `isBatched(block)` is true (`block.IsSendBlock() && IsEmbeddedAddress(block.Address)`): skip continuity check; **do not advance** `heads[header.Address]`. The block must still be present in the lookup.
  - Otherwise: require `block.Previous() == heads[header.Address]`; then set `heads[header.Address] = block.Identifier()`.
  - Initial value of `heads[addr]`: `momentumStore.GetFrontierAccountBlock(addr).Identifier()` or `ZeroHashHeight` if none.

**[UNKNOWN]** The protocol intent for skipping continuity on batched (embedded send) blocks is not documented in code.

### 6.2 Momentum — Transaction Validation

Checked by `momentumTransactionVerifier.all()`. `verifier/momentum.go`.

**Step 1 — Changes hash (full state only):**
- `db.PatchHash(transaction.Changes) == transaction.Momentum.ChangesHash` → else `ErrMChangesHashInvalid`
- See §10 for critical portability limitations.

**Step 2 — Momentum hash:**
- `momentum.ComputeHash() == momentum.Hash` → else `ErrMHashInvalid`

**Step 3 — Signature (hash must be verified first):**
- `len(Signature) != 0` → else `ErrMSignatureMissing`
- `len(PublicKey) != 0` → else `ErrMPublicKeyMissing`
- `ed25519.Verify(PublicKey, momentum.Hash.Bytes(), Signature)` → else `ErrMSignatureInvalid`

**Step 4 — Producer:**
- `consensus.VerifyMomentumProducer(momentum)` → else `ErrMProducerInvalid`. See §7.

### 6.3 AccountBlock — Structure and Reference Validation

`verifier/account_block.go`

**Preconditions:**
- `Height != 0` → else `ErrABMHeightMissing`
- `Height == 1 → PreviousHash == ZeroHash` → else `ErrABPrevHashMustBeZero`
- `Height != 1 → PreviousHash != ZeroHash` → else `ErrABPrevHashMissing`
- `MomentumAcknowledged != ZeroHashHeight` → else `ErrABMAMustNotBeZero`
- Momentum store for `MomentumAcknowledged` must exist → else `ErrABMAMissing`

**Version:** Must equal `1`. No spork gate.

**ChainIdentifier:** Must match `momentumStore.ChainIdentifier()`.

**BlockType:** See §2.5 constraints.

**Amounts — send blocks:**
- `Amount.Sign() >= 0` → else `ErrABAmountNegative`
- `Amount.BitLen() <= 255` → else `ErrABAmountTooBig`
- `Amount > 0 → TokenStandard != ZeroTokenStandard` → else `ErrABZtsMissing`
- `FromBlockHash == ZeroHash` → else `ErrABFromBlockHashMustBeZero`

**Amounts — receive blocks:**
- `Amount == nil or Amount == 0` → else `ErrABAmountMustBeZero`
- `TokenStandard == ZeroTokenStandard` → else `ErrABZtsMustBeZero`
- `ToAddress == ZeroAddress` → else `ErrABToAddressMustBeZero`
- `FromBlockHash != ZeroHash` → else `ErrABFromBlockHashMissing`

**PoW (if `Difficulty != 0`):**
- `IsEmbeddedAddress(block.Address)` → `ErrABPoWInvalid`
- `pow.CheckPoWNonce(block)` must return true → else `ErrABPoWInvalid`. See §8.

**Previous-link:**
- Embedded addresses: check skipped.
- Non-embedded, `Height > 1`: `accountStore.Frontier().Identifier() == block.Previous()` → else `ErrABPreviousMissing`.

**MomentumAcknowledged:**
- `momentumStore.GetFrontierMomentum().Identifier() == block.MomentumAcknowledged` → else `ErrABMAMissing`.
- Non-batched blocks: `previousBlock.MomentumAcknowledged.Height <= block.MomentumAcknowledged.Height` → else `ErrABMAGap`.
- Embedded receive blocks: all descendants must share the same `MomentumAcknowledged` → else `ErrABMAMustBeTheSame`; and `momentumStore.GetBlockConfirmationHeight(block.FromBlockHash) == block.MomentumAcknowledged.Height` → else `ErrABMAInvalidForAutoGenerated`.

**Receive linkage:**
- `FromBlockHash` must resolve to an existing send block → else `ErrABFromBlockMissing`.
- `accountStore.IsReceived(fromHash) == false` → else `ErrABFromBlockAlreadyReceived`.
- At `momentumStore.Identifier().Height >= 10109240`: `sendBlock.ToAddress == block.Address` → else `ErrABFromBlockReceiverMismatch`.

**[CODE]** `ReceiverMismatchEnforcementHeight = 10109240`. `verifier/account_block.go:18`.

**Embedded receive sequencer:** Applied when `IsEmbeddedAddress(block.Address) && block.IsReceiveBlock()`.

```
nextInLine = accountStore.SequencerFront(momentumStore.GetAccountMailbox(block.Address))
```

- `nextInLine == nil` → `ErrABSequencerNothing`
- `sendBlock = momentumStore.GetAccountBlockByHash(block.FromBlockHash)`
- `sendBlock.Header() != *nextInLine` → `ErrABSequencerNotNext`

See §6.4 for the full sequencer specification.

### 6.4 Sequencer — Complete Specification

**[CODE]** Sources: `chain/account/sequencer.go`, `chain/account/mailbox/mailbox.go`, `chain/momentum/ledger_store.go`, `vm/vm.go`.

The sequencer is a per-contract FIFO queue tracking which send blocks a given embedded contract must receive next, in the exact order they were committed to the chain.

**Queue population — push rule:**

When a momentum is applied, `vm.applyMomentum` iterates `Momentum.Content` in list order (`vm/vm.go:285–295`). For each header, `momentumStore.AddAccountBlockTransaction` is called, which processes:

```
blocks_to_process = [block] + block.DescendantBlocks   (in this exact order)
```

For each element `b` in `blocks_to_process`:

```
if b.IsSendBlock() AND IsEmbeddedAddress(b.ToAddress):
    mailbox(b.ToAddress).SequencerPushBack(b.Header())
```

`chain/momentum/ledger_store.go:73–95`

**[CODE]** Critical cases:

- `UserSend` to embedded: the parent block is pushed. It has no descendants. Exactly one entry is pushed per such block.
- `ContractReceive` with `ContractSend` descendants: the parent `ContractReceive` block has `IsSendBlock() = false` — it is **never pushed**. Only its `ContractSend` descendants that have `IsEmbeddedAddress(ToAddress) = true` are pushed, in `DescendantBlocks` slice order.
- `UserReceive`, `ContractReceive` with no embedded-targeting descendants: nothing is pushed.

**[CODE] Total ordering** of pushes for a given embedded contract address `C`:

```
Primary:   Momentum height ascending
Secondary: Position of parent block in Momentum.Content (list order)
Tertiary:  Position within [block] + block.DescendantBlocks (index 0 first)
           — filtered to only those elements where IsSendBlock() AND ToAddress == C
```

Any deviation in this ordering produces a different `SequencerFront()` result and causes embedded receive verification to fail.

**Queue state (logical):**

```
Queue is an ordered list of AccountHeaders, indexed by position (1-based)

SequencerPushBack(header):   append header to back; total_size += 1

SequencerFront(mailbox):
  if last_received == mailbox.total_size: return nil
  return entries[last_received + 1]

SequencerPopFront():         last_received += 1
```

`SequencerPopFront()` is called during contract receive application after all checks pass. `vm/vm.go:160–161`.

**[INFERRED]** Reconstructing the sequencer state requires replaying all committed momentums in height order, processing their `Content` entries in list order, and applying the push rule to each element of `[block] + block.DescendantBlocks`. This is a full-state requirement.

### 6.5 AccountBlock Transaction Validation

**Step 1 — Hash:**
- `block.Hash != ZeroHash` → else `ErrABHashMissing`
- `block.ComputeHash() == block.Hash` → else `ErrABHashInvalid`

**Step 2 — Signature (hash must be verified first):**
- Embedded address: `len(PublicKey) == 0` and `len(Signature) == 0` → else `ErrABPublicKeyMustBeZero` / `ErrABSignatureMustBeZero`.
- User address: non-empty `Signature` and `PublicKey` required.
- `ed25519.Verify(block.PublicKey, block.Hash.Bytes(), block.Signature)` → else `ErrABSignatureInvalid`.

**Step 3 — Producer:**
- User blocks only: `types.PubKeyToAddress(block.PublicKey) == block.Address` → else `ErrABPublicKeyWrongAddress`.

**Step 4 — Descendants:**
- `!isContractReceive(block) → len(block.DescendantBlocks) == 0` → else `ErrABDescendantMustBeZero`.
- Each descendant must pass `accountBlockVerifier.all()`.

---

## 7. Consensus — Producer Election

**[CODE]** Sources: `consensus/election.go`, `consensus/election_algorithm.go`, `consensus/context.go`, `common/ticker.go`.

### 7.1 Tick Computation

```
tick = floor( (momentumTimestamp − genesisTimestamp).TotalSeconds / 300 )
```

`common/ticker.go` → `ToTick()`:

```
subSec = int64(time.Sub(startTime).Seconds())   ← truncated to integer seconds
tick   = uint64(subSec) / 300
```

### 7.2 Proof Block Selection

For `tick >= 2`:
```
proofTime  = genesisTime + 300 × (tick − 1)
proofBlock = latest momentum with Timestamp < proofTime (strictly, by nanoseconds)
```

For `tick < 2`:
```
proofTime  = genesisTime + 1 second
proofBlock = latest momentum with Timestamp < proofTime
```

`consensus/election.go` → `genProofTime()`, `getMomentumBeforeTime()`

### 7.3 Delegation Snapshot

**[CODE]** Delegations are read from state at `proofBlock.Identifier()`:

- `store.ComputePillarDelegations()` reads PillarContract storage.
- Pillar weights use ZNN balances: `getZnnBalance(backerAddress)`. `chain/momentum/balance.go`, `chain/momentum/embedded.go`.

**[INFERRED]** Reproducing delegation weights requires full state replay of all prior ZNN transfers and embedded contract mutations. This is a full-state requirement.

### 7.4 Election Algorithm

**[CODE]** `consensus/election_algorithm.go` → `SelectProducers()`:

```
seed = int64(proofBlock.Height)
```

**[CODE]** The seed is derived from `proofBlock.Height` alone with no hash component. This is consensus-critical: any deviation in seed derivation breaks producer schedule computation.

```
1. Sort all delegations by weight descending.
2. If len(delegations) <= 30: groupA = all; groupB = empty.
   Else:                       groupA = top 30; groupB = remainder.
3. perm1 = rand.New(rand.NewSource(seed)).Perm(len(groupA))
   Select top 15 by perm1: result = groupA[perm1[0..14]]
   Move unselected groupA to groupB: groupB += groupA[perm1[15..29]]
4. perm2 = rand.New(rand.NewSource(seed + 1)).Perm(len(groupB))
   result += groupB[perm2[0..14]]
5. shuffle = rand.New(rand.NewSource(seed)).Perm(30)
   final_producers = result[shuffle[0]], result[shuffle[1]], ..., result[shuffle[29]]
6. Assign each producer a 10-second slot starting at genesisTime + 300 × tick.
7. Expected producer for a given timestamp = pillar whose slot contains that timestamp.
```

### 7.5 Spork-Gated Dispatch

**[CODE]** `common/types/spork.go`:

| Spork | SporkId |
|---|---|
| `AcceleratorSpork` | `6d2b1e6cb4025f2f45533f0fe22e9b7ce2014d91cc960471045fa64eee5a6ba3` |
| `HtlcSpork` | `ceb7e3808ef17ea910adda2f3ab547be4cdfb54de8400ce3683258d06be1354b` |
| `BridgeAndLiquiditySpork` | `ddd43466769461c5b5d109c639da0f50a7eeb96ad6e7274b1928a35c431d7b1b` |

These gates control which embedded contract method maps are active during execution. Required for full-state verification.

---

## 8. Proof of Work

**[CODE]** `pow/pow.go` → `CheckPoWNonce(block)`.

**PoW input hash** (not the block hash — a separate PoW-specific computation):

```
dataHash = SHA3-256( block.Address[20] || block.PreviousHash[32] )
```

**Target:**

```
threshold = 2^64 − floor(2^64 / block.Difficulty)
target[8] = Uint64LE(threshold)   ← little-endian
```

**Candidate:**

```
calc = SHA3-256( block.Nonce[8] || dataHash[32] )[:8]   ← first 8 bytes
```

**Validity (little-endian byte comparison, most significant byte at index 7):**

```
for i from 7 downto 0:
    if calc[i] > target[i]: return true
    if calc[i] < target[i]: return false
return true   ← equal is valid
```

- `Difficulty == 0`: PoW check is skipped entirely.
- `Difficulty != 0` and `IsEmbeddedAddress(block.Address)`: rejected.
- Maximum PoW difficulty: `94 500 × 1 500 = 141 750 000`.

---

## 9. Plasma (Full State Only)

A structural verifier MUST NOT enforce plasma limits. All checks in this section are full-state-only.

**[CODE]** `vm/constants/plasma.go`:

| Constant | Value |
|---|---|
| `AccountBlockBasePlasma` | 21 000 |
| `ABByteDataPlasma` | 68 per byte |
| `EmbeddedSimplePlasma` | 52 500 |
| `EmbeddedWWithdraw` | 73 500 |
| `EmbeddedWDoubleWithdraw` | 94 500 |
| `MaxFusionUnitsPerAccount` | 5 000 |
| `MaxFusionPlasmaForAccount` | 10 500 000 |
| `MaxPlasmaForAccountBlock` | 10 500 000 |
| `MaxPoWPlasmaForAccountBlock` | 94 500 |
| `PoWDifficultyPerPlasma` | 1 500 |
| `MaxDataLength` | 16 384 bytes |

`len(block.Data) > 16 384` → `ErrABDataTooBig`. **[CODE]** Enforced in `vm/plasma.go:94` during VM execution only.

---

## 10. State Commitment — ChangesHash

**[CODE]** `common/db/patch.go`, `verifier/momentum.go`:

```
Momentum.ChangesHash = SHA3-256( leveldb.Batch.Dump() )
```

where `Batch.Dump()` is the internal serialization of `github.com/syndtr/goleveldb v1.0.1-0.20210819022825-2ae1ddf74ef7`.

**[UNKNOWN — CRITICAL]** The exact byte encoding of `leveldb.Batch.Dump()` is not defined in this repository. It is an undocumented internal of the `syndtr/goleveldb` library with no stability guarantees across versions. Cross-language verifiers cannot safely derive this format from the Zenon codebase alone.

Additionally: whether all state-write code paths avoid Go map-iteration nondeterminism before issuing batch operations cannot be established without auditing every call site. Nondeterministic ordering would make `ChangesHash` unreproducible even within Go.

**Implications by verifier tier:**

**Structural verifier:** May skip `ChangesHash` validation for momentum. All other momentum fields can be independently verified.

**Full state verifier — momentum:** Must validate `db.PatchHash(transaction.Changes) == momentum.ChangesHash`. This requires exact replication of the goleveldb batch serialization.

**Full state verifier — contract receive blocks:** `ContractReceive` validity requires `generated.ChangesHash == block.ChangesHash` (the regenerated receive block's changes hash must match). **[CODE]** `vm/vm.go` → `applyBlock(...)` case `BlockTypeContractReceive`. Without reproducing `ChangesHash`, `ContractReceive` blocks cannot be fully validated — only their structural correctness can be checked. This is a hard limitation: a verifier that cannot reproduce `ChangesHash` cannot confirm correct embedded contract execution.

---

## 11. Minimal Data Requirements

### 11.1 Full Chain — Trustless State Verification

1. **Genesis trust anchor** (§4.1): canonical genesis hash or full genesis config JSON.
2. **For each momentum M (strict height order):** all `ComputeHash()` fields, PublicKey, Signature, full `Content` list.
3. **For each AccountBlock referenced by M.Content:** all `ComputeHash()` fields, PublicKey/Signature for user blocks, referenced send block for receive blocks.
4. **For embedded receive blocks:** referenced send block plus embedded method semantics.
5. **Embedded contract code:** `vm/embedded/implementation/*` and `vm/embedded/definition/*`.
6. **State at proof blocks:** ZNN balance ledger, PillarContract storage, for producer election.

### 11.2 Single Account Chain

1. All AccountBlocks for the target address and height range with correct linking.
2. Referenced send blocks for receive blocks.
3. All momentums referenced by `MomentumAcknowledged`, plus their momentum stores.
4. Sequencer state for any embedded contracts the account sends to.
5. Full state prefix for balance/plasma verification (full state only).

### 11.3 Single Transaction

**Structural:**
1. Full AccountBlock B to recompute `B.Hash` and verify signature.
2. Momentum M including B: full fields for hash/signature; full `Content` list (no compact proof exists).

**Full state:** all of the above plus VM state (balances, plasma, received-set, contract state).

---

## 12. Error Catalog

**[CODE]** `verifier/errors.go`

### Momentum Errors

| Error | Trigger |
|---|---|
| `ErrMVersionMissing` | `Version == 0` |
| `ErrMVersionInvalid` | `Version != 1` |
| `ErrMChainIdentifierMissing` | `ChainIdentifier == 0` |
| `ErrMChainIdentifierMismatch` | mismatch with store |
| `ErrMDataMustBeZero` | `len(Data) != 0` |
| `ErrMChangesHashInvalid` | computed ≠ stored (full state) |
| `ErrMHashInvalid` | `ComputeHash() != Hash` |
| `ErrMContentTooBig` | `len(Content) > 100` |
| `ErrMTimestampMissing` | `Timestamp.Unix() == 0` |
| `ErrMTimestampInTheFuture` | `> time.Now() + 10s` |
| `ErrMTimestampNotIncreasing` | `TimestampUnix <= prev` |
| `ErrMSignatureMissing` | empty |
| `ErrMPublicKeyMissing` | empty |
| `ErrMSignatureInvalid` | ed25519 fail |
| `ErrMPrevHashMissing` | zero |
| `ErrMNotGenesis` | `Height == 1` in non-genesis path |
| `ErrMProducerInvalid` | consensus fail |
| `ErrMPreviousMissing` | frontier mismatch |

### AccountBlock Errors

| Error | Trigger |
|---|---|
| `ErrABVersionMissing` | `Version == 0` |
| `ErrABVersionInvalid` | `Version != 1` |
| `ErrABChainIdentifierMissing` | zero |
| `ErrABChainIdentifierMismatch` | mismatch |
| `ErrABTypeInvalidExternal` | `ContractSend` at top level |
| `ErrABTypeMissing` | `BlockType == 0` |
| `ErrABTypeMustNotBeGenesis` | `BlockTypeGenesisReceive` |
| `ErrABTypeMustBeContract` | embedded addr with user type |
| `ErrABTypeMustBeUser` | user addr with contract type |
| `ErrABMHeightMissing` | `Height == 0` |
| `ErrABPrevHashMustBeZero` | `Height == 1`, PreviousHash non-zero |
| `ErrABPrevHashMissing` | `Height > 1`, PreviousHash zero |
| `ErrABAmountNegative` | send, `Amount < 0` |
| `ErrABAmountTooBig` | `Amount.BitLen() > 255` |
| `ErrABAmountMustBeZero` | receive with non-zero |
| `ErrABZtsMissing` | `Amount > 0` but zero ZTS |
| `ErrABZtsMustBeZero` | receive with non-zero ZTS |
| `ErrABToAddressMustBeZero` | receive, non-zero ToAddress |
| `ErrABFromBlockHashMustBeZero` | send, non-zero FromBlockHash |
| `ErrABFromBlockHashMissing` | receive, zero FromBlockHash |
| `ErrABHashMissing` | `Hash == ZeroHash` |
| `ErrABHashInvalid` | `ComputeHash() != Hash` |
| `ErrABDataTooBig` | `len(Data) > 16384` (full state) |
| `ErrABPublicKeyWrongAddress` | `PubKeyToAddress(PK) != Address` |
| `ErrABPublicKeyMissing` | user block, empty |
| `ErrABPublicKeyMustBeZero` | contract block, non-empty |
| `ErrABSignatureInvalid` | ed25519 fail |
| `ErrABSignatureMissing` | user block, empty |
| `ErrABSignatureMustBeZero` | contract block, non-empty |
| `ErrABPoWInvalid` | PoW fail or embedded attempted PoW |
| `ErrABDescendantMustBeZero` | non-contract-receive has descendants |
| `ErrABDescendantVerify` | descendant fails structure checks |
| `ErrABPreviousMissing` | frontier ≠ `block.Previous()` |
| `ErrABMAGap` | `MA.Height < prev.MA.Height` |
| `ErrABMAMustBeTheSame` | batch descendants differ on MA |
| `ErrABMAInvalidForAutoGenerated` | confirmation height ≠ MA.Height |
| `ErrABMAMissing` | MA momentum store not found |
| `ErrABMAMustNotBeZero` | MA is zero |
| `ErrABFromBlockMissing` | FromBlockHash doesn't resolve |
| `ErrABFromBlockAlreadyReceived` | already received |
| `ErrABFromBlockReceiverMismatch` | ToAddress mismatch at height ≥ 10109240 |
| `ErrABSequencerNothing` | embedded contract mailbox empty |
| `ErrABSequencerNotNext` | `sendBlock.Header() != sequencer.Front()` |

---

## 13. Known Gaps

| Gap | Severity | Detail |
|---|---|---|
| `leveldb.Batch.Dump()` encoding | **Critical** | Undocumented internal of `syndtr/goleveldb`. `ChangesHash` is not portable across implementations without exact replication of this format. |
| `ContractReceive` full validation | **Critical** | Requires reproducing `ChangesHash`. Without it, only structural correctness of contract receive blocks can be checked; embedded contract execution cannot be confirmed. |
| Map nondeterminism in batch construction | **High** | Cannot be ruled out without auditing every state-write call site. |
| Full embedded contract method semantics | **High** | `vm/embedded/implementation/*` — not enumerated here. |
| Genesis `ChangesHash` reproducibility | **Medium** | Requires full replay of genesis account block construction. |
| Embedded contract ABI storage keyspace | **Medium** | Distributed across `vm/embedded/definition/*`; not enumerated. |
