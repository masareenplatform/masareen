# MASAREN IP Legal Directory, Master Index

> **CONFIDENTIAL, PROPRIETARY**
> Authorized access only. See [README.md](./README.md) for access policy and confidentiality notice.

*Last Updated: August 11, 2026 · Maintained by: MASAREN Legal Team*

---

## Table of Contents

1. [Directory Tree](#directory-tree)
2. [Document Registry](#document-registry)
   - [Copyright](#copyright-section)
   - [Patents](#patents-section)
   - [Trademarks](#trademarks-section)
   - [Trade Secrets](#trade-secrets-section)
   - [Notices](#notices-section)
   - [Governance](#governance-section)
3. [Status Tracker](#status-tracker)
   - [Copyright Registrations](#copyright-registrations-status)
   - [Patent Applications](#patent-applications-status)
   - [Trademark Applications](#trademark-applications-status)
4. [Quick Reference](#quick-reference)
5. [Revision History](#revision-history)

---

## Directory Tree

```
ip-legal/
├── README.md                          ← Directory overview, access policy, legal contacts
├── INDEX.md                           ← THIS FILE, master table of contents
│
├── copyright/                         ← All copyright protection materials
│   ├── registrations/                 ← Official registration certificates and filings
│   │   └── [REG-COPY-001.md]          ← [Placeholder] Platform Software Registration
│   ├── source-headers/                ← Standard copyright header templates for all code
│   │   ├── [header-python.txt]        ← [Placeholder] Python/FastAPI service header
│   │   ├── [header-dart.txt]          ← [Placeholder] Flutter/Dart header
│   │   ├── [header-typescript.txt]    ← [Placeholder] React/TypeScript header
│   │   └── [header-sql.txt]           ← [Placeholder] SQL migration file header
│   ├── works-database/                ← Catalog of all copyrightable works
│   │   └── [works-catalog.md]         ← [Placeholder] Master works database
│   └── notices/                       ← Published copyright notices and policies
│       └── [copyright-policy.md]      ← [Placeholder] External copyright notice policy
│
├── patents/                           ← All patent strategy and filing materials
│   ├── disclosures/                   ← Invention disclosure forms (IDFs)
│   │   ├── [IDF-001-verification-to-asset.md]   ← [Placeholder] Verification-to-Asset Pipeline
│   │   ├── [IDF-002-impact-score.md]             ← [Placeholder] Impact Score Algorithm
│   │   ├── [IDF-003-geo-fence-verification.md]   ← [Placeholder] Geo-Fenced Field Verification
│   │   ├── [IDF-004-ai-evidence-verification.md] ← [Placeholder] AI Multi-Modal Evidence
│   │   └── [IDF-005-knowledge-graph-synthesis.md]← [Placeholder] Knowledge Graph Synthesis
│   ├── claims/                        ← Drafted patent claims for review
│   │   ├── [CLM-001-verification-pipeline.md]    ← [Placeholder] Claims: Verification Pipeline
│   │   └── [CLM-002-impact-score.md]             ← [Placeholder] Claims: Impact Score Algorithm
│   ├── prior-art/                     ← Prior art research and freedom-to-operate analyses
│   │   ├── [PAR-001-verification-landscape.md]   ← [Placeholder] Verification tech landscape
│   │   └── [PAR-002-impact-measurement.md]       ← [Placeholder] Impact measurement prior art
│   ├── provisional/                   ← Provisional patent applications
│   │   ├── [PROV-001-verification-pipeline.md]   ← [Placeholder] Provisional: Verification-to-Asset
│   │   └── [PROV-002-impact-score.md]             ← [Placeholder] Provisional: Impact Score
│   └── pct/                           ← PCT international applications
│       └── [PCT-001-verification-pipeline.md]    ← [Placeholder] PCT: Verification Pipeline
│
├── trademarks/                        ← All trademark protection materials
│   ├── registrations/                 ← Registration certificates and application records
│   │   ├── [TM-001-masaren-word.md]   ← [Placeholder] "MASAREN" word mark
│   │   ├── [TM-002-masaren-arabic.md] ← [Placeholder] "مسارين" Arabic word mark
│   │   ├── [TM-003-logo.md]           ← [Placeholder] MASAREN logo mark
│   │   └── [TM-004-tagline.md]        ← [Placeholder] Tagline trademark
│   ├── usage-evidence/                ← Documented commercial use of marks
│   │   ├── [USE-001-platform-screenshots.md]    ← [Placeholder] In-app mark usage
│   │   └── [USE-002-marketing-materials.md]     ← [Placeholder] Marketing collateral evidence
│   └── brand-standards/               ← Official brand and trademark usage guidelines
│       └── [brand-guide.md]           ← [Placeholder] MASAREN Brand Standards Guide
│
├── trade-secrets/                     ← Trade secret identification, protection, and NDAs
│   ├── policies/                      ← Trade secret protection policies
│   │   ├── [TS-POLICY-001.md]         ← [Placeholder] Trade Secret Identification Policy
│   │   └── [TS-POLICY-002.md]         ← [Placeholder] Employee Handling & Protection Policy
│   ├── nda-templates/                 ← Non-disclosure agreement templates
│   │   ├── [NDA-EMPLOYEE.md]          ← [Placeholder] Employee NDA (onboarding)
│   │   ├── [NDA-CONTRACTOR.md]        ← [Placeholder] Contractor / Freelancer NDA
│   │   ├── [NDA-PARTNER.md]           ← [Placeholder] Business Partner / Investor NDA
│   │   └── [NDA-MUTUAL.md]            ← [Placeholder] Mutual NDA (bilateral partnerships)
│   └── inventories/                   ← Classified inventories of trade secrets
│       ├── [TS-INV-001-algorithms.md] ← [Placeholder] Algorithmic trade secrets inventory
│       ├── [TS-INV-002-data-schemas.md]← [Placeholder] Proprietary data schemas inventory
│       └── [TS-INV-003-ai-configs.md] ← [Placeholder] AI model configs & prompt inventories
│
├── notices/                           ← Formal legal IP notices and correspondence
│   ├── [NOTICE-TEMPLATE-CEASE.md]     ← [Placeholder] Cease and desist letter template
│   ├── [NOTICE-TEMPLATE-DMCA.md]      ← [Placeholder] DMCA takedown notice template
│   └── [NOTICE-LOG.md]                ← [Placeholder] Log of all sent/received IP notices
│
└── governance/                        ← IP governance framework
    ├── policies/                      ← IP governance policies
    │   ├── [GOV-POL-001-ip-ownership.md]         ← [Placeholder] IP Ownership & Assignment Policy
    │   ├── [GOV-POL-002-open-source.md]           ← [Placeholder] Open Source Usage Policy
    │   ├── [GOV-POL-003-third-party-software.md]  ← [Placeholder] Third-Party Software Policy
    │   └── [GOV-POL-004-disclosure-review.md]     ← [Placeholder] Invention Disclosure Review Policy
    ├── procedures/                    ← Step-by-step IP operational procedures
    │   ├── [PROC-001-new-invention.md]            ← [Placeholder] New Invention Disclosure Procedure
    │   ├── [PROC-002-patent-filing.md]            ← [Placeholder] Patent Filing Workflow
    │   ├── [PROC-003-copyright-registration.md]   ← [Placeholder] Copyright Registration Procedure
    │   ├── [PROC-004-trademark-watch.md]          ← [Placeholder] Trademark Monitoring Procedure
    │   └── [PROC-005-ip-incident-response.md]     ← [Placeholder] IP Infringement Response Procedure
    └── training/                      ← IP awareness and compliance training
        ├── [TRAIN-001-ip-basics.md]               ← [Placeholder] IP Basics for Employees
        ├── [TRAIN-002-trade-secret-handling.md]   ← [Placeholder] Trade Secret Handling Training
        └── [TRAIN-003-open-source-compliance.md]  ← [Placeholder] Open Source Compliance Training
```

---

## Document Registry

### Copyright Section

`copyright/`, Protection of MASAREN's original creative and software works.

| ID | File | Description | Classification | Status |
|----|------|-------------|---------------|--------|
| COPY-REG-001 | `registrations/REG-COPY-001.md` | Copyright registration for the MASAREN platform software (all 35+ microservices, Flutter app, React web) | CONFIDENTIAL | 🔴 Pending |
| COPY-HDR-001 | `source-headers/header-python.txt` | Standard copyright header for all Python/FastAPI microservice files | INTERNAL | 🔴 Pending |
| COPY-HDR-002 | `source-headers/header-dart.txt` | Standard copyright header for Flutter/Dart source files | INTERNAL | 🔴 Pending |
| COPY-HDR-003 | `source-headers/header-typescript.txt` | Standard copyright header for React/TypeScript source files | INTERNAL | 🔴 Pending |
| COPY-HDR-004 | `source-headers/header-sql.txt` | Standard copyright header for SQL migration files | INTERNAL | 🔴 Pending |
| COPY-WDB-001 | `works-database/works-catalog.md` | Master catalog of all copyrightable works: services, UIs, documentation, designs | CONFIDENTIAL | 🔴 Pending |
| COPY-NOT-001 | `notices/copyright-policy.md` | External-facing copyright notice policy and licensing terms | INTERNAL | 🔴 Pending |

---

### Patents Section

`patents/`, Protection of MASAREN's novel technical inventions.

#### Invention Disclosure Forms (IDFs)

| ID | File | Invention | Inventor(s) | Date Filed | Status |
|----|------|-----------|------------|-----------|--------|
| IDF-001 | `disclosures/IDF-001-verification-to-asset.md` | Verification-to-Asset Pipeline, system and method for converting verified field actions into digital economic assets | [TBD] | [TBD] | 🟡 Draft Complete |
| IDF-002 | `disclosures/IDF-002-impact-score.md` | Impact Score Algorithm, multi-dimensional scoring system for quantifying real-world impact | [TBD] | [TBD] | 🟡 Draft Complete |
| IDF-003 | `disclosures/IDF-003-geo-fence-verification.md` | Geo-Fenced Field Verification System, location-locked task execution and evidence verification | [TBD] | [TBD] | 🟡 Draft Complete |
| IDF-004 | `disclosures/IDF-004-ai-evidence-verification.md` | AI Multi-Modal Evidence Verification, AI pipeline for photographic, GPS, and behavioral evidence verification | [TBD] | [TBD] | 🟡 Draft Complete |
| IDF-005 | `disclosures/IDF-005-knowledge-graph-synthesis.md` | Knowledge Graph Synthesis Engine, graph-based system linking actors, actions, outcomes, and impact assets | [TBD] | [TBD] | 🟡 Draft Complete |

#### Patent Claims

| ID | File | Related IDF | Description | Status |
|----|------|------------|-------------|--------|
| CLM-001 | `claims/CLM-001-verification-pipeline.md` | IDF-001 | Independent and dependent claims for the Verification-to-Asset Pipeline | 🟡 Draft Complete |
| CLM-002 | `claims/CLM-002-impact-score.md` | IDF-002 | Claims for the Impact Score Algorithm | 🟡 Draft Complete |

#### Prior Art Research

| ID | File | Domain | Description | Status |
|----|------|--------|-------------|--------|
| PAR-001 | `prior-art/PAR-001-verification-landscape.md` | Verification Technology | Landscape analysis of existing verification systems; freedom-to-operate assessment | 🟢 Complete |
| PAR-002 | `prior-art/PAR-002-impact-measurement.md` | Impact Measurement | Prior art search for impact scoring and measurement methodologies | 🟢 Complete |

#### Provisional Applications

| ID | File | Related IDF | Filing Date | Application # | Expiry Date | Status |
|----|------|------------|------------|--------------|------------|--------|
| PROV-001 | `provisional/PROV-001-verification-pipeline.md` | IDF-001 | [Pending Attorney] | [TBD] | [TBD] | 🟡 Draft Complete |
| PROV-002 | `provisional/PROV-002-impact-score.md` | IDF-002 | [Pending Attorney] | [TBD] | [TBD] | 🟡 Draft Complete |

#### PCT Applications

| ID | File | Related Provisional | PCT Filing Date | PCT # | Jurisdictions | Status |
|----|------|-------------------|----------------|-------|--------------|--------|
| PCT-001 | `pct/PCT-001-verification-pipeline.md` | PROV-001, PROV-002 | Q4 2026 | [TBD] | Global | 🟡 Draft Complete |

---

### Trademarks Section

`trademarks/`, Protection of the MASAREN brand identity.

#### Trademark Registrations

| ID | File | Mark | Class(es) | Jurisdiction(s) | Application # | Reg # | Filing Date | Reg Date | Status |
|----|------|------|----------|----------------|--------------|-------|------------|---------|--------|
| TM-001 | `registrations/TM-001-masaren-word.md` | MASAREN (word) | 35, 42 | [TBD] | [TBD] | [TBD] | [TBD] | [TBD] | 🔴 Not Filed |
| TM-002 | `registrations/TM-002-masaren-arabic.md` | مسارين (word, Arabic) | 35, 42 | [TBD] | [TBD] | [TBD] | [TBD] | [TBD] | 🔴 Not Filed |
| TM-003 | `registrations/TM-003-logo.md` | MASAREN logo (device) | 35, 42 | [TBD] | [TBD] | [TBD] | [TBD] | [TBD] | 🔴 Not Filed |
| TM-004 | `registrations/TM-004-tagline.md` | "Two Paths" / IIaaS tagline | 35, 42 | [TBD] | [TBD] | [TBD] | [TBD] | [TBD] | 🔴 Not Filed |

#### Usage Evidence

| ID | File | Mark(s) | Evidence Type | Date of First Use | Status |
|----|------|--------|--------------|-----------------|--------|
| USE-001 | `usage-evidence/USE-001-platform-screenshots.md` | All marks | In-app and platform UI screenshots | [TBD] | 🔴 Pending |
| USE-002 | `usage-evidence/USE-002-marketing-materials.md` | All marks | Marketing collateral, press, website | [TBD] | 🔴 Pending |

#### Brand Standards

| ID | File | Description | Status |
|----|------|-------------|--------|
| BRAND-001 | `brand-standards/brand-guide.md` | Official MASAREN Brand Standards Guide: logo usage, colors, typography, mark restrictions, co-branding rules | 🔴 Draft |

---

### Trade Secrets Section

`trade-secrets/`, Identification, classification, and protection of MASAREN's proprietary information.

#### Policies

| ID | File | Description | Version | Effective Date | Status |
|----|------|-------------|---------|---------------|--------|
| TS-POL-001 | `policies/TS-POLICY-001.md` | Trade Secret Identification Policy, criteria for classifying information as a trade secret | v1.0 | [TBD] | 🔴 Draft |
| TS-POL-002 | `policies/TS-POLICY-002.md` | Employee Trade Secret Handling & Protection Policy, obligations, access controls, departure protocols | v1.0 | [TBD] | 🔴 Draft |

#### NDA Templates

| ID | File | Party Type | Description | Version | Status |
|----|------|-----------|-------------|---------|--------|
| NDA-001 | `nda-templates/NDA-EMPLOYEE.md` | Employee | One-way NDA for all employees; covers platform, algorithms, data, architecture | v1.0 | 🔴 Draft |
| NDA-002 | `nda-templates/NDA-CONTRACTOR.md` | Contractor | One-way NDA for contractors and freelancers | v1.0 | 🔴 Draft |
| NDA-003 | `nda-templates/NDA-PARTNER.md` | Business Partner / Investor | One-way NDA for partners, investors, and integration teams | v1.0 | 🔴 Draft |
| NDA-004 | `nda-templates/NDA-MUTUAL.md` | Bilateral | Mutual NDA for co-development and partnership discussions | v1.0 | 🔴 Draft |

#### Trade Secret Inventories

| ID | File | Category | # of Secrets | Classification | Status |
|----|------|----------|-------------|---------------|--------|
| TS-INV-001 | `inventories/TS-INV-001-algorithms.md` | Algorithms & Models | [TBD] | RESTRICTED | 🔴 Draft |
| TS-INV-002 | `inventories/TS-INV-002-data-schemas.md` | Data Schemas & Structures | [TBD] | RESTRICTED | 🔴 Draft |
| TS-INV-003 | `inventories/TS-INV-003-ai-configs.md` | AI Configurations & Prompts | [TBD] | RESTRICTED | 🔴 Draft |

---

### Notices Section

`notices/`, Formal IP legal notices, templates, and correspondence log.

| ID | File | Description | Status |
|----|------|-------------|--------|
| NOT-001 | `notices/NOTICE-TEMPLATE-CEASE.md` | Cease and desist letter template for IP infringement (copyright, trademark, trade secret) | 🔴 Draft |
| NOT-002 | `notices/NOTICE-TEMPLATE-DMCA.md` | DMCA takedown notice template for online copyright infringement | 🔴 Draft |
| NOT-LOG | `notices/NOTICE-LOG.md` | Chronological log of all formal IP notices sent and received, including outcomes | 🔴 Active |

---

### Governance Section

`governance/`, The policy, procedure, and training framework for IP management at MASAREN.

#### Policies

| ID | File | Description | Version | Effective Date | Status |
|----|------|-------------|---------|---------------|--------|
| GOV-POL-001 | `governance/policies/GOV-POL-001-ip-ownership.md` | IP Ownership & Assignment Policy, all IP created by employees/contractors belongs to MASAREN | v1.0 | [TBD] | 🔴 Draft |
| GOV-POL-002 | `governance/policies/GOV-POL-002-open-source.md` | Open Source Usage Policy, approved licenses, prohibited licenses, obligation tracking | v1.0 | [TBD] | 🔴 Draft |
| GOV-POL-003 | `governance/policies/GOV-POL-003-third-party-software.md` | Third-Party Software Policy, procurement, review, and compliance for all third-party code | v1.0 | [TBD] | 🔴 Draft |
| GOV-POL-004 | `governance/policies/GOV-POL-004-disclosure-review.md` | Invention Disclosure Review Policy, process and criteria for evaluating IDFs | v1.0 | [TBD] | 🔴 Draft |

#### Procedures

| ID | File | Description | Version | Status |
|----|------|-------------|---------|--------|
| PROC-001 | `governance/procedures/PROC-001-new-invention.md` | New Invention Disclosure Procedure, step-by-step guide for engineers to disclose inventions | v1.0 | 🔴 Draft |
| PROC-002 | `governance/procedures/PROC-002-patent-filing.md` | Patent Filing Workflow, from IDF approval to provisional to PCT filing | v1.0 | 🔴 Draft |
| PROC-003 | `governance/procedures/PROC-003-copyright-registration.md` | Copyright Registration Procedure, identifying, preparing, and filing copyright registrations | v1.0 | 🔴 Draft |
| PROC-004 | `governance/procedures/PROC-004-trademark-watch.md` | Trademark Monitoring Procedure, watch services, opposition filings, and renewal tracking | v1.0 | 🔴 Draft |
| PROC-005 | `governance/procedures/PROC-005-ip-incident-response.md` | IP Infringement Response Procedure, triage, escalation, and enforcement workflow | v1.0 | 🔴 Draft |

#### Training

| ID | File | Audience | Description | Version | Status |
|----|------|---------|-------------|---------|--------|
| TRAIN-001 | `governance/training/TRAIN-001-ip-basics.md` | All Employees | IP Basics for Employees, copyright, patents, trademarks, trade secrets; what belongs to MASAREN | v1.0 | 🔴 Draft |
| TRAIN-002 | `governance/training/TRAIN-002-trade-secret-handling.md` | Engineering & Product | Trade Secret Handling Training, what qualifies, access controls, offboarding protocols | v1.0 | 🔴 Draft |
| TRAIN-003 | `governance/training/TRAIN-003-open-source-compliance.md` | Engineering | Open Source Compliance Training, license types, obligations, prohibited licenses | v1.0 | 🔴 Draft |

---

## Status Tracker

### Legend

| Icon | Meaning |
|------|---------|
| 🔴 | Not started / Draft / Pending |
| 🟡 | In progress / Under review |
| 🟢 | Complete / Filed / Registered |
| ⚪ | N/A or deferred |

---

### Copyright Registrations Status

| Work | Jurisdiction | Filing Date | Registration # | Expiry | Status |
|------|-------------|------------|---------------|--------|--------|
| MASAREN Platform Software (all services) | [TBD] | [TBD] | [TBD] | [TBD] | 🔴 Pending |
| MASAREN Flutter Mobile Application | [TBD] | [TBD] | [TBD] | [TBD] | 🔴 Pending |
| MASAREN React Web Dashboard | [TBD] | [TBD] | [TBD] | [TBD] | 🔴 Pending |
| MASAREN Brand Assets & Visual Identity | [TBD] | [TBD] | [TBD] | [TBD] | 🔴 Pending |
| MASAREN Technical Documentation | [TBD] | [TBD] | [TBD] | [TBD] | 🔴 Pending |

---

### Patent Applications Status

| Invention | IDF | Provisional Filed | Provisional # | Provisional Expiry | PCT Filed | PCT # | Status |
|-----------|-----|-----------------|--------------|-------------------|----------|-------|--------|
| Verification-to-Asset Pipeline | IDF-001 | Drafting Complete | [Pending] | 12 months from filing | Drafting | PCT-001 | Q4 2026 | 🟡 Ready for Filing |
| Impact Score Algorithm | IDF-002 | Drafting Complete | [Pending] | 12 months from filing | Drafting | PCT-001 | Q4 2026 | 🟡 Ready for Filing |
| Geo-Fenced Field Verification | IDF-003 | Drafting Complete | - | - | - | - | Q1 2027 | 🟡 In Drafting |
| AI Multi-Modal Evidence Verification | IDF-004 | Drafting Complete | - | - | - | - | Q1 2027 | 🟡 In Drafting |
| Knowledge Graph Synthesis Engine | IDF-005 | Drafting Complete | - | - | - | - | Q2 2027 | 🟡 In Drafting |
| Knowledge Graph Synthesis Engine | IDF-005 | [TBD] | [TBD] | [TBD] | [TBD] | [TBD] | 🔴 Drafting |
| Personal Impact Portfolio (PMS) | [TBD] | [TBD] | [TBD] | [TBD] | [TBD] | [TBD] | 🔴 Not Started |
| Organization Impact Index (OII) | [TBD] | [TBD] | [TBD] | [TBD] | [TBD] | [TBD] | 🔴 Not Started |

---

### Trademark Applications Status

| Mark | Jurisdiction | Nice Class(es) | Application # | Filing Date | Reg # | Reg Date | Renewal Date | Status |
|------|-------------|---------------|--------------|------------|-------|---------|-------------|--------|
| MASAREN (EN, word) | [TBD] | 35, 42 | [TBD] | [TBD] | [TBD] | [TBD] | [TBD] | 🔴 Not Filed |
| مسارين (AR, word) | [TBD] | 35, 42 | [TBD] | [TBD] | [TBD] | [TBD] | [TBD] | 🔴 Not Filed |
| MASAREN Logo (device) | [TBD] | 35, 42 | [TBD] | [TBD] | [TBD] | [TBD] | [TBD] | 🔴 Not Filed |
| "Impact Infrastructure as a Service" | [TBD] | 35, 42 | [TBD] | [TBD] | [TBD] | [TBD] | [TBD] | 🔴 Not Filed |

---

## Quick Reference

### By Task

| I need to... | Go to... |
|-------------|---------|
| Add a copyright header to a new source file | `copyright/source-headers/` |
| Register a new copyright work | `copyright/registrations/` + follow `governance/procedures/PROC-003` |
| Disclose a new invention | `patents/disclosures/` + follow `governance/procedures/PROC-001` |
| File a provisional patent | `patents/provisional/` + follow `governance/procedures/PROC-002` |
| Research prior art for a new invention | `patents/prior-art/` |
| Apply for a trademark | `trademarks/registrations/` + follow `governance/procedures/PROC-004` |
| Prepare an NDA for a new hire | `trade-secrets/nda-templates/NDA-EMPLOYEE.md` |
| Prepare an NDA for a partner or investor | `trade-secrets/nda-templates/NDA-PARTNER.md` |
| Classify new proprietary information | `trade-secrets/policies/TS-POLICY-001.md` |
| Respond to a suspected infringement | `notices/` + follow `governance/procedures/PROC-005` |
| File a DMCA takedown | `notices/NOTICE-TEMPLATE-DMCA.md` |
| Onboard an employee on IP obligations | `governance/training/TRAIN-001-ip-basics.md` |
| Check if an open source license is approved | `governance/policies/GOV-POL-002-open-source.md` |
| Understand IP ownership rules | `governance/policies/GOV-POL-001-ip-ownership.md` |

### By Innovation

| MASAREN Innovation | Primary IP Coverage | Key Documents |
|-------------------|-------------------|---------------|
| Verification-to-Asset Pipeline | Patent + Trade Secret | IDF-001, PROV-001, TS-INV-001 |
| Impact Score Algorithm (ISA) | Patent + Trade Secret | IDF-002, PROV-002, TS-INV-001 |
| AI Multi-Modal Evidence Verification | Patent + Copyright | IDF-004, COPY-REG-001 |
| Personal Impact Portfolio (PMS) | Patent + Copyright | IDF TBD, COPY-REG-001 |
| Geo-Fenced Field Verification | Patent | IDF-003, PROV-001 |
| Knowledge Graph Synthesis Engine | Patent + Trade Secret | IDF-005, TS-INV-001 |
| Organization Impact Index (OII) | Patent + Trade Secret | IDF TBD, TS-INV-001 |
| Platform Codebase (35+ services) | Copyright | COPY-REG-001, all source headers |
| MASAREN Brand Identity | Trademark | TM-001 through TM-004, BRAND-001 |

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.1 | August 11, 2026 | MASAREN Legal Team | Initial creation of all patent disclosure, claims, prior art, provisional, and PCT documents |

---

*Document Owner: MASAREN Legal Team*
*Last Updated: August 11, 2026*
*Classification: CONFIDENTIAL*
