# INVENTION DISCLOSURE FORM (IDF)

**ID:** IDF-005
**Title:** Knowledge Graph Synthesis Engine, Graph-Based System Linking Actors, Actions, Outcomes, and Impact Assets
**Date:** August 11, 2026
**Classification:** CONFIDENTIAL, PROPRIETARY
**Status:** 🔴 Draft

---

## 1. SUMMARY

The Knowledge Graph Synthesis Engine is a Neo4j-based graph database system that maintains a comprehensive, real-time knowledge graph linking all entities in the MASAREN ecosystem:

- **Actors:** Individuals, organizations, communities
- **Actions:** Field activities, verifications, submissions
- **Outcomes:** Measured impacts, verification results
- **Assets:** Digital Impact Assets (MIAs), tokens, portfolio entries
- **Relationships:** Trust links, referrals, collaborations, conflicts of interest

The engine continuously ingests events from the event-sourced architecture (ms_orchestrator, transactional outbox), transforms them into graph nodes and edges using predefined mapping rules, and applies graph algorithms for anomaly detection, trust propagation, and network analysis.

---

## 2. TECHNICAL FIELD

This invention relates to graph databases, knowledge graphs, and real-time data processing. More specifically, it relates to a method and system for:

- Representing an interconnected ecosystem of actors, actions, and assets as a knowledge graph
- Real-time graph updates from distributed event streams
- Anomaly detection and trust propagation using graph algorithms
- Cross-domain inference and recommendation generation

---

## 3. PROBLEM STATEMENT

Traditional impact platforms use relational databases that cannot efficiently:

1. **Represent complex relationships:** Who referred whom? Which organizations collaborated?
2. **Detect collusion:** Circular trust relationships, Sybil attacks across actor networks
3. **Compute network effects:** How impact propagates through social/organizational networks
4. **Enable cross-domain inference:** Link environmental impact to economic outcomes via shared actors

---

## 4. DETAILED DESCRIPTION

### 4.1 Graph Schema

**Node Types:**

| Label | Properties |
|-------|-----------|
| `Actor` | id, type (individual/org), trust_score, join_date, location, sector |
| `Action` | id, type, timestamp, status, confidence_score, location |
| `Outcome` | id, action_id, metric_name, value, unit |
| `Asset` | id, token_address, isa_score, value, status, owner_id |
| `Organization` | id, name, impact_score, industry, verification_level |
| `Geography` | id, name, boundary, vulnerability_index, impact_density |
| `Task` | id, program_id, reward_pool, deadline, requirements |

**Relationship Types:**

| Type | From → To | Properties |
|------|-----------|-----------|
| `PERFORMED` | Actor → Action | role, timestamp |
| `VERIFIED` | Actor(Action) → Actor(Verifier) | method, confidence |
| `PRODUCED` | Action → Outcome |  |
| `MINTED` | Action → Asset | value, confidence |
| `OWNS` | Actor → Asset | quantity, acquisition_date |
| `REFERRED` | Actor → Actor | strength, date |
| `COLLABORATED` | Actor → Actor | project_id, impact |
| `LOCATED_IN` | Actor/Action → Geography |  |
| `ASSIGNED_TO` | Actor → Task | status, completion_date |
| `PARTICIPATED_IN` | Actor → Action | contribution_type |

### 4.2 Event Ingestion Pipeline

```
Event Store (PostgreSQL) 
  → Kafka Stream 
  → Neo4j Streams Connector 
  → Cypher Mapping Rules 
  → Graph Database (Neo4j)
```

Each event type has a mapping rule:

```cypher
// ActionCompleted event → PERFORMED relationship
MATCH (a:Actor {id: $actor_id})
MERGE (action:Action {id: $action_id})
  SET action.type = $action_type,
      action.status = 'completed',
      action.confidence_score = $confidence
MERGE (a)-[:PERFORMED]->(action)
```

### 4.3 Anomaly Detection

Uses graph algorithms to detect:

1. **Sybil Attack Detection:** 
   - Pattern: New actors with no referrals clustering near each other
   - Algorithm: Weakly Connected Components + density analysis
   
2. **Circular Trust Detection:**
   - Pattern: Actor A verifies B, B verifies C, C verifies A within short time window
   - Algorithm: Cycle detection with temporal constraints

3. **Impact Clustering Anomalies:**
   - Pattern: Unusually high impact scores in geographic clusters
   - Algorithm: Spatial autocorrelation (Moran's I) on geography nodes

```cypher
// Sybil detection example
MATCH (n:Actor) 
WHERE n.is_verified = false AND n.created_at > date() - duration({days: 7})
WITH n, count{(n)--(m:Actor)} AS degree
WHERE degree < 2 AND n.location_cluster = true
MATCH (cluster:Actor) WHERE cluster.location_cluster = true
RETURN collect(n) AS potential_sybils
```

### 4.4 Trust Propagation

Implements a PageRank-style trust propagation algorithm:

```
trust(A) = (1-d) + d × Σ(trust(B) × weight(B→A)) / out_degree(B)

where d = 0.85 (damping factor)
weight(B→A) = 1.0 if B is high-trust, 0.5 if B is untrusted
```

### 4.5 Cross-Domain Inference

Example: If Actor X has high environmental impact and collaborates with Actor Y in social domain, the system can recommend Y for environmental actions based on the strength of the collaboration edge.

```cypher
// Recommendation: Find collaborators of high-trust actors for new tasks
MATCH (high:Actor {trust_score: >0.8})-[:COLLABORATED]-(collaborator:Actor)
WHERE NOT (collaborator)-[:ASSIGNED_TO]->(task:Task {status: 'open'})
RETURN collaborator, count(*) AS collaboration_strength
ORDER BY collaboration_strength DESC LIMIT 10
```

### 4.6 Performance Optimization

- **Graph Data Science Library:** Pre-computes trust scores via batch processing every 6 hours
- **Indexing:** Composite indexes on Actor.id, Action.timestamp, Geography.boundary
- **Caching:** Hot nodes (top 1000 actors, active tasks) cached in Redis
- **Partitioning:** Actions partitioned by month; historical data archived

---

## 5. INVENTOR(S)

| Name | Affiliation | Contribution |
|------|------------|--------------|
| [Graph Architect] | MASAREN | Graph schema design, Neo4j integration |
| [Backend Engineer] | MASAREN | Event pipeline, mapping rules |
| [Data Scientist] | MASAREN | Anomaly detection algorithms, trust propagation |

---

## 6. COMMERCIAL APPLICATION

- **Ecosystem intelligence:** Understand how impact propagates through social/organizational networks
- **Fraud detection:** Identify coordinated manipulation attempts across multiple actors
- **Recommendations:** Match actors to appropriate tasks based on network position and skills
- **Partnership discovery:** Identify high-trust actors for collaboration opportunities
- **Impact attribution:** Trace the causal chain from action → outcome → asset → value

---

## 7. ATTACHMENTS

1. Full graph schema diagram (nodes, relationships, properties)
2. Event mapping rules (Cypher queries for each event type)
3. Anomaly detection algorithm specifications
4. Trust propagation pseudocode

---

**Form Completed By:** MASAREN Legal Team
**Date:** August 11, 2026
**IDF Reference:** IDF-005-20260811
**Distribution:** Legal Team, Patent Attorney, CTO, Board IP Committee