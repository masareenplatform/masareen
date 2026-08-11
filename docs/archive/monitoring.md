# 📊 Monitoring & Analytics Guide

This guide explains how to monitor the MASAREN platform and perform deep data analysis using the observability stack.

## 1. Observability Stack
We use the **LGP Stack** (Loki, Grafana, Prometheus) for real-time monitoring.

### Prometheus (Metrics)
- **Scrape Interval**: 15 seconds.
- **Key Metrics**:
  - `up`: Service availability.
  - `ai_verification_requests_total`: Throughput of the AI Orchestrator.
  - `ai_verification_failures_total`: Error rate of the POAI crew.
  - `platform_ad_budget_remaining`: Financial health of sponsored content.
- **Access**: `http://prometheus.masaren.io:9090`

### Grafana (Visualizations)
The Admin Dashboard consists of three main views:
1. **System Health**: CPU/RAM per pod, Request Latency (p99), and Kafka lag.
2. **Verification Funnel**: Ratio of `Submission` $\rightarrow$ `AI Review` $\rightarrow$ `Human Review` $\rightarrow$ `Verified`.
3. **Economic View**: Real-time revenue from ads and verification fees.

### Alertmanager (Alerting)
Critical alerts are routed to Slack/Email:
- **Critical**: Service Down (Immediate action required).
- **Warning**: High AI Failure Rate (Needs prompt tuning).
- **Info**: Ad Budget Exhausted (Sales opportunity).

---

## 2. Deep Analytics (R-Scripts)
While Grafana is for *real-time* monitoring, we use **R** for *strategic* analysis.

### Available Scripts in `/analytics`
- `user_behavior_analysis.R`: Analyzes user retention and the correlation between field work and PMS growth.
- `organizational_impact_report.R`: Generates global SDG trend reports and OII distribution maps.

### How to Run Analytics
1. Install R and the `tidyverse` package.
2. Connect to the PostgreSQL read-replica.
3. Execute the script:
   ```bash
   Rscript analytics/user_behavior_analysis.R
   ```

---

## 3. Platform Improvement Cycle
We follow a data-driven feedback loop:
`Metrics (Prometheus)` $\rightarrow$ `Insight (R-Analysis)` $\rightarrow$ `Strategic Change (CEO Plan)` $\rightarrow$ `Implementation (Code)`
