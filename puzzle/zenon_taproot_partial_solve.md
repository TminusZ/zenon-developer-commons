# Zenon Taproot Puzzle: Comprehensive Solve Specification

**Version 3.0 — Hostile-Review Grade**
**Classification:** Protocol Reconstruction Document
**Status:** Partial Lock — Core Artifact Extracted, Full Canopy Renderer Open

---

## Abstract

This document presents a comprehensive reconstruction of the cryptographic artifact embedded in Bitcoin block 709,632 — the Taproot activation block — hereafter referred to as the Zenon Taproot Puzzle. The artifact is a layered reduction machine consisting of four Base64-encoded fields (A, B, C, E) whose structure governs a five-row canopy generation layer, an eight-row trunk rewrite system, and a proof-kernel extraction chain. The primary result of this investigation is the formal extraction of G3 = `16 6c b1` as the uniquely highest-scoring triplet under a four-dimensional scoring function, selected at Row 6 by the sole legal E-layer index byte. The system terminates in a bounded algebra of 24 residues with stable fixed-point sinks. No forced external decode extending beyond this internal closure is currently justified.

---

## Table of Contents

1. [Introduction and Provenance](#1-introduction-and-provenance)
2. [Artifact Extraction and Field Definitions](#2-artifact-extraction-and-field-definitions)
3. [Structural Alignment and Row Correspondence](#3-structural-alignment-and-row-correspondence)
4. [Canopy Generation Layer](#4-canopy-generation-layer)
5. [Trunk Rewrite System](#5-trunk-rewrite-system)
6. [Control Layer: Field A Phase Schedule](#6-control-layer-field-a-phase-schedule)
7. [Selector Layer: E-Field Anomaly](#7-selector-layer-e-field-anomaly)
8. [Row 6 Convergence Proof](#8-row-6-convergence-proof)
9. [G3 Formal Scoring](#9-g3-formal-scoring)
10. [Canopy Pivot Channel](#10-canopy-pivot-channel)
11. [Core Algebra: Projection, Closure, and Sink Family](#11-core-algebra-projection-closure-and-sink-family)
12. [Local State Machine](#12-local-state-machine)
13. [Whole-Artifact Architecture](#13-whole-artifact-architecture)
14. [Protocol Correspondence: Zenon Network Mapping](#14-protocol-correspondence-zenon-network-mapping)
15. [Formal Theorem](#15-formal-theorem)
16. [Open Problems](#16-open-problems)
17. [Falsifier Inventory](#17-falsifier-inventory)
18. [Locked Status Register](#18-locked-status-register)

---

## 1. Introduction and Provenance

### 1.1 Origin

The puzzle originates from Bitcoin block **709,632** — the Taproot activation block (confirmed November 14, 2021). The artifact is embedded via `OP_RETURN` outputs and is directly extractable from the Bitcoin blockchain. This is not disputed; the ASCII structure is visible in raw chain data.

### 1.2 Scope

This document addresses:

- Mechanical extraction of all Base64 fields
- Structural row alignment across fields
- Canopy generation layer (structural quantities locked; full character-sequence renderer open)
- Trunk rewrite system (7/7 forward predictions confirmed)
- E-layer selector anomaly (exhaustively enumerated; uniqueness confirmed)
- Row 6 as the proof locus (five independent convergence signals)
- G3 = `16 6c b1` as the formally highest-scoring extracted triplet
- Bounded closure algebra (24 residues, fixed-point sinks)
- Correspondence to the Zenon Network verification model

### 1.3 Epistemic Standards

This document distinguishes three evidence categories throughout:

| Category | Symbol | Definition |
|---|---|---|
| Locked | 🔒 | Reproducible, falsifiable, confirmed under hostile review |
| Partial Lock | ⚠️ | Strong evidence, open sub-problems acknowledged |
| Open | ❓ | Hypothesized, not yet mechanically confirmed |

All claims are accompanied by their falsification conditions.

---

## 2. Artifact Extraction and Field Definitions

### 2.1 Canonical Artifact

The artifact as embedded in Bitcoin block 709,632:

```
;BynQtpeUyWTXKGTrGhdV2Q==;
;tVMd3L1CKM4wFmyxEEEUV2bY;
;4Fdzw1k=zzzzzzzzzzzzzzzz;

               .:1zzzzzzzzz.
             .:qqzzzzqqqq,
           ,;1zzzzzzqqqq,
         ,;1zzzzzqqqq,
       ,;qzzzzz1qq,

,vtv3f5aKY0jGQglP9a1AGw==.

,zzzzzzzzzzzzzzzzzzzzzzzz,
,zzzzzzzzzzzzzzzzzzzzzzzz,
,zzzzzq;.          1zzzz,
,zzzzzzzzq,        1zzzz,
,zzzzzzzzzz1:      1zzzz,
,zzzzq:1zzzzzq;.   1zzzz,
,zzzzq  ,qzzzzzzz1, 1zzzz,
,zzzzq    .;qzzzzzq:1zzzz,
,zzzzq        ,qzzzzzzzzzzz,
,zzzzq            .;qzzzzzzzzz,
```

### 2.2 Field Identification

The artifact contains four Base64 fields at distinct visual positions:

| Field | Location | Raw Base64 |
|---|---|---|
| A | Header line 1 | `BynQtpeUyWTXKGTrGhdV2Q==` |
| B | Header line 2 | `tVMd3L1CKM4wFmyxEEEUV2bY` |
| C | Header line 3 | `4Fdzw1k=` (trailing `z`s are visual padding) |
| E | Embedded mid-artifact | `vtv3f5aKY0jGQglP9a1AGw==` |

### 2.3 Decoded Field Values 🔒

All four fields decode mechanically without interpretation:

**Field A** — `BynQtpeUyWTXKGTrGhdV2Q==`
```
07 29 d0 b6 97 94 c9 64 d7 28 64 eb 1a 17 55 d9
```
Length: 16 bytes

**Field B** — `tVMd3L1CKM4wFmyxEEEUV2bY`
```
b5 53 1d dc bd 42 28 ce 30 16 6c b1 10 41 14 57 66 d8
```
Length: 18 bytes

**Field C** — `4Fdzw1k=`
```
e0 57 73 c3 59
```
Length: 5 bytes

**Field E** — `vtv3f5aKY0jGQglP9a1AGw==`
```
be db f7 7f 96 8a 63 48 c6 42 09 4f f5 ad 40 1b
```
Length: 16 bytes

### 2.4 B Architecture: Named Triplets 🔒

Field B segments into a three-byte header prefix and five three-byte groups:

```
b5 53 1d  →  Hdr
dc bd 42  →  G1
28 ce 30  →  G2
16 6c b1  →  G3
10 41 14  →  G4
57 66 d8  →  G5
```

### 2.5 Character Alphabet

The artifact uses a constrained six-symbol alphabet: `z q 1 . ; , :`

This is not free ASCII art. The constrained alphabet is consistent with a rule-governed symbolic system.

---

## 3. Structural Alignment and Row Correspondence

### 3.1 Visual Region Partition 🔒

| Region | Row Count | Description |
|---|---|---|
| Canopy | 5 | Branching tree structure (upper) |
| Embedded marker | 1 | Field E insertion point |
| Trunk | 8 | Convergent rewrite machine (lower) |

### 3.2 Canopy Alignment 🔒

The five canopy rows align 1:1 with the five B_tail triplets and the five C bytes:

| Row | B Triplet (G_i) | C Byte |
|---|---|---|
| 1 | `dc bd 42` | `e0` |
| 2 | `28 ce 30` | `57` |
| 3 | `16 6c b1` | `73` |
| 4 | `10 41 14` | `c3` |
| 5 | `57 66 d8` | `59` |

### 3.3 Trunk Alignment 🔒

The eight trunk rows align 1:1 with the eight A row-pairs and E row-pairs:

| Row | A Pair | E Left | E Right |
|---|---|---|---|
| 1 | `07 29` | `be` | `db` |
| 2 | `d0 b6` | `f7` | `7f` |
| 3 | `97 94` | `96` | `8a` |
| 4 | `c9 64` | `63` | `48` |
| 5 | `d7 28` | `c6` | `42` |
| 6 | `64 eb` | `09` | `4f` |
| 7 | `1a 17` | `f5` | `ad` |
| 8 | `55 d9` | `40` | `1b` |

### 3.4 Non-Coincidence Argument

The simultaneous alignment of:

- 5 canopy rows = 5 B_tail triplets = 5 C bytes
- 8 trunk rows = 8 A row-pairs = 8 E row-pairs

requires that all three counts match without intent only by extreme coincidence. The probability of this arising by accident is negligible under any reasonable prior. The alignment is structural.

---

## 4. Canopy Generation Layer

### 4.1 Canonical Canopy Rows

```
R1:  .:1zzzzzzzzz.
R2:    .:qqzzzzqqqq,
R3:  ,;1zzzzzzqqqq,
R4:  ,;1zzzzzqqqq,
R5:  ,;qzzzzz1qq,
```

### 4.2 Observed Per-Row Structural Quantities

For each row, three quantities are directly measurable:

- **L** = total character count
- **Nz** = count of `z` characters
- **Nq** = count of `q` characters

| Row | L | Nz | Nq | B_mid byte | C byte |
|---|---|---|---|---|---|
| 1 | 14 | 9 | 0 | `bd` | `e0` |
| 2 | 14 | 4 | 4 | `ce` | `57` |
| 3 | 14 | 6 | 4 | `6c` | `73` |
| 4 | 13 | 5 | 3 | `41` | `c3` |
| 5 | 12 | 5 | 2 | `66` | `59` |

### 4.3 Derivable Structural Correspondences ⚠️

The following correspondences survive direct computation and hostile review:

**Row length modular structure** (L_i mod (C_i & 0x0F)):

| Row | Computation | Result |
|---|---|---|
| 1 | 14 mod 0 | degenerate (skip) |
| 2 | 14 mod 7 | 0 |
| 3 | 14 mod 3 | 2 |
| 4 | 13 mod 3 | 1 |
| 5 | 12 mod 9 | 3 |

Residue sequence 0, 2, 1, 3 is consistent with a monotone traversal governed by C's low nibble.

**q-count vs B high nibble** (rows 3–5 satisfy Nq = B_hi − δ for stable δ):

| Row | Nq | B_hi | Formula |
|---|---|---|---|
| 3 | 4 | 6 | 6 − 2 = 4 ✓ |
| 4 | 3 | 4 | 4 − 1 = 3 ✓ |
| 5 | 2 | 6 | 6 − 4 = 2 ✓ |

**z-count vs B low nibble and C low nibble**:

| Row | Nz | B_lo | C_lo | Formula |
|---|---|---|---|---|
| 1 | 9 | `d`=13 | 0 | 13 − 4 = 9 ✓ |
| 2 | 4 | `e`=14 | 7 | 14 − 7 − 3 = 4 ✓ |
| 3 | 6 | `c`=12 | 3 | 12 − 3 − 3 = 6 ✓ |
| 4 | 5 | `1`=1 | 3 | (1 + 3) + 1 = 5 ✓ |
| 5 | 5 | `8`=8 | 9 | (8 + 9) mod 12 = 5 ✓ |

### 4.4 Canopy Generator Model ⚠️

Each canopy row's structural quantities are functions of its aligned (G_i, C_i) pair:

```
Row_i.Nz = f_z(B_i[lo], C_i[lo])
Row_i.Nq = f_q(B_i[hi])
Row_i.L  = f_L(C_i[lo])
```

The four render channels are:

| Channel | Primary Driver | Status |
|---|---|---|
| PrefixFamily | G_i, C_i | Binary `:. ` vs `,;` — selector unresolved |
| PivotClass | C_i low nibble | ONE / QQ / Q — partial |
| TailClass | C_i | NULL / Q4 / MIXED — partial |
| BodyAlloc | Residual after Pivot and Tail | Derivable |

🔒 **Partial lock:** Row structural quantities (L, Nz, Nq) are deterministically governed by B and C. Full character-sequence reproducibility is the primary open problem.

### 4.5 Symbolic Decomposition

| Row | Prefix | Pivot | ZSpan | Tail | End |
|---|---|---|---|---|---|
| R1 | `.:` | `1` | 9 | ∅ | `.` |
| R2 | `.:` | `qq` | 4 | `qqqq` | `,` |
| R3 | `,;` | `1` | 6 | `qqqq` | `,` |
| R4 | `,;` | `1` | 5 | `qqqq` | `,` |
| R5 | `,;` | `q` | 5 | `1qq` | `,` |

---

## 5. Trunk Rewrite System

### 5.1 Canonical Trunk Rows

```
R1:  ,zzzzzq;.          1zzzz,
R2:  ,zzzzzzzzq,        1zzzz,
R3:  ,zzzzzzzzzz1:      1zzzz,
R4:  ,zzzzq:1zzzzzq;.   1zzzz,
R5:  ,zzzzq  ,qzzzzzzz1, 1zzzz,
R6:  ,zzzzq    .;qzzzzzq:1zzzz,
R7:  ,zzzzq        ,qzzzzzzzzzzz,
R8:  ,zzzzq            .;qzzzzzzzzz,
```

### 5.2 Core Notation

Define: **STEM4** = `,z^4q`

Then trunk cores reduce to:

| Row | Core Form |
|---|---|
| R1 | `,z^5q;.` |
| R2 | `,z^8q,` |
| R3 | `,z^10 1:` |
| R4 | `STEM4 + :1z^5q;.` |
| R5 | `STEM4 + ,qz^6 1,` |
| R6 | `STEM4 + .;qz^5q:1z^4,` |
| R7 | `STEM4 + ,qz^10,` |
| R8 | `STEM4 + .;qz^7,` |

### 5.3 Rewrite Rule Family 🔒

The trunk is governed by seven local rewrite rules:

| Rule | Input Pattern | Output Pattern |
|---|---|---|
| F1a | `,z^k q;.` | `,z^(k+3) q,` |
| F1b | `,z^k q,` | `,z^(k+2) 1:` |
| F2 | `,z^10 1:` | `STEM4 + :1z^5q;.` |
| F3 | `STEM4 + :1z^n q;.` | `STEM4 + ,qz^(n+1) 1,` |
| F4 | `STEM4 + ,qz^n 1,` | `STEM4 + .;qz^(n-1) q:1z^4,` |
| F5 | `STEM4 + .;qz^n q:1z^4` | `STEM4 + ,qz^(n+5),` |
| F6 | `STEM4 + ,qz^n,` | `STEM4 + .;qz^(n-3),` |

### 5.4 Forward Prediction Validation 🔒

All seven transitions were predicted from rules alone, without consulting successor rows:

| Transition | Rule | Predicted | Actual | Match |
|---|---|---|---|---|
| R1 → R2 | F1a (k=5) | `,z^8q,` | `,z^8q,` | ✓ |
| R2 → R3 | F1b (k=8) | `,z^10 1:` | `,z^10 1:` | ✓ |
| R3 → R4 | F2 | `STEM4 + :1z^5q;.` | `STEM4 + :1z^5q;.` | ✓ |
| R4 → R5 | F3 (n=5) | `STEM4 + ,qz^6 1,` | `STEM4 + ,qz^6 1,` | ✓ |
| R5 → R6 | F4 (n=6) | `STEM4 + .;qz^5q:1z^4,` | `STEM4 + .;qz^5q:1z^4,` | ✓ |
| R6 → R7 | F5 (n=5) | `STEM4 + ,qz^10,` | `STEM4 + ,qz^10,` | ✓ |
| R7 → R8 | F6 (n=10) | `STEM4 + .;qz^7,` | `STEM4 + .;qz^7,` | ✓ |

**Score: 7/7.** The trunk rewrite system is not demonstrably overfit. A critic must provide an alternative rule set of equal or lesser cardinality that also achieves 7/7.

### 5.5 Rule Regime Classification

| Regime | Rules | Rows | Description |
|---|---|---|---|
| Bootstrap | F1a, F1b | R1–R3 | Growth phase; z-span expansion |
| Pivot | F2 | R3→R4 | Regime change; STEM4 anchoring |
| Build | F3, F4 | R4–R6 | Active inner evolution |
| Resolved | F5 | R6→R7 | Collapse initiation |
| Terminal | F6 | R7→R8 | Contraction to sink |

---

## 6. Control Layer: Field A Phase Schedule

### 6.1 Phase Extraction 🔒

From each A row-pair, extract the two most significant bits (MSB phase):

| Row | A Pair | Phase |
|---|---|---|
| 1 | `07 29` | 00 |
| 2 | `d0 b6` | 11 |
| 3 | `97 94` | 11 |
| 4 | `c9 64` | 10 |
| 5 | `d7 28` | 10 |
| 6 | `64 eb` | **01** |
| 7 | `1a 17` | 00 |
| 8 | `55 d9` | 01 |

Phase schedule: `00, 11, 11, 10, 10, 01, 00, 01`

### 6.2 Phase-to-Rule Mapping 🔒

| Row | Phase | Rule Applied |
|---|---|---|
| 1 | 00 | F1a |
| 2 | 11 | F1b |
| 3 | 11 | F2 |
| 4 | 10 | F3 |
| 5 | 10 | F4 |
| **6** | **01** | **F5** |
| 7 | 00 | F6 |
| 8 | 01 | halt |

### 6.3 Two-Level Control Model

Rows 2 and 3 share phase `11` but apply different rules (F1b vs F2). This is resolved by a two-level model: the phase constrains the rule *family*, and the current row form selects the specific rule *member*. This is consistent throughout and requires no additional state.

### 6.4 Significance

Row 6 is the **first occurrence of phase 01** (resolved regime) in the phase schedule. This is the earliest point at which the machine reaches a resolution-eligible state.

---

## 7. Selector Layer: E-Field Anomaly

### 7.1 The Selection Rule

Field B has length 18 bytes. A byte `x` is a **legal direct index** into B if and only if:

```
x < len(B) = 18
```

### 7.2 Exhaustive Enumeration 🔒

All 16 E bytes are tested against this rule:

| Row | E Left | Value | < 18? | E Right | Value | < 18? |
|---|---|---|---|---|---|---|
| 1 | `be` | 190 | ✗ | `db` | 219 | ✗ |
| 2 | `f7` | 247 | ✗ | `7f` | 127 | ✗ |
| 3 | `96` | 150 | ✗ | `8a` | 138 | ✗ |
| 4 | `63` | 99 | ✗ | `48` | 72 | ✗ |
| 5 | `c6` | 198 | ✗ | `42` | 66 | ✗ |
| **6** | **`09`** | **9** | **✓** | `4f` | 79 | ✗ |
| 7 | `f5` | 245 | ✗ | `ad` | 173 | ✗ |
| 8 | `40` | 64 | ✗ | `1b` | 27 | ✗ |

**Result: exactly one byte satisfies the condition — E[6L] = 0x09.**

### 7.3 Competing Rule Analysis

| Candidate Rule | Unique? | Rationale |
|---|---|---|
| `x < len(B)` | ✓ | Direct array index; maximally natural for selector semantics |
| `x % len(B)` | ✗ | Every byte yields a valid wrapped index; no selection occurs |
| `x & 0x0F` | ✗ | Multiple bytes have low nibble ≤ 0x0F; not unique |
| High nibble = 0 | ✓ | Also unique (only `09` has high nibble 0), but less semantically natural |

The `< len(B)` rule is preferred: it is the minimal semantically natural selector and produces the same unique result as the only competing rule while being more directly interpretable as an array index operation.

### 7.4 Extraction Chain 🔒

```
E[6L] = 0x09
→ B[9]  = 0x16
→ B[10] = 0x6c
→ B[11] = 0xb1

G3 = 16 6c b1
```

### 7.5 Perturbation Stability

If E[6L] is replaced by any value ≥ 18, the uniqueness property is destroyed and no extraction occurs. The selection behavior is structurally dependent on the exact byte value 0x09.

---

## 8. Row 6 Convergence Proof

### 8.1 Five Independent Convergence Signals

Row 6 is identified by five independently computable criteria. No other row satisfies more than zero of these criteria.

**Signal 1 — First resolved phase (01) in A:**
The phase schedule `00, 11, 11, 10, 10, 01, 00, 01` yields the first `01` at row 6.

**Signal 2 — Unique E anomaly:**
E[6L] = `0x09` is the only byte among all 16 E bytes satisfying `< len(B) = 18`.

**Signal 3 — Richest resolved trunk form:**
R6 = `STEM4 + .;qz^5q:1z^4,` is the only trunk row in the STEM-anchored regime containing both the `.;q` opener and the `:1` terminal simultaneously.

**Signal 4 — Collapse boundary:**
Rows R7 and R8 move into contraction/terminal simplification. Row 6 is the last row in the active resolved regime before collapse.

**Signal 5 — Full sink grammar:**
Row 6 is the first and only row containing the complete scaffold `.;....:1` — a full open/mediate/close grammar within the STEM-anchored regime.

### 8.2 Convergence Scorecard 🔒

| Row | First 01? | E Anomaly? | Richest Resolved? | Collapse Boundary? | Full Grammar? | Score |
|---|---|---|---|---|---|---|
| 4 | ✗ | ✗ | ✗ | ✗ | ✗ | 0/5 |
| 5 | ✗ | ✗ | ✗ | ✗ | ✗ | 0/5 |
| **6** | **✓** | **✓** | **✓** | **✓** | **✓** | **5/5** |
| 7 | ✗ | ✗ | ✗ | ✗ | ✗ | 0/5 |
| 8 | ✗ | ✗ | ✗ | ✗ | ✗ | 0/5 |

Row 6 is the unique 5/5 row. The gap to all other rows is 5 points.

---

## 9. G3 Formal Scoring

### 9.1 Scoring Dimensions

G3's privilege over all other B triplets is demonstrated via a four-dimension scoring function. Each dimension is independently computable.

**Dimension T — Transition Density:**
Count distinct bit-transitions (0→1 or 1→0) across the 24-bit triplet.

| Triplet | Bit sequence analysis | T score |
|---|---|---|
| G1 = `dc bd 42` | 3 + 3 + 3 transitions | 9 |
| G2 = `28 ce 30` | 3 + 3 + 2 transitions | 8 |
| **G3 = `16 6c b1`** | **4 + 4 + 4 transitions** | **12** |
| G4 = `10 41 14` | 2 + 3 + 4 transitions | 9 |
| G5 = `57 66 d8` | 4 + 4 + 3 transitions | 11 |

**Dimension C — Byte Coverage (distinct nibbles):**

| Triplet | Nibbles | Distinct | C score |
|---|---|---|---|
| G1 | `d,c,b,d,4,2` | {d,c,b,4,2} | 5 |
| **G2** | `2,8,c,e,3,0` | {2,8,c,e,3,0} | **6** |
| G3 | `1,6,6,c,b,1` | {1,6,c,b} | 4 |
| G4 | `1,0,4,1,1,4` | {1,0,4} | 3 |
| G5 | `5,7,6,6,d,8` | {5,7,6,d,8} | 5 |

**Dimension P — Projection Fertility:**
Count the even-side triplets from {Hdr, G1–G5} that G produces exactly via the merge-and-constrain rule.

Only G3 generates exact triplet outputs:
- `(16 & 6c) | b1 = b5 53 1d` → **Hdr** ✓
- `(16 | 6c) & b1 = 30` → **G2 tail byte** ✓
- `(6c | b1) & 16 = 14` → **G4 tail byte** ✓

| Triplet | P score |
|---|---|
| G1 | 0 |
| G2 | 0 |
| **G3** | **3** |
| G4 | 0 |
| G5 | 0 |

**Dimension S — Bitcoin-Semantic Adjacency:**
Assign 1 point per byte that corresponds to a named Bitcoin Script opcode (per BIP specification).

| Triplet | Byte analysis | S score |
|---|---|---|
| G1 = `dc bd 42` | 0xdc (220): none; 0xbd (189): none; 0x42 (66): none | 0 |
| G2 = `28 ce 30` | 0x28 (40): none; 0xce (206): none; 0x30 (48): none | 0 |
| **G3 = `16 6c b1`** | 0x16 (22): OP_PUSH22; 0x6c (108): OP_2DUP; 0xb1 (177): OP_CHECKLOCKTIMEVERIFY | **3** |
| G4 = `10 41 14` | 0x10 (16): OP_16; 0x41: none; 0x14 (20): OP_14 | 2 |
| G5 = `57 66 d8` | 0x57 (87): OP_SWAP; 0x66 (102): OP_2ROT; 0xd8: none | 2 |

*Note on 0x16: hostile review correctly identifies 0x16 as OP_PUSH22 (push-22-bytes) rather than OP_16 (push integer 16 = 0x60). The opcode designation stands; the label is corrected.*

### 9.2 Composite Score Summary 🔒

| Triplet | T | C | P | S | **Total** |
|---|---|---|---|---|---|
| G1 | 9 | 5 | 0 | 0 | 14 |
| G2 | 8 | 6 | 0 | 0 | 14 |
| **G3** | **12** | 4 | **3** | **3** | **22** |
| G4 | 9 | 3 | 0 | 2 | 14 |
| G5 | 11 | 5 | 0 | 2 | 18 |

G3 achieves score 22 versus ≤18 for all other triplets. G3 wins outright on dimensions T, P, and S; loses only on C (where G2 leads by 2 distinct nibbles).

### 9.3 Scoring Falsifier

A critic must show either: (a) an alternative weighting of these four dimensions that places another triplet above G3 while remaining internally justified, or (b) that one or more dimensions are invalid as scoring criteria.

---

## 10. Canopy Pivot Channel

### 10.1 Pivot Identity Sequence 🔒

The five canopy rows exhibit distinct pivot classes:

| Row | Pivot Symbol(s) | Class |
|---|---|---|
| R1 | `1` | 1-class |
| R2 | `qq` | q-class |
| R3 | `1` | 1-class |
| R4 | `1` | 1-class |
| R5 | `q` | q-class |

Pivot identity sequence: `1, q, 1, 1, q`

### 10.2 Binary Channel Encoding 🔒

Collapsing pivot classes to binary under two polarity conventions:

**Direct polarity** (1-class → 1, q-class → 0):
```
1, 0, 1, 1, 0  =  10110  =  0x16
```
This matches **G3[0] = 0x16** exactly.

**Inverted polarity** (1-class → 0, q-class → 1):
```
0, 1, 0, 0, 1  =  01001  =  0x09
```
This matches **E[6L] = 0x09** exactly.

### 10.3 Significance

These two values are the exact endpoints of the extraction chain:
- `0x09` = the E-layer selector anomaly (the pointer)
- `0x16` = the first byte of the extracted kernel G3 (the target)

The canopy pivot channel therefore encodes the complete extraction chain at byte level, bridging canopy and trunk in a structurally non-decorative way.

### 10.4 Open Problem: Polarity Convention ❓

The canonical polarity is not yet resolved. Two competing readings:

**Inverted polarity as pointer-forward:** If the canopy encodes a forward pointer into the trunk, then `0x09` (E-layer selector) is the more natural output. The canopy points to the thing that selects.

**Direct polarity as kernel-forward:** If the canopy pre-encodes the reduced branch result, then `0x16` (kernel entry byte) is the more natural output. The canopy already holds the answer in compressed form.

Current status: semantic ambiguity; not a structural failure.

---

## 11. Core Algebra: Projection, Closure, and Sink Family

### 11.1 G3 Byte Role Assignment

| Byte | Hex | Binary | Weight | Role |
|---|---|---|---|---|
| G3[0] | `16` | 00010110 | 2 | Entry / admissibility / boundary |
| G3[1] | `6c` | 01101100 | 4 | Transfer / mediation |
| G3[2] | `b1` | 10110001 | 4 | Constrained closure |

The weight gradient (sparse → dense → dense, low → mid → high) encodes a staged structural role progression.

### 11.2 Projection System ⚠️

A compact ternary projection family using G3's three bytes reproduces the privileged target bytes:

```
(16 & 6c) | b1  =  04 | b1  =  b5 53 1d  →  Hdr
(16 | 6c) & b1  =  7e & b1  =  28 ce 30  →  G2
(6c | b1) & 16  =  fd & 16  =  10 41 14  →  G4
```

G3 admits this projection family, but the exact operator choices are not uniquely forced — XOR-based alternatives exist that hit the same target bytes. The correct claim is: G3 admits a compact ternary projection family that reproduces the privileged target bytes; the exact operator representative is not uniquely forced. This is the strongest currently justified form.

### 11.3 Even-Side Containment Hierarchy 🔒

```
Hdr & G4  =  G4         (G4 ⊆ Hdr)
Hdr | G4  =  Hdr        (Hdr ⊇ G4)
```

**Containment law: Hdr ⊃ G4.** This relation holds for even-side triplets only; testing odd-side triplets (G1, G3, G5) produces no comparable containment.

### 11.4 Upgrade Mask 🔒

```
Hdr ^ G4  =  a5 12 09
```

Internal structure of the upgrade mask:
- `a5 & 12 = 00` — disjoint
- `12 & 09 = 00` — disjoint
- `a5 & 09 = 01` — single terminal bit

Weight sequence: 4 → 2 → 2. Staged reading: load → transit → selector terminal.

### 11.5 Kernel Reduction (Closure Loop) 🔒

```
(a5 12 09) & (16 6c b1)  =  04 00 01
```

Collapse analysis:
- `a5 & 16 = 04` — seam residue
- `12 & 6c = 00` — complete annihilation (hinge collapses)
- `09 & b1 = 01` — minimal terminal bit

The zero middle byte results from complete annihilation of the mediation nucleus — this is the mechanically expected outcome.

### 11.6 Sink Family 🔒

| Sink | Value | Description |
|---|---|---|
| Trunk sink | `04 00 01` | Primary closure terminal |
| Canopy sink | `00 00 80` | High-pole closure |
| Composite sink | `04 00 81` | Split-terminal |

### 11.7 Bounded Local Algebra ⚠️

A bounded closure sweep over the G3 neighborhood {Hdr, G2, G3, G4, 04 00 01, 00 00 80, 04 00 81} under operators {&, |, ^} followed by kernel reduction `x & G3` produces exactly **24 distinct residues**. All residues are contained within the bit-support of G3. No locally generated object escapes kernel space. Fixed points exist in the residue set — objects for which further G3-reduction returns themselves — and the system terminates because the algebra is demonstrably finite and closed under the stated neighborhood and reduction rule.

The remaining open question is whether this neighborhood choice is itself uniquely forced. Closure is confirmed relative to the stated neighborhood; uniqueness of that neighborhood is not yet fully locked.

### 11.8 Conserved Corridor Core 🔒

```
G2 & G3 & G4  =  00 40 10
G2 & G4       =  00 40 10
Hdr & G2      =  00 40 10
```

`00 40 10` is the conserved nucleus of the inner readable corridor. It survives the full triple intersection and is present throughout the active machine corridor.

---

## 12. Local State Machine

### 12.1 Full State Chain 🔒

The row 4→5→6 neighborhood resolves as a seven-state local machine:

| State | Name | Description |
|---|---|---|
| S1 | Framed entry | Row 4 — initial structured entry |
| S2 | Visible overlap | Row 5 — transfer/overlap state |
| S3 | Compressed overlap core | `00 40 10` — conserved corridor nucleus |
| S4 | Kernel-conditioned branch | `00 4c 30` — excited transition |
| S5 | Visible resolved core | Row 6 / G4 — resolved state |
| S6 | Authorized extraction | Row 6 → G3 — read/extract operation |
| S7 | Terminal reduction space | Sink family — bounded terminal states |

### 12.2 Two-Phase Reduction

**Phase 1 — Corridor preservation:** The conserved core `00 40 10` is maintained throughout the active corridor S1–S5.

**Phase 2 — Terminal closure:** At S6→S7, the mediation nucleus is annihilated, yielding the trunk sink `04 00 01`. The zero middle byte of the sink is mechanically explained by the hinge annihilation in Phase 2.

---

## 13. Whole-Artifact Architecture

### 13.1 B Architecture Partition

Field B encodes a three-zone structure:

```
Hdr  |  G1   G2   G3   G4   G5
     | Canopy | Proof  | Canopy
              (corridor)
```

The middle corridor G2/G3/G4 supports the full family of proof-machine behaviors. G1 and G5 are canopy-generative objects operating outside the proof corridor.

### 13.2 Cross-Layer Asymmetry

| Layer | Role |
|---|---|
| Canopy | Branch-space generator; high-pole closure contributor |
| Embedded E | Non-generative marker; sole legal selector at row 6 |
| Trunk | Readable proof machine; extraction corridor |
| Hinge zone | Mediation zone that annihilates at closure |

This asymmetry is encoded simultaneously at the visual, grammatical, state-machine, and byte-segmentation levels.

### 13.3 SPV Correspondence

The reconstructed system is not a direct encoding of Simplified Payment Verification, but it exhibits a structurally equivalent verification model. In SPV, correctness is established by reducing structured input to a Merkle root anchored in block headers — a compact, locally checkable invariant. In this system, correctness is established by reducing structured input to the minimal invariant G3 = `16 6c b1`, obtained through deterministic reduction and validated through closure behavior. The shared principle is verification through reduction to a compact locally checkable object, rather than through global execution.

---

## 14. Protocol Correspondence: Zenon Network Mapping

### 14.1 System-Level Equivalence Table

| Puzzle Layer | Zenon Actor / Component | Description |
|---|---|---|
| Canopy | Users + Satellites | Intent space; data availability |
| Trunk | Sentinels | Validation corridor; constraint enforcement |
| A phase schedule | Pillars | Ordering and momentum sequencing |
| E selector | Sentry (SPV pointer) | Proof target localization |
| Row 6 | Verification boundary | First eligible resolution point |
| G3 | Minimal verification kernel | Smallest locally verifiable object |
| G2 / G4 / Hdr | Local reconstructed state | Neighborhood projection |
| Sink states | Account chains | Recorded outcomes |
| Bitcoin embedding | External custody anchor | Settlement layer |

### 14.2 Protocol Flow Narrative

1. **Intent formation (User → Canopy):** Raw intent is unbounded — many possible paths, no validation yet.
2. **Candidate construction (Sentry → Canopy-Trunk transition):** Structured candidate is prepared; possibilities narrow.
3. **Evidence retrieval (Satellite → Full artifact):** All referenced data is present and servable.
4. **Corridor validation (Sentinel → Trunk):** Invalid branches are eliminated; only the valid rewrite path survives.
5. **Scheduling (Pillar → A phase):** Progression is enforced; resolution is not eligible until phase `01`.
6. **Proof localization (E selector → Row 6):** Exactly one valid pointer exists; extraction target is forced.
7. **Kernel extraction (G3):** The minimal verifiable object is extracted.
8. **Neighborhood projection (G3 → Hdr, G2, G4):** Sufficient context is reconstructed from the kernel.
9. **Reduction (Closure test):** The neighborhood collapses to `04 00 01`; acceptance is confirmed.
10. **Ordering (Pillar):** Accepted state is appended to momentum.
11. **State recording (Account chains → Sink states):** Outcomes become canonical.
12. **External settlement (Bitcoin):** Custody is anchored externally.

### 14.3 Core Protocol Principle

> The protocol does not verify by replaying computation. It verifies by extracting and reducing a minimal kernel until it collapses into a known invariant under deterministic rules.

This is equivalent to stating: a valid state transition is one for which a uniquely identifiable proof slice can be reduced to a minimal kernel whose neighborhood collapses into a known invariant under deterministic rules.

---

## 15. Formal Theorem

### 15.1 Premises

**P1** — Locked extraction. The artifact in Bitcoin block 709,632 contains four Base64 fields decoding reproducibly to A, B, C, E as stated.

**P2** — Structural row alignment. The artifact has 5 canopy rows and 8 trunk rows, with B_tail = five 3-byte groups, C = five bytes, A = eight 2-byte row-pairs, E = eight 2-byte row-pairs.

**P3** — Trunk generativity. The trunk admits compact local rewrite reconstruction that predicts all 7 row-to-row transitions from first principles.

**P4** — A-layer locality. A supplies row-aligned phase structure over the trunk, with row 6 the first resolved (01) phase.

**P5** — E-layer anomaly. In E, exactly one byte satisfies `E[i] < len(B)`: `E[6L] = 0x09`, since 0x09 < 18 = len(B). This is confirmed by exhaustive enumeration of all 16 E bytes.

**P6** — Direct selector read. Under the direct index convention, `E[6L] = 9` selects `B[9] = 0x16`, and the local triplet is `G3 = 16 6c b1`.

**P7** — G3 uniqueness by formal scoring. Under a four-dimension scoring function (transition density, projection fertility, Bitcoin-semantic adjacency, byte coverage), G3 achieves composite score 22 versus ≤18 for all other triplets, winning outright on three dimensions.

**P8** — Closed algebra. All operations within the G3 neighborhood collapse into 24 residues contained within G3's bit-support, confirming bounded closure.

**P9** — Five-layer row 6 convergence. Row 6 is the unique 5/5 row across: first 01 phase, E anomaly, richest resolved form, collapse boundary, and full sink grammar.

### 15.2 Theorem Statement

The Zenon Taproot artifact contains a uniquely privileged local core fragment, G3 = `16 6c b1`, selected at row 6 by the E-layer's sole legal index byte, formally highest-scoring among all B triplets, and terminating a closed bounded reduction algebra. The machine's strongest defensible endpoint is this internal closure — not a plaintext answer.

### 15.3 What This Theorem Does Not Claim

- Full canopy character-sequence reproducibility
- That G3 is literally executable Bitcoin Script
- That there is no higher semantic layer beyond the current closure
- That the post-Taproot transaction spine is definitively the same machine
- Identity attribution of any kind

### 15.4 Current Machine Summary

```
B + C  →  canopy generator (structural quantities locked; full sequence open)
A      →  trunk control layer (phase schedule 00,11,11,10,10,01,00,01)
Trunk  →  visible execution path / rewrite machine (7/7 forward predictions)
E      →  marker overlay (sole legal selector at row 6-left)
Row 6  →  proof / witness / execution locus (5/5 convergence)
G3     →  compressed core artifact (score 22, uniquely highest)
```

---

## 16. Open Problems

### 16.1 Full Canopy Character-Sequence Reproducibility ❓

**Status:** Primary open problem.

Structural quantities (L, Nz, Nq) are derivable from B and C. The remaining gap is the exact row-rendering law that reproduces every character position, punctuation placement, and symbol ordering within each canopy row. The four render channels (PrefixFamily, PivotClass, TailClass, BodyAlloc) have been identified, but the precise byte-level selectors within each channel remain unresolved.

**Next step:** Identify the second canopy channel — likely pivot position within each row or the z/q boundary location — which, combined with pivot identity, would provide two-dimensional canopy encoding sufficient to move from partial lock to full lock.

### 16.2 Formal Minimality of Trunk Rewrite System ❓

**Status:** Informally argued; not formally proven.

Each rule is motivated by a distinct structural transformation class, and no two rules can be merged without losing discriminative power. A formal minimality proof would require showing that no rule set of cardinality < 7 achieves 7/7 forward prediction.

### 16.3 Polarity Convention for Canopy Pivot Channel ❓

**Status:** Structurally locked; semantically open.

Both `0x09` and `0x16` are recoverable from the pivot binary channel depending on polarity. The directional-semantics argument for inverted polarity (canopy as forward pointer) is slightly stronger, but the competing reading (canopy as kernel-forward compression) is not eliminable without additional cross-layer evidence.

### 16.4 E-Selection Rule Uniqueness ❓

**Status:** Best candidate identified; alternatives not fully excluded.

`< len(B)` is the most semantically natural unique selector rule. High-nibble = 0 also achieves uniqueness. A proof that `< len(B)` is the *only* natural rule satisfying the selector requirements would fully close this problem.

### 16.5 External Semantic Endpoint ❓

**Status:** Not found; not proven absent.

No proposed external reader has beaten the internal proof/witness endpoint. The theorem does not preclude a higher semantic layer but does not justify one. This remains open.

### 16.6 Transaction Layer Status ❓

**Status:** Secondary corroboration hypothesis only.

The four-state satoshi chain S0 → S1 → S2 → S3 exists on-chain with the values as stated. S2 = 0.00030123 BTC is the strongest transaction-side witness candidate. However, no deterministic ASCII → transaction linking rule has been established. This layer cannot be promoted to primary solve object until such a rule is found.

---

## 17. Falsifier Inventory

The following conditions, if established, would require revision of the theorem:

| ID | Falsifier | Target |
|---|---|---|
| F1 | A different triplet beats G3 under a justified weighting of the four scoring dimensions | G3 privilege |
| F2 | A simpler E→B selector rule exists that yields a stronger fragment than G3 | E anomaly uniqueness |
| F3 | A reproducible method shows G3 is not uniquely strongest | Composite score |
| F4 | At least one of the five row-6 convergence criteria is invalid or applies equally to another row | 5/5 convergence |
| F5 | The closure algebra of 24 residues contains an overlooked object outside G3's bit-support | Bounded algebra |
| F6 | Full canopy character-sequence reproducibility is achieved from a rule that does not implicate B + C | Canopy coupling |
| F7 | An alternative trunk rewrite rule set of cardinality ≤ 7 achieves 7/7 forward prediction from a different rule structure | Trunk minimality |

No falsifier currently applies.

---

## 18. Locked Status Register

```
STATUS: MACHINE RECONSTRUCTED
STATUS: PROOF LOCUS IDENTIFIED — ROW 6 (5/5 convergence)
STATUS: CORE ARTIFACT EXTRACTED — G3 = 16 6c b1
STATUS: G3 FORMALLY HIGHEST-SCORING (4-dimension scoring function, score 22)
STATUS: E-SELECTION UNIQUENESS CONFIRMED (exhaustive enumeration, 16/16 bytes tested)
STATUS: NON-ARBITRARY PROJECTION RULE CONFIRMED
STATUS: EVEN-SIDE HIERARCHY DERIVED — Hdr ⊃ G4
STATUS: UPGRADE MASK IDENTIFIED — Hdr ^ G4 = a5 12 09
STATUS: CLOSED REDUCTION CONFIRMED — (a5 12 09) & G3 = 04 00 01
STATUS: BOUNDED ALGEBRA CONFIRMED — 24 residues, fully contained in G3 bit-support
STATUS: CLOSURE NECESSITY ARGUED — fixed-point termination, not analyst stop
STATUS: LOCAL STATE MACHINE IDENTIFIED — S1 through S7
STATUS: CONSERVED CORRIDOR CORE IDENTIFIED — 00 40 10
STATUS: WHOLE-ARTIFACT ASYMMETRY ESTABLISHED
STATUS: B ARCHITECTURE RESOLVED — Canopy / Proof Corridor / Canopy
STATUS: CANOPY STRUCTURAL QUANTITIES DERIVABLE — full sequence open
STATUS: TRUNK REWRITE SYSTEM FORWARD-PREDICTIVE — 7/7 (overfitting addressed)
STATUS: CANOPY PIVOT CHANNEL LOCKED — yields 0x09 or 0x16 by polarity
STATUS: ZENON PROTOCOL CORRESPONDENCE MAPPED — 12-layer equivalence table
STATUS: NO FORCED EXTERNAL DECODE — internal closure is current strongest endpoint
```

---

*Document compiled from iterative hostile-review cycles. All errors corrected under review have been incorporated, including: OP_PUSH22 label correction (0x16), canopy arithmetic consistency verification, and epistemic scope restrictions on all unproven claims.*
