#!/usr/bin/env bash
# Shared helpers. Source, do not execute.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
log()  { printf '\033[1;34m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*"; }
ok()   { printf '\033[1;32m  PASS\033[0m %s\n' "$*"; }
bad()  { printf '\033[1;31m  FAIL\033[0m %s\n' "$*"; FAILED=$((FAILED+1)); }
need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing required tool: $1" >&2; exit 2; }; }
load_env() { [ -f .env ] || { echo ".env missing - run scripts/generate-env.sh" >&2; exit 2; }; set -a; . ./.env; set +a; }
FAILED=0
