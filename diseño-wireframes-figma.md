# UU28 - Wireframes UniConnect

## DISEÑO DE WIREFRAMES DE PANTALLAS PRINCIPALES EN FIGMA

**Integrantes:**
- David Mora Duque
- Juan Pablo Devia
- Juan Diego Rodríguez

**Docente:**  
Jairo Rodríguez Martínez

**Institución:**  
Unidad Central del Valle del Cauca  
Tuluá, Valle del Cauca  

**Fecha:**  
19/03/2026  

---

# Diseño de Wireframes - Pantallas Principales

## 1. Introducción

Este documento describe el proceso de diseño y creación de wireframes de las pantallas principales de UniConnect UCEVA, desarrollado como parte del Sprint 0 del proyecto integrador de séptimo semestre de Ingeniería de Sistemas.

Los wireframes representan la estructura visual y funcional de la aplicación móvil antes de pasar a la fase de desarrollo, permitiendo al equipo validar los flujos de usuario y la organización de la información.

UniConnect UCEVA es una aplicación móvil exclusiva para la comunidad de la Universidad Central del Valle del Cauca, que integra dos módulos principales:

- Un sistema de carpooling para compartir rutas de transporte  
- Un bazar académico para la compra y venta de materiales de estudio  

---

## 2. Objetivo del Diseño de Wireframes

El objetivo principal de la tarea UU-28 fue diseñar los wireframes de las pantallas principales de UniConnect UCEVA en Figma, aplicando la guía de estilo visual definida en UU-30.

### Objetivos específicos

- Visualizar la estructura de cada pantalla antes del desarrollo, evitando reprocesos costosos de código  
- Validar los flujos de navegación entre módulos (autenticación, carpooling, bazar, perfil)  
- Establecer un estándar visual consistente para el desarrollo en Flutter  
- Facilitar las pruebas de usabilidad con usuarios reales  
- Servir como base para el prototipo navegable  

---

## 3. Herramienta y Metodología

### 3.1 Herramienta utilizada

Los wireframes fueron diseñados en Figma, plataforma de diseño colaborativo seleccionada como herramienta oficial del proyecto.

Se utilizó la plantilla:

- Mobile App Wireframing UI Kit (Figma Community)

---

### 3.2 Especificaciones técnicas

- Tamaño de frame: 393×852 px (iPhone 14 Pro)  
- Fuente: Inter (Google Fonts)  

**Paleta de colores:**
- Verde primario: `#1D9E75`  
- Verde oscuro: `#085041`  
- Coral: `#D85A30`  
- Ámbar: `#EF9F27`  

- Fondo: `#F7F8F5`  

**Colores por módulo:**
- Verde → Carpooling  
- Coral → Bazar  

---

### 3.3 Proceso de diseño

El diseño siguió un proceso iterativo de cinco fases:

1. Creación del frame base  
2. Aplicación del status bar y navegación  
3. Construcción del contenido principal  
4. Revisión de consistencia visual  
5. Ajustes finales  

---

## 4. Pantallas Diseñadas - Justificación y Propósito

### 4.1 Módulo de Autenticación

#### Pantalla 01 - Splash Screen
Primera pantalla de la app. Presenta la identidad visual y permite la carga inicial.

#### Pantalla 02 - Login
Permite el acceso mediante correo institucional y contraseña.

#### Pantalla 03 - Registro
Permite crear una cuenta capturando:

- Nombre completo  
- Código estudiantil  
- Correo institucional  
- Contraseña  
- Rol (estudiante, docente, administrativo)  

#### Pantalla 04 - Perfil de Usuario
Permite visualizar:

- Información personal  
- Historial de actividad  
- Reputación del usuario  

---

### 4.2 Módulo de Carpooling

#### Pantalla 05 - Home Rutas
Pantalla principal del módulo. Muestra rutas disponibles con:

- Origen  
- Destino  
- Hora  
- Precio  
- Reputación del conductor  

#### Pantalla 06 - Publicar Ruta
Formulario para que los conductores publiquen rutas.

#### Pantalla 07 - Detalle de Ruta
Muestra:

- Mapa del trayecto  
- Información del conductor  
- Detalles del viaje  
- Acciones (solicitar o reportar)  

#### Pantalla 11 - Solicitar Cupo
Permite confirmar la solicitud de un viaje e incluir un mensaje opcional.

---

### 4.3 Módulo Bazar UCEVA

#### Pantalla 08 - Home Bazar
Catálogo de productos en formato grid con filtros por categoría.

#### Pantalla 09 - Publicar Producto
Formulario que permite:

- Subir imágenes  
- Ingresar nombre  
- Categoría  
- Precio  
- Estado (nuevo/usado)  
- Descripción  

#### Pantalla 10 - Detalle de Producto
Muestra:

- Imagen  
- Precio  
- Categoría  
- Estado  
- Descripción  
- Perfil del vendedor  

---

### 4.4 Módulo de Reputación

#### Pantalla 12 - Calificación
Permite calificar usuarios mediante:

- Sistema de estrellas (1 a 5)  
- Etiquetas de valoración  
- Comentarios opcionales  

---

### 4.5 Pantallas adicionales

#### Pantalla 13 - Notificaciones
Centraliza notificaciones del sistema:

- Rutas  
- Bazar  
- Sistema  

---

## 5. Consistencia Visual Aplicada

- Header verde oscuro en pantallas secundarias  
- Bottom Navigation en pantallas principales  
- Colores diferenciados por módulo  
- Tipografía Inter con escala:

  - H1: 28px  
  - H2: 20px  
  - Body: 14px  
  - Caption: 12px  

- Cards con bordes y esquinas redondeadas  
- Status bar oscuro para contraste  

---

## 6. Conclusión

El diseño de los wireframes representa la base visual del proyecto antes de su implementación.

Cumple tres funciones principales:

1. Servir como guía para el desarrollo en Flutter  
2. Base para pruebas de usabilidad  
3. Validar la viabilidad del proyecto  

El proceso también demuestra la capacidad del equipo para adaptarse a herramientas como Figma y cumplir con los objetivos del Sprint 0. 