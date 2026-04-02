# Configuración de Entornos de Desarrollo

## UniConnect UCEVA

---

## 1. Descripción General

UniConnect UCEVA es una aplicación móvil para la comunidad universitaria de la UCEVA que integra dos módulos principales: carpooling (transporte compartido entre estudiantes y docentes) y Marketplace (compra y venta de artículos académicos). El presente documento describe el proceso de configuración de los entornos de desarrollo de cada integrante del equipo, como parte de las actividades definidas en el Sprint 0 del proyecto.

---

## 2. Equipo de Desarrollo

La siguiente tabla presenta los integrantes del equipo, sus roles dentro del proyecto y el estado de configuración de su entorno de desarrollo:

| Integrante | Rol | Estado del Entorno |
|---|---|---|
| David Mora Duque | Líder Técnico / Desarrollador | Configurado |
| Juan Pablo Devia Masso | Líder de Producto / Investigación | Configurado |
| Juan Diego Rodriguez | Diseñador UX/UI | Configurado |

---

## 3. Stack Tecnológico del Proyecto

El stack tecnológico fue definido y documentado en el documento de referencia *Stack Tecnológico del Proyecto – UniConnect UCEVA*. A continuación, se presenta el resumen de las tecnologías que cada integrante debe tener disponibles en su entorno:

| Capa | Tecnología |
|---|---|
| Frontend / App Móvil | Flutter (Dart) |
| IDE Principal | Android Studio |
| IDE Alternativo | Visual Studio Code |
| Lógica de Negocio | Dart (BLoC / Provider) |
| Base de Datos | Por definir: Firebase (Firestore) o Supabase (PostgreSQL) |
| Autenticación | Firebase Authentication o Supabase Auth |
| Almacenamiento | Firebase Storage o Supabase Storage |
| Notificaciones | Firebase Cloud Messaging (FCM) |
| Mapas | Google Maps Platform |
| Diseño UI/UX | Figma |
| Control de Versiones | Git + GitHub |
| Gestión de Tareas | Jira (metodología Scrum) |
| Comunicación | Slack |

> **Nota:** La decisión entre Firebase y Supabase como plataforma de base de datos y autenticación se encuentra en proceso de evaluación durante el Sprint 0, según lo indicado en el documento de stack tecnológico del equipo.

---

## 4. Herramientas Requeridas por Integrante

Cada integrante del equipo debe tener instaladas y correctamente configuradas las siguientes herramientas en su máquina con sistema operativo Windows:

| Herramienta | Versión | Propósito en el Proyecto |
|---|---|---|
| Flutter SDK | 3.x (stable) | Framework principal para el desarrollo de la app móvil (iOS/Android) |
| Android Studio | Hedgehog o superior | IDE principal con emulador integrado, plugins de Flutter y Dart |
| Dart SDK | Incluido con Flutter | Lenguaje de programación para lógica de negocio y UI |
| Git | 2.x o superior | Control de versiones y colaboración mediante GitHub |
| VS Code (opcional) | Última versión | Editor alternativo liviano con extensión oficial de Flutter |

---

## 5. Pasos de Configuración del Entorno

### 5.1 Instalación de Flutter SDK

La instalación del SDK de Flutter se realizó siguiendo los pasos oficiales de la documentación de Flutter para Windows (<https://docs.flutter.dev/get-started/install/windows>):

1. Descargar el archivo ZIP del SDK desde el sitio oficial de Flutter.
2. Extraer el contenido en la ruta `C:\flutter` (se evitan rutas con espacios o caracteres especiales).
3. Agregar `C:\flutter\bin` a la variable de entorno PATH del sistema operativo.
4. Abrir una nueva terminal y ejecutar el comando:
   ```
   flutter doctor
   ```
5. Verificar que no aparezcan errores críticos en la salida del comando.

### 5.2 Instalación de Android Studio

Se instaló Android Studio siguiendo la configuración estándar recomendada para proyectos Flutter:

1. Descargar Android Studio desde <https://developer.android.com/studio> e instalar con la configuración por defecto.
2. Asegurarse de incluir en la instalación: Android SDK, Android SDK Platform y Android Virtual Device (AVD).
3. Instalar el plugin oficial de Flutter desde: `File → Settings → Plugins → buscar "Flutter" → Install`.
4. El plugin de Dart se instala automáticamente como dependencia del plugin de Flutter.
5. Configurar la ruta del SDK de Flutter en: `File → Settings → Languages & Frameworks → Flutter → Flutter SDK path`.

### 5.3 Configuración de Git y GitHub

Git fue instalado y configurado para la colaboración en el repositorio del proyecto:

1. Instalar Git para Windows desde <https://git-scm.com/download/win> con las opciones por defecto.
2. Configurar la identidad del usuario con los siguientes comandos en la terminal:
   ```bash
   git config --global user.name "Nombre del Integrante"
   git config --global user.email "correo@uceva.edu.co"
   ```
3. Clonar el repositorio del proyecto desde GitHub:
   ```bash
   git clone https://github.com/INGDavidMora2005/uniconnect-uceva
   ```
4. Cambiar a la rama de desarrollo activa:
   ```bash
   git checkout develop
   ```

### 5.4 Configuración del Emulador Android (AVD)

Para probar la aplicación sin necesidad de un dispositivo físico, se configuró un emulador Android Virtual Device (AVD):

1. En Android Studio ir a: `Tools → Device Manager → Create Device`.
2. Seleccionar el perfil de hardware: Pixel 6 (o similar con pantalla de aproximadamente 6 pulgadas).
3. Seleccionar la imagen del sistema: API Level 33 (Android 13) y descargarla si no está disponible.
4. Finalizar la creación del dispositivo virtual y verificar que inicia correctamente.
5. Confirmar el funcionamiento ejecutando `flutter run` con el emulador activo.

---

## 6. Estructura del Proyecto Flutter

Una vez clonado el repositorio, la estructura de carpetas del proyecto es la siguiente:

```
uniconnect_uceva/
├── lib/
│   ├── main.dart              # Punto de entrada de la aplicación
│   ├── screens/               # Pantallas: Login, Home, Rutas, Bazar
│   ├── widgets/               # Componentes reutilizables de la UI
│   ├── models/                # Modelos de datos: User, Route, Product
│   └── services/              # Servicios: Firebase/Supabase, Maps, Auth
├── assets/                    # Imágenes, íconos, fuentes
└── pubspec.yaml               # Dependencias del proyecto
```

---

## 7. Flujo de Trabajo con Git – Ramas del Repositorio

El equipo trabaja bajo la metodología Scrum gestionada en Jira. El manejo del repositorio sigue la siguiente estructura de ramas:

| Rama | Propósito |
|---|---|
| `main` | Versión estable y lista para producción |
| `develop` | Rama de integración, donde se unen todos los cambios del equipo |
| `feature/auth` | Desarrollo del módulo de autenticación |
| `feature/routes` | Desarrollo del módulo de rutas (carpooling) |
| `feature/bazar` | Desarrollo del módulo del bazar (marketplace) |

El flujo de trabajo para cada tarea del sprint consiste en: crear una rama `feature` desde `develop`, desarrollar la funcionalidad, abrir un pull request hacia `develop` y realizar la revisión de código antes de integrar los cambios.

---

## 8. Verificación del Entorno

Para confirmar que el entorno de desarrollo está correctamente configurado, cada integrante debe ejecutar el siguiente comando y verificar que no existan errores críticos:

```bash
flutter doctor -v
```

Los ítems que deben aparecer sin errores son los siguientes:

- Flutter (canal stable, versión 3.x)
- Android toolchain – librerías del SDK instaladas correctamente
- Android Studio – con los plugins de Flutter y Dart activos
- Connected device – al menos un dispositivo físico o emulador disponible

---

## 9. Lista de Verificación por Integrante

La siguiente tabla permite registrar el estado de configuración de cada ítem por integrante:

| Ítem de Verificación | David Mora | Juan Pablo Devia |
|---|---|---|
| Flutter SDK instalado y configurado en el PATH | | |
| `flutter doctor -v` sin errores críticos | | |
| Android Studio instalado con plugins Flutter y Dart | | |
| Emulador AVD creado y funcional | | |
| Git configurado con correo institucional UCEVA | | |
| Repositorio clonado localmente | | |
| Rama develop activa (`git checkout develop`) | | |
| `flutter pub get` ejecutado sin errores | | |
| App de prueba corriendo en el emulador | | |

---

## 10. Conclusión

Los tres integrantes del equipo UniConnect UCEVA han configurado sus entornos de desarrollo con las herramientas necesarias para iniciar el desarrollo del proyecto en Flutter. La configuración incluye el SDK de Flutter, Android Studio con los plugins correspondientes, Git integrado con el repositorio del proyecto en GitHub y un emulador Android funcional.

Esta configuración constituye la base técnica para avanzar hacia los Sprints 1 al 5, en los que se desarrollarán los módulos de Autenticación, Rutas, Bazar, Reputación y Administración de la aplicación.

---

*Documento correspondiente a la tarea UU-32 – Sprint 0 | UniConnect UCEVA – Proyecto Integrador 7° Semestre – UCEVA 2026*