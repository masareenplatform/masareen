"""JWT auth dependency for the social-service.

Decodes the same bearer token the API gateway validates, so posts/likes/
bookmarks are correctly attributed to the requesting user. Falls back to the
gateway's dev default secret when JWT_SECRET is unset.
"""
from __future__ import annotations

import os

from shared.middleware import make_auth_dependency

JWT_SECRET = os.getenv("JWT_SECRET", "change-me-in-production")
JWT_ALGO = os.getenv("JWT_ALGORITHM", "HS256")

get_current_user = make_auth_dependency(JWT_SECRET, JWT_ALGO)
