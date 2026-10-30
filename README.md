# DevOps EP2 · Pipeline CI/CD de microservicios

[![CI/CD](https://github.com/msalgadof/devops-ep2-pipeline/actions/workflows/ci-cd.yml/badge.svg?branch=main)](https://github.com/msalgadof/devops-ep2-pipeline/actions/workflows/ci-cd.yml)
[![Quality Gate](https://sonarcloud.io/api/project_badges/measure?project=msalgadof_devops-ep2-pipeline&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=msalgadof_devops-ep2-pipeline)

Pipeline CI/CD en GitHub Actions que automatiza el ciclo de vida de dos microservicios: pruebas, análisis de seguridad, construcción de imágenes, publicación y despliegue simulado con Docker Compose.

**Asignatura:** Ingeniería DevOps (DOY0101) · Evaluación Parcial N°2

## Microservicios

| Servicio | Stack | Función |
|---|---|---|
| `inventory-service` | Python 3.12 · FastAPI | Catálogo y stock |
| `orders-service` | Java 21 · Spring Boot 3.5 | Crea pedidos y valida el stock con `inventory-service` |

Detalle en [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Estructura

## Ejecución local

Requisitos: Docker y Docker Compose.

```bash
cp .env.example .env
docker compose up -d --build --wait
./scripts/smoke-test.sh
curl -X POST localhost:8080/orders -H 'Content-Type: application/json' -d '{"itemId":1,"quantity":2}'
docker compose down -v
```

| Pedido | Respuesta |
|---|---|
| `itemId` 1, cantidad 2 | `201` creado |
| `itemId` 2, cantidad 1 | `409` stock insuficiente |
| `itemId` 99 | `404` ítem inexistente |
| cantidad 0 | `400` datos inválidos |

Verificación completa: `./scripts/verify.sh` y `./scripts/verify-compose.sh`.

## Pipeline



Detalle de cada etapa, políticas y problemas frecuentes en [docs/PIPELINE.md](docs/PIPELINE.md).

## Calidad

- Pruebas unitarias con PyTest y JUnit; cobertura mínima de **80 %** con ruff, pytest-cov y JaCoCo. El build **falla** si no se alcanza.
- SonarCloud con Quality Gate bloqueante.
- `main` y `develop` protegidas: no se mergea con checks en rojo.

## Seguridad

- Dependabot semanal (pip, Maven, Docker, GitHub Actions) y alertas de seguridad activas.
- Trivy sobre dependencias e imágenes: **bloquea** ante vulnerabilidades CRITICAL.
- Contenedores no-root, FS de solo lectura, `cap_drop: ALL`, red interna y límites de recursos.
- Excepciones aceptadas y justificadas en [SECURITY.md](SECURITY.md).

## Trazabilidad

| Etapa | Evidencia |
|---|---|
| Commit | SHA del commit en Actions |
| Pruebas | Run de Actions y artefactos de cobertura |
| Build | Imagen `ghcr.io/msalgadof/<servicio>:sha-<7>` |
| Metadatos | Label `org.opencontainers.image.revision` = SHA completo |
| Deploy | Tabla de resumen del job *Deploy simulado*, que verifica que la imagen corresponde al commit |

Releases con tag semántico `vX.Y.Z`, que publica además las imágenes `X.Y.Z` y `X.Y`.

## Evidencias

- Ejecución del pipeline en `develop` (todos los jobs en verde, incluido el despliegue): https://github.com/msalgadof/devops-ep2-pipeline/actions/runs/41139917527
- Análisis de SonarCloud: https://sonarcloud.io/summary/new_code?id=msalgadof_devops-ep2-pipeline
- Imágenes publicadas: https://github.com/msalgadof?tab=packages&repo_name=devops-ep2-pipeline

## Correspondencia con la rúbrica

| Indicador | Dónde se cumple |
|---|---|
| IE1 · Contenedores | Dockerfiles multi-stage, no-root, healthcheck; build y publicación en el pipeline |
| IE2 · Pruebas | `pytest` y `mvn verify` en el pipeline con umbral del 80 % |
| IE3 · Seguridad y parámetros | Dependabot, Trivy, SonarCloud con Quality Gate, ramas protegidas, permisos mínimos, límites de recursos |
| IE4 · Despliegue y trazabilidad | Job *Deploy simulado* con smoke test y verificación commit → imagen |
| IE5 · Orquestación | `docker-compose.yml` con redes, healthchecks, `depends_on` condicional, escalado y límites |

## Flujo de trabajo

GitFlow con PR obligatorio y Conventional Commits. Ver [CONTRIBUTING.md](CONTRIBUTING.md).
