import 'package:entwined_memories/models/memory.dart';
import 'package:flutter_test/flutter_test.dart';

Memory _memory({
  String? imageUrl,
  String? thumbnailUrl,
  String? displayMediaKey,
  int? mediaProviderVersion,
}) {
  return Memory(
    id: 'memory-1',
    note: 'A family memory',
    date: DateTime.utc(2026, 8, 18),
    createdBy: 'Dad',
    mood: '😊',
    imageUrl: imageUrl,
    thumbnailUrl: thumbnailUrl,
    displayMediaKey: displayMediaKey,
    mediaProviderVersion: mediaProviderVersion,
  );
}

void main() {
  group('Memory dual-provider fields', () {
    test('legacy Cloudinary-only memory remains a valid image memory', () {
      final memory =
          _memory(imageUrl: 'https://res.cloudinary.com/legacy.webp');

      expect(memory.hasImage, isTrue);
      expect(memory.feedThumbnailUrl, memory.imageUrl);
      expect(memory.hasPrivateDisplay, isFalse);
    });

    test('new memory uses Cloudinary for feed and R2 key for full display', () {
      final memory = _memory(
        imageUrl: 'https://res.cloudinary.com/thumb.webp',
        thumbnailUrl: 'https://res.cloudinary.com/thumb.webp',
        displayMediaKey: 'display/00000000-0000-0000-0000-000000000000.webp',
        mediaProviderVersion: 1,
      );

      expect(memory.hasImage, isTrue);
      expect(memory.feedThumbnailUrl, 'https://res.cloudinary.com/thumb.webp');
      expect(memory.hasPrivateDisplay, isTrue);
      expect(memory.toMap()['displayMediaKey'], memory.displayMediaKey);
      expect(memory.toMap()['mediaProviderVersion'], 1);
    });
  });
}
