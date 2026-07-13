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
  ///
  /// [onProgress] is called with a 0.0-1.0 fraction as bytes are sent, so the
  /// UI can show a real percentage instead of a spinner that looks stuck.
  /// [isCancelled] is polled between chunks; if it returns true the upload
  /// is aborted and a [YouTubeUploadCancelled] exception is thrown.
  static Future<String> uploadVideo({
    required File videoFile,
    required String title,
    required String description,
    void Function(double progress)? onProgress,
    bool Function()? isCancelled,
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
            'status': {'privacyStatus': 'unlisted'},
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (initResponse.statusCode != 200) {
      throw Exception(
          'Upload session မတည်ဆောက်နိုင်ဘူး: ${initResponse.body}');
    }

    final uploadUrl = initResponse.headers['location'];
    if (uploadUrl == null) throw Exception('Upload URL မရဘူး');

    // Step 2: Stream the video bytes so we can report real progress and
    // allow cancellation instead of blocking on one giant PUT body.
    final request = http.StreamedRequest('PUT', Uri.parse(uploadUrl));
    request.headers.addAll({
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'video/mp4',
      'Content-Length': fileSize.toString(),
    });

    var sent = 0;
    final fileStream = videoFile.openRead();
    final subscription = fileStream.listen(
      null,
      onError: (e) => request.sink.addError(e),
      onDone: () => request.sink.close(),
      cancelOnError: true,
    );
    subscription.onData((chunk) {
      if (isCancelled?.call() ?? false) {
        subscription.cancel();
        request.sink.addError(YouTubeUploadCancelled());
        return;
      }
      request.sink.add(chunk);
      sent += chunk.length;
      if (fileSize > 0) onProgress?.call(sent / fileSize);
    });

    final streamedResponse =
        await request.send().timeout(const Duration(minutes: 30));
    final uploadResponse = await http.Response.fromStream(streamedResponse);

    if (uploadResponse.statusCode == 200 ||
        uploadResponse.statusCode == 201) {
      onProgress?.call(1.0);
      final data =
          jsonDecode(uploadResponse.body) as Map<String, dynamic>;
      return data['id'] as String;
    }

    throw Exception('Video upload မအောင်မြင်ဘူး: ${uploadResponse.body}');
  }
}

/// Thrown when the caller cancels an in-progress YouTube upload.
class YouTubeUploadCancelled implements Exception {
  @override
  String toString() => 'Upload ကို ပယ်ဖျက်လိုက်ပါတယ်';
}
