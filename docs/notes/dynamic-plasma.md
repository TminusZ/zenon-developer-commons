Dynamic Plasma: Adaptive Resource Scaling (Draft)

Dynamic Plasma (DP) refers to an adaptive mechanism for regulating resource consumption in Zenon’s dual-ledger architecture.
This draft outlines why a static plasma model is insufficient, how adaptive scaling could operate, and how it interacts with account-chains, zApps, and future protocol extensions.
It is a research framing, not a finalized specification.

⸻

1. Purpose of Dynamic Plasma

Static plasma costs assume a stable, uniform workload. Zenon is designed for heterogeneous and evolving usage patterns, including lightweight browser clients, zApps with variable data footprints, and potential cross-chain commitments.

Dynamic Plasma introduces an adaptive mechanism intended to:

• Regulate long-term database growth
• Stabilize throughput across heterogeneous workloads
• Protect Pillars and Sentinels from overload
• Adjust resource constraints without introducing economic fees
• Preserve a feeless user experience while enforcing physical limits

In essence, DP replaces pricing mechanisms with adaptive computational constraints.

⸻

2. Motivation for a Dynamic Model

A fixed plasma cost per byte becomes insufficient as the system scales.
Growth will arise from:

• Expansion of the account-chain ecosystem
• Increased zApp complexity and usage
• Cross-chain proof anchoring
• Utilization of the Momentum Data field for protocol extensions
• Higher activity from browser-based nodes

An adaptive mechanism allows the protocol to adjust plasma difficulty in response to state growth, analogous to how Bitcoin adjusts PoW difficulty relative to hashrate—but here the regulation target is storage growth rather than computational throughput.

⸻

3. Resource Dimensions Affected by DP

A practical DP framework would regulate several dimensions of resource usage:

• Database growth rate to maintain predictable node requirements
• Account-block size distribution to ensure large transitions remain possible but appropriately constrained
• Global transition volume to protect consensus nodes
• Proof and commitment sizes especially for cross-chain or multi-party operations

DP operates on aggregate behavior rather than on a per-transaction fee basis.

⸻

4. Conceptual Model for Dynamic Plasma Adjustment

One conceptual, non-binding model:
	1.	Define a target for daily database growth
(e.g., ≈13.68 MB/day corresponding to a 5 GB/year limit).
	2.	Measure the actual state delta applied through each day’s Momentums.
	3.	If observed growth exceeds the target, increase plasma difficulty.
	4.	If observed growth falls below the target, decrease plasma difficulty.
	5.	Apply adjustments gradually to avoid oscillatory behavior.
	6.	Allow Sentries and zApps to adapt automatically, as plasma calculation is local and deterministic.

This model is intended only as a structural reference point.

⸻

5. Compatibility With the Account-Chain Architecture

Zenon’s per-user account-chain model decouples global execution from local state evolution.
As a result:

• Individual growth is sequential and predictable
• Independent users generate parallel, isolated footprints
• Pillars validate only frontier deltas, not full histories

Dynamic Plasma can scale per-user resource use without imposing global burdens on validation.

⸻

6. Interaction With zApps

zApps introduce additional variability, including:

• Larger or irregular commitments
• Bundled multi-message interactions
• Cross-chain or proof-heavy operations

DP provides bounded elasticity:

• Large commitments remain possible
• Small commitments remain inexpensive
• The system remains protected from pathological usage
• No fee auction emerges, preserving UX

⸻

7. Comparison With Fee Markets

Dynamic Plasma is fundamentally distinct from fee markets:

• No entity receives payment
• No competitive bidding or gas auction occurs
• Users do not compete for blockspace
• Priority ordering is not economically determined

Plasma adjustments are protocol-level constraints rather than economic incentives.
DP extends the feeless model while still enforcing systemic limits.

⸻

8. Implications for Light Clients and SPV

DP does not meaningfully alter light-client verification because:

• Plasma difficulty does not modify the verification rules
• Light clients depend on headers and state commitments, not plasma cost
• Sentries still construct transitions deterministically
• The SPV model remains unchanged

DP influences production, not verification.

⸻

9. Open Research Questions

Key unresolved questions include:

• Optimal adjustment interval (per-Momentum, daily, or rolling window)
• Whether adjustments should be global, per-account, or per-transition-type
• Sensitivity to short-lived spikes in activity or data growth
• Whether large proofs (e.g., zk commitments) should be governed separately
• How DP interacts with extended use of Momentum Data
• Whether Pillars should expose telemetry to assist browser nodes

These questions define the main research surface for DP.

⸻

10. Summary

Dynamic Plasma aligns naturally with Zenon’s architecture:

• Account-chains isolate state evolution
• Pillars commit deterministic state deltas
• Sentinels enforce structural validity rather than economic pricing
• Sentries compute plasma locally and deterministically
• Light clients rely on headers rather than execution traces

An adaptive plasma model supports long-term scalability without introducing fees, maintaining the system’s lightweight and browser-native design philosophy.
