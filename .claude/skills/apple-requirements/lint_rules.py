#!/usr/bin/env python3
"""Lint the Apple requirements catalogue (rules.yaml). Python standard library only.

Usage: python3 .claude/skills/apple-requirements/lint_rules.py [path/to/rules.yaml]

Fails (exit 1) if any rule lacks a required field, a `source` isn't an https URL on apple.com or
one of its subdomains, `checked` isn't an ISO date (or is in the future), an enum field has an
unknown value, a `test` doesn't resolve (see below), ids are duplicated, a coverage area from the
slice 01 spec is missing, or a Milestone 3 rule isn't `not_applicable_yet`.

`test` must resolve as follows:
- `todo:<slice>` names an existing slice folder under missions/*/slices/;
- `checklist:<path>[#anchor]` (only for `review` and `person` rules) names an existing file, and the
  anchor, if given, matches one of its Markdown headings;
- anything else is a repository path (optionally `path::TestName`) that must exist.

rules.yaml is a small YAML subset (see its header) parsed here without third-party libraries;
anything outside that subset is reported as an error rather than guessed at.
"""

from __future__ import annotations

import datetime as _dt
import re
import sys
from pathlib import Path
from urllib.parse import urlparse

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]  # .claude/skills/apple-requirements -> repo root

REQUIRED = ("id", "title", "source", "checked", "applies_when", "check", "test", "status_now")
OPTIONAL = ("area", "milestone", "requirement", "notes")

APPLIES_WHEN = {
    "always",
    "release",            # uploading to App Store Connect / TestFlight
    "networking",         # any network access
    "data_leaves_device", # data reaches a server we control (Milestone 3 sync)
    "account_signin",     # accounts or sign-in (Milestone 3 parent sign-in)
    "third_party_login",  # Google/Facebook/etc. sign-in
    "camera",
    "photos",
    "notifications",
    "dependencies",       # third-party packages or SDKs
    "kids_category",      # a public listing in the App Store Kids Category
}
CHECKS = {"static", "simulator", "review", "person"}
STATUS = {"met", "not_met", "not_applicable_yet", "unknown"}

# Mini-requirement 3 of missions/m0/slices/01-apple-requirements-skill/SPEC.md.
REQUIRED_AREAS = {
    "kids_category": "App Review 1.3 Kids Category",
    "app_completeness": "App Review 2.1 App Completeness",
    "accurate_metadata": "App Review 2.3 accurate metadata",
    "login_services": "App Review 4.8 Login Services",
    "data_collection": "App Review 5.1.1 data collection and storage",
    "data_sharing": "App Review 5.1.2 data use and sharing",
    "privacy_manifest": "privacy manifests",
    "required_reason_api": "required-reason APIs",
    "app_privacy_details": "App Privacy details",
    "testflight": "TestFlight and Beta App Review",
    "export_compliance": "export compliance",
    "purpose_strings": "Info.plist purpose strings",
    "app_icon": "app icon requirements",
    "accessibility": "accessibility",
}
# Mini-requirement 4: Milestone 3 triggers must be present.
MILESTONE3_TRIGGERS = {"account_signin", "third_party_login", "data_leaves_device"}

ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
KEY_RE = re.compile(r"^([a-z_][a-z0-9_]*):(?:\s+(.*))?$")


class ParseError(Exception):
    pass


def _scalar(raw: str, lineno: int) -> str:
    raw = raw.strip()
    if raw[:1] in ("'", '"'):
        q = raw[0]
        if len(raw) < 2 or raw[-1] != q:
            raise ParseError(f"line {lineno}: unterminated quoted value")
        inner = raw[1:-1]
        return inner.replace("''", "'") if q == "'" else inner.replace('\\"', '"')
    if raw[:1] in ("[", "{", "&", "*", "!", "|"):
        raise ParseError(f"line {lineno}: unsupported YAML ({raw[:1]!r}); use a plain scalar or '>'")
    if " #" in raw:
        raw = raw.split(" #", 1)[0].rstrip()
    return raw


def parse_rules(text: str) -> list[tuple[int, dict[str, str]]]:
    """Parse the catalogue subset: `rules:` then `- key: value` mappings, with `>` folded blocks."""
    lines = text.splitlines()
    rules: list[tuple[int, dict[str, str]]] = []
    current: dict[str, str] | None = None
    key_indent = None
    seen_root = False
    i = 0
    while i < len(lines):
        lineno, line = i + 1, lines[i]
        i += 1
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if "\t" in line[: len(line) - len(line.lstrip())]:
            raise ParseError(f"line {lineno}: tabs are not allowed in indentation")
        indent = len(line) - len(line.lstrip(" "))
        if not seen_root:
            if stripped != "rules:" or indent != 0:
                raise ParseError(f"line {lineno}: expected top-level 'rules:'")
            seen_root = True
            continue
        if stripped.startswith("- "):
            current = {}
            rules.append((lineno, current))
            key_indent = indent + 2
            stripped = stripped[2:].strip()
        elif current is None:
            raise ParseError(f"line {lineno}: expected '- id: ...' to start a rule")
        elif indent != key_indent:
            raise ParseError(f"line {lineno}: unexpected indentation ({indent}, expected {key_indent})")
        m = KEY_RE.match(stripped)
        if not m:
            raise ParseError(f"line {lineno}: expected 'key: value', got {stripped!r}")
        key, raw = m.group(1), (m.group(2) or "")
        if key in current:
            raise ParseError(f"line {lineno}: key {key!r} repeated in one rule")
        if raw.strip() in (">", ">-"):
            parts = []
            while i < len(lines):
                nxt = lines[i]
                if nxt.strip() and len(nxt) - len(nxt.lstrip(" ")) <= key_indent:
                    break
                parts.append(nxt.strip())
                i += 1
            value = " ".join(p for p in parts if p)
        else:
            value = _scalar(raw, lineno)
        current[key] = value
    if not seen_root:
        raise ParseError("no top-level 'rules:' found")
    return rules


def _slices() -> set[str]:
    return {p.name for p in REPO.glob("missions/*/slices/*") if p.is_dir()}


def _heading_anchors(path: Path) -> set[str]:
    anchors = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^#{1,6}\s+(.*?)\s*#*\s*$", line)
        if m:
            slug = re.sub(r"[^\w\- ]", "", m.group(1).strip().lower()).replace(" ", "-")
            anchors.add(slug)
    return anchors


def _check_test(rule: dict[str, str], slices: set[str]) -> str | None:
    test = rule.get("test", "").strip()
    check = rule.get("check")
    if not test:
        return "empty test"
    if test.startswith("todo:"):
        name = test[len("todo:"):]
        return None if name in slices else f"todo:{name} is not a slice under missions/*/slices/"
    if test.startswith("checklist:"):
        if check in ("static", "simulator"):
            return f"check: {check} needs a real test path or todo:<slice>, not a checklist item"
        target, _, anchor = test[len("checklist:"):].partition("#")
        path = REPO / target
        if not path.is_file():
            return f"checklist file {target} does not exist"
        if anchor and anchor not in _heading_anchors(path):
            return f"checklist anchor #{anchor} is not a heading in {target}"
        return None
    target = test.split("::", 1)[0]
    if not (REPO / target).exists():
        return f"test path {target} does not exist (use a real path or todo:<slice>)"
    return None


def _check_source(url: str) -> str | None:
    p = urlparse(url)
    host = (p.hostname or "").lower()
    if p.scheme != "https":
        return f"source {url!r} is not an https URL"
    if host != "apple.com" and not host.endswith(".apple.com"):
        return f"source host {host!r} is not apple.com or a subdomain (e.g. developer.apple.com)"
    return None


def lint(path: Path) -> list[str]:
    errors: list[str] = []
    try:
        rules = parse_rules(path.read_text(encoding="utf-8"))
    except (OSError, ParseError) as exc:
        return [f"{path}: {exc}"]
    if not rules:
        return [f"{path}: no rules"]

    slices = _slices()
    today = _dt.date.today()
    seen: dict[str, int] = {}
    areas: set[str] = set()
    m3_triggers: set[str] = set()

    for lineno, rule in rules:
        rid = rule.get("id", f"<rule at line {lineno}>")
        where = f"{rid} (line {lineno})"
        for field in REQUIRED:
            if not rule.get(field, "").strip():
                errors.append(f"{where}: missing field '{field}'")
        for field in rule:
            if field not in REQUIRED and field not in OPTIONAL:
                errors.append(f"{where}: unknown field '{field}'")
        if "id" in rule:
            if not ID_RE.match(rule["id"]):
                errors.append(f"{where}: id has unexpected characters")
            if rule["id"] in seen:
                errors.append(f"{where}: duplicate id (first at line {seen[rule['id']]})")
            else:
                seen[rule["id"]] = lineno
        if rule.get("source"):
            err = _check_source(rule["source"])
            if err:
                errors.append(f"{where}: {err}")
        if rule.get("checked"):
            try:
                d = _dt.date.fromisoformat(rule["checked"])
                if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", rule["checked"]):
                    raise ValueError
                if d > today:
                    errors.append(f"{where}: checked date {d} is in the future")
            except ValueError:
                errors.append(f"{where}: checked {rule['checked']!r} is not a YYYY-MM-DD date")
        for field, allowed in (("applies_when", APPLIES_WHEN), ("check", CHECKS), ("status_now", STATUS)):
            val = rule.get(field)
            if val and val not in allowed:
                errors.append(f"{where}: {field} {val!r} not in {sorted(allowed)}")
        if rule.get("test") is not None and rule.get("check") in CHECKS:
            err = _check_test(rule, slices)
            if err:
                errors.append(f"{where}: {err}")
        area = rule.get("area")
        if area:
            if area not in REQUIRED_AREAS:
                errors.append(f"{where}: area {area!r} not in {sorted(REQUIRED_AREAS)}")
            areas.add(area)
        if rule.get("milestone") == "3":
            m3_triggers.add(rule.get("applies_when", ""))
            if rule.get("status_now") != "not_applicable_yet":
                errors.append(f"{where}: Milestone 3 rule must have status_now: not_applicable_yet")
        elif rule.get("milestone"):
            errors.append(f"{where}: milestone {rule['milestone']!r} is not supported (only 3)")

    for area, label in sorted(REQUIRED_AREAS.items()):
        if area not in areas:
            errors.append(f"coverage: no rule with area: {area} ({label})")
    for trig in sorted(MILESTONE3_TRIGGERS - m3_triggers):
        errors.append(f"coverage: no Milestone 3 rule with applies_when: {trig}")
    return errors


def main(argv: list[str]) -> int:
    path = Path(argv[1]) if len(argv) > 1 else HERE / "rules.yaml"
    errors = lint(path)
    if errors:
        for e in errors:
            print(f"FAIL {e}")
        print(f"{len(errors)} problem(s) in {path}")
        return 1
    rules = parse_rules(path.read_text(encoding="utf-8"))
    counts: dict[str, int] = {}
    for _, r in rules:
        counts[r["status_now"]] = counts.get(r["status_now"], 0) + 1
    summary = ", ".join(f"{k} {v}" for k, v in sorted(counts.items()))
    print(f"OK {len(rules)} rules in {path.relative_to(REPO) if path.is_relative_to(REPO) else path} ({summary})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
