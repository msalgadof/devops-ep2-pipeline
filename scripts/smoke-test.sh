#!/usr/bin/env bash
# Uso: scripts/smoke-test.sh [BASE_URL]   (por defecto http://localhost:8080)
set -uo pipefail
BASE_URL="${1:-http://localhost:8080}"
TIMEOUT="${SMOKE_TIMEOUT:-90}"
fails=0

echo "Esperando a ${BASE_URL} (máx ${TIMEOUT}s)..."
for ((i = 0; i < TIMEOUT; i += 2)); do
  curl -sf "${BASE_URL}/actuator/health" >/dev/null && break
  sleep 2
done
curl -sf "${BASE_URL}/actuator/health" >/dev/null || { echo "[FALLO] orders-service no está saludable"; exit 1; }

expect() { # descripción, payload, código esperado
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "${BASE_URL}/orders" \
         -H 'Content-Type: application/json' -d "$2")
  if [ "$code" = "$3" ]; then
    echo "[OK]    $1 → $code"
  else
    echo "[FALLO] $1 → esperado $3, obtenido $code"
    fails=$((fails + 1))
  fi
}

expect "pedido con stock"     '{"itemId":1,"quantity":2}'  201
expect "sin stock"            '{"itemId":2,"quantity":1}'  409
expect "item inexistente"     '{"itemId":99,"quantity":1}' 404
expect "cantidad inválida"    '{"itemId":1,"quantity":0}'  400

[ "$fails" -eq 0 ] && echo "SMOKE TEST OK" || echo "SMOKE TEST: ${fails} fallo(s)"
exit "$fails"
