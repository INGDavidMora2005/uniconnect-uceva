import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class CloudinaryService {
  // Solo estos dos valores son seguros en el cliente (no son secretos)
  static const String _cloudName = 'dzey2lhu5';
  static const String _uploadPreset = 'uceva_unsigned'; // nombre del preset creado

  static Future<String> uploadImage(File imageFile) async {
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
          .timeout(const Duration(seconds: 30));
      final responseData = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseData);

      if (response.statusCode == 200 && jsonResponse['secure_url'] != null) {
        return jsonResponse['secure_url'];
      } else {
        throw Exception(
          'Error uploading image: ${jsonResponse['error']?['message'] ?? responseData}',
        );
      }
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }
}
