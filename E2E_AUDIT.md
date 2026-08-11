# MASAREN Flutter E2E Audit (real backend)

Generated: 2026-07-13T08:45:08.9242809+02:00
Backend: real (docker compose, gateway :8080)

## Summary: 9 passed / 7 failed / 16 total

## Per-test results

| # | Flow | Result | Detail |
|---|------|--------|--------|
| 1 | audit_auth_persistence | PASS |  |
| 2 | audit_feed_reactions | FAIL | Assertion '"Verified by POAI Crew" is visible' failed. Check the UI hierarchy in debug artifacts to verify the element state and properties. |
| 3 | audit_opportunities | FAIL | Tap on "Explore"... FAILED |
| 4 | audit_profile_badges | FAIL | Assertion '"Sign Out" is visible' failed. Check the UI hierarchy in debug artifacts to verify the element state and properties. |
| 5 | audit_register | PASS |  |
| 6 | audit_splash_onboarding | PASS |  |
| 7 | audit_surface_adsmanager | PASS |  |
| 8 | audit_surface_collaborate | FAIL | Assertion '"Host on MASAREN" is visible' failed. Check the UI hierarchy in debug artifacts to verify the element state and properties. |
| 9 | audit_surface_dashboard | PASS |  |
| 10 | audit_surface_evidence | PASS |  |
| 11 | audit_surface_impactpassport | PASS |  |
| 12 | audit_surface_masarencoin | PASS |  |
| 13 | audit_surface_payments | FAIL | Tap on "Payments"... FAILED |
| 14 | audit_surface_platformrevenuefees | FAIL | Assertion '"Platform Revenue & Fees" is visible' failed. Check the UI hierarchy in debug artifacts to verify the element state and properties. |
| 15 | audit_surface_profile | FAIL | Assertion '"Personal Information" is visible' failed. Check the UI hierarchy in debug artifacts to verify the element state and properties. |
| 16 | audit_surface_settings | PASS |  |

## Backend service status

```nmasaren-kafka-1 Up 16 hours
masaren-postgres-1 Up 16 hours (healthy)
masaren-redis-1 Up 16 hours
masaren-zookeeper-1 Up 16 hours
```n
