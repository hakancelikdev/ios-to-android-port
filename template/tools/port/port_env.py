"""Reads tools/port/port.env for the Python port scripts (plain KEY=VALUE, optional quotes)."""
import os
import shlex
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def load():
    path = os.path.join(ROOT, "tools", "port", "port.env")
    if not os.path.exists(path):
        sys.exit("❌ tools/port/port.env not found — copy tools/port/port.env.example and edit it.")
    env = {}
    for raw in open(path, encoding="utf-8"):
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        parts = shlex.split(value, comments=True)
        env[key.strip()] = parts[0] if parts else ""
    return env


def langs(env):
    """LANGS="en:values tr:values-tr" → [("en", "values"), ("tr", "values-tr")]; first = base."""
    pairs = [p.split(":", 1) for p in env.get("LANGS", "en:values").split()]
    return [(a, b) for a, b in pairs]


def path(*parts):
    return os.path.normpath(os.path.join(ROOT, *parts))
