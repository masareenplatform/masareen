from dataclasses import dataclass
from typing import Dict
from shared.utils.cqrs import Command


@dataclass
class UpdatePMSCommand(Command):
    user_id: str
    dimension_deltas: Dict[str, float]
    source: str = "GRAPH_SYNTHESIS"
