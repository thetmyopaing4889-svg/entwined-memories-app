import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:entwined_memories/models/memory.dart';
import 'package:entwined_memories/services/family_memory_journal_service.dart';
import 'package:entwined_memories/services/original_vault_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('entwined_memories/family_journal');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('requires a selected Documents archive folder', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'ensureArchiveFolderSelected');
          return <String, Object>{'configured': true};
        });

    await FamilyMemoryJournalService.ensureArchiveFolderSelected();
  });

  test(
    'writes portable JSON event with memory and vault hash metadata',
    () async {
      MethodCall? received;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            received = call;
            return <String, Object>{
              'fileName': call.arguments['fileName'] as String,
              'uri': 'content://example/journal-event',
            };
          });

      final memory = Memory(
        id: 'memory-123',
        note: 'First steps',
        date: DateTime(2026, 8, 21),
        createdBy: 'Dad',
        mood: '🥰',
        photos: const [
          MemoryPhoto(
            thumbnailUrl: 'https://thumb.example/photo.webp',
            displayMediaKey:
                'display/00000000-0000-0000-0000-000000000001.webp',
          ),
        ],
      );
      const archive = OriginalVaultArchive(
        uri: 'content://media/external/images/media/42',
        sha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        bytes: 1234,
        alreadyExists: false,
      );

      final fileName = await FamilyMemoryJournalService.appendMemoryEvent(
        eventType: 'memory_created',
        memory: memory,
        vaultArchives: const [archive],
      );

      expect(fileName, startsWith('event_'));
      expect(fileName, endsWith('.json'));
      expect(received?.method, 'appendJournalEvent');

      final arguments = received?.arguments as Map<Object?, Object?>;
      final event =
          jsonDecode(arguments['json'] as String) as Map<String, dynamic>;
      expect(event['schemaVersion'], 1);
      expect(event['eventType'], 'memory_created');
      expect(event['memory']['id'], 'memory-123');
      expect(event['memory']['dateLocal'], '2026-08-21');
      expect(event['memory']['note'], 'First steps');
      expect(event['vaultArchives'][0]['sha256'], archive.sha256);
    },
  );
}
