"""In-memory registry of capabilities/variants with JSON persistence.

Real persistence: the registry is loaded from and saved to a JSON file so the
selector survives restarts and a restarted agent (or the platform) resumes from
the exact same state. No mock data.
"""
from __future__ import annotations

import json
import os
import threading
from typing import Dict, Optional

from ..domain.model import CapabilityState, Language, Policy, Variant


class Registry:
    def __init__(self, store_path: str) -> None:
        self._store_path = store_path
        self._lock = threading.RLock()
        self._caps: Dict[str, CapabilityState] = {}
        self._load()

    def _load(self) -> None:
        if not os.path.exists(self._store_path):
            return
        try:
            with open(self._store_path, "r", encoding="utf-8") as fh:
                data = json.load(fh)
        except (json.JSONDecodeError, OSError):
            return
        for cap_name, cap_data in data.get("capabilities", {}).items():
            cap = CapabilityState(
                name=cap_name,
                policy=Policy(cap_data.get("policy", "latency")),
                pinned=cap_data.get("pinned"),
            )
            for vd in cap_data.get("variants", []):
                v = Variant(
                    capability=vd["capability"],
                    language=Language(vd["language"]),
                    version=vd["version"],
                    health_url=vd["health_url"],
                    bench_url=vd["bench_url"],
                    business_url=vd["business_url"],
                    healthy=vd.get("healthy", True),
                    p50_ms=vd.get("p50_ms"),
                    throughput_rps=vd.get("throughput_rps"),
                    samples=vd.get("samples", 0),
                    last_bench_at=vd.get("last_bench_at"),
                )
                cap.add(v)
            self._caps[cap_name] = cap

    def save(self) -> None:
        data = {"capabilities": {}}
        with self._lock:
            for name, cap in self._caps.items():
                data["capabilities"][name] = {
                    "policy": cap.policy.value,
                    "pinned": cap.pinned,
                    "variants": [v.to_dict() for v in cap.variants.values()],
                }
        os.makedirs(os.path.dirname(self._store_path) or ".", exist_ok=True)
        tmp = self._store_path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=2)
        os.replace(tmp, self._store_path)

    def get_capability(self, name: str) -> Optional[CapabilityState]:
        with self._lock:
            return self._caps.get(name)

    def ensure_capability(self, name: str) -> CapabilityState:
        with self._lock:
            cap = self._caps.get(name)
            if cap is None:
                cap = CapabilityState(name=name)
                self._caps[name] = cap
            return cap

    def list_capabilities(self):
        with self._lock:
            return list(self._caps.keys())

    def register_variant(self, v: Variant) -> None:
        with self._lock:
            cap = self.ensure_capability(v.capability)
            cap.add(v)
            self.save()

    def update_variant(self, v: Variant) -> None:
        with self._lock:
            cap = self.ensure_capability(v.capability)
            cap.add(v)
            self.save()

    def set_policy(self, capability: str, policy, pinned: Optional[str]) -> None:
        with self._lock:
            cap = self.ensure_capability(capability)
            cap.policy = policy
            cap.pinned = pinned
            self.save()
