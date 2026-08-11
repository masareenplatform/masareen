"""Application event handlers for verification domain."""
from datetime import datetime
from shared.utils.cqrs import CommandHandler
from shared.utils.outbox import OutboxWriter
from shared.utils.logging import get_logger
from shared.exceptions import NotFoundException, ConflictException
from ..domain.evidence_record import EvidenceRecord, EvidenceStatus
from ..domain.verification_pipeline import VerificationPipeline, PipelineStatus
from .commands import (
    StartVerificationPipelineCommand,
    RecordAIVerificationResultCommand,
    StartFraudCheckCommand,
    StartHumanReviewCommand,
    RecordHumanVerdictCommand,
    SubmitVerificationCommand,
    RejectVerificationCommand,
    SubmitForHumanReviewCommand,
)

log = get_logger(__name__)
T_AI_REVIEW         = "masaren.verification.ai_review.v1"
T_FRAUD_CHECK       = "masaren.verification.fraud_check.v1"
T_HUMAN_REVIEW      = "masaren.verification.human_review.v1"
T_VERIFICATION      = "masaren.verification.verification.v1"
T_PIPELINE_STARTED  = "masaren.verification.pipeline_started.v1"
T_EVIDENCE_SUBMITTED= "masaren.verification.evidence_submitted.v1"
T_EVIDENCE_REJECTED = "masaren.verification.evidence_rejected.v1"


class StartVerificationPipelineHandler(CommandHandler):
    """Handler for starting verification pipeline."""

    def __init__(self, evidence_repo, pipeline_repo, outbox):
        self.evidence_repo = evidence_repo
        self.pipeline_repo = pipeline_repo
        self.outbox = outbox

    async def handle(self, cmd: StartVerificationPipelineCommand):
        evidence = await self.evidence_repo.get_by_id(cmd.evidence_id)
        if not evidence:
            raise NotFoundException("Evidence", cmd.evidence_id)

        if evidence.status != EvidenceStatus.UPLOADED:
            raise ConflictException("Evidence must be uploaded before verification")

        pipeline = VerificationPipeline.create(
            evidence_id=cmd.evidence_id,
            task_id=cmd.task_id,
            submitted_by=cmd.submitted_by,
            ai_confidence_threshold=cmd.ai_confidence_threshold,
            fraud_risk_threshold=cmd.fraud_risk_threshold
        )

        pipeline = await self.pipeline_repo.save(pipeline)

        for evt in pipeline.pull_domain_events():
            await self.outbox.write(None, evt, T_PIPELINE_STARTED)

        log.info("verification_pipeline_started", 
                 pipeline_id=pipeline.pipeline_id,
                 evidence_id=evidence.evidence_id)

        return {"pipeline_id": pipeline.pipeline_id, "status": pipeline.status.value}


class RecordAIVerificationHandler(CommandHandler):
    """Handler for recording AI verification results."""

    def __init__(self, evidence_repo, pipeline_repo, outbox):
        self.evidence_repo = evidence_repo
        self.pipeline_repo = pipeline_repo
        self.outbox = outbox

    async def handle(self, cmd: RecordAIVerificationResultCommand):
        evidence = await self.evidence_repo.get_by_id(cmd.evidence_id)
        if not evidence:
            raise NotFoundException("Evidence", cmd.evidence_id)

        evidence.record_ai_result(cmd.verdict, cmd.confidence)
        evidence = await self.evidence_repo.save(evidence)

        for evt in evidence.pull_domain_events():
            await self.outbox.write(evidence.id, evt, T_AI_REVIEW)

        log.info("ai_verification_recorded",
                 evidence_id=evidence.evidence_id,
                 verdict=cmd.verdict,
                 confidence=cmd.confidence)

        return {"evidence_id": evidence.evidence_id, "verdict": cmd.verdict}


class StartFraudCheckHandler(CommandHandler):
    """Handler for starting fraud check."""

    def __init__(self, pipeline_repo, evidence_repo):
        self.pipeline_repo = pipeline_repo
        self.evidence_repo = evidence_repo

    async def handle(self, cmd: StartFraudCheckCommand):
        pipeline = await self.pipeline_repo.get_by_id(cmd.pipeline_id)
        if not pipeline:
            raise NotFoundException("Pipeline", cmd.pipeline_id)

        if pipeline.status != PipelineStatus.AI_REVIEW:
            raise ConflictException("Pipeline must be in AI_REVIEW state")

        evidence = await self.evidence_repo.get_by_id(cmd.evidence_id)
        if not evidence:
            raise NotFoundException("Evidence", cmd.evidence_id)

        # Calculate risk score based on real evidence attributes
        risk_score = 0
        risk_factors: list[str] = []
        if not evidence.checksum:
            risk_score += 40
            risk_factors.append("missing_content_checksum")
        if (evidence.latitude is None or evidence.longitude is None
                or (evidence.latitude == 0.0 and evidence.longitude == 0.0)):
            risk_score += 25
            risk_factors.append("null_or_default_gps")
        if evidence.ai_confidence_score < 0.6:
            risk_score += 15
            risk_factors.append("low_ai_confidence")
        risk_score = min(risk_score, 100)

        risk_verdict = "HIGH" if risk_score > 30 else "LOW"

        pipeline.start_fraud_check()
        pipeline.record_fraud_result(
            risk_score, risk_verdict,
            notes=";".join(risk_factors) if risk_factors else "none",
        )
        pipeline = await self.pipeline_repo.save(pipeline)

        log.info("fraud_check_completed",
                 pipeline_id=pipeline.pipeline_id,
                 risk_score=risk_score,
                 verdict=risk_verdict)

        if pipeline.requires_human_review:
            return {"status": "Routed to human review", "risk_score": risk_score}
        else:
            return {"status": "Auto-approved", "risk_score": risk_score}


class StartHumanReviewHandler(CommandHandler):
    """Handler for starting human review."""

    def __init__(self, pipeline_repo, evidence_repo):
        self.pipeline_repo = pipeline_repo
        self.evidence_repo = evidence_repo

    async def handle(self, cmd: StartHumanReviewCommand):
        pipeline = await self.pipeline_repo.get_by_id(cmd.pipeline_id)
        if not pipeline:
            raise NotFoundException("Pipeline", cmd.pipeline_id)

        if pipeline.status != PipelineStatus.FRAUD_CHECK and pipeline.status != PipelineStatus.HUMAN_REVIEW:
            raise ConflictException("Pipeline must be in FRAUD_CHECK or HUMAN_REVIEW state")

        evidence = await self.evidence_repo.get_by_id(cmd.evidence_id)
        if not evidence:
            raise NotFoundException("Evidence", cmd.evidence_id)

        evidence.assign_reviewer(cmd.reviewer_id if cmd.reviewer_id else "default-reviewer")
        evidence.start_human_review()
        evidence = await self.evidence_repo.save(evidence)

        log.info("human_review_started",
                 evidence_id=evidence.evidence_id,
                 pipeline_id=pipeline.pipeline_id,
                 reviewer_id=evidence.assigned_reviewer)

        return {"status": "Human review started", "reviewer_id": evidence.assigned_reviewer}


class RecordHumanVerdictHandler(CommandHandler):
    """Handler for recording human verdict."""

    def __init__(self, evidence_repo, pipeline_repo, outbox):
        self.evidence_repo = evidence_repo
        self.pipeline_repo = pipeline_repo
        self.outbox = outbox

    async def handle(self, cmd: RecordHumanVerdictCommand):
        pipeline = await self.pipeline_repo.get_by_id(cmd.pipeline_id)
        if not pipeline:
            raise NotFoundException("Pipeline", cmd.pipeline_id)

        evidence = await self.evidence_repo.get_by_id(cmd.evidence_id)
        if not evidence:
            raise NotFoundException("Evidence", cmd.evidence_id)

        evidence.record_human_verdict(cmd.verdict, cmd.reviewer_id, cmd.confidence, cmd.notes)
        evidence = await self.evidence_repo.save(evidence)

        for evt in evidence.pull_domain_events():
            await self.outbox.write(evidence.id, evt, T_HUMAN_REVIEW)

        log.info("human_verdict_recorded",
                 evidence_id=evidence.evidence_id,
                 verdict=cmd.verdict,
                 reviewer_id=cmd.reviewer_id,
                 confidence=cmd.confidence)

        return {
            "evidence_id": evidence.evidence_id,
            "final_verdict": evidence.final_verdict.value if evidence.final_verdict else None,
            "status": evidence.status.value
        }


class SubmitVerificationHandler(CommandHandler):
    """Handler for submitting evidence for verification."""

    def __init__(self, evidence_repo):
        self.evidence_repo = evidence_repo

    async def handle(self, cmd: SubmitVerificationCommand):
        evidence = await self.evidence_repo.get_by_id(cmd.evidence_id)
        if not evidence:
            raise NotFoundException("Evidence", cmd.evidence_id)

        evidence.submit(cmd.evidence_id)
        evidence = await self.evidence_repo.save(evidence)

        log.info("evidence_submitted",
                 evidence_id=evidence.evidence_id,
                 submitted_by=cmd.submitted_by)

        return {"evidence_id": evidence.evidence_id, "status": evidence.status.value}


class RejectVerificationHandler(CommandHandler):
    """Handler for rejecting evidence verification."""

    def __init__(self, evidence_repo, outbox):
        self.evidence_repo = evidence_repo
        self.outbox = outbox

    async def handle(self, cmd: RejectVerificationCommand):
        evidence = await self.evidence_repo.get_by_id(cmd.evidence_id)
        if not evidence:
            raise NotFoundException("Evidence", cmd.evidence_id)

        evidence.status = EvidenceStatus.REJECTED
        evidence.final_verdict = "REJECTED"
        evidence.updated_at = datetime.utcnow()
        evidence = await self.evidence_repo.save(evidence)

        log.info("evidence_rejected",
                 evidence_id=evidence.evidence_id,
                 reason=cmd.reason)

        return {"evidence_id": evidence.evidence_id, "status": evidence.status.value}


class SubmitForHumanReviewHandler(CommandHandler):
    """Handler for submitting evidence for human review."""

    def __init__(self, evidence_repo, pipeline_repo, outbox):
        self.evidence_repo = evidence_repo
        self.pipeline_repo = pipeline_repo
        self.outbox = outbox

    async def handle(self, cmd: SubmitForHumanReviewCommand):
        evidence = await self.evidence_repo.get_by_id(cmd.evidence_id)
        if not evidence:
            raise NotFoundException("Evidence", cmd.evidence_id)

        pipeline = await self.pipeline_repo.get_by_evidence_id(cmd.evidence_id)
        if not pipeline:
            raise NotFoundException("Pipeline", "")

        evidence.start_human_review()
        evidence = await self.evidence_repo.save(evidence)

        log.info("evidence_submitted_for_human_review",
                 evidence_id=evidence.evidence_id,
                 pipeline_id=pipeline.pipeline_id,
                 reason=cmd.reason)

        return {"evidence_id": evidence.evidence_id, "status": evidence.status.value}
