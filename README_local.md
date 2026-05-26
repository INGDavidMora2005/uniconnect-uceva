# uniconnect_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Variables de entorno requeridas

La app requiere `GEMINI_API_KEY` y `SHARED_PHONE_KEY` para funcionar correctamente
(el asistente UniBot y recomendaciones de IA fallan sin la primera; el cifrado de
teléfonos falla sin la segunda).

Estas variables se pasan vía `--dart-define` al correr o compilar (el proyecto NO usa
`flutter_dotenv`):

```bash
flutter run \
  --dart-define=GEMINI_API_KEY=REEMPLAZAR_CON_TU_GEMINI_API_KEY \
  --dart-define=SHARED_PHONE_KEY=REEMPLAZAR_CON_CLAVE_AES_256_DE_32_CARACTERES
```

Para obtener `GEMINI_API_KEY`:
- Ve a https://aistudio.google.com/app/apikey
- Crea la key y restríngela en Google Cloud Console al package `com.uceva.uniconnect_app`.

En VS Code, edita los valores en `.vscode/launch.json` (ya commiteado con placeholders)
y usa las configuraciones "UniConnect (debug)" etc. para lanzar sin escribir los defines
cada vez.
