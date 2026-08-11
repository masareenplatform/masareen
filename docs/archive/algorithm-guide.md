# 📐 Algorithm & Mathematical Modeling Guide

This document formalizes the mathematical logic governing the MASAREN platform.

## 1. Dynamic Pricing Model (Financial Sustainability)

To ensure the platform remains profitable and covers the cost of Cloud LLMs and Human Auditors, we use a **Stochastic Variable Pricing Model**.

### The Formula
$$\text{Total Cost} (C) = \text{Base Price} (B) \times (M_{comp} \times M_{urg}) + S_{risk}$$

**Parameters:**
- $B$: **Base Price** (Admin-defined).
- $M_{comp}$: **Complexity Multiplier**. (e.g., $\text{Text}=1.0, \text{Multimodal}=1.5$).
- $M_{urg}$: **Urgency Multiplier**. (e.g., $\text{Standard}=1.0, \text{Express}=1.5$).
- $S_{risk}$: **Stochastic Risk Surcharge**.
  - If $\text{Confidence Score} (\text{CS}) < 0.75$:
    $$S_{risk} = (1 - \text{CS}) \times \text{Surcharge Cap}$$
  - This surcharge directly funds the human auditor's time.

**Profit Guardrail:**
$$\text{Final Price} = \max(C, \text{Minimum Floor})$$

---

## 2. Human-in-the-Loop (HITL) Routing Logic

Verification is a hybrid process between AI Agents and Human Auditors.

### Confidence Scoring
AI agents output a `ConfidenceScore` $\in [0, 1]$.

### Routing Table
| Confidence Score (CS) | Route | Action |
| :--- | :--- | :--- |
| $\text{CS} \ge 0.95$ | **Auto-Approve** | Immediate PMS/OII update. |
| $0.75 \le \text{CS} < 0.95$ | **Soft-Approve** | Update score, flag for random spot-check. |
| $\text{CS} < 0.75$ | **Human Review** | Route to `ReviewQueue`; block score update. |

---

## 3. Reputation Scoring (PMS & OII)

### Personal Merit Score (PMS)
The PMS is a weighted aggregation of verified impact events.
$$\text{PMS} = \sum_{i=1}^{n} (\text{Event Value}_i \times \text{Difficulty}_i \times \text{Verification Confidence}_i)$$

### Organization Impact Index (OII)
The OII measures the collective efficiency of an organization's workforce.
$$\text{OII} = \frac{\sum \text{Verified Impact of Affiliates}}{\text{Total Members}} \times \text{Governance Multiplier}$$

---

## 4. Ad Budgeting Logic (Monetization)

Ads are deactivated based on a linear depletion model.
$$\text{Current Spend} = (\text{Impressions} \times \text{Cost}_{imp}) + (\text{Clicks} \times \text{Cost}_{click})$$
**Condition:**
$$\text{If } \text{Current Spend} \ge \text{Spend Limit} \rightarrow \text{Status} = \text{INACTIVE}$$
