# MASAREN Event Catalog

All events follow the schema defined in `shared/events/`.
Topics follow: `masaren.{domain}.{event_name}.v{version}`

## Identity Events
| Event | Topic | Emitter | Consumers |
|-------|-------|---------|-----------|
| UserRegistered | masaren.identity.user_registered.v1 | identity-service | graph-service, notification-service |
| UserVerified | masaren.identity.user_verified.v1 | identity-service | notification-service |
| PMSUpdated | masaren.identity.pms_updated.v1 | graph-synthesis-engine | identity-service, recommendation-agent |

## Execution Events
| Event | Topic | Emitter | Consumers |
|-------|-------|---------|-----------|
| OrganizationCreated | masaren.execution.organization_created.v1 | organization-service | graph-service |
| ProgramCreated | masaren.execution.program_created.v1 | program-service | planner-agent, graph-service |
| TaskAssigned | masaren.execution.task_assigned.v1 | task-service | notification-service, graph-service |
| TaskStarted | masaren.execution.task_started.v1 | task-service | notification-service |
| TaskCompleted | masaren.execution.task_completed.v1 | task-service | impact-score-service, graph-service |

## Verification Events
| Event | Topic | Emitter | Consumers |
|-------|-------|---------|-----------|
| LocationReached | masaren.verification.location_reached.v1 | gps-service | fraud-service, graph-service |
| EvidenceCaptured | masaren.verification.evidence_captured.v1 | evidence-service | audit-service |
| EvidenceUploaded | masaren.verification.evidence_uploaded.v1 | evidence-service | vision-ai-service, fraud-service, speech-ai-service |
| EvidenceVerified | masaren.verification.evidence_verified.v1 | verification-service | task-service, impact-economist-agent, notification-service |
| FraudDetected | masaren.verification.fraud_detected.v1 | fraud-service | audit-service, notification-service, identity-service |

## Reputation Events
| Event | Topic | Emitter | Consumers |
|-------|-------|---------|-----------|
| ImpactAssetCreated | masaren.reputation.impact_asset_created.v1 | impact-economist-agent | graph-synthesis-engine, broker-agent, portfolio-service |
| CertificateIssued | masaren.reputation.certificate_issued.v1 | program-service | identity-service, graph-service, notification-service |
| OIIUpdated | masaren.reputation.oii_updated.v1 | organization-score-service | graph-service |

## Marketplace Events
| Event | Topic | Emitter | Consumers |
|-------|-------|---------|-----------|
| OpportunityMatched | masaren.marketplace.opportunity_matched.v1 | matching-service | notification-service |
| FundingApproved | masaren.marketplace.funding_approved.v1 | opportunity-service | notification-service, graph-service |
