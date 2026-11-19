#!/usr/bin/env bash
# Health + connectivity checks. Exit code != 0 on any failure.
source "$(dirname "$0")/_lib.sh"; need docker; need curl; load_env
PP="${PLATFORM_HOST_PORT:-8090}"; SP="${STOREFRONT_HOST_PORT:-8080}"
log "1. Container health"
for s in sqlserver elasticsearch redis platform; do
  st="$(docker compose ps --format '{{.Health}}' "$s" 2>/dev/null || true)"
  [ "$st" = healthy ] && ok "$s healthy" || bad "$s health='$st'"
done
log "2. Platform HTTP"
code="$(curl -s -o /dev/null -w '%{http_code}' -m 20 "http://localhost:$PP/" || true)"
[[ "$code" =~ ^(200|301|302)$ ]] && ok "platform / -> $code" || bad "platform / -> $code"
hc="$(curl -s -o /dev/null -w '%{http_code}' -m 20 "http://localhost:$PP/health" || true)"
echo "  info: platform /health -> $hc (endpoint availability depends on platform version)"
log "3. Dependencies reachable from platform container (network-level)"
for t in sqlserver:1433 elasticsearch:9200 redis:6379; do
  docker compose exec -T platform bash -c "exec 3<>/dev/tcp/${t%%:*}/${t##*:}" 2>/dev/null \
    && ok "platform -> $t" || bad "platform -> $t"
done
log "4. DB / search / cache not exposed on the host"
for p in 1433 9200 6379; do
  (exec 3<>/dev/tcp/127.0.0.1/$p) 2>/dev/null && bad "host port $p is open" || ok "host port $p closed"
done
if docker compose ps --services --filter status=running | grep -qx storefront; then
  log "5. Storefront + platform<->storefront communication"
  code="$(curl -s -o /dev/null -w '%{http_code}' -m 30 "http://localhost:$SP/" || true)"
  [[ "$code" =~ ^(200|301|302)$ ]] && ok "storefront / -> $code" || bad "storefront / -> $code"
  docker compose exec -T storefront bash -c 'exec 3<>/dev/tcp/platform/80' 2>/dev/null \
    && ok "storefront -> platform:80" || bad "storefront -> platform:80"
  docker compose logs --no-color --tail 200 storefront | grep -qiE 'unauthorized|401|connection refused|unable to connect' \
    && bad "storefront logs show platform auth/connect errors" || ok "no platform errors in storefront logs"
else
  echo "  skip: storefront not running (start with scripts/up.sh --with-storefront)"
fi
echo; [ "$FAILED" -eq 0 ] && { echo "ALL CHECKS PASSED"; exit 0; } || { echo "$FAILED CHECK(S) FAILED"; exit 1; }
