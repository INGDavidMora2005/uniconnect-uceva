# Stack Tecnológico del Proyecto

## UniConnect UCEVA

---

## 1. Descripción General

UniConnect es una aplicación móvil para la comunidad universitaria de la UCEVA que integra dos módulos principales: carpooling (transporte compartido entre estudiantes) y Marketplace (compra y venta de artículos académicos). A continuación, se define el stack tecnológico propuesto para el desarrollo del proyecto.

---

## 2. Frontend – Aplicación Móvil

| Categoría | Tecnología | Justificación |
|---|---|---|
| Framework | Flutter (Dart) | Desarrollo multiplataforma (Android/iOS) con una sola base de código, alto rendimiento y UI nativa. |
| IDE Principal | Android Studio | IDE oficial para desarrollo Flutter/Android con emulador integrado y herramientas de depuración. |
| IDE Alternativo | Visual Studio Code | Editor liviano con extensión oficial de Flutter, útil para desarrollo rápido. |
| Control de versiones | GitHub | Repositorio central del código fuente, manejo de ramas, revisión de pull requests y colaboración entre integrantes del equipo. |

---

## 3. Backend – Flutter / Dart

El proyecto no contará con un servidor backend independiente. Toda la lógica de negocio se manejará directamente desde la aplicación Flutter utilizando Dart, en combinación con los servicios que provea la plataforma de base de datos seleccionada (Firebase o Supabase).

| Categoría | Tecnología | Justificación |
|---|---|---|
| Lenguaje | Dart | Lenguaje nativo de Flutter. Gestiona la lógica de negocio, validaciones y consumo de servicios directamente desde el cliente. |
| Arquitectura | BLoC / Provider | Patrones de gestión de estado en Flutter que permiten separar la lógica de negocio de la interfaz de usuario. |
| Comunicación con BD | SDK de Firebase o Supabase para Dart | Ambas plataformas cuentan con SDK oficial para Flutter/Dart, permitiendo conexión directa sin necesidad de servidor intermedio. |

---

## 4. Base de Datos – Firebase vs Supabase

Se están evaluando dos alternativas para la base de datos y autenticación del proyecto:

| Criterio | Firebase (Google) | Supabase (Open Source) |
|---|---|---|
| Tipo de BD | NoSQL (Firestore) | SQL (PostgreSQL) |
| Autenticación | Sí, integrada (email, Google, etc.) | Sí, integrada con Row Level Security |
| Integración Flutter | Excelente – SDK oficial maduro | Buena – SDK en crecimiento activo |
| Tiempo real | Sí, nativo | Sí, con Realtime subscriptions |
| Plan gratuito | Sí, generoso para proyectos pequeños | Sí, 500MB base de datos incluidos |
| Curva de aprendizaje | Baja – mucha documentación y tutoriales | Media – requiere conocimiento básico de SQL |
| Recomendado para | Apps con datos no relacionales, notificaciones push, almacenamiento de archivos. | Apps con datos relacionales estructurados (ideal para marketplace con usuarios, productos, transacciones). |

> **Decisión pendiente.** Se recomienda Supabase si el equipo tiene conocimientos básicos de SQL, dado que el modelo de datos de UniConnect (usuarios, viajes, productos, transacciones) es naturalmente relacional.

---

## 5. Herramientas de Gestión y Colaboración

| Herramienta | Tecnología | Uso |
|---|---|---|
| Diseño UI/UX | Figma | Herramienta principal de diseño. Se usará para crear wireframes, prototipos interactivos, guía de estilos y pantallas finales de UniConnect. |
| Gestión de proyecto | Jira | Seguimiento de tareas, sprints y backlog del equipo. |
| Documentación | Confluence / Drive | Documentación técnica y entregables del proyecto. |
| Comunicación | Slack | Canal oficial de comunicación del equipo. Permite coordinación diaria, notificaciones del proyecto e integraciones con Jira y GitHub. |

---

## 6. Resumen del Stack Definido

- **Frontend:** Flutter (Dart)
- **IDE:** Android Studio + Visual Studio Code
- **Lenguaje backend:** Dart (lógica de negocio dentro de Flutter)
- **Control de versiones:** GitHub
- **Base de datos:** Por definir (opciones: Firebase o Supabase)
- **Diseño UI/UX:** Figma
- **Gestión:** Jira + Slack

---

## 7. Conclusión

El equipo de UniConnect UCEVA ha definido Flutter con Dart como tecnología central del proyecto, manejando tanto el frontend como la lógica de negocio desde la misma plataforma, sin necesidad de un servidor backend independiente. Figma será la herramienta oficial de diseño UI/UX para todo el proyecto. La decisión sobre la base de datos (Firebase o Supabase) está en proceso de evaluación y será definida en las próximas sesiones del Sprint 0, tomando como base la comparativa presentada en este documento.

---

*Proyecto Integrador – Séptimo Semestre de Ingeniería de Sistemas – UCEVA 2026*