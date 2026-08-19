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

  group('Memory multi-photo gallery fields', () {
    test('gallery memory keeps a cover photo and every cleanup identifier', () {
      const first = MemoryPhoto(
        imageUrl: 'https://res.cloudinary.com/family/one.webp',
        thumbnailUrl: 'https://res.cloudinary.com/family/one.webp',
        displayMediaKey: 'display/11111111-1111-1111-1111-111111111111.webp',
        mediaProviderVersion: 1,
        imagePublicId: 'family/one',
      );
      const second = MemoryPhoto(
        imageUrl: 'https://res.cloudinary.com/family/two.webp',
        thumbnailUrl: 'https://res.cloudinary.com/family/two.webp',
        displayMediaKey: 'display/22222222-2222-2222-2222-222222222222.webp',
        mediaProviderVersion: 1,
        imagePublicId: 'family/two',
      );
      final memory = Memory(
        id: 'gallery-1',
        note: 'A multi-photo family day',
        date: DateTime.utc(2026, 8, 19),
        createdBy: 'Mom',
        mood: '🥰',
        imageUrl: first.imageUrl,
        thumbnailUrl: first.thumbnailUrl,
        displayMediaKey: first.displayMediaKey,
        mediaProviderVersion: first.mediaProviderVersion,
        imagePublicId: first.imagePublicId,
        photos: const [first, second],
      );

      expect(memory.hasImage, isTrue);
      expect(memory.photoCount, 2);
      expect(memory.coverPhoto?.imagePublicId, 'family/one');
      expect(memory.feedThumbnailUrl, first.thumbnailUrl);
      expect(memory.allPhotos.last.displayMediaKey, second.displayMediaKey);
      expect((memory.toMap()['photos'] as List).length, 2);
    });

    test('old one-photo records derive a one-item gallery', () {
      final memory = _memory(
        imageUrl: 'https://res.cloudinary.com/legacy.webp',
        displayMediaKey: 'display/33333333-3333-3333-3333-333333333333.webp',
      );

      expect(memory.photoCount, 1);
      expect(memory.allPhotos.single.imageUrl, memory.imageUrl);
      expect(memory.allPhotos.single.displayMediaKey, memory.displayMediaKey);
    });
  });
}
