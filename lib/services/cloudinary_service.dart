import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class CloudinaryUploadException implements Exception {
  final String message;

  CloudinaryUploadException(this.message);

  @override
  String toString() => 'CloudinaryUploadException: $message';
}

class CloudinaryService {
  static const String _cloudName = 'dzey2lhu5';
  static const String _uploadPreset = 'uceva_unsigned';
  static const int _maxRetries = 2;
  static const int _timeoutSeconds = 30;

  static Future<String> uploadImage(File imageFile) async {
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final uri = Uri.parse(
          'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
        );

        final request = http.MultipartRequest('POST', uri);
        request.fields['upload_preset'] = _uploadPreset;

        final fileStream = http.ByteStream(imageFile.openRead());
        final fileLength = await imageFile.length();
        request.files.add(http.MultipartFile(
          'file',
          fileStream,
          fileLength,
          filename: 'upload.jpg',
        ));

        final response = await request.send()
            .timeout(const Duration(seconds: _timeoutSeconds));
        final responseData = await response.stream.bytesToString();
        final jsonResponse = json.decode(responseData);

        if (response.statusCode == 200 && jsonResponse['secure_url'] != null) {
          return jsonResponse['secure_url'];
        } else {
          throw CloudinaryUploadException(
            jsonResponse['error']?['message'] ?? 'Error desconocido en Cloudinary',
          );
        }
      } on TimeoutException catch (_) {
        if (attempt == _maxRetries - 1) {
          await FirebaseCrashlytics.instance.recordError(
            'TimeoutException',
            StackTrace.current,
            reason: 'Cloudinary upload failed after $_maxRetries retries',
            fatal: false,
          );
          throw CloudinaryUploadException(
            'La subida tardó demasiado. Verifica tu conexión.',
          );
        }
      } on SocketException catch (_) {
        if (attempt == _maxRetries - 1) {
          await FirebaseCrashlytics.instance.recordError(
            'SocketException',
            StackTrace.current,
            reason: 'Cloudinary upload failed after $_maxRetries retries',
            fatal: false,
          );
          throw CloudinaryUploadException(
            'Sin conexión a internet. Revisa tu red.',
          );
        }
      } on CloudinaryUploadException catch (e) {
        if (attempt == _maxRetries - 1) {
          await FirebaseCrashlytics.instance.recordError(
            e,
            StackTrace.current,
            reason: 'Cloudinary upload failed after $_maxRetries retries',
            fatal: false,
          );
          rethrow;
        }
      } catch (e) {
        if (attempt == _maxRetries - 1) {
          await FirebaseCrashlytics.instance.recordError(
            e,
            StackTrace.current,
            reason: 'Cloudinary upload failed after $_maxRetries retries',
            fatal: false,
          );
          throw CloudinaryUploadException(
            'Error inesperado al subir la imagen. Intenta de nuevo.',
          );
        }
      }
    }
    throw CloudinaryUploadException('Error inesperado al subir la imagen.');
  }
}