"""
Command handlers for the Identity service.
Each handler: validates → loads aggregate → mutates → saves → publishes events.
"""
from __future__ import annotations
from typing import Any

from shared.exceptions import ConflictException, NotFoundException
from shared.middleware import hash_password
from shared.utils.cqrs import CommandHandler, QueryHandler
from shared.utils.outbox import OutboxWriter
from shared.utils.logging import get_logger

from ..domain.user import User, UserProfile, UserSkill, UserRole
from ..domain.user_repository import UserRepository
from ..domain.value_objects import ImpactPassport
from .commands import (
    RegisterUserCommand, VerifyEmailCommand, UpdateUserProfileCommand,
    AddSkillToUserCommand, SuspendUserCommand, UpdatePMSScoreCommand,
)
from .queries import (
    GetUserByIdQuery, GetUserByEmailQuery, ListUsersQuery, GetImpactPassportQuery,
)

log = get_logger(__name__)

# Topic constants
TOPIC_IDENTITY = "masaren.identity.user_registered.v1"
TOPIC_VERIFIED = "masaren.identity.user_verified.v1"
TOPIC_PMS      = "masaren.identity.pms_updated.v1"


# ── Command Handlers ──────────────────────────────────────────────────────────

class RegisterUserHandler(CommandHandler):
    def __init__(self, repo: UserRepository, session, outbox: OutboxWriter):
        self._repo    = repo
        self._session = session
        self._outbox  = outbox

    async def handle(self, command: RegisterUserCommand) -> dict:
        from ...config.settings import settings

        if await self._repo.exists_by_email(command.email):
            raise ConflictException(f"Email '{command.email}' is already registered.")

        hashed = hash_password(command.password)
        role = UserRole(command.role) if command.role in UserRole.__members__.values() else UserRole.INDIVIDUAL
        user = User.register(
            email=command.email,
            full_name=command.full_name,
            hashed_password=hashed,
            phone=command.phone,
            national_id=command.national_id,
            university_id=command.university_id,
            role=role,
            audience=command.audience,
        )

        # Alpha mode: auto-verify + activate so the new account can sign in
        # immediately without an email-verification round trip. Gated by the
        # AUTO_VERIFY_ON_REGISTER env flag so production keeps the verification flow.
        auto_verified = False
        if settings.auto_verify_on_register:
            user.verify_email()
            auto_verified = True

        saved = await self._repo.save(user)

        # Publish events via outbox (atomic with the save)
        for event in saved.pull_domain_events():
            await self._outbox.write(self._session, event, TOPIC_IDENTITY)

        log.info("user_registered", user_id=saved.id, email=saved.email, auto_verified=auto_verified)
        return {
            "user_id": saved.id,
            "email": saved.email,
            "status": saved.status.value,
            "auto_verified": auto_verified,
            "message": (
                "Registration successful. Your account is verified — you can sign in now."
                if auto_verified else
                "Registration successful. Please verify your email to activate your account."
            ),
        }


class VerifyEmailHandler(CommandHandler):
    def __init__(self, repo: UserRepository, session, token_store):
        self._repo        = repo
        self._session     = session
        self._token_store = token_store  # Redis-backed token store injected

    async def handle(self, command: VerifyEmailCommand) -> dict:
        # Validate token (Redis lookup)
        stored_user_id = await self._token_store.get(f"email_verify:{command.token}")
        if not stored_user_id or stored_user_id != command.user_id:
            from shared.exceptions import ValidationException
            raise ValidationException("Invalid or expired verification token.")

        user = await self._repo.get_by_id(command.user_id)
        if not user:
            raise NotFoundException("User", command.user_id)

        user.verify_email()
        await self._repo.save(user)
        await self._token_store.delete(f"email_verify:{command.token}")

        log.info("email_verified", user_id=user.id)
        return {"user_id": user.id, "status": user.status.value}


class UpdateUserProfileHandler(CommandHandler):
    def __init__(self, repo: UserRepository):
        self._repo = repo

    async def handle(self, command: UpdateUserProfileCommand) -> dict:
        user = await self._repo.get_by_id(command.user_id)
        if not user:
            raise NotFoundException("User", command.user_id)

        existing = user.profile
        profile = UserProfile(
            bio=command.bio if command.bio is not None else (existing.bio if existing else None),
            avatar_url=command.avatar_url if command.avatar_url is not None else (existing.avatar_url if existing else None),
            cover_url=existing.cover_url if existing else None,
            country=command.country if command.country is not None else (existing.country if existing else None),
            city=command.city if command.city is not None else (existing.city if existing else None),
            languages=command.languages if command.languages is not None else (existing.languages if existing else []),
            latitude=command.latitude if command.latitude is not None else (existing.latitude if existing else None),
            longitude=command.longitude if command.longitude is not None else (existing.longitude if existing else None),
            target_audience=existing.target_audience if (existing and existing.target_audience) else "STUDENT",
            gallery_ids=existing.gallery_ids if existing else [],
            followers_count=existing.followers_count if existing else 0,
            following_count=existing.following_count if existing else 0,
            website=existing.website if existing else None,
            social_links=existing.social_links if existing else {},
        )
        user.update_profile(profile)
        await self._repo.save(user)
        log.info("profile_updated", user_id=user.id)
        return {"user_id": user.id}


class AddSkillHandler(CommandHandler):
    def __init__(self, repo: UserRepository):
        self._repo = repo

    async def handle(self, command: AddSkillToUserCommand) -> dict:
        user = await self._repo.get_by_id(command.user_id)
        if not user:
            raise NotFoundException("User", command.user_id)

        skill = UserSkill(
            skill_id=command.skill_id,
            skill_name=command.skill_name,
            proficiency=command.proficiency,
        )
        user.add_skill(skill)
        await self._repo.save(user)
        return {"user_id": user.id, "skill_id": command.skill_id}


class SuspendUserHandler(CommandHandler):
    def __init__(self, repo: UserRepository):
        self._repo = repo

    async def handle(self, command: SuspendUserCommand) -> dict:
        user = await self._repo.get_by_id(command.user_id)
        if not user:
            raise NotFoundException("User", command.user_id)
        user.suspend(command.reason)
        await self._repo.save(user)
        log.info("user_suspended", user_id=user.id, admin_id=command.admin_id)
        return {"user_id": user.id, "status": user.status.value}


class UpdatePMSScoreHandler(CommandHandler):
    def __init__(self, repo: UserRepository, session, outbox: OutboxWriter):
        self._repo    = repo
        self._session = session
        self._outbox  = outbox

    async def handle(self, command: UpdatePMSScoreCommand) -> dict:
        user = await self._repo.get_by_id(command.user_id)
        if not user:
            raise NotFoundException("User", command.user_id)
        user.update_pms_score(command.new_score, command.dimensions)
        await self._repo.save(user)
        for event in user.pull_domain_events():
            await self._outbox.write(self._session, event, TOPIC_PMS)
        return {"user_id": user.id, "pms_score": user.pms_score}


# ── Query Handlers ────────────────────────────────────────────────────────────

class GetUserByIdHandler(QueryHandler):
    def __init__(self, repo: UserRepository):
        self._repo = repo

    async def handle(self, query: GetUserByIdQuery):
        user = await self._repo.get_by_id(query.user_id)
        if not user:
            raise NotFoundException("User", query.user_id)
        return user


class GetUserByEmailHandler(QueryHandler):
    def __init__(self, repo: UserRepository):
        self._repo = repo

    async def handle(self, query: GetUserByEmailQuery):
        user = await self._repo.get_by_email(query.email)
        if not user:
            raise NotFoundException("User", query.email)
        return user


class ListUsersHandler(QueryHandler):
    def __init__(self, repo: UserRepository):
        self._repo = repo

    async def handle(self, query: ListUsersQuery):
        users, total = await self._repo.list_users(
            limit=query.limit, offset=query.offset, role=query.role
        )
        return users, total


class GetImpactPassportHandler(QueryHandler):
    def __init__(self, repo: UserRepository):
        self._repo = repo

    async def handle(self, query: GetImpactPassportQuery):
        user = await self._repo.get_by_id(query.user_id)
        if not user:
            raise NotFoundException("User", query.user_id)
        tier = ImpactPassport.compute_tier(user.pms_score)
        passport = ImpactPassport(user_id=user.id, tier=tier, level=2 if user.email_verified else 1)
        return {
            "user_id":      user.id,
            "full_name":    user.full_name,
            "pms_score":    user.pms_score,
            "tier":         tier,
            "passport_id":  passport.passport_id,
            "email_verified": user.email_verified,
            "skills_count": len(user.skills),
        }
