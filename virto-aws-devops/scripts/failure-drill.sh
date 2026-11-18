#!/usr/bin/env bash
# Safe, reversible failure: stop Redis (cache) and observe/recover. No data is touched.
source "$(dirname "$0")/_lib.sh"; need docker; need curl; load_env
PP="${PLATFORM_HOST_PORT:-8090}"
code(){ curl -s -o /dev/null -w '%{http_code}' -m 20 "http://localhost:$PP/" || true; }
log "Baseline: platform -> $(code)"
log "INJECT: docker compose stop redis"; docker compose stop redis
sleep 10; echo "  during failure: platform -> $(code) (record this in evidence; behaviour depends on version)"
docker compose logs --no-color --tail 20 platform | sed 's/^/  | /'
log "RECOVER: docker compose start redis"; docker compose start redis
docker compose up -d --wait --wait-timeout 120 redis
sleep 10
r="$(code)"; [[ "$r" =~ ^(200|301|302)$ ]] && ok "platform recovered -> $r" || { bad "platform not recovered -> $r (try: docker compose restart platform)"; }
[ "$FAILED" -eq 0 ]
