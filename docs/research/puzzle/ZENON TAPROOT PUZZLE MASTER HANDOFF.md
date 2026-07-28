Zenon Taproot Puzzle — Condensed Master Handoff
Status: Internal mechanics near-locked. External semantic referent open. No hidden plaintext found. Artifact: Bitcoin block 709,632 (Taproot activation block, 2021-11-14) This document supersedes Addenda A–K by consolidating all results into one deduplicated reference. No locked or strong-partial finding from the source material has been dropped — only repetition across addenda has been removed.

1. The Raw Artifact
20 OP_RETURN transactions from address bc1qrnldpdlq9dsfy946m4vqa5mrec8qhdrx363end, all in block 709,632, timestamp 2021-11-14 00:15:27. 19 are structural fragments; the 20th is a terminal consolidation transaction.
Constrained alphabet across all fragments: z q 1 . : ; , — 7 symbols only.
Assembled reconstruction (rendered tree, not raw storage order):
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
Terminal consolidation transaction (Locked, pending explorer re-verification)
* TXID 911dcb7435932f64215f8de4058186aef9bfd4356978c95830e77a38b9484083
* 19 inputs (consumes all 19 structural UTXOs), 1 OP_RETURN output + 1 change output (same address)
* Fee 1,008,000 sats; OP_RETURN hex 6a0d5a454e4f4e204e4554574f524b = "ZENON NETWORK"
* Makes the object architecturally 20 units: 3 payload + 5 canopy + 1 E-boundary + 10 trunk + 1 terminal
Published visual render (Partial)
A green-on-black monospace terminal-style render of the assembled tree exists and may be a canonical layer in its own right, not just a transcription convenience. Source/provenance/timestamp of that image have not yet been independently documented — required before treating absolute spacing/font metrics as meaningful.

2. The Four Payload Fields
Field	Base64	Decoded Bytes	Length
A	BynQtpeUyWTXKGTrGhdV2Q==	07 29 d0 b6 97 94 c9 64 d7 28 64 eb 1a 17 55 d9	16
B	tVMd3L1CKM4wFmyxEEEUV2bY	b5 53 1d dc bd 42 28 ce 30 16 6c b1 10 41 14 57 66 d8	18
C	4Fdzw1k=	e0 57 73 c3 59	5
E	vtv3f5aKY0jGQglP9a1AGw==	be db f7 7f 96 8a 63 48 c6 42 09 4f f5 ad 40 1b	16
B segmented into six 3-byte chunks (Hdr + G1–G5):
Hdr = b5 53 1d
G1  = dc bd 42
G2  = 28 ce 30
G3  = 16 6c b1   ← proof kernel
G4  = 10 41 14
G5  = 57 66 d8
C as ASCII string: 4 F d z w 1 k = (indices 0–7). C nibbles: e,0,5,7,7,3,c,3,5,9.
B Base64 quartet decomposition:
tVMd | 3L1C | KM4w | Fmyx | EEEU | V2bY
b5531d | dcbd42 | 28ce30 | 166cb1 | 104114 | 5766d8
Hdr   | G1    | G2    | G3=Fmyx | G4    | G5
C Base64 self-split (Strong Partial / near-Locked): 4Fdz | w1k= → e0 57 73 | c3 59. Left half = idle/activation/witness-exposure bytes; right half = witness-consumption/terminalization bytes. The w1k= corridor is the densest single object in the artifact — simultaneously an execution-layer fragment (w,1,k), an assertion-layer fragment (=), a valid Base64 closure, and a scheduler fragment decoding to c3 59.

3. Structural Layout & Assembly (Locked)
Region	Rows	Description
Payload header	3	A, B, C — delimited by ;...;
Canopy	5	Branching structure
E boundary	1	Asymmetric delimiters ,E.
Trunk (idle)	2	Pure-z, nibbles e,0
Trunk (active)	8	Geometry-bearing, nibbles 5,7,7,3,c,3,5,9
Terminal	1	ZENON NETWORK
Delimiter grammar classifies every row and is required for assembly (Locked) but was hostile-tested and found not required for projection, witness exposure, or any execution semantics (Rejected as an opcode layer; Locked only as render/assembly grammar):
Pattern	Row class
;...;	Payload rows (A,B,C)
.:...	Canopy type A
,;...	Canopy type B
,...,	Trunk rows
,....`	E boundary
C is simultaneously: (1) a control word, (2) the trunk execution schedule, (3) the assembly key that orders the 10 unordered trunk fragments — confirmed Locked, reconstruction unique except for two genuinely interchangeable duplicate rows.
Structural correspondences (Locked): C has 5 bytes ↔ 5 canopy rows; C has 10 nibbles ↔ 10 trunk rows; B has 5 triplets (G1–G5) ↔ 5 canopy rows; q-count = 27 = E's terminal byte 0x1b; ; count = 13 = count of 1 geometry symbols; : count = 5 = canopy row count = C byte count.
Coordinate caveat: all geometry coordinates in this document are row-local. Canopy rows have staggered absolute indentation. Cross-row visual-adjacency claims require a separate absolute-coordinate pass; the projection rule itself is unaffected.

4. Canopy Rendering Law (Strong Partial / Near-Locked)
For canopy row i: G_i = corresponding B triplet, C_i = corresponding C byte, n = low nibble of C_i, p = popcount(n).
Prefix rule — controlled by high bit of G_i[1]:
if G_i[1] >= 0x80: prefix = ".:"
else:              prefix = ",;"
(G1[1]=bd→.:, G2[1]=ce→.:, G3[1]=6c→,;, G4[1]=41→,;, G5[1]=66→,; — reproduces .: .: ,; ,; ,; exactly.)
Body rule — controlled by low nibble of C_i:
if n == 0: body = "1" + "z"*9
else:
    left_symbol = "q" if n >= 4 else "1"
    left_len    = max(popcount(n) - 1, 1)
    z_len       = 7 - popcount(n)
    right       = "qqq" if n < 8 else "1qq"
    body = left_symbol*left_len + "z"*z_len + right
(C1=e0→1zzzzzzzzz, C2=57→qqzzzzqqq, C3=73→1zzzzzqqq, C4=c3→1zzzzzqqq, C5=59→qzzzzz1qq — exact match. The two identical duplicate rows are explained mechanically: 73 and c3 share low nibble 3; the high nibble is discarded by the body renderer.)
Terminal punctuation rule: n==0 → ".", else ",".
This reproduces all five canopy rows exactly. Remaining caveat: a hostile minimality proof (testing whether a simpler non-equivalent rule reproduces the same rows) has not been completed.
Channel split: G middle-byte high bit → prefix family; C low nibble → body class; C low-nibble-zero test → terminal punctuation. Canopy = compressed/declared state; trunk = expanded/executed state.

5. Geometry Layer & Projection Machine (Locked)
Coordinate table (row-local, valid for projection only):
Type	Coordinates (row,col)	Count
q	(1,2)(1,3)(1,8)(1,9)(1,10)(2,8)(2,9)(2,10)(3,8)(3,9)(3,10)(4,2)(4,9)(4,10)(7,6)(8,10)(10,5)(10,13)(11,5)(11,9)(12,5)(12,12)(12,18)(13,5)(13,15)(14,5)(14,18)	27
1	(0,2)(2,2)(3,2)(4,8)(7,19)(8,19)(9,12)(9,19)(10,7)(10,19)(11,16)(11,19)(12,20)	13
q forms one connected 27-node/49-edge backbone with two degree-1 terminals at (7,6) and (10,13); dominant bottleneck at (4,9), the canopy/trunk boundary. (Cross-row topology claims need the absolute-coordinate repass noted in §3.)
Projection rule (the core mechanism):
payload_col = geometry_col - 1
Trunk execution trace (all four payloads, by nibble phase):
Phase	Nibble	A	B	C	E	Active count
1	e	—	—	—	—	0
2	0	—	—	—	—	0
3	5	pe	1E	1z	5a	2
4	7	We	ME	zz	0A	2
5	7	Xe	wE	zz	jA	2
6	3	wkTe	3KFE	wkzz	fYlA	4
7	c	wWTe	3myE	wzzz	f0PA	4
8	3	wXdV	3wEU	wzzz	fjaw	4
9	5	wr	3y	wz	fl	2
10	9	wd	3E	wz	fa	2
Activation envelope: 0,0,2,2,2,4,4,4,2,2 (ramp/peak/decay). The C column is the canonical witness-lifecycle trace: 1 once (onset), k once (transient at privilege onset, phase 6), w persists from phase 6 onward, z is substrate/default.
Statefulness proof (Locked): output is not a function of current nibble alone. 5 after 0 → 1z; 5 after 3 → wz (same nibble, different output). 3 after 7 → wkzz; 3 after c → wzzz (same nibble, different output). So output = f(previous_nibble → current_nibble), not f(current_nibble). The trunk is a stateful edge machine, read as 7 transitions: 0→5 (activation), 5→7 (prep), 7→3 (witness exposure), 3→c (witness consumption), c→3 (commit), 3→5 (compression), 5→9 (finalization).
Canopy projection (same rule applied to canopy rows) reproduces F, Fd=zz, F=zz, F=zz, F=zz.
Read/residue split (geometry selects a "read set"; everything else is "residue"):
Payload	Read set	Residue
A	tpeyWXKTrhdV	BynQUTGG2Q==
B	3L1KMwFyxEEU	tVMdC4mEV2bY
E	f5aY0GQlPa1A	vtv3Kjg9Gw==
Protected anti-diagonal (survives projection in all three residues, center Base64 quartet of each): UTGG+C4mE+Kjg9 → 51 31 86 0b 89 84 2a 38 3d (9 bytes). This is the single most important unresolved object in the artifact (see §8).

6. Byte-Layer Machine — G3 Kernel and Terminal Sink (Locked)
E selector: E[10] = 0x09 is the unique byte in E satisfying value < len(B)=18 (exhaustively confirmed across all 16 E bytes — domain caveat: this is exhaustive within the tested selector interpretation, not proven exhaustive against all conceivable interpretations). 0x09 selects B[9:12] = G3 = 16 6c b1.
Kernel computation:
mask = (G3[0] XOR G3[2]) AND 0x07 = (0x16 XOR 0xb1) AND 0x07 = 0x07
out  = G3[1] XOR mask = 0x6c XOR 0x07 = 0x6b
0x6b does not appear in any raw field byte — it is computed. 0x6b = ASCII k. C[6] = k, and the projection trace reads C[6] exactly once, at phase 6 — the wkzz transient, the unique one-time character in the entire ASCII execution trace. This kernel-output-equals-ASCII-transient match is mechanically verified (treat the earlier "not coincidental" framing as "strong convergence" pending full formal unification).
Closing relations (Locked):
0x6b XOR G4[2]   = 0x6b XOR 0x14 = 0x7f  = E[3]     ✓
E[10] XOR G4[2]  = 0x09 XOR 0x14 = 0x1d  = Hdr[2]   ✓
G3[2] OR G4[2]   = 0xb1 OR 0x14  = 0xb5  = Hdr[0]   ✓
Hdr AND G4 = G4  (G4 bitwise contained within Hdr)   ✓
Delta vector and terminal sink — the central equation:
Δ = Hdr XOR G4 = (b5 53 1d) XOR (10 41 14) = a5 12 09
Sink = G3 AND Δ = (16 6c b1) AND (a5 12 09) = 04 00 01
   lane-wise: 16&a5=04   6c&12=00   b1&09=01
Disjoint header structure (Locked): G4 AND Δ = 00 00 00; G4 XOR Δ = Hdr; G4 + Δ = Hdr. Hdr is the disjoint union of G4 (resolved/terminal state) and Δ (verification/control mask) packed into one header.
Bounded closure: 24 distinct residues under the G3 neighborhood, all within G3's bit-support; fixed-point termination confirmed.
Conserved corridor core: G2 AND G3 AND G4 = G2 AND G4 = Hdr AND G2 = 00 40 10.
Current role assignment (Strong Partial unless noted)
Object	Role
Hdr	environment state (claim + verification mask, packed)
G1	gate / opening object
G2	proof-corridor container (see §7)
G3	selected/witness kernel — Locked as the kernel itself
G4	resolved/terminal-state object
G5	post-resolution carried state (audited against anti-diagonal and against substitution into the Δ calculation — no privileged recovery found; best current classification: post-resolution carry object, not a sink comparator or anti-diagonal constructor)
C	scheduler / canopy-renderer control / static memory (see §9)
E	wrapper / selector / boundary object
A	witness prefix
G4 internal reading (Strong Partial / near-Locked): G4 = 10 41 14. G4[0]=0x10=16 matches the terminal moving address P10={4,16} (§10). G4[1]=0x41 packs the two surviving sink lanes 04/01 together. G4[2]=0x14=20 matches the active-trunk absolute right rail / closure boundary column.

7. Bitcoin-Script-Language Symbolic Layer (Strong Partial — explicitly NOT executable Script)
The artifact is not spendable Bitcoin Script or a Taproot witness (Rejected, multiple hostile passes). It does, however, use Script/Tapscript vocabulary symbolically:
* G2 = 28 ce 30 → 28 = PUSH40. The following 40-byte corridor is exactly: G2-tail + G3 + G4 + G5 + C + E + A-prefix. So G2 functions as a proof-corridor container carrying everything except Hdr and G1 (the "environment/gate" objects).
* G3 starts with 16 = PUSH22; G4 starts with 10 = PUSH16; A starts with 07 = PUSH7 → reader hierarchy PUSH40 → PUSH22 → PUSH16 → PUSH7.
* G3[1] = 0x6c = OP_FROMALTSTACK; the kernel computes 0x6b = OP_TOALTSTACK; the ASCII layer independently produces k = 0x6b. Strong symbolic convergence (not a valid execution path).
* E[10] = 0x09 = OP_PUSHBYTES_9 — and the protected anti-diagonal certificate is exactly 9 bytes. So 09 plausibly does two jobs at once: selects G3, and symbolically pushes the 9-byte certificate object: 09 [51 31 86 0b 89 84 2a 38 3d]. Status: Locked that 09 = OP_PUSHBYTES_9 and that it exactly accounts for the certificate length; Strong Partial / near-Locked that this is intentional.
Hostile falsifications (Rejected, do not revisit): 04 00 01 is not a Taproot control block; 0x80 is not a Tapscript leaf version (Taproot uses 0xc0/0xc1); the anti-diagonal matrix is not a Merkle path; the artifact is not executable Bitcoin Script; it is not a literal Taproot spend path.

8. The Protected Anti-Diagonal Certificate (Locked carrier behavior; Open derivation)
Object: UTGG | C4mE | Kjg9 → matrix
L = 51 31 86
M = 0b 89 84
R = 2a 38 3d
(Column 3 of the underlying residues is ragged/padded and not admissible as a clean 3×3 comparison — Locked caveat.)
Tier-1 census protocol (Locked methodology, to prevent data-dredging)
Only same-lane primitive reductions allowed: L,M,R, L&M,L|M,L^M, L&R,L|R,L^R, M&R,M|R,M^R, L&M&R,L|M|R,L^M^R = 15 reductions × 3 lanes = 45 total. No shifts, rotates, cross-lane ops, or chains.
Result vs. control: the adjacent Column-1 control matrix scores density 0.088 (4 hits / 45) against the machine vocabulary {00,01,04,09} + provenance byte b1. The target (anti-diagonal) matrix scores 0.244 (11/45) — and recovers the full vocabulary through shallow same-lane ops:
51&0b=01   51&2a=00   51&0b&2a=00
31&89=01   31^38=09   89^38=b1   31&89&38=00
86&3d=04   84&3d=04   86&84&3d=04
Recovered: 00=consumed lane, 01=substrate, 04=survivor, 09=selector, b1=G3-ancestry byte.
Full 45-output census: 32 unique bytes; convergence hubs include b9(×4), 00(×3), 04(×3), 7b(×3). Vocabulary hits: 00×3, 01×2, 04×3, 09×1, b1×1 — not a flat random spread.
Monte Carlo control (Locked for vocabulary specificity): real nonzero vocabulary scores 0.2222; 100 matched-Hamming-weight fake vocabularies scored mean 0.0327, median 0.0222, max 0.1111 (99th pct 0.0891). 100/100 controls scored below the real vocabulary. Fake weight-4 "provenance" targets appeared in only 8/100 controls. This is statistically real enrichment, not generic low-Hamming-weight bias — but note b1 is not the only weight-4 output in the full Tier-1 space (5 exist: 2b,39,5a,b1,b8); its significance is that it's the one that's also G3-ancestry, not that it's mathematically unique.
0x80 topology (Locked relationships, Strong Partial interpretation):
31 ^ 80 = b1   (G3-ancestry relation)
89 ^ 80 = 09   (selector relation)
84 ^ 80 = 04   (survivor relation)
Suggests the high bit may function as a boundary/carrier/normalization flag — not proven.
Scaffold relations (Partial): 38 = 31^09; 2a = 31-07. Unresolved rim bytes: 51, 0b, 86, 3d — possibly carrier substrate or fragments of a larger construction; no full deterministic forward-constructor found.
Witness-boundary bridge (Partial, interesting, not locked): the witness byte 6b/6c is largely absent from the anti-diagonal — except 86 - 6b = 1b, and 0x1b = 27 independently equals both the padded E-residue terminal quartet (Gw== → 1b) and the q-count (27). May indicate Column 3 functions as terminal-boundary residue rather than full carrier matrix.
Current best classification: post-consumption attestation/certificate carrier, preferentially encoding the machine's completed-state vocabulary while omitting the active witness 6b. Not plaintext, not executable Script, not proven to have a complete forward constructor F(machine_state) → anti-diagonal.

9. C as Address-Controlled Memory (Strong Partial / near-Locked)
Reframing: C is static — the trunk doesn't mutate C, geometry changes which addresses of C become reachable.
Address lifecycle by phase:
phase 3 (5)  → C[5],C[18]              = 1z
phase 4 (7)  → C[9],C[18]              = zz
phase 5 (7)  → C[11],C[18]             = zz
phase 6 (3)  → C[4],C[6],C[12],C[18]   = wkzz
phase 7 (c)  → C[4],C[8],C[15],C[18]   = wzzz
phase 8 (3)  → C[4],C[11],C[17],C[19]  = wzzz
phase 9 (5)  → C[4],C[14]              = wz
phase 10 (9) → C[4],C[17]              = wz
C[5]=1 and C[6]=k each appear exactly once then become unreachable. C[4]=w appears alongside k and remains reachable through the terminal state. Mechanism: read-head address removal, not value mutation. 7→3 exposes w+k; 3→c removes the k address while preserving w — the cleanest mechanistic statement of "witness consumption" in the whole artifact.
Canopy/trunk privilege split (Strong Partial): canopy reads only declaration-domain addresses C[1]=F, C[2]=d, C[7]= =; trunk reads only execution-domain addresses C[4]=w, C[5]=1, C[6]=k. The trunk never reads C[7]= =. So: canopy declares, trunk executes — and = is canopy-visible but trunk-inaccessible (role: declaration/closure/assertion marker, exact semantics still Partial).

10. Visual Geometry — The Fixed-Envelope Plateau (Locked arithmetic; Strong Partial interpretation)
Active-trunk negative-space gap sequence: 11, 9, 7, 4, 4, 4, 7, 9 → hex 0b, 09, 07, 04, 04, 04, 07, 09 — overlaps existing vocabulary (0b=anti-diagonal byte, 09=selector, 07=kernel mask, 04=survivor lane). Locked as observation; Strong Partial as "meaningful machine trace" (not claimed as a plaintext channel).
Triple-4 plateau rows are visually equal-width but NOT identical (Locked) — confirming the plateau is an active transition chamber, not a passive stable zone.
Plateau reachable C-address sets (via projection rule):
P6 = {4,6,12,19}   (4a — witness exposed:  k=C[6] reachable)
P7 = {4,8,15,19}   (4b — witness removed/retargeted)
P8 = {4,11,17,19}  (4c — post-removal commit)
C[4]=w and C[19]=z persist across all three; C[6]=k appears only in P6. The P6→P7 transition is the cleanest visual proof of witness-address-removal in the document.
Local plateau arithmetic (Locked):
* Middle-pair sums: 6+12=18, 8+15=23, 11+17=28 → progression 18→23→28, step +5, observed only inside the chamber (Rejected as a global clock — does not continue outside the plateau).
* Middle-pair distances: 12-6=6, 15-8=7, 17-11=6 → oscillation 6,7,6.
* Recurrence law (Locked): next_left = current_right - 4 (12-4=8, 15-4=11, 17-4=13 ✓).
* Exit collapse: P9={4,13}, P10={4,16}, stride 13→16=+3 (Partial as a finalization marker).
The 0x12 Geometry–Byte Bridge (Locked equality; Strong Partial causal interpretation)
This is the strongest cross-layer (visual ↔ byte) bridge found.
P6 middle-pair sum: 6 + 12 = 18 = 0x12
Δ[1] (from §6)    = 0x12
G3[1] AND Δ[1]: 6c & 12 = 00   ← the middle-lane annihilation in the terminal sink
The same value 0x12 is independently produced by the visual plateau geometry and functions as the byte-layer's middle-lane sink annihilator. (Hostile caveat: 0x12 is not the only byte capable of annihilating 0x6c, so this isn't mathematical uniqueness — its significance is that it's the actual value, independently arrived at from two different layers.)
The 0x0f Spatial Constant (Locked arithmetic; Strong Partial as workspace constant; Rejected as a byte-layer constant)
Three independent constructions all yield 15 = 0x0f:
* P8 collapse: 11+4=15, 19-4=15
* Visual active-trunk absolute width: right rail (col 20) − left rail (col 5) = 15
* Row-local workspace: right wall (26) − left spine (11) = 15
0x0f does not appear directly in Hdr/G3/G4/Δ/Sink/C, so it is classified as a geometry/visual-workspace constant, distinct from 0x12 which bridges directly into the byte machine.
Updated role of k (Strong Partial, downweighted from earlier addenda): hostile testing showed the P7→P8→P9 recurrence still holds even if k/address-6 is removed from consideration — so k is a transient exposure token, not the causal engine of terminal compression. It remains important as the mechanically-verified ASCII/byte bridge (§6), just not as the thing that drives collapse.
Visual model rejections: a "global clock" reading of the +5 progression — Rejected. A speculative "hourglass" reading of the gap sequence — Partial/weak, geometric description only, not a machine object. The best-supported visual interpretation remains the recurrence/transition chamber model above.

11. Terminal State Equivalence (Strong Partial / near-Locked)
Two terminal states, reached independently:
* ASCII layer: wkzz → wzzz → wz (witness exposed → witness removed → compressed survivor)
* Byte layer: 16 6c b1 → 04 00 01 (kernel → sink, via Δ filtering, §6)
Role-mapped (not literal byte-to-character) correspondence:
04 00 01  →  w  Ø  z   →   wz
(survive)(consumed)(survive)
This is asserted as role-preserving terminal equivalence, explicitly not literal equality — no direct mechanical transform from 04 00 01 to the ASCII string wz has been proven. Status: Strong Partial / near-Locked for the role correspondence; Open for a formal transform.

12. Assertion Layer (Partial / Strong Partial)
Two objects sit outside every known execution system, both at the same architectural position (terminal state → assertion):
	Local	Global
Object	= (C[7])	ZENON NETWORK
Properties	canopy-visible, trunk-inaccessible, persistent, non-executing	outside projection/byte/scheduler machines; terminal
Proposed closure chains:
Local:  wkz → wØz → wz → =
Global: 09 → 6b → 04 00 01 → [9-byte certificate] → ZENON NETWORK
Current interpretation: = and ZENON NETWORK may belong to a distinct assertion/attestation layer, structurally downstream of execution and residue but not produced by a known transform from either. Status: Partial.

13. What Has Been Falsified (Do Not Revisit)
* HTLC / hash preimage; Bitcoin Script / Taproot witness (spendable); wallet or private-key derivation; address derivation (Bitcoin or Zenon); ZTS token derivation
* SHA256 / SHA3 / Keccak chains (single & double); hash chaining/concatenation; simple XOR; simple substitution cipher; simple Base64-as-plaintext; standard steganography in the plain-text artifact
* Punctuation layer as an execution/opcode layer (assembly-grammar role only — Locked; opcode role — Rejected)
* Literal Taproot control block / Tapscript leaf version / Merkle path for 04 00 01 or the anti-diagonal matrix
* Executable Bitcoin Script anywhere in the artifact
* "Global clock" reading of the +5 plateau progression
* Direct genesis byte-cluster identity: disciplined scan of go-zenon-master for e05773c359, 4Fdzw1k=, 5131860b89842a383d, 166cb1, 040001, a51209, b10904, e0735907 found no structured anchor — only weak unpositioned fragments inside unrelated 32-byte hash fields (c359, 73c3, 6c6b). Literal Zenon genesis identity proof: Rejected based on the tested repository.
* k as a literal private key, literal Kaine key, or literal SporkAddress key — Rejected (Open/unsupported at best; "k = Kaine specifically" is explicitly flagged as speculative, not evidenced)
* ZENON NETWORK as a literal decode output of 04 00 01 or any sink byte — Rejected
* CommunitySporkAddress relevance to this 2021 artifact — Rejected; legacy-entry bytes 01/04/09 in genesis data — assessed as sorted hash-prefix noise, not role bytes

14. Confidence Register (Consolidated)
Locked:
* C = e0 57 73 c3 59; B segmentation into Hdr/G1–G5; all structural row/byte/nibble correspondences in §3
* Delimiter grammar fully classifies assembly; C nibble sequence fully orders the trunk
* Canopy rendering law reproduces all 5 rows exactly (minimality proof still pending — see Strong Partial)
* payload_col = geometry_col - 1 projection rule; full A/B/C/E execution trace table; statefulness proof (output depends on transition, not current nibble alone)
* Anti-diagonal residue preserved across A/B/E; center-quartet extraction method
* E[10]=0x09 uniquely satisfies <len(B) within the tested domain; selects B[9:12]=G3=16 6c b1
* Kernel: mask=0x07, out=0x6b; 0x6b=ASCII k; k appears in trace exactly once, at phase 6
* Closing relations (§6) all verified; Hdr XOR G4 = a5 12 09; G3 AND Δ = 04 00 01; G4 AND Δ = 0, G4 XOR Δ = Hdr, G4+Δ=Hdr
* 0x12 bridge: P6 middle-pair sum =0x12=Δ[1]; 6c & 12 = 00
* 0x0f workspace constant independently derived three ways (§10)
* Plateau reachable sets and the next_left = current_right-4 recurrence; triple-4 rows non-identical; C[6]=k reachable only in P6
* Anti-diagonal Tier-1 census methodology, Monte Carlo result (100/100 controls below real vocabulary), 0x80 topology relationships
* E[10]=0x09=OP_PUSHBYTES_9 exactly accounts for the 9-byte anti-diagonal length
* Terminal consolidation transaction structure (pending one external explorer re-check, see §1)
* All falsifications in §13
Strong Partial / near-Locked:
* G3 is the intended proof kernel; 0x6b/k is the intended ASCII↔byte bridge; canopy-rendering minimality unproven
* G4 as compressed/resolved terminal-state object; Hdr as claim+verification-mask packing; Δ as the selected verification mask
* 0x12 as an intentional (not incidental) geometry-byte bridge; plateau as a witness-transition/recurrence chamber
* Anti-diagonal as a post-consumption attestation/certificate carrier; 09 as an intentional symbolic OP_PUSHBYTES_9 pushing that exact certificate
* Symbolic (non-executable) Bitcoin/Tapscript-language framing of the whole machine
* Terminal-state role equivalence between 04 00 01 and ASCII wz
* Canopy = declaration layer / trunk = execution layer privilege split; C as address-controlled static memory
* Role-level "bootstrap authority / witness disappears / surviving network asserted" reading (see §15) — explicitly role-level only, not byte-identity
Open (the actual remaining work):
1. Anti-diagonal forward constructor — no function F(machine_state) → 9-byte certificate has been derived; this is the single highest-value remaining problem along with #2.
2. Why Hdr XOR G4 specifically produces a5 12 09 — the delta vector's origin is unexplained; the sink computation downstream of it is solved.
3. Exact external semantic referent — what real-world claim, if any, the machine is attesting.
4. Whether the published visual render is designer-canonical (provenance undocumented).
5. Formal (not role-based) proof that 04 00 01 and ASCII wz are literally the same terminal state.
6. Exact semantic role of = (declaration/closure/padding-only?) and of G5 (post-resolution carry — confirmed not a sink comparator or anti-diagonal constructor, but no positive role established).
7. Whether the 0x80 topology in the anti-diagonal is genuine flagging/normalization or coincidental.

15. Current Best Solve Statement
The artifact is most defensibly described as a deliberately layered, self-describing, symbolic proof/certification object embedded in Bitcoin's Taproot-activation block — not a hidden plaintext message, not executable Bitcoin Script, and not a literal Taproot spend path or control structure.
Reproducible pipeline:
19 unordered OP_RETURN fragments
→ delimiter-grammar assembly + C-nibble ordering → rendered tree
→ canopy renderer (G middle-byte hi-bit → prefix; C low-nibble → body/punctuation)
→ geometry projection (payload_col = geometry_col - 1) → read/residue split per payload
→ E[10]=0x09 selects B[9:12]=G3=16 6c b1
→ kernel: mask=0x07, computed transient 0x6b = ASCII k
→ C-address lifecycle: C[6]=k exposed once (phase 6 / plateau state P6), then made unreachable
   (P6→P7), while C[4]=w persists — mechanically and visually confirmed witness removal
→ Hdr XOR G4 = Δ = a5 12 09;  G3 AND Δ = terminal sink 04 00 01
   (bridge: P6 middle-pair-sum = 0x12 = Δ[1]; 6c & 12 = 00, the annihilated middle lane)
→ 9-byte protected anti-diagonal certificate (statistically verified non-random vocabulary carrier)
→ 0x09 = OP_PUSHBYTES_9 symbolically pushes that exact 9-byte object
→ local assertion "=" / global assertion "ZENON NETWORK" close the object
The strongest invariant spanning every layer (ASCII, byte, address-reachability, and visual-geometry) is the same three-step shape recurring at different representational levels:
survivor present → witness exposed and then removed → survivor persists as residue, closed by an assertion marker.
A genesis-identity audit against the live Zenon codebase found no direct byte-level anchor for any of the kernel, sink, or certificate values — so any Zenon-specific reading (e.g. bootstrap-authority/spork-witness symbolism) remains a role-level, not identity-level, hypothesis.
Final status:
* Internal mechanical reconstruction: Near-Locked
* Symbolic (non-executable) Script-language framing: Strong Partial / near-Locked
* Geometry↔byte bridge (0x12) and sink architecture: Locked
* Anti-diagonal certificate role: Strong Partial; forward constructor: Open
* External semantic referent / author intent: Open
* Hidden plaintext: not justified by current evidence
* Direct Zenon genesis byte identity: Rejected
* Executable Taproot script: Rejected

16. Next Highest-Value Work (in order)
1. Derive the anti-diagonal forward constructor F(machine_state) → 51 31 86 / 0b 89 84 / 2a 38 3d. This is the largest remaining gap between "we can verify the certificate's properties" and "we understand how it's built."
2. Explain the origin of Δ = a5 12 09 (i.e., why Hdr XOR G4 takes this specific value) — the sink computation itself is fully solved downstream of this; this is the next layer up.
3. Resolve terminal-state equivalence formally — test for a real mechanical transform between 04 00 01 and ASCII wz, not just role correspondence.
4. Document provenance of the published visual render (source, timestamp, author) before treating absolute spacing/font metrics as meaningful.
5. Independently re-verify the terminal consolidation transaction (911dcb74...) against the live explorer one more time given its structural importance to the "20-object" framing.
Do not propose new cryptographic transforms from scratch. Do not re-test anything in §13. Work forward from the Locked and Strong Partial register in §14.
