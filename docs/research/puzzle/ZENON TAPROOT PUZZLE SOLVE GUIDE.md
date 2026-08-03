# How to Solve the Zenon Taproot Puzzle — A Beginner's Guide

*A plain-language walkthrough that anyone with a terminal can follow. Every command below has been run and produces the results shown.*

---

## What is this?

In November 2021, the Zenon Network hid a puzzle **inside the Bitcoin blockchain** — specifically inside block **709,632**, the block where Bitcoin's "Taproot" upgrade activated. They did it by publishing a picture of the Zenon logo drawn in text characters (ASCII art), spread across 19 Bitcoin transactions.

Tucked inside that logo were four short strings of gibberish. Decoded and decrypted correctly, they reveal **four secret words**. Add those to eight words from earlier puzzles and you get a complete 12-word crypto wallet seed phrase — which unlocks a specific Zenon wallet address.

This guide takes you from the raw clues to those four words and the final address. The whole thing is **provable**: at the key moment, the cryptography either verifies or it doesn't. There's no guessing.

**The answer, up front** (so you know where we're headed):

- The four missing words are: **`wall nation drive smoke`**
- The wallet they unlock: **`z1qrn3jeapt848zxg3akf2ewhrxxwsa945sj798s`**

The fun is in reproducing it yourself.

---

## What you'll need

- **Python 3** (already on most Macs and Linux machines; on Windows, install from python.org)
- **One extra library.** Install it once:
  ```sh
  pip install cryptography
  ```
- A terminal, and about 15 minutes.
- *(Optional)* Internet access, only if you want to pull the data straight from the Bitcoin blockchain yourself instead of trusting the strings printed below.

That's it. No blockchain node, no special hardware.

---

## The big picture

Here's the whole journey in one glance:

```
Bitcoin block 709,632
        │  (contains 19 transactions drawing the Zenon logo)
        ▼
Four hidden text strings   →   BynQtpeUyWTXKGTrGhdV2Q==  (and 3 more)
        │  (decode from Base64)
        ▼
55 raw bytes, split 16 / 23 / 16
        │  (these are the 3 parts of an encrypted message)
        ▼
Decrypt using the key SHA-256("Taproot")
        │  (the math verifies — this is the "aha" moment)
        ▼
wall nation drive smoke
        │  (add the 8 earlier words → 12-word seed phrase)
        ▼
z1qrn3jeapt848zxg3akf2ewhrxxwsa945sj798s
```

Now let's do it step by step. If you just want the payoff, skip to **[The all-in-one script](#the-all-in-one-script)** — it runs the entire thing in one go.

---

# Part 1 — The core solve

## Step 1 — Your starting clues

Two earlier Zenon puzzles had already handed out **eight words**:

```
oblige dilemma hurry disorder happy spoil shiver key
```

A third puzzle asked for the **four missing words** and gave these clues:

```
Quantum computers can't break it.

Never doubt you can make history. You already have.

The key to bitcoin smart contracts is _______

Look for the final piece of the puzzle in block 709.632.
```

The posts also tagged **`#Taproot`**. Hold onto these — the underlined blank (7 letters) and the `#Taproot` hashtag are the key clues later.

> **One important rule:** the puzzle *also* published the final wallet address. We will **not** use that address to find the answer — that would be cheating (working backward from the solution). We use it only at the very end to confirm we got it right.

---

## Step 2 — Get the Bitcoin data *(you can skip this)*

The clue points to Bitcoin block **709,632**:

```
height = 709632
hash   = 0000000000000000000687bca986194dc2c1f949318629b44bb54ec0a94d8244
```

The four strings we need are printed for you in Step 3, so **you can skip straight to Step 3** and still solve the puzzle. This step is only for people who want to prove the strings really come from the blockchain.

If you *do* want to fetch the raw block yourself:

```sh
curl -fsSL \
  https://mempool.space/api/block/0000000000000000000687bca986194dc2c1f949318629b44bb54ec0a94d8244/raw \
  -o block_709632.raw
```

Inside that block, 19 transactions each store one row of ASCII art (using Bitcoin's `OP_RETURN` feature, which lets you attach a bit of text to a transaction). Read in the right order, the rows draw the Zenon logo:

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
   ... (more logo rows) ...
```

Notice the four rows that aren't just `z`'s and punctuation — those hold the real data.

---

## Step 3 — Find the four hidden strings

Buried in the artwork are **four strings** that use the Base64 alphabet (letters, numbers, `+`, `/`, and `=`). Three of them end in `=` or `==`, which is a dead giveaway that they're complete Base64 objects:

```
BynQtpeUyWTXKGTrGhdV2Q==
tVMd3L1CKM4wFmyxEEEUV2bY
4Fdzw1k=
vtv3f5aKY0jGQglP9a1AGw==
```

**The one tricky bit:** the second and third strings actually belong together as a single string:

```
tVMd3L1CKM4wFmyxEEEUV2bY4Fdzw1k=
```

Why join them? Base64 lets you read them either way, so this isn't obvious yet. But in Step 7 the decryption will only succeed if they're joined — that's how we *know* it's the right reading. For now, just treat them as **three** strings:

| Part | String |
|---|---|
| 1 | `BynQtpeUyWTXKGTrGhdV2Q==` |
| 2 | `tVMd3L1CKM4wFmyxEEEUV2bY4Fdzw1k=` |
| 3 | `vtv3f5aKY0jGQglP9a1AGw==` |

---

## Step 4 — Decode them into raw bytes

**Base64** is just a way of writing raw binary data using printable characters. Let's turn each string back into its actual bytes:

```sh
python3 - <<'PY'
import base64

parts = [
    "BynQtpeUyWTXKGTrGhdV2Q==",
    "tVMd3L1CKM4wFmyxEEEUV2bY" + "4Fdzw1k=",
    "vtv3f5aKY0jGQglP9a1AGw==",
]
for p in parts:
    raw = base64.b64decode(p, validate=True)
    print(len(raw), "bytes:", raw.hex())
PY
```

You'll get:

```
16 bytes: 0729d0b69794c964d72864eb1a1755d9
23 bytes: b5531ddcbd4228ce30166cb11041145766d8e05773c359
16 bytes: bedbf77f968a6348c642094ff5ad401b
```

So we have **16, 23, and 16 bytes** — 55 bytes total. Remember that `16 / 23 / 16` shape.

---

## Step 5 — Recognize the encryption "envelope"

Those three sizes aren't random. They exactly match a common encryption format called **AES-GCM**, which packages an encrypted message in three parts:

```
16-byte nonce  │  23-byte ciphertext  │  16-byte authentication tag
```

In plain terms:

- **Nonce** — a one-time random-looking starter value (16 bytes here).
- **Ciphertext** — the actual scrambled message. In AES-GCM the ciphertext is *the same length as the original text*, so 23 bytes of ciphertext means 23 characters of hidden text — a perfect fit for four short English words with spaces.
- **Authentication tag** — a 16-byte "seal" that only verifies if you used the exact right key and settings. This is the part that makes the puzzle *provable*: guess wrong and the seal breaks.

Every one of our 55 bytes is accounted for, with nothing left over. That's a strong hint we're on the right track.

---

## Step 6 — Build the key from the word "Taproot"

Look back at the clues:

- *"The key to bitcoin smart contracts is `_______`"* — seven blanks.
- The data lives in Bitcoin's **Taproot** activation block.
- The posts used **`#Taproot`**.

**`Taproot`** has exactly seven letters. That's our key word.

But an encryption key needs to be a specific length (AES-256 needs 32 bytes), and `Taproot` is only 7 characters. The standard way to turn any text into a fixed-size key is to run it through a **hash function** called SHA-256:

```sh
python3 -c 'import hashlib; print(hashlib.sha256(b"Taproot").hexdigest())'
```

Result:

```
e943f7ddcf9ae051d98b9143365193ae8e60b8ffac522ff78f61cb7c3d1b9203
```

(Why SHA-256? The *"quantum computers can't break it"* clue points to a strong, 256-bit design — exactly what SHA-256 → AES-256 gives you.)

Note the capital **T** — capitalization matters, and Step 7 proves it must be `Taproot`, not `taproot`.

---

## Step 7 — Decrypt → the four missing words 🎉

This is the moment of truth. We feed the nonce, ciphertext, tag, and key into AES-GCM. If everything is right, the authentication tag verifies and we get plaintext. If anything is wrong, it errors out.

```sh
python3 - <<'PY'
import base64, hashlib
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.exceptions import InvalidTag

nonce      = base64.b64decode("BynQtpeUyWTXKGTrGhdV2Q==")
ciphertext = base64.b64decode("tVMd3L1CKM4wFmyxEEEUV2bY" + "4Fdzw1k=")
tag        = base64.b64decode("vtv3f5aKY0jGQglP9a1AGw==")
key        = hashlib.sha256(b"Taproot").digest()

# Decrypt. If the tag doesn't verify, this raises an error.
plaintext = AESGCM(key).decrypt(nonce, ciphertext + tag, None)
print("THE FOUR WORDS:", plaintext.decode("ascii"))

# Proof the key is exactly right: the wrong capitalization must FAIL.
try:
    AESGCM(hashlib.sha256(b"taproot").digest()).decrypt(nonce, ciphertext + tag, None)
    print("(this should never print)")
except InvalidTag:
    print("Check passed: lowercase 'taproot' is correctly rejected.")
PY
```

Output:

```
THE FOUR WORDS: wall nation drive smoke
Check passed: lowercase 'taproot' is correctly rejected.
```

**`wall nation drive smoke`** — there they are.

This is what makes the solve airtight: only the exact right key, capitalization, nonce, byte-split, and format make the 16-byte tag verify. Everything else fails. We never looked at the answer; the math confirmed it.

---

## Step 8 — Assemble the 12-word seed phrase

Now stick the four words onto the eight from earlier:

```
oblige dilemma hurry disorder happy spoil shiver key wall nation drive smoke
```

This is a **BIP39 seed phrase** — the 12-word standard used by crypto wallets. BIP39 phrases have a built-in **checksum** (a self-consistency check), so we can confirm these 12 words form a valid phrase:

```sh
python3 - <<'PY'
import hashlib
# Position of each word in the official BIP39 English word list:
indexes = [1217, 497, 893, 507, 839, 1682, 1585, 976, 1973, 1178, 538, 1638]
bits = "".join(f"{i:011b}" for i in indexes)      # 132 bits total
entropy  = int(bits[:128], 2).to_bytes(16, "big") # first 128 bits
checksum = bits[128:]                              # last 4 bits
expected = f"{hashlib.sha256(entropy).digest()[0] >> 4:04b}"
print("Checksum in phrase:", checksum, "| expected:", expected,
      "->", "VALID" if checksum == expected else "INVALID")
PY
```

Output:

```
Checksum in phrase: 0110 | expected: 0110 -> VALID
```

A valid checksum means these really are a legitimate, complete seed phrase — not just twelve random words.

---

## Step 9 — Turn the seed phrase into the Zenon address

Finally, we run the seed phrase through Zenon's standard wallet math to get an address, then check it against the one the puzzle published.

The recipe Zenon uses:
1. Turn the 12 words into a 64-byte seed.
2. Walk a specific derivation path (`m/44'/73404'/0'`) using Ed25519.
3. Hash the resulting public key with SHA3-256.
4. Format it as a Bech32 address starting with `z`.

Here's the full, self-contained code:

```sh
python3 - <<'PY'
import hashlib, hmac
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives import serialization

mnemonic = "oblige dilemma hurry disorder happy spoil shiver key wall nation drive smoke"

# 1) Seed phrase -> 64-byte seed
seed = hashlib.pbkdf2_hmac("sha512", mnemonic.encode(), b"mnemonic", 2048)

# 2) Derive the key along m/44'/73404'/0' (Ed25519 / SLIP-0010, all-hardened)
def master(seed):
    I = hmac.new(b"ed25519 seed", seed, hashlib.sha512).digest()
    return I[:32], I[32:]
def child(key, cc, index):
    data = b"\x00" + key + (index | 0x80000000).to_bytes(4, "big")
    I = hmac.new(cc, data, hashlib.sha512).digest()
    return I[:32], I[32:]
key, cc = master(seed)
for i in (44, 73404, 0):
    key, cc = child(key, cc, i)

# 3) Public key -> SHA3-256 -> address payload (0x00 + first 19 bytes)
pub = Ed25519PrivateKey.from_private_bytes(key).public_key().public_bytes(
    serialization.Encoding.Raw, serialization.PublicFormat.Raw)
core = b"\x00" + hashlib.sha3_256(pub).digest()[:19]

# 4) Encode as a Bech32 address with prefix "z"
CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"
def polymod(v):
    GEN = [0x3b6a57b2,0x26508e6d,0x1ea119fa,0x3d4233dd,0x2a1462b3]; chk = 1
    for x in v:
        b = chk >> 25; chk = ((chk & 0x1ffffff) << 5) ^ x
        for i in range(5): chk ^= GEN[i] if (b >> i) & 1 else 0
    return chk
def convertbits(data):
    acc = bits = 0; out = []
    for byte in data:
        acc = (acc << 8) | byte; bits += 8
        while bits >= 5:
            bits -= 5; out.append((acc >> bits) & 31)
    if bits: out.append((acc << (5 - bits)) & 31)
    return out
data = convertbits(core)
values = [ord(c) >> 5 for c in "z"] + [0] + [ord(c) & 31 for c in "z"] + data
pm = polymod(values + [0]*6) ^ 1
checksum = [(pm >> 5*(5-i)) & 31 for i in range(6)]
address = "z1" + "".join(CHARSET[d] for d in data + checksum)

print("Derived address:", address)
print("Puzzle address :", "z1qrn3jeapt848zxg3akf2ewhrxxwsa945sj798s")
print("MATCH!" if address == "z1qrn3jeapt848zxg3akf2ewhrxxwsa945sj798s" else "no match")
PY
```

Output:

```
Derived address: z1qrn3jeapt848zxg3akf2ewhrxxwsa945sj798s
Puzzle address : z1qrn3jeapt848zxg3akf2ewhrxxwsa945sj798s
MATCH!
```

**Solved.** The four words you decrypted, added to the earlier eight, derive exactly the address the puzzle published — and you got there without ever using that address as a shortcut.

---

## The all-in-one script

Prefer to run everything at once? Save this as `solve.py` and run `python3 solve.py`. (It's the same code as the steps above, stitched together. Requires `pip install cryptography`.)

```python
import base64, hashlib, hmac
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives import serialization

# --- 1. The three data fields hidden in the Bitcoin artwork ---
nonce      = base64.b64decode("BynQtpeUyWTXKGTrGhdV2Q==")
ciphertext = base64.b64decode("tVMd3L1CKM4wFmyxEEEUV2bY" + "4Fdzw1k=")
tag        = base64.b64decode("vtv3f5aKY0jGQglP9a1AGw==")
print(f"Fields decode to {len(nonce)}/{len(ciphertext)}/{len(tag)} bytes")

# --- 2. Key = SHA-256 of the clue word "Taproot" ---
key = hashlib.sha256(b"Taproot").digest()

# --- 3. Decrypt with AES-256-GCM (the tag must verify) ---
words = AESGCM(key).decrypt(nonce, ciphertext + tag, None).decode("ascii")
print("Decrypted words:", words)

# --- 4. Complete the 12-word BIP39 seed phrase ---
mnemonic = "oblige dilemma hurry disorder happy spoil shiver key " + words
print("Seed phrase:", mnemonic)

# --- 5. Derive the Zenon address and confirm the match ---
seed = hashlib.pbkdf2_hmac("sha512", mnemonic.encode(), b"mnemonic", 2048)
k, cc = (lambda I: (I[:32], I[32:]))(hmac.new(b"ed25519 seed", seed, hashlib.sha512).digest())
for i in (44, 73404, 0):
    I = hmac.new(cc, b"\x00" + k + (i | 0x80000000).to_bytes(4, "big"), hashlib.sha512).digest()
    k, cc = I[:32], I[32:]
pub = Ed25519PrivateKey.from_private_bytes(k).public_key().public_bytes(
    serialization.Encoding.Raw, serialization.PublicFormat.Raw)
core = b"\x00" + hashlib.sha3_256(pub).digest()[:19]

CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"
def polymod(v):
    GEN = [0x3b6a57b2,0x26508e6d,0x1ea119fa,0x3d4233dd,0x2a1462b3]; chk = 1
    for x in v:
        b = chk >> 25; chk = ((chk & 0x1ffffff) << 5) ^ x
        for j in range(5): chk ^= GEN[j] if (b >> j) & 1 else 0
    return chk
acc = bits = 0; data = []
for byte in core:
    acc = (acc << 8) | byte; bits += 8
    while bits >= 5:
        bits -= 5; data.append((acc >> bits) & 31)
if bits: data.append((acc << (5 - bits)) & 31)
vals = [ord("z") >> 5, 0, ord("z") & 31] + data
pm = polymod(vals + [0]*6) ^ 1
address = "z1" + "".join(CHARSET[d] for d in data + [(pm >> 5*(5-i)) & 31 for i in range(6)])

print("Zenon address:", address)
assert address == "z1qrn3jeapt848zxg3akf2ewhrxxwsa945sj798s", "mismatch!"
print("VERIFIED — puzzle solved.")
```

Expected output:

```
Fields decode to 16/23/16 bytes
Decrypted words: wall nation drive smoke
Seed phrase: oblige dilemma hurry disorder happy spoil shiver key wall nation drive smoke
Zenon address: z1qrn3jeapt848zxg3akf2ewhrxxwsa945sj798s
VERIFIED — puzzle solved.
```

---

## How to know you did it right

Compare your outputs against these known-good values:

| Checkpoint | Correct value |
|---|---|
| Three field sizes | `16 / 23 / 16` bytes |
| Key `SHA-256("Taproot")` | `e943f7ddcf9ae051d98b9143365193ae8e60b8ffac522ff78f61cb7c3d1b9203` |
| Decrypted words | `wall nation drive smoke` |
| BIP39 checksum | valid (`0110`) |
| Final address | `z1qrn3jeapt848zxg3akf2ewhrxxwsa945sj798s` |

If all five match, you've reproduced the solve exactly.

---

# Part 2 — A debated "hidden message" (optional, not proven)

Some solvers believe the *same 55 bytes* also spell out a second, hidden sentence:

> **ART IS ABSTRACT BY NATURE**

The idea is that the four data fields' lengths, the leftover bits when you read them as word-list indexes, and the address prefixes can be combined to spell this out. It's a neat theory, and a few of its pieces are genuinely striking (for example, both the Bitcoin and Zenon addresses begin with characters that decode to the word "abstract").

**But treat this as speculation, not fact.** Unlike the four words — which are locked in by cryptographic proof (the tag either verifies or it doesn't) — this sentence has *no* such proof. It's assembled by making several judgment calls about how to read each piece, and reasonable people disagree about whether the author intended it or whether it's a pattern found after the fact. The four words are the real, verifiable answer; the sentence is an interesting maybe.

If you want to explore it, the original technical write-up walks through the full extraction. Just keep the distinction in mind: **Part 1 is proven, Part 2 is a hypothesis.**

---

## Mini-glossary

- **Base64** — a way to write raw binary data using ordinary keyboard characters. The trailing `=` signs are padding.
- **AES-GCM** — a standard encryption method that both scrambles a message *and* includes a "tag" proving it wasn't tampered with and the key was correct.
- **Nonce** — a one-time value used alongside the key so the same message doesn't always encrypt the same way.
- **Authentication tag** — the 16-byte "seal" in AES-GCM. It only verifies with the exact right key/settings, which is what makes this puzzle provable.
- **BIP39 seed phrase** — the 12- or 24-word human-readable format for a crypto wallet key. Includes a checksum so typos are caught.
- **Bech32** — the address format Zenon uses (the `z1...` string). Bitcoin uses the same format for `bc1...` addresses.
- **OP_RETURN** — a Bitcoin transaction feature that lets you attach a small piece of arbitrary text (here, one row of the logo).
- **Hash (SHA-256 / SHA3-256)** — a one-way function that turns any input into a fixed-size fingerprint. Used here to turn "Taproot" into a key and to build the address.

---

## Why go to all this trouble?

The 19-transaction machinery isn't required by the encryption — it's a flourish that serves three purposes:

1. **A permanent, ordered inscription** of the Zenon logo, baked into Bitcoin forever.
2. **Precise timing** — the creators paid extra fees to land the artwork in the *exact* Taproot activation block, giving real meaning to the clue *"you can make history."*
3. **Cross-chain signature** — the final transaction literally says `ZENON NETWORK`, and both the Bitcoin and Zenon addresses were crafted to start with the same visible characters.

In other words: a Zenon monument, deliberately placed inside a landmark moment of Bitcoin's history — with a real, solvable reward tucked inside.

---

*The four-word answer in this guide is verified by cryptographic proof. Blockchain data referenced (block 709,632 and its transactions) can be independently inspected on any Bitcoin block explorer.*
