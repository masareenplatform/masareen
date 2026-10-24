# INVENTION DISCLOSURE FORM (IDF)

**ID:** IDF-002
**Title:** Impact Score Algorithm (ISA), Multi-Dimensional Scoring Engine for Quantifying Real-World Impact
**Date:** August 11, 2026
**Classification:** CONFIDENTIAL, PROPRIETARY
**Status:** 🔴 Draft

---

## 1. SUMMARY

The Impact Score Algorithm (ISA) is a multi-dimensional scoring engine that quantifies the measurable real-world impact of verified field actions. The algorithm operates on verified evidence ingested through the Verification-to-Asset Pipeline (IDF-001) and produces a normalized, comparable impact score that drives digital asset value assignment, organizational ranking, and marketplace pricing.

ISA combines domain-specific impact models, temporal decay functions, geographic weighting, demographic adjustment, and cross-actor normalization to produce a single, comparable impact score. Unlike traditional scoring systems that use static weighting, ISA dynamically adjusts weights based on a continuous learning model trained on outcome data, ensuring that impact scores converge toward actual real-world outcomes over time.

---

## 2. TECHNICAL FIELD

This invention relates to algorithmic impact measurement, machine learning, and scoring systems. More specifically, it relates to a method and system for:

- Computing multi-dimensional impact scores for real-world actions
- Normalizing impact across heterogeneous action types (environmental, social, educational, economic)
- Dynamically adjusting impact weights based on outcome feedback
- Applying geographic, temporal, and demographic adjustments to raw impact metrics
- Producing comparable scores suitable for digital asset value assignment

---

## 3. PROBLEM STATEMENT

Existing impact measurement systems suffer from:

1. **Non-comparability:** Different action types (tree planting vs. education hours) cannot be meaningfully compared.
2. **Static Weighting:** Weights are set manually and never updated based on actual outcomes.
3. **No Temporal Adjustment:** Impacts decay over time, but no system accounts for this.
4. **Geographic Blindness:** The value of an action depends on where it occurs, but systems don't adjust for this.
5. **No Feedback Loop:** Scores are never revised when actual outcomes differ from projections.

---

## 4. PRIOR ART CONSIDERATIONS

See PAR-002 for detailed analysis. Key prior art includes ESG scoring frameworks (MSCI, Sustainalytics), carbon credit standards (Verra, Gold Standard), and social impact measurement tools (IRIS+). None of these systems incorporate:

- Dynamic weight adjustment through outcome feedback
- Cross-domain normalization to a single comparable score
- Integration with real-world evidence verification pipelines
- Blockchain asset value mapping

---

## 5. DETAILED DESCRIPTION

### 5.1 Core Formula

The Impact Score for an action `a` is computed as:

```
I(a) = Σ(w_d(i) × R_d(i) × T_d(t_deadline)) × G_d(location) × C_d(time) × N(actor_history)

where:
  w_d(i)      = domain weight for metric i (learnable parameter)
  R_d(i)      = raw metric value for domain d, metric i
  T_d(t)      = temporal decay function for deadline t
  G_d(location) = geographic adjustment factor
  C_d(time)   = temporal context adjustment
  N(actor_history) = actor normalization factor
  i           = sum over all metrics in domain d
```

### 5.2 Domain Models

ISA defines 6 domains:

1. **Environmental (ENV):** CO2 sequestered, biodiversity impact, water saved, soil health
2. **Social (SOC):** People reached, hours contributed, lives improved, inequality reduction
3. **Economic (ECO):** Income generated, local GDP contribution, employment created
4. **Governance (GOV):** Transparency points, policy adherence, community engagement
5. **Educational (EDU):** Literacy hours, students reached, curriculum covered
6. **Infrastructure (INF):** Facilities built, maintenance performed, access provided

Each domain has 3–7 metrics, each with a raw value, a normalization function, and a learnable weight.

### 5.3 Temporal Decay Functions

Different domains decay at different rates:

```
T_env(t) = exp(-λ_env × t)       # λ_env = 0.05 (slow decay)
T_soc(t) = 1.0 - (t / T_max)^2   # Quadratic decay
T_gov(t) = sigmoid(k × (t - t_half)) # S-curve transition
```

Where `t` is time elapsed since action completion and `T_max` is the domain's maximum relevance window.

### 5.4 Geographic Weighting

Actions in underserved or high-impact geographic zones receive a multiplier:

```
G_d(location) = 1.0 + β_d × vulnerability_index(location) × urgency_factor(location)
```

- `vulnerability_index`: Based on UN development indicators, climate risk, poverty rates
- `urgency_factor`: Adjusts for time-sensitive impact (e.g., disaster relief)

### 5.5 Actor Normalization

New actors receive a higher score multiplier to encourage participation, which converges to 1.0 over 50 verified actions:

```
N(actor_history) = 1.0 + (0.5 × e^(-verified_actions / 50))
```

### 5.6 Learning Layer

ISA includes a reinforcement learning component that adjusts domain weights every 24 hours based on outcome feedback:

- **Reward signal:** Difference between projected and actual outcome (from audit, sensor data, or third-party verification)
- **Update rule:** Gradient-based weight update with L2 regularization
- **Constraints:** Weights are constrained to sum to 1.0 per domain

### 5.7 Output Score

The final ISA score is normalized to a 0–1000 scale:

```
ISA_final = (I(a) - I_min) / (I_max - I_min) × 1000
```

Where `I_min` and `I_max` are computed from the global distribution of all scores in the last 30 days.

### 5.8 Digital Asset Mapping

The ISA score maps directly to digital asset value:

- ISA ≥ 800 → MIA token value = 1.0 × base_rate
- ISA 500–799 → MIA token value = 0.5 × base_rate
- ISA 200–499 → MIA token value = 0.1 × base_rate
- ISA < 200 → No asset minted

---

## 6. INVENTOR(S)

| Name | Affiliation | Contribution |
|------|------------|--------------|
| [ML Lead] | MASAREN | Algorithm design, learning layer implementation |
| [Data Scientist] | MASAREN | Domain model calibration, statistical validation |
| [Backend Engineer] | MASAREN | System integration, event processing |

---

## 7. COMMERCIAL APPLICATION

- **Impact investing:** Standardized scoring for ESG investment decisions
- **Carbon markets:** Impact-adjusted carbon credit pricing
- **NGO benchmarking:** Cross-organization comparison of impact effectiveness
- **Corporate sustainability:** Internal program ROI measurement
- **Government grants:** Outcome-based funding allocation

---

## 8. ATTACHMENTS

1. Full domain metric catalog (`documents/IDF-002-metrics.csv`)
2. Temporal decay function plots
3. Weight update algorithm pseudocode
4. Geographic vulnerability index computation

---

**Form Completed By:** MASAREN Legal Team
**Date:** August 11, 2026
**IDF Reference:** IDF-002-20260811
**Distribution:** Legal Team, Patent Attorney, CTO, Board IP Committee