import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class DisplayMediaUpload {
  final String key;
  final int size;

  const DisplayMediaUpload({required this.key, required this.size});
}

class DisplayMediaRequest {
  final String url;
  final Map<String, String> headers;

  const DisplayMediaRequest({required this.url, required this.headers});
}

/// Accesses the private R2 display-copy endpoints through the family-authenticated
/// Cloudflare Worker. R2 credentials never enter the mobile application.
class DisplayMediaService {
  static const _workerBaseUrl =
      'https://entwined-memories.thetmyopaing4889.workers.dev';
  // Version the app-side cache key after correcting the Worker response from
  // erroneous partial content (HTTP 206) to full-image HTTP 200 responses.
  static const _displayCacheVersion = '2';

  static Future<DisplayMediaUpload> uploadDisplayWebp(File displayFile) async {
    if (!await displayFile.exists()) {
      throw StateError('R2 တင်မယ့် display photo file မတွေ့ဘူး');
    }

    final response = await http
        .post(
          Uri.parse('$_workerBaseUrl/media/display-upload'),
          headers: await _authorizedHeaders(contentType: 'image/webp'),
          body: await displayFile.readAsBytes(),
        )
        .timeout(const Duration(minutes: 2));

    final data = _decodeResponse(response);
    if (response.statusCode != 201) {
      throw StateError(
          _responseMessage(data, 'R2 display photo တင်မအောင်မြင်ဘူး'));
    }

    final key = data['key'];
    final size = data['size'];
    if (key is! String || key.isEmpty || size is! num) {
      throw StateError('R2 upload response မှာ display media key မပါဘူး');
    }
    return DisplayMediaUpload(key: key, size: size.toInt());
  }

  static Future<DisplayMediaRequest> authorizedDisplayRequest(
      String key) async {
    if (!RegExp(r'^display/[0-9a-f-]{36}\.webp$', caseSensitive: false)
        .hasMatch(key)) {
      throw ArgumentError.value(key, 'key', 'Invalid display media key');
    }

    return DisplayMediaRequest(
      url:
          '$_workerBaseUrl/media/display/${Uri.encodeComponent(key)}?cacheVersion=$_displayCacheVersion',
      headers: await _authorizedHeaders(),
    );
  }

  static Future<Map<String, String>> _authorizedHeaders({
    String? contentType,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError(
          'R2 media အတွက် shared family account နဲ့ login ဝင်ရမယ်');
    }

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw StateError('R2 media အတွက် login token မရသေးဘူး');
    }

    return {
      'Authorization': 'Bearer $idToken',
      if (contentType != null) 'Content-Type': contentType,
    };
  }

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    try {
      final value = jsonDecode(response.body);
      return value is Map<String, dynamic> ? value : const {};
    } catch (_) {
      return const {};
    }
  }

  static String _responseMessage(Map<String, dynamic> data, String fallback) {
    final message = data['error_description'] ?? data['error'];
    return message is String && message.isNotEmpty ? message : fallback;
  }
}
