import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String _cloudName = 'txnn5lsu';
  static const String _uploadPreset = 'Entwined Memories App';

  /// Upload image to Cloudinary. Returns secure HTTPS URL.
  static Future<String> uploadImage(File imageFile) async {
    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload');

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..files
          .add(await http.MultipartFile.fromPath('file', imageFile.path));

    final streamed =
        await request.send().timeout(const Duration(minutes: 3));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['secure_url'] as String;
    }

    throw Exception('Cloudinary upload မအောင်မြင်ဘူး: ${response.body}');
  }
}
