#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/.."
FAILS=0
ok()   { echo "  [OK]    $1"; }
fail() { echo "  [FALLO] $1"; FAILS=$((FAILS+1)); }
check() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else fail "$d"; fi; }

cleanup() { docker rm -f inventory-service orders-service >/dev/null 2>&1; docker network rm ep2-net >/dev/null 2>&1; }
trap cleanup EXIT
cleanup

echo "== 1. Archivos requeridos (no vacíos) =="
for f in services/inventory-service/{Dockerfile,.dockerignore,requirements.txt,requirements-dev.txt,pytest.ini,app/main.py,tests/test_main.py} \
         services/orders-service/{Dockerfile,.dockerignore,pom.xml,src/main/java/cl/duoc/orders/OrderController.java,src/main/java/cl/duoc/orders/InventoryClient.java} \
         services/orders-service/src/test/java/cl/duoc/orders/{OrderControllerTest,InventoryClientTest,OrdersApplicationTests}.java; do
  check "$f" test -s "$f"
done

echo "== 2. Tests inventory-service (PyTest + cobertura 80% + ruff) =="
check "pytest + cobertura + ruff" docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp \
  -v "$PWD/services/inventory-service":/app -w /app python:3.12-slim \
  sh -c "pip install -q --user -r requirements-dev.txt && python -m pytest -q && python -m ruff check ."

echo "== 3. Tests orders-service (JUnit + JaCoCo 80%) =="
check "mvn verify (tests + check JaCoCo)" docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp \
  -v "$PWD/services/orders-service":/app -w /app maven:3.9-eclipse-temurin-21 \
  mvn -B -q -Dmaven.repo.local=/tmp/m2 verify
check "reporte JaCoCo generado" test -f services/orders-service/target/site/jacoco/index.html

echo "== 4. Build de imágenes =="
check "build inventory-service" docker build -q -t inventory-service:dev services/inventory-service
check "build orders-service"    docker build -q -t orders-service:dev services/orders-service

echo "== 5. Usuario no-root =="
[[ "$(docker run --rm --entrypoint id inventory-service:dev -u 2>/dev/null)" = "10001" ]] && ok "inventory-service UID 10001" || fail "inventory-service UID"
[[ "$(docker run --rm --entrypoint id orders-service:dev -u 2>/dev/null)" = "10001" ]] && ok "orders-service UID 10001" || fail "orders-service UID"

echo "== 6. Prueba end-to-end =="
docker network create ep2-net >/dev/null
docker run -d --name inventory-service --network ep2-net inventory-service:dev >/dev/null
docker run -d --name orders-service --network ep2-net -p 8080:8080 orders-service:dev >/dev/null
for i in $(seq 1 40); do
  curl -sf localhost:8080/actuator/health >/dev/null 2>&1 && break; sleep 2
done
post() { curl -s -o /dev/null -w "%{http_code}" -X POST localhost:8080/orders -H 'Content-Type: application/json' -d "$1"; }
[[ "$(post '{"itemId":1,"quantity":2}')"  = "201" ]] && ok "pedido con stock → 201"        || fail "pedido con stock"
[[ "$(post '{"itemId":2,"quantity":1}')"  = "409" ]] && ok "sin stock → 409"               || fail "sin stock"
[[ "$(post '{"itemId":99,"quantity":1}')" = "404" ]] && ok "item inexistente → 404"        || fail "item inexistente"
[[ "$(post '{"itemId":1,"quantity":0}')"  = "400" ]] && ok "cantidad inválida → 400"       || fail "cantidad inválida"
sleep 12
for s in inventory-service orders-service; do
  [[ "$(docker inspect -f '{{.State.Health.Status}}' $s 2>/dev/null)" = "healthy" ]] && ok "$s healthcheck healthy" || fail "$s healthcheck"
done

echo "== 7. Git =="
[[ "$(git rev-parse --abbrev-ref HEAD)" != "main" ]] && ok "no estás trabajando sobre main" || fail "estás en main"
git diff --quiet && git diff --cached --quiet && ok "sin cambios sin commitear" || fail "hay cambios sin commitear"
git ls-remote --exit-code origin >/dev/null 2>&1 && ok "remoto accesible" || fail "remoto"

echo
[[ "$FAILS" -eq 0 ]] && echo "TODO OK → listo para la Fase 4" || echo "$FAILS fallo(s) → revisa arriba"
exit "$FAILS"
