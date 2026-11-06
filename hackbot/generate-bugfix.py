#!/usr/bin/env python3
"""Fetch hackbot runs and write the data for the HTML report.

Fetches all runs (paginated) for an agent (default: bug-fix), keeps only those
whose bug is in Bugzilla product "Web Compatibility", component "Site Reports",
looks up each run's Phabricator revision (needs PHABRICATOR_API_KEY in the
environment or .env) and writes bug-fix-data.js next to this script. The static
bug-fix.html template loads it with a <script> tag, so it works from file://.

Use --all to skip the Bugzilla filter, --json to also print the raw runs to
stdout, --actions to also fetch the actions of the first run, or --run-id to
look at one run's actions instead.

Usage:
    HACKBOT_API_KEY=... python3 hackbot/generate-bugfix.py
    open hackbot/bug-fix.html in a browser
    python3 hackbot/generate-bugfix.py --agent build-repair --output hackbot/other.js
    # edit the <script src> in bug-fix.html to point at other.js
"""


from __future__ import annotations

import argparse
import json
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse

import requests

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_API_URL = "https://hackbot-api.moz.tools"
DEFAULT_RUN_URL = "https://hackbot.moz.tools/runs/{run_id}"
REDASH_URL = "https://sql.telemetry.mozilla.org"
REDASH_DATA_SOURCE = 63
KB_DATASET = "moz-fx-dev-dschubert-wckb.webcompat_knowledge_base"
BUGZILLA_URL = "https://bugzilla.mozilla.org/rest/bug"
PHABRICATOR = "https://phabricator.services.mozilla.com"
PATCH_ACTIONS = {"phabricator.submit_patch", "phabricator.update_patch"}
LANDED = "published"
PRODUCT = "Web Compatibility"
COMPONENT = "Site Reports"


def load_env(path: Path):
    """Read KEY=VALUE lines from .env without overriding the environment."""
    if not path.exists():
        return
    for line in path.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            os.environ.setdefault(key.strip(), value.strip().strip("'\""))


def get_json(url, api_key):
    resp = requests.get(
        url,
        headers={"X-API-Key": api_key, "User-Agent": "hackbot-ci-agents-analytics/1.0"},
        timeout=60,
    )
    print(f"GET {url} -> {resp.status_code}", file=sys.stderr)
    resp.raise_for_status()
    return resp.json()


def fetch_all_runs(api_url, api_key, agent, page_size):
    """Page through /runs until a short page is returned."""
    runs = []
    offset = 0
    while True:
        page = get_json(
            f"{api_url}/runs?agent={agent}&limit={page_size}&offset={offset}",
            api_key,
        )
        runs.extend(page)
        if len(page) < page_size:
            return runs
        offset += page_size


def run_bug_id(run):
    """Bug id of a run: inputs.bug_id, falling back to summary.findings.bug_id."""
    findings = (run.get("summary") or {}).get("findings") or {}
    bug_id = (run.get("inputs") or {}).get("bug_id") or findings.get("bug_id") or run.get("bug_id")
    try:
        return int(bug_id)
    except (TypeError, ValueError):
        return None


def bugzilla_bugs(bug_ids, batch=200):
    """bug id -> {product, component, status, resolution} from Bugzilla."""
    found = {}
    bug_ids = sorted(bug_ids)
    for i in range(0, len(bug_ids), batch):
        resp = requests.get(
            BUGZILLA_URL,
            params={
                "id": ",".join(map(str, bug_ids[i : i + batch])),
                "include_fields": "id,product,component,status,resolution,url,keywords",
            },
            headers={"User-Agent": "hackbot-ci-agents-analytics/1.0"},
            timeout=60,
        )
        print(f"GET bugzilla batch {i // batch} -> {resp.status_code}", file=sys.stderr)
        resp.raise_for_status()
        for bug in resp.json()["bugs"]:
            found[bug["id"]] = bug
    return found


def bug_domain(url):
    """Host name of a bug's URL field (without a leading www.), or None."""
    url = (url or "").strip()
    if not url:
        return None
    host = urlparse(url if "://" in url else f"//{url}").hostname
    return host.removeprefix("www.") if host else None


def bug_status(bug):
    """'NEW', 'RESOLVED FIXED', ... or None when the bug is unknown."""
    bug = bug or {}
    return " ".join(filter(None, [bug.get("status"), bug.get("resolution")])).upper() or None


def has_patch(run):
    return "changes/changes.patch" in {a.get("name") for a in run.get("artifacts") or []}


def is_webcompat(bug):
    return bug["product"] == PRODUCT and bug["component"].lower() == COMPONENT.lower()


def latest_per_bug(runs):
    """Keep only the most recent run (by created_at) of each bug; runs without a bug stay."""
    latest = {}
    for run in runs:
        bug = run_bug_id(run)
        if bug and run.get("created_at", "") >= latest.get(bug, {}).get("created_at", ""):
            latest[bug] = run
    return [r for r in runs if not run_bug_id(r) or latest[run_bug_id(r)] is r]


def latest_patch_per_bug(runs):
    """For bugs with patch-producing runs, keep only the latest of those runs.

    Other runs of such a bug are dropped; bugs with no patch at all keep all their runs.
    """
    latest = {}
    for run in runs:
        bug = run_bug_id(run)
        if bug and has_patch(run) and run.get("created_at", "") >= latest.get(bug, {}).get("created_at", ""):
            latest[bug] = run
    return [r for r in runs if not run_bug_id(r) or run_bug_id(r) not in latest or latest[run_bug_id(r)] is r]


def to_number(value):
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    return int(number) if number.is_integer() else number


# Fallback when the KB `score` is 0: the product of these component scores.
SCORE_FACTORS = [
    "impact_score",
    "platform_score",
    "configuration_score",
    "affects_score",
    "site_rank_score",
    "branch_score",
]


def kb_impact_score(row):
    """The KB `score`; when it is 0, the product of the component scores instead."""
    score = to_number(row.get("score"))
    if score != 0:
        return score
    product = 1
    for factor in SCORE_FACTORS:
        value = to_number(row.get(factor))
        if value is None:
            return score
        product *= value
    return to_number(product)


def kb_scores(bug_ids, redash_key, batch=500):
    """bug id -> {priority, impact_score (the KB "score" column)} from the webcompat knowledge base, via STMO."""
    out = {}
    bug_ids = sorted(bug_ids)
    for i in range(0, len(bug_ids), batch):
        ids = ",".join(str(int(b)) for b in bug_ids[i : i + batch])
        sql = (
            "SELECT number, webcompat_priority, score, "
            + ", ".join(SCORE_FACTORS)
            + " "
            f"FROM `{KB_DATASET}.scored_site_reports` WHERE number IN ({ids})"
        )
        for row in redash_query(sql, redash_key):
            out[int(row["number"])] = {
                "priority": row.get("webcompat_priority"),
                "impact_score": kb_impact_score(row),
            }
    return out


def redash_query(sql, redash_key, timeout=300):
    """Run an ad-hoc query on STMO and return its rows."""
    headers = {"Authorization": f"Key {redash_key}"}
    resp = requests.post(
        f"{REDASH_URL}/api/query_results",
        headers=headers,
        json={"query": sql, "data_source_id": REDASH_DATA_SOURCE, "max_age": 3600},
        timeout=60,
    )
    resp.raise_for_status()
    body = resp.json()
    deadline = time.time() + timeout
    while "job" in body:
        job = body["job"]
        if job["status"] == 3:
            result_id = job["query_result_id"]
            break
        if job["status"] in (4, 5) or time.time() > deadline:
            raise RuntimeError(f"STMO query failed: {job.get('error') or 'timeout'}")
        time.sleep(2)
        body = requests.get(f"{REDASH_URL}/api/jobs/{job['id']}", headers=headers, timeout=60).json()
    else:
        result_id = body["query_result"]["id"]
    if "query_result" in body:
        return body["query_result"]["data"]["rows"]
    resp = requests.get(f"{REDASH_URL}/api/query_results/{result_id}", headers=headers, timeout=60)
    resp.raise_for_status()
    return resp.json()["query_result"]["data"]["rows"]


def parse_ts(value):
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except (AttributeError, ValueError):
        return None


def patch_revision(actions):
    """Revision id an applied patch action created or updated, if any."""
    for action in actions:
        if action.get("type") in PATCH_ACTIONS and action.get("status") == "applied":
            result = action.get("result") or {}
            revision = result.get("revision_id") or (action.get("params") or {}).get("revision_id")
            if revision:
                try:
                    return int(revision)
                except (TypeError, ValueError):
                    pass
    return None


def run_revisions(runs, api_url, api_key):
    """run_id -> Phabricator revision id, for runs that recorded a patch action."""
    ids = [
        r["run_id"]
        for r in runs
        if PATCH_ACTIONS & {a.get("type") for a in (r.get("summary") or {}).get("actions") or []}
    ]
    with ThreadPoolExecutor(8) as pool:
        all_actions = list(pool.map(lambda i: get_json(f"{api_url}/runs/{i}/actions", api_key), ids))
    found = {i: rev for i, acts in zip(ids, all_actions) if (rev := patch_revision(acts))}
    print(f"{len(found)} run(s) with a Phabricator revision", file=sys.stderr)
    return found


def phab_call(method, payload, token):
    resp = requests.post(
        f"{PHABRICATOR}/api/{method}", data={"api.token": token, **payload}, timeout=60
    )
    resp.raise_for_status()
    data = resp.json()
    if data.get("error_code"):
        raise RuntimeError(f"{method}: {data.get('error_info')}")
    return data["result"]["data"]


def revision_details(rev_ids, token):
    """revision id -> {title, status, status_name, author, created, modified}."""
    rev_ids = sorted(set(rev_ids))
    out, author_phids = {}, set()
    for i in range(0, len(rev_ids), 100):
        payload = {f"constraints[ids][{n}]": rid for n, rid in enumerate(rev_ids[i : i + 100])}
        for rev in phab_call("differential.revision.search", payload, token):
            f = rev["fields"]
            author_phids.add(f["authorPHID"])
            out[rev["id"]] = {
                "title": f["title"],
                "status": f["status"]["value"],
                "status_name": f["status"]["name"],
                "author_phid": f["authorPHID"],
                "created": datetime.fromtimestamp(f["dateCreated"], timezone.utc),
                "modified": datetime.fromtimestamp(f["dateModified"], timezone.utc),
            }
    names = {}
    phids = sorted(author_phids)
    for i in range(0, len(phids), 100):
        payload = {f"constraints[phids][{n}]": p for n, p in enumerate(phids[i : i + 100])}
        for user in phab_call("user.search", payload, token):
            names[user["phid"]] = user["fields"]["username"]
    for d in out.values():
        d["author"] = names.get(d.pop("author_phid"), "")
    return out


def iso(dt):
    return dt.isoformat() if dt else None


def run_row(run, revision=None, phab=None, bug=None, kb=None):
    start = parse_ts(run.get("created_at"))
    phab = phab or {}
    bug, kb = bug or {}, kb or {}
    return {
        "run_id": run.get("run_id", ""),
        "bug_id": run_bug_id(run),
        "status": run.get("status", ""),
        "requested_by": run.get("requested_by"),
        "bug_status": bug_status(bug) if bug else None,
        "bug_domain": bug_domain(bug.get("url")),
        "sitepatch_applied": any("sitepatch-applied" in k for k in bug.get("keywords") or []),
        "bug_priority": kb.get("priority"),
        "impact_score": kb.get("impact_score"),
        "created": iso(start),
        "patch": has_patch(run),
        "revision": revision,
        "phab": {
            **phab,
            "created": iso(phab.get("created")),
            "modified": iso(phab.get("modified")),
        }
        if phab
        else None,
    }


# Optional hook for sibling scripts: run -> dict of extra fields merged into each row.
RUN_EXTRA = None


def build_report(
    runs, agent, filtered, revisions=None, details=None, run_url=DEFAULT_RUN_URL, bugs=None, scores=None
):
    """The JSON document the HTML template loads."""
    revisions, details = revisions or {}, details or {}
    bugs, scores = bugs or {}, scores or {}
    rows = [
        {
            **run_row(
                r,
                revisions.get(r["run_id"]),
                details.get(revisions.get(r["run_id"])),
                bugs.get(run_bug_id(r)),
                scores.get(run_bug_id(r)),
            ),
            **(RUN_EXTRA(r) if RUN_EXTRA else {}),
        }
        for r in runs
    ]
    rows.sort(key=lambda r: r["created"] or "", reverse=True)
    return {
        "meta": {
            "agent": agent,
            "scope": f"{PRODUCT} :: {COMPONENT}" if filtered else "all bugs",
            "generated": iso(datetime.now(timezone.utc)),
            "run_url": run_url,
            "bugzilla_url": BUGZILLA_URL.rsplit("/rest", 1)[0],
            "phabricator_url": PHABRICATOR,
            "landed_status": LANDED,
        },
        "runs": rows,
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--agent", default="bug-fix", help="agent name (default: bug-fix)")
    parser.add_argument("--page-size", type=int, default=100, help="runs per request")
    parser.add_argument("--all", action="store_true", help="don't filter on the Bugzilla product/component")
    parser.add_argument("--output", type=Path, default=Path(__file__).with_name("bug-fix-data.js"), help="JS data file loaded by bug-fix.html")
    parser.add_argument("--json", action="store_true", help="also print the runs as JSON on stdout")
    parser.add_argument(
        "--run-url",
        default=os.environ.get("HACKBOT_RUN_URL", DEFAULT_RUN_URL),
        help="link template for the Run column; {api_url} and {run_id} are substituted",
    )
    parser.add_argument(
        "--latest-per-bug",
        action=argparse.BooleanOptionalAction,
        default=False,
        help="when a bug has several runs, only keep the latest",
    )
    parser.add_argument(
        "--exclude-status",
        action="append",
        default=[],
        metavar="STATUS",
        help='drop runs whose bug has this status, e.g. "RESOLVED WORKSFORME" (repeatable)',
    )
    parser.add_argument(
        "--drop-resolved-without-patch",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="drop runs that generated no patch when their bug is RESOLVED (default: on)",
    )
    parser.add_argument(
        "--latest-patch-per-bug",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="when a bug has several runs that produced a patch, only keep the latest (default: on)",
    )
    parser.add_argument("--no-phabricator", action="store_true", help="skip Phabricator lookups")
    parser.add_argument("--actions", action="store_true", help="also fetch actions of the first run")
    parser.add_argument("--run-id", help="skip the runs listing and use this run")
    args = parser.parse_args(argv)

    load_env(ROOT / ".env")
    api_url = os.environ.get("HACKBOT_API_URL", DEFAULT_API_URL).rstrip("/")
    api_key = os.environ.get("HACKBOT_API_KEY")
    if not api_key:
        parser.error("HACKBOT_API_KEY must be set (environment or .env)")

    run_id = args.run_id
    if not run_id:
        runs = fetch_all_runs(api_url, api_key, args.agent, args.page_size)
        print(f"{len(runs)} run(s) returned", file=sys.stderr)
        ids = {b for b in map(run_bug_id, runs) if b}
        bugs = bugzilla_bugs(ids)
        if not args.all:
            runs = [r for r in runs if run_bug_id(r) in bugs and is_webcompat(bugs[run_bug_id(r)])]
            print(f"{len(runs)} run(s) on {PRODUCT} :: {COMPONENT} bugs", file=sys.stderr)
        if args.exclude_status:
            excluded = {x.upper() for x in args.exclude_status}
            before = len(runs)
            runs = [r for r in runs if bug_status(bugs.get(run_bug_id(r))) not in excluded]
            print(f"{len(runs)} run(s) after excluding {sorted(excluded)} (was {before})", file=sys.stderr)
        if args.drop_resolved_without_patch:
            before = len(runs)
            runs = [
                r
                for r in runs
                if has_patch(r) or not (bug_status(bugs.get(run_bug_id(r))) or "").startswith("RESOLVED")
            ]
            print(f"{len(runs)} run(s) after dropping RESOLVED bugs without a patch (was {before})", file=sys.stderr)
        if args.latest_patch_per_bug:
            before = len(runs)
            runs = latest_patch_per_bug(runs)
            print(f"{len(runs)} run(s) after keeping the latest patch per bug (was {before})", file=sys.stderr)
        if args.latest_per_bug:
            before = len(runs)
            runs = latest_per_bug(runs)
            print(f"{len(runs)} run(s) after keeping the latest per bug (was {before})", file=sys.stderr)
        scores = {}
        redash_key = os.environ.get("REDASH_API_KEY")
        if not redash_key:
            print("REDASH_API_KEY not set, skipping priority and impact score", file=sys.stderr)
        else:
            scores = kb_scores({run_bug_id(r) for r in runs if run_bug_id(r)}, redash_key)
            print(f"{len(scores)} bug(s) scored in the knowledge base", file=sys.stderr)
        revisions, details = {}, {}
        phab_token = os.environ.get("PHABRICATOR_API_KEY")
        if args.no_phabricator:
            pass
        elif not phab_token:
            print("PHABRICATOR_API_KEY not set, skipping Phabricator details", file=sys.stderr)
        else:
            revisions = run_revisions(runs, api_url, api_key)
            details = revision_details(revisions.values(), phab_token)
        report = build_report(
            runs, args.agent, not args.all, revisions, details, args.run_url.replace("{api_url}", api_url),
            bugs, scores,
        )
        args.output.write_text("window.REPORT_DATA = " + json.dumps(report, indent=2) + ";\n")
        print(f"report data written to {args.output}", file=sys.stderr)
        if args.json:
            print(json.dumps(runs, indent=2))
        if not args.actions or not runs:
            return
        run_id = runs[0]["run_id"]

    actions = get_json(f"{api_url}/runs/{run_id}/actions", api_key)
    print(f"actions for run {run_id}:", file=sys.stderr)
    print(json.dumps(actions, indent=2))


if __name__ == "__main__":
    main()
