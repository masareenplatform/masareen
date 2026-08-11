---
id: workflows
title: Platform Workflows
slug: /workflows
sidebar_position: 2
---

# MASAREEN Platform Workflows

This guide covers all major workflows in the MASAREEN platform, from registration to verification.

## Table of Contents

1. [User Registration & Onboarding](#1-user-registration--onboarding)
2. [Capturing Evidence](#2-capturing-evidence)
3. [Task Workflow](#3-task-workflow)
4. [Program Participation](#4-program-participation)
5. [Opportunity Marketplace](#5-opportunity-marketplace)
6. [Verification Process](#6-verification-process)
7. [Wallet & MASAREN Coin](#7-wallet--masaren-coin)
8. [Social Feed](#8-social-feed)
9. [Portfolio & Reputation](#9-portfolio--reputation)
10. [Admin Dashboard](#10-admin-dashboard)

---

## 1. User Registration & Onboarding

### For Individuals

1. **Navigate to `/login` or `/register`**
2. **Choose account type**: INDIVIDUAL (Professional, NGO, Student, Corporate)
3. **Complete profile**:
   - Full name
   - Email (valid verification required)
   - Password (min 8 chars, mixed case, digit, special char)
   - Audience/Role selection
4. **Verify email** (if not auto-verified)
5. **Complete onboarding** (optional profile setup)

### For Organizations

1. **Navigate to `/register`**
2. **Select ORGANIZATION audience**
3. **Provide**:
   - Organization name
   - Contact email
   - Description
   - SDG focus areas
4. **Submit for verification** (admin review required)

### Post-Registration

After registration, users land on the **Dashboard** with:
- Welcome message
- PMS (Proof-of-Mission Score) badge
- Quick stats overview
- Navigation to main features

---

## 2. Capturing Evidence

### Evidence Types

| Type | Description | Use Case |
|------|-------------|----------|
| Image | Photo with GPS | Field observations |
| Video | Short clips | Process documentation |
| Audio | Voice recordings | Community meetings |
| Document | PDFs, forms | Certificates, reports |
| GPS Track | Location history | Route verification |

### Capture Flow

1. **Navigate to `/evidence`**
2. **Click "Capture New"**
3. **Select evidence type**
4. **Capture/Upload media**:
   - Take photo or select from gallery
   - Add description
   - Attach to task or program
5. **Submit for verification**

### Verification Requirements

- GPS coordinates must match task location
- Image must be recent (within 24h)
- Video must show clear activity
- Documents must be legible

---

## 3. Task Workflow

### Task Lifecycle

```
PENDING → ASSIGNED → IN_PROGRESS → SUBMITTED → VERIFIED → COMPLETED
                             ↘ CANCELLED
```

### Complete Workflow

1. **View Tasks** (`/tasks`)
   - Filter by status: All, Assigned, Completed
   - Sort by due date, program, or SDG

2. **Accept Task** (if ASSIGNED)
   - Click "Start Task"
   - Confirm understanding

3. **Work on Task**
   - Complete field work
   - Capture evidence
   - Document progress

4. **Submit Task**
   - Go to `/tasks/[id]`
   - Click "Submit Evidence"
   - Upload all required media
   - Add completion notes

5. **Verification Review**
   - AI analyzes evidence
   - Human reviewer checks
   - Status updates to VERIFIED or REJECTED

6. **Complete**
   - Receive MRC reward
   - Update PMS score
   - Earn reputation points

### Example: Tree Planting Task

1. Task: "Plant 100 mangrove saplings"
2. Location: Nile Delta Coast
3. Evidence: 100 photos + GPS track
4. Verification: AI checks trees, human confirms GPS
5. Reward: 500 MRC + 50 PMS points

---

## 4. Program Participation

### Program Types

| Type | Focus | Duration | Benefits |
|------|-------|----------|----------|
| Restoration | Environment | 3-12 months | Certifications |
| Education | Youth | 6-24 months | Scholarships |
| Capacity | NGOs | 12+ months | Training |
| Research | Academia | 12+ months | Publications |

### Join a Program

1. **Browse Programs** (`/programs`)
2. **Apply to Program**:
   - Read description
   - Check SDG alignment
   - Click "Enroll"
3. **Receive Confirmation**
   - Access program resources
   - See assigned tasks
   - Join program group chat

### Program Dashboard

- Progress tracking
- Impact metrics
- Community feed
- Resource library
- Milestone badges

---

## 5. Opportunity Marketplace

### Opportunity Types

| Type | Description | Compensation |
|------|-------------|--------------|
| Field Work | On-site activities | MRC, cash |
| Remote | Desk-based tasks | MRC |
| Partnership | Org collaborations | Funding |
| Research | Data collection | MRC, credit |

### Find Opportunities

1. **Navigate to `/opportunities`**
2. **Filter by**:
   - Location
   - SDG goals
   - Program
   - Compensation
   - Skill requirements
3. **Apply**:
   - Submit application
   - Attach relevant experience
   - Wait for review

### Accept Opportunity

1. **Receive notification**
2. **Review details**:
   - Scope of work
   - Timeline
   - Requirements
3. **Accept & Enroll**
4. **Access opportunity resources**

---

## 6. Verification Process

### Two-Stage Verification

#### Stage 1: AI Analysis

- **Computer Vision**: Checks image authenticity, detects manipulation
- **GPS Validation**: Confirms location matches claimed site
- **Media Analysis**: Verifies video/audio integrity
- **Pattern Recognition**: Compares to known activity patterns

#### Stage 2: Human Review

- **Expert Review**: Domain specialists verify
- **Cross-Reference**: Checks against other evidence
- **Decision**: VERIFIED, REJECTED, or REQUEST MORE

### Verification Outcomes

| Outcome | Action | Reward |
|---------|--------|--------|
| VERIFIED | Task completed | Full MRC + PMS |
| PARTIAL | Some evidence valid | Partial reward |
| REJECTED | Evidence invalid | No reward |
| REQUEST MORE | Insufficient evidence | 24h extension |

### Appeal Process

1. **View rejection reason**
2. **Gather additional evidence**
3. **Submit appeal** (within 48h)
4. **Senior reviewer decision**

---

## 7. Wallet & MASAREN Coin

### MASAREN Coin (MRC)

MRC is the platform's utility token for:
- Task completion rewards
- Opportunity compensation
- Marketplace transactions
- Staking for benefits

### Wallet Features

1. **View Balance** (`/wallet`)
2. **Transaction History**
3. **Exchange Fiat** (EGP, USD)
4. **Transfer to Others**
5. **Stake for Benefits**

### Earning MRC

| Activity | Reward |
|----------|--------|
| Task completion | Variable |
| Evidence submission | 10-50 MRC |
| Community help | 5-20 MRC |
| Content creation | 100+ MRC |
| Program milestones | Bonus |

### Exchanging MRC

```
1 EGP = 10 MRC (configurable)
```

1. Navigate to `/wallet/exchange`
2. Enter amount
3. Select direction (deposit/withdraw)
4. Confirm transaction

---

## 8. Social Feed

### Feed Types

1. **For You** - Personalized content
2. **Impact** - Verified achievements
3. **Programs** - Program updates
4. **Evidence** - New submissions
5. **Saved** - Bookmarked posts

### Posting

1. **Click Composer** (center of feed)
2. **Create post**:
   - Text content
   - Add media (image/video/audio)
   - Tag program or opportunity
3. **Submit** → enters moderation queue

### Engagement

- **Like**: Show support
- **Comment**: Discuss
- **Share**: Spread impact
- **Save**: Bookmark for later

### Post Types

| Type | Purpose | Verification |
|------|---------|--------------|
| Impact | Completed work | Auto-verified |
| Story | Personal journey | Optional |
| Program | Organization update | Verified |
| Evidence | New submission | Pending |

---

## 9. Portfolio & Reputation

### PMS (Proof-of-Mission Score)

PMS is a 0-100 score representing your verified impact:

| Tier | Score Range | Benefits |
|------|-------------|----------|
| Bronze | 0-30 | Basic access |
| Silver | 31-60 | Higher opportunities |
| Gold | 61-85 | Premium tasks |
| Platinum | 86-100 | Elite programs |

### Portfolio View (`/portfolio`)

- **PMS Score & Tier**
- **Impact Assets** (verified work)
- **Participation History**
- **Achievements & Badges**
- **Recommendations**

### Building Reputation

1. **Complete tasks** → +PMS
2. **Submit quality evidence** → +PMS
3. **Help community** → +PMS
4. **Maintain verification rate** → Multiplier
5. **Longevity** → Stability bonus

---

## 10. Admin Dashboard

### Access

- Role: ADMIN or SUPER_ADMIN
- Path: `/admin`

### Features

#### 1. User Management

- View all users
- Verify organizations
- Manage roles
- View profiles

#### 2. Verification Review

- Pending evidence
- Review queue
- Make decisions
- Request more info

#### 3. Analytics

- Platform stats
- Impact metrics
- Revenue tracking
- User growth

#### 4. Billing

- Invoices
- Subscriptions
- Payments
- Revenue reports

#### 5. Content Moderation

- Reported posts
- Policy violations
- User warnings
- Account actions

---

## Quick Reference

### Common Paths

| Feature | Path | Auth Required |
|---------|------|---------------|
| Login | `/login` | No |
| Register | `/register` | No |
| Dashboard | `/dashboard` | Yes |
| Feed | `/feed` | Yes |
| Tasks | `/tasks` | Yes |
| Programs | `/programs` | Yes |
| Opportunities | `/opportunities` | Yes |
| Evidence | `/evidence` | Yes |
| Wallet | `/wallet` | Yes |
| Portfolio | `/portfolio` | Yes |
| Notifications | `/notifications` | Yes |
| Admin | `/admin` | Yes (Admin) |

### Support

- **Help Center**: `/resources`
- **Contact**: support@masaren.org
- **API Docs**: `/docs` (Swagger UI)
- **Status**: status.masaren.org

---

## Next Steps

- [Quickstart Guide](/docs/guides/quickstart)
- [Individual User Guide](/docs/guides/individual-user)
- [Organization Guide](/docs/guides/organization)
- [Evidence Submission Guide](/docs/guides/submit-evidence)