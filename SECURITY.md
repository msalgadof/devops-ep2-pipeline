# Política de seguridad

## Controles automáticos

| Control | Herramienta | Efecto ante fallos |
|---|---|---|
| Actualización de dependencias | Dependabot (pip, Maven, Docker, GitHub Actions), semanal hacia `develop` | PR automático con la actualización |
| Alertas y parches de seguridad | Dependabot security alerts y security updates | Alerta y PR automático |
| Escaneo de dependencias | Trivy (`fs`) | **Bloquea** el pipeline con vulnerabilidades CRITICAL |
| Escaneo de imágenes | Trivy (`image`), antes de publicar en GHCR | **Bloquea** la publicación con vulnerabilidades CRITICAL |
| Análisis estático (SAST) | SonarCloud con Quality Gate | **Bloquea** el pipeline si el Quality Gate falla |
| Ramas protegidas | `main` y `develop` con checks obligatorios | No se puede mergear con checks en rojo |

## Endurecimiento de contenedores

- Usuario no-root (UID 10001) en ambas imágenes.
- Imágenes mínimas (`python:3.12-slim` y `eclipse-temurin:21-jre-alpine`) con build multi-stage.
- Sistema de archivos de solo lectura, `cap_drop: ALL` y `no-new-privileges`.
- Límites de CPU y memoria por servicio.
- Red `backend` interna, sin salida a internet ni acceso desde el host. Solo `orders-service` se publica, y solo en `127.0.0.1`.
- Permisos mínimos del `GITHUB_TOKEN` por job.

## Gestión de vulnerabilidades

- **CVE-2026-65182, CVE-2026-65637 y CVE-2026-65905 (Tomcat):** corregidas fijando `tomcat.version=10.1.59` en `services/orders-service/pom.xml`. La versión 10.1.58 citada en los avisos no está publicada en Maven Central.

## Excepciones aceptadas

Definidas en `.trivyignore.yaml`, cada una con justificación y fecha de vencimiento (31-12-2026).

| CVE | Componente | Motivo |
|---|---|---|
| CVE-2026-47884 | spring-webmvc 6.2.19 | Afecta a `XsltView`. El servicio es una API REST/JSON que no usa vistas XSLT. La corrección existe solo en Spring Framework 7.0.9 |
| CVE-2026-47890 | spring-webmvc 6.2.19 | Afecta a SSE con vistas. El servicio no expone SSE ni renderiza vistas. Sin parche en la rama 6.2 |

**Acción de cierre:** migrar a Spring Boot 4.x (Spring Framework 7.x) y adaptar los tests (`@MockBean`, `@WebMvcTest`). La rama 3.5 de Spring Boot cerró su soporte open source el 30-06-2026.

## Reporte de vulnerabilidades

Abrir un *issue* privado en el repositorio o contactar a `@msalgadof`.
