"""MASAREN Profile Seed Script — populates every profile type for testing.

Creates 17 demo accounts across 5 categories:
  - News Media Profiles (Al Jazeera, BBC, Al Masareen)
  - Sports Institutions (Ahly, Zamalek, Egypt NT)
  - Egyptian Players (Salah, Abdelmonem, Trezeguet, Elneny)
  - Government Profiles (Tourism, Youth, ICT Ministries)
  - Organizations (UNICEF, Red Crescent, Cairo Tech Hub)

Each account gets:
  - A users row (bcrypt-hashed password, ACTIVE, email_verified)
  - A user_profiles row (bio, country, city, languages)
  - A m_personnel row (headline, summary, beat, expertise)
  - A wallets row with MRC balance
  - A sample post matching the profile type

Run standalone:
    cd backend && python -m combined.seed_profiles
    # or
    cd backend && python combined/seed_profiles.py
"""
from __future__ import annotations

import asyncio
import uuid
import sys
import os

# Ensure the backend root and shared/ are importable
BACKEND = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHARED = os.path.join(BACKEND, "shared")
for p in (BACKEND, SHARED):
    if p not in sys.path:
        sys.path.insert(0, p)

import asyncpg

# ── Config ────────────────────────────────────────────────────────────────────
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+asyncpg://masaren:masaren_password@localhost:5432/masaren",
)
# asyncpg expects plain postgresql://
DB_DSN = DATABASE_URL.replace("postgresql+asyncpg://", "postgresql://")
PASSWORD = "Masaren@1234"


# ── Helpers ───────────────────────────────────────────────────────────────────
def _id() -> str:
    return str(uuid.uuid4())


def _hash_password(plain: str) -> str:
    """bcrypt hash via the bcrypt library (passlib-compatible)."""
    try:
        import bcrypt
        return bcrypt.hashpw(plain.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")
    except ImportError:
        from passlib.context import CryptContext
        ctx = CryptContext(schemes=["bcrypt"], deprecated="auto")
        return ctx.hash(plain)


HASHED_PW = _hash_password(PASSWORD)


# ── Profile definitions ───────────────────────────────────────────────────────
# Each entry: (email, full_name, role, audience, profile, personnel, wallet_balance, posts)
PROFILES = [
    # ════════════════════════════════════════════════════════════════════════════
    # NEWS MEDIA PROFILES
    # ════════════════════════════════════════════════════════════════════════════
    {
        "email": "aljazeera@masaren.org",
        "full_name": "Al Jazeera Media Network",
        "role": "Media",
        "audience": "PROFESSIONAL",
        "profile": {
            "bio": "Al Jazeera is a state-funded independent news organisation headquartered in Doha, Qatar, delivering in-depth reporting to a global audience.",
            "country": "Qatar",
            "city": "Doha",
            "languages": ["Arabic", "English"],
            "latitude": 25.2854,
            "longitude": 51.5310,
            "target_audience": "PROFESSIONAL",
            "website": "https://www.aljazeera.com",
            "social_links": {"twitter": "@AJEnglish", "youtube": "aljazeera"},
        },
        "personnel": {
            "headline": "Global News Network — Al Jazeera",
            "summary": "Award-winning news network providing independent journalism across 150+ countries, with a focus on underserved stories.",
            "mission": "Giving voice to the voiceless and holding power to account through fearless, independent journalism.",
            "beat": "International News",
            "expertise": ["Investigative Journalism", "Conflict Reporting", "Documentary", "Live Broadcasting", "Digital Media"],
            "specializations": ["Investigative Reporting", "Documentary Filmmaking", "Live Event Coverage"],
            "skills": [
                {"name": "Investigative Journalism", "endorsements": 342},
                {"name": "Conflict Zone Reporting", "endorsements": 218},
                {"name": "Multimedia Storytelling", "endorsements": 189},
                {"name": "Data Journalism", "endorsements": 156},
            ],
            "languages": ["Arabic", "English", "French", "Spanish"],
            "employment_status": "Employed",
            "verification_level": "VERIFIED",
            "impact_tier": "Luminary",
            "professional_rank": "Senior Correspondent",
            "endorsements_count": 1200,
            "followers_count": 8500,
            "following_count": 320,
            "experience": [
                {"role": "Lead Correspondent", "org": "Al Jazeera Media Network", "from": "2004", "to": "Present", "impact": "Covered 40+ countries"}
            ],
            "education": [
                {"institution": "University of Doha", "degree": "Master of Journalism", "year": 2003}
            ],
            "awards": [
                {"title": "Peabody Award", "year": 2022, "detail": "Outstanding coverage of climate migration"}
            ],
            "social_links": {"twitter": "@AJEnglish", "youtube": "aljazeera"},
        },
        "wallet_balance": 5000,
        "posts": [
            {
                "text": "BREAKING: Masaren platform partnership opens new channels for verified impact reporting across the MENA region. Our teams on the ground will deliver real-time, verified stories from communities that matter most.",
                "kind": "news",
                "sdg": 16,
                "impact_value": 0,
                "impact_label": None,
                "confidence": 97.0,
                "media": [{"type": "article", "title": "Al Jazeera × MASAREN Partnership", "summary": "A new chapter in verified, community-driven journalism.", "source": "Al Jazeera", "url": "https://www.aljazeera.com/masaren"}],
                "likes": 3420,
                "shares": 890,
            },
            {
                "text": "INVESTIGATION: How digital platforms are transforming access to verified information in underserved communities. Full report in the link below.",
                "kind": "news",
                "sdg": 17,
                "impact_value": 0,
                "impact_label": None,
                "confidence": 95.5,
                "media": [{"type": "article", "title": "Digital Access & Truth", "summary": "An in-depth look at the digital information divide.", "source": "Al Jazeera Investigations", "url": "https://www.aljazeera.com/investigations/digital-access"}],
                "likes": 2180,
                "shares": 560,
            },
        ],
    },
    {
        "email": "bbcnews@masaren.org",
        "full_name": "BBC News",
        "role": "Media",
        "audience": "PROFESSIONAL",
        "profile": {
            "bio": "BBC News reaches over 500 million people globally with trusted, impartial journalism in 40+ languages.",
            "country": "United Kingdom",
            "city": "London",
            "languages": ["English", "Arabic"],
            "latitude": 51.5074,
            "longitude": -0.1278,
            "target_audience": "PROFESSIONAL",
            "website": "https://www.bbc.com/news",
            "social_links": {"twitter": "@BBCNews", "youtube": "BBCNews"},
        },
        "personnel": {
            "headline": "BBC News — World Service Arabic",
            "summary": "The BBC's Arabic service delivers impartial news and analysis to audiences across the Middle East and North Africa.",
            "mission": "To provide impartial, high-quality journalism that informs and educates a global audience.",
            "beat": "Global Affairs",
            "expertise": ["Broadcast Journalism", "Radio Production", "Digital News", "Podcast Production"],
            "specializations": ["Breaking News Coverage", "Long-form Documentary", "Audio Journalism"],
            "skills": [
                {"name": "Broadcast Journalism", "endorsements": 456},
                {"name": "Radio Production", "endorsements": 312},
                {"name": "Fact-Checking", "endorsements": 278},
            ],
            "languages": ["English", "Arabic", "Urdu"],
            "employment_status": "Employed",
            "verification_level": "VERIFIED",
            "impact_tier": "Luminary",
            "professional_rank": "Senior Correspondent",
            "endorsements_count": 980,
            "followers_count": 6200,
            "following_count": 210,
            "experience": [
                {"role": "Senior Producer", "org": "BBC World Service", "from": "2010", "to": "Present", "impact": "Led Arabic digital expansion"}
            ],
            "education": [
                {"institution": "City, University of London", "degree": "MA Broadcasting Journalism", "year": 2008}
            ],
            "awards": [],
            "social_links": {"twitter": "@BBCNews", "youtube": "BBCNews"},
        },
        "wallet_balance": 4500,
        "posts": [
            {
                "text": "REPORT: The impact of verified data on humanitarian response times. Our investigation shows communities with access to verified information networks respond 3x faster to crises.",
                "kind": "news",
                "sdg": 11,
                "impact_value": 0,
                "impact_label": None,
                "confidence": 94.0,
                "media": [{"type": "article", "title": "Crisis Response & Verified Data", "summary": "How data verification saves lives in humanitarian emergencies.", "source": "BBC News", "url": "https://www.bbc.com/news/crisis-data"}],
                "likes": 2800,
                "shares": 670,
            },
        ],
    },
    {
        "email": "almasareen_media@masaren.org",
        "full_name": "Al Masareen News",
        "role": "Media",
        "audience": "PROFESSIONAL",
        "profile": {
            "bio": "Al Masareen News is the flagship media outlet of the MASAREN platform, delivering verified community-driven stories from across Egypt and the MENA region.",
            "country": "Egypt",
            "city": "Cairo",
            "languages": ["Arabic", "English"],
            "latitude": 30.0444,
            "longitude": 31.2357,
            "target_audience": "PROFESSIONAL",
            "website": "https://masaren.org/news",
            "social_links": {"twitter": "@AlMasareenNews", "youtube": "almasareennews"},
        },
        "personnel": {
            "headline": "Al Masareen News — Platform Media",
            "summary": "The editorial voice of MASAREN, amplifying verified community impact and holding institutions accountable.",
            "mission": "Amplifying verified community voices and creating transparent impact narratives.",
            "beat": "Community Impact",
            "expertise": ["Community Journalism", "Impact Reporting", "Data Visualization", "Social Media"],
            "specializations": ["Impact Storytelling", "Community Verification", "SDG Reporting"],
            "skills": [
                {"name": "Community Journalism", "endorsements": 120},
                {"name": "Impact Reporting", "endorsements": 95},
                {"name": "Arabic Content", "endorsements": 88},
            ],
            "languages": ["Arabic", "English"],
            "employment_status": "Employed",
            "verification_level": "VERIFIED",
            "impact_tier": "Authority",
            "professional_rank": "Correspondent",
            "endorsements_count": 310,
            "followers_count": 2100,
            "following_count": 450,
            "experience": [
                {"role": "Editor-in-Chief", "org": "Al Masareen News", "from": "2024", "to": "Present", "impact": "Launched platform's first verified newsroom"}
            ],
            "education": [
                {"institution": "Cairo University", "degree": "Bachelor of Mass Communication", "year": 2020}
            ],
            "awards": [],
            "social_links": {"twitter": "@AlMasareenNews"},
        },
        "wallet_balance": 3000,
        "posts": [
            {
                "text": "LAUNCH: Al Masareen News goes live. Every story we publish is verified through the MASAREN POAI system. This is the future of community journalism.",
                "kind": "news",
                "sdg": 16,
                "impact_value": 0,
                "impact_label": None,
                "confidence": 92.0,
                "media": [],
                "likes": 1500,
                "shares": 420,
            },
            {
                "text": "EXCLUSIVE: Over 10,000 community impact reports have been verified through the MASAREN platform this quarter alone. Here's what the data tells us about Egypt's grassroots development.",
                "kind": "news",
                "sdg": 17,
                "impact_value": 10000,
                "impact_label": "reports verified",
                "confidence": 91.0,
                "media": [{"type": "image", "url": "https://picsum.photos/seed/masareen/900/600", "name": "Impact dashboard"}],
                "likes": 980,
                "shares": 230,
            },
        ],
    },

    # ════════════════════════════════════════════════════════════════════════════
    # SPORTS INSTITUTIONS
    # ════════════════════════════════════════════════════════════════════════════
    {
        "email": "ahly@masaren.org",
        "full_name": "Al Ahly SC",
        "role": "Sports Club",
        "audience": "CORPORATE",
        "profile": {
            "bio": "Al Ahly Sporting Club — the most decorated club in African football history. Founded 1907 in Cairo, Egypt.",
            "country": "Egypt",
            "city": "Cairo",
            "languages": ["Arabic", "English"],
            "latitude": 30.0561,
            "longitude": 31.2840,
            "target_audience": "CORPORATE",
            "website": "https://www.alahlyegypt.com",
            "social_links": {"twitter": "@AlAhly", "instagram": "alahly"},
        },
        "personnel": {
            "headline": "Al Ahly SC — Club Communications",
            "summary": "Official communications channel for Al Ahly Sporting Club, delivering match updates, transfer news, and club initiatives.",
            "mission": "Serving the Ahly community with verified updates and championing sports development across Egypt.",
            "beat": "Football",
            "expertise": ["Sports Management", "Fan Engagement", "Youth Development", "Stadium Operations"],
            "specializations": ["Match Coverage", "Transfer Analysis", "Youth Academy"],
            "skills": [
                {"name": "Sports Management", "endorsements": 560},
                {"name": "Fan Engagement", "endorsements": 340},
                {"name": "Youth Development", "endorsements": 210},
            ],
            "languages": ["Arabic", "English"],
            "employment_status": "Employed",
            "verification_level": "VERIFIED",
            "impact_tier": "Authority",
            "professional_rank": "Correspondent",
            "endorsements_count": 450,
            "followers_count": 12000,
            "following_count": 85,
            "experience": [
                {"role": "Media Director", "org": "Al Ahly SC", "from": "2018", "to": "Present", "impact": "Grew digital fanbase 400%"}
            ],
            "education": [
                {"institution": "Helwan University", "degree": "Sports Management", "year": 2015}
            ],
            "awards": [
                {"title": "CAF Club of the Century", "year": 2000, "detail": "Named best African club of the 20th century"}
            ],
            "social_links": {"twitter": "@AlAhly", "instagram": "alahly"},
        },
        "wallet_balance": 3500,
        "posts": [
            {
                "text": "ANNOUNCEMENT: Al Ahly SC partners with MASAREN to track and verify our community development programs across 12 governorates. Real impact, real verification.",
                "kind": "announcement",
                "sdg": 3,
                "impact_value": 12,
                "impact_label": "governorates covered",
                "confidence": 90.0,
                "media": [{"type": "image", "url": "https://picsum.photos/seed/ahly/900/600", "name": "Al Ahly community program"}],
                "likes": 5600,
                "shares": 1200,
            },
        ],
    },
    {
        "email": "zamalek@masaren.org",
        "full_name": "Zamalek SC",
        "role": "Sports Club",
        "audience": "CORPORATE",
        "profile": {
            "bio": "Zamalek Sporting Club — White Knights of Egyptian football. Founded 1911, one of Africa's most storied clubs.",
            "country": "Egypt",
            "city": "Giza",
            "languages": ["Arabic", "English"],
            "latitude": 30.0265,
            "longitude": 31.2089,
            "target_audience": "CORPORATE",
            "website": "https://www.zamalekclub.com",
            "social_links": {"twitter": "@ZamalekClub", "instagram": "zamalekclub"},
        },
        "personnel": {
            "headline": "Zamalek SC — Official Media",
            "summary": "The official media arm of Zamalek Sporting Club, covering first-team football, academy, and community outreach.",
            "mission": "Connecting the Zamalek community through verified stories and championing sportsmanship.",
            "beat": "Football",
            "expertise": ["Sports Broadcasting", "Youth Academy", "Community Sports", "Fan Relations"],
            "specializations": ["Match Analysis", "Academy Coverage", "Community Outreach"],
            "skills": [
                {"name": "Sports Broadcasting", "endorsements": 380},
                {"name": "Fan Community Management", "endorsements": 250},
                {"name": "Youth Academy", "endorsements": 190},
            ],
            "languages": ["Arabic", "English"],
            "employment_status": "Employed",
            "verification_level": "VERIFIED",
            "impact_tier": "Authority",
            "professional_rank": "Correspondent",
            "endorsements_count": 320,
            "followers_count": 9800,
            "following_count": 120,
            "experience": [
                {"role": "Head of Media", "org": "Zamalek SC", "from": "2019", "to": "Present", "impact": "Launched verified community programs"}
            ],
            "education": [
                {"institution": "Ain Shams University", "degree": "Sports Science", "year": 2016}
            ],
            "awards": [],
            "social_links": {"twitter": "@ZamalekClub"},
        },
        "wallet_balance": 3500,
        "posts": [
            {
                "text": "ANNOUNCEMENT: Zamalek SC joins the MASAREN platform to bring transparency to our community sports initiatives. Every program will be POAI-verified.",
                "kind": "announcement",
                "sdg": 3,
                "impact_value": 8,
                "impact_label": "programs launched",
                "confidence": 88.5,
                "media": [{"type": "image", "url": "https://picsum.photos/seed/zamalek/900/600", "name": "Zamalek community program"}],
                "likes": 4200,
                "shares": 950,
            },
        ],
    },
    {
        "email": "egypt_nt@masaren.org",
        "full_name": "Egyptian National Team",
        "role": "Sports Federation",
        "audience": "GOVERNMENT",
        "profile": {
            "bio": "The Egyptian National Football Team — Pharaohs of Africa. 7-time Africa Cup of Nations champions and FIFA World Cup participants.",
            "country": "Egypt",
            "city": "Cairo",
            "languages": ["Arabic", "English", "French"],
            "latitude": 30.0131,
            "longitude": 31.2089,
            "target_audience": "GOVERNMENT",
            "website": "https://www.efegypt.com",
            "social_links": {"twitter": "@EFA", "instagram": "egyptiannationalteam"},
        },
        "personnel": {
            "headline": "Egyptian FA — National Team Communications",
            "summary": "Official media channel for Egypt's national football teams, covering senior, U-23, and women's programmes.",
            "mission": "Representing Egyptian football on the world stage and developing the next generation of champions.",
            "beat": "National Football",
            "expertise": ["Team Management", "Tournament Planning", "Player Development", "Stadium Security"],
            "specializations": ["FIFA World Cup", "Africa Cup of Nations", "Youth Development"],
            "skills": [
                {"name": "Tournament Organization", "endorsements": 420},
                {"name": "National Team Management", "endorsements": 310},
                {"name": "Youth Scouting", "endorsements": 240},
            ],
            "languages": ["Arabic", "English", "French"],
            "employment_status": "Government",
            "verification_level": "VERIFIED",
            "impact_tier": "Authority",
            "professional_rank": "Correspondent",
            "endorsements_count": 380,
            "followers_count": 15000,
            "following_count": 55,
            "experience": [
                {"role": "Communications Director", "org": "Egyptian Football Association", "from": "2020", "to": "Present", "impact": "Led World Cup 2026 qualifying campaign media"}
            ],
            "education": [
                {"institution": "Egyptian Police Academy", "degree": "Sports Administration", "year": 2014}
            ],
            "awards": [
                {"title": "CAF Best Organising Association", "year": 2023, "detail": "For AFCON hosting"}
            ],
            "social_links": {"twitter": "@EFA"},
        },
        "wallet_balance": 4000,
        "posts": [
            {
                "text": "ANNOUNCEMENT: The Egyptian National Team programme adopts MASAREN's verified impact tracking for all youth development and grassroots football initiatives ahead of World Cup 2026.",
                "kind": "announcement",
                "sdg": 3,
                "impact_value": 0,
                "impact_label": None,
                "confidence": 93.0,
                "media": [{"type": "image", "url": "https://picsum.photos/seed/egyptnt/900/600", "name": "Egypt NT training"}],
                "likes": 8200,
                "shares": 2100,
            },
        ],
    },

    # ════════════════════════════════════════════════════════════════════════════
    # EGYPTIAN PLAYERS (World Cup)
    # ════════════════════════════════════════════════════════════════════════════
    {
        "email": "mohamed_salah@masaren.org",
        "full_name": "Mohamed Salah",
        "role": "Athlete",
        "audience": "PROFESSIONAL",
        "profile": {
            "bio": "Mohamed Salah — Egyptian King. Liverpool FC forward, AFCON champion, and global ambassador for Egyptian football.",
            "country": "Egypt",
            "city": "Cairo",
            "languages": ["Arabic", "English"],
            "latitude": 30.0444,
            "longitude": 31.2357,
            "target_audience": "PROFESSIONAL",
            "website": "https://www.mohamedsalah.com",
            "social_links": {"twitter": "@MoSalah", "instagram": "mosalah"},
        },
        "personnel": {
            "headline": "Mohamed Salah — Professional Footballer",
            "summary": "Premier League and Champions League winner, multiple African Player of the Year. Using football as a force for social good.",
            "mission": "Inspiring the next generation of Egyptian athletes and using my platform to create verified positive impact in communities.",
            "beat": "Professional Football",
            "expertise": ["Football", "Philanthropy", "Youth Inspiration", "Brand Management"],
            "specializations": ["Premier League", "Community Development", "Youth Football Academies"],
            "skills": [
                {"name": "Professional Football", "endorsements": 1200},
                {"name": "Community Leadership", "endorsements": 680},
                {"name": "Youth Mentorship", "endorsements": 420},
            ],
            "languages": ["Arabic", "English"],
            "employment_status": "Professional Athlete",
            "verification_level": "VERIFIED",
            "impact_tier": "Luminary",
            "professional_rank": "Senior Correspondent",
            "endorsements_count": 2100,
            "followers_count": 50000,
            "following_count": 45,
            "experience": [
                {"role": "Forward", "org": "Liverpool FC", "from": "2017", "to": "Present", "impact": "Champions League, Premier League winner"},
                {"role": "Forward", "org": "AS Roma", "from": "2015", "to": "2017", "impact": "Serie A top scorer"},
                {"role": "Forward", "org": "Egypt National Team", "from": "2011", "to": "Present", "impact": "AFCON champion, World Cup 2018"},
            ],
            "education": [
                {"institution": "Egyptian Sports Institute", "degree": "Sports Science", "year": 2010}
            ],
            "awards": [
                {"title": "CAF African Player of the Year", "year": 2017, "detail": "First Egyptian to win"},
                {"title": "PFA Players' Player of the Year", "year": 2018, "detail": "Premier League"},
                {"title": "BBC African Footballer of the Year", "year": 2017, "detail": ""},
            ],
            "social_links": {"twitter": "@MoSalah", "instagram": "mosalah"},
        },
        "wallet_balance": 2500,
        "posts": [
            {
                "text": "STORY: Growing up in Nagrig, I dreamed of playing for Egypt and the world. Today I'm proud to partner with MASAREN to verify the impact of football academies across Egyptian villages. Every child deserves a chance.",
                "kind": "story",
                "sdg": 3,
                "impact_value": 5000,
                "impact_label": "kids reached",
                "confidence": 96.0,
                "media": [{"type": "image", "url": "https://picsum.photos/seed/salah/900/600", "name": "Salah youth academy"}],
                "likes": 15000,
                "shares": 4200,
            },
            {
                "text": "Football taught me discipline, teamwork, and belief. Through MASAREN's verified impact system, every programme we fund is transparent and accountable. Real impact, verified.",
                "kind": "story",
                "sdg": 4,
                "impact_value": 3200,
                "impact_label": "students enrolled",
                "confidence": 94.0,
                "media": [],
                "likes": 8500,
                "shares": 1800,
            },
        ],
    },
    {
        "email": "mohamed_abdelmonem@masaren.org",
        "full_name": "Mohamed Abdelmonem",
        "role": "Athlete",
        "audience": "PROFESSIONAL",
        "profile": {
            "bio": "Mohamed Abdelmonem — Egyptian international centre-back, known for his aerial dominance and leadership at the back.",
            "country": "Egypt",
            "city": "Alexandria",
            "languages": ["Arabic", "English"],
            "latitude": 31.2001,
            "longitude": 29.9187,
            "target_audience": "PROFESSIONAL",
            "website": None,
            "social_links": {"instagram": "abdelmonem"},
        },
        "personnel": {
            "headline": "Mohamed Abdelmonem — Professional Footballer",
            "summary": "Egyptian international defender and AFCON standout, committed to community work through verified platforms.",
            "mission": "Using my platform to support youth development and community sports in Alexandria and across Egypt.",
            "beat": "Professional Football",
            "expertise": ["Defensive Play", "Youth Football", "Community Sports"],
            "specializations": ["Centre-Back", "Set-Piece Threat", "Youth Coaching"],
            "skills": [
                {"name": "Professional Football", "endorsements": 340},
                {"name": "Youth Coaching", "endorsements": 120},
            ],
            "languages": ["Arabic", "English"],
            "employment_status": "Professional Athlete",
            "verification_level": "VERIFIED",
            "impact_tier": "Professional",
            "professional_rank": "Field Reporter II",
            "endorsements_count": 280,
            "followers_count": 8500,
            "following_count": 120,
            "experience": [
                {"role": "Centre-Back", "org": "Al Ahly SC", "from": "2022", "to": "Present", "impact": "Champions League semi-finalist"},
                {"role": "Centre-Back", "org": "Egypt National Team", "from": "2021", "to": "Present", "impact": "AFCON 2022 runner-up"},
            ],
            "education": [
                {"institution": "Alexandria University", "degree": "Sports Education", "year": 2019}
            ],
            "awards": [],
            "social_links": {"instagram": "abdelmonem"},
        },
        "wallet_balance": 1500,
        "posts": [
            {
                "text": "STORY: From the streets of Alexandria to the biggest stages in African football. Grateful to partner with MASAREN to bring verified community sports programs to my hometown.",
                "kind": "story",
                "sdg": 3,
                "impact_value": 800,
                "impact_label": "youth athletes",
                "confidence": 91.0,
                "media": [{"type": "image", "url": "https://picsum.photos/seed/abdelmonem/900/600", "name": "Community sports"}],
                "likes": 3200,
                "shares": 680,
            },
        ],
    },
    {
        "email": "trezeguet@masaren.org",
        "full_name": "Mahmoud Hassan (Trezeguet)",
        "role": "Athlete",
        "audience": "PROFESSIONAL",
        "profile": {
            "bio": "Mahmoud Hassan 'Trezeguet' — Egyptian winger known for pace, flair, and creativity. Former Trabzonspor, now Al Ahly SC.",
            "country": "Egypt",
            "city": "Cairo",
            "languages": ["Arabic", "English", "Turkish"],
            "latitude": 30.0444,
            "longitude": 31.2357,
            "target_audience": "PROFESSIONAL",
            "website": None,
            "social_links": {"twitter": "@Trezeguet", "instagram": "trezeguet"},
        },
        "personnel": {
            "headline": "Trezeguet — Professional Footballer",
            "summary": "Explosive winger who has played across Europe and the Middle East, now back home at Al Ahly and the Egyptian national team.",
            "mission": "Bringing joy through football and supporting verified grassroots development programs in Upper Egypt.",
            "beat": "Professional Football",
            "expertise": ["Wing Play", "Speed & Dribbling", "Youth Inspiration"],
            "specializations": ["Winger", "Creative Play", "Upper Egypt Outreach"],
            "skills": [
                {"name": "Professional Football", "endorsements": 290},
                {"name": "Youth Outreach", "endorsements": 150},
            ],
            "languages": ["Arabic", "English", "Turkish"],
            "employment_status": "Professional Athlete",
            "verification_level": "VERIFIED",
            "impact_tier": "Professional",
            "professional_rank": "Field Reporter II",
            "endorsements_count": 210,
            "followers_count": 6200,
            "following_count": 200,
            "experience": [
                {"role": "Winger", "org": "Al Ahly SC", "from": "2022", "to": "Present", "impact": "Egyptian Premier League champion"},
                {"role": "Winger", "org": "Trabzonspor", "from": "2019", "to": "2022", "impact": "Süper Lig champion"},
            ],
            "education": [],
            "awards": [],
            "social_links": {"twitter": "@Trezeguet", "instagram": "trezeguet"},
        },
        "wallet_balance": 1500,
        "posts": [
            {
                "text": "STORY: I grew up in Mahalla, kicking a ball on dusty streets. Now I'm using MASAREN to verify every sports development program we run in Upper Egypt. No more empty promises — only verified impact.",
                "kind": "story",
                "sdg": 3,
                "impact_value": 1200,
                "impact_label": "kids enrolled",
                "confidence": 89.0,
                "media": [{"type": "image", "url": "https://picsum.photos/seed/trezeguet/900/600", "name": "Youth football program"}],
                "likes": 2800,
                "shares": 520,
            },
        ],
    },
    {
        "email": "mohamed_elneny@masaren.org",
        "full_name": "Mohamed Elneny",
        "role": "Athlete",
        "audience": "PROFESSIONAL",
        "profile": {
            "bio": "Mohamed Elneny — Egyptian midfielder, Arsenal legend, known for his tireless engine and class on the ball.",
            "country": "Egypt",
            "city": "Cairo",
            "languages": ["Arabic", "English"],
            "latitude": 30.0444,
            "longitude": 31.2357,
            "target_audience": "PROFESSIONAL",
            "website": None,
            "social_links": {"twitter": "@ElNenny", "instagram": "elneny"},
        },
        "personnel": {
            "headline": "Mohamed Elneny — Professional Footballer",
            "summary": "Egyptian international midfielder, Arsenal FC veteran, and advocate for education through sport.",
            "mission": "Championing education and sport as equalisers for Egyptian youth, verified through transparent impact tracking.",
            "beat": "Professional Football",
            "expertise": ["Midfield Play", "Sports Philanthropy", "Education Advocacy"],
            "specializations": ["Box-to-Box Midfielder", "Education Through Sport", "Youth Scholarships"],
            "skills": [
                {"name": "Professional Football", "endorsements": 410},
                {"name": "Education Advocacy", "endorsements": 230},
                {"name": "Youth Mentorship", "endorsements": 180},
            ],
            "languages": ["Arabic", "English"],
            "employment_status": "Professional Athlete",
            "verification_level": "VERIFIED",
            "impact_tier": "Authority",
            "professional_rank": "Correspondent",
            "endorsements_count": 350,
            "followers_count": 12000,
            "following_count": 180,
            "experience": [
                {"role": "Midfielder", "org": "Arsenal FC", "from": "2016", "to": "2024", "impact": "FA Cup winner, 200+ appearances"},
                {"role": "Midfielder", "org": "Egypt National Team", "from": "2013", "to": "Present", "impact": "World Cup 2018, AFCON finalist"},
            ],
            "education": [
                {"institution": "Arab Contractors SC Academy", "degree": "Youth Academy Graduate", "year": 2010}
            ],
            "awards": [
                {"title": "FA Cup Winner", "year": 2017, "detail": "With Arsenal"},
                {"title": "Premier League Asia Trophy", "year": 2019, "detail": ""},
            ],
            "social_links": {"twitter": "@ElNenny", "instagram": "elneny"},
        },
        "wallet_balance": 2000,
        "posts": [
            {
                "text": "STORY: Education changed my life — football was just the vehicle. Through MASAREN, I can verify every scholarship and school we build. Every dirham, every student, verified.",
                "kind": "story",
                "sdg": 4,
                "impact_value": 2500,
                "impact_label": "students supported",
                "confidence": 93.5,
                "media": [{"type": "image", "url": "https://picsum.photos/seed/elneny/900/600", "name": "School build"}],
                "likes": 6800,
                "shares": 1400,
            },
        ],
    },

    # ════════════════════════════════════════════════════════════════════════════
    # GOVERNMENT PROFILES
    # ════════════════════════════════════════════════════════════════════════════
    {
        "email": "tourism_ministry@masaren.org",
        "full_name": "Ministry of Tourism & Antiquities",
        "role": "Government",
        "audience": "GOVERNMENT",
        "profile": {
            "bio": "The Egyptian Ministry of Tourism & Antiquities — preserving Egypt's heritage and promoting sustainable tourism.",
            "country": "Egypt",
            "city": "Cairo",
            "languages": ["Arabic", "English", "French"],
            "latitude": 30.0444,
            "longitude": 31.2357,
            "target_audience": "GOVERNMENT",
            "website": "https://www.antiquities.gov.eg",
            "social_links": {"twitter": "@TourismEgypt"},
        },
        "personnel": {
            "headline": "Ministry of Tourism & Antiquities — Communications",
            "summary": "Official digital communications for Egypt's tourism and antiquities portfolio, covering heritage preservation and sustainable tourism.",
            "mission": "Preserving 5,000 years of civilisation while building a sustainable tourism economy for Egypt's future.",
            "beat": "Tourism & Heritage",
            "expertise": ["Heritage Preservation", "Tourism Development", "Cultural Diplomacy", "Museum Management"],
            "specializations": ["Archaeological Preservation", "Tourism Strategy", "Cultural Heritage"],
            "skills": [
                {"name": "Heritage Management", "endorsements": 560},
                {"name": "Tourism Policy", "endorsements": 340},
                {"name": "Cultural Diplomacy", "endorsements": 220},
            ],
            "languages": ["Arabic", "English", "French", "German"],
            "employment_status": "Government",
            "verification_level": "VERIFIED",
            "impact_tier": "Authority",
            "professional_rank": "Correspondent",
            "endorsements_count": 620,
            "followers_count": 4500,
            "following_count": 90,
            "experience": [
                {"role": "Director of Communications", "org": "Ministry of Tourism & Antiquities", "from": "2019", "to": "Present", "impact": "Led digital heritage campaign"}
            ],
            "education": [
                {"institution": "Cairo University", "degree": "Archaeology", "year": 2008}
            ],
            "awards": [],
            "social_links": {"twitter": "@TourismEgypt"},
        },
        "wallet_balance": 5000,
        "posts": [
            {
                "text": "ANNOUNCEMENT: The Ministry of Tourism & Antiquities partners with MASAREN to track and verify the impact of heritage preservation programs across Upper Egypt. Transparency in every restoration project.",
                "kind": "announcement",
                "sdg": 11,
                "impact_value": 0,
                "impact_label": None,
                "confidence": 95.0,
                "media": [{"type": "image", "url": "https://picsum.photos/seed/tourism_egypt/900/600", "name": "Heritage preservation"}],
                "likes": 2100,
                "shares": 480,
            },
        ],
    },
    {
        "email": "youth_ministry@masaren.org",
        "full_name": "Ministry of Youth & Sports",
        "role": "Government",
        "audience": "GOVERNMENT",
        "profile": {
            "bio": "The Egyptian Ministry of Youth & Sports — empowering the next generation through sport, culture, and community engagement.",
            "country": "Egypt",
            "city": "Cairo",
            "languages": ["Arabic", "English"],
            "latitude": 30.0444,
            "longitude": 31.2357,
            "target_audience": "GOVERNMENT",
            "website": "https://www.youthandsports.gov.eg",
            "social_links": {"twitter": "@YouthSportsEG"},
        },
        "personnel": {
            "headline": "Ministry of Youth & Sports — Public Affairs",
            "summary": "Official communications for Egypt's youth and sports ministry, covering policy, grassroots programmes, and Olympic preparation.",
            "mission": "Empowering 60 million Egyptian youth through sport, creativity, and verified community programmes.",
            "beat": "Youth Policy & Sports",
            "expertise": ["Youth Policy", "Sports Infrastructure", "Olympic Preparation", "Grassroots Sport"],
            "specializations": ["Youth Empowerment", "Sports Policy", "Olympic Committee Liaison"],
            "skills": [
                {"name": "Sports Policy", "endorsements": 380},
                {"name": "Youth Development", "endorsements": 290},
                {"name": "Event Management", "endorsements": 190},
            ],
            "languages": ["Arabic", "English"],
            "employment_status": "Government",
            "verification_level": "VERIFIED",
            "impact_tier": "Authority",
            "professional_rank": "Correspondent",
            "endorsements_count": 440,
            "followers_count": 3200,
            "following_count": 110,
            "experience": [
                {"role": "Policy Advisor", "org": "Ministry of Youth & Sports", "from": "2020", "to": "Present", "impact": "Drafted national youth strategy"}
            ],
            "education": [
                {"institution": "Ain Shams University", "degree": "Public Administration", "year": 2012}
            ],
            "awards": [],
            "social_links": {"twitter": "@YouthSportsEG"},
        },
        "wallet_balance": 5000,
        "posts": [
            {
                "text": "ANNOUNCEMENT: Ministry of Youth & Sports adopts MASAREN's POAI verification for all youth development programmes. Every EGP invested will have verified, transparent outcomes.",
                "kind": "announcement",
                "sdg": 3,
                "impact_value": 0,
                "impact_label": None,
                "confidence": 94.0,
                "media": [],
                "likes": 1800,
                "shares": 400,
            },
        ],
    },
    {
        "email": "ict_ministry@masaren.org",
        "full_name": "Ministry of Communications & IT",
        "role": "Government",
        "audience": "GOVERNMENT",
        "profile": {
            "bio": "Egypt's Ministry of Communications & Information Technology — driving Egypt's digital transformation and tech ecosystem.",
            "country": "Egypt",
            "city": "Smart Village, Giza",
            "languages": ["Arabic", "English"],
            "latitude": 30.0200,
            "longitude": 31.0100,
            "target_audience": "GOVERNMENT",
            "website": "https://mcit.gov.eg",
            "social_links": {"twitter": "@MCIT_Egypt"},
        },
        "personnel": {
            "headline": "MCIT — Digital Egypt Communications",
            "summary": "Driving Egypt's digital transformation through policy, infrastructure, and tech ecosystem development.",
            "mission": "Building a digitally empowered Egypt where technology serves every citizen transparently.",
            "beat": "Digital Policy",
            "expertise": ["Digital Transformation", "Tech Policy", "Fibre Infrastructure", "Cyber Security"],
            "specializations": ["Digital Egypt Strategy", "Startup Ecosystem", "Smart Infrastructure"],
            "skills": [
                {"name": "Digital Policy", "endorsements": 420},
                {"name": "Tech Ecosystem Development", "endorsements": 310},
                {"name": "Infrastructure Planning", "endorsements": 200},
            ],
            "languages": ["Arabic", "English"],
            "employment_status": "Government",
            "verification_level": "VERIFIED",
            "impact_tier": "Authority",
            "professional_rank": "Correspondent",
            "endorsements_count": 380,
            "followers_count": 2800,
            "following_count": 95,
            "experience": [
                {"role": "Director of Digital Transformation", "org": "MCIT", "from": "2021", "to": "Present", "impact": "Fibre optic rollout to 60% coverage"}
            ],
            "education": [
                {"institution": "Egypt-Japan University", "degree": "Information Technology", "year": 2013}
            ],
            "awards": [
                {"title": "UN WSIS Award", "year": 2024, "detail": "Digital literacy programme"}
            ],
            "social_links": {"twitter": "@MCIT_Egypt"},
        },
        "wallet_balance": 5000,
        "posts": [
            {
                "text": "ANNOUNCEMENT: MCIT partners with MASAREN to bring verified digital literacy programmes to 27 governorates. Every learner, every outcome — tracked and verified on-chain.",
                "kind": "announcement",
                "sdg": 9,
                "impact_value": 0,
                "impact_label": None,
                "confidence": 93.5,
                "media": [{"type": "image", "url": "https://picsum.photos/seed/mcit/900/600", "name": "Digital literacy"}],
                "likes": 1400,
                "shares": 320,
            },
        ],
    },

    # ════════════════════════════════════════════════════════════════════════════
    # ORGANIZATIONS
    # ════════════════════════════════════════════════════════════════════════════
    {
        "email": "unicef_egypt@masaren.org",
        "full_name": "UNICEF Egypt",
        "role": "NGO",
        "audience": "NGO",
        "profile": {
            "bio": "UNICEF works in 190 countries and territories to save children's lives, defend their rights, and help them fulfil their potential.",
            "country": "Egypt",
            "city": "Cairo",
            "languages": ["Arabic", "English", "French"],
            "latitude": 30.0561,
            "longitude": 31.2243,
            "target_audience": "NGO",
            "website": "https://www.unicef.org/egypt",
            "social_links": {"twitter": "@UNICEFEgypt", "youtube": "unicefegypt"},
        },
        "personnel": {
            "headline": "UNICEF Egypt — Communications & Advocacy",
            "summary": "UNICEF Egypt's public communications covering child rights, education, health, and WASH programmes.",
            "mission": "Every child in Egypt has the right to survive, thrive and fulfil their potential — verified and transparent.",
            "beat": "Child Rights & Development",
            "expertise": ["Child Protection", "Education", "WASH", "Health Systems", "Nutrition"],
            "specializations": ["Programme Verification", "Child Rights Advocacy", "Emergency Response"],
            "skills": [
                {"name": "Programme Management", "endorsements": 520},
                {"name": "Child Rights Advocacy", "endorsements": 380},
                {"name": "Monitoring & Evaluation", "endorsements": 290},
            ],
            "languages": ["Arabic", "English", "French"],
            "employment_status": "Employed",
            "verification_level": "VERIFIED",
            "impact_tier": "Luminary",
            "professional_rank": "Senior Correspondent",
            "endorsements_count": 680,
            "followers_count": 5500,
            "following_count": 310,
            "experience": [
                {"role": "Communications Specialist", "org": "UNICEF Egypt", "from": "2018", "to": "Present", "impact": "Led Egypt child rights campaign"}
            ],
            "education": [
                {"institution": "American University in Cairo", "degree": "MA Public Policy", "year": 2016}
            ],
            "awards": [],
            "social_links": {"twitter": "@UNICEFEgypt"},
        },
        "wallet_balance": 3000,
        "posts": [
            {
                "text": "SYNERGY: UNICEF Egypt partners with MASAREN to verify the impact of our child nutrition and education programmes. Every child reached, every outcome verified.",
                "kind": "synergy",
                "sdg": 4,
                "impact_value": 15000,
                "impact_label": "children reached",
                "confidence": 96.0,
                "media": [{"type": "image", "url": "https://picsum.photos/seed/unicef_egypt/900/600", "name": "UNICEF programme"}],
                "likes": 3200,
                "shares": 750,
            },
        ],
    },
    {
        "email": "red_crescent@masaren.org",
        "full_name": "Egyptian Red Crescent",
        "role": "NGO",
        "audience": "NGO",
        "profile": {
            "bio": "The Egyptian Red Crescent — part of the International Red Cross and Red Crescent Movement, providing humanitarian aid across Egypt.",
            "country": "Egypt",
            "city": "Cairo",
            "languages": ["Arabic", "English", "French"],
            "latitude": 30.0444,
            "longitude": 31.2357,
            "target_audience": "NGO",
            "website": "https://www.redcrescent.org.eg",
            "social_links": {"twitter": "@ERCSofficial", "instagram": "egyptianredcrescent"},
        },
        "personnel": {
            "headline": "Egyptian Red Crescent — Disaster Response & First Aid",
            "summary": "Leading humanitarian response in Egypt, providing disaster relief, first aid training, and community resilience programmes.",
            "mission": "Alleviating human suffering and protecting life and dignity through verified humanitarian action.",
            "beat": "Humanitarian Response",
            "expertise": ["Disaster Response", "First Aid", "Community Resilience", "Blood Bank"],
            "specializations": ["Emergency Response", "First Aid Training", "Refugee Support"],
            "skills": [
                {"name": "Disaster Response", "endorsements": 450},
                {"name": "First Aid Training", "endorsements": 380},
                {"name": "Community Health", "endorsements": 260},
            ],
            "languages": ["Arabic", "English", "French"],
            "employment_status": "NGO",
            "verification_level": "VERIFIED",
            "impact_tier": "Authority",
            "professional_rank": "Correspondent",
            "endorsements_count": 520,
            "followers_count": 4200,
            "following_count": 280,
            "experience": [
                {"role": "Head of Communications", "org": "Egyptian Red Crescent", "from": "2017", "to": "Present", "impact": "Coordinated COVID-19 response media"}
            ],
            "education": [
                {"institution": "Cairo University", "degree": "International Humanitarian Law", "year": 2014}
            ],
            "awards": [],
            "social_links": {"twitter": "@ERCSofficial"},
        },
        "wallet_balance": 3000,
        "posts": [
            {
                "text": "SYNERGY: The Egyptian Red Crescent adopts MASAREN's POAI system to verify every humanitarian intervention — from earthquake response to first aid training. Verified trust saves lives.",
                "kind": "synergy",
                "sdg": 17,
                "impact_value": 8000,
                "impact_label": "first responders trained",
                "confidence": 94.5,
                "media": [{"type": "image", "url": "https://picsum.photos/seed/red_crescent/900/600", "name": "First aid training"}],
                "likes": 2400,
                "shares": 560,
            },
        ],
    },
    {
        "email": "tech_hub_cairo@masaren.org",
        "full_name": "Cairo Tech Hub",
        "role": "Company",
        "audience": "CORPORATE",
        "profile": {
            "bio": "Cairo Tech Hub — Egypt's leading technology incubator, supporting startups and building the MENA digital ecosystem.",
            "country": "Egypt",
            "city": "Cairo",
            "languages": ["Arabic", "English"],
            "latitude": 30.0131,
            "longitude": 31.2089,
            "target_audience": "CORPORATE",
            "website": "https://www.cairotechhub.com",
            "social_links": {"twitter": "@CairoTechHub", "linkedin": "cairo-tech-hub"},
        },
        "personnel": {
            "headline": "Cairo Tech Hub — Innovation & Ecosystem",
            "summary": "Building Egypt's tech future through incubation, acceleration, and verified impact programmes.",
            "mission": "Accelerating Egypt's digital economy by empowering startups with transparent, verified support programmes.",
            "beat": "Technology & Innovation",
            "expertise": ["Startup Incubation", "Venture Building", "Tech Education", "Ecosystem Development"],
            "specializations": ["Startup Acceleration", "Innovation Policy", "Digital Skills"],
            "skills": [
                {"name": "Startup Incubation", "endorsements": 310},
                {"name": "Venture Building", "endorsements": 240},
                {"name": "Digital Skills Training", "endorsements": 180},
            ],
            "languages": ["Arabic", "English"],
            "employment_status": "Employed",
            "verification_level": "VERIFIED",
            "impact_tier": "Professional",
            "professional_rank": "Field Reporter II",
            "endorsements_count": 260,
            "followers_count": 2100,
            "following_count": 350,
            "experience": [
                {"role": "CEO & Founder", "org": "Cairo Tech Hub", "from": "2021", "to": "Present", "impact": "Incubated 80+ startups"}
            ],
            "education": [
                {"institution": "MIT Sloan School of Management", "degree": "Executive Certificate in Strategy & Innovation", "year": 2020}
            ],
            "awards": [
                {"title": "MENA Best Incubator", "year": 2024, "detail": "Arabnet Awards"}
            ],
            "social_links": {"twitter": "@CairoTechHub", "linkedin": "cairo-tech-hub"},
        },
        "wallet_balance": 2000,
        "posts": [
            {
                "text": "SYNERGY: Cairo Tech Hub × MASAREN — tracking the real impact of our startup programmes. Every job created, every product launched, every metric verified on-chain.",
                "kind": "synergy",
                "sdg": 8,
                "impact_value": 80,
                "impact_label": "startups incubated",
                "confidence": 90.0,
                "media": [{"type": "image", "url": "https://picsum.photos/seed/cairotechhub/900/600", "name": "Tech hub workspace"}],
                "likes": 1600,
                "shares": 380,
            },
        ],
    },
]


# ── Seed logic ────────────────────────────────────────────────────────────────
async def seed():
    print(f"\n{'='*60}")
    print("  MASAREN Profile Seed Script")
    print(f"{'='*60}")
    print(f"  Connecting to: {DB_DSN.split('@')[1] if '@' in DB_DSN else DB_DSN}")
    print(f"  Profiles to seed: {len(PROFILES)}")
    print(f"  Password: {PASSWORD}")
    print(f"{'='*60}\n")

    conn = await asyncpg.connect(DB_DSN)
    try:
        created_users = 0
        skipped_users = 0
        created_profiles = 0
        created_personnel = 0
        created_wallets = 0
        created_posts = 0

        for profile in PROFILES:
            email = profile["email"]
            full_name = profile["full_name"]
            role = profile["role"]
            audience = profile["audience"]

            # ── Check if user exists ──────────────────────────────────────
            existing = await conn.fetchrow(
                "SELECT id FROM users WHERE email = $1", email
            )
            if existing:
                print(f"  SKIP  {email} (already exists)")
                skipped_users += 1
                user_id = existing["id"]
            else:
                # ── Create user ───────────────────────────────────────────
                user_id = uuid.uuid4()
                try:
                    await conn.execute(
                        """INSERT INTO users
                           (id, email, phone, full_name, role, status, hashed_password,
                            email_verified, phone_verified, pms_score, certificate_count,
                            impact_asset_count, version, created_at, updated_at)
                           VALUES ($1, $2, '', $3, $4, 'ACTIVE', $5,
                                   true, false, 0, 0, 0, 0, NOW(), NOW())""",
                        user_id, email, full_name, role, HASHED_PW,
                    )
                    created_users += 1
                    print(f"  USER  {email} — {full_name} ({role})")
                except Exception as e:
                    if "unique" in str(e).lower() or "duplicate" in str(e).lower():
                        print(f"  SKIP  {email} (race condition, already exists)")
                        skipped_users += 1
                        row = await conn.fetchrow(
                            "SELECT id FROM users WHERE email = $1", email
                        )
                        user_id = row["id"] if row else user_id
                    else:
                        print(f"  ERROR {email}: {e}")
                        continue

            # ── Create user_profile ───────────────────────────────────────
            pp = profile["profile"]
            existing_profile = await conn.fetchrow(
                "SELECT id FROM user_profiles WHERE user_id = $1", user_id
            )
            if existing_profile:
                print(f"  SKIP  profile for {email} (exists)")
            else:
                await conn.execute(
                    """INSERT INTO user_profiles
                       (id, user_id, bio, avatar_url, cover_url, country, city,
                        languages, latitude, longitude, target_audience,
                        gallery_ids, followers_count, following_count,
                        website, social_links, created_at)
                       VALUES ($1, $2, $3, NULL, NULL, $4, $5,
                               $6, $7, $8, $9,
                               ARRAY[]::uuid[], 0, 0,
                               $10, $11, NOW())""",
                    uuid.uuid4(),
                    user_id,
                    pp.get("bio", ""),
                    pp.get("country"),
                    pp.get("city"),
                    pp.get("languages", []),
                    pp.get("latitude"),
                    pp.get("longitude"),
                    audience,
                    pp.get("website"),
                    _jsonb(pp.get("social_links", {})),
                )
                created_profiles += 1
                print(f"  PROFS {email}")

            # ── Create m_personnel ────────────────────────────────────────
            pn = profile.get("personnel", {})
            existing_pn = await conn.fetchrow(
                "SELECT user_id FROM m_personnel WHERE user_id = $1",
                str(user_id),
            )
            if existing_pn:
                print(f"  SKIP  personnel for {email} (exists)")
            else:
                await conn.execute(
                    """INSERT INTO m_personnel
                       (user_id, headline, summary, mission, beat,
                        expertise, specializations, skills,
                        education, experience, certificates, awards,
                        publications, memberships,
                        employment_status, availability, verification_level,
                        impact_tier, professional_rank,
                        languages, social_links,
                        endorsements_count, followers_count, following_count,
                        updated_at)
                       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24,NOW())""",
                    str(user_id),
                    pn.get("headline", ""),
                    pn.get("summary", ""),
                    pn.get("mission", ""),
                    pn.get("beat", ""),
                    _jsonb(pn.get("expertise", [])),
                    _jsonb(pn.get("specializations", [])),
                    _jsonb(pn.get("skills", [])),
                    _jsonb(pn.get("education", [])),
                    _jsonb(pn.get("experience", [])),
                    _jsonb(pn.get("certificates", [])),
                    _jsonb(pn.get("awards", [])),
                    _jsonb(pn.get("publications", [])),
                    _jsonb(pn.get("memberships", [])),
                    pn.get("employment_status", "Independent"),
                    pn.get("availability", "Open to opportunities"),
                    pn.get("verification_level", "VERIFIED"),
                    pn.get("impact_tier", "Contributor"),
                    pn.get("professional_rank", "Field Reporter"),
                    _jsonb(pn.get("languages", [])),
                    _jsonb(pn.get("social_links", {})),
                    pn.get("endorsements_count", 0),
                    pn.get("followers_count", 0),
                    pn.get("following_count", 0),
                )
                created_personnel += 1
                print(f"  PERSN {email}")

            # ── Create wallet ─────────────────────────────────────────────
            balance = profile.get("wallet_balance", 1000)
            existing_wallet = await conn.fetchrow(
                "SELECT owner_id FROM wallets WHERE owner_id = $1",
                str(user_id),
            )
            if existing_wallet:
                print(f"  SKIP  wallet for {email} (exists)")
            else:
                await conn.execute(
                    """INSERT INTO wallets (owner_id, balance, currency, created_at, updated_at)
                       VALUES ($1, $2, 'MRC', NOW(), NOW())""",
                    str(user_id), float(balance),
                )
                # Record the initial coin transaction
                await conn.execute(
                    """INSERT INTO coin_transactions
                       (id, owner_id, counterparty_id, type, amount, balance_after, reference, created_at)
                       VALUES (gen_random_uuid(), $1, NULL, 'EARN', $2, $2, 'Welcome bonus — seed script', NOW())""",
                    str(user_id), float(balance),
                )
                created_wallets += 1
                print(f"  WALLET {email} — {balance} MRC")

            # ── Create posts ──────────────────────────────────────────────
            for post_data in profile.get("posts", []):
                # Skip if user already has posts (idempotent)
                existing_post_count = await conn.fetchval(
                    "SELECT COUNT(*) FROM posts WHERE author_id = $1",
                    str(user_id),
                )
                if existing_post_count and existing_post_count > 0:
                    print(f"  SKIP  posts for {email} ({existing_post_count} exist)")
                    break

                post_id = uuid.uuid4().hex
                post_media = post_data.get("media", [])
                post_comments = []
                author_handle = email.split("@")[0]

                await conn.execute(
                    """INSERT INTO posts
                       (id, author_id, author_name, author_handle,
                        author_verified, author_role, text, kind,
                        program_tag, sdg, impact_value, impact_label,
                        confidence, media, comments, likes, shares,
                        created_at, updated_at)
                       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,NOW(),NOW())""",
                    post_id,
                    str(user_id),
                    full_name,
                    author_handle,
                    True,
                    role,
                    post_data.get("text", ""),
                    post_data.get("kind", "story"),
                    None,
                    post_data.get("sdg", 0),
                    post_data.get("impact_value", 0),
                    post_data.get("impact_label"),
                    post_data.get("confidence", 85.0),
                    _jsonb(post_media),
                    _jsonb(post_comments),
                    post_data.get("likes", 0),
                    post_data.get("shares", 0),
                )
                created_posts += 1
                print(f"  POST  [{post_data.get('kind','story')}] {email}")

        print(f"\n{'='*60}")
        print(f"  SEED COMPLETE")
        print(f"{'='*60}")
        print(f"  Users created:     {created_users}")
        print(f"  Users skipped:     {skipped_users}")
        print(f"  Profiles created:  {created_profiles}")
        print(f"  Personnel created: {created_personnel}")
        print(f"  Wallets created:   {created_wallets}")
        print(f"  Posts created:     {created_posts}")
        print(f"{'='*60}\n")
        print(f"  All accounts use password: {PASSWORD}")
        print(f"  Login URL: POST /api/v1/auth/login")
        print(f"  Example:   {{\"email\": \"mohamed_salah@masaren.org\", \"password\": \"{PASSWORD}\"}}")
        print()

    finally:
        await conn.close()


def _jsonb(obj) -> str:
    """Serialize to JSON string for asyncpg JSONB columns."""
    import json
    return json.dumps(obj)


# ── Entry point ───────────────────────────────────────────────────────────────
if __name__ == "__main__":
    asyncio.run(seed())
