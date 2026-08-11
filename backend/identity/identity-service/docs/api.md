# identity-service API Reference

Base URL: `https://api.masaren.io/identity/v1`

## Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/v1/users/register` | None | Register a new user |
| GET | `/api/v1/users/me` | Bearer | Get current user |
| PATCH | `/api/v1/users/me/profile` | Bearer | Update profile |
| POST | `/api/v1/users/me/skills` | Bearer | Add a skill |
| GET | `/api/v1/users/{user_id}` | Bearer | Get user by ID |
| GET | `/api/v1/users/{user_id}/impact-passport` | Bearer | Get Impact Passport |
| GET | `/api/v1/users/` | Admin | List all users |

## Impact Passport Tiers

| Tier | PMS Threshold | Verification Level |
|------|--------------|-------------------|
| BRONZE | 0.00 | L1 |
| SILVER | 0.40 | L1–2 |
| GOLD | 0.65 | L2–3 |
| PLATINUM | 0.85 | L3–5 |
