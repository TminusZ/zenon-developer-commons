# Zenon Taproot Puzzle — Machine Specification

**Status:** Partial reconstruction. Deterministic components confirmed. Unification open.  
**Source artifact:** Bitcoin block 709,632, OP_RETURN transaction sequence  
**Version:** 1.0

---

## What this document is

This is a specification of a byte-level verification machine extracted from the artifact embedded in Bitcoin block 709,632. It is written so that any analyst — human or automated — can independently reproduce every result from the raw on-chain data.

**What this document claims:**
- Several deterministic arithmetic and selector relationships exist in the artifact
- These relationships are internally consistent and non-trivial
- They can be reproduced by anyone with the canonical byte arrays

**What this document does not claim:**
- That the puzzle encodes a hidden sentence or private key
- That all components of the machine are unified into one system
- That the kernel formula is uniquely forced by the data
- Intent or authorship of any kind

Every result is labeled with its epistemic status. Reproducible means the arithmetic checks out. Derived means it follows from a justified prior step. Assumed means a structural choice was made that another analyst might make differently. Open means the question is unresolved.

---

## 1. Canonical inputs

These four byte arrays are the ground truth. They decode from the Base64 fields in the OP_RETURN transaction sequence of block 709,632, in transaction order.

```
A (16 bytes):  07 29 d0 b6 97 94 c9 64 d7 28 64 eb 1a 17 55 d9
B (18 bytes):  b5 53 1d dc bd 42 28 ce 30 16 6c b1 10 41 14 57 66 d8
C  (5 bytes):  e0 57 73 c3 59
E (16 bytes):  be db f7 7f 96 8a 63 48 c6 42 09 4f f5 ad 40 1b
```

To verify independently: decode the following Base64 strings.

```
A  ← BynQtpeUyWTXKGTrGhdV2Q==
B  ← tVMd3L1CKM4wFmyxEEEUV2bY
C  ← 4Fdzw1k=
E  ← vtv3f5aKY0jGQglP9a1AGw==
```

Standard Base64 decoding produces these byte arrays exactly.

---

## 2. B partition

**Assumption (explicit):** B is segmented into a 3-byte header and five 3-byte groups. This 3-byte stride is a structural choice. A different stride produces a different machine. This choice is supported by the alignment results in sections 4 and 5, but it is not uniquely forced by the data alone.

```
Hdr = B[0:3]  = b5 53 1d
G1  = B[3:6]  = dc bd 42
G2  = B[6:9]  = 28 ce 30
G3  = B[9:12] = 16 6c b1
G4  = B[12:15]= 10 41 14
G5  = B[15:18]= 57 66 d8
```

---

## 3. G3 selection

**Status: Derived (conditional on selector rule)**

The selector rule applied to E is:

> Find all E bytes whose value is a valid index into B (i.e., value < 18).

Applied exhaustively:

| i | E[i] | E[i] < 18? |
|---|------|------------|
| 0 | 0xbe | No |
| 1 | 0xdb | No |
| 2 | 0xf7 | No |
| 3 | 0x7f | No |
| 4 | 0x96 | No |
| 5 | 0x8a | No |
| 6 | 0x63 | No |
| 7 | 0x48 | No |
| 8 | 0xc6 | No |
| 9 | 0x42 | No |
| 10 | 0x09 | **Yes** |
| 11 | 0x4f | No |
| 12 | 0xf5 | No |
| 13 | 0xad | No |
| 14 | 0x40 | No |
| 15 | 0x1b | No |

**Result:** E[10] = 0x09 is the unique E byte satisfying the rule.

B[9] begins G3. Therefore the selector rule uniquely extracts G3.

**Caveat:** The selector rule (value < len(B)) is one of several plausible rules. Its uniqueness has not been proven against all alternatives. A different rule could select a different group.

---

## 4. Arithmetic core (System A)

### 4.1 Kernel

**Status: Reproducible. Formula not independently derived.**

The kernel operates on G3. The formula is:

```
mask = (G3[0] XOR G3[2]) AND 0x07
out  = G3[1] XOR mask
```

Concrete evaluation:

```
G3        = [16, 6c, b1]

mask      = (0x16 XOR 0xb1) AND 0x07
          = 0xa7 AND 0x07
          = 0x07

out       = 0x6c XOR 0x07
          = 0x6b
```

**Kernel output: 0x6b**

Note: 0x6b does not appear in any of the raw field bytes A, B, C, or E. It is computed.

**What is not proven:** Why this formula rather than another. The formula uses XOR of the outer bytes, masked to 3 bits, applied to the middle byte. This is reproducible given the formula, but the formula's origin is not derived from first principles.

### 4.2 Bridge relation

**Status: Reproducible.**

```
0x6b XOR G4[2] = 0x6b XOR 0x14 = 0x7f
```

E[3] = 0x7f.

Therefore:

```
kernel_out XOR G4[2] = E[3]
```

### 4.3 Selector bridge

**Status: Reproducible.**

```
E[10] XOR G4[2] = 0x09 XOR 0x14 = 0x1d
```

Hdr[2] = 0x1d.

Therefore:

```
E[10] XOR G4[2] = Hdr[2]
```

### 4.4 Header relation

**Status: Reproducible.**

```
G3[2] OR G4[2] = 0xb1 OR 0x14 = 0xb5
```

Hdr[0] = 0xb5.

Therefore:

```
G3[2] OR G4[2] = Hdr[0]
```

Note: this relation mixes OR with the XOR operations above. The three relations share G4[2] = 0x14 as a common operand, but they use different operators (XOR, XOR, OR). They are not unified by a single operation type.

### 4.5 Frame containment

**Status: Reproducible (one fact, not two).**

G4 is bitwise contained within Hdr:

```
Hdr AND G4 = G4
```

Verified byte by byte:

```
b5 AND 10 = 10  ✓
53 AND 41 = 41  ✓
1d AND 14 = 14  ✓
```

This is equivalent to `Hdr OR G4 = Hdr`. These two statements are the same fact — G4 is a submask of Hdr.

### 4.6 System A summary

```
Input:   G3 = [16, 6c, b1]

mask     = (16 XOR b1) AND 07 = 07
out      = 6c XOR 07 = 6b           ← not in any raw field

Bridge:  6b XOR 14 = 7f = E[3]
Sel:     09 XOR 14 = 1d = Hdr[2]
Header:  b1 OR  14 = b5 = Hdr[0]

G4 is bitwise contained within Hdr.
G4[2] = 0x14 is the shared operand across all three closing relations.
```

---

## 5. Selector core (System B)

### 5.1 Sequence construction

**Status: Reproducible. Formula derivation partially circular (see caveat).**

For each i in 0..15:

```
seq[i] = group[ E[i] mod 5 ][ E[i] mod 3 ]
```

where group[0]=G1, group[1]=G2, group[2]=G3, group[3]=G4, group[4]=G5.

**Caveat:** mod 5 is natural because there are 5 groups. mod 3 selects a byte within a group, which only makes sense because groups are 3 bytes wide — a stride that was assumed in section 2. The index formula is partially circular with the partition assumption.

Resulting sequence:

```
i:    0   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15
seq: bd  57  6c  6c  dc  10  57  16  10  28  57  66  42  14  66  16
```

### 5.2 Printable subset of B

The bytes of B that fall in the printable ASCII range (0x20–0x7e):

```
Σ_B = {28, 30, 41, 42, 53, 57, 66, 6c}
```

These correspond to ASCII characters: `( 0 A B S W f l`

### 5.3 Adjacency constraint

Find all index pairs (i, j) satisfying both:

```
|A[i] - A[j]| <= 1
seq[i] ∈ Σ_B  AND  seq[j] ∈ Σ_B
```

**Caveat:** The threshold of 1 is set, not derived. At threshold 0 (exact equality), no pair survives. At threshold 2, additional pairs may exist. The uniqueness result below is specific to threshold = 1.

Exhaustive check:

Only one pair survives:

```
i = 9:  A[9]  = 0x28,  seq[9]  = 0x28  ∈ Σ_B
j = 1:  A[1]  = 0x29,  seq[1]  = 0x57  ∈ Σ_B

|0x28 - 0x29| = 1  ✓
```

**Unique selector pair: S = (0x28, 0x29)**

### 5.4 Base64 projection

The four original encoded strings concatenated in field order:

```
BynQtpeUyWTXKGTrGhdV2Q==   (24 chars)
tVMd3L1CKM4wFmyxEEEUV2bY   (24 chars)
4Fdzw1k=                   (8 chars)
vtv3f5aKY0jGQglP9a1AGw==   (24 chars)

Total: 80 characters
```

Note: 80 is also the byte length of a Bitcoin block header. This may or may not be meaningful.

S = (0x28, 0x29) = (40, 41) as decimal indices.

Positions 40–41 in the concatenated string fall inside the B encoding (`tVMd3L1CKM4wFmyxEEEUV2bY`, characters 16–19 of that field, specifically `EEEU`).

`EEEU` decodes to G4 = [10, 41, 14].

Therefore: **S → G4** in the base64 layout.

**Caveat:** This is a positional observation in the encoded (character-level) representation, not a byte-level derivation. The arithmetic of System A operates on decoded bytes. The projection of S into the base64 string operates on encoded characters. These are different representations. The result that both converge on G4 is notable but the two paths are not formally unified.

### 5.5 System B summary

```
Input:   A, E
Formula: seq[i] = group[E[i] mod 5][E[i] mod 3]
Filter:  seq[i] ∈ Σ_B AND |A[i] - A[j]| <= 1
Result:  S = (0x28, 0x29) — unique at threshold 1
Projection: S[decimal] = (40,41) → base64 position → G4
```

---

## 6. A-field derivations

A large number of bytes in field A are reproducibly derivable from the machine components. This is one of the stronger arguments that the machine is not coincidental.

| A index | A value | Derivation |
|---------|---------|------------|
| A[0] | 0x07 | = mask |
| A[1] | 0x29 | = Hdr[1] >> 1 = 0x53 >> 1 |
| A[2] | 0xd0 | = G3[2] XOR mask XOR G5[1] = b1 XOR 07 XOR 66 |
| A[3] | 0xb6 | = G3[2] XOR mask = b1 XOR 07 |
| A[4] | 0x97 | = E[4] OR mask = 96 OR 07 |
| A[5] | 0x94 | = Hdr[0] AND G1[0] = b5 AND dc |
| A[6] | 0xc9 | = G5[2] XOR G3[0] XOR mask = d8 XOR 16 XOR 07 |
| A[7] | 0x64 | = E[6] XOR mask = 63 XOR 07 |
| A[8] | 0xd7 | = NOT(G2[0]) mod 256 = NOT(28) |
| A[9] | 0x28 | = G2[0] |
| A[11] | 0xeb | = G2[2] XOR E[1] = 30 XOR db |
| A[12] | 0x1a | = Hdr[2] XOR mask = 1d XOR 07 |
| A[13] | 0x17 | = G4[0] XOR mask = 10 XOR 07 |
| A[14] | 0x55 | = G4[0] OR G4[1] OR G4[2] = 10 OR 41 OR 14 |
| A[15] | 0xd9 | = Hdr[0] XOR G3[1] = b5 XOR 6c |

A[10] = 0x64 is not independently derived through this path (it duplicates A[7]).

These derivations use a mix of XOR, OR, AND, NOT, and right-shift. They share mask and the G-group bytes as common operands, but they do not all follow a single unified formula. They are a family of relations, not a single rule.

---

## 7. Secondary relations

These hold and have been verified but are less central than the kernel/bridge chain.

```
G2[1] XOR G3[2] = ce XOR b1 = 7f = E[3]
G5[1] XOR G5[2] = 66 XOR d8 = be = E[0]
G3[0] + G4[1]   = 16 + 41  = 57 = G5[0]   (mod 256)
G3[1] + G3[2]   = 6c + b1  = 1d = Hdr[2]  (mod 256)
```

---

## 8. What is and is not unified

### 8.1 System A and System B are not connected

System A (arithmetic core) produces **0x6b** from G3.  
System B (selector core) produces **S = (0x28, 0x29)** from A and E.

Both converge on G4 — System A through the bridge relation, System B through the base64 projection. But the path from 0x6b to S = (0x28, 0x29) has not been derived. These are two independent subsystems that share G4 as a common landmark.

### 8.2 The kernel formula is not derived

The formula `mask = (G3[0] XOR G3[2]) AND 0x07` is reproducible but not derived from first principles. An independent analyst applying a different formula to G3 would get a different output. The specific formula used here is the one that produces the machine's most internally consistent results.

### 8.3 The selector rule is not proven unique

The rule `E[i] < len(B)` uniquely extracts G3 under this formulation. Whether it is the intended rule, or whether a different rule also produces a unique selection, has not been exhaustively tested.

---

## 9. Reproduction procedure

Any analyst can independently verify the machine by following these steps.

**Step 1.** Decode the four Base64 strings and verify the byte arrays match section 1.

**Step 2.** Segment B as specified in section 2.

**Step 3.** Apply the E selector rule from section 3. Confirm E[10] = 0x09 is the unique value satisfying value < 18. Confirm B[9:12] = G3 = [16, 6c, b1].

**Step 4.** Compute the kernel:
```
mask = (0x16 XOR 0xb1) AND 0x07  → 0x07
out  = 0x6c XOR 0x07             → 0x6b
```

**Step 5.** Verify the three closing relations:
```
0x6b XOR 0x14 = 0x7f  →  check against E[3]
0x09 XOR 0x14 = 0x1d  →  check against Hdr[2]
0xb1 OR  0x14 = 0xb5  →  check against Hdr[0]
```

**Step 6.** Compute the seq array from section 5.1 and verify S = (0x28, 0x29) is the unique adjacency pair under threshold 1.

**Step 7.** Verify A-field derivations from section 6 against raw A values.

If all steps verify, the machine has been independently reproduced.

---

## 10. Open questions

These are the unresolved problems as of this version. Contributions addressing any of these with mechanical rather than interpretive arguments are welcome.

1. **Kernel formula origin.** What is the non-arbitrary justification for `(G3[0] XOR G3[2]) AND 0x07` applied to G3[1]?

2. **System A / System B unification.** Is there a single formal system from which both 0x6b and S = (0x28, 0x29) are derived?

3. **Selector rule uniqueness.** Is `value < len(B)` the uniquely correct selector rule, or do alternative rules also produce clean single-extraction results?

4. **Adjacency threshold justification.** Why threshold 1? Can it be derived rather than chosen?

5. **External endpoint.** Does the machine point at something outside itself — a block, a key, a transaction — or is the machine the terminal result?

6. **C field role.** Field C participates in the canopy grammar described in companion documents but its structural role in the arithmetic core has not been established.

---

## 11. Falsification criteria

This specification is invalidated if any of the following can be demonstrated:

- The Base64 decodes in section 1 are incorrect
- The A-field derivations in section 6 do not hold arithmetically
- A second index pair satisfies the System B adjacency constraint at threshold 1
- The closing relations in section 4.2–4.4 fail to hold
- A permutation of the B partition (different stride or offset) produces a more complete machine with fewer free parameters

---

## 12. Changelog

| Version | Change |
|---------|--------|
| 1.0 | Initial public specification. Systems A and B documented separately. Open questions and falsification criteria explicit. |

---

*This specification makes no claims about intent, authorship, or the existence of a hidden message. It documents what is mechanically present in the data.*
