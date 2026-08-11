"""Tests for the EfficiencySelector domain selection logic."""
import pytest

from src.domain.model import CapabilityState, Language, Policy, Variant


def _variant(cap, lang, ver, p50=None, rps=None, healthy=True):
    return Variant(
        capability=cap, language=lang, version=ver,
        health_url=f"http://{lang}/{cap}/health",
        bench_url=f"http://{lang}/{cap}/bench",
        business_url=f"http://{lang}/{cap}",
        healthy=healthy, p50_ms=p50, throughput_rps=rps, samples=10,
    )


def test_select_prefers_python_when_unmeasured():
    cap = CapabilityState(name="fraud.score")
    cap.add(_variant("fraud.score", Language.PYTHON, "1"))
    cap.add(_variant("fraud.score", Language.RUST, "1"))
    chosen = cap.select()
    assert chosen.language == Language.PYTHON


def test_select_latency_picks_lowest_p50():
    cap = CapabilityState(name="fraud.score", policy=Policy.LATENCY)
    cap.add(_variant("fraud.score", Language.PYTHON, "1", p50=12.0, rps=80))
    cap.add(_variant("fraud.score", Language.RUST, "1", p50=2.0, rps=900))
    assert cap.select().language == Language.RUST


def test_select_throughput_picks_highest_rps():
    cap = CapabilityState(name="fraud.score", policy=Policy.THROUGHPUT)
    cap.add(_variant("fraud.score", Language.PYTHON, "1", p50=12.0, rps=80))
    cap.add(_variant("fraud.score", Language.RUST, "1", p50=2.0, rps=900))
    assert cap.select().language == Language.RUST


def test_select_explicit_pin():
    cap = CapabilityState(name="fraud.score", policy=Policy.EXPLICIT, pinned="fraud.score/go/1")
    cap.add(_variant("fraud.score", Language.PYTHON, "1", p50=12.0, rps=80))
    cap.add(_variant("fraud.score", Language.GO, "1", p50=5.0, rps=400))
    assert cap.select().language == Language.GO


def test_unhealthy_excluded():
    cap = CapabilityState(name="fraud.score")
    cap.add(_variant("fraud.score", Language.PYTHON, "1", p50=12.0, rps=80, healthy=False))
    cap.add(_variant("fraud.score", Language.RUST, "1", p50=2.0, rps=900))
    assert cap.select().language == Language.RUST


def test_no_healthy_returns_none():
    cap = CapabilityState(name="fraud.score")
    cap.add(_variant("fraud.score", Language.PYTHON, "1", healthy=False))
    assert cap.select() is None


def test_ranking_ordered():
    cap = CapabilityState(name="fraud.score", policy=Policy.LATENCY)
    cap.add(_variant("fraud.score", Language.PYTHON, "1", p50=12.0, rps=80))
    cap.add(_variant("fraud.score", Language.RUST, "1", p50=2.0, rps=900))
    cap.add(_variant("fraud.score", Language.GO, "1", p50=5.0, rps=400))
    ranks = cap.ranking()
    assert ranks[0].language == Language.RUST
    assert ranks[-1].language == Language.PYTHON
