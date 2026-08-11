"""Seed posts for the social-service demo store.

Mirrors the shape returned by :func:`posts_service.src.service.to_dict` so the
web/mobile UIs render identically whether the data comes from here or the
previous client-side mock.

Each post carries a ``media`` list whose first item carries a ``type``
(image / video / audio / article / link) and a ``url`` so the Home feed can
render every post kind through one PostMedia widget. ``confidence`` is the
POAI verification score shown on the card.
"""
from __future__ import annotations

from datetime import datetime, timezone
from uuid import uuid4


def _ago(minutes: int) -> datetime:
    return datetime.fromtimestamp(datetime.now(timezone.utc).timestamp() - minutes * 60, timezone.utc)


def _id() -> str:
    return uuid4().hex


IMG = "https://picsum.photos/seed/{}/900/600"
VID = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4"
AUD = "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"

SEED_POSTS: list[dict] = [
    # ── Impact (TEXT + image) ──
    {
        "id": _id(),
        "author_id": "u_amira", "author_name": "Amira Saleh", "author_handle": "amira",
        "author_verified": True, "author_role": "Organization",
        "text": "We just planted 12,000 mangrove saplings along the northern coast with 340 volunteers. Real, verified impact — every seedling geotagged and audited.",
        "kind": "impact", "program_tag": "Coastal Restoration", "sdg": 14,
        "impact_value": 12000, "impact_label": "seedlings planted", "confidence": 96.4,
        "media": [{"type": "image", "url": IMG.format("mangrove"), "name": "Mangrove restoration"}],
        "comments": [{"id": _id(), "author": {"id": "u_yusuf", "name": "Yusuf Rahman", "handle": "yusuf"},
                      "text": "Incredible work! Proud to have joined.", "createdAt": _ago(42).isoformat()}],
        "likes": 482, "shares": 73, "created_at": _ago(58),
    },
    # ── Story (TEXT) ──
    {
        "id": _id(),
        "author_id": "u_yusuf", "author_name": "Yusuf Rahman", "author_handle": "yusuf",
        "author_verified": False, "author_role": "Individual",
        "text": "Spent the weekend teaching in the community coding club. Small steps, but the kids built their first app today. This is what impact looks like up close.",
        "kind": "story", "program_tag": None, "sdg": 0,
        "impact_value": 0, "impact_label": None, "confidence": 88.0,
        "media": [], "comments": [], "likes": 89, "shares": 4, "created_at": _ago(310),
    },
    # ── Impact (TEXT + video) ──
    {
        "id": _id(),
        "author_id": "u_solar", "author_name": "SolarCoop", "author_handle": "solarcoop",
        "author_verified": True, "author_role": "Organization",
        "text": "Aswan solar microgrid just crossed 98% uptime for the quarter — clean energy reaching 4 villages. Watch the full site walkthrough.",
        "kind": "impact", "program_tag": "Rural Electrification", "sdg": 7,
        "impact_value": 98, "impact_label": "% uptime", "confidence": 94.2,
        "media": [{"type": "video", "url": VID, "name": "Microgrid walkthrough"}],
        "comments": [], "likes": 240, "shares": 31, "created_at": _ago(95),
    },
    # ── Program (TEXT) ──
    {
        "id": _id(),
        "author_id": "u_edu", "author_name": "EduForAll", "author_handle": "eduforall",
        "author_verified": True, "author_role": "Organization",
        "text": "Scholarships are open for the 2026 EduForAll cohort — 200 places for girls in STEM across 5 governorates.",
        "kind": "program", "program_tag": "EduForAll 2026", "sdg": 4,
        "impact_value": 200, "impact_label": "scholarships", "confidence": 91.7,
        "media": [], "comments": [], "likes": 176, "shares": 22, "created_at": _ago(160),
    },
    # ── Evidence (TEXT + image) ──
    {
        "id": _id(),
        "author_id": "u_water", "author_name": "WaterWatch", "author_handle": "waterwatch",
        "author_verified": True, "author_role": "Organization",
        "text": "River quality dashboard is live for the Nile Delta. Real-time sensors, fully auditable.",
        "kind": "evidence", "program_tag": "Nile Delta", "sdg": 6,
        "impact_value": 14, "impact_label": "sensors online", "confidence": 90.1,
        "media": [{"type": "image", "url": IMG.format("river"), "name": "Sensor node"}],
        "comments": [], "likes": 132, "shares": 9, "created_at": _ago(205),
    },
    # ── IMAGE post (gallery) ──
    {
        "id": _id(),
        "author_id": "u_amira", "author_name": "Amira Saleh", "author_handle": "amira",
        "author_verified": True, "author_role": "Organization",
        "text": "Field day with the coastal team — dune stabilisation is paying off. 🌱",
        "kind": "impact", "program_tag": "Coastal Restoration", "sdg": 15,
        "impact_value": 540, "impact_label": "metres stabilised", "confidence": 89.5,
        "media": [{"type": "image", "url": IMG.format("dune1"), "name": "Dune work"},
                  {"type": "image", "url": IMG.format("dune2"), "name": "Team"}],
        "comments": [], "likes": 311, "shares": 18, "created_at": _ago(70),
    },
    # ── VIDEO post ──
    {
        "id": _id(),
        "author_id": "u_solar", "author_name": "SolarCoop", "author_handle": "solarcoop",
        "author_verified": True, "author_role": "Organization",
        "text": "How a single microgrid lit up a whole village — 90 seconds.",
        "kind": "impact", "program_tag": "Rural Electrification", "sdg": 7,
        "impact_value": 1200, "impact_label": "homes powered", "confidence": 93.0,
        "media": [{"type": "video", "url": VID, "name": "Village lights"}],
        "comments": [], "likes": 205, "shares": 27, "created_at": _ago(120),
    },
    # ── AUDIO post ──
    {
        "id": _id(),
        "author_id": "u_yusuf", "author_name": "Yusuf Rahman", "author_handle": "yusuf",
        "author_verified": False, "author_role": "Individual",
        "text": "Listen: a field recording from last night's community meeting on the new water project.",
        "kind": "story", "program_tag": None, "sdg": 6,
        "impact_value": 0, "impact_label": None, "confidence": 82.4,
        "media": [{"type": "audio", "url": AUD, "name": "Community meeting"}],
        "comments": [], "likes": 64, "shares": 3, "created_at": _ago(140),
    },
    # ── AUDIO post (iteration 2) ──
    {
        "id": _id(),
        "author_id": "u_edu", "author_name": "EduForAll", "author_handle": "eduforall",
        "author_verified": True, "author_role": "Organization",
        "text": "A student reads her winning essay on why clean water matters.",
        "kind": "story", "program_tag": "Voices", "sdg": 4,
        "impact_value": 0, "impact_label": None, "confidence": 85.0,
        "media": [{"type": "audio", "url": AUD, "name": "Winning essay"}],
        "comments": [], "likes": 51, "shares": 2, "created_at": _ago(180),
    },
    # ── ARTICLE post ──
    {
        "id": _id(),
        "author_id": "u_water", "author_name": "WaterWatch", "author_handle": "waterwatch",
        "author_verified": True, "author_role": "Organization",
        "text": "Our year in water: what the sensors taught us about the Delta.",
        "kind": "evidence", "program_tag": "Nile Delta", "sdg": 6,
        "impact_value": 200, "impact_label": "readings", "confidence": 92.3,
        "media": [{"type": "article", "title": "A year of clean-water data",
                   "summary": "How 14 sensor nodes turned a polluted delta into a measurable win.",
                   "source": "MASAREEN Journal", "imageUrl": IMG.format("article"),
                   "url": "https://masaren.org/journal/year-of-water"}],
        "comments": [], "likes": 144, "shares": 11, "created_at": _ago(220),
    },
    # ── LINK post ──
    {
        "id": _id(),
        "author_id": "u_amira", "author_name": "Amira Saleh", "author_handle": "amira",
        "author_verified": True, "author_role": "Organization",
        "text": "The UN framework we modelled our verification standard on.",
        "kind": "impact", "program_tag": "Policy", "sdg": 17,
        "impact_value": 0, "impact_label": None, "confidence": 87.6,
        "media": [{"type": "link", "title": "UN SDG verification guidance",
                   "domain": "un.org", "url": "https://un.org/sustainabledevelopment/"}],
        "comments": [], "likes": 98, "shares": 14, "created_at": _ago(260),
    },
    # ── Impact (TEXT) iteration ──
    {
        "id": _id(),
        "author_id": "u_solar", "author_name": "SolarCoop", "author_handle": "solarcoop",
        "author_verified": True, "author_role": "Organization",
        "text": "Battery bank commissioned — the village now has power through the night.",
        "kind": "impact", "program_tag": "Rural Electrification", "sdg": 7,
        "impact_value": 60, "impact_label": "kWh stored", "confidence": 90.8,
        "media": [], "comments": [], "likes": 160, "shares": 12, "created_at": _ago(300),
    },
    # ── Story (TEXT) iteration ──
    {
        "id": _id(),
        "author_id": "u_yusuf", "author_name": "Yusuf Rahman", "author_handle": "yusuf",
        "author_verified": False, "author_role": "Individual",
        "text": "Repaired three community water pumps this morning. Small wins add up.",
        "kind": "story", "program_tag": None, "sdg": 6,
        "impact_value": 3, "impact_label": "pumps fixed", "confidence": 84.0,
        "media": [], "comments": [], "likes": 73, "shares": 5, "created_at": _ago(340),
    },
]
