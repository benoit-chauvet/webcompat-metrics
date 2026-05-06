#!/usr/bin/env python3
"""
Run STMO queries locally and display results.

Usage:
    source .env && python3 run_queries.py
    source .env && python3 run_queries.py --from 2025-01-01 --to 2025-12-31
"""

import requests
import os
import time
import argparse

API_KEY = os.environ.get('REDASH_API_KEY')
BASE_URL = 'https://sql.telemetry.mozilla.org/api'

def run_query(query_text, params=None):
    """Execute a query via the Redash API and return results."""
    headers = {'Authorization': f'Key {API_KEY}'}
    payload = {
        'query': query_text,
        'data_source_id': 63,
        'parameters': params or {},
        'max_age': 0
    }

    response = requests.post(f'{BASE_URL}/query_results', headers=headers, json=payload)
    result = response.json()

    if 'job' in result:
        job_id = result['job']['id']
        for _ in range(60):
            time.sleep(2)
            job_response = requests.get(f'{BASE_URL}/jobs/{job_id}', headers=headers)
            job_status = job_response.json().get('job', {})
            if job_status.get('status') == 3:
                result_id = job_status.get('query_result_id')
                result_response = requests.get(f'{BASE_URL}/query_results/{result_id}', headers=headers)
                return result_response.json().get('query_result', {}).get('data', {})
            elif job_status.get('status') == 4:
                print(f"Error: {job_status.get('error')}")
                return None
    elif 'query_result' in result:
        return result.get('query_result', {}).get('data', {})
    return None


def print_table(data, title):
    """Print query results as a formatted table."""
    if not data or not data.get('rows'):
        print(f"\n{title}: No data")
        return

    rows = data['rows']
    cols = [c['name'] for c in data['columns']]

    def fmt(v):
        if v is None:
            return '-'
        if isinstance(v, float):
            return f"{v:.1f}"
        return str(v)

    widths = {c: max(len(c), max(len(fmt(r.get(c))) for r in rows)) for c in cols}

    print(f"\n{'='*70}")
    print(f"  {title}")
    print('='*70)
    print(' | '.join(c.ljust(widths[c]) for c in cols))
    print('-+-'.join('-'*widths[c] for c in cols))

    for row in rows:
        print(' | '.join(fmt(row.get(c)).ljust(widths[c]) for c in cols))


def main():
    parser = argparse.ArgumentParser(description='Run STMO queries locally')
    parser.add_argument('--from', dest='from_date', default='2026-01-01', help='Start date (YYYY-MM-DD)')
    parser.add_argument('--to', dest='to_date', default='2026-04-17', help='End date (YYYY-MM-DD)')
    args = parser.parse_args()

    if not API_KEY:
        print("Error: REDASH_API_KEY environment variable not set")
        print("Run: source .env && python3 run_queries.py")
        return

    params = {'from': args.from_date, 'to': args.to_date}
    print(f"Running queries with date range: {args.from_date} to {args.to_date}")

    # Run sitepatch query
    with open('webcompat_bugs_sitepatch_lifetime.sql') as f:
        print_table(run_query(f.read(), params), "SITEPATCH LIFETIME (days to resolve X% of bugs)")

    # Run diagnosis query
    with open('webcompat_bugs_diagnosis_lifetime.sql') as f:
        print_table(run_query(f.read(), params), "DIAGNOSIS LIFETIME (days to resolve X% of bugs)")


if __name__ == '__main__':
    main()
