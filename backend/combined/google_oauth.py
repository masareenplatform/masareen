"""Google OAuth endpoint for the combined MASAREEN backend.

Flow (client-side popup):
  1. Frontend opens Google's OAuth consent in a popup.
  2. Google redirects back with an `id_token` (JWT) + `access_token`.
  3. Frontend posts `{ id_token }` here.
  4. We verify the id_token with Google's tokeninfo endpoint, read the
     verified email / name, then find-or-create the user and issue a
     first-party MASAREEN JWT (same secret + shape as the password login).

No external crypto libs needed: Google's tokeninfo endpoint validates the
signature server-side. Good enough for the demo and for production behind a
real domain with the proper client id check below.
"""
from __future__ import annotations

import os
import uuid
import asyncio
from datetime import datetime, timezone
from typing import Optional

import httpx
from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, EmailStr

try:
    import asyncpg
except ImportError:  # pragma: no cover
    asyncpg = None

from shared.middleware import create_access_token, create_refresh_token

JWT_SECRET = os.getenv("JWT_SECRET", "masaren-alpha-change-me")
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
DB_DSN = os.getenv(
    "DATABASE_URL",
    "postgresql+asyncpg://masaren:masaren_password@localhost:5432/masaren",
).replace("postgresql+asyncpg://", "postgresql://")

# Accept the project's own Google client id(s); empty = accept any verified email.
GOOGLE_CLIENT_IDS = [
    c.strip()
    for c in os.getenv("GOOGLE_CLIENT_IDS", "").split(",")
    if c.strip()
]

router = APIRouter(prefix="/auth", tags=["Authentication"])


class GoogleAuthRequest(BaseModel):
    id_token: str
    full_name: Optional[str] = None
    audience: Optional[str] = "PROFESSIONAL"


async def _verify_google_id_token(id_token: str) -> dict:
    async with httpx.AsyncClient(timeout=10) as client:
        r = await client.get(
            "https://oauth2.googleapis.com/tokeninfo",
            params={"id_token": id_token},
        )
    if r.status_code != 200:
        raise HTTPException(status_code=401, detail="Invalid Google token.")
    info = r.json()
    if info.get("email_verified") != "true" and info.get("email_verified") is not True:
        # Some responses return boolean, some string; normalise.
        if str(info.get("email_verified")).lower() != "true":
            raise HTTPException(status_code=401, detail="Google email not verified.")
    if GOOGLE_CLIENT_IDS and info.get("aud") not in GOOGLE_CLIENT_IDS:
        raise HTTPException(status_code=401, detail="Unknown Google client.")
    return info


async def _get_conn():
    return await asyncpg.connect(DB_DSN)


async def _find_or_create_user(info: dict) -> dict:
    email = info.get("email")
    name = info.get("name") or info.get("given_name") or email.split("@")[0]
    picture = info.get("picture")
    conn = await _get_conn()
    try:
        row = await conn.fetchrow("SELECT id, role, status FROM users WHERE email=$1", email)
        if row:
            uid = row["id"]
            await conn.execute(
                "UPDATE users SET email_verified=true WHERE id=$1", uid
            )
        else:
            uid = uuid.uuid4()
            # Random unusable password; Google users never use password login.
            import hashlib
            pw = hashlib.sha256(uuid.uuid4().bytes).hexdigest()
            from shared.middleware import pwd_context
            hashed = pwd_context.hash(pw)
            await conn.execute(
                """INSERT INTO users
                   (id, email, phone, full_name, role, status, hashed_password,
                    email_verified, phone_verified, pms_score, certificate_count,
                    impact_asset_count, version, created_at, updated_at)
                   VALUES ($1,$2,'',$3,'INDIVIDUAL','ACTIVE',$4,true,false,0,0,0,0,now(),now())""",
                uid, email, name, hashed,
            )
            await conn.execute(
                """INSERT INTO user_profiles
                   (id, user_id, bio, country, city, followers_count, following_count,
                    languages, gallery_ids, social_links, created_at)
                   VALUES ($1,$2,'',NULL,NULL,0,0,ARRAY['ar','en'],ARRAY[]::uuid[],$3,now())""",
                uuid.uuid4(), uid,
                '{"google_picture": "%s"}' % (picture or ""),
            )
        return {"id": uid, "email": email, "name": name, "picture": picture}
    finally:
        await conn.close()


@router.post("/google")
async def google_auth(body: GoogleAuthRequest, request: Request):
    if asyncpg is None:
        raise HTTPException(status_code=500, detail="DB driver unavailable.")
    info = await _verify_google_id_token(body.id_token)
    user = await _find_or_create_user(info)
    payload = type("P", (), {})()
    from shared.middleware import TokenPayload
    tp = TokenPayload(
        sub=str(user["id"]), email=user["email"], role="INDIVIDUAL", org_id=None
    )
    access_token = create_access_token(tp, JWT_SECRET, JWT_ALGORITHM)
    refresh_token = create_refresh_token(str(user["id"]), JWT_SECRET, JWT_ALGORITHM)
    return {
        "success": True,
        "data": {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "Bearer",
            "expires_in": 3600,
            "user_id": str(user["id"]),
            "role": "INDIVIDUAL",
            "email": user["email"],
            "full_name": user["name"],
            "picture": user.get("picture"),
        },
        "message": None,
        "errors": None,
        "meta": None,
    }
