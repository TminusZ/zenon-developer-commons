# Execution Domain Specification

---

# 1. Overview

The Executor is a deterministic off-chain execution engine responsible for processing one or more execution domains and producing state transitions for Settlement.

Settlement does not execute arbitrary computation. It verifies commitments produced by Executors and enforces protocol-level invariants.

Execution logic is isolated into **Domains**, allowing multiple independent runtimes (e.g. WASM, Bitcoin, Ethereum) to coexist without modifications to Settlement.

```
              Settlement

                   ▲

              Commit(State)

                   ▲

             Executor Runtime

      ┌────────────┼────────────┐

      │            │            │

   WASM        Bitcoin      Ethereum

   Domain       Domain       Domain
```

---

# 2. Design Goals

An Executor implementation MUST satisfy the following goals:

* Deterministic execution
* Replayability
* Runtime isolation
* Domain independence
* Stateless Settlement integration
* Future fraud-proof compatibility

The Executor SHOULD be capable of loading additional execution domains without requiring protocol modifications.

---

# 3. Architecture

The Executor consists of two layers.

## Executor Runtime

The runtime is generic infrastructure.

Responsibilities include:

* lifecycle management
* batching
* checkpoint creation
* witness generation
* settlement communication
* storage
* networking
* fraud-proof interface

The runtime contains no application-specific logic.

---

## Execution Domains

Execution domains define state transition functions.

Each domain determines:

* input source
* execution rules
* state representation
* witness format

Examples include:

```
Domain 1

Input:
Zenon Transactions

Execution:
WASM

Output:
Contract State
```

```
Domain 2

Input:
Bitcoin Blocks

Execution:
Bitcoin Consensus

Output:
Bridge State
```

```
Domain 3

Input:
Ethereum Blocks

Execution:
Ethereum Consensus

Output:
Bridge State
```

Settlement is unaware of runtime-specific behaviour.

---

# 4. Domain Interface

Each execution domain MUST implement a common interface.

```go
type Domain interface {

    // Collect new inputs
    Ingest(ctx Context) error

    // Execute deterministic state transitions
    Execute(ctx Context) error

    // Produce execution witness
    Prove(ctx Context) (Witness, error)

    // Commit results to Settlement
    Commit(ctx Context) error
}
```

These methods are executed sequentially.

```
Ingest

↓

Execute

↓

Prove

↓

Commit
```

---

# 5. Ingest()

The Ingest phase imports external events into the domain.

Examples:

WASM

* user transactions
* contract deployments

Bitcoin

* new headers
* new blocks
* reorg notifications

Ethereum

* finalized blocks
* logs
* receipts

The output of Ingest is a deterministic input queue.

---

# 6. Execute()

Execute applies deterministic state transitions.

The function MUST produce identical results on every Executor given identical inputs.

No external network calls may occur during Execute.

Execution may update:

* domain state
* checkpoints
* pending outputs
* execution receipts

---

# 7. Prove()

Prove generates a deterministic witness describing the transition.

Examples include:

WASM

* transaction list
* gas usage
* state root

Bitcoin

* block headers
* Merkle proofs
* confirmation depth
* transaction inclusion

Ethereum

* receipts
* storage proofs
* state proofs

The witness format is domain specific.

Future fraud proofs operate on witnesses.

---

# 8. Commit()

Commit packages execution results into Settlement batches.

Commit does not perform execution.

It serializes:

* state commitment
* witness commitment
* execution outputs
* metadata

Settlement validates protocol rules before accepting the batch.

---

# 9. Runtime Responsibilities

The Executor Runtime provides shared services.

These include:

```
Storage

Networking

Checkpointing

Batching

Witness Encoding

Settlement Client

Metrics

Logging

Configuration
```

These services are shared across all domains.

---

# 10. Domain Isolation

Domains MUST NOT directly communicate.

Instead they communicate asynchronously through Settlement.

```
Bitcoin

↓

Settlement

↓

WASM
```

This guarantees deterministic ordering.

---

# 11. Domain Registration

Each domain registers itself during Executor initialization.

Example:

```go
executor.Register(
    wasm.New()
)

executor.Register(
    bitcoin.New()
)
```

The runtime discovers available domains automatically.

---

# 12. Future Domains

The Executor is intended to support arbitrary deterministic execution environments.

Potential domains include:

* WASM
* Bitcoin
* Ethereum
* Solana
* Oracle Networks
* zkVMs
* AI Inference
* External APIs (where deterministically verifiable)

No protocol modifications are required to introduce additional domains.

---

## One additional abstraction I would introduce

There's one concept I think would make the implementation exceptionally clean: split the runtime into **Domain** and **Adapter**.

```go
type Domain interface {
    Ingest(Context) error
    Execute(Context) error
    Prove(Context) (Witness, error)
}

type Adapter interface {
    Commit(Context, Witness) error
}
```

The domain's sole responsibility is to deterministically answer the question:

> "Given these inputs, what is the new state and how can I prove it?"

The adapter's responsibility is:

> "How do I package that result for Zenon Settlement?"

That separation means you could run the exact same Bitcoin domain in a standalone application, another blockchain, or a local simulator simply by swapping the adapter. It also keeps every domain completely unaware of Settlement, which reinforces the architectural principle that **Settlement is a consumer of deterministic state transitions, not a dependency of the execution environment**.

Personally, I think this is the abstraction that elevates your design from "an L2 with plugins" to **a generic deterministic execution framework**. Every new domain becomes just another implementation of the same execution lifecycle, while the executor runtime remains almost entirely unchanged. I suspect that once this abstraction is in place, adding a new domain like Bitcoin, Ethereum, or a zkVM could be measured in hundreds of lines of integration code rather than thousands.
