#!/usr/bin/env python3
"""Fetch autowebcompat-intervention runs and write the data for interventions.html.

Same pipeline as generate-bugfix.py (Bugzilla filter on Web Compatibility ::
Site Reports, Phabricator revision details, knowledge-base priority and score),
with the agent defaulting to autowebcompat-intervention and extra per-run fields
from the agent's findings: whether it wrote an intervention, whether that fixed
the bug, whether the build succeeded, and a short summary.

Bugs that are RESOLVED WORKSFORME or RESOLVED DUPLICATE are dropped (override with --exclude-status).
All runs are kept; interventions.html groups them by bug. Pass --latest-per-bug to
keep only the latest run of each bug. All generate-bugfix.py options work here
(--all, --json, ...).

Usage:
    python3 hackbot/generate-interventions.py
    open hackbot/interventions.html
"""

from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
AGENT = "autowebcompat-intervention"
EXCLUDED_STATUSES = ["RESOLVED WORKSFORME", "RESOLVED DUPLICATE"]


def load_bugfix():
    spec = importlib.util.spec_from_file_location("generate_bugfix", HERE / "generate-bugfix.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def failure_reason(run, result):
    """The agent's failure_reason, else the run's own error (top level, then summary)."""
    for candidate in (
        result.get("failure_reason"),
        run.get("error"),
        (run.get("summary") or {}).get("error"),
    ):
        if candidate:
            return candidate if isinstance(candidate, str) else json.dumps(candidate)
    return None


def intervention_fields(run):
    inputs = run.get("inputs") or {}
    result = ((run.get("summary") or {}).get("findings") or {}).get("result") or {}
    return {
        # A run triggered by a reviewer comment updates an existing revision.
        "kind": "update" if inputs.get("revision_id") else "new",
        "wrote_intervention": result.get("wrote_intervention"),
        "fixed_with_intervention": result.get("fixed_with_intervention"),
        "build_succeeded": result.get("build_succeeded"),
        "files_changed": len(result.get("files_changed") or []),
        "failure_reason": failure_reason(run, result),
        "result_summary": result.get("summary"),
    }


def main(argv=None):
    bugfix = load_bugfix()
    bugfix.RUN_EXTRA = intervention_fields
    argv = list(sys.argv[1:] if argv is None else argv)
    defaults = []
    if "--agent" not in argv:
        defaults += ["--agent", AGENT]
    if "--latest-patch-per-bug" not in argv and "--no-latest-patch-per-bug" not in argv:
        defaults.append("--no-latest-patch-per-bug")
    if "--drop-resolved-without-patch" not in argv:
        defaults.append("--no-drop-resolved-without-patch")
    if "--exclude-status" not in argv:
        for status in EXCLUDED_STATUSES:
            defaults += ["--exclude-status", status]
    if "--output" not in argv:
        defaults += ["--output", str(HERE / "interventions-data.js")]
    bugfix.main(defaults + argv)


if __name__ == "__main__":
    main()
