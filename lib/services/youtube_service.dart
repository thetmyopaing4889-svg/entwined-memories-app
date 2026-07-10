import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class YouTubeService {
  static const String _workerUrl =
      'https://entwined-memories.thetmyopaing4889.workers.dev';

  static String getThumbnailUrl(String videoId) =>
      'https://img.youtube.com/vi/$videoId/hqdefault.jpg';

  static String getWatchUrl(String videoId) =>
      'https://www.youtube.com/watch?v=$videoId';

  static Future<String> _getAccessToken() async {
    final response = await http
        .post(Uri.parse('$_workerUrl/token'))
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['access_token'] as String;
    }
    throw Exception('Access token မရဘူး: ${response.body}');
  }

  /// Upload video to YouTube (private). Returns YouTube video ID.
  static Future<String> uploadVideo({
    required File videoFile,
    required String title,
    required String description,
  }) async {
    final accessToken = await _getAccessToken();
    final fileSize = await videoFile.length();

    // Step 1: Initialize resumable upload session
    final initResponse = await http
        .post(
          Uri.parse(
            'https://www.googleapis.com/upload/youtube/v3/videos'
            '?uploadType=resumable&part=snippet,status',
          ),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json; charset=UTF-8',
            'X-Upload-Content-Type': 'video/mp4',
            'X-Upload-Content-Length': fileSize.toString(),
          },
          body: jsonEncode({
            'snippet': {
              'title': title,
              'description': description,
              'categoryId': '22',
            },
            'status': {'privacyStatus': 'private'},
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (initResponse.statusCode != 200) {
      throw Exception(
          'Upload session မတည်ဆောက်နိုင်ဘူး: ${initResponse.body}');
    }

    final uploadUrl = initResponse.headers['location'];
    if (uploadUrl == null) throw Exception('Upload URL မရဘူး');

    // Step 2: Upload the actual video bytes
    final videoBytes = await videoFile.readAsBytes();

    final uploadResponse = await http
        .put(
          Uri.parse(uploadUrl),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'video/mp4',
            'Content-Length': fileSize.toString(),
          },
          body: videoBytes,
        )
        .timeout(const Duration(minutes: 15));

    if (uploadResponse.statusCode == 200 ||
        uploadResponse.statusCode == 201) {
      final data =
          jsonDecode(uploadResponse.body) as Map<String, dynamic>;
      return data['id'] as String;
    }

    throw Exception('Video upload မအောင်မြင်ဘူး: ${uploadResponse.body}');
  }
}
