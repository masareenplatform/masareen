import pytest
from decimal import Decimal
from src.domain.pricing_engine import DynamicPricingEngine, PricingConfig

@pytest.fixture
def pricing_engine():
    configs = {
        "verification": PricingConfig(
            service_name="verification",
            base_price=Decimal("10.00"),
            complexity_multiplier={"SIMPLE": Decimal("1.0"), "COMPLEX": Decimal("1.5")},
            urgency_multiplier={"STANDARD": Decimal("1.0"), "EXPRESS": Decimal("1.5")}
        )
    }
    return DynamicPricingEngine(configs)

def test_base_pricing(pricing_engine):
    # Base: 10 * 1.0 * 1.0 = 10.00
    price = pricing_engine.calculate_price("verification", complexity="SIMPLE", urgency="STANDARD", risk_score=0.1)
    assert price == Decimal("10.00")

def test_complexity_and_urgency(pricing_engine):
    # 10 * 1.5 (Complex) * 1.5 (Express) = 22.50
    price = pricing_engine.calculate_price("verification", complexity="COMPLEX", urgency="EXPRESS", risk_score=0.1)
    assert price == Decimal("22.50")

def test_risk_surcharge(pricing_engine):
    # 10 * 1 * 1 + (0.9 * 10) = 19.00
    price = pricing_engine.calculate_price("verification", complexity="SIMPLE", urgency="STANDARD", risk_score=0.9)
    assert price == Decimal("19.00")

def test_profit_guardrail(pricing_engine):
    # Force a very low base price in a separate config to test floor
    configs = {
        "cheap_service": PricingConfig(
            service_name="cheap_service",
            base_price=Decimal("0.50"),
            complexity_multiplier={"SIMPLE": Decimal("1.0")},
            urgency_multiplier={"STANDARD": Decimal("1.0")}
        )
    }
    engine = DynamicPricingEngine(configs)
    price = engine.calculate_price("cheap_service", complexity="SIMPLE", urgency="STANDARD", risk_score=0.1)
    assert price == Decimal("2.00") # Min price floor

def test_invalid_service(pricing_engine):
    with pytest.raises(ValueError, match="Pricing config for unknown not found"):
        pricing_engine.calculate_price("unknown")
