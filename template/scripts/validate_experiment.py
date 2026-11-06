#!/usr/bin/env python3
"""Validate experiment YAML files against the JSON Schema.

Checks:
  1. JSON Schema (required fields, types, Slurm time format, approval rules)
  2. Leftover placeholders ("REPLACE_...") — skipped with --allow-placeholders
  3. experiment_id matches the file name

Usage:
  python scripts/validate_experiment.py experiments/foo.yaml [more.yaml ...]
  python scripts/validate_experiment.py --allow-placeholders experiments/templates/experiment.yaml

Dependencies: PyYAML, jsonschema  (installed by `scripts/researchctl setup` = uv sync)

This script validates structure only. It does not approve or launch experiments.
"""
import json
import sys
from pathlib import Path

try:
    import yaml
    from jsonschema import Draft202012Validator
except ImportError:
    print("Missing dependency. Run: scripts/researchctl setup   (uv sync), then: uv run python scripts/validate_experiment.py ...", file=sys.stderr)
    sys.exit(2)

ROOT = Path(__file__).resolve().parents[1]
SCHEMA_PATH = ROOT / "schemas" / "experiment.schema.json"
PLACEHOLDER = "REPLACE_"


def find_placeholders(node, path=""):
    if isinstance(node, dict):
        for k, v in node.items():
            yield from find_placeholders(v, f"{path}.{k}" if path else str(k))
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from find_placeholders(v, f"{path}[{i}]")
    elif isinstance(node, str) and PLACEHOLDER in node:
        yield path or "<root>", node


def validate(spec_path: Path, validator, allow_placeholders: bool) -> list[str]:
    try:
        spec = yaml.safe_load(spec_path.read_text(encoding="utf-8"))
    except Exception as exc:
        return [f"could not read YAML: {exc}"]
    if not isinstance(spec, dict):
        return ["top level must be a mapping"]

    errors = []
    for e in sorted(validator.iter_errors(spec), key=lambda e: list(map(str, e.path))):
        loc = ".".join(map(str, e.path)) or "<root>"
        errors.append(f"{loc}: {e.message}")

    if not allow_placeholders:
        for loc, value in find_placeholders(spec):
            errors.append(f"{loc}: placeholder not filled in ({value!r})")

    if "templates" not in spec_path.parts and spec.get("experiment_id") != spec_path.stem:
        errors.append(
            f"experiment_id: {spec.get('experiment_id')!r} must match file name {spec_path.stem!r}"
        )
    return errors


def main(argv: list[str]) -> int:
    allow = "--allow-placeholders" in argv
    files = [a for a in argv if not a.startswith("--")]
    if not files:
        print(__doc__, file=sys.stderr)
        return 2

    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    validator = Draft202012Validator(schema)

    failed = 0
    for f in files:
        p = Path(f)
        if not p.is_absolute():
            p = (Path.cwd() / p).resolve()
        errs = validate(p, validator, allow)
        if errs:
            failed += 1
            print(f"FAIL {f}")
            for e in errs:
                print(f"  ERROR {e}")
        else:
            print(f"OK   {f}")

    if failed:
        return 1
    print("Note: schema OK. Approval and resource policies must still be checked before execution.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
