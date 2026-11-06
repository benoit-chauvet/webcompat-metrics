#!/usr/bin/env bash
# Regenerate both dashboards' data and publish the site in one go:
# https://autwebcompat-patches-report.quick.mozilla.cloud
#
# 1. generate-bugfix.py        -> bug-fix-data.js
# 2. generate-interventions.py -> interventions-data.js
# 3. quick deploy of bug-fix.html, interventions.html, both data files and an
#    index.html (a copy of bug-fix.html). Comments are stored in Quick's datastore,
#    not in these files, so republishing never deletes them.
#
# Needs HACKBOT_API_KEY, PHABRICATOR_API_KEY and REDASH_API_KEY (environment or the
# repo's .env). Stops before publishing if a generator fails.
#
# Usage:
#     hackbot/publish.sh               # regenerate everything, then publish
#     hackbot/publish.sh --no-refresh  # publish the data files as they are
#     hackbot/publish.sh -y            # skip quick's overwrite confirmation

set -euo pipefail

SITE="autwebcompat-patches-report"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILES=(bug-fix.html bug-fix-data.js interventions.html interventions-data.js)

refresh=1
quick_args=()
for arg in "$@"; do
    case "$arg" in
        --no-refresh) refresh=0 ;;
        *) quick_args+=("$arg") ;;
    esac
done

if [[ $refresh -eq 1 ]]; then
    echo "==> Generating bug-fix data"
    python3 "$HERE/generate-bugfix.py"
    echo "==> Generating interventions data"
    python3 "$HERE/generate-interventions.py"
fi

for f in "${FILES[@]}"; do
    [[ -f "$HERE/$f" ]] || { echo "missing $HERE/$f (run without --no-refresh)" >&2; exit 1; }
done

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
for f in "${FILES[@]}"; do
    cp "$HERE/$f" "$stage/$f"
done
cp "$HERE/bug-fix.html" "$stage/index.html"

echo "==> Publishing to $SITE"
quick deploy "$stage" "$SITE" ${quick_args[@]+"${quick_args[@]}"}
echo "Published: https://$SITE.quick.mozilla.cloud"
