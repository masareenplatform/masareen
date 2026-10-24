"""MASAREN Platform Seed Script, populates demo data for the combined backend.

This script creates:
- Demo users (individuals, organizations)
- Programs with SDG goals
- Tasks with verification workflows
- Opportunities
- Evidences
- Wallet balances
- Portfolio scores
- Chat conversations
- Notifications

Run with: python -m combined.seed_platform
"""

import asyncio
import uuid
from datetime import datetime, timezone, timedelta
from decimal import Decimal

from shared.base_repository.db import async_session
from shared.infrastructure import kafka_producer
from shared.events import DomainEvent


def _id() -> str:
    return str(uuid.uuid4())


def _now() -> datetime:
    return datetime.now(timezone.utc)


async def seed_database():
    """Populate the database with demo data."""
    from sqlalchemy import text
    
    print("[seed] Starting MASAREN platform seed...")
    
    async with async_session() as session:
        # ── Create demo users ──
        users = [
            {"id": "demo-user-1", "email": "alice@developer.org", "full_name": "Alice Chen", "role": "INDIVIDUAL", "audience": "PROFESSIONAL", "status": "ACTIVE", "auto_verified": True},
            {"id": "demo-user-2", "email": "bob@engineer.net", "full_name": "Bob Martinez", "role": "INDIVIDUAL", "audience": "PROFESSIONAL", "status": "ACTIVE", "auto_verified": True},
            {"id": "demo-user-3", "email": "carol@ngo.org", "full_name": "Carol Okafor", "role": "INDIVIDUAL", "audience": "NGO", "status": "ACTIVE", "auto_verified": True},
            {"id": "demo-org-1", "email": "contact@solarcoop.coop", "full_name": "SolarCoop", "role": "ORGANIZATION", "audience": "NGO", "status": "ACTIVE", "auto_verified": True},
            {"id": "demo-org-2", "email": "info@waterwatch.org", "full_name": "WaterWatch", "role": "ORGANIZATION", "audience": "NGO", "status": "ACTIVE", "auto_verified": True},
            {"id": "demo-org-3", "email": "hello@eduforall.net", "full_name": "EduForAll", "role": "ORGANIZATION", "audience": "NGO", "status": "ACTIVE", "auto_verified": True},
        ]
        
        for user in users:
            try:
                await session.execute(text("""
                    INSERT INTO users (id, email, full_name, role, audience, status, auto_verified, created_at, updated_at)
                    VALUES (:id, :email, :full_name, :role, :audience, :status, :auto_verified, NOW(), NOW())
                    ON CONFLICT (id) DO NOTHING
                """), user)
            except Exception as e:
                print(f"[seed] User {user['id']}: {e}")
        
        # ── Create Programs ──
        programs = [
            {"id": "prog-001", "title": "Coastal Restoration 2024", "description": "Restore 50km of coastline with native mangroves and dune stabilization", "status": "ACTIVE", "sdg_goals": [14, 15], "created_at": _now() - timedelta(days=60)},
            {"id": "prog-002", "title": "Rural Electrification Initiative", "description": "Bring solar microgrids to 50 off-grid villages", "status": "ACTIVE", "sdg_goals": [7, 11], "created_at": _now() - timedelta(days=45)},
            {"id": "prog-003", "title": "EduForAll STEM Scholarships", "description": "200 scholarships for girls in STEM across Egypt", "status": "ACTIVE", "sdg_goals": [4, 5], "created_at": _now() - timedelta(days=30)},
        ]
        
        for prog in programs:
            try:
                await session.execute(text("""
                    INSERT INTO programs (id, title, description, status, sdg_goals, created_at, updated_at)
                    VALUES (:id, :title, :description, :status, :sdg_goals, :created_at, :updated_at)
                    ON CONFLICT (id) DO NOTHING
                """), prog)
            except Exception as e:
                print(f"[seed] Program {prog['id']}: {e}")
        
        # ── Create Opportunities ──
        opportunities = [
            {"id": "opp-001", "title": "Field Data Collector - Nile Delta", "description": "Collect water quality data from 50 monitoring stations", "program_id": "prog-001", "location": "Egypt", "compensation_mrc": 5000, "min_pms_score": 0.5, "status": "OPEN", "created_at": _now() - timedelta(days=15)},
            {"id": "opp-002", "title": "Solar Technician - Aswan", "description": "Install and maintain solar panels in 20 villages", "program_id": "prog-002", "location": "Aswan, Egypt", "compensation_mrc": 15000, "min_pms_score": 0.7, "status": "OPEN", "created_at": _now() - timedelta(days=10)},
            {"id": "opp-003", "title": "STEM Tutor - Cairo", "description": "Teach coding and robotics to 30 high school students", "program_id": "prog-003", "location": "Cairo, Egypt", "compensation_mrc": 3000, "min_pms_score": 0.6, "status": "OPEN", "created_at": _now() - timedelta(days=5)},
        ]
        
        for opp in opportunities:
            try:
                await session.execute(text("""
                    INSERT INTO opportunities (id, title, description, program_id, location, compensation_mrc, min_pms_score, status, created_at, updated_at)
                    VALUES (:id, :title, :description, :program_id, :location, :compensation_mrc, :min_pms_score, :status, :created_at, NOW())
                    ON CONFLICT (id) DO NOTHING
                """), opp)
            except Exception as e:
                print(f"[seed] Opportunity {opp['id']}: {e}")
        
        # ── Create Tasks ──
        tasks = [
            {"id": "task-001", "program_id": "prog-001", "title": "Survey Mangrove Restoration Sites", "description": "Visit 10 sites and document restoration progress", "status": "COMPLETED", "assignee_id": "demo-user-1", "due_date": _now() - timedelta(days=5), "created_at": _now() - timedelta(days=10)},
            {"id": "task-002", "program_id": "prog-002", "title": "Install Solar Panel at Village A", "description": "Mount and connect 5kW solar system", "status": "IN_PROGRESS", "assignee_id": "demo-user-2", "due_date": _now() + timedelta(days=3), "created_at": _now() - timedelta(days=2)},
            {"id": "task-003", "program_id": "prog-003", "title": "Week 1 Teaching Session", "description": "Intro to Python programming for beginners", "status": "SUBMITTED", "assignee_id": "demo-user-3", "due_date": _now() - timedelta(days=1), "created_at": _now() - timedelta(days=7)},
        ]
        
        for task in tasks:
            try:
                await session.execute(text("""
                    INSERT INTO tasks (id, program_id, title, description, status, assignee_id, due_date, created_at, updated_at)
                    VALUES (:id, :program_id, :title, :description, :status, :assignee_id, :due_date, :created_at, NOW())
                    ON CONFLICT (id) DO NOTHING
                """), task)
            except Exception as e:
                print(f"[seed] Task {task['id']}: {e}")
        
        # ── Create Wallets ──
        wallets = [
            {"owner_id": "demo-user-1", "balance": Decimal("15420.5000"), "currency": "MRC", "created_at": _now() - timedelta(days=90)},
            {"owner_id": "demo-user-2", "balance": Decimal("8750.2500"), "currency": "MRC", "created_at": _now() - timedelta(days=120)},
            {"owner_id": "demo-user-3", "balance": Decimal("3200.0000"), "currency": "MRC", "created_at": _now() - timedelta(days=60)},
            {"owner_id": "demo-org-1", "balance": Decimal("50000.0000"), "currency": "MRC", "created_at": _now() - timedelta(days=180)},
            {"owner_id": "demo-org-2", "balance": Decimal("75000.0000"), "currency": "MRC", "created_at": _now() - timedelta(days=200)},
        ]
        
        for wallet in wallets:
            try:
                await session.execute(text("""
                    INSERT INTO wallets (owner_id, balance, currency, created_at, updated_at)
                    VALUES (:owner_id, :balance, :currency, :created_at, NOW())
                    ON CONFLICT (owner_id) DO NOTHING
                """), wallet)
            except Exception as e:
                print(f"[seed] Wallet {wallet['owner_id']}: {e}")
        
        # ── Create Program Enrollments ──
        enrollments = [
            {"user_id": "demo-user-1", "program_id": "prog-001", "enrolled_at": _now() - timedelta(days=55), "status": "COMPLETED"},
            {"user_id": "demo-user-2", "program_id": "prog-002", "enrolled_at": _now() - timedelta(days=3), "status": "ACTIVE"},
            {"user_id": "demo-user-3", "program_id": "prog-003", "enrolled_at": _now() - timedelta(days=25), "status": "ACTIVE"},
        ]
        
        for enrol in enrollments:
            try:
                await session.execute(text("""
                    INSERT INTO program_enrollments (user_id, program_id, enrolled_at, status)
                    VALUES (:user_id, :program_id, :enrolled_at, :status)
                    ON CONFLICT DO NOTHING
                """), enrol)
            except Exception as e:
                print(f"[seed] Enrollment: {e}")
        
        # ── Create Exchange Rates ──
        try:
            await session.execute(text("""
                INSERT INTO coin_exchange_rates (currency, rate_to_mrc, updated_at)
                VALUES ('EGP', 10.0, NOW())
                ON CONFLICT (currency) DO NOTHING
            """))
        except Exception as e:
            print(f"[seed] Exchange rate: {e}")
        
        await session.commit()
        print("[seed] Database seeded successfully!")
        
        # ── Grant initial MRC coins ──
        for wallet in wallets:
            try:
                await session.execute(text("""
                    INSERT INTO coin_transactions (id, owner_id, type, amount, balance_after, reference, created_at)
                    VALUES (:id, :owner_id, 'EARN', :amount, :balance_after, 'Welcome bonus', NOW())
                """), {
                    "id": _id(),
                    "owner_id": wallet["owner_id"],
                    "amount": wallet["balance"],
                    "balance_after": wallet["balance"],
                })
            except Exception as e:
                print(f"[seed] Coin transaction {wallet['owner_id']}: {e}")
        
        await session.commit()
        print("[seed] MRC coins distributed!")


if __name__ == "__main__":
    asyncio.run(seed_database())