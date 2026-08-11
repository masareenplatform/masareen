# Database Ownership

## Evidence Table

| Column | Type | Nullable | Description | Owner |
|--------|------|----------|-------------|-------|
| evidence_id | UUID | PRIMARY | Unique identifier | EvidenceService |
| submission_id | UUID | FOREIGN | Reference to submission | EvidenceService |
| content_type | VARCHAR(50) | NOT NULL | text | image | audio | video | EvidenceService |
| storage_url | VARCHAR(500) | NOT NULL | Location of stored content | EvidenceService |
| description | TEXT | NULL | | EvidenceService |
| uploaded_at | TIMESTAMP | NOT NULL | | EvidenceService |
| verified_at | TIMESTAMP | NULL | | EvidenceService |
| verification_status | VARCHAR(20) | NOT NULL | pending | approved | rejected | EvidenceService |
| rejection_reason | TEXT | NULL | | EvidenceService |
| verifier | VARCHAR(100) | NULL | | EvidenceService |

## GPS Table

| Column | Type | Nullable | Description | Owner |
|--------|------|----------|-------------|-------|
| device_id | UUID | PRIMARY | Unique identifier | GPSService |
| latitude | DECIMAL(10,8) | NOT NULL | | GPSService |
| longitude | DECIMAL(11,8) | NOT NULL | | GPSService |
| altitude | FLOAT | NULL | | GPSService |
| accuracy | DECIMAL(10,8) | NULL | | GPSService |
| timestamp | TIMESTAMP | NOT NULL | | GPSService |
| device_status | VARCHAR(20) | NOT NULL | enabled | disabled | initializing | GPSService |

## verification Table

| Column | Type | Nullable | Description | Owner |
|--------|------|----------|-------------|-------|
| request_id | UUID | PRIMARY | Unique identifier | VerificationService |
| submission_id | UUID | FOREIGN | Reference to submission | VerificationService |
| verification_type | VARCHAR(20) | NOT NULL | manual | automated | VerificationService |
| status | VARCHAR(20) | NOT NULL | requested | in_progress | completed | failed | VerificationService |
| priority | VARCHAR(10) | NOT NULL | high | medium | low | VerificationService |
| requested_at | TIMESTAMP | NOT NULL | | VerificationService |
| completed_at | TIMESTAMP | NULL | | VerificationService |
| failure_reason | TEXT | NULL | | VerificationService |
| score | FLOAT | NULL | | VerificationService |
| verification_count | INTEGER | NOT NULL | Default: 0 | VerificationService |

## audit_logs Table

| Column | Type | Nullable | Description | Owner |
|--------|------|----------|-------------|-------|
| audit_id | UUID | PRIMARY | Unique identifier | AuditService |
| submission_id | UUID | NULL | Reference to submission | AuditService |
| action | VARCHAR(100) | NOT NULL | | AuditService |
| performed_by | VARCHAR(100) | NOT NULL | | AuditService |
| timestamp | TIMESTAMP | NOT NULL | | AuditService |
| details | JSONB | NULL | | AuditService |
| evidence_id | UUID | NULL | Reference to evidence | AuditService |
| verification_request_id | UUID | NULL | Reference to verification | AuditService |
| ai_request_id | UUID | NULL | Reference to AI processing | AuditService |

## ai_requests Table

| Column | Type | Nullable | Description | Owner |
|--------|------|----------|-------------|-------|
| ai_request_id | UUID | PRIMARY | Unique identifier | AIService |
| request_type | VARCHAR(50) | NOT NULL | ocr | content_analysis | fraud_detection | AIService |
| status | VARCHAR(20) | NOT NULL | requested | processing | completed | failed | AIService |
| requested_at | TIMESTAMP | NOT NULL | | AIService |
| completed_at | TIMESTAMP | NULL | | AIService |
| input_data | JSONB | NOT NULL | | AIService |
| output_data | JSONB | NULL | | AIService |
| processing_time | INTEGER | NULL | In milliseconds | AIService |
| failure_reason | TEXT | NULL | | AIService |
| priority | VARCHAR(10) | NOT NULL | high | medium | low | AIService |

## reputations Table

| Column | Type | Nullable | Description | Owner |
|--------|------|----------|-------------|-------|
| user_id | UUID | PRIMARY | Unique identifier | ReputationService |
| score | FLOAT | NOT NULL | Default: 0.0 | ReputationService |
| level | VARCHAR(20) | NOT NULL | bronze | silver | gold | platinum | ReputationService |
| total_submissions | INTEGER | NOT NULL | Default: 0 | ReputationService |
| successful_verifications | INTEGER | NOT NULL | Default: 0 | ReputationService |
| fraud_attempts | INTEGER | NOT NULL | Default: 0 | ReputationService |
| last_updated | TIMESTAMP | NOT NULL | | ReputationService |
| created_at | TIMESTAMP | NOT NULL | | ReputationService |