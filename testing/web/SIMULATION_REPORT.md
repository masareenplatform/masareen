# MASAREN Web, Comprehensive Simulation Report

**Generated:** 2026-07-10T19:36:43.281Z
**Overall verdict:** **GREEN**

| Metric | Value |
|---|---|
| Routes visited | 21 |
| Routes rendered OK | 21 |
| Routes with console errors | 0 |
| Feature interactions run | 23 |
| Feature interactions passed | 23 |
| Features covered (pass/total) | 24/24 |

## Feature coverage matrix

| Feature | Status |
|---|---|
| Auth / Login | ✅ PASS |
| Dashboard | ✅ PASS |
| Feed / Compose post | ✅ PASS |
| Feed / React | ✅ PASS |
| Programs / Create | ✅ PASS |
| Tasks / Create | ✅ PASS |
| Tasks / Lifecycle | ✅ PASS |
| Opportunities / Marketplace apply | ✅ PASS |
| Collaborate / Partner submit | ✅ PASS |
| Chat / Messaging | ✅ PASS |
| Notifications / Mark read | ✅ PASS |
| Wallet / Coin convert | ✅ PASS |
| Wallet / Coin transfer | ✅ PASS |
| Ads / Create campaign | ✅ PASS |
| Ads / Impression tracking | ✅ PASS |
| Payments / Paymob intent | ✅ PASS |
| Revenue / Admin fee update | ✅ PASS |
| Admin / HITL verification | ✅ PASS |
| Evidence / Capture | ✅ PASS |
| Reports / Analytics | ✅ PASS |
| Billing / Subscription plans | ✅ PASS |
| Profile | ✅ PASS |
| Passport / Impact | ✅ PASS |
| Portfolio | ✅ PASS |

## Route coverage

| Route | Rendered | h1 | Load(ms) | Nodes | Console errors |
|---|---|---|---|---|---|
| /login | ✅ | MASAREN | 1675 | 89 | 0 |
| /register | ✅ | MASAREN | 1369 | 231 | 0 |
| /dashboard | ✅ | Dashboard | 1374 | 494 | 0 |
| /feed | ✅ | Impact Discovery | 1366 | 1430 | 0 |
| /programs | ✅ | Programs | 1365 | 1680 | 0 |
| /tasks | ✅ | Tasks | 1361 | 1938 | 0 |
| /evidence | ✅ | Evidence | 1358 | 2184 | 0 |
| /passport | ✅ | Impact Passport | 1375 | 2421 | 0 |
| /opportunities | ✅ | Opportunity Marketplace | 1367 | 2689 | 0 |
| /collaborate | ✅ | Host your service on MASAREN | 1372 | 2962 | 0 |
| /portfolio | ✅ | Portfolio | 1363 | 3208 | 0 |
| /chat | ✅ | - | 1370 | 3430 | 0 |
| /admin | ✅ | HITL Verification Queue | 1369 | 3663 | 0 |
| /notifications | ✅ | Notifications | 1372 | 3890 | 0 |
| /reports | ✅ | Platform Analytics | 1375 | 4129 | 0 |
| /billing | ✅ | Billing & Subscription | 1372 | 4374 | 0 |
| /profile | ✅ | Admin User | 1364 | 4649 | 0 |
| /wallet | ✅ | MASAREN Coin Wallet | 1371 | 4999 | 0 |
| /ads | ✅ | Ads Manager | 1374 | 5300 | 0 |
| /payments | ✅ | Payments | 1362 | 5608 | 0 |
| /revenue | ✅ | Profit & Fees | 1367 | 5674 | 0 |

## Interaction tests

| Interaction | Route | Status | Detail |
|---|---|---|---|
| auth_login_flow | /login | ✅ | logged in -> redirected to dashboard |
| feed_compose | /feed | ✅ | post authored and appeared in feed |
| feed_react | /feed | ✅ | react toggled (482 -> 483) |
| programs_create | /programs | ✅ | program created via API and shown in web list |
| tasks_create | /tasks | ✅ | task created via API and shown in web list |
| tasks_lifecycle | /tasks | ✅ | assign/start/submit/complete all 200 OK |
| opportunities_apply | /opportunities | ✅ | applied to opportunity -> button shows 'Applied' |
| collaborate_submit | /collaborate | ✅ | partner hosting request submitted |
| chat_send | /chat | ✅ | message sent and visible in conversation |
| notifications_read | /notifications | ✅ | notification marked read (button removed) |
| wallet_convert | /wallet | ✅ | converted 100 EGP -> MRC with platform brokerage fee deducted |
| wallet_transfer | /wallet | ✅ | transferred 50 MRC to u_vol with platform brokerage fee deducted |
| ads_create | /ads | ✅ | campaign created (1000 MRC budget, 2.5% brokerage fee) |
| ads_impression | /ads | ✅ | impression recorded against active campaign |
| payments_intent | /payments | ✅ | Paymob payment intent created (order 999) |
| revenue_fee_update | /revenue | ✅ | admin updated brokerage fee to 5% |
| admin_hitl_resolve | /admin | ✅ | pending HITL review approved and cleared from queue |
| evidence_capture | /evidence | ✅ | evidence capture submitted for task tk1 |
| reports_analytics | /reports | ✅ | platform analytics (evidence/programs/impact) rendered |
| billing_plans | /billing | ✅ | billing page renders current plan + available plans |
| profile_view | /profile | ✅ | personal profile rendered (name/email/role/PMS) |
| passport_view | /passport | ✅ | impact passport rendered (PMS score + tier) |
| portfolio_view | /portfolio | ✅ | portfolio metrics rendered (evidence/tasks/programs/impact) |

## Notes
- **Billing, payments & wallets** fully exercised: wallet convert + transfer both apply the 2.5% platform brokerage fee; Paymob intent + Stripe/Paymob PSP status rendered; billing plans shown.
- **Feed algorithm**: items arrive pre-ranked by confidence score (descending); the web renders them in that order and exposes a per-item "Confidence: NN%", verified non-increasing.
- **Reacts**: the like button toggles 🤍 → ❤️ client-side. **Comments** are display-only counts in the current web build (no post/comment compose UI exists in the web client, consumption-only feed).
- **Create program / task / post**: the web pages are read-only dashboards, so creation is driven through the API contract (exactly as the mobile client does) and the web list is re-verified to reflect the new item. (The web has no program/task/post compose form.)
- **Opportunities / marketplace**: apply flow works end-to-end (button flips to "Applied").
- **Admin HITL**: approving a pending review removes it from the queue (stateful mock).
- Run offline against an in-process stateful mock gateway (no Docker required). Re-run against a live gateway for true E2E.