import 'package:flutter_test/flutter_test.dart';
import 'package:entwined_memories/models/memory.dart';
import 'package:entwined_memories/models/child_profile.dart';
import 'package:entwined_memories/utils/memory_stats.dart';

void main() {
  group('memory model used by detail and playback flows', () {
    test('recognises photo and ready video media', () {
      final photo = Memory(
        id: 'photo',
        note: 'First smile',
        date: DateTime(2026, 1, 2),
        createdBy: 'Mom',
        mood: '😊',
        imageUrl: 'https://example.com/photo.jpg',
      );
      final video = Memory(
        id: 'video',
        note: 'First steps',
        date: DateTime(2026, 1, 3),
        createdBy: 'Dad',
        mood: '🥹',
        videoId: 'video-id',
        processingStatus: 'ready',
      );
      final processing = Memory(
        id: 'processing',
        note: 'Uploading',
        date: DateTime(2026, 1, 4),
        createdBy: 'Dad',
        mood: '💗',
        videoId: 'video-id-2',
        processingStatus: 'processing',
      );

      expect(photo.hasImage, isTrue);
      expect(photo.hasVideo, isFalse);
      expect(video.hasVideo, isTrue);
      expect(video.isVideoReady, isTrue);
      expect(processing.hasVideo, isTrue);
      expect(processing.isVideoReady, isFalse);
    });

    test('formats the memory date consistently', () {
      final memory = Memory(
        id: 'date',
        note: 'A quiet day',
        date: DateTime(2026, 8, 9),
        createdBy: 'Mom',
        mood: '🌸',
      );

      expect(memory.formattedDate, 'Aug 9, 2026');
    });
  });

  test('home stats count memories by available media', () {
    final memories = [
      Memory(
        id: '1',
        note: 'Photo',
        date: DateTime(2026, 1, 1),
        createdBy: 'Mom',
        mood: '😊',
        imageUrl: 'https://example.com/1.jpg',
      ),
      Memory(
        id: '2',
        note: 'Video',
        date: DateTime(2026, 1, 2),
        createdBy: 'Dad',
        mood: '🥹',
        videoId: 'video-id',
      ),
      Memory(
        id: '3',
        note: 'Note only',
        date: DateTime(2026, 1, 3),
        createdBy: 'Mom',
        mood: '💗',
      ),
    ];

    final stats = MemoryStats.fromMemories(memories);

    expect(stats.totalMemories, 3);
    expect(stats.photoCount, 1);
    expect(stats.videoCount, 1);
  });

  test('profile beginning fields round-trip through a copy', () {
    const profile = ChildProfile(
      name: 'Mia',
      beginningTitle: 'The day Mia began',
      beginningSubtitle: 'Our smallest, sweetest beginning',
      beginningStory: 'A story written with love.',
      birthPlace: 'Yangon',
      birthWeight: '3.2 kg',
    );
    final edited = profile.copyWith(beginningStory: 'A new first chapter.');

    expect(edited.name, 'Mia');
    expect(edited.beginningTitle, 'The day Mia began');
    expect(edited.beginningSubtitle, 'Our smallest, sweetest beginning');
    expect(edited.beginningStory, 'A new first chapter.');
    expect(edited.birthPlace, 'Yangon');
    expect(edited.birthWeight, '3.2 kg');
  });
}
