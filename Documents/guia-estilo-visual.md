# Guía de Estilo Visual - UniConnect UCEVA

**Integrantes:**
- David Mora Duque
- Juan Pablo Devia
- Juan Diego Rodríguez

**Docente:** Jairo Rodríguez Martínez  
**Institución:** Unidad Central del Valle del Cauca  
**Fecha:** 19/03/2026

---

## 1. Introducción

Este documento define la identidad visual de UniConnect UCEVA, una aplicación móvil exclusiva para la comunidad universitaria de la Universidad Central del Valle del Cauca. La guía de estilo establece los estándares de diseño que todo el equipo debe seguir durante el desarrollo, garantizando consistencia visual en todos los módulos y pantallas de la aplicación.

La identidad visual se inspira en el color institucional de la UCEVA, el verde esmeralda, que representa libertad y superación.

---

## 2. Identidad de Marca y Logo

### 2.1 Concepto del Logo

- **Ícono:** Una letra U estilizada sobre un cuadrado con bordes redondeados de color verde primario (#1D9E75).
- **Wordmark:** "Uni" en verde primario Bold, "Connect" en gris oscuro Regular. Debajo, "UCEVA" como sello institucional.

### 2.2 Variantes del Logo

| Variante | Uso | Descripción |
|---|---|---|
| Principal | Fondo blanco / claro | Logo completo con ícono verde y wordmark bicolor |
| Sobre fondo oscuro | Headers, splash screen | Ícono con opacidad reducida, texto en blanco y verde claro |
| Ícono app | Ícono de app, favicon | Solo la U sobre cuadrado verde, sin wordmark |

### 2.3 Normas de Uso del Logo

- No deformar, rotar ni cambiar las proporciones del logo.
- No cambiar los colores definidos en esta guía.
- Respetar el espacio mínimo alrededor del logo (equivalente a la altura de la U).
- No agregar efectos visuales como sombras, brillos o degradados.

---

## 3. Paleta de Colores

### 3.1 Colores Primarios

| Nombre | Hex | Uso principal |
|---|---|---|
| Verde UCEVA | `#1D9E75` | Botones primarios, CTAs, ícono app |
| Verde oscuro | `#085041` | Headers, barras de navegación, fondo splash |
| Verde claro | `#E1F5EE` | Fondos de cards activos, chips seleccionados |

### 3.2 Colores de Acento por Módulo

| Módulo | Hex | Justificación |
|---|---|---|
| Carpooling | `#1D9E75` | Verde principal — módulo estrella de la app |
| Bazar UCEVA | `#D85A30` | Coral/naranja — evoca mercado e intercambio |
| Reputación | `#EF9F27` | Ámbar/dorado — asociado a estrellas y calificación |
| Administración | `#378ADD` | Azul — transmite confianza y formalidad |

### 3.3 Colores de Texto y Estado

| Nombre | Hex | Uso |
|---|---|---|
| Texto principal | `#2C2C2A` | Títulos, nombres, información principal |
| Texto secundario | `#888780` | Subtítulos, metadata, fechas |
| Error | `#E24B4A` | Mensajes de error, validaciones fallidas |
| Advertencia | `#EF9F27` | Alertas, reputación baja |
| Fondo app | `#F8F9FA` | Background principal de todas las pantallas |

---

## 4. Tipografía

### 4.1 Fuente Principal

**Inter** — disponible en Google Fonts. Elegida por:
- Excelente legibilidad en pantallas pequeñas.
- Disponible en Flutter con google_fonts sin costo adicional.
- Soporta múltiples pesos: Regular, Medium, SemiBold, Bold.

### 4.2 Escala Tipográfica

| Nombre | Tamaño | Peso | Uso |
|---|---|---|---|
| Heading 1 | 28px | Bold 700 | Título de pantalla principal |
| Heading 2 | 20px | SemiBold 600 | Títulos de sección, cards |
| Heading 3 | 16px | Medium 500 | Subtítulos, nombre de usuario |
| Body | 14px | Regular 400 | Texto principal del cuerpo |
| Caption | 12px | Regular 400 | Fechas, metadata, etiquetas |
| Button | 14px | SemiBold 600 | Texto de botones y CTAs |

---

## 5. Componentes UI

### 5.1 Botones

- **Primario:** Fondo verde `#1D9E75`, texto blanco, border-radius 10px, altura mínima 48px.
- **Secundario:** Borde verde `#1D9E75` (1.5px), texto verde, fondo transparente.
- **Estado activo:** Fondo verde claro `#E1F5EE`, texto verde oscuro.

### 5.2 Badges y Chips

Etiquetas pill shape que usan el color del módulo al que pertenecen:
- **Conductor / Pasajero:** Verde claro sobre verde oscuro.
- **Reputación (⭐):** Ámbar claro sobre ámbar oscuro.
- **Estudiante / Docente:** Azul claro sobre azul oscuro.

### 5.3 Cards

- Borde: `0.5px solid #1D9E75`
- Border-radius: 10px
- Padding: 12px horizontal, 10px vertical
- Avatar: Círculo 24px con inicial del nombre sobre fondo verde.

### 5.4 Inputs y Formularios

- Altura mínima: 48px
- Borde activo: `#1D9E75` (2px)
- Borde inactivo: `#D3D1C7` (1px)
- Texto de error: `#E24B4A` debajo del campo.

---

## 6. Implementación en Flutter
```dart
// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary = Color(0xFF1D9E75);
  static const dark = Color(0xFF085041);
  static const light = Color(0xFFE1F5EE);
  static const blueAccent = Color(0xFF378ADD);
  static const coral = Color(0xFFD85A30);
  static const amber = Color(0xFFEF9F27);
  static const textMain = Color(0xFF2C2C2A);
  static const textSec = Color(0xFF888780);
  static const error = Color(0xFFE24B4A);
}
```

---

## 7. Resumen de Decisiones de Diseño

| Decisión | Justificación |
|---|---|
| Verde como color primario | Color institucional de la UCEVA. Genera identidad con la universidad. |
| Color diferente por módulo | Facilita la orientación del usuario dentro de la app. |
| Fuente Inter | Gratuita, legible en gama media Android, disponible en Flutter. |
| Altura mínima 48px | Estándar de accesibilidad de Google Material Design. |
| Border-radius 10px | Balance entre modernidad y formalidad. |