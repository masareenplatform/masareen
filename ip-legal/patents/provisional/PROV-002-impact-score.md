# PROVISIONAL PATENT APPLICATION

**US Provisional No.:** [To be assigned by USPTO]
**Title:** Multi-Dimensional Impact Scoring Algorithm with Dynamic Weight Learning, Geographic Vulnerability Adjustment, and Blockchain Asset Value Mapping
**Cross-Reference to Related Applications:** This application claims the benefit of U.S. Provisional Application No. 63/XXX,XXX filed August 11, 2026.
**Related Disclosures:** IDF-002 (Impact Score Algorithm)
**Related Claims:** CLM-002

---

## FIELD OF THE INVENTION

The present invention relates to algorithmic impact measurement, machine learning, and digital asset valuation. More particularly, this invention relates to a multi-dimensional scoring algorithm that quantifies the real-world impact of verified actions across multiple domains (environmental, social, economic, governance, educational, infrastructure), dynamically adjusts scoring weights based on outcome feedback, and maps the resulting score to blockchain-backed digital asset values.

---

## BACKGROUND

### Technical Problem

Impact measurement systems today suffer from several fundamental limitations:

1. **Incomparability:** Different types of impact (planting a tree vs. teaching a child to read) cannot be meaningfully compared because each uses its own ad-hoc scoring system.

2. **Static Weights:** Domain weights are set manually by experts and never updated, even when outcomes differ from projections.

3. **No Geographic Adjustment:** The same action (e.g., building a well) has vastly different value depending on where it occurs—a fact that current scoring systems ignore.

4. **No New Actor Incentive:** New participants have no mechanism to bootstrap trust or attract attention in a system dominated by established actors.

5. **No Digital Asset Linkage:** Scores exist in isolation; there is no automatic mapping from measured impact to economic value via digital assets.

### Prior Art

While various systems exist for ESG scoring (MSCI, Sustainalytics, Refinitiv) and social impact measurement (IRIS+, B Impact Assessment), and while some patents cover corporate sustainability scoring (IBM US-9,852,423; Microsoft US-10,546,278; SAP US-10,984,441), none of these systems teach or suggest:

- Multi-domain normalization with learnable weights updated via reinforcement learning
- Geographic vulnerability index integration
- Actor normalization with new-participant incentives
- Cross-domain consistency scoring with inter-metric correlation penalties
- Direct mapping from impact scores to blockchain asset value tiers

---

## SUMMARY OF THE INVENTION

The **Impact Score Algorithm (ISA)** computes a single, normalized, comparable impact score for any verified real-world action by combining signals from 6 impact domains, each with 3–7 metrics, using a formula that is:

**Novel in its combination**, **non-obvious in its execution**, and **unpredictable in its results**.

### Core Formula

```
I(a) = Σ(w_d(i) × R_d(i) × T_d(t_deadline)) × G_d(location) × C_d(time) × N(actor_history)
```

Where:
- `w_d(i)` = learnable domain weight for metric i
- `R_d(i)` = raw metric value for domain d, metric i (after normalization)
- `T_d(t)` = domain-specific temporal decay function
- `G_d(location)` = geographic vulnerability adjustment factor
- `C_d(time)` = temporal context adjustment
- `N(actor_history)` = actor normalization factor (new actor boost)

### Key Inventive Concepts

a) **Domain-Specific Temporal Decay Functions**
- Environmental: Exponential decay `exp(-λ × t)` (slow decay—environmental impact persists)
- Social: Quadratic decay `1 - (t/T_max)²` (social impact fades moderately)
- Governance: Sigmoid `sigmoid(k × (t - t_half))` (sudden policy changes)

b) **Reinforcement Learning Weight Updates**
Weights are updated daily using gradient descent on the reward signal:
```
R = projected_outcome - actual_outcome
w ← w + α × R × ∂(score)/∂w
```
Where the gradient is computed analytically through the scoring formula. This has never been done in impact measurement.

c) **Geographic Vulnerability Adjustment**
```
G_d(location) = 1.0 + β_d × vulnerability_index × urgency_factor
```
The vulnerability index is computed from UN SDG data, climate risk maps, and poverty indicators. The urgency factor adjusts for time-sensitive domains (e.g., disaster relief).

d) **Cross-Domain Consistency Scoring**
When metrics within a domain are inconsistent with each other (e.g., high CO2 but low biodiversity score for a tree planting action), a penalty factor is applied:
```
P = tanh(Σ|metric_i - mean| / std)
I_adjusted = I × (1 - γ × P)
```

e) **Actor Normalization with New-Participant Boost**
```
N = 1.0 + 0.5 × exp(-verified_actions / 50)
```
This gives new actors a 1.5x score boost that converges to 1.0 over 50 verified actions, solving the "cold start" problem.

f) **Impact Score → Asset Value Mapping**
The final normalized score maps directly to blockchain asset value:
- 800+ → 1.0× base rate (full asset)
- 500–799 → 0.5× base rate (half asset)
- 200–499 → 0.1× base rate (fractional asset)
- <200 → No asset minted

---

## BRIEF DESCRIPTION OF THE DRAWINGS

**Fig. 1.** Domain model architecture. Six domains (ENV, SOC, ECO, GOV, EDU, INF), each with 3–7 metrics, weights, and adjustment factors.

**Fig. 2.** Temporal decay functions plotted for each domain, showing different decay rates.

**Fig. 3.** Reinforcement learning weight update loop: outcome feedback → reward computation → gradient update.

**Fig. 4.** Impact score to asset value mapping chart showing tier thresholds.

---

## DETAILED DESCRIPTION

### 6.1 Domain Definitions

#### Environmental (ENV)
| Metric | Unit | Normalization | Weight (initial) |
|--------|------|--------------|-----------------|
| CO2 sequestered | kg | log(1 + value) | 0.35 |
| Biodiversity score | 0–1 | as-is | 0.25 |
| Water saved | liters | value / 1000 | 0.20 |
| Soil health index | 0–1 | as-is | 0.20 |

#### Social (SOC)
| Metric | Unit | Normalization | Weight (initial) |
|--------|------|--------------|-----------------|
| People reached | count | value / 1000 | 0.30 |
| Hours contributed | hours | value / 40 | 0.25 |
| Lives improved | count | value / 50 | 0.25 |
| Inequality reduction | Gini coeff delta | abs(value) | 0.20 |

#### Economic (ECO)
| Metric | Unit | Normalization | Weight (initial) |
|--------|------|--------------|-----------------|
| Local GDP impact | USD | log(1 + value / 100) | 0.40 |
| Income generated | USD | value / 5000 | 0.30 |
| Employment created | jobs | value / 5 | 0.30 |

#### Governance (GOV)
| Metric | Unit | Normalization | Weight (initial) |
|--------|------|--------------|-----------------|
| Transparency points | 0–100 | value / 100 | 0.40 |
| Policy adherence | % | value / 100 | 0.30 |
| Community engagement | 0–1 | as-is | 0.30 |

#### Educational (EDU)
| Metric | Unit | Normalization | Weight (initial) |
|--------|------|--------------|-----------------|
| Literacy hours | hours | value / 10 | 0.30 |
| Students reached | count | value / 30 | 0.30 |
| Curriculum covered | % | value / 100 | 0.20 |
| Knowledge retention | % | value / 100 | 0.20 |

#### Infrastructure (INF)
| Metric | Unit | Normalization | Weight (initial) |
|--------|------|--------------|-----------------|
| Facilities built | count | value | 0.40 |
| Maintenance performed | hours | value / 20 | 0.30 |
| Access provided | count | value / 100 | 0.30 |

### 6.2 Algorithm Implementation

```python
class ImpactScoreAlgorithm:
    def __init__(self, domains: dict, weights: dict, 
                 vulnerability_data: dict, un_sdgs: dict):
        self.domains = domains  # {domain_name: [metric_names]}
        self.weights = weights  # {domain_name: {metric_name: weight}}
        self.vulnerability = vulnerability_data
        self.sdgs = un_sdgs
        self.alpha = 0.01  # learning rate
        
    def compute_score(self, action_metrics: dict, 
                      location: dict, time_since_action: float,
                      actor_verified_actions: int,
                      timestamp: datetime) -> float:
        
        domain_contributions = {}
        
        for domain, metrics in self.domains.items():
            domain_score = 0.0
            for metric in metrics:
                raw = action_metrics[domain][metric]
                normalized = self.normalize(raw, metric)
                weight = self.weights[domain][metric]
                decayed = normalized * self.temporal_decay(domain, time_since_action)
                domain_score += weight * decayed
            
            geo_adj = self.geographic_adjustment(domain, location)
            time_ctx = self.temporal_context(domain, timestamp)
            actor_norm = self.actor_normalization(actor_verified_actions)
            
            # Cross-domain consistency penalty
            consistency = self.cross_domain_consistency(action_metrics)
            
            domain_contributions[domain] = domain_score * geo_adj * time_ctx * actor_norm * (1 - 0.3 * consistency)
        
        total = sum(domain_contributions.values())
        return self.normalize_to_scale(total, 0, 1000)
    
    def update_weights(self, reward: float, gradients: dict):
        """Reinforcement learning weight update"""
        for domain, metric_grad in gradients.items():
            for metric, grad in metric_grad.items():
                self.weights[domain][metric] += self.alpha * reward * grad
                # Ensure weights stay in [0, 1] and sum to 1.0 per domain
                self.weights[domain][metric] = max(0, min(1, self.weights[domain][metric]))
        self._renormalize_domain_weights()
```

### 6.3 Temporal Decay Functions

```python
def temporal_decay(self, domain: str, t: float) -> float:
    """t = days since action completion"""
    if domain == "environmental":
        return math.exp(-0.05 * t)           # λ = 0.05
    elif domain == "social":
        t_max = 365  # 1 year max relevance
        return 1.0 - (t / t_max) ** 2
    elif domain == "governance":
        k = 0.05   # steepness
        t_half = 180  # days
        return 1.0 / (1.0 + math.exp(-k * (t - t_half)))
    elif domain == "economic":
        return math.exp(-0.1 * t)            # λ = 0.1
    elif domain == "educational":
        return math.exp(-0.03 * t)           # λ = 0.03
    elif domain == "infrastructure":
        return max(0.5, 1.0 - 0.02 * t)      # floors at 0.5
    return 1.0
```

### 6.4 Geographic Adjustment

```python
def geographic_adjustment(self, domain: str, location: dict) -> float:
    # location: {lat, lon, country, admin_region}
    vuln_idx = self.vulnerability.get(location['country'], 0.0)
    urgency = self.compute_urgency(domain, location)
    beta_d = {
        'environmental': 0.4,
        'social': 0.6,
        'governance': 0.5,
        'economic': 0.3,
        'educational': 0.5,
        'infrastructure': 0.7,
    }
    return 1.0 + beta_d.get(domain, 0.5) * vuln_idx * urgency
```

### 6.5 Cross-Domain Consistency

```python
def cross_domain_consistency(self, action_metrics: dict) -> float:
    """Penalize inconsistency between domains"""
    domain_scores = []
    for domain, metrics in self.domains.items():
        # Normalize each domain's metrics to 0-1, then take weighted average
        norm_scores = []
        for metric in metrics:
            raw = action_metrics[domain][metric]
            norm_scores.append(self.normalize(raw, metric))
        domain_avg = sum(norm_scores) / len(norm_scores)
        domain_scores.append(domain_avg)
    
    # Compute variance across domains
    mean_score = sum(domain_scores) / len(domain_scores)
    variance = sum((s - mean_score) ** 2 for s in domain_scores) / len(domain_scores)
    # Normalize variance to 0-1
    return min(1.0, variance / 0.25)  # cap at 1.0
```

---

## CLAIMS

*(See CLM-002 for full claim set. The following is a summary.)*

1. Multi-dimensional impact scoring across 6 domains with per-domain metrics and normalization
2. Learnable domain weights updated via reinforcement learning from outcome feedback
3. Domain-specific temporal decay functions
4. Geographic vulnerability index integration for adjustment factors
5. Actor normalization with new-participant incentive boost
6. Cross-domain consistency scoring with penalty
7. Impact score → blockchain asset value tier mapping

---

## ABSTRACT

A multi-dimensional impact scoring algorithm that quantifies real-world impact across six domains—environmental, social, economic, governance, educational, and infrastructure. Each domain contains 3–7 metrics with learnable weights that are dynamically updated via reinforcement learning based on outcome feedback. The algorithm applies domain-specific temporal decay functions, geographic vulnerability adjustment, and actor normalization with a new-participant incentive boost. Cross-domain consistency is enforced through a variance penalty. The final normalized score maps directly to blockchain-backed digital asset value tiers.

---

**Filed:** August 11, 2026
**Inventors:** MASAREN Engineering Team
**Attorney:** [To be assigned]
**Classification:** CONFIDENTIAL — PROPRIETARY

*This is a provisional patent application drafted for internal use pending formal attorney review and USPTO filing.*