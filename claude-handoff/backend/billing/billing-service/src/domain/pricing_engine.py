from dataclasses import dataclass
from typing import Dict, Any, Optional
from decimal import Decimal

@dataclass
class PricingConfig:
    service_name: str
    base_price: Decimal
    complexity_multiplier: Dict[str, Decimal] # e.g. {"SIMPLE": 1.0, "COMPLEX": 1.5}
    urgency_multiplier: Dict[str, Decimal]   # e.g. {"STANDARD": 1.0, "EXPRESS": 1.5}

class DynamicPricingEngine:
    """
    Implements the stochastic and variable pricing model to ensure profitability.
    Formula: Total = Base + (Variable * StochasticMultiplier)
    """
    def __init__(self, configs: Dict[str, PricingConfig]):
        self.configs = configs

    def calculate_price(
        self, 
        service_name: str, 
        complexity: str = "SIMPLE", 
        urgency: str = "STANDARD", 
        risk_score: float = 0.0
    ) -> Decimal:
        config = self.configs.get(service_name)
        if not config:
            raise ValueError(f"Pricing config for {service_name} not found")

        # 1. Base Price
        price = config.base_price

        # 2. Variable Multipliers
        comp_mult = config.complexity_multiplier.get(complexity, Decimal("1.0"))
        urg_mult = config.urgency_multiplier.get(urgency, Decimal("1.0"))
        
        price = price * comp_mult * urg_mult

        # 3. Stochastic Risk Surcharge
        # If risk is high (> 0.7), add a surcharge to cover human review costs
        if risk_score > 0.7:
            risk_surcharge = Decimal(str(risk_score)) * Decimal("10.0") # $10 max surcharge
            price += risk_surcharge

        # 4. Profit Margin Guardrail
        # Ensure the price never drops below a minimum threshold (example: $2.0)
        min_price = Decimal("2.00")
        return max(price, min_price).quantize(Decimal("0.01"))
