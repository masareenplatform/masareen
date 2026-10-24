# COPYRIGHT APPLICATION, RECORD 001
## MASAREN Platform, Complete Software System

---

> **Document Classification:** Confidential, Legal / Intellectual Property  
> **Document ID:** MASAREN-CR-APP-001  
> **Version:** 1.0  
> **Prepared:** August 11, 2026  
> **Jurisdiction:** International (Berne Convention Member States)

---

## SECTION 1, TITLE OF WORK

| Field | Value |
|-------|-------|
| **Title (English)** | MASAREN, Impact Infrastructure as a Service Platform |
| **Title (Arabic)** | مسارين، منصة البنية التحتية للأثر كخدمة |
| **Short Title** | MASAREN IIaaS Platform |
| **Alternative Titles** | MASAREN; مسارين; Impact Infrastructure Platform |
| **Series / Collection** | N/A, Single Unified Platform Work |

---

## SECTION 2, NATURE OF WORK

| Field | Value |
|-------|-------|
| **Type of Work** | Computer Software / Literary Work |
| **Form of Work** | Source Code, Object Code, and Associated Documentation |
| **Registration Category** | TX (Literary Works), Computer Program |
| **Medium of Fixation** | Electronic files fixed in digital storage media |
| **Derivative Work?** | No, Original work |
| **Compilation?** | Yes, Collection of original, independently copyrightable modules assembled into a unified platform |

### Description of Nature

MASAREN is an original, proprietary software platform constituting a computer program and associated documentation fixed in tangible digital form. The work includes:

- **Backend microservices** written in Python 3.12 using the FastAPI framework (35+ independent services)
- **Mobile application** written in Dart/Flutter (iOS and Android)
- **Web application** written in TypeScript/React with Vite
- **Administrative dashboard** written in TypeScript/React
- **Infrastructure-as-Code** including Kubernetes manifests, Helm charts, Terraform modules, and CI/CD pipelines in YAML
- **Database schemas** in SQL (PostgreSQL/PostGIS) and Neo4j Cypher
- **API specifications** and technical documentation
- **AI pipeline code** integrating cloud-based vision, fraud detection, and economic modeling

---

## SECTION 3, YEAR OF CREATION AND PUBLICATION

| Field | Value |
|-------|-------|
| **Year of Creation** | 2026 |
| **Date Work Completed** | August 2026 (ongoing development) |
| **First Publication Date** | Not yet publicly published |
| **Publication Status** | Unpublished (Pre-Alpha) |
| **Country of First Publication** | N/A, Not yet published |

> **Note:** Under the Berne Convention, copyright protection attaches at the moment of creation and fixation, without any registration requirement. This application documents the claimant's ownership record.

---

## SECTION 4, AUTHOR AND CLAIMANT

### 4.1 Author Information

| Field | Value |
|-------|-------|
| **Author Type** | Organization (Work Made for Hire / Organizational Work) |
| **Author / Owner Name** | MASAREN Project |
| **Domicile / Country** | [Country, To be completed by legal counsel] |
| **Author's Contribution** | Entire work, original conception, architecture, design, implementation |
| **Pseudonymous Work?** | No |
| **Anonymous Work?** | No |
| **Work Made for Hire?** | Yes, all contributing developers created works within the scope of engagement |

### 4.2 Claimant Information

| Field | Value |
|-------|-------|
| **Claimant Name** | MASAREN Project |
| **Claimant Address** | [Legal address, To be completed] |
| **Claimant Email** | [Legal contact email, To be completed] |
| **Basis of Claim** | Author and Owner, original creation |
| **Transfer of Rights** | N/A, No transfer; claimant is original author/owner |

### 4.3 Rights Owner Contact

| Field | Value |
|-------|-------|
| **Contact for Licensing** | [Designated IP contact, To be completed] |
| **Contact for Infringement** | [Designated IP contact, To be completed] |

---

## SECTION 5, DESCRIPTION OF WORK

### 5.1 Executive Summary

MASAREN (مسارين, meaning "Two Paths") is the world's first **Impact Infrastructure as a Service (IIaaS)** platform. The platform converts every verified real-world field action performed by individuals, volunteers, and organizations into immutable, measurable, and economically valuable digital assets.

The core innovation is an AI-powered verification pipeline that cross-references GPS data, photographic/video evidence, and behavioral patterns to authenticate that a claimed real-world action (e.g., planting a tree, completing a community service task, distributing aid) was genuinely performed. Upon verification, the action is minted as an "Impact Asset", a structured data record representing verified real-world value stored in a knowledge graph.

### 5.2 Technical Architecture

The platform implements a **Domain-Driven Design (DDD)** architecture with **Clean/Hexagonal Architecture** patterns, organized into the following bounded contexts:

| Domain | Services | Primary Function |
|--------|----------|-----------------|
| **Shared Kernel** | `shared/` | Common utilities, events, middleware, CQRS bus |
| **Identity** | identity-service, authentication-service, authorization-service | User registration, JWT auth, RBAC |
| **Execution** | organization-service, program-service, task-service, workflow-service | Program management, task assignment |
| **Verification** | submission-service, media-service, evidence-service, gps-service, audit-service, verification-service | Field action submission and multi-layer verification |
| **AI** | vision-ai-service, fraud-service, economist-agent, verification_orchestrator_service | Cloud AI inference pipeline for verification |
| **Reputation** | impact-score-service, organization-score-service, portfolio-service | Personal and organizational impact scoring |
| **Marketplace** | matching-service, opportunity-service | Impact opportunity discovery and matching |
| **Reporting** | report-service, analytics-service, forecast-service | Analytics, dashboards, impact forecasting |
| **Knowledge Graph** | graph-service | Neo4j-backed relationship mapping |
| **Billing** | billing-service, subscription-service, payment-service | Monetization and subscription management |
| **Notifications** | notification-service | Cross-channel alerting |
| **Social** | posts-service | Social content layer |
| **Chat** | chat-service | Messaging |
| **Partners** | partner-service | B2B partner integration |
| **Coin** | coin-service | Internal value token |
| **Ads** | ads-service | Sponsored content |
| **Platform** | platform-service | Core platform orchestration |
| **Gateway** | gateway + websocket-gateway | API gateway, WebSocket relay |

### 5.3 Key Proprietary Innovations

1. **Impact Verification Engine**, Multi-layer, AI-assisted verification combining GPS spoofing detection, image analysis, behavioral fraud detection, and cryptographic audit trails.

2. **Impact Asset Creation Protocol**, Automated conversion of verified field actions into structured digital assets with economic valuation via the Economist Agent.

3. **Personal Mission Score (PMS)**, A novel, multi-dimensional reputation scoring algorithm combining recency, diversity, volume, and quality of verified impact actions.

4. **Organizational Impact Index (OII)**, Aggregated organizational reputation derived from member activities and program outcomes.

5. **Efficiency Selector**, A proprietary AI sub-system that dynamically routes AI inference calls to the optimal cloud provider based on cost, speed, and capability.

6. **Knowledge Graph Synthesis**, Automated generation of Neo4j Cypher queries from verified impact data to build a real-time relationship map of actors, actions, programs, and outcomes.

### 5.4 Software Components Covered

This copyright application covers the following components as a unified compilation work:

- All Python source files under `backend/` (approximately 35+ service directories)
- All Dart/Flutter source files under `apps/mobile/`
- All TypeScript/JavaScript source files under `apps/web/` and `apps/admin/`
- All SQL migration files under `infrastructure/databases/`
- All YAML configuration files under `infrastructure/`
- All documentation files under `docs/`
- All infrastructure-as-code files (Kubernetes, Helm, Terraform, CI/CD)
- The MASAREN Demo application under `MASAREN-DEMO/`
- All associated configuration, environment, and build files

---

## SECTION 6, REGISTRATION STATUS

| Field | Value |
|-------|-------|
| **Internal Registration ID** | MASAREN-CR-APP-001 |
| **External Registration Number** | **TBD**, Application not yet filed with official copyright office |
| **Filing Status** | ⬜ PENDING, Preparation stage |
| **Target Copyright Office** | [To be determined by legal counsel, e.g., U.S. Copyright Office, national office] |
| **Expected Filing Date** | [To be completed, Q4 2026 target] |
| **Registration Received** | - |
| **Certificate Issued** | - |

### Registration Priority Notes

Copyright protection under the **Berne Convention** (175+ member countries) attaches automatically upon creation and fixation. Formal registration with a national copyright office (e.g., the U.S. Copyright Office for U.S. registration benefits) provides:

- Prima facie evidence of validity in litigation
- Eligibility for statutory damages and attorney's fees (U.S. jurisdiction)
- Public record of ownership
- Simplified customs recordation for border enforcement

**Recommended Action:** File with the U.S. Copyright Office (Form TX, Literary Works) and simultaneously consider filings in primary markets of operation.

---

## SECTION 7, FILING DETAILS

### 7.1 Deposit Requirements

| Jurisdiction | Deposit Requirement |
|-------------|---------------------|
| U.S. Copyright Office | Identifying portions of source code (first/last 25 pages, plus representative middle pages) or electronic deposit; trade secret protection available for proprietary sections |
| EU (via national offices) | Typically copy or description of the work |

### 7.2 Recommended Deposit Preparation

For the U.S. Copyright Office filing, prepare:

1. **Completed Form TX** (or equivalent online registration at copyright.gov)
2. **Deposit copy**, First 25 pages and last 25 pages of representative source code, with trade-secret sections redacted per 37 CFR § 202.20(c)(vii)
3. **Representative screenshots** of the application UI (web and mobile)
4. **Filing fee** (current fee: approximately $65 USD for online single application)
5. **Cover letter** identifying the work as a computer program

### 7.3 Key Filing Dates & Deadlines

| Event | Date |
|-------|------|
| Work created / fixed | 2026 |
| Internal IP record created | August 11, 2026 |
| Target external filing | Q4 2026 |
| Renewal (if applicable) | N/A, Life of author + 70 years (Berne); no renewal required |

### 7.4 Correspondence Log

| Date | Action | Party | Notes |
|------|--------|-------|-------|
| 2026-08-11 | Internal copyright record created | MASAREN IP Team | This document |
| - | Legal counsel engagement | TBD | Pending |
| - | External filing | TBD | Pending |

---

## SECTION 8, RIGHTS STATEMENT

```
Copyright © 2026 MASAREN Project. All Rights Reserved.

This software platform and all associated source code, documentation,
designs, and materials are the exclusive proprietary property of the
MASAREN Project. No part of this work may be reproduced, distributed,
transmitted, stored, modified, adapted, translated, or used to create
derivative works in any form or by any means, electronic, mechanical,
photocopying, recording, or otherwise, without the prior express written
permission of MASAREN Project.

Any unauthorized use of this work may constitute copyright infringement
and may be subject to civil and criminal penalties under applicable law.
```

---

## SECTION 9, DOCUMENT CONTROL

| Field | Value |
|-------|-------|
| **Prepared by** | MASAREN IP Documentation System |
| **Review Required by** | Legal Counsel |
| **Next Review Date** | Upon external filing or December 31, 2026 |
| **Document Location** | `ip-legal/copyright/registrations/COPYRIGHT-APPLICATION-001.md` |
| **Related Documents** | `WORKS-REGISTER.md`, `SOFTWARE-WORKS-INVENTORY.md`, `COPYRIGHT-NOTICE.md` |

---

*This document is a confidential internal record of MASAREN's intellectual property. It does not constitute legal advice. Consult qualified legal counsel for filing strategy and jurisdiction-specific requirements.*
