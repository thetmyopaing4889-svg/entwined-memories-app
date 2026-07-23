import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class YouTubeUploadResult {
  final String videoId;
  final String processingStatus;

  const YouTubeUploadResult({
    required this.videoId,
    required this.processingStatus,
  });
}

class YouTubeWorkerException implements Exception {
  final int statusCode;
  final String message;

  const YouTubeWorkerException({
    required this.statusCode,
    required this.message,
  });

  @override
  String toString() => 'YouTube Worker error ($statusCode): $message';
}

class YouTubeService {
  static const String _workerUrl =
      'https://entwined-memories.thetmyopaing4889.workers.dev';
  static const String _uploadPrivacyStatus = 'unlisted';
  static const bool _uploadEmbeddable = true;

  static String getThumbnailUrl(String videoId) {
    final url = 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
    debugPrint('[YouTubeService] getThumbnailUrl videoId="$videoId" -> $url');
    return url;
  }

  static String getWatchUrl(String videoId) {
    final url = 'https://www.youtube.com/watch?v=$videoId';
    debugPrint('[YouTubeService] getWatchUrl videoId="$videoId" -> $url');
    return url;
  }

  static Map<String, dynamic> _decodeObject(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // The caller turns this into a safe, user-facing API error.
    }
    return const <String, dynamic>{};
  }

  static String _apiErrorMessage(Map<String, dynamic> data) {
    final errorDescription = data['error_description'];
    if (errorDescription is String && errorDescription.trim().isNotEmpty) {
      return errorDescription;
    }

    final error = data['error'];
    if (error is String && error.trim().isNotEmpty) return error;

    final detail = data['detail'];
    if (detail is Map<String, dynamic>) {
      final description = detail['error_description'];
      if (description is String && description.trim().isNotEmpty) {
        return description;
      }
      final detailError = detail['error'];
      if (detailError is String && detailError.trim().isNotEmpty) {
        return detailError;
      }
    }

    return 'Unexpected response from the YouTube Worker';
  }

  static String _mimeTypeForVideo(File file, String? suppliedMimeType) {
    final supplied = suppliedMimeType?.trim().toLowerCase();
    if (supplied != null && supplied.isNotEmpty) {
      if (!supplied.startsWith('video/')) {
        throw ArgumentError('Selected file is not a supported video type');
      }
      return supplied;
    }

    final path = file.path.toLowerCase();
    final dot = path.lastIndexOf('.');
    final extension = dot == -1 ? '' : path.substring(dot + 1);
    const byExtension = <String, String>{
      'mp4': 'video/mp4',
      'm4v': 'video/x-m4v',
      'mov': 'video/quicktime',
      'webm': 'video/webm',
      'mkv': 'video/x-matroska',
      'avi': 'video/x-msvideo',
      '3gp': 'video/3gpp',
      'mpeg': 'video/mpeg',
      'mpg': 'video/mpeg',
      'flv': 'video/x-flv',
    };
    final detected = byExtension[extension];
    if (detected == null) {
      throw ArgumentError(
          'Video format မသိရသေးဘူး။ MP4, MOV, M4V, WebM, MKV, AVI, '
          '3GP, MPEG, ဒါမှမဟုတ် FLV ဖိုင်ကို ရွေးပါ။');
    }
    return detected;
  }

  static String _processingStatusFromUpload(
      Map<String, dynamic> responseData) {
    final direct = responseData['processingStatus'];
    if (direct is String && direct.trim().isNotEmpty) return direct;

    final details = responseData['processingDetails'];
    if (details is Map<String, dynamic>) {
      final status = details['processingStatus'];
      if (status is String && status == 'succeeded') return 'ready';
      if (status is String && status == 'failed') return 'failed';
    }

    // YouTube accepts the upload before its transcoding work is complete.
    return 'processing';
  }

  static Future<String> _getAccessToken() async {
    final response = await http
        .post(Uri.parse('$_workerUrl/token'))
        .timeout(const Duration(seconds: 20));

    final data = _decodeObject(response.body);
    if (response.statusCode != 200) {
      throw YouTubeWorkerException(
        statusCode: response.statusCode,
        message: _apiErrorMessage(data),
      );
    }

    final accessToken = data['access_token'];
    if (accessToken is! String || accessToken.trim().isEmpty) {
      throw const YouTubeWorkerException(
        statusCode: 502,
        message: 'Worker က valid access token မပြန်ပေးဘူး',
      );
    }
    return accessToken;
  }

  /// Ask the Worker for YouTube's current processing state for one video.
  ///
  /// The Worker owns the OAuth refresh token, so the mobile app never needs
  /// to receive or store Google credentials.
  static Future<String> getVideoProcessingStatus(String videoId) async {
    final normalizedVideoId = videoId.trim();
    if (!RegExp(r'^[A-Za-z0-9_-]{6,20}$').hasMatch(normalizedVideoId)) {
      throw const YouTubeWorkerException(
        statusCode: 400,
        message: 'YouTube video ID မမှန်ဘူး',
      );
    }

    final response = await http
        .post(
          Uri.parse('$_workerUrl/video-status'),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'videoId': normalizedVideoId}),
        )
        .timeout(const Duration(seconds: 20));

    final data = _decodeObject(response.body);
    if (response.statusCode != 200) {
      throw YouTubeWorkerException(
        statusCode: response.statusCode,
        message: _apiErrorMessage(data),
      );
    }

    final status = data['processingStatus'];
    if (status is! String ||
        !const {'succeeded', 'processing', 'failed'}.contains(status)) {
      throw const YouTubeWorkerException(
        statusCode: 502,
        message: 'Worker က video processing status မမှန်ဘူး',
      );
    }
    return status;
  }

  /// Upload video to YouTube (unlisted). Returns the video ID and its initial
  /// processing state. A successful upload normally starts as `processing`;
  /// YouTube may need additional time before playback is available.
  ///
  /// [onProgress] is called with a 0.0-1.0 fraction as bytes are sent, so the
  /// UI can show a real percentage instead of a spinner that looks stuck.
  /// [isCancelled] is polled between chunks; if it returns true the upload
  /// is aborted and a [YouTubeUploadCancelled] exception is thrown.
  static Future<YouTubeUploadResult> uploadVideo({
    required File videoFile,
    required String title,
    required String description,
    String? mimeType,
    void Function(double progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final accessToken = await _getAccessToken();
    final fileSize = await videoFile.length();
    final detectedMimeType = _mimeTypeForVideo(videoFile, mimeType);

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
            'X-Upload-Content-Type': detectedMimeType,
            'X-Upload-Content-Length': fileSize.toString(),
          },
          body: jsonEncode({
            'snippet': {
              'title': title,
              'description': description,
              'categoryId': '22',
            },
            'status': {
              // Keep memory videos playable inside the app's YouTube embed.
              'privacyStatus': _uploadPrivacyStatus,
              'embeddable': _uploadEmbeddable,
            },
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
      'Content-Type': detectedMimeType,
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
      final data = _decodeObject(uploadResponse.body);
      final videoId = data['id'];
      if (videoId is! String || videoId.trim().isEmpty) {
        throw const YouTubeWorkerException(
          statusCode: 502,
          message: 'YouTube upload response မှာ video ID မပါဘူး',
        );
      }
      return YouTubeUploadResult(
        videoId: videoId,
        processingStatus: _processingStatusFromUpload(data),
      );
    }

    final data = _decodeObject(uploadResponse.body);
    throw YouTubeWorkerException(
      statusCode: uploadResponse.statusCode,
      message: _apiErrorMessage(data),
    );
  }
}

/// Thrown when the caller cancels an in-progress YouTube upload.
class YouTubeUploadCancelled implements Exception {
  @override
  String toString() => 'Upload ကို ပယ်ဖျက်လိုက်ပါတယ်';
}
