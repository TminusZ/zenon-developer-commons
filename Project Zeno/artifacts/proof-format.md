# proof-format.md — Canonical SMT Proof Format V1

**Companion to:** `smt-v1-test-vectors.json`, `../SPEC.md` §13.4 and §13.7
**Hash:** SHA3-256 (FIPS-202). Confirm: `SHA3-256("") = a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a`. This is **not** Keccak-256.

This document fully specifies the proof structure so that two independent implementations (Go, Rust, TypeScript) produce **byte-identical** proofs. It defines sibling ordering, path-bit ordering, proof encoding, and serialization. The same structure serves both inclusion and non-inclusion proofs.

---

## 1. Tree model the proof is built against

The proof is a full-depth proof over the uncompressed 256-level binary SMT defined in `../SPEC.md` §13.4:

- Depth ranges from `0` (root) to `256` (leaf). There are exactly 256 branch levels.
- **Path-bit ordering (MSB-first):** at depth `d`, the selecting bit is `bit(key, d) = (key[d / 8] >> (7 - (d mod 8))) & 1`. Depth 0 uses the most-significant bit of `key[0]`; depth 255 uses the least-significant bit of `key[31]`.
- **Side mapping:** bit `0` = left child, bit `1` = right child.
- **Leaf:** `leaf = SHA3-256(key || value)` for a present key. For a non-inclusion proof the leaf field is the 32-byte zero hash (the empty slot at that position).
- **Interior:** `SHA3-256(left || right)`, with the both-zero short-circuit: if both children are the 32-byte zero hash the node is the 32-byte zero hash.

A proof asserts exactly one sibling per branch level for all 256 levels. A zero-hash sibling is a real sibling and is counted at its level; it is simply not stored explicitly (see encoding).

---

## 2. Sibling ordering

**Deepest-first.** The proof's logical sibling sequence is `sib[255], sib[254], ..., sib[0]`, where `sib[d]` is the hash of the sibling subtree at the branch taken at depth `d` on the path to `key`:

- if `bit(key, d) = 0`, the path goes left, so `sib[d]` is the **right** subtree at depth `d+1`;
- if `bit(key, d) = 1`, the path goes right, so `sib[d]` is the **left** subtree at depth `d+1`.

Verification consumes siblings deepest-first (starting adjacent to the leaf at depth 255) and climbs to the root at depth 0. This is the "leaf-to-root" order required by `../SPEC.md` §13.4.

---

## 3. Zero-sibling compression via a 256-bit bitmap

Storing 256 explicit 32-byte siblings (8 KiB) per proof is unnecessary because most siblings are the 32-byte zero hash. The canonical encoding stores a **256-bit bitmap** plus only the **non-zero** siblings, in deepest-first order. This omits the *bytes* of zero siblings; it does **not** omit any *level*. Verification still walks all 256 levels, supplying the zero hash wherever the bitmap bit is clear. This encoding is canonical and **MUST** be reproduced exactly; an implementation that writes 256 explicit siblings, or that truncates levels, is non-conformant.

**Bitmap bit positions.** Let deepest-first index `i` run `0..255`, where `i` corresponds to depth `255 - i`. Bit `i` is stored MSB-first within the 32-byte bitmap: byte `i / 8`, bit `7 - (i mod 8)`. Bit `i` is **set** iff `sib[255 - i]` is non-zero.

The number of set bits equals the number of stored siblings, which appear in ascending `i` order (deepest-first).

---

## 4. Serialization (wire format)

All integers are big-endian. Fields are concatenated with no padding or separators. Exactly one valid encoding exists.

```
SmtProof :=
    flags        : u8       // bit0 = present (1) / absent (0); bits1..7 MUST be 0
    key          : 32 bytes
    leaf_hash    : 32 bytes // SHA3-256(key||value) if present; 32 zero bytes if absent
    sibling_bitmap : 32 bytes  // 256 bits, deepest-first, MSB-first within each byte
    sib_count    : u16      // number of non-zero siblings == popcount(sibling_bitmap)
    siblings     : sib_count * 32 bytes  // non-zero siblings, deepest-first (ascending i)
    // present-only tail:
    value_len    : u32      // present iff flags.bit0 == 1
    value        : value_len bytes  // present iff flags.bit0 == 1
```

**Encoding rules (normative):**

- `flags` bits 1..7 **MUST** be zero; a decoder **MUST** reject otherwise.
- `sib_count` **MUST** equal the popcount of `sibling_bitmap`; a decoder **MUST** reject otherwise.
- For a non-inclusion proof (`flags.bit0 == 0`), `leaf_hash` **MUST** be 32 zero bytes and the `value_len`/`value` tail **MUST** be absent.
- For an inclusion proof (`flags.bit0 == 1`), the decoder **MUST** verify `SHA3-256(key || value) == leaf_hash`.
- The total length **MUST** be exactly `1 + 32 + 32 + 32 + 2 + 32*sib_count (+ 4 + value_len if present)`; trailing bytes **MUST** be rejected.

---

## 5. Proof verification procedure

Input: a 32-byte `expected_root` and an `SmtProof`. Output: accept / reject.

```
1.  Parse the proof per Section 4. Reject on any structural violation
    (reserved flag bits set, sib_count != popcount, wrong tail presence,
     leaf_hash != SHA3-256(key||value) for an inclusion proof, trailing bytes).
2.  cur := leaf_hash
3.  next_sibling := 0   // index into the stored non-zero siblings
4.  for i in 0 .. 255:                 // deepest-first
        depth := 255 - i
        if bit i of sibling_bitmap is set:
            sib := siblings[next_sibling]; next_sibling := next_sibling + 1
        else:
            sib := 32 zero bytes
        b := bit(key, depth)            // (key[depth/8] >> (7 - depth mod 8)) & 1
        if b == 0:
            cur := NODE(cur, sib)       // our node is LEFT, sibling RIGHT
        else:
            cur := NODE(sib, cur)       // our node is RIGHT, sibling LEFT
        // NODE(l,r): if l == zero32 and r == zero32 -> zero32; else SHA3-256(l || r)
5.  Accept iff cur == expected_root AND next_sibling == sib_count.
```

- An **inclusion** proof proves `key` maps to `value` under `expected_root`.
- A **non-inclusion** proof (`leaf_hash = zero32`) proves `key` is absent under `expected_root`: the same climb with an empty leaf slot reproduces the root.
- The final `next_sibling == sib_count` check **MUST** be enforced so a proof cannot carry unused siblings.

---

## 6. Worked reference

Every proof in `smt-v1-test-vectors.json` carries its `serialized` bytes and its `expected_root`. Each has been independently re-derived from the serialized bytes alone (parse → climb 256 levels → compare root). The empty-tree root is the 32-byte zero hash; a single all-left key (`0x00..00`) climbs 256 levels with a zero-hash right sibling at every level. Implementers should treat the JSON as the authoritative byte-level oracle and this document as the procedure that produces it.
