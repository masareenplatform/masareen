# MASAREN API Contracts (v1.0)

This document defines the strict request/response schemas for the MASAREN BFF. Any changes to these contracts must be coordinated between the Backend and Mobile teams.

## 1. Authentication
### POST `/auth/login`
**Request:**
```json
{
  "email": "string",
  "password": "string"
}
```
**Response (200 OK):**
```json
{
  "status": "success",
  "data": {
    "access_token": "jwt_string",
    "user_id": "uuid",
    "user": {
      "id": "uuid",
      "email": "string",
      "role": "string"
    }
  }
}
```

## 2. Identity & Profiles
### GET `/users/me`
**Response (200 OK):**
```json
{
  "status": "success",
  "data": {
    "id": "uuid",
    "email": "string",
    "full_name": "string",
    "role": "string",
    "pms_score": 0.0,
    "created_at": "iso8601"
  }
}
```

## 3. Task Execution
### GET `/tasks`
**Response (200 OK):**
```json
{
  "status": "success",
  "data": [
    {
      "id": "uuid",
      "title": "string",
      "status": "PENDING|IN_PROGRESS|COMPLETED",
      "deadline": "iso8601",
      "sdg_mapping": ["string"],
      "assigned_to": "uuid"
    }
  ]
}
```

## 4. Verification Orchestrator (POAI)
### POST `/verify`
**Request:**
```json
{
  "evidence_id": "uuid"
}
```
**Response (202 Accepted):**
```json
{
  "status": "success",
  "data": {
    "job_id": "uuid",
    "status": "ACCEPTED",
    "message": "Verification crew initiated."
  }
}
```

### GET `/report/{evidence_id}`
**Response (200 OK):**
```json
{
  "status": "success",
  "data": "Full deliberative report text from POAI crew..."
}
```

## 5. Billing & Payments
### POST `/payments/intent`
**Request:**
```json
{
  "invoice_id": "uuid",
  "amount_usd": 0.0,
  "org_id": "uuid",
  "payment_method_id": "string"
}
```
**Response (201 Created):**
```json
{
  "status": "success",
  "data": {
    "payment_intent_id": "uuid",
    "amount": 0.0,
    "currency": "USD",
    "status": "PENDING"
  }
}
```
