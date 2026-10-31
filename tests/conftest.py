"""The core package has no Home Assistant dependency, so it is imported directly as `core`."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1] / "custom_components" / "thask"))
