"""Platform-wide constants for the MASAREN shared kernel.

These values are authoritative and must not be redefined in individual services.
"""
from enum import Enum


# ── Pagination defaults ───────────────────────────────────────────────────────
DEFAULT_PAGE_SIZE = 20
MAX_PAGE_SIZE = 100

# ── JWT ───────────────────────────────────────────────────────────────────────
JWT_ALGORITHM_HS256 = "HS256"
JWT_ALGORITHM_RS256 = "RS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60
REFRESH_TOKEN_EXPIRE_DAYS = 30

# ── Confidence scoring (Media Institutions Blueprint §2) ──────────────────────
CONFIDENCE_WEIGHT_SOURCE = 0.20
CONFIDENCE_WEIGHT_EVIDENCE = 0.22
CONFIDENCE_WEIGHT_CORROBORATION = 0.18
CONFIDENCE_WEIGHT_EDITORIAL = 0.15
CONFIDENCE_WEIGHT_TRANSPARENCY = 0.15
CONFIDENCE_WEIGHT_HISTORY = 0.10
CONFIDENCE_PENALTY_MAX = 1.0

# ── Feed ranking (Media Institutions Blueprint §2) ────────────────────────────
RANKING_WEIGHT_USER_VALUE = 0.24
RANKING_WEIGHT_QUALITY = 0.16
RANKING_WEIGHT_FRESHNESS = 0.14
RANKING_WEIGHT_CONFIDENCE = 0.13
RANKING_WEIGHT_DIVERSITY = 0.10
RANKING_WEIGHT_LOCAL = 0.09
RANKING_WEIGHT_NOVELTY = 0.08
RANKING_WEIGHT_PUBLIC_SERVICE = 0.06

# ── Post types ────────────────────────────────────────────────────────────────
class PostType(str, Enum):
    ARTICLE = "ARTICLE"
    IMAGE = "IMAGE"
    VIDEO = "VIDEO"
    STORY = "STORY"
    RECOGNITION = "RECOGNITION"
    EVIDENCE = "EVIDENCE"


# ── Sports passport domains (Sports Profiling Blueprint §2) ───────────────────
class SportDomain(str, Enum):
    IDENTITY = "identity"
    REGISTRATION = "registration"
    TEAM = "team"
    COMPETITION = "competition"
    PERFORMANCE = "performance"
    DEVELOPMENT = "development"
    HEALTH = "health"
    MEDIA = "media"
    IMPACT = "impact"


# ── Welfare visibility (Sports Profiling Blueprint §2) ────────────────────────
class WelfareStatus(str, Enum):
    ELIGIBLE = "eligible"
    TEMPORARILY_UNAVAILABLE = "temporarily_unavailable"
    CLEARANCE_REQUIRED = "clearance_required"


# ── Rate limiting ─────────────────────────────────────────────────────────────
RATE_LIMIT_AUTH = 10          # requests per minute per IP
RATE_LIMIT_API = 200          # requests per minute per user
RATE_LIMIT_POST_CREATE = 10   # posts per minute per user

# ── Redis key prefixes ────────────────────────────────────────────────────────
REDIS_KEY_SESSION = "session"
REDIS_KEY_RATE_LIMIT = "rl"
REDIS_KEY_FEED_CACHE = "feed"
REDIS_KEY_PROFILE_CACHE = "profile"
