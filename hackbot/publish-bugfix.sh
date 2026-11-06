#!/usr/bin/env bash
# Publish the bug-fix report to https://autwebcompat-patches-report.quick.mozilla.cloud
#
# Stages both dashboards (bug-fix.html, interventions.html), their data files and
# an index.html (a copy of bug-fix.html) in a temp dir and deploys it with `quick`. Pass --refresh to regenerate the data first.
#
# Usage:
#     hackbot/publish-bugfix.sh             # publish the current data
#     hackbot/publish-bugfix.sh --refresh   # regenerate both data files first
#     hackbot/publish-bugfix.sh -y          # skip quick's overwrite confirmation

set -euo pipefail

SITE="autwebcompat-patches-report"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

refresh=0
quick_args=()
for arg in "$@"; do
    case "$arg" in
        --refresh) refresh=1 ;;
        *) quick_args+=("$arg") ;;
    esac
done

if [[ $refresh -eq 1 ]]; then
    python3 "$HERE/generate-bugfix.py"
    python3 "$HERE/generate-interventions.py"
fi

for f in bug-fix.html bug-fix-data.js interventions.html interventions-data.js; do
    [[ -f "$HERE/$f" ]] || { echo "missing $HERE/$f (run generate-bugfix.py)" >&2; exit 1; }
done

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
for f in bug-fix.html bug-fix-data.js interventions.html interventions-data.js; do
    cp "$HERE/$f" "$stage/$f"
done
cp "$HERE/bug-fix.html" "$stage/index.html"

quick deploy "$stage" "$SITE" ${quick_args[@]+"${quick_args[@]}"}
echo "Published: https://$SITE.quick.mozilla.cloud"
