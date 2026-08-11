"""pytest config for fraud-service — adds backend root for `shared` imports."""
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../../.."))
