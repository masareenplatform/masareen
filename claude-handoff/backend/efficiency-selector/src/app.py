"""EfficiencySelector FastAPI application."""
from __future__ import annotations

import json
import os

from shared.utils.app_factory import create_app

from .api import router
from .domain.model import Language, Variant
from .infrastructure.registry import Registry

STORE_PATH = os.environ.get(
    "SELECTOR_STORE",
    os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "selector_state.json")),
)
MANIFEST_PATH = os.environ.get(
    "SELECTOR_MANIFEST",
    os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "variants.manifest.json")),
)

# Singleton registry, loaded from disk at import time so state survives restarts.
registry = Registry(STORE_PATH)


def _seed_from_manifest() -> None:
    """Register known variants from the manifest so the selector is ready on boot.

    Variants already present (persisted in the store) are preserved; the manifest
    only adds missing ones. Real benchmarks are still required before selection
    prefers a non-Python variant.
    """
    if not os.path.exists(MANIFEST_PATH):
        return
    try:
        with open(MANIFEST_PATH, "r", encoding="utf-8") as fh:
            data = json.load(fh)
    except (json.JSONDecodeError, OSError):
        return
    for vd in data.get("variants", []):
        try:
            lang = Language(vd["language"])
        except ValueError:
            continue
        key = f"{vd['capability']}/{vd['language']}/{vd['version']}"
        if registry.get_capability(vd["capability"]) and registry.get_capability(
            vd["capability"]
        ).get(key):
            continue
        registry.register_variant(
            Variant(
                capability=vd["capability"],
                language=lang,
                version=vd["version"],
                health_url=vd["health_url"],
                bench_url=vd["bench_url"],
                business_url=vd["business_url"],
            )
        )


async def _on_startup() -> None:
    _seed_from_manifest()


app = create_app(
    "efficiency-selector",
    "0.1.0",
    "Control plane that selects the best language implementation per capability.",
    on_startup=[_on_startup],
)
app.include_router(router, prefix="")
