# Verification Domain Event Catalog

## Submission Events

| Event Name | Version | Publisher | Consumers | Kafka Topic | Payload Schema | Idempotency Key | Retry Policy | Ordering Requirements | Dead Letter Strategy |
|------------|---------|-----------|-----------|-------------|----------------|------------------|--------------|-----------------------|----------------------|
| SubmissionCreated | 1.0.0 | SubmissionService | [VerificationService, AuditService, ReputationService] | submission.created | \{\n  "submissionId": "uuid",\n  "proofUrl": "string",\n  "description": "string",\n  "visibilityLevel": "public | private",\n  "contactInfo": {\n    "email": "string",\n    "phone": "string"\n  "\n}\n} | submissionId | 3 attempts (exponential backoff) | FIFO per submissionId | Dead letter to DLQ with alert | 
| SubmissionUpdated | 1.0.0 | SubmissionService | [AuditService] | submission.updated | \{\n  "submissionId": "uuid",\n  "field": "string",\n  "value": "string"\n}\n} | submissionId + field | 2 attempts | FIFO per submissionId | Dead letter to DLQ with alert |

## Media Events

| Event Name | Version | Publisher | Consumers | Kafka Topic | Payload Schema | Idempotency Key | Retry Policy | Ordering Requirements | Dead Letter Strategy |
|------------|---------|-----------|-----------|-------------|----------------|------------------|--------------|-----------------------|----------------------|
| MediaUploaded | 1.0.0 | MediaService | [VerificationService, AuditService] | media.uploaded | \{\n  "mediaId": "uuid",\n  "submissionId": "uuid",\n  "fileName": "string",\n  "storageProvider": "s3 | gcs",\n  "fileSize": "integer",\n  "mimeType": "string"\n}\n} | mediaId | 3 attempts | FIFO per submissionId | Dead letter to DLQ with alert |
| MediaProcessingCompleted | 1.0.0 | MediaService | [VerificationService] | media.processing.completed | \{\n  "mediaId": "uuid",\n  "processingStatus": "success | failed",\n  "ocrResults": {\n    "extractedText": "string",\n    "confidence": "float"\n  "\n}\n}\n} | mediaId | 3 attempts | FIFO per mediaId | Dead letter to DLQ with alert |

## Evidence Events

| Event Name | Version | Publisher | Consumers | Kafka Topic | Payload Schema | Idempotency Key | Retry Policy | Ordering Requirements | Dead Letter Strategy |
|------------|---------|-----------|-----------|-------------|----------------|------------------|--------------|-----------------------|----------------------|
| EvidenceSubmitted | 1.0.0 | EvidenceService | [VerificationService, AuditService, GPSService, AIService] | evidence.submitted | \{\n  "evidenceId": "uuid",\n  "submissionId": "uuid",\n  "type": "text | image | audio | video",\n  "url": "string",\n  "description": "string",\n  "timestamp": "ISO8601"\n}\n} | evidenceId | 3 attempts | Sequential by submissionId | Dead letter to DLQ with alert |
| EvidenceVerified | 1.0.0 | EvidenceService | [SubmissionService] | evidence.verified | \{\n  "evidenceId": "uuid",\n  "verificationStatus": "approved | rejected",\n  "rejectionReason": "string",\n  "approver": "string"\n}\n} | evidenceId | 2 attempts | FIFO per evidenceId | Dead letter to DLQ with alert |

## GPS Events

| Event Name | Version | Publisher | Consumers | Kafka Topic | Payload Schema | Idempotency Key | Retry Policy | Ordering Requirements | Dead Letter Strategy |
|------------|---------|-----------|-----------|-------------|----------------|------------------|--------------|-----------------------|----------------------|
| GPSEnabled | 1.0.0 | GPSService | [AIService, VerificationService] | gps.enabled | \{\n  "deviceId": "uuid",\n  "coordinates": {\n    "latitude": "float",\n    "longitude": "float"\n  "\n}\n}\n} | coordinates.timestamp | 3 attempts | Sequential by deviceId | Dead letter to DLQ with alert |
| GPSDisabled | 1.0.0 | GPSService | [AIService] | gps.disabled | \{\n  "deviceId": "uuid",\n  "reason": "string"\n}\n} | deviceId | 2 attempts | FIFO per deviceId | Dead letter to DLQ with alert |

## Verification Events

| Event Name | Version | Publisher | Consumers | Kafka Topic | Payload Schema | Idempotency Key | Retry Policy | Ordering Requirements | Dead Letter Strategy |
|------------|---------|-----------|-----------|-------------|----------------|------------------|--------------|-----------------------|----------------------|
| VerificationRequested | 1.0.0 | VerificationService | [AIService, GPSService, EvidenceService, AuditService] | verification.requested | \{\n  "requestId": "uuid",\n  "submissionId": "uuid",\n  "verificationType": "manual | automated",\n  "priority": "high | medium | low",\n  "requestedBy": "string"\n}\n} | requestId | 3 attempts | Sequential by submissionId | Dead letter to DLQ with alert |
| VerificationCompleted | 1.0.0 | VerificationService | [SubmissionService, AuditService] | verification.completed | \{\n  "requestId": "uuid",\n  "status": "passed | failed",\n  "failureReason": "string",\n  "score": "float",\n  verifier": "string"\n}\n} | requestId | 3 attempts | FIFO per requestId | Dead letter to DLQ with alert |
| VerificationFailed | 1.0.0 | VerificationService | [SubmissionService, AuditService] | verification.failed | \{\n  "requestId": "uuid",\n  "reason": "string",\n  "escalationRequired": "boolean"\n}\n} | requestId | 3 attempts | Sequential by submissionId | Dead letter to DLQ with alert |

## Audit Events

| Event Name | Version | Publisher | Consumers | Kafka Topic | Payload Schema | Idempotency Key | Retry Policy | Ordering Requirements | Dead Letter Strategy |
|------------|---------|-----------|-----------|-------------|----------------|------------------|--------------|-----------------------|----------------------|
| AuditLogCreated | 1.0.0 | AuditService | [AuditService] | audit.log.created | \{\n  "auditId": "uuid",\n  "submissionId": "uuid",\n  "action": "string",\n  "performedBy": "string",\n  "timestamp": "ISO8601",\n  "details": {"string": "string"}\n}\n} | auditId | 3 attempts | FIFO per submissionId | Dead letter to DLQ with alert |

## AI Events

| Event Name | Version | Publisher | Consumers | Kafka Topic | Payload Schema | Idempotency Key | Retry Policy | Ordering Requirements | Dead Letter Strategy |
|------------|---------|-----------|-----------|-------------|----------------|------------------|--------------|-----------------------|----------------------|
| AIProcessingRequested | 1.0.0 | AIService | [GPSService, EvidenceService] | ai.processing.requested | \{\n  "aiRequestId": "uuid",\n  "type": "ocr | content_analysis | fraud_detection",\n  "input": {"string": "any"},\n  "priority": "high | medium | low"\n}\n} | aiRequestId | 2 attempts | Sequential by priority | Dead letter to DLQ with alert |
| AIProcessingCompleted | 1.0.0 | AIService | [VerificationService] | ai.processing.completed | \{\n  "aiRequestId": "uuid",\n  "status": "success | failed",\n  "results": {"string": "any"},\n  "processingTime": "integer"\n}\n} | aiRequestId | 3 attempts | FIFO per aiRequestId | Dead letter to DLQ with alert |
| AIVerificationResult | 1.0.0 | AIService | [VerificationService] | ai.verification.result | \{\n  "verificationId": "uuid",\n  "submissionId": "uuid",\n  "confidence": "float",\n  "relevantEvidenceIds": ["uuid"],\n  "reasoning": "string"\n}\n} | verificationId | 3 attempts | Sequential by submissionId | Dead letter to DLQ with alert |

## Reputation Events

| Event Name | Version | Publisher | Consumers | Kafka Topic | Payload Schema | Idempotency Key | Retry Policy | Ordering Requirements | Dead Letter Strategy |
|------------|---------|-----------|-----------|-------------|----------------|------------------|--------------|-----------------------|----------------------|
| ReputationUpdated | 1.0.0 | ReputationService | [SubmissionService] | reputation.updated | \{\n  "userId": "uuid",\n  "score": "float",\n  "changeReason": "string",\n  "timestamp": "ISO8601"\n}\n} | userId + timestamp | 3 attempts | FIFO per userId | Dead letter to DLQ with alert |