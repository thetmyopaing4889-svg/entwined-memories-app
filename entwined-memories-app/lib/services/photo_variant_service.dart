import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Short-lived, compressed copies made from an original gallery file.
///
/// The original source file is never overwritten or deleted. Call [dispose]
/// after both remote uploads finish (or fail) to clear only these app-cache
/// copies.
class PhotoUploadVariants {
  final File thumbnailFile;
  final File displayFile;

  const PhotoUploadVariants({
    required this.thumbnailFile,
    required this.displayFile,
  });

  Future<void> dispose() async {
    await Future.wait([
      if (await thumbnailFile.exists()) thumbnailFile.delete(),
      if (await displayFile.exists()) displayFile.delete(),
    ]);
  }
}

class PhotoVariantService {
  static const int thumbnailMaxDimension = 640;
  static const int thumbnailTargetBytes = 75 * 1024;
  static const int displayMaxDimension = 1536;
  static const int displayTargetBytes = 250 * 1024;
  static const int _minimumQuality = 40;

  /// Creates two WebP copies while preserving the whole photo's aspect ratio.
  /// No crop is made and GPS/EXIF metadata is deliberately omitted from copies.
  static Future<PhotoUploadVariants> createVariants(File original) async {
    if (!await original.exists()) {
      throw StateError('ရွေးထားသော ဓာတ်ပုံ file မတွေ့တော့ဘူး');
    }

    final dimensions = await _readDimensions(original);
    final temporaryDirectory = await getTemporaryDirectory();
    final variantsDirectory = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}entwined-photo-variants',
    );
    await variantsDirectory.create(recursive: true);

    final id = const Uuid().v4();
    try {
      final thumbnail = await _compressWebp(
        source: original,
        targetPath:
            '${variantsDirectory.path}${Platform.pathSeparator}$id-thumb.webp',
        dimensions: dimensions,
        maxDimension: thumbnailMaxDimension,
        initialQuality: 78,
        targetBytes: thumbnailTargetBytes,
      );
      final display = await _compressWebp(
        source: original,
        targetPath:
            '${variantsDirectory.path}${Platform.pathSeparator}$id-display.webp',
        dimensions: dimensions,
        maxDimension: displayMaxDimension,
        initialQuality: 84,
        targetBytes: displayTargetBytes,
      );

      return PhotoUploadVariants(
        thumbnailFile: thumbnail,
        displayFile: display,
      );
    } catch (_) {
      final thumbnail = File(
        '${variantsDirectory.path}${Platform.pathSeparator}$id-thumb.webp',
      );
      final display = File(
        '${variantsDirectory.path}${Platform.pathSeparator}$id-display.webp',
      );
      await Future.wait([
        if (await thumbnail.exists()) thumbnail.delete(),
        if (await display.exists()) display.delete(),
      ]);
      rethrow;
    }
  }

  static Future<ui.Size> _readDimensions(File source) async {
    final bytes = await source.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final size = ui.Size(image.width.toDouble(), image.height.toDouble());
    image.dispose();
    codec.dispose();
    return size;
  }

  static Future<File> _compressWebp({
    required File source,
    required String targetPath,
    required ui.Size dimensions,
    required int maxDimension,
    required int initialQuality,
    required int targetBytes,
  }) async {
    final targetSize = _targetSize(dimensions, maxDimension);
    var quality = initialQuality;

    while (true) {
      final compressed = await FlutterImageCompress.compressAndGetFile(
        source.absolute.path,
        targetPath,
        minWidth: targetSize.width,
        minHeight: targetSize.height,
        quality: quality,
        format: CompressFormat.webp,
        autoCorrectionAngle: true,
        keepExif: false,
      );
      if (compressed == null) {
        throw StateError('ဓာတ်ပုံကို WebP copy ပြောင်းမရဘူး');
      }

      final output = File(compressed.path);
      if (!await output.exists()) {
        throw StateError('ဓာတ်ပုံ WebP copy file မရခဲ့ဘူး');
      }
      if (await output.length() <= targetBytes || quality <= _minimumQuality) {
        return output;
      }
      quality -= 8;
    }
  }

  static _TargetSize _targetSize(ui.Size source, int maxDimension) {
    if (source.width >= source.height) {
      final height = (maxDimension * source.height / source.width).round();
      return _TargetSize(maxDimension, height.clamp(1, maxDimension).toInt());
    }

    final width = (maxDimension * source.width / source.height).round();
    return _TargetSize(width.clamp(1, maxDimension).toInt(), maxDimension);
  }
}

class _TargetSize {
  final int width;
  final int height;

  const _TargetSize(this.width, this.height);
}
