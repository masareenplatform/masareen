# OpenAPI Index - Verification Domain

This document lists all REST endpoints across the Verification Domain services.

## Submission Service Endpoints

### Authentication
| Method | Path | Description |
|--------|------|-------------|
| POST | /api/v1/auth/login | Authenticate and generate JWT token |

### Submissions
| Method | Path | Description | Request Body | Response Body |
|--------|------|-------------|--------------|---------------|
| POST | /api/v1/submissions | Create new submission | SubmissionCreateRequest | SubmissionResponse |
| GET | /api/v1/submissions | List submissions | - | ListSubmissionResponse |
| GET | /api/v1/submissions/{id} | Get submission details | - | SubmissionResponse |
| PUT | /api/v1/submissions/{id} | Update submission | SubmissionUpdateRequest | SubmissionResponse |
| DELETE | /api/v1/submissions/{id} | Cancel submission | - | SimpleResponse |

### Webhooks
| Method | Path | Description | Request Body |
|--------|------|-------------|--------------|
| POST | /api/v1/webhooks/events | Process webhook events | WebhookEvent |

## Media Service Endpoints

### Media Operations
| Method | Path | Description | Request Body | Response Body |
|--------|------|-------------|--------------|---------------|
| POST | /api/v1/media/upload | Upload media file | MediaUploadRequest | MediaUploadResponse |
| GET | /api/v1/media/{id} | Get media details | - | MediaResponse |
| PUT | /api/v1/media/{id}/process | Start processing | - | ProcessingResponse |
| GET | /api/v1/media/{id}/status | Get processing status | - | ProcessingStatusResponse |

### Presigned URLs
| Method | Path | Description | Request Body |
|--------|------|-------------|--------------|
| POST | /api/v1/media/presigned-url | Generate presigned URL | PresignedUrlRequest |

## Evidence Service Endpoints

### Evidence Operations
| Method | Path | Description | Request Body | Response Body |
|--------|------|-------------|--------------|---------------|
| POST | /api/v1/evidence | Submit evidence | EvidenceCreateRequest | EvidenceResponse |
| GET | /api/v1/evidence | List evidence | - | ListEvidenceResponse |
| GET | /api/v1/evidence/{id} | Get evidence details | - | EvidenceResponse |
| PUT | /api/v1/evidence/{id}/verify | Start verification | - | VerificationResponse |
| GET | /api/v1/evidence/{id}/status | Get verification status | - | EvidenceStatusResponse |

### Evidence Tags
| Method | Path | Description | Request Body |
|--------|------|-------------|--------------|
| POST | /api/v1/evidence/{id}/tags | Add tags to evidence | EvidenceTagsRequest |
| DELETE | /api/v1/evidence/{id}/tags/{tag} | Remove tag from evidence | - |

## GPS Service Endpoints

### GPS Operations
| Method | Path | Description | Request Body | Response Body |
|--------|------|-------------|--------------|---------------|
| POST | /api/v1/gps/enable | Enable GPS device | GPSDeviceRequest | GPSResponse |
| GET | /api/v1/gps/{deviceId} | Get GPS coordinates | - | GPSResponse |
| DELETE | /api/v1/gps/{deviceId} | Disable GPS device | - | SimpleResponse |
| GET | /api/v1/gps/{deviceId}/history | Get GPS history | - | GPSHistoryResponse |

### GPS Configuration
| Method | Path | Description | Request Body |
|--------|------|-------------|--------------|
| PUT | /api/v1/gps/{deviceId}/settings | Update GPS settings | GPSSettingsRequest |

## AI Service Endpoints

### AI Processing
| Method | Path | Description | Request Body | Response Body |
|--------|------|-------------|--------------|---------------|
| POST | /api/v1/ai/requests | Create AI processing request | AIRequestCreate | AIRequestResponse |
| GET | /api/v1/ai/requests/{id} | Get AI request status | - | AIRequestResponse |
| PUT | /api/v1/ai/requests/{id}/process | Process AI request | - | ProcessingResponse |
| POST | /api/v1/ai/verify | Submit AI verification result | AIVerificationRequest | AIVerificationResponse |

### AI Templates
| Method | Path | Description | Request Body |
|--------|------|-------------|--------------|
| GET | /api/v1/ai/templates | List AI templates | - |
| POST | /api/v1/ai/templates | Create AI template | AITemplateCreate |

## Audit Service Endpoints

### Audit Logs
| Method | Path | Description | Request Body | Response Body |
|--------|------|-------------|--------------|---------------|
| POST | /api/v1/audit/logs | Create audit entry | AuditLogRequest | AuditLogResponse |
| GET | /api/v1/audit/logs | List audit logs | - | ListAuditLogResponse |
| GET | /api/v1/audit/logs/{id} | Get audit log details | - | AuditLogResponse |

### Audit Search
| Method | Path | Description | Request Body |
|--------|------|-------------|--------------|
| GET | /api/v1/audit/search | Search audit logs | SearchFilters |

## Reputation Service Endpoints

### Reputation Operations
| Method | Path | Description | Request Body | Response Body |
|--------|------|-------------|--------------|---------------|
| GET | /api/v1/reputations/{userId} | Get user reputation | - | ReputationResponse |
| POST | /api/v1/reputations/{userId}/update | Update reputation | ReputationUpdateRequest | ReputationUpdateResponse |

### Reputation Categories
| Method | Path | Description | Request Body |
|--------|------|-------------|--------------|
| GET | /api/v1/reputations/categories | List reputation categories | - |

## Health Check Endpoints

### System Health
| Method | Path | Description |
|--------|------|-------------|
| GET | /health | System health check |
| GET | /ready | Readiness probe |
| GET | /metrics | Prometheus metrics |

### Service Health
| Method | Path | Description |
|--------|------|-------------|
| GET | /api/v1/health/submission | Submission Service health |
| GET | /api/v1/health/media | Media Service health |
| GET | /api/v1/health/evidence | Evidence Service health |
| GET | /api/v1/health/gps | GPS Service health |
| GET | /api/v1/health/ai | AI Service health |
| GET | /api/v1/health/audit | Audit Service health |
| GET | /api/v1/health/reputation | Reputation Service health |

## Error Handling

### Common Error Responses
| HTTP Status | Description |
|-------------|-------------|
| 400 | Bad Request - Invalid request format |
| 401 | Unauthorized - Invalid credentials |
| 403 | Forbidden - Insufficient permissions |
| 404 | Not Found - Resource not found |
| 429 | Too Many Requests - Rate limit exceeded |
| 500 | Internal Server Error - Unexpected error |
| 503 | Service Unavailable - Service down for maintenance |