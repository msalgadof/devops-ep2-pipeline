#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/.."
FAILS=0
ok()   { echo "  [OK]    $1"; }
fail() { echo "  [FALLO] $1"; FAILS=$((FAILS+1)); }
check() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else fail "$d"; fi; }
cid() { docker compose ps -q "$1" | head -n1; }
post() { curl -s -o /dev/null -w "%{http_code}" -X POST localhost:8080/orders -H 'Content-Type: application/json' -d "$1"; }

trap 'docker compose down -v >/dev/null 2>&1' EXIT
docker compose down -v >/dev/null 2>&1

echo "== 1. Configuración =="
check "docker-compose.yml válido" docker compose config -q
check ".env.example existe" test -s .env.example
check "smoke-test.sh con sintaxis válida" bash -n scripts/smoke-test.sh
grep -q 'pids_limit' docker-compose.yml && fail "pids_limit sigue en el compose" || ok "sin pids_limit conflictivo"

echo "== 2. Levantar y salud =="
check "up --build --wait" docker compose up -d --build --wait --wait-timeout 180
for s in inventory-service orders-service; do
  [ "$(docker inspect -f '{{.State.Health.Status}}' "$(cid $s)" 2>/dev/null)" = "healthy" ] && ok "$s healthy" || fail "$s healthy"
done

echo "== 3. Smoke test =="
check "smoke-test.sh" ./scripts/smoke-test.sh

echo "== 4. Aislamiento de red =="
curl -s -m 3 localhost:8000/health >/dev/null 2>&1 && fail "inventory accesible desde el host" || ok "inventory NO accesible desde el host"
[ "$(docker network inspect ep2-pipeline_backend -f '{{.Internal}}' 2>/dev/null)" = "true" ] && ok "red backend interna" || fail "red backend interna"
check "orders alcanza a inventory por nombre" docker compose exec -T orders-service wget -qO- http://inventory-service:8000/health
docker compose exec -T inventory-service python -c "import urllib.request; urllib.request.urlopen('http://1.1.1.1', timeout=3)" >/dev/null 2>&1 \
  && fail "inventory tiene salida a internet" || ok "inventory sin salida a internet"

echo "== 5. Endurecimiento y límites =="
[ "$(docker compose exec -T orders-service id -u 2>/dev/null | tr -d '\r')" = "10001" ] && ok "orders no-root" || fail "orders no-root"
[ "$(docker inspect -f '{{.HostConfig.ReadonlyRootfs}}' "$(cid inventory-service)")" = "true" ] && ok "inventory FS solo lectura" || fail "inventory FS solo lectura"
[ "$(docker inspect -f '{{.HostConfig.Memory}}' "$(cid inventory-service)")" = "268435456" ] && ok "inventory límite 256M" || fail "inventory límite memoria"
[ "$(docker inspect -f '{{.HostConfig.Memory}}' "$(cid orders-service)")" = "536870912" ] && ok "orders límite 512M" || fail "orders límite memoria"
docker inspect -f '{{.HostConfig.CapDrop}}' "$(cid orders-service)" | grep -q ALL && ok "cap_drop ALL" || fail "cap_drop ALL"
[ -n "$(docker inspect -f '{{index .Config.Labels "org.opencontainers.image.revision"}}' "$(cid orders-service)")" ] && ok "label de revisión (trazabilidad)" || fail "label de revisión"

echo "== 6. Escalabilidad =="
check "scale inventory=3" docker compose up -d --scale inventory-service=3 --wait --wait-timeout 120
[ "$(docker compose ps -q inventory-service | wc -l)" = "3" ] && ok "3 réplicas corriendo" || fail "3 réplicas"
check "smoke con 3 réplicas" ./scripts/smoke-test.sh
check "volver a 1 réplica" docker compose up -d --scale inventory-service=1 --wait --wait-timeout 120

echo "== 7. Resiliencia =="
docker compose stop inventory-service >/dev/null 2>&1
sleep 3
[ "$(post '{"itemId":1,"quantity":1}')" = "503" ] && ok "inventory caído → orders responde 503" || fail "503 con inventory caído"
check "recuperación (up --wait)" docker compose up -d --wait --wait-timeout 120
check "smoke tras recuperación" ./scripts/smoke-test.sh

echo "== 8. Git =="
[ "$(git rev-parse --abbrev-ref HEAD)" != "main" ] && ok "no estás en main" || fail "estás en main"

echo
[ "$FAILS" -eq 0 ] && echo "TODO OK → listo para la Fase 5" || echo "$FAILS fallo(s) → revisa arriba"
exit "$FAILS"
