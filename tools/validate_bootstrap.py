#!/usr/bin/env python3
"""Fast repository checks that do not require Godot."""

from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]

REQUIRED = [
    "project.godot",
    "export_presets.cfg",
    "web/shell/index.html",
    "web/platform/platform-config.js",
    "web/platform/debug-provider.js",
    "web/platform/platform-loader.js",
    "i18n/en.po",
    "i18n/pt_BR.po",
    "i18n/es_ES.po",
    "src/ui/screens/bootstrap/bootstrap_screen.tscn",
    "src/ui/screens/bootstrap/bootstrap_screen.gd",
    "AGENTS.md",
    "docs/ASSETS.md",
]

PORTAL_IDENTIFIERS = ("crazygames", "gamepix", "gamemonetize", "gamedistribution", "poki")
MSGID = re.compile(r'^msgid "([^"]+)"$', re.MULTILINE)


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def validate_required_files() -> None:
    missing = [path for path in REQUIRED if not (ROOT / path).is_file()]
    if missing:
        fail("Missing required bootstrap files: " + ", ".join(missing))


def validate_translations() -> None:
    expected_languages = {
        "en.po": "Language: en",
        "pt_BR.po": "Language: pt_BR",
        "es_ES.po": "Language: es_ES",
    }
    catalogs: dict[str, set[str]] = {}
    for filename, header in expected_languages.items():
        text = (ROOT / "i18n" / filename).read_text(encoding="utf-8")
        if header not in text:
            fail(f"{filename} is missing expected language header {header!r}")
        ids = set(MSGID.findall(text))
        if not ids:
            fail(f"{filename} contains no translation messages")
        catalogs[filename] = ids

    reference = catalogs["en.po"]
    for filename, ids in catalogs.items():
        missing = sorted(reference - ids)
        extra = sorted(ids - reference)
        if missing or extra:
            fail(f"{filename} key mismatch; missing={missing}, extra={extra}")


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
