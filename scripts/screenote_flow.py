#!/usr/bin/env python3
"""Compatibility import for the shipped Screenote workflow contract runtime."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import sys


_IMPLEMENTATION = (
    Path(__file__).resolve().parents[1]
    / "plugins"
    / "screenote"
    / "scripts"
    / "screenote_flow.py"
)
_SPEC = importlib.util.spec_from_file_location("screenote_plugin_flow", _IMPLEMENTATION)
if _SPEC is None or _SPEC.loader is None:
    raise ImportError(f"cannot load Screenote workflow runtime from {_IMPLEMENTATION}")
_MODULE = importlib.util.module_from_spec(_SPEC)
sys.modules[_SPEC.name] = _MODULE
_SPEC.loader.exec_module(_MODULE)

__all__ = _MODULE.__all__
globals().update({name: getattr(_MODULE, name) for name in __all__})
