# Phase 1 — Implementation Epics

Phase-based implementation plan for the Phase 1 off-chain WASM execution layer
(bonded attestation), derived from `../SPEC.md` (v1.6.0, normative),
`../EXECUTOR.md` (v0.3.0, executor binary), and `../ARCHITECTURE.md` (design
companion). Those documents govern on any conflict — these tickets are the
delivery plan, not a re-specification.

> **Scope note (SPEC v1.6.0).** The spec now carries the generalized bridge
> framework (domain classes, execution/foreign-fact profiles, custody modes,
> `chainBinding`) as first-class schema, but **all of it ships reserved** — Phase 1
> implements only the single active point `(EXECUTION, L1_NATIVE, ATTESTATION,
> NONE, ESCROW, SINGLE)`. These tickets are therefore unchanged in scope; the only
> impact is that the `DomainRecord` storage encoding (Ticket 09) and `RegisterDomain`
> validation (Ticket 11) must carry the new fields and **clamp them to their Phase-1
> defaults** (schema-shaped from day one, so later activation is a spork, not a
> storage migration). `MESSAGING`/`BRIDGE` domains, `MINTED` custody, the profile
> ladders, and OD-1 are all out of Phase 1.

## Two epics

| Epic | Folder | Scope |
|---|---|---|
| **Epic 1 — L1 Settlement** | `epic-1-l1-settlement/` | The spork-gated Settlement embedded contract inside `go-zenon`: domain registry, custody/conservation, executor bond, batch acceptance, deployment state machine, relay/withdrawal, admin/pause. Tickets **08–17**. |
| **Epic 2 — Executor** | `epic-2-executor/` | The standalone off-chain executor binary (separate repo / Go module that pins `go-zenon`): generic runtime, SMT store, serializer, WASM plugin, input pipeline, batch builder, recovery, watcher, DA, system vault contract. Tickets **01–07, 18–21**. |

## Global implementation order

Tickets are numbered with a **single global sequence** that is the build order,
following `SPEC.md` §29 (1A → 1B → 1C). The epic a ticket belongs to is a
grouping label; the number is the order in which work should land.

```
Phase 1A — Executor core, no chain changes        (Epic 2)   01 → 07
Phase 1B — Spork-gated Settlement contract         (Epic 1)   08 → 17
Phase 1C — Wiring, DA, vault, testnet → mainnet    (Epic 2)   18 → 21
```

Rationale (SPEC §29): the executor runtime + conformance suite (1A) has **no
on-chain dependency** and retires the highest-risk item (deterministic
instrumentation) first; the Settlement contract (1B) ships dark on testnet; the
wiring (1C) connects the two and activates the spork. Cross-epic dependencies are
listed per ticket under **Depends on**.

## Ticket format (lean)

Each ticket carries: **Goal**, **SPEC refs**, **Depends on**, **Key work**,
**Code references**, **Acceptance criteria**. Every ticket ends with a tested,
verified, independently-mergeable increment.

## Status legend for code references

- **[EXISTS]** — present in current `go-zenon` source, build against it.
- **[NEW]** — created by this plan.
- **[ARTIFACT]** — a companion file already in `../WASM Spec/` (gas table,
  proof-format, SMT/execution vectors).
