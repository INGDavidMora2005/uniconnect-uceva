import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

class CloudinaryService {
  static const String cloudName = 'dzey2lhu5';
  static const String apiKey = '929192931653823';
  static const String apiSecret = 'Y7DN1TMOhvivCKBQ_5zL3AvK3fk';
  static const String uploadUrl =
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

  static Future<String> uploadImage(File imageFile) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final signature = _generateSignature(timestamp);

      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      request.fields['api_key'] = apiKey;
      request.fields['timestamp'] = timestamp.toString();
      request.fields['signature'] = signature;

      final fileStream = http.ByteStream(imageFile.openRead());
      final fileLength = await imageFile.length();
      final multipartFile = http.MultipartFile(
        'file',
        fileStream,
        fileLength,
        filename: 'upload.jpg',
      );
      request.files.add(multipartFile);

      final response = await request.send();
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

  static String _generateSignature(int timestamp) {
    final signatureString = 'timestamp=$timestamp$apiSecret';
    final bytes = utf8.encode(signatureString);
    final digest = sha1.convert(bytes);
    return digest.toString();
  }
}
