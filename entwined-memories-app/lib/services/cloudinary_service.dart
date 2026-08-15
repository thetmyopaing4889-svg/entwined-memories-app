import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class CloudinaryImageUpload {
  final String secureUrl;
  final String publicId;

  const CloudinaryImageUpload({
    required this.secureUrl,
    required this.publicId,
  });
}

class CloudinaryService {
  static const String _cloudName = 'txnn5lsu';
  static const String _uploadPreset = 'Entwined Memories App';

  /// Preserves the existing profile-image API for callers that need only the
  /// display URL. Memory uploads should use [uploadMemoryImage] so their
  /// server-side deletion can target an exact Cloudinary public ID.
  static Future<String> uploadImage(File imageFile) async {
    final upload = await _upload(imageFile);
    return upload.secureUrl;
  }

  static Future<CloudinaryImageUpload> uploadMemoryImage(
      File imageFile) async {
    return _upload(imageFile);
  }

  static Future<CloudinaryImageUpload> _upload(File imageFile) async {
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
      final secureUrl = data['secure_url'];
      final publicId = data['public_id'];
      if (secureUrl is String && secureUrl.isNotEmpty &&
          publicId is String && publicId.isNotEmpty) {
        return CloudinaryImageUpload(
          secureUrl: secureUrl,
          publicId: publicId,
        );
      }
      throw Exception('Cloudinary upload response မှာ media ID မပါဘူး');
    }

    throw Exception('Cloudinary upload မအောင်မြင်ဘူး: ${response.body}');
  }
}
