# Guía de contribución

## Estrategia de ramas (GitFlow)

| Rama | Propósito | Reglas |
|---|---|---|
| `main` | Código en producción, siempre desplegable | Solo recibe PR desde `develop` o `hotfix/*`. Cada release lleva un tag `vX.Y.Z` |
| `develop` | Integración y pruebas antes de producción | Solo recibe PR desde `feature/*` |
| `feature/<nombre>` | Cambios planificados | Se crea desde `develop` y vuelve a `develop` por PR |
| `hotfix/<nombre>` | Correcciones urgentes en producción | Se crea desde `main` y se mergea a `main` y a `develop` |

Nunca se hace push directo a `main` ni a `develop`.

## Commits (Conventional Commits)

`<tipo>(<alcance>): <descripción>`

Tipos: `feat`, `fix`, `docs`, `test`, `ci`, `chore`, `refactor`.
Ejemplos: `feat(compose): agrega healthchecks`, `fix(security): fija tomcat 10.1.59`.

## Flujo de trabajo

1. `git checkout develop && git pull && git checkout -b feature/<nombre>`
2. Desarrollar, ejecutar `./scripts/verify.sh` y `./scripts/verify-compose.sh`.
3. Abrir un Pull Request hacia `develop` con la plantilla.
4. Los checks del pipeline deben pasar (tests, cobertura, Trivy, SonarCloud, build).
5. Merge a `develop`. El push publica las imágenes y ejecuta el despliegue simulado.
6. Para liberar: PR de `develop` a `main` y tag `vX.Y.Z`.

## Checks obligatorios antes de mergear

- Test inventory-service
- Test orders-service
- Dependency scan (Trivy)
- SAST + Quality Gate (SonarCloud)
- Build & scan (inventory-service)
- Build & scan (orders-service)

## Política de calidad

- Cobertura mínima de pruebas unitarias: **80 %** por servicio.
- Sin vulnerabilidades CRITICAL en dependencias ni imágenes (salvo excepciones documentadas en `SECURITY.md`).
- Quality Gate de SonarCloud en verde.
- Sin secretos en el repositorio: se usan *GitHub Secrets*.
