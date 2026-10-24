"""Unit tests for the OII (Organizational Impact Index) domain, pure, no I/O."""
from src.domain.oii_model import OrganizationalImpactIndex, OIIDimension


def _index_with(values: dict, weight: float = 0.1) -> OrganizationalImpactIndex:
    idx = OrganizationalImpactIndex(organization_id="org-1")
    idx.dimensions = {k: OIIDimension(name=k, value=v, weight=weight) for k, v in values.items()}
    return idx


class TestOIIComputation:
    def test_zero_when_no_dimensions(self):
        idx = OrganizationalImpactIndex(organization_id="org-1")
        assert idx.compute_composite() == 0.0

    def test_weighted_average_all_equal_weights(self):
        idx = _index_with({"verified_impact": 0.8, "compliance": 0.4})
        # equal weights -> simple mean = 0.6
        assert idx.compute_composite() == 0.6

    def test_composite_is_stored_on_instance(self):
        idx = _index_with({"governance": 1.0})
        idx.compute_composite()
        assert idx.composite_index == 1.0

    def test_weighting_respected(self):
        idx = OrganizationalImpactIndex(organization_id="org-2")
        idx.dimensions = {
            "verified_impact": OIIDimension(name="verified_impact", value=1.0, weight=0.9),
            "compliance": OIIDimension(name="compliance", value=0.0, weight=0.1),
        }
        # (1.0*0.9 + 0.0*0.1) / (0.9+0.1) = 0.9
        assert idx.compute_composite() == 0.9
