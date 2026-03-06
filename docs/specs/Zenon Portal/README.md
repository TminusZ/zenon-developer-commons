# Zenon Portal Protocol Specification (v1.5)

This document contains the **Zenon Portal protocol specification**, a research design for a Bitcoin–Zenon interoperability mechanism.

Zenon Portal proposes a model where **Bitcoin remains in native custody on the Bitcoin blockchain**, while Zenon maintains a receipt ledger (**eBTC**) representing claims on those escrowed Bitcoin funds.

Deposits are verified using **Simplified Payment Verification (SPV)** and withdrawals are executed cooperatively by a **threshold relayer system**.

The goal of the design is to separate **custody (Bitcoin)** from **execution (Zenon)** while reducing reliance on trusted custodians.

---

## Current Version

**Specification:** Zenon Portal v1.5
**Status:** Research / design specification

The architecture described in v1.5 is considered **design-stable**, but the protocol has **not yet been implemented or audited**.

Future work includes:

* reference implementation
* interoperability testing
* security audit
* slashing activation
* economic stress testing

---

## Escrow Classes

The protocol defines two deposit escrow classes selected by the user.

### Class R — Refund Protected

* Cooperative withdrawal requires depositor co-signature.
* Relayers cannot unilaterally spend the escrow.
* A Bitcoin-native refund becomes available after the timelock expires.

### Class P — Pool Liquidity

* Relayers control the key-path spend for pooled withdrawals.
* Allows non-interactive withdrawals and batching.

Tradeoff:

* The unilateral refund path becomes time-limited.
* Security depends on the relayer threshold honesty assumption.

Class P is **disabled by default** until the enforcement stack is activated.

---

## Security Model

Zenon Portal is **trust-reduced, not trustless**.

The dominant trust assumption is that **fewer than the relayer threshold `t` collude to steal funds**.

Class R deposits provide stronger depositor safety guarantees than Class P deposits.

All trust assumptions and failure modes are described in the specification.

---

## Disclaimer

This document is part of a **research repository** and does not represent production software.

The protocol has **not been audited** and should not be used with real funds without extensive review and testing.

---

## Location in Repository

The full specification is contained in:

```
zenon-portal-spec-v1.5.md
```

Older design revisions and analysis documents may also exist in this repository as part of the research history.

---

## License

MIT License
