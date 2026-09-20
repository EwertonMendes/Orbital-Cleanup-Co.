#!/usr/bin/env python3
"""Fast repository checks that do not require Godot."""

from __future__ import annotations

import csv
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

REQUIRED = [
    "project.godot",
    "export_presets.cfg",
    "web/shell/index.html",
    "web/platform/platform-config.js",
    "web/platform/debug-provider.js",
    "web/platform/platform-loader.js",
    "i18n/ui.csv",
    "src/ui/screens/bootstrap/bootstrap_screen.tscn",
    "src/ui/screens/bootstrap/bootstrap_screen.gd",
    "AGENTS.md",
    "docs/ASSETS.md",
]

PORTAL_IDENTIFIERS = ("crazygames", "gamepix", "gamemonetize", "gamedistribution", "poki")


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def validate_required_files() -> None:
    missing = [path for path in REQUIRED if not (ROOT / path).is_file()]
    if missing:
        fail("Missing required bootstrap files: " + ", ".join(missing))


def validate_translations() -> None:
    path = ROOT / "i18n/ui.csv"
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    expected = {"keys", "en", "pt_BR", "es_ES"}
    if not rows:
        fail("Translation catalog is empty")
    if set(rows[0].keys()) != expected:
        fail(f"Translation columns must be exactly {sorted(expected)}")
    keys = [row["keys"].strip() for row in rows]
    if any(not key for key in keys):
        fail("Translation key cannot be empty")
    if len(keys) != len(set(keys)):
        fail("Duplicate translation keys detected")
    for row in rows:
        for locale in ("en", "pt_BR", "es_ES"):
            if not row[locale].strip():
                fail(f"Missing {locale} translation for {row['keys']}")


def validate_provider_boundary() -> None:
    src_root = ROOT / "src"
    offenders: list[str] = []
    for path in src_root.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in {".gd", ".tscn", ".tres"}:
            continue
        text = path.read_text(encoding="utf-8", errors="ignore").lower()
        if any(identifier in text for identifier in PORTAL_IDENTIFIERS):
            offenders.append(str(path.relative_to(ROOT)))
    if offenders:
        fail("Portal SDK identifiers leaked into Godot source: " + ", ".join(offenders))

    config = (ROOT / "web/platform/platform-config.js").read_text(encoding="utf-8")
    if "__OCC_PROVIDER__" not in config:
        fail("platform-config.js must remain build-configurable")
    debug_provider = (ROOT / "web/platform/debug-provider.js").read_text(encoding="utf-8").lower()
    if "fetch(" in debug_provider or "xmlhttprequest" in debug_provider:
        fail("DebugWebProvider must not call remote ad/network APIs")


def main() -> None:
    validate_required_files()
    validate_translations()
    validate_provider_boundary()
    print("Bootstrap validation passed.")


if __name__ == "__main__":
    main()
