import httpx
from typing import Any, Dict, Optional
import os
from ...config import settings

# `crewai_tools` is an optional dependency (only needed when the crew runs).
try:
    from crewai_tools import BaseTool
except Exception:  # pragma: no cover - optional dep
    BaseTool = object


class MasarenBffTool(BaseTool):
    name: str = "masaren_bff_tool"
    description: str = (
        "Useful for interacting with the MASAREN Demo Backend (BFF). "
        "Can fetch evidence details, user profiles, and stats. "
        "Accepts an 'endpoint' (e.g., '/api/evidence/123') and 'method' (GET, POST, etc.)."
    )
    
    def _run(self, endpoint: str, method: str = "GET", payload: Optional[Dict[str, Any]] = None) -> str:
        base_url = settings.bff_url
        url = f"{base_url}{endpoint}"
        try:
            with httpx.Client(base_url=base_url, timeout=10.0) as client:
                if method.upper() == "GET":
                    response = client.get(endpoint)
                elif method.upper() == "POST":
                    response = client.post(endpoint, json=payload)
                elif method.upper() == "PATCH":
                    response = client.patch(endpoint, json=payload)
                elif method.upper() == "PUT":
                    response = client.put(endpoint, json=payload)
                elif method.upper() == "DELETE":
                    response = client.delete(endpoint)
                else:
                    return f"Error: Unsupported method {method}"

                response.raise_for_status()
                return response.text
        except httpx.HTTPStatusError as e:
            return f"HTTP Error: {e.response.status_code} - {e.response.text}"
        except Exception as e:
            return f"Error: {str(e)}"
