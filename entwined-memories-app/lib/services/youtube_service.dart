import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

enum YouTubeUploadStage {
  uploading,
  finalizing,
  recovering,
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

class _UploadSessionStatus {
  final int nextByte;
  final YouTubeUploadResult? completedResult;

  const _UploadSessionStatus({
    required this.nextByte,
    this.completedResult,
  });
}

class _RecoverableUploadFailure implements Exception {
  final String message;

  const _RecoverableUploadFailure(this.message);
}

class YouTubeService {
  static const String _workerUrl =
      'https://entwined-memories.thetmyopaing4889.workers.dev';
  static const String _uploadPrivacyStatus = 'unlisted';
  static const bool _uploadEmbeddable = true;

  // YouTube requires non-final resumable chunks to be multiples of 256 KiB.
  // 1 MiB balances mobile reliability with low request overhead.
  static const int _uploadChunkBytes = 1024 * 1024;
  static const int _maxConsecutiveRecoveryAttempts = 3;
  static const Duration _chunkRequestTimeout = Duration(seconds: 90);
  static const Duration _statusRequestTimeout = Duration(seconds: 30);

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
        '3GP, MPEG, ဒါမှမဟုတ် FLV ဖိုင်ကို ရွေးပါ။',
      );
    }
    return detected;
  }

  static String _processingStatusFromUpload(Map<String, dynamic> responseData) {
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

  static Future<Uri> _startUploadSession({
    required String accessToken,
    required int fileSize,
    required String mimeType,
    required String title,
    required String description,
  }) async {
    final initResponse = await http
        .post(
          Uri.parse(
            'https://www.googleapis.com/upload/youtube/v3/videos'
            '?uploadType=resumable&part=snippet,status',
          ),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json; charset=UTF-8',
            'X-Upload-Content-Type': mimeType,
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
      throw YouTubeWorkerException(
        statusCode: initResponse.statusCode,
        message: 'Upload session မတည်ဆောက်နိုင်ဘူး: ${initResponse.body}',
      );
    }

    final location = initResponse.headers['location'];
    if (location == null || location.isEmpty) {
      throw const YouTubeWorkerException(
        statusCode: 502,
        message: 'YouTube က upload session URL မပြန်ပေးဘူး',
      );
    }
    return Uri.parse(location);
  }

  static Future<List<int>> _readFileRange(
    File file,
    int start,
    int endExclusive,
  ) async {
    final handle = await file.open(mode: FileMode.read);
    try {
      await handle.setPosition(start);
      final bytes = await handle.read(endExclusive - start);
      if (bytes.length != endExclusive - start) {
        throw StateError('Video ဖိုင်ကိုအပြည့်အစုံ မဖတ်နိုင်တော့ဘူး။');
      }
      return bytes;
    } finally {
      await handle.close();
    }
  }

  static Future<http.Response> _putToUploadSession({
    required Uri uploadUrl,
    required String accessToken,
    required Map<String, String> headers,
    List<int>? body,
    required Duration timeout,
  }) async {
    final request = http.StreamedRequest('PUT', uploadUrl);
    request.headers.addAll({
      'Authorization': 'Bearer $accessToken',
      ...headers,
    });
    if (body != null && body.isNotEmpty) request.sink.add(body);
    await request.sink.close();

    final streamedResponse = await request.send().timeout(timeout);
    return http.Response.fromStream(streamedResponse);
  }

  static YouTubeUploadResult _resultFromCompletedResponse(http.Response response) {
    final data = _decodeObject(response.body);
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

  static int _nextByteFromRange(String? rangeHeader, int fileSize) {
    if (rangeHeader == null || rangeHeader.trim().isEmpty) return 0;
    final match = RegExp(r'(?:bytes=)?\s*\d+-(\d+)').firstMatch(rangeHeader);
    if (match == null) {
      throw const YouTubeWorkerException(
        statusCode: 502,
        message: 'YouTube upload status range မမှန်ဘူး',
      );
    }
    final lastByte = int.tryParse(match.group(1)!);
    if (lastByte == null || lastByte < 0 || lastByte >= fileSize) {
      throw const YouTubeWorkerException(
        statusCode: 502,
        message: 'YouTube upload status range မမှန်ဘူး',
      );
    }
    return lastByte + 1;
  }

  static Future<_UploadSessionStatus> _checkUploadSession({
    required Uri uploadUrl,
    required String accessToken,
    required int fileSize,
  }) async {
    final response = await _putToUploadSession(
      uploadUrl: uploadUrl,
      accessToken: accessToken,
      headers: {
        'Content-Length': '0',
        'Content-Range': 'bytes */$fileSize',
      },
      timeout: _statusRequestTimeout,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return _UploadSessionStatus(
        nextByte: fileSize,
        completedResult: _resultFromCompletedResponse(response),
      );
    }
    if (response.statusCode == 308) {
      return _UploadSessionStatus(
        nextByte: _nextByteFromRange(response.headers['range'], fileSize),
      );
    }

    final data = _decodeObject(response.body);
    throw YouTubeWorkerException(
      statusCode: response.statusCode,
      message: _apiErrorMessage(data),
    );
  }

  static Future<_UploadSessionStatus> _recoverUploadSession({
    required Uri uploadUrl,
    required String accessToken,
    required int fileSize,
    required int recoveryAttempt,
  }) async {
    if (recoveryAttempt > 1) {
      await Future<void>.delayed(Duration(seconds: recoveryAttempt * 2));
    }
    return _checkUploadSession(
      uploadUrl: uploadUrl,
      accessToken: accessToken,
      fileSize: fileSize,
    );
  }

  /// Upload video to YouTube (unlisted) using server-confirmed resumable chunks.
  ///
  /// Progress advances only after YouTube acknowledges each chunk, so `100%`
  /// means that YouTube returned the final video resource rather than merely
  /// that Android finished reading the local source file.
  static Future<YouTubeUploadResult> uploadVideo({
    required File videoFile,
    required String title,
    required String description,
    String? mimeType,
    void Function(double progress)? onProgress,
    void Function(YouTubeUploadStage stage)? onStage,
    bool Function()? isCancelled,
  }) async {
    final accessToken = await _getAccessToken();
    final fileSize = await videoFile.length();
    if (fileSize <= 0) {
      throw StateError('ရွေးထားတဲ့ Video file ကဗလာဖြစ်နေတယ်။');
    }
    final detectedMimeType = _mimeTypeForVideo(videoFile, mimeType);
    final uploadUrl = await _startUploadSession(
      accessToken: accessToken,
      fileSize: fileSize,
      mimeType: detectedMimeType,
      title: title,
      description: description,
    );

    onStage?.call(YouTubeUploadStage.uploading);
    onProgress?.call(0);

    var nextByte = 0;
    var recoveryAttempts = 0;

    while (nextByte < fileSize) {
      if (isCancelled?.call() ?? false) throw YouTubeUploadCancelled();

      final endExclusive = nextByte + _uploadChunkBytes > fileSize
          ? fileSize
          : nextByte + _uploadChunkBytes;
      final isFinalChunk = endExclusive == fileSize;
      if (isFinalChunk) onStage?.call(YouTubeUploadStage.finalizing);

      try {
        final bytes = await _readFileRange(videoFile, nextByte, endExclusive);
        final response = await _putToUploadSession(
          uploadUrl: uploadUrl,
          accessToken: accessToken,
          headers: {
            'Content-Type': detectedMimeType,
            'Content-Length': bytes.length.toString(),
            'Content-Range':
                'bytes $nextByte-${endExclusive - 1}/$fileSize',
          },
          body: bytes,
          timeout: _chunkRequestTimeout,
        );

        if (isCancelled?.call() ?? false) throw YouTubeUploadCancelled();

        if (response.statusCode == 200 || response.statusCode == 201) {
          final result = _resultFromCompletedResponse(response);
          onProgress?.call(1.0);
          return result;
        }
        if (response.statusCode == 308) {
          final acknowledgedByte =
              _nextByteFromRange(response.headers['range'], fileSize);
          if (acknowledgedByte <= nextByte) {
            throw const _RecoverableUploadFailure(
              'YouTube did not acknowledge the current video chunk',
            );
          }
          nextByte = acknowledgedByte;
          recoveryAttempts = 0;
          onProgress?.call(nextByte / fileSize);
          continue;
        }
        if (response.statusCode >= 500) {
          throw _RecoverableUploadFailure(
            'YouTube temporary error ${response.statusCode}',
          );
        }

        final data = _decodeObject(response.body);
        throw YouTubeWorkerException(
          statusCode: response.statusCode,
          message: _apiErrorMessage(data),
        );
      } on YouTubeUploadCancelled {
        rethrow;
      } on YouTubeWorkerException {
        rethrow;
      } on _RecoverableUploadFailure {
        // Ask YouTube which bytes it accepted before retrying. This prevents a
        // mobile interruption from forcing a complete re-upload.
      } on TimeoutException {
        // The status check below determines whether the timed-out chunk landed.
      } on SocketException {
        // The status check below determines whether the interrupted chunk landed.
      } on http.ClientException {
        // The status check below determines whether the interrupted chunk landed.
      }

      if (isCancelled?.call() ?? false) throw YouTubeUploadCancelled();
      recoveryAttempts += 1;
      if (recoveryAttempts > _maxConsecutiveRecoveryAttempts) {
        throw const YouTubeWorkerException(
          statusCode: 504,
          message:
              'Network မတည်ငြိမ်လို့ Video upload ကိုပြန်ဆက်မရတော့ဘူး။ Wi-Fi/connection စစ်ပြီးပြန်တင်ပါ။',
        );
      }

      onStage?.call(YouTubeUploadStage.recovering);
      try {
        final session = await _recoverUploadSession(
          uploadUrl: uploadUrl,
          accessToken: accessToken,
          fileSize: fileSize,
          recoveryAttempt: recoveryAttempts,
        );
        if (session.completedResult != null) {
          onProgress?.call(1.0);
          return session.completedResult!;
        }
        nextByte = session.nextByte;
        onProgress?.call(nextByte / fileSize);
        onStage?.call(YouTubeUploadStage.uploading);
      } on YouTubeUploadCancelled {
        rethrow;
      } catch (_) {
        if (recoveryAttempts >= _maxConsecutiveRecoveryAttempts) {
          throw const YouTubeWorkerException(
            statusCode: 504,
            message:
                'Network မတည်ငြိမ်လို့ Video upload ကိုပြန်ဆက်မရတော့ဘူး။ Wi-Fi/connection စစ်ပြီးပြန်တင်ပါ။',
          );
        }
      }
    }

    throw const YouTubeWorkerException(
      statusCode: 502,
      message: 'YouTube က Video upload completion ကိုအတည်မပြုနိုင်သေးဘူး',
    );
  }
}

/// Thrown when the caller cancels an in-progress YouTube upload.
class YouTubeUploadCancelled implements Exception {
  @override
  String toString() => 'Upload ကို ပယ်ဖျက်လိုက်ပါတယ်';
}
