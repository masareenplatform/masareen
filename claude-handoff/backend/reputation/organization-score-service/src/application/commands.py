from dataclasses import dataclass
from typing import Dict
from shared.utils.cqrs import Command


@dataclass
class UpdateOIICommand(Command):
    organization_id: str
    dimension_values: Dict[str, float]
