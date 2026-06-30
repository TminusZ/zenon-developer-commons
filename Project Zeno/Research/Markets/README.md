# Markets

The documents in this folder explore the market architecture that can emerge around the Project Zeno Domain Settlement Layer.

These documents are Frontier research.

They are not implementation claims.

They do not introduce protocol features, tokenomics, governance decisions, or deployment commitments.

They examine how independent market infrastructure can compose with Settlement while remaining completely outside of it.

SPEC.md remains the governing authority for all on-chain protocol behavior.

⸻

Purpose

The interoperability architecture explains how deterministic truth moves across execution environments.

This folder explores what happens after truth exists.

Questions addressed here include:

* How is value discovered?
* Where does liquidity come from?
* How is capital deployed?
* How are markets structured?
* How can financial infrastructure become modular while remaining independent of Settlement?

These documents describe the economic architecture surrounding the Domain Settlement Layer, not the Settlement Layer itself.

⸻

Architectural principle

The Domain Settlement Layer is deliberately minimal.

Settlement determines:

* Truth
* Finality
* Replay protection
* Conservation
* Deterministic state

Settlement does not determine:

* Prices
* Liquidity
* Credit
* Capital allocation
* Market structure
* Financial products

Those responsibilities belong entirely to market participants and market infrastructure built around Settlement.

⸻

Scope

Research in this folder includes topics such as:

* Market architecture
* Liquidity infrastructure
* Capital deployment
* Credit systems
* Lending
* Market making
* Automated market makers
* RFQ systems
* Order books
* Derivatives
* Stable assets
* Cross-domain liquidity
* Financial service domains

Each document explores one architectural concept in isolation while maintaining the separation between Settlement and markets.

⸻

Relationship to the rest of the research

These documents build upon the interoperability architecture but do not replace or extend it.

They assume the guarantees established by:

* SPEC.md
* Bridge Framework
* Execution Provider Framework
* Intent Framework
* Economic Security Framework
* Service Domain Framework

The market layer consumes Settlement’s finalized truth but never modifies Settlement itself.

⸻

Design philosophy

Project Zeno separates deterministic protocol guarantees from economic behavior.

Settlement determines what is true.

Markets determine what it is worth.

Liquidity determines what is available.

Execution determines what happens.

Keeping those responsibilities independent allows each layer to evolve without increasing protocol complexity.

⸻

Research discipline

Every document in this folder follows the same principles:

* Settlement remains minimal.
* Markets remain external.
* Competition is preferred over protocol authority.
* Services become domains rather than protocol features.
* Economic systems remain modular.
* Failures remain isolated.
* Speculation is explicitly identified.
* SPEC.md governs on any conflict.

The goal of this folder is not to design financial products.

The goal is to understand how a minimal settlement protocol can support an open, programmable, and competitive market ecosystem without compromising its architectural boundaries.
