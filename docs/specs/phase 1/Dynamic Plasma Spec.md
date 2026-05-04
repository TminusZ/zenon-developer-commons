# Zenon Dynamic Plasma Specification

**Status:** Implementation Ready
**Scope:** Protocol-level adaptive Plasma multiplier for go-zenon go-zenon
**Purpose:** Adjust required Plasma dynamically based on sustained observed Plasma-volume pressure
**Consensus Impact:** Yes
**Economic Impact:** Yes
**Current P2P Impact:** None
**ChainBridge Impact:** None

---

## Purpose

Dynamic Plasma introduces an epoch-based multiplier:

```text id="gk5n2x"
M
```

that adjusts transaction Plasma requirements according to observed base Plasma consumption.

Validation requirement:

```text id="d7r4mp"
required_plasma(tx) = ceil(base_required_plasma(tx) × M)
```

Dynamic Plasma:

* preserves the existing base Plasma table
* modifies required Plasma at validation time only
* measures Plasma-volume pressure, not transaction-count pressure
* smooths adjustments over time
* decays slowly after congestion
* uses deterministic fixed-point arithmetic only

Dynamic Plasma does not:

* mutate stored base Plasma
* change transaction hash semantics
* use floating-point arithmetic in consensus logic
* count mempool activity as utilization
* count rejected transactions as utilization

---

## Design Goals

1. **Determinism**
   All nodes compute the same multiplier from the same canonical chain history.

2. **Smooth Adjustment**
   One congested epoch should not cause violent multiplier jumps.

3. **Congestion Resistance**
   Sustained high utilization should raise Plasma requirements meaningfully.

4. **Slow Recovery**
   Multiplier decay should be gradual after congestion.

5. **Minimal Intrusion**
   Existing Plasma accounting should be reused where possible.

6. **Resource Pressure Focus**
   Data-heavy transactions intentionally contribute more utilization pressure than simple transfers.

---

## Constants

```go id="s5n8qk"
const MScale uint64 = 1_000_000

const MInitial uint64 = 1_000_000 // 1.0x
const MMin     uint64 =   500_000 // 0.5x
const MMax     uint64 = 5_000_000 // 5.0x

const TargetLowFP  uint64 = 450_000 // 45%
const TargetHighFP uint64 = 650_000 // 65%

const AlphaUpFP   uint64 = 500_000 // 0.50
const BetaDownFP  uint64 = 100_000 // 0.10

const EMAOldFP    uint64 = 750_000 // 0.75
const EMATargetFP uint64 = 250_000 // 0.25

const EpochLengthMomentums uint64 = 720
```

Fixed-point scale:

```text id="s8w1rv"
1.0x = 1,000,000
0.5x =   500,000
5.0x = 5,000,000
```

---

## Baseline Denominator

Simple-transfer saturation baseline:

```go id="n4k7tw"
const SimpleTransferBasePlasma uint64 = 21_000
const MaxAccountBlocksPerMomentum uint64 = 100

const BaselinePlasmaPerMomentum uint64 =
    MaxAccountBlocksPerMomentum * SimpleTransferBasePlasma

const BaselinePlasmaPerEpoch uint64 =
    BaselinePlasmaPerMomentum * EpochLengthMomentums
```

Result:

```text id="z2m6ph"
BaselinePlasmaPerEpoch = 1,512,000,000
```

This baseline intentionally represents:

> simple-transfer saturation

not:

> theoretical byte-capacity saturation

---

## Activation

Dynamic Plasma activates at:

```text id="f6q2vm"
activationHeight
```

Before activation:

> Plasma behavior remains unchanged

At activation:

```text id="a1r8nk"
M = MInitial
epoch_consumed_base_plasma = 0
```

Activation height is protocol-defined and must be agreed by all upgraded nodes.

---

## Base Plasma Rule

Canonical accounting always uses:

```text id="r3t9wp"
base_required_plasma(tx)
```

not multiplied required Plasma.

Correct:

```text id="v7n4cx"
epoch_consumed_base_plasma += base_required_plasma(tx)
```

Incorrect:

```text id="q2k5hs"
epoch_consumed_base_plasma += required_plasma(tx)
```

Using multiplied Plasma creates recursive feedback and is forbidden.

---

## Epoch Accounting

For each accepted account block in canonical momentum history:

```go id="u6m1pv"
base := base_required_plasma(block)
epoch_consumed_base_plasma += base
```

Only accepted canonical blocks count.

Never count:

* mempool transactions
* rejected transactions
* orphaned blocks
* local construction attempts
* duplicate replay outside canonical order

---

## Epoch Boundary

Epoch index:

```text id="h4x7qn"
(height - activationHeight) / EpochLengthMomentums
```

Boundary order is canonical:

1. close epoch
2. compute utilization
3. compute multiplier target
4. apply EMA smoothing
5. clamp multiplier
6. store new multiplier
7. reset epoch accumulator
8. begin next epoch

Boundary momentum transactions count in the closing epoch before multiplier update.

No off-by-one ambiguity is permitted.

---

## Utilization Calculation

Fixed-point utilization:

U = \min\left(\frac{\text{epoch_consumed_base_plasma}}{\text{BaselinePlasmaPerEpoch}}, 1\right)

Canonical function:

```go id="e5k3mr"
func ComputeUtilizationFP(consumed uint64) uint64 {
    u := (consumed * MScale) / BaselinePlasmaPerEpoch
    if u > MScale {
        return MScale
    }
    return u
}
```

Range:

```text id="w9p4kv"
U_fp ∈ [0, 1,000,000]
```

Utilization is clamped to 1.0.

---

## Multiplier Adjustment Rule

Three cases:

### Congestion

If:

```text id="k1m8qp"
U_fp > TargetHighFP
```

Increase multiplier proportionally.

---

### Underload

If:

```text id="b4r7nw"
U_fp < TargetLowFP
```

Decrease multiplier gradually.

---

### Deadband

If:

```text id="m2q5tx"
TargetLowFP <= U_fp <= TargetHighFP
```

Keep multiplier unchanged.

Deadband prevents oscillation near target utilization.

---

## EMA Smoothing

After target calculation:

M_{ema} = \frac{M_{old}\cdot EMAOldFP + M_{target}\cdot EMATargetFP}{MScale}

Then clamp:

```text id="c6t1vz"
M_new = clamp(M_ema, MMin, MMax)
```

Canonical order:

> compute target → EMA → clamp → store

Never clamp before EMA.

---

## Arithmetic Rules

Consensus arithmetic must use:

> fixed-point integers only

Forbidden:

* float32
* float64
* non-deterministic rounding

Rounding policy:

* adjustment arithmetic → truncate toward zero
* EMA arithmetic → truncate toward zero
* required Plasma application → ceiling

Each rounding rule is intentional and consensus-critical.

---

## Overflow Safety

Congestion / underload delta:

```text id="r8k2mw"
(a × b × c) / denom
```

Canonical helper:

```go id="p5v7qn"
func MulDiv3(a uint64, b uint64, c uint64, denom uint64) uint64 {
    return (a * b * c) / denom
}
```

Current constant bounds fit safely within:

```text id="j4x9tc"
uint64
```

Any future constant increase requires overflow proof to be rerun.

Overflow assumptions are part of consensus safety.

---

## Applying the Multiplier

Validation requirement:

required_plasma = \left\lceil \frac{base_required_plasma \cdot M}{MScale} \right\rceil

Canonical function:

```go id="n1q8rw"
func ApplyDynamicPlasmaMultiplier(base uint64, m uint64) uint64 {
    return (base*m + MScale - 1) / MScale
}
```

Ceiling is required.

Users must provide at least the required Plasma.

---

## Validation Rule

At validation:

```go id="t3m6px"
base := GetBasePlasmaForAccountBlock(context, block)
required := ApplyDynamicPlasmaMultiplier(base, currentMultiplier)

if block.TotalPlasma < required {
    return ErrNotEnoughTotalPlasma
}
```

Rule:

> compare provided Plasma against multiplied required Plasma

Stored base Plasma remains unchanged.

---

## Storage Rule

Dynamic Plasma must not mutate stored base Plasma.

Do not store:

> adjusted required Plasma

Compute adjusted requirement on demand.

This preserves:

* serialized account block format
* transaction hashing semantics
* historical compatibility

---

## Fused QSR Interaction

Dynamic Plasma scales:

> required Plasma

It does not scale:

> fused QSR Plasma cap

Under current bounds:

```text id="k7w3nr"
MMax = 5.0x
```

existing transaction classes remain below:

```text id="u2m9qx"
MaxPlasmaForAccountBlock
```

through multiplier scaling alone.

No new hard cap conflict is introduced by v0.8.

---

## Zero-Activity Epochs

If:

```text id="v5t1mk"
epoch_consumed_base_plasma = 0
```

Then:

```text id="q8n4rv"
U = 0
```

Multiplier decays gradually toward:

```text id="d1k7px"
MMin
```

There is no instant reset.

Slow recovery is intentional anti-gaming behavior.

---

## Persistence and Replay

Canonical authority:

> chain history

Persisted state is optimization only.

Required persisted fields:

* current_multiplier
* epoch_consumed_base_plasma

If persisted state is missing or inconsistent:

> replay canonical chain history

Replay authority overrides local persisted state.

Persisted cache is never consensus authority.

---

## Atomic Epoch Transition

Epoch close must be atomic:

```text id="m6v2qt"
old state
→ compute U
→ compute target
→ compute EMA
→ clamp
→ store new multiplier
→ reset accumulator
```

Partial application is forbidden.

Crash recovery must reproduce identical final state through replay.

Deterministic replay is mandatory.

---

## Integration Boundary

Recommended ownership:

**Chain layer**

* accounting
* epoch tracking
* multiplier state
* replay logic

**Validation / VM layer**

* multiplier application
* required Plasma enforcement

Accumulator fires only after:

> accepted canonical account block insertion

Never on mempool receipt.

Never on failed validation.

Never on orphaned data.

---

## Known Policy Tradeoff

v0.8 intentionally measures:

> Plasma-volume pressure

not:

> transaction-count pressure

Result:

data-heavy transactions push utilization upward aggressively.

This is:

> intentional policy

not:

> mechanical bug

Future versions may refine weighting or denominator design.

That is out of scope for v0.8.

---

## Security Considerations

Protections:

* fixed-point determinism
* canonical rounding rules
* explicit epoch boundary semantics
* replay authority
* overflow-bounded arithmetic
* EMA damping against spike abuse
* slow recovery against reset gaming

Known behavior:

* sustained congestion raises cost
* single-epoch spikes are dampened
* oscillation should remain stable
* data-heavy spam raises pressure quickly by design

Consensus safety depends on exact arithmetic rules remaining canonical.

---

## Final Rule

Dynamic Plasma computes:

> deterministic epoch utilization → deterministic multiplier → deterministic required Plasma

Invariant:

> account for base Plasma
> multiply only at validation
> replay from canonical chain
> never trust local persisted cache over chain history
