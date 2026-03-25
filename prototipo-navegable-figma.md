# UU29 - Prototipo UniConnect

## PROTOTIPO NAVEGABLE DE LA APLICACIÓN EN FIGMA

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
25/03/2026  

---

# Prototipo Navegable - Conexiones y Flujos

## 1. Introducción

Este documento describe el prototipo navegable de UniConnect UCEVA, desarrollado como tarea UU-29 del Sprint 0.

Un prototipo navegable es una versión interactiva del diseño que simula el comportamiento real de la aplicación sin necesidad de código, permitiendo al usuario navegar entre pantallas como si usara la app final.

El prototipo fue construido sobre los 13 wireframes diseñados en UU-28, conectando cada pantalla mediante flujos de navegación definidos en Figma.

---

## 2. Objetivo del Prototipo Navegable

El prototipo cumple tres objetivos fundamentales:

- Validar los flujos de navegación (recorrido lógico e intuitivo)
- Facilitar pruebas de usabilidad con usuarios reales
- Reducir riesgos antes del desarrollo en Flutter

---

## 3. Pantallas del Prototipo

| #  | Pantalla           | Módulo        | Descripción         |
|----|--------------------|---------------|---------------------|
| 01 | Splash Screen      | Entrada       | Pantalla de carga   |
| 02 | Login              | Autenticación | Inicio de sesión    |
| 03 | Registro           | Autenticación | Crear cuenta        |
| 04 | Perfil             | Perfil        | Info del usuario    |
| 05 | Home Rutas         | Carpooling    | Listado de rutas    |
| 06 | Publicar Ruta      | Carpooling    | Crear ruta          |
| 07 | Detalle de Ruta    | Carpooling    | Info de ruta        |
| 08 | Home Bazar         | Bazar         | Catálogo            |
| 09 | Publicar Producto  | Bazar         | Crear producto      |
| 10 | Detalle Producto   | Bazar         | Info producto       |
| 11 | Solicitar Cupo     | Carpooling    | Confirmación        |
| 12 | Calificación       | Reputación    | Sistema de rating   |
| 13 | Notificaciones     | Sistema       | Alertas             |

---

## 4. Mapa de Flujos de Navegación

### 4.1 Flujo 1 - Onboarding y Autenticación

| Origen → Destino | Acción |
|------------------|--------|
| Splash → Login | Automático (2 segundos) |
| Login → Home Rutas | Botón "Ingresar" |
| Login → Registro | Link "Regístrate" |
| Registro → Login | Link o botón atrás |
| Registro → Home Rutas | Botón "Crear cuenta" |

---

### 4.2 Flujo 2 - Módulo Carpooling

| Origen → Destino | Acción |
|------------------|--------|
| Home Rutas → Detalle Ruta | Tap en card |
| Home Rutas → Publicar Ruta | Botón flotante |
| Publicar Ruta → Home | Publicar o cancelar |
| Detalle Ruta → Solicitar Cupo | Botón |
| Detalle Ruta → Home | Flecha atrás |
| Solicitar Cupo → Home | Confirmar o cancelar |
| Solicitar Cupo → Calificación | Post-viaje |
| Calificación → Home | Enviar u omitir |

---

### 4.3 Flujo 3 - Módulo Bazar

| Origen → Destino | Acción |
|------------------|--------|
| Home Bazar → Detalle Producto | Tap en producto |
| Home Bazar → Publicar Producto | Botón flotante |
| Publicar Producto → Home | Publicar o cancelar |
| Detalle Producto → Home | Flecha atrás |
| Detalle Producto → Calificación | Post-venta |

---

### 4.4 Flujo 4 - Navegación Global

| Desde | Hacia | Acción |
|------|------|--------|
| Cualquier pantalla | Home Rutas | Icono 🚗 |
| Cualquier pantalla | Home Bazar | Icono 🛍️ |
| Cualquier pantalla | Perfil | Icono 👤 |
| Cualquier pantalla | Notificaciones | Icono 🔔 |

---

## 5. Reglas de Navegación

### 5.1 Pantallas sin navegación inferior

No tienen bottom nav:

- Publicar Ruta  
- Detalle de Ruta  
- Publicar Producto  
- Detalle de Producto  
- Solicitar Cupo  
- Calificación  

---

### 5.2 Pantallas de entrada única

Las pantallas de autenticación solo aparecen al inicio o al cerrar sesión.

---

### 5.3 Flujo de calificación

Se accede después de completar:

- Un viaje  
- Una transacción  

---

### 5.4 Botón atrás

Todas las pantallas secundarias tienen botón ← para regresar.

---

## 6. Enlace al Prototipo

Puedes acceder al prototipo en Figma:

https://www.figma.com/design/phkRWEZJPGogl7VN2qbBA0/UniConnect-Wireframes-UU-28

---

## 7. Conclusión

El prototipo navegable conecta las 13 pantallas mediante 21 flujos organizados en:

- Onboarding  
- Carpooling  
- Bazar  
- Navegación global  

Esto permite al usuario completar las acciones principales de la app:

- Buscar rutas  
- Solicitar cupos  
- Comprar productos  
- Publicar artículos  

---

## Índice

1. Introducción  
2. Objetivo del Prototipo  
3. Pantallas  
4. Flujos de navegación  
   - 4.1 Autenticación  
   - 4.2 Carpooling  
   - 4.3 Bazar  
   - 4.4 Navegación global  
5. Reglas  
6. Enlace  
7. Conclusión  