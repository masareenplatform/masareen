"""Media identifier value object - global unique identifier for media assets."""
from dataclasses import dataclass
from uuid import uuid4


@dataclass(frozen=True)
class MediaId:
    """Media identifier value object - global unique identifier for media assets."""
    value: str

    def __post_init__(self):
        if not self.value:
            raise ValueError("MediaId value cannot be empty.")

    @classmethod
    def generate(cls) -> MediaId:
        return cls(str(uuid4()))

    def __str__(self):
        return self.value
