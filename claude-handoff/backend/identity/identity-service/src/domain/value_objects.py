"""Value objects for the Identity domain."""
from __future__ import annotations
import re
from dataclasses import dataclass

from shared.exceptions import ValidationException


@dataclass(frozen=True)
class Email:
    value: str

    def __post_init__(self):
        pattern = r"^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$"
        if not re.match(pattern, self.value):
            raise ValidationException(f"'{self.value}' is not a valid email address.")

    def __str__(self) -> str:
        return self.value


@dataclass(frozen=True)
class PhoneNumber:
    value: str

    def __post_init__(self):
        digits = re.sub(r"[\s\-\(\)]", "", self.value)
        if not re.match(r"^\+?[1-9]\d{6,14}$", digits):
            raise ValidationException(f"'{self.value}' is not a valid phone number.")

    def __str__(self) -> str:
        return self.value


@dataclass(frozen=True)
class ImpactPassport:
    """
    An individual's portable verifiable identity across MASAREN.
    Encodes the user's PMS tier and verification level as a compact string.
    Format: MP-{USER_ID_SHORT}-{TIER}-{VERIFICATION_LEVEL}
    Example: MP-A1B2C3D4-GOLD-L3
    """
    user_id: str
    tier: str        # BRONZE | SILVER | GOLD | PLATINUM
    level: int       # 1–5 verification depth

    TIERS = ["BRONZE", "SILVER", "GOLD", "PLATINUM"]
    PMS_THRESHOLDS = {
        "BRONZE":   0.0,
        "SILVER":   0.40,
        "GOLD":     0.65,
        "PLATINUM": 0.85,
    }

    @classmethod
    def compute_tier(cls, pms_score: float) -> str:
        tier = "BRONZE"
        for t, threshold in cls.PMS_THRESHOLDS.items():
            if pms_score >= threshold:
                tier = t
        return tier

    @property
    def passport_id(self) -> str:
        short = self.user_id.replace("-", "")[:8].upper()
        return f"MP-{short}-{self.tier}-L{self.level}"

    def __str__(self) -> str:
        return self.passport_id
