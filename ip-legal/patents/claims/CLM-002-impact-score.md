# PATENT CLAIMS, DRAFT

**CLM-002** | **Related IDF:** IDF-002
**Title:** Claims for the Impact Score Algorithm (ISA)
**Status:** 🔴 Draft (Pre-Attorney Review)

---

## CLAIMS

### Independent Claim 1
> A non-transitory computer-readable medium storing instructions that, when executed by one or more processors, cause the processors to perform a method for computing a multi-dimensional impact score for a verified real-world action, the method comprising:
>
> receiving a plurality of impact metrics for the verified real-world action, the plurality of impact metrics spanning at least two impact domains selected from the group consisting of: environmental, social, economic, governance, educational, and infrastructure;
>
> applying, to each impact metric, a domain-specific normalization function and a learnable domain weight, producing a weighted normalized metric;
>
> applying a temporal decay function to each weighted normalized metric, the temporal decay function being domain-specific and configured to reduce the metric's contribution over time;
>
> applying a geographic adjustment factor based on a vulnerability index and urgency factor associated with the location where the real-world action occurred;
>
> applying an actor normalization factor that adjusts the impact score based on the actor's historical number of verified actions;
>
> computing a cross-modal consistency score between the plurality of impact metrics;
>
> computing an aggregate impact score as a function of the temporally-decayed, geographically-adjusted, actor-normalized weighted normalized metrics and the cross-modal consistency score;
>
> and normalizing the aggregate impact score to a predetermined scale.

### Dependent Claim 2
> The method of claim 1, wherein the temporal decay function for the environmental domain is an exponential decay function `T_env(t) = exp(-λ_env × t)`, and the temporal decay function for the governance domain is a sigmoid function `T_gov(t) = sigmoid(k × (t - t_half))`.

### Dependent Claim 3
> The method of claim 1, further comprising updating the learnable domain weights using a reinforcement learning process, wherein the update is based on a reward signal computed as the difference between projected impact metrics and actual outcome metrics received from audit data or sensor feedback.

### Dependent Claim 4
> The method of claim 1, wherein the geographic adjustment factor is computed as `G_d(location) = 1.0 + β_d × vulnerability_index(location) × urgency_factor(location)`, where `β_d` is a domain-specific coefficient, `vulnerability_index` is derived from UN development indicators and climate risk data, and `urgency_factor` adjusts for time-sensitive impact types.

### Dependent Claim 5
> The method of claim 1, wherein the actor normalization factor is computed as `N(actor_history) = 1.0 + (0.5 × e^(-verified_actions / 50))`, providing a higher score multiplier for new actors to incentivize participation, converging to 1.0 over 50 verified actions.

### Dependent Claim 6
> The method of claim 1, wherein the cross-modal consistency score is computed as `tanh(|R_env - R_soc| + |R_env - R_eco| + |R_soc - R_eco|)`, penalizing cases where impact metrics across domains are inconsistent with each other.

### Dependent Claim 7
> The method of claim 1, further comprising mapping the normalized impact score to a digital asset value multiplier, wherein an impact score above a first threshold produces a full-value asset, an impact score between the first and second thresholds produces a half-value asset, and an impact score below the second threshold produces no asset.

### Dependent Claim 8
> The method of claim 1, further comprising: storing computed impact scores in a distributed event store alongside the original evidence and verification results, enabling full audit trail reconstruction.

---

## ABSTRACT (for Publication)

A multi-dimensional impact scoring algorithm that quantifies real-world impact of verified actions across six domains (environmental, social, economic, governance, educational, infrastructure). The algorithm combines domain-specific normalization, temporal decay, geographic weighting, actor normalization, and cross-modal consistency into a single comparable score. Learnable weights are updated via reinforcement learning based on outcome feedback. The score maps directly to digital asset value in a blockchain-backed impact economy.

---

## DRAWINGS SUMMARY

1. **Fig. 1:** Domain model architecture showing the 6 impact domains and their metric relationships
2. **Fig. 2:** Temporal decay function graph for different domains
3. **Fig. 3:** Weight update reinforcement learning loop
4. **Fig. 4:** Impact score to digital asset value mapping table

---

**Prepared by:** MASAREN Patent Team
**Date:** August 11, 2026
**Review Status:** 🔴 Pending attorney review and formal claim drafting