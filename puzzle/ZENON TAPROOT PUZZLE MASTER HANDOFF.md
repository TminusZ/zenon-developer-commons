# Zenon Taproot Puzzle — Master Investigation Handoff

**Status:** Unsolved as final plaintext
**Artifact:** Bitcoin block 709,632 (Taproot activation block, 2021-11-14)
**Version:** Solve Candidate

---

## How to Use This Document

Read every section before responding. Do not re-derive confirmed results. Do not revisit falsified theories. The puzzle has a multi-layer architecture — treat each layer as distinct. Label every claim with its epistemic status: **Locked** (mechanically verified), **Strong Partial / Near-Locked** (reproducible, minimality or final proof pending), **Partial** (strong evidence, sub-problems open), or **Open** (hypothesized).

---

## 1. The Raw Artifact

20 OP_RETURN transactions from address `bc1qrnldpdlq9dsfy946m4vqa5mrec8qhdrx363end`, all in block 709,632, timestamp `2021-11-14 00:15:27`.

The artifact is **not** a single contiguous text block. It is 19 structural OP_RETURN fragments plus 1 terminal consolidation marker. The rendered ASCII tree below is an **assembled reconstruction**, not the raw storage format.

```
      ;BynQtpeUyWTXKGTrGhdV2Q==;
      ;tVMd3L1CKM4wFmyxEEEUV2bY;
      ;4Fdzw1k=zzzzzzzzzzzzzzzz;

                  .:1zzzzzzzzz.
                .:qqzzzzqqq,
             ,;1zzzzzqqq,
          ,;1zzzzzqqq,
       ,;qzzzzz1qq,

      ,vtv3f5aKY0jGQglP9a1AGw==.

      ,zzzzzzzzzzzzzzzzzzzzzzzz,
      ,zzzzzzzzzzzzzzzzzzzzzzzz,
      ,zzzzzq;.           1zzzz,
      ,zzzzzzzzq,         1zzzz,
      ,zzzzzzzzzz1:       1zzzz,
      ,zzzzq:1zzzzzq;.    1zzzz,
      ,zzzzq  ,qzzzzzz1,  1zzzz,
      ,zzzzq    .;qzzzzzq:1zzzz,
      ,zzzzq       ,qzzzzzzzzzz,
      ,zzzzq         .;qzzzzzzz,
ZENON NETWORK
```

**Constrained alphabet:** `z q 1 . : ; ,` — 7 symbols only. Not free ASCII art.

---

## 2. The Four Payload Fields

Canonical assignment by visual position in the rendered tree:

| Field | Base64 | Decoded Bytes | Length |
|---|---|---|---|
| A | `BynQtpeUyWTXKGTrGhdV2Q==` | `07 29 d0 b6 97 94 c9 64 d7 28 64 eb 1a 17 55 d9` | 16 bytes |
| B | `tVMd3L1CKM4wFmyxEEEUV2bY` | `b5 53 1d dc bd 42 28 ce 30 16 6c b1 10 41 14 57 66 d8` | 18 bytes |
| C | `4Fdzw1k=` | `e0 57 73 c3 59` | 5 bytes |
| E | `vtv3f5aKY0jGQglP9a1AGw==` | `be db f7 7f 96 8a 63 48 c6 42 09 4f f5 ad 40 1b` | 16 bytes |

**Field B segmented into six 3-byte groups** (Hdr + G1–G5; G3 indexing follows zero/one-based repo convention):

```
Hdr = b5 53 1d
G1  = dc bd 42
G2  = 28 ce 30
G3  = 16 6c b1   ← proof kernel candidate
G4  = 10 41 14
G5  = 57 66 d8
```

**C as ASCII string (artifact form, padded with z):**

```
Col:  0  1  2  3  4  5  6  7  8  9  10 11 12 ...
Char: 4  F  d  z  w  1  k  =  z  z  z  z  z  ...
```

---

## 3. Structural Layout

| Region | Rows | Description |
|---|---|---|
| Payload header | 3 | A, B, C — delimited by `;...;` |
| Canopy | 5 | Branching structure, right-to-left indent |
| E boundary | 1 | Asymmetric delimiters `,E.` |
| Trunk (idle) | 2 | Pure-z rows, nibbles `e` and `0` |
| Trunk (active) | 8 | Geometry-bearing rows, nibbles `5,7,7,3,c,3,5,9` |
| Terminal | 1 | `ZENON NETWORK` (terminal consolidation marker) |

**Key structural correspondences (all Locked):**

- C has 5 bytes ↔ 5 canopy rows
- C has 10 nibbles (`e,0,5,7,7,3,c,3,5,9`) ↔ 10 trunk rows
- B has 5 triplets (G1–G5) ↔ 5 canopy rows
- q count = 27; E terminal byte = `0x1b` = 27
- `;` count = 13 = count of `1` geometry symbols
- `:` count = 5 = canopy row count = C byte count

---

## 4. The Assembly Layer (Locked)

The 19 OP_RETURNs are unordered on-chain (same block, same second, txids are hash-random relative to content). The rendered tree is reconstructed from content alone using:

**Delimiter grammar — classifies every row:**

| Delimiter pattern | Row class |
|---|---|
| `;...;` | Payload rows (A, B, C) |
| `,...,` | Trunk rows |
| `.:...` | Canopy type A (rows 1–2) |
| `,;...` | Canopy type B (rows 3–5) |
| `,...`.` | E boundary row |

**C as assembly key:** C nibbles (`e,0,5,7,7,3,c,3,5,9`) sequence the 10 trunk rows. Active trunk rows self-order by internal geometry against this sequence. The tree reconstructs uniquely except for two genuine ambiguities: the two identical idle trunk rows and the two identical canopy-B rows (both expected, both inconsequential).

**C therefore serves three roles simultaneously:**
1. Control word (describes execution)
2. Trunk execution schedule
3. Trunk assembly key for unordered OP_RETURN fragments

---

## 5. The Geometry Layer (Locked)

The artifact contains two geometry symbol types inside the tree structure.

**Coordinate table (row-local, 0-based — valid for projection, NOT for absolute canvas graph):**

| Type | Coordinates (row, col) |
|---|---|
| q | (1,2)(1,3)(1,8)(1,9)(1,10)(2,8)(2,9)(2,10)(3,8)(3,9)(3,10)(4,2)(4,9)(4,10)(7,6)(8,10)(10,5)(10,13)(11,5)(11,9)(12,5)(12,12)(12,18)(13,5)(13,15)(14,5)(14,18) |
| 1 | (0,2)(2,2)(3,2)(4,8)(7,19)(8,19)(9,12)(9,19)(10,7)(10,19)(11,16)(11,19)(12,20) |

**Counts:** q = 27, 1 = 13, z (geometry only) = 177

**Graph properties (row-local coordinates — topology claims require absolute-coordinate repass):**
- q nodes form one connected backbone, 27 nodes, 49 edges
- Two degree-1 terminals: (7,6) and (10,13)
- Dominant bottleneck: (4,9) — at the canopy/trunk boundary
- Canopy subgraph: dense, 14 nodes, 30 edges, 1 component
- Trunk subgraph: sparse, 13 nodes, 13 edges, 2 components

> **Coordinate warning:** All coordinates above are row-local (col 0 = first character of trimmed row). Canopy rows have staggered absolute indentation (~14, 12, 9, 6, 3, 0 leading spaces descending). Any claims about cross-row visual adjacency in the graph require an absolute-coordinate repass. Projection rule results are unaffected.

---

## 6. The ASCII Projection Machine (Locked)

**Rule:** `payload_col = geometry_col - 1`

Applied to any payload string, geometry symbols `q` and `1` at column `c` read the payload character at column `c-1`.

**Trunk phase matrix:**

| Row | Nibble | Active q cols | Active 1 cols | Total active |
|---|---|---|---|---|
| 5 | e | [] | [] | 0 |
| 6 | 0 | [] | [] | 0 |
| 7 | 5 | [6] | [19] | 2 |
| 8 | 7 | [10] | [19] | 2 |
| 9 | 7 | [] | [12,19] | 2 |
| 10 | 3 | [5,13] | [7,19] | 4 |
| 11 | c | [5,9] | [16,19] | 4 |
| 12 | 3 | [5,12,18] | [20] | 4 |
| 13 | 5 | [5,15] | [] | 2 |
| 14 | 9 | [5,18] | [] | 2 |

**Execution trace across all four payloads:**

| Phase | Nibble | A | B | C | E |
|---|---|---|---|---|---|
| 1 | e | — | — | — | — |
| 2 | 0 | — | — | — | — |
| 3 | 5 | pe | 1E | 1z | 5a |
| 4 | 7 | We | ME | zz | 0A |
| 5 | 7 | Xe | wE | zz | jA |
| 6 | 3 | wkTe | 3KFE | wkzz | fYlA |
| 7 | c | wWTe | 3myE | wzzz | f0PA |
| 8 | 3 | wXdV | 3wEU | wzzz | fjaw |
| 9 | 5 | wr | 3y | wz | fl |
| 10 | 9 | wd | 3E | wz | fa |

**Activation envelope:** 0, 0, 2, 2, 2, 4, 4, 4, 2, 2 — ramp / peak / decay pattern.

**C execution trace symbol behavior:**
- `1` appears once (phase 3), onset trigger
- `k` appears once (phase 6), transient at privilege onset, then normalizes to `z`
- `w` persists from phase 6 through terminal
- `z` is substrate/default state

**Canopy extraction (same rule applied to canopy rows):**

| Canopy row | Geometry cols | Payload cols | C output |
|---|---|---|---|
| 0 | [2] | [1] | F |
| 1 | [2,3,8,9,10] | [1,2,7,8,9] | Fd=zz |
| 2 | [2,8,9,10] | [1,7,8,9] | F=zz |
| 3 | [2,8,9,10] | [1,7,8,9] | F=zz |
| 4 | [2,8,9,10] | [1,7,8,9] | F=zz |

**Read sets and residues:**

| Payload | Read set | Residue |
|---|---|---|
| A | `tpeyWXKTrhdV` | `BynQUTGG2Q==` |
| B | `3L1KMwFyxEEU` | `tVMdC4mEV2bY` |
| E | `f5aY0GQlPa1A` | `vtv3Kjg9Gw==` |

**Protected anti-diagonal block** (survives projection in all three residues):
- A residue: `UTGG`
- B residue: `C4mE`
- E residue: `Kjg9`
- Concatenated: `UTGGC4mEKjg9` → decoded bytes: `51 31 86 0b 89 84 2a 38 3d`

---

## 7. The Byte-Layer Machine (Locked)

**E selector:** E contains exactly one byte satisfying `value < len(B)` (i.e., `< 18`) among the tested selector domain/interpretation:
- `E[10] = 0x09` — confirmed by exhaustive enumeration of all 16 E bytes under the tested interpretation
- `B[9] = 0x16` begins G3, so `E[10] = 0x09` selects `B[9:12]` = G3

**Kernel computation:**

```
mask = (G3[0] XOR G3[2]) AND 0x07
     = (0x16 XOR 0xb1) AND 0x07
     = 0xa7 AND 0x07
     = 0x07

out  = G3[1] XOR mask
     = 0x6c XOR 0x07
     = 0x6b
```

`0x6b` does not appear in any raw field byte. It is computed.

**Closing relations:**

```
0x6b XOR G4[2]   = 0x6b XOR 0x14 = 0x7f  = E[3]     ✓
E[10] XOR G4[2]  = 0x09 XOR 0x14 = 0x1d  = Hdr[2]   ✓
G3[2] OR G4[2]   = 0xb1 OR 0x14  = 0xb5  = Hdr[0]   ✓
Hdr AND G4 = G4  (G4 is bitwise contained within Hdr) ✓
```

**Upgrade mask:** `Hdr XOR G4 = a5 12 09`

**Terminal reduction:** `(a5 12 09) AND G3 = 04 00 01` — trunk sink

**Bounded closure:** 24 distinct residues under G3 neighborhood, all within G3 bit-support. Fixed-point termination confirmed.

**Conserved corridor core:** `G2 AND G3 AND G4 = G2 AND G4 = Hdr AND G2 = 00 40 10`

---

## 8. The G3 Bridge — Cross-Layer Convergence (Locked)

This is the strongest result in the investigation. G3 = `16 6c b1` is simultaneously addressed from three independent directions.

### 8.1 The Fmyx Quartet

B as Base64 string: `tVMd3L1CKM4w` **`Fmyx`** `EEEUV2bY`

Quartet `Fmyx` at B string positions 12–15:

```
F = index  5 = 000101
m = index 38 = 100110   ← PROTECTED (residue)
y = index 50 = 110010
x = index 49 = 110001

All 24 bits: 000101 100110 110010 110001

Byte 0: 00010110 = 0x16 = G3[0]   (F contributes 6 bits, m contributes 2)
Byte 1: 01101100 = 0x6c = G3[1]   (m contributes 4 bits, y contributes 4)
Byte 2: 10110001 = 0xb1 = G3[2]   (y contributes 2 bits, x contributes 6)
```

**ASCII selector split on Fmyx:**
- `F` → Read (execution witness)
- `m` → Protected (residue)
- `y` → Read
- `x` → Read

Pattern: R P R R

`m` is the hinge character. It spans the byte 0 / byte 1 boundary. Without `m`, G3[0] has only 6 of 8 bits and G3[1] has only 4 of 8 bits. **G3 is unrecoverable from the read set alone and unrecoverable from the residue alone. Both layers are required.**

### 8.2 The 0x6b / k Connection

- Byte layer kernel output: `0x6b`
- ASCII character `0x6b` = `k`
- `k` appears in C string at column 6
- The projection machine reads `C[6] = k = 0x6b` at phase 6 (nibble `3`, the first privilege phase)
- This is exactly the `wkzz` transient — the unique one-time character in the entire ASCII execution trace

**The byte-layer kernel computes a value that appears as the ASCII transient at privilege onset. Verified mechanically. This is a strong convergence, not yet a fully formal unification.**

### 8.3 Same Quartet Position Across A, B, E

| Payload | Quartet [12:16] | Selector split | Decoded |
|---|---|---|---|
| A | `KGTr` | K**G**Tr → G protected | `28 64 eb` |
| B | `Fmyx` | F**m**yx → m protected | `16 6c b1` = G3 |
| E | `QglP` | Q**g**lP → g protected | `42 09 4f` |

E's quartet at the same position contains `0x09` — which is the byte-layer selector value that points to G3. **E and B are linked at the quartet level.**

---

## 9. Seven-Layer Architecture (Current Model)

```
Layer 0 — On-chain storage
  19 unordered OP_RETURN fragments + 1 terminal marker
  Same block, same second, same address

Layer 1 — Assembly grammar
  Delimiter classes (. : ; ,) classify and reconstruct rows
  C nibble sequence orders the trunk

Layer 2 — Rendered ASCII tree
  The image is a reconstruction, not the raw artifact
  Canopy indentation is visual (absolute), not row-local

Layer 3 — Geometry selector
  q and 1 coordinates define read positions
  27-node q backbone, 13 one-markers
  Canopy graph: dense / Trunk graph: sparse

Layer 4 — Base64 character selector
  Projection rule: payload_col = geometry_col - 1
  Splits each payload into read set + residue
  Anti-diagonal block preserved across A, B, E residues

Layer 5 — Decoded byte machine
  E[10] = 0x09 selects B[9:12] = G3
  Kernel: mask = 0x07, out = 0x6b
  Closing relations verified
  Bounded closure: 24 residues, trunk sink 04 00 01

Layer 6 — Proof kernel
  G3 = 16 6c b1
  Unrecoverable from either layer alone
  Associated with ASCII transient k = 0x6b
  Selected by E, located in Fmyx, split by ASCII machine

Layer 7 — Unknown
  No confirmed external target found
  ZENON NETWORK terminal marker — see Section 9A
```

---

### 9A. Terminal Consolidation Transaction (Locked, pending explorer data verification)

The 20th OP_RETURN is part of the artifact's closing structure, not merely a possible thematic marker.

| Field | Value |
|---|---|
| Terminal TXID | `911dcb7435932f64215f8de4058186aef9bfd4356978c95830e77a38b9484083` |
| OP_RETURN | `ZENON NETWORK` |
| Block | 709,632 |
| Timestamp | 2021-11-14 00:15:27 |
| Input address | `bc1qrnldpdlq9dsfy946m4vqa5mrec8qhdrx363end` |
| Change address | `bc1qrnldpdlq9dsfy946m4vqa5mrec8qhdrx363end` |
| Inputs | 19 |
| Sigops | 19 |
| Outputs | 1 OP_RETURN + 1 same-address change |
| Fee | 1,008,000 sats |
| Fee rate | 744 sat/vB shown by explorer; effective fee rate 255 sat/vB |
| Miner | F2Pool |
| OP_RETURN hex | `6a0d5a454e4f4e204e4554574f524b` |

**Interpretation:** The terminal transaction spends/consolidates the 19 artifact UTXOs and emits the final OP_RETURN marker `ZENON NETWORK`. This makes the artifact architecturally cleaner:

```
3 payload rows
+ 5 canopy rows
+ 1 E boundary row
+ 10 trunk rows
+ 1 terminal consolidation marker
= 20 objects
```

**Status:** Locked, assuming the explorer data pasted above is accurate and independently re-verified. The terminal marker is structurally linked by the 19-input consolidation pattern from the same artifact address — not merely thematically related.

**Architectural consequence:** The on-chain object is better modeled as:

```
19 structural fragments
→ terminal consolidation transaction
→ ZENON NETWORK assertion
```

---

### 9B. Canonical Render / Published Image Layer (Partial)

A published render of the assembled artifact exists as a green-on-black monospace terminal-style image. This matters because it suggests the visual presentation was intentional, not merely an analyst reconstruction.

**Observed visual properties:**
- Black background
- Green monospace text
- Terminal / hacker-console aesthetic
- Rendered as a fixed-width visual object
- Same assembled tree structure as the OP_RETURN reconstruction

**Interpretive consequence:** The rendered image should be treated as a candidate canonical layer, not just a convenience visualization. The artifact may have at least three forms:

```
1. On-chain storage form
   19 unordered OP_RETURN fragments + terminal consolidation transaction

2. Textual assembly form
   delimiter grammar + C-ordered tree reconstruction

3. Published visual render form
   green-on-black monospace image
```

**Why this matters:** If the designer intentionally published this exact render, then absolute spacing, indentation, font metrics, line height, color, and raster geometry may carry information not captured by the plain text transcription.

**Status:** Partial. The existence of the image is observed, but its original publication source, timestamp, author/context, and whether it is designer-authored versus community-rendered must be documented before treating it as fully canonical.

**Required tests:**
1. Identify original publication source and context.
2. Preserve the original image file, not a screenshot or compressed repost if possible.
3. Extract metadata: dimensions, file type, creation/modification fields, color profile, compression history.
4. Test for image steganography: metadata, appended bytes, LSB planes, palette anomalies, alpha channel, pixel-grid periodicity.
5. Reconstruct absolute text grid from the image and compare it against the plain-text assembled artifact.
6. Determine whether font choice, point size, line spacing, and indentation produce geometry relationships not visible in row-local coordinates.

**Caution:** Do not infer steganography merely from the aesthetic. Green-on-black terminal styling is meaningful context, but embedded image data must be mechanically verified.

---

## 10. What Has Been Falsified

Do not revisit. These are dead ends confirmed by exhaustive testing:

- HTLC / hash preimage
- Bitcoin Script / Taproot witness (as a spendable script)
- Wallet or private key derivation
- Address derivation (Bitcoin or Zenon)
- ZTS token derivation
- SHA256, SHA3, Keccak chains (single and double)
- Hash chaining / concatenation schemes
- Simple XOR
- Simple substitution cipher
- Simple Base64 decode as plaintext
- Hidden plaintext via standard steganography methods

**Rejected after later sessions (Addenda F–G), do not revive without new mechanical evidence:**

- `k` = literal private key
- `k` = literal Kaine key
- `k` = literal SporkAddress key
- Artifact = executable Taproot script
- Artifact = Bitcoin bridge source code
- Artifact = direct Zenon genesis byte identity proof
- Anti-diagonal = plaintext
- Anti-diagonal = executable Script
- `04 00 01` = literal text decode
- `ZENON NETWORK` = decoded from sink bytes
- `CommunitySporkAddress` relevance to the 2021 artifact
- `LegacyEntries 01/04/09` as role bytes (these are sorted hash-prefix noise)
- `SporkAddress` literal identity match
- Direct genesis byte identity proof

---

## 11. The Canopy Rendering Law (Strong Partial / Near-Locked)

This was the primary open problem through Addendum B. A reproducible renderer has since been identified for all five canopy rows.

For each canopy row:

```
G_i = corresponding B triplet
C_i = corresponding C byte
n   = low nibble of C_i
p   = popcount(n)
```

**Prefix rule** — controlled by the high bit of the middle byte of `G_i`:

```
if G_i[1] >= 0x80:
    prefix = ".:"
else:
    prefix = ",;"
```

Verification:

```
G1[1] = bd → .:
G2[1] = ce → .:
G3[1] = 6c → ,;
G4[1] = 41 → ,;
G5[1] = 66 → ,;
```

This reproduces: `.: .: ,; ,; ,;`

**Body rule** — controlled by the low nibble of the corresponding C byte:

```
if n == 0:
    body = "1" + "z"*9
else:
    left_symbol = "q" if n >= 4 else "1"
    left_len    = max(popcount(n) - 1, 1)
    z_len       = 7 - popcount(n)
    right       = "qqq" if n < 8 else "1qq"
    body        = left_symbol*left_len + "z"*z_len + right
```

Verification:

```
C1 = e0 → n=0 → 1zzzzzzzzz
C2 = 57 → n=7, popcount=3 → qqzzzzqqq
C3 = 73 → n=3, popcount=2 → 1zzzzzqqq
C4 = c3 → n=3, popcount=2 → 1zzzzzqqq
C5 = 59 → n=9, popcount=2 → qzzzzz1qq
```

**End punctuation rule:**

```
if n == 0:
    end = "."
else:
    end = ","
```

**Full canopy reproduction:**

```
G1 + e0 → .:1zzzzzzzzz.
G2 + 57 → .:qqzzzzqqq,
G3 + 73 → ,;1zzzzzqqq,
G4 + c3 → ,;1zzzzzqqq,
G5 + 59 → ,;qzzzzz1qq,
```

This reproduces all five canopy rows exactly.

**Status:** Strong Partial / Near-Locked. Remaining caveat: the rule is exact for the observed artifact, but a minimality proof has not yet been completed. A hostile reviewer must test whether a simpler non-equivalent rule can reproduce the same rows while preserving the independent G/C channel split.

**Updated interpretation:** The canopy is not decorative and not raw byte display. It is a compiler/render layer with separated channels:

```
G middle-byte high bit → prefix family
C low nibble           → body class
C low nibble zero test → terminal punctuation
```

The duplicate canopy rows (`,;1zzzzzqqq,` twice) are now explained mechanically: `73` and `c3` share low nibble `3`; the high nibble is discarded by the body renderer.

---

## 12. Bitcoin-Script-Language Symbolic Layer (Strong Partial)

The artifact should **not** be treated as a spendable Bitcoin Script or Taproot witness. That path remains falsified. However, the artifact appears to use Bitcoin Script/Tapscript language as symbolic machinery.

**Key correspondences:**

```
G2 = 28 ce 30
28 = PUSH40
```

G2 opens a 40-byte corridor exactly:

```
ce30
166cb1
104114
5766d8
e05773c359
bedbf77f968a6348c642094ff5ad401b
0729d0b69794c964
```

This decomposes as: `G2 tail | G3 | G4 | G5 | C | E | A-prefix`

So G2 behaves as a proof-corridor container, not merely a triplet.

**Additional reader correspondences:**

```
G3 starts with 16 = PUSH22
G4 starts with 10 = PUSH16
A  starts with 07 = PUSH7
E[10] = 09 = selector / PUSH9-like control byte
```

This gives a reader hierarchy: `PUSH40 → PUSH22 → PUSH16 → PUSH7`

The strongest Script-language bridge remains:

```
G3 contains 6c = OP_FROMALTSTACK
machine computes 6b = OP_TOALTSTACK
ASCII layer produces k = 0x6b
```

This is not a valid Script execution path, but it is a strong symbolic convergence.

### 12.1 G2 as Proof Corridor Container

G2 carries the internal proof corridor but excludes Hdr and G1.

| Inside G2 | Outside G2 |
|---|---|
| G3, G4, G5, C, E, A-prefix | Hdr, G1 |

**Current role assignment:**

| Object | Role |
|---|---|
| Hdr | External constraint / environment |
| G1 | Success/open gate |
| G2 | Proof corridor container |
| G3 | Selected kernel |
| G4 | Reducer / resolved state |
| G5 | Terminal carried state |
| C | Scheduler / canopy renderer control |
| E | Selector / boundary marker |
| A | Witness prefix |

This partition matters because everything required for the proof corridor is carried inside G2, while the environment/gate objects remain outside.

---

## 13. The Stateful Edge Machine (Strong Partial / Near-Locked)

The artifact is not best modeled as a stateless selector/projection system. The C-driven trunk behaves as a **stateful edge machine**: output depends on transition history, not only the current nibble.

### 13.1 C as Transition Grammar

```
e0 | 57 | 73 | c3 | 59
=
(e→0) (5→7) (7→3) (c→3) (5→9)
```

The canopy compresses the trunk schedule into five transition descriptors. The trunk expands those descriptors into ten execution phases.

### 13.2 Statefulness Proof (Locked, assuming the projection trace is correct)

```
5 after 0 → 1z
5 after 3 → wz       (same current nibble 5, different output)

3 after 7 → wkzz
3 after c → wzzz     (same current nibble 3, different output)
```

Therefore: `output ≠ f(current nibble)`; `output = f(previous nibble → current nibble)`.

### 13.3 Edge Map

| Edge | Meaning | C-layer output |
|---|---|---|
| 0→5 | Activation / first marker | `1z` |
| 5→7 | Preparation / marker cleared | `zz` |
| 7→3 | Witness exposure | `wkzz` |
| 3→c | Witness consumption | `wzzz` |
| c→3 | Proof-context commit | `wzzz` |
| 3→5 | Terminal compression | `wz` |
| 5→9 | Finalization | `wz` |

This edge model explains why identical nibbles can produce different outputs. Status: Strong Partial / near-Locked.

### 13.4 Witness Exposure and Consumption

The core proof event occurs at the `73 → c3` boundary.

At phase 3 after 7, row `,zzzzq:1zzzzzq;.    1zzzz,` — the `1` in `:1` projects to `C[6] = k`, exposing `wkzz`.

At the next phase, `c`, the local structure rewrites `:1 → ,q` and the output becomes `wzzz`.

```
:1 exposes k
,q consumes k
w survives
z normalizes
```

This mirrors the byte layer exactly: G3 computes `0x6b`; `0x6b` = ASCII `k`; `k` appears once; `k` is consumed.

### 13.5 Symbol Lifecycle

| Symbol | Role |
|---|---|
| `1` | Activation marker |
| `k` | Witness token |
| `w` | Accepted / established state marker |
| `z` | Substrate / default null state |

Lifecycle: `1` appears → disappears; `k` appears → disappears; `w` appears → persists; `z` persists as substrate. The machine does not prove `k` — it uses `k` to establish `w`.

### 13.6 Terminal Compression and Three-Lane Residue

ASCII terminal compression: `wzzz → wz → wz`

Byte-layer terminal reduction: `Hdr XOR G4 = a5 12 09`; `(a5 12 09) AND G3 = 04 00 01`

Both layers show the same structural pattern: witness removed, redundancy compressed, minimal terminal residue preserved (role equivalence, not a literal byte transform).

**Lane-wise production of the terminal sink:**

```
a5 & 16 = 04
12 & 6c = 00
09 & b1 = 01
```

Interpretation: left lane survives, middle witness lane annihilates, right lane survives. The middle lane is the witness lane because `G3[1] = 6c` computes `6b = k`, and `k` is consumed; terminal middle lane = `00`. Thus `04 00 01` records witness consumption. Status: Strong Partial.

### 13.7 Anti-Diagonal Residue, Lane Split

```
UTGGC4mEKjg9 → 51 31 86 0b 89 84 2a 38 3d

L = 51 31 86
M = 0b 89 84
R = 2a 38 3d

L XOR R = 7b 09 bb   (exposes 09 — same selector value as E[10])
L AND R = 00 30 04
M AND (L AND R) = 00 00 04
```

This suggests the anti-diagonal repeats the same lane architecture: outer lanes interact, middle/protected lane mostly annihilates, small residue survives. It does not decode to plaintext and should not be treated as a Script program. Status: Partial. Best current role: protected cross-layer proof residue / support object.

---

## 14. C as Self-Describing Address-Control Memory (Strong Partial)

The C field is no longer merely a scheduler. It is best modeled as a self-describing control/memory field whose Base64 spelling, decoded bytes, canopy visibility, and trunk execution all participate in the machine.

### 14.1 Static Memory, Not Mutating Data

```
Base64:  4Fdzw1k=
Decoded: e0 57 73 c3 59
index:   0 1 2 3 4 5 6 7
char:    4 F d z w 1 k =
```

The trunk does not modify C. The geometry layer changes which C addresses are visible:

```
static memory field C
→ geometry read-heads
→ controlled address exposure
→ witness visibility
→ witness removal by dereferencing
```

### 14.2 Proof Corridor in C

```
C[4] = w  → accepted / persistent state marker
C[5] = 1  → activation marker
C[6] = k  → witness marker
C[7] = =  → assertion / closure marker
```

The trunk reads `C[5]=1` exactly once, `C[6]=k` exactly once, and `C[4]=w` from witness exposure onward through terminal. The trunk never reads `C[7]==`. This gives the compact local proof expression `w1k=` — not as plaintext, but as a visible control/memory corridor. Status: Strong Partial / near-Locked for address behavior; semantic role of `=` remains Partial.

### 14.3 Address Lifecycle (Locked, assuming the projection trace is accepted)

```
phase 3 / nibble 5  → C[5], C[18]              = 1z
phase 4 / nibble 7  → C[9], C[18]              = zz
phase 5 / nibble 7  → C[11], C[18]             = zz
phase 6 / nibble 3  → C[4], C[6], C[12], C[18] = wkzz
phase 7 / nibble c  → C[4], C[8], C[15], C[18] = wzzz
phase 8 / nibble 3  → C[4], C[11], C[17], C[19]= wzzz
phase 9 / nibble 5  → C[4], C[14]              = wz
phase 10 / nibble 9 → C[4], C[17]              = wz
```

Key lifecycle: `C[5]=1` appears once, then becomes unreachable. `C[6]=k` appears once, then becomes unreachable. `C[4]=w` appears with `k` and remains reachable through terminal. Therefore `k` is not deleted — `k` is dereferenced once, then made unreachable, while `w` is established at the same witness-exposure edge and remains reachable. This is the strongest current mechanism for witness consumption.

### 14.4 Core Proof Transition

At `7→3`, read-heads expose `C[4]=w` and `C[6]=k` → output `wkzz`.
At `3→c`, read-heads remove the address `C[6]=k` while preserving `C[4]=w` → output `wzzz`.

Mechanism: `7→3` exposes witness `k` and establishes accepted marker `w`; `3→c` removes witness address `k` and preserves accepted marker `w`. This is stronger than saying punctuation "consumes" k — the actual mechanism is read-head rewiring / address removal. Status: Strong Partial / near-Locked.

### 14.5 Canopy / Trunk Privilege Separation

| Domain | C positions read | Contents |
|---|---|---|
| Canopy (declaration/assertion) | C[1], C[2], C[7] | `F`, `d`, `=` |
| Trunk (execution/witness) | C[4], C[5], C[6] | `w`, `1`, `k` |

The trunk never reads `C[7]==`. Clean privilege split: canopy declares, trunk executes. Status: Strong Partial.

### 14.6 C Base64 Self-Split

```
4Fdz | w1k=
e0 57 73 | c3 59
```

| Side | Bytes | Lifecycle stage |
|---|---|---|
| `4Fdz` | `e0 57 73` | idle / activation / witness exposure |
| `w1k=` | `c3 59` | witness consumption / terminalization |

The visible corridor `w1k=` decodes directly to the post-proof scheduler bytes `c3 59` — a major self-description result. Status: Strong Partial / near-Locked.

### 14.7 B Base64 Instruction Surface

```
tVMd | 3L1C | KM4w | Fmyx | EEEU | V2bY
b5531d | dcbd42 | 28ce30 | 166cb1 | 104114 | 5766d8
Hdr   | G1     | G2     | G3     | G4     | G5
```

The critical quartet `Fmyx → 16 6c b1 = G3` is the visible Base64 surface carrying the proof kernel. This supports the emerging rule: visible Base64 spelling → decoded bytes → machine stage. The Base64 text is not cosmetic; it is part of the instruction surface. Status: Strong Partial.

### 14.8 Refined Role of `=`

`C[7] = =` is canopy-readable but trunk-inaccessible — not part of active witness execution. Better modeled as a declaration/closure/assertion marker: it marks the assertion boundary of the proof corridor `w1k=`, visible to the canopy declaration layer but withheld from the trunk execution layer. Status: Partial.

---

## 15. Residue Architecture and the Three-Layer Model (Partial)

The artifact is no longer best modeled as a byte machine plus an ASCII machine. Evidence supports a three-layer architecture — execution → terminal residue → assertion — appearing independently at both local and global scales.

### 15.1 Closed Role System

| ASCII symbol | Proposed role | Byte object | Proposed role |
|---|---|---|---|
| `z` | substrate | `01` | substrate residue |
| `1` | activation marker | `09` | activation selector |
| `k` | witness token | `6b` | witness token |
| (absent k) | — | `00` | consumed witness lane |
| `w` | accepted/persistent state | `04` | surviving accepted state |

The strongest bridge remains `6c → 6b = ASCII k`, already mechanically established. Status: Partial — the role correspondence is structurally strong but not formally proven.

### 15.2 Witness-Consumption Invariant (Strong Partial)

A recurring topology — survivor → witness removed → survivor — appears across multiple layers:

| Layer | Sequence | Role form |
|---|---|---|
| ASCII | `wkzz → wzzz → wz` | w / Ø / z |
| Byte | `16 6c b1 → 04 00 01` | survive / consume witness / survive |
| Address | `C[4]=w, C[6]=k` → `C[4]=w, C[6] unreachable` | survivor / witness removed |

This is currently the strongest invariant spanning the execution systems.

### 15.3 Three-Layer Architecture

```
Layer A — Execution      ASCII: 1, k, w        Byte: 09, 6b, 04
Layer B — Terminal residue   ASCII: wz             Byte: 04 00 01
Layer C — Assertion       ASCII: =               Global: ZENON NETWORK
```

This suggests `execution → residue → assertion`, rather than `execution → message`.

### 15.4 Assertion-Layer Hypothesis

Two objects remain outside all known execution systems:

| Object | Properties |
|---|---|
| `=` (local) | canopy-visible, trunk-inaccessible, persistent, non-executing |
| `ZENON NETWORK` (global) | outside projection machine, byte machine, and scheduler; terminal object |

Both occupy the same architectural position: execution → terminal state → assertion. Current interpretation: `=` and `ZENON NETWORK` may belong to an assertion/attestation layer rather than an execution layer. Status: Partial.

### 15.5 Base64 Midpoint Boundary and the w1k= Corridor

`4Fdzw1k=` splits as `4Fdz | w1k=` → `e0 57 73 | c3 59`, aligning with the strongest lifecycle boundary discovered so far (pre-witness side / post-witness side). The split survives comparison against alternative Base64 partition points. Status: Strong Partial.

The corridor `w1k=` is currently the densest object in the artifact, simultaneously participating in the execution layer (`w`, `1`, `k`), the assertion layer (`=`), the Base64 layer (valid closure), and the scheduler layer (decodes to `c3 59`, the post-witness half). Current interpretation: `w1k=` may function as an interface object connecting execution, residue, and assertion layers. Status: Strong Partial.

### 15.6 Canopy Reclassification

The canopy does not appear to encode witness execution directly. It exhibits a stable outer-channel structure (left channel / center substrate / right channel) where outer channels carry most variation and the center channel remains predominantly z-substrate — resembling the terminal sink topology more than the witness-execution topology. Current interpretation: canopy = declaration/render layer, trunk = execution layer. Status: Partial.

---

## 16. Reproducible Solve Path (Current Best Summary)

The puzzle is reproducible as a layered state-transition proof machine. The strongest remaining interpretation is no longer "hidden plaintext," but a formal proof/certification structure whose likely external referent is Zenon bootstrap authority, network survival, and post-bootstrap assertion.

```
OP_RETURN fragments
→ delimiter assembly
→ C-ordered tree
→ projection machine
→ C address lifecycle
→ witness exposure
→ witness consumption
→ byte-layer terminal sink
→ anti-diagonal certificate
→ assertion layer
```

### 16.1 Minimal Reproduction Steps

**Step 1 — Assemble the artifact.** Use delimiter grammar to classify rows (`;...;` payload, `.:...` canopy type A, `,;...` canopy type B, `,...,` trunk, `,... .` E boundary), then use C nibbles `e,0,5,7,7,3,c,3,5,9` to order the trunk rows. *Status: Locked.*

**Step 2 — Decode fields.** Decode A, B, C, E as given in Section 2; segment B into Hdr/G1–G5. *Status: Locked.*

**Step 3 — Apply projection rule** `payload_col = geometry_col - 1`. The C trace must reproduce `1z, zz, zz, wkzz, wzzz, wzzz, wz, wz`. *Status: Locked if the coordinate/projection table is accepted.*

**Step 4 — Verify byte witness.** `E[10]=09` selects `B[9:12]=G3=16 6c b1`; `mask=(16 XOR b1) AND 07=07`; `out=6c XOR 07=6b=ASCII k`; verify `C[6]=k` appears exactly once during the projection trace. *Status: Locked.*

**Step 5 — Verify terminal sink.** `Hdr XOR G4 = a5 12 09`; `(a5 12 09) AND G3 = 04 00 01`. Lane interpretation: `04`=survivor/accepted state, `00`=consumed witness lane, `01`=substrate survivor. *Status: Strong Partial.*

**Step 6 — Verify ASCII/byte terminal equivalence.** ASCII terminal `wkzz → wzzz → wz` (role form `w k z → w Ø z → wz`); byte terminal `16 6c b1 → 04 00 01` (role form survivor/witness/substrate → survivor/consumed-witness/substrate). Proposed equivalence `04 00 01 → wØz → wz` is role-preserving, not literal byte-to-character equality. *Status: Strong Partial / near-Locked.*

**Step 7 — Verify anti-diagonal certificate behavior.** `UTGGC4mEKjg9 → 51 31 86 0b 89 84 2a 38 3d`; split into `L/M/R`; `L XOR R=7b 09 bb`, `L AND R=00 30 04`, `M AND (L AND R)=00 00 04`. The certificate preserves `09` (selector) and `04` (survivor), and omits `6b` (witness). Current best interpretation: post-consumption certificate / invariant carrier. *Status: Strong Partial for role; exact derivation remains Open.*

**Step 8 — Verify assertion layer.** Local: `wkz → wØz → wz → =`. Global: `09 → 6b → 04 00 01 → certificate → ZENON NETWORK`. *Status: Partial / Strong Partial.*

### 16.2 Current Formal Role Table

| Role | ASCII object | Byte object | Status |
|---|---|---|---|
| Substrate | `z` | `01` | Strong Partial |
| Activation | `1` | `09` | Strong Partial |
| Witness | `k` | `6b` | Locked / near-Locked |
| Consumed witness | absent k / Ø | `00` | Strong Partial |
| Survivor / accepted state | `w` | `04` | Strong Partial |
| Terminal residue | `wz` | `04 00 01` | Strong Partial |
| Certificate | protected residue | anti-diagonal | Partial |
| Assertion | `=` | `ZENON NETWORK` | Partial |

### 16.3 Canopy / Trunk Relation

The canopy is best modeled as the compressed declaration of the execution machine — C bytes `e0 57 73 c3 59` map to idle/setup, activation, witness exposure, witness consumption, terminalization. The trunk expands these same bytes into the full execution trace `e,0,5,7,7,3,c,3,5,9`. Current interpretation: canopy = compressed proof declaration, trunk = expanded proof execution. Status: Strong Partial.

---

## 17. Current Best External Interpretation

The strongest external theory is:

```
bootstrap authority / witness
→ activation
→ witness disappearance or removal
→ surviving network state
→ ZENON NETWORK assertion
```

This is supported externally by the Zenon codebase containing a privileged SporkAddress, a later temporary CommunitySporkAddress, and comments indicating future governance replacement — but this is codebase context, not a direct mechanical match (see Section 17.2).

**Current best semantic interpretation:**

| Symbolic object | Proposed meaning |
|---|---|
| `k` / `6b` | Bootstrap authority witness or founder/core-dev authority role |
| `w` / `04` | Surviving accepted network state |
| `z` / `01` | Substrate / persistent network background |
| `00` | Consumed or absent witness authority |
| `ZENON NETWORK` | Assertion of the surviving system |

This does not prove that `k` is a literal private key.

**More disciplined status:**

| Claim | Status |
|---|---|
| `k` = literal private key | Open / unsupported |
| `k` = Kaine specifically | Speculative |
| `k` = founder/core-dev bootstrap authority | Partial |
| `k` = abstract bootstrap/spork authority role | Strong Partial |

### 17.1 What Has Been Rejected (External Attribution)

A genesis identity audit found **no direct genesis identity proof**. Specifically, no direct mechanical match was found for `16 6c b1`, `04 00 01`, `51 31 86 0b 89 84 2a 38 3d`, or `a5 12 09` inside the tested 2021 Zenon genesis objects, legacy entries, pillar records, spork configuration, or genesis serialization.

| Claim | Status |
|---|---|
| `CommunitySporkAddress` relevance to 2021 artifact | Rejected |
| `LegacyEntries 01/04/09` as role bytes | Rejected — sorted hash-prefix noise |
| `SporkAddress` literal identity match | Rejected |
| Direct genesis byte identity proof | Rejected |

What remains plausible is not a literal byte identity, but a role-level correspondence: a privileged witness/authority appears, performs activation, is removed from the terminal state, and the surviving network state is asserted.

**Current status:** External referent = Open. Bootstrap-authority interpretation = Strong Partial, role-level only. Direct identity proof = Rejected.

---

## 18. Confidence Register (Consolidated, Current)

**Locked — mechanically verified, survives hostile review:**
- C = `e0 57 73 c3 59`; 5 C bytes ↔ 5 canopy rows; 10 C nibbles ↔ 10 trunk rows
- q count = 27; E terminal byte = `0x1b` = 27
- `payload_col = geometry_col - 1` projection rule
- Full A/B/C/E execution trace table
- Machine selects (reads/preserves), does not transform
- Anti-diagonal residue preserved across A, B, E
- `E[10] = 0x09` uniquely satisfies `value < len(B)` under the tested selector interpretation
- `B[9:12] = G3 = 16 6c b1`; kernel output `0x6b` = ASCII `k`
- `k` appears in ASCII trace at privilege onset (phase 6, col 6)
- `Fmyx` decodes to G3; `m` is hinge character spanning byte boundary
- ASCII selector splits `Fmyx` as R/P/R/R; G3 requires both layers
- Bounded closure algebra: 24 residues, trunk sink `04 00 01`
- OP_RETURN set is primary storage; rendered tree is assembled
- Delimiter grammar classifies all rows; C is simultaneously control word, execution schedule, and assembly key
- Statefulness: `output = f(previous nibble → current nibble)`, not current nibble alone
- C address lifecycle: `C[5]`, `C[6]` become unreachable after one read; `C[4]` remains reachable through terminal

**Strong Partial / Near-Locked:**
- Canopy rendering law (prefix/body/punctuation rules reproduce all 5 rows exactly; minimality proof pending)
- Terminal consolidation transaction linkage (pending independent re-verification of explorer data)
- Terminal state equivalence: `04 00 01` ↔ role form `wØz` ↔ `wz` (role-preserving, not literal)
- Anti-diagonal generation mechanics; G2 as 40-byte proof corridor container
- C Base64 self-split `4Fdz | w1k=`; B Base64 instruction surface (Hdr/G1–G5 quartets)
- Witness-consumption invariant (survivor → witness removed → survivor) across ASCII, byte, and address layers

**Partial — strong evidence, sub-problems open:**
- G3 is the intended proof kernel; `0x6b`/`k` is the intended ASCII–byte bridge
- Delimiter layer carries semantic content beyond assembly grammar
- E is both boundary marker and selector object
- 20th OP_RETURN is part of the same artifact family
- Canopy = state space / declaration layer; Trunk = execution space
- Three-layer architecture (execution → residue → assertion)
- Assertion-layer hypothesis (`=` and `ZENON NETWORK` as equivalent assertion objects)
- Bootstrap-authority external interpretation (role-level only)

**Open — not established:**
- Canopy renderer minimality proof
- System A / System B (ASCII-layer / byte-layer) full formal unification
- External plaintext, key, or protocol endpoint
- Exact semantic meaning of protected anti-diagonal `51 31 86 0b 89 84 2a 38 3d`
- Whether `wz` (ASCII terminal) and `04 00 01` (byte terminal) are formally — not just role-equivalently — the same state
- The precise real-world claim, doctrine, authority lifecycle, or protocol transition the machine attests to

---

## 19. What Has Been Falsified or Rejected — Full List

Do not propose new cryptographic transforms. Do not revisit falsified theories. Work mechanically from the locked facts.

**Falsified (early sessions):**
HTLC / hash preimage · Bitcoin Script or Taproot witness as a spendable script · wallet or private key derivation · address derivation (Bitcoin or Zenon) · ZTS token derivation · SHA256 / SHA3 / Keccak chains (single and double) · hash chaining or concatenation schemes · simple XOR · simple substitution cipher · simple Base64 decode as plaintext · hidden plaintext via standard steganography methods

**Rejected (later sessions):**
`k` as a literal private key, literal Kaine key, or literal SporkAddress key · artifact as executable Taproot script or Bitcoin bridge source code · artifact as a direct Zenon genesis byte identity proof · anti-diagonal as plaintext or executable Script · `04 00 01` as literal text · `ZENON NETWORK` as a literal decode of `04 00 01` · `CommunitySporkAddress` relevance to the 2021 artifact · `LegacyEntries 01/04/09` as intentional role bytes · `SporkAddress` literal identity match · direct genesis byte identity proof

---

## 20. Transaction Reference

All 19 structural transactions, confirmed on-chain:

| TXID | OP_RETURN content |
|---|---|
| `31fd67de...` | `;BynQtpeUyWTXKGTrGhdV2Q==;` |
| `1dbe3537...` | `;tVMd3L1CKM4wFmyxEEEUV2bY;` |
| `71d9187c...` | `;4Fdzw1k=zzzzzzzzzzzzzzzz;` |
| `19b3689e...` | `.:1zzzzzzzzz.` |
| `1025eece...` | `.:qqzzzzqqq,` |
| `30912564...` | `,;1zzzzzqqq,` |
| `22a4216d...` | `,;1zzzzzqqq,` |
| `488c0d57...` | `,;qzzzzz1qq,` |
| `57b5f224...` | `,vtv3f5aKY0jGQglP9a1AGw==.` |
| `f985bca5...` | `,zzzzzzzzzzzzzzzzzzzzzzzz,` |
| `86a2ce16...` | `,zzzzzzzzzzzzzzzzzzzzzzzz,` |
| `d4d7ec6f...` | `,zzzzzq;.           1zzzz,` |
| `b8aa79a2...` | `,zzzzzzzzq,         1zzzz,` |
| `3fb6ecc1...` | `,zzzzzzzzzz1:       1zzzz,` |
| `2830adbb...` | `,zzzzq:1zzzzzq;.    1zzzz,` |
| `100b3fb5...` | `,zzzzq  ,qzzzzzz1,  1zzzz,` |
| `34e16ce8...` | `,zzzzq    .;qzzzzzq:1zzzz,` |
| `b63c7002...` | `,zzzzq       ,qzzzzzzzzzz,` |
| `67ff2854...` | `,zzzzq         .;qzzzzzzz,` |
| `911dcb74...` | `ZENON NETWORK` (terminal consolidation marker — see Section 9A) |

**Source address:** `bc1qrnldpdlq9dsfy946m4vqa5mrec8qhdrx363end`
**Block:** 709,632
**Fee (structural transactions):** 36.3–36.4 sat/vB, 5,760 sats per transaction
**Fee (terminal consolidation transaction):** 1,008,000 sats total (744 sat/vB displayed, 255 sat/vB effective)

---

## 21. Revised Open Problems (Current Priority Order)

1. **Canopy renderer minimality.** The renderer reproduces all five rows; a hostile-review minimality proof is still needed.
2. **Anti-diagonal purpose.** `51 31 86 0b 89 84 2a 38 3d` remains structurally preserved but semantically unresolved.
3. **Terminal equivalence.** Determine whether `wz` and `04 00 01` are two encodings of the same terminal state, or merely role-analogous endpoints.
4. **Delimiter semantics.** Trunk punctuation participates partly in canopy rendering but remains not fully formalized as an instruction or addressing channel.
5. **Formal finite-state machine.** Build every state as a set of reachable C addresses; track added, removed, and persistent addresses for every edge; test whether every known artifact component maps to exactly one state or transition.
6. **Formal role of `=`.** Canopy-visible, trunk-inaccessible — prove whether it marks equality, closure, assertion, or is Base64 padding only.
7. **Final external endpoint.** What real-world authority, state, or genesis transition (if any) is being certified? Current best answer points toward bootstrap completion or authority disappearance, at the role level only — not a literal identity match.

---

## 22. Conclusion — Internal Solve Boundary and Remaining External Attribution

The internal mechanics of the artifact are now substantially reconstructed. The remaining unsolved question is not *how the machine runs*, but *what real-world claim the completed machine is intended to attest*.

**Reproducible internal pipeline:**

```
OP_RETURN fragments
→ delimiter assembly
→ C-ordered tree
→ canopy declaration
→ trunk execution
→ projection read/residue split
→ G3 witness kernel
→ 0x6b / k witness exposure
→ witness consumption
→ terminal residue
→ center-quartet certificate
→ assertion
```

This is not a conventional ciphertext. The artifact does not currently justify treatment as a private key, wallet seed, address derivation, hash preimage, HTLC, Taproot spend path, plaintext cipher, or bridge source code. Those paths remain rejected unless new evidence appears.

**Final internal solve statement:** the Zenon Taproot artifact is best described as a recursive proof/certification machine embedded in Bitcoin block 709,632. It assembles unordered OP_RETURN fragments, declares a compressed state machine in the canopy, executes the expanded state machine in the trunk, uses projection geometry as read-heads, selects G3 through `E[10] = 09`, computes witness `0x6b`, exposes that witness as ASCII `k`, removes the witness from reachability, preserves survivor state `w`/`04` and substrate `z`/`01`, records the uncompressed terminal residue `04 00 01`, compresses the ASCII terminal state to `wz`, extracts the center-quartet residue certificate, and closes with `=` / `ZENON NETWORK` assertion markers.

**Current status:**

| Dimension | Status |
|---|---|
| Internal mechanics | Near-Locked |
| Terminal equivalence | Strong Partial |
| Anti-diagonal certificate role | Strong Partial |
| Exact anti-diagonal derivation | Open |
| External semantic endpoint | Open / Strong Partial toward bootstrap-authority interpretation |
| Direct genesis identity proof | Rejected |
| Hidden plaintext | Not justified by current evidence |

---

## 23. What To Work On Next

In priority order:

1. **Hostile-review minimality proof for the canopy renderer.** Test whether a simpler, non-equivalent rule reproduces the same five rows while preserving the independent G/C channel split.
2. **Formal finite-state machine construction.** Encode every artifact component as a state or transition in a single formal system, unifying the ASCII-layer and byte-layer machines.
3. **Anti-diagonal derivation.** Find the exact mechanical rule that produces `51 31 86 0b 89 84 2a 38 3d` from upstream layers, beyond the currently observed lane-preservation behavior.
4. **Terminal equivalence proof.** Attempt a direct, non-role-based mechanical transform between `04 00 01` and `wz`; if none exists, formally document why role equivalence is the correct final framing.
5. **Independent re-verification of the terminal consolidation transaction** (`911dcb74...`) against current block explorer data, to confirm address, input count, fee, and change-address details exactly as recorded in Section 9A.
6. **Canonical image layer forensics**, per the required tests in Section 9B, if and when the original published render can be sourced.

Do not propose new cryptographic transforms. Do not revisit falsified or rejected theories listed in Sections 10 and 19. Work mechanically from the locked and strong-partial facts above.
