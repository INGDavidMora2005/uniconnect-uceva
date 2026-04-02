# 🎓 UniConnect UCEVA

> Aplicación móvil de carpooling y marketplace académico para la comunidad universitaria de la UCEVA.

---

## 📌 Objetivo del Proyecto

UniConnect UCEVA es una plataforma móvil que conecta a estudiantes y docentes de la Universidad Central del Valle del Cauca (UCEVA) para:

- **Compartir rutas** de transporte (carpooling) de forma segura dentro de la comunidad universitaria.
- **Comprar y vender** materiales, libros y artículos académicos a través de un bazar virtual.

El objetivo es reducir costos de transporte, facilitar el intercambio de recursos académicos y fortalecer la comunidad UCEVA mediante una plataforma confiable y exclusiva para sus miembros.

---

## 👥 Equipo de Desarrollo

| Nombre | Rol |
|---|---|
| David Mora Duque | Líder Técnico / Desarrollador |
| Juan Pablo Devia Masso | Líder de Producto / Investigación |
| Juan Diego Rodriguez | Diseñador UX/UI |

---

## 🛠️ Tech Stack

| Capa | Tecnología |
|---|---|
| **App móvil** | Flutter + Dart |
| **Autenticación** | Firebase Authentication |
| **Base de datos** | Cloud Firestore |
| **Almacenamiento** | Firebase Storage |
| **Notificaciones** | Firebase Cloud Messaging (FCM) |
| **Mapas** | Google Maps Platform |
| **Control de versiones** | Git + GitHub |
| **Gestión de tareas** | Jira |
| **Diseño colaborativo** | Figma |
| **Integraciones** | Figma ↔ Jira sync |

---

## 🌿 Ramas del Repositorio

| Rama | Propósito |
|---|---|
| `main` | Versión estable y lista para producción |
| `develop` | Rama de desarrollo e integración |

---

## 📋 Gestión del Proyecto

El proyecto se gestiona con metodología **Scrum** en Jira:
- 🔗 [Tablero del proyecto en Jira](https://uni-connect-uceva-team-26.atlassian.net)
- **Sprint 0:** Investigación, diseño y configuración técnica
- **Sprints 1–5:** Desarrollo por módulos (Autenticación, Rutas, Bazar, Reputación, Administración)

---

## 📱 MVP — Funcionalidades Principales

1. Registro e inicio de sesión con correo UCEVA
2. Publicar y buscar rutas de transporte compartido
3. Publicar y buscar productos en el Bazar UCEVA
4. Sistema de calificaciones y reputación
5. Moderación básica de usuarios y publicaciones

---

## 🔗 Integraciones Figma ↔ Jira

La aplicación incluye integraciones bidireccionales entre Figma y Jira para sincronizar diseños y tareas:

### Configuración
1. Ve a la pantalla de Integraciones en la app
2. Conecta tu cuenta de Jira con URL base, email y API token
3. Conecta tu cuenta de Figma con access token
4. Una vez conectadas, puedes sincronizar issues de Jira con archivos de Figma

### Funcionalidades
- **Sync Jira → Figma**: Los cambios en issues se reflejan como comentarios en Figma
- **Sync Figma → Jira**: Las actualizaciones de archivos se sincronizan con issues relacionados
- **Sincronización bidireccional**: Mantén consistencia entre diseño y desarrollo
- **Almacenamiento seguro**: Credenciales encriptadas localmente

### Webhooks (Backend requerido)
Para sincronización en tiempo real, configura Firebase Functions siguiendo `WEBHOOK_SETUP.md`

---

## 📁 Estructura del Proyecto (próximamente)

```
uniconnect_uceva/
├── lib/
│   ├── main.dart
│   ├── screens/
│   ├── widgets/
│   ├── models/
│   └── services/
├── assets/
└── pubspec.yaml
```

---

*Proyecto Integrador — Séptimo Semestre de Ingeniería de Sistemas — UCEVA 2026*
