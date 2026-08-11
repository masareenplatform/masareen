# Service Contracts

## Submission Service Contract

### Owned Database Tables

| Table Name | Primary Key | Owner | Description |
|------------|-------------|-------|-------------|
| submissions | submission_id | SubmissionService | Contains all submission data |

### Owned Aggregates

1. **SubmissionAggregate**
   - Represents a complete submission with all its metadata and associated media
   - State transitions: Draft → Submitted → InProgress → Completed

### REST APIs

| Method | Path | Description | Produces | Consumes |
|--------|------|-------------|----------|----------|
| POST | /api/v1/submissions | Create new submission | SubmissionCreated event | SubmissionCreateRequest |
| GET | /api/v1/submissions/{id} | Get submission details | SubmissionResponse | - |
| PUT | /api/v1/submissions/{id} | Update submission | SubmissionUpdated event | SubmissionUpdateRequest |
| DELETE | /api/v1/submissions/{id} | Cancel submission | SubmissionCancelled event | - |

### Published Events

| Event | Schema | Timestamps |
|-------|--------|------------|
| SubmissionCreated | \{\n  "submissionId": "uuid",\n  "proofUrl": "string",\n  "description": "string",\n  "visibilityLevel": "public | private",\n  "contactInfo": {\n    "email": "string",\n    "phone": "string"\n  "\n}\n}\n} | Published when submission is created |
| SubmissionUpdated | \{\n  "submissionId": "uuid",\n  "field": "string",\n  "value": "string"\n}\n} | Published when submission is updated |
| SubmissionCancelled | \{\n  "submissionId": "uuid",\n  "reason": "string"\n}\n} | Published when submission is cancelled |

### Consumed Events

| Event | From Service | Condition | Action |
|-------|--------------|----------|--------|
| EvidenceVerified | EvidenceService | When evidence is verified | Update submission status |
| VerificationCompleted | VerificationService | When verification completes | Update submission status |
| AIVerificationResult | AIService | When AI verification completes | Update submission status |

### External Dependencies

| Service | Dependency | Reason |
|---------|-----------|--------|
| SubmissionService | MediaService | Upload and store media files |
| SubmissionService | VerificationService | Initiate and track verification |
| SubmissionService | AuditService | Create audit trails |
| SubmissionService | ReputationService | Update reputation scores |

### Forbidden Dependencies

- Must not directly access EvidenceService database
- Must not directly access VerificationService database
- Must not implement verification logic directly

## Media Service Contract

### Owned Database Tables

| Table Name | Primary Key | Owner | Description |
|------------|-------------|-------|-------------|
| media_files | media_id | MediaService | Contains metadata for all uploaded media |

### Owned Aggregates

1. **MediaAggregate**
   - Manages media upload, processing, and storage
   - State transitions: Uploaded → Processing → Processed

### REST APIs

| Method | Path | Description | Produces | Consumes |
|--------|------|-------------|----------|----------|
| POST | /api/v1/media/upload | Upload media file | MediaUploaded event | MediaUploadRequest |
| GET | /api/v1/media/{id} | Get media details | MediaResponse | - |
| PUT | /api/v1/media/{id}/process | Start processing | MediaProcessingCompleted event | - |

### Published Events

| Event | Schema | Timestamps |
|-------|--------|------------|
| MediaUploaded | \{\n  "mediaId": "uuid",\n  "submissionId": "uuid",\n  "fileName": "string",\n  "storageProvider": "s3 | gcs",\n  "fileSize": "integer",\n  "mimeType": "string"\n}\n} | Published when media is uploaded |
| MediaProcessingCompleted | \{\n  "mediaId": "uuid",\n  "processingStatus": "success | failed",\n  "ocrResults": {\n    "extractedText": "string",\n    "confidence": "float"\n  "\n}\n}\n} | Published when processing completes |

### Consumed Events

| Event | From Service | Condition | Action |
|-------|--------------|----------|--------|
| SubmissionCreated | SubmissionService | When submission is created | Prepare media upload |
| EvidenceSubmitted | EvidenceService | When evidence is submitted | Associate media |

### External Dependencies

| Service | Dependency | Reason |
|---------|-----------|--------|
| MediaService | StorageProvider (S3/GCS) | Store media files |
| MediaService | EvidenceService | Associate media with evidence |

### Forbidden Dependencies

- Must not directly access SubmissionService database
- Must not implement evidence logic directly

## Evidence Service Contract

### Owned Database Tables

| Table Name | Primary Key | Owner | Description |
|------------|-------------|-------|-------------|
| evidence | evidence_id | EvidenceService | Contains all evidence data |

### Owned Aggregates

1. **EvidenceAggregate**
   - Manages evidence submission and verification
   - State transitions: Draft → Submitted → UnderReview → Verified

### REST APIs

| Method | Path | Description | Produces | Consumes |
|--------|------|-------------|----------|----------|
| POST | /api/v1/evidence | Submit evidence | EvidenceSubmitted event | EvidenceCreateRequest |
| GET | /api/v1/evidence/{id} | Get evidence details | EvidenceResponse | - |
| PUT | /api/v1/evidence/{id}/verify | Start verification | EvidenceVerified event | - |

### Published Events

| Event | Schema | Timestamps |
|-------|--------|------------|
| EvidenceSubmitted | \{\n  "evidenceId": "uuid",\n  "submissionId": "uuid",\n  "type": "text | image | audio | video",\n  "url": "string",\n  "description": "string",\n  "timestamp": "ISO8601"\n}\n} | Published when evidence is submitted |
| EvidenceVerified | \{\n  "evidenceId": "uuid",\n  "verificationStatus": "approved | rejected",\n  "rejectionReason": "string",\n  "approver": "string"\n}\n} | Published when evidence is verified |

### Consumed Events

| Event | From Service | Condition | Action |
|-------|--------------|----------|--------|
| SubmissionCreated | SubmissionService | When submission is created | Prepare evidence submission |
| VerificationRequested | VerificationService | When verification is requested | Collect evidence |
| GPSEnabled | GPSService | When GPS is available | Add location to evidence |
| AIProcessingCompleted | AIService | When AI processing completes | Enhance evidence |

### External Dependencies

| Service | Dependency | Reason |
|---------|-----------|--------|
| EvidenceService | StorageProvider | Store evidence files |
| EvidenceService | MediaService | Upload media as evidence |
| EvidenceService | AIService | Process evidence content |

### Forbidden Dependencies

- Must not directly access SubmissionService database
- Must not directly access VerificationService database

## GPS Service Contract

### Owned Database Tables

| Table Name | Primary Key | Owner | Description |
|------------|-------------|-------|-------------|
| gps_records | device_id | GPSService | Contains GPS location data |

### Owned Aggregates

1. **GPSDeviceAggregate**
   - Manages GPS device status and coordinates
   - State transitions: Disabled → Initializing → Enabled → Disabled

### REST APIs

| Method | Path | Description | Produces | Consumes |
|--------|------|-------------|----------|----------|
| POST | /api/v1/gps/enable | Enable GPS device | GPSEnabled event | GPSDeviceRequest |
| GET | /api/v1/gps/{deviceId} | Get GPS coordinates | GPSResponse | - |
| DELETE | /api/v1/gps/{deviceId} | Disable GPS device | GPSDisabled event | - |

### Published Events

| Event | Schema | Timestamps |
|-------|--------|------------|
| GPSEnabled | \{\n  "deviceId": "uuid",\n  "coordinates": {\n    "latitude": "float",\n    "longitude": "float"\n  "\n}\n}\n} | Published when GPS is enabled |
| GPSDisabled | \{\n  "deviceId": "uuid",\n  "reason": "string"\n}\n} | Published when GPS is disabled |

### Consumed Events

| Event | From Service | Condition | Action |
|-------|--------------|----------|--------|
| AIProcessingRequested | AIService | When AI processing requires location | Provide GPS data |
| EvidenceSubmitted | EvidenceService | When evidence requires location | Provide GPS data |

### External Dependencies

| Service | Dependency | Reason |
|---------|-----------|--------|
| GPSService | DeviceManager | Control GPS hardware |
| GPSService | AIService | Provide location for AI analysis |

### Forbidden Dependencies

- Must not directly access EvidenceService database
- Must not directly access AIService database

## Verification Service Contract

### Owned Database Tables

| Table Name | Primary Key | Owner | Description |
|------------|-------------|-------|-------------|
| verifications | request_id | VerificationService | Contains all verification requests |

### Owned Aggregates

1. **VerificationAggregate**
   - Manages the verification workflow
   - State transitions: Requested → InProgress → Completed → Failed

### REST APIs

| Method | Path | Description | Produces | Consumes |
|--------|------|-------------|----------|----------|
| POST | /api/v1/verifications | Request verification | VerificationRequested event | VerificationRequest |
| GET | /api/v1/verifications/{id} | Get verification status | VerificationResponse | - |
| PUT | /api/v1/verifications/{id}/complete | Complete verification | VerificationCompleted event | VerificationResult |
| DELETE | /api/v1/verifications/{id}/fail | Fail verification | VerificationFailed event | FailureReason |

### Published Events

| Event | Schema | Timestamps |
|-------|--------|------------|
| VerificationRequested | \{\n  "requestId": "uuid",\n  "submissionId": "uuid",\n  "verificationType": "manual | automated",\n  "priority": "high | medium | low",\n  "requestedBy": "string"\n}\n} | Published when verification is requested |
| VerificationCompleted | \{\n  "requestId": "uuid",\n  "status": "passed | failed",\n  "failureReason": "string",\n  "score": "float",\n  "verifier": "string"\n}\n} | Published when verification completes |
| VerificationFailed | \{\n  "requestId": "uuid",\n  "reason": "string",\n  "escalationRequired": "boolean"\n}\n} | Published when verification fails |

### Consumed Events

| Event | From Service | Condition | Action |
|-------|--------------|----------|--------|
| SubmissionCreated | SubmissionService | When submission is created | Create verification request |
| EvidenceSubmitted | EvidenceService | When all evidence is available | Create verification request |
| GPSEnabled | GPSService | When GPS is available | Include location in verification |
| AIProcessingCompleted | AIService | When AI processing completes | Include AI results |
| VerificationCompleted | - | - | Update submission status |
| VerificationFailed | - | - | Update submission status |

### External Dependencies

| Service | Dependency | Reason |
|---------|-----------|--------|
| VerificationService | AIService | Process verification data |
| VerificationService | EvidenceService | Collect verification evidence |
| VerificationService | GPSService | Include location data |
| VerificationService | AuditService | Create audit trails |

### Forbidden Dependencies

- Must not directly access SubmissionService database
- Must not directly access EvidenceService database

## Audit Service Contract

### Owned Database Tables

| Table Name | Primary Key | Owner | Description |
|------------|-------------|-------|-------------|
| audit_logs | audit_id | AuditService | Contains all audit entries |

### Owned Aggregates

1. **AuditLogAggregate**
   - Manages audit logging for all operations
   - State transitions: Submitted → Logged

### REST APIs

| Method | Path | Description | Produces | Consumes |
|--------|------|-------------|----------|----------|
| POST | /api/v1/audit/logs | Create audit entry | AuditLogCreated event | AuditLogRequest |
| GET | /api/v1/audit/logs | List audit logs | AuditLogResponse | - |
| GET | /api/v1/audit/logs/{id} | Get audit log details | AuditLogResponse | - |

### Published Events

| Event | Schema | Timestamps |
|-------|--------|------------|
| AuditLogCreated | \{\n  "auditId": "uuid",\n  "submissionId": "uuid",\n  "action": "string",\n  "performedBy": "string",\n  "timestamp": "ISO8601",\n  "details": {"string": "string"}\n}\n} | Published when audit log is created |

### Consumed Events

| Event | From Service | Condition | Action |
|-------|--------------|----------|--------|
| SubmissionCreated | SubmissionService | When submission is created | Log creation |
| SubmissionUpdated | SubmissionService | When submission is updated | Log update |
| SubmissionCancelled | SubmissionService | When submission is cancelled | Log cancellation |
| EvidenceSubmitted | EvidenceService | When evidence is submitted | Log submission |
| EvidenceVerified | EvidenceService | When evidence is verified | Log verification |
| VerificationRequested | VerificationService | When verification is requested | Log request |
| VerificationCompleted | VerificationService | When verification completes | Log completion |
| VerificationFailed | VerificationService | When verification fails | Log failure |
| AIVerificationResult | AIService | When AI verification completes | Log result |
| ReputationUpdated | ReputationService | When reputation is updated | Log update |

### External Dependencies

| Service | Dependency | Reason |
|---------|-----------|--------|
| AuditService | All Services | Log all operations |

### Forbidden Dependencies

- Must not directly access any other service's database (audit logs are isolated)

## AI Service Contract

### Owned Database Tables

| Table Name | Primary Key | Owner | Description |
|------------|-------------|-------|-------------|
| ai_requests | ai_request_id | AIService | Contains all AI processing requests |

### Owned Aggregates

1. **AIRequestAggregate**
   - Manages AI processing workflows
   - State transitions: Requested → Processing → Completed → Failed

### REST APIs

| Method | Path | Description | Produces | Consumes |
|--------|------|-------------|----------|----------|
| POST | /api/v1/ai/requests | Create AI processing request | AIProcessingRequested event | AIRequestCreate |
| GET | /api/v1/ai/requests/{id} | Get AI request status | AIRequestResponse | - |
| PUT | /api/v1/ai/requests/{id}/process | Process AI request | AIProcessingCompleted event | - |
| POST | /api/v1/ai/verify | Submit AI verification result | AIVerificationResult event | AIVerificationResult |

### Published Events

| Event | Schema | Timestamps |
|-------|--------|------------|
| AIProcessingRequested | \{\n  "aiRequestId": "uuid",\n  "type": "ocr | content_analysis | fraud_detection",\n  "input": {"string": "any"},\n  "priority": "high | medium | low"\n}\n} | Published when AI processing is requested |
| AIProcessingCompleted | \{\n  "aiRequestId": "uuid",\n  "status": "success | failed",\n  "results": {"string": "any"},\n  "processingTime": "integer"\n}\n} | Published when AI processing completes |
| AIVerificationResult | \{\n  "verificationId": "uuid",\n  "submissionId": "uuid",\n  "confidence": "float",\n  "relevantEvidenceIds": ["uuid"],\n  "reasoning": "string"\n}\n} | Published when AI verification completes |

### Consumed Events

| Event | From Service | Condition | Action |
|-------|---------------|----------|--------|
| VerificationRequested | VerificationService | When verification is requested | Process with AI |
| GPSEnabled | GPSService | When location is available | Include in processing |
| EvidenceSubmitted | EvidenceService | When evidence is available | Process evidence |
| VerificationCompleted | - | - | Log for downstream |

### External Dependencies

| Service | Dependency | Reason |
|---------|-----------|--------|
| AIService | EvidenceService | Access evidence for processing |
| AIService | GPSService | Include location data |
| AIService | VerificationService | Send results |

### Forbidden Dependencies

- Must not directly access SubmissionService database
- Must not directly access EvidenceService database
- Must not directly access VerificationService database

## Reputation Service Contract

### Owned Database Tables

| Table Name | Primary Key | Owner | Description |
|------------|-------------|-------|-------------|
| reputations | user_id | ReputationService | Contains all user reputation data |

### Owned Aggregates

1. **ReputationAggregate**
   - Manages user reputation scores
   - State transitions: Updated

### REST APIs

| Method | Path | Description | Produces | Consumes |
|--------|------|-------------|----------|----------|
| GET | /api/v1/reputations/{userId} | Get user reputation | ReputationResponse | - |
| POST | /api/v1/reputations/{userId}/update | Update reputation | ReputationUpdated event | ReputationUpdateRequest |

### Published Events

| Event | Schema | Timestamps |
|-------|--------|------------|
| ReputationUpdated | \{\n  "userId": "uuid",\n  "score": "float",\n  "changeReason": "string",\n  "timestamp": "ISO8601"\n}\n} | Published when reputation is updated |

### Consumed Events

| Event | From Service | Condition | Action |
|-------|--------------|----------|--------|
| SubmissionCreated | SubmissionService | When submission is created | Update reputation |
| SubmissionUpdated | SubmissionService | When submission is updated | Update reputation |

### External Dependencies

| Service | Dependency | Reason |
|---------|-----------|--------|
| ReputationService | SubmissionService | Track submission activity |

### Forbidden Dependencies

- Must not directly access any other service's database except through events