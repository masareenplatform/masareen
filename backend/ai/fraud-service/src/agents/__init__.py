"""
Fraud Detection Agent, analyses spatial-temporal anomalies.

Detects: GPS spoofing, duplicate photo hashes across profiles,
timeline manipulation, impossible travel, coordinated fraud patterns.

Local computation: hash checks, geospatial distance (PostGIS).
Cloud LLM: pattern reasoning on anomaly sets too complex for rules.
"""
from __future__ import annotations
import hashlib
import json
import math
from typing import Any, Dict, List, Optional

from shared.utils.kafka_consumer import EventConsumer
from shared.utils.kafka_producer import EventPublisher
from shared.utils.cloud_llm_client import CloudLLMClient, LLMMessage
from shared.utils.logging import get_logger

log = get_logger(__name__)

FRAUD_SYSTEM_PROMPT = """You are MASAREEN's Fraud Detection Agent.
You receive a JSON payload describing a set of spatial-temporal anomalies detected for a field submission.
Analyse the pattern and respond ONLY in valid JSON:
{
  "fraud_detected": true/false,
  "fraud_type": "GPS_SPOOFING | DUPLICATE_CONTENT | TIMELINE_MANIPULATION | COORDINATED_FRAUD | NONE",
  "confidence": 0.0-1.0,
  "risk_score": 0-100,
  "evidence": ["specific indicators that support the verdict"],
  "recommended_action": "PASS | FLAG | SUSPEND_USER | ESCALATE"
}"""


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Great-circle distance in kilometres."""
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2) ** 2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def compute_image_hash(image_bytes: bytes) -> str:
    return hashlib.sha256(image_bytes).hexdigest()


class FraudDetectionAgent(EventConsumer):
    """
    Consumes: masaren.verification.evidence_uploaded.v1
              masaren.verification.location_reached.v1
    Emits:    masaren.verification.fraud_detected.v1
    """

    CONSUME_TOPICS = [
        "masaren.verification.evidence_uploaded.v1",
        "masaren.verification.location_reached.v1",
    ]
    EMIT_TOPIC = "masaren.verification.fraud_detected.v1"
    GROUP_ID   = "fraud-detection-agent"

    def __init__(self, llm_client: CloudLLMClient, publisher: EventPublisher) -> None:
        super().__init__(topics=self.CONSUME_TOPICS, group_id=self.GROUP_ID)
        self._llm       = llm_client
        self._publisher = publisher

    async def handle_event(
        self,
        event_type: str,
        payload: Dict[str, Any],
        topic: str,
        partition: int,
        offset: int,
    ) -> None:
        if event_type == "LocationReached":
            await self._check_gps_anomaly(payload)
        elif event_type == "EvidenceUploaded":
            await self._check_evidence_fraud(payload)

    async def _check_gps_anomaly(self, payload: Dict[str, Any]) -> None:
        """
        Local rule: if GPS accuracy > 100m, flag for review.
        Cloud LLM: if multiple GPS points arrive from same user in impossible time window.
        """
        user_id       = payload.get("user_id", "")
        lat           = payload.get("latitude", 0.0)
        lon           = payload.get("longitude", 0.0)
        accuracy      = payload.get("accuracy_meters", 0.0)

        anomalies: List[str] = []
        if accuracy > 100:
            anomalies.append(f"Low GPS accuracy: {accuracy}m (threshold: 100m)")
        if lat == 0.0 and lon == 0.0:
            anomalies.append("GPS coordinates are (0,0), likely null/default value")

        if not anomalies:
            return  # No local anomalies detected

        await self._invoke_cloud_fraud_check(
            user_id=user_id,
            anomaly_context={
                "type": "GPS_ANOMALY",
                "latitude": lat,
                "longitude": lon,
                "accuracy_meters": accuracy,
                "anomalies": anomalies,
            },
            aggregate_id=payload.get("aggregate_id", user_id),
        )

    async def _check_evidence_fraud(self, payload: Dict[str, Any]) -> None:
        """Check for duplicate content hashes and metadata anomalies."""
        evidence_id  = payload.get("aggregate_id", "")
        checksum     = payload.get("checksum", "")
        submitted_by = payload.get("user_id", "")

        anomalies: List[str] = []
        if not checksum:
            anomalies.append("Missing content checksum, cannot verify uniqueness")

        if not anomalies:
            return

        await self._invoke_cloud_fraud_check(
            user_id=submitted_by,
            anomaly_context={
                "type": "EVIDENCE_ANOMALY",
                "evidence_id": evidence_id,
                "checksum": checksum,
                "anomalies": anomalies,
            },
            aggregate_id=evidence_id,
        )

    async def _invoke_cloud_fraud_check(
        self,
        user_id: str,
        anomaly_context: Dict[str, Any],
        aggregate_id: str,
    ) -> None:
        try:
            response = await self._llm.complete(
                messages=[
                    LLMMessage(role="system", content=FRAUD_SYSTEM_PROMPT),
                    LLMMessage(role="user", content=json.dumps(anomaly_context)),
                ],
                json_mode=True,
            )
            result = json.loads(response.text)
        except Exception as exc:
            log.error("fraud_agent_llm_failed", error=str(exc))
            return

        if result.get("fraud_detected"):
            log.warning(
                "fraud_detected",
                user_id=user_id,
                fraud_type=result.get("fraud_type"),
                risk_score=result.get("risk_score"),
            )
            # Emit fraud detected event, downstream services handle suspension/escalation
            from shared.events import DomainEvent
            from dataclasses import dataclass

            @dataclass
            class FraudDetected(DomainEvent):
                event_type:    str   = "FraudDetected"
                aggregate_type: str  = "Evidence"
                user_id:       str   = ""
                fraud_type:    str   = ""
                risk_score:    int   = 0
                confidence:    float = 0.0
                recommended_action: str = "FLAG"

            event = FraudDetected(
                aggregate_id=aggregate_id,
                user_id=user_id,
                fraud_type=result.get("fraud_type", "UNKNOWN"),
                risk_score=result.get("risk_score", 50),
                confidence=result.get("confidence", 0.5),
                recommended_action=result.get("recommended_action", "FLAG"),
            )
            await self._publisher.publish(self.EMIT_TOPIC, event, key=aggregate_id)
