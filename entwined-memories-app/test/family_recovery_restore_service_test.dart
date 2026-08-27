import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:entwined_memories/services/family_recovery_restore_service.dart';

void main() {
  Map<String, Object?> memory({
    required String id,
    required String dateUtc,
    String note = 'A family note',
  }) =>
      <String, Object?>{
        'id': id,
        'dateLocal': dateUtc.substring(0, 10),
        'dateUtc': dateUtc,
        'note': note,
        'mood': '😊',
        'createdBy': 'Dad',
        'photos': <Object?>[
          <String, Object?>{
            'thumbnailUrl': 'https://example.test/thumb.webp',
            'imageUrl': 'https://example.test/full.webp',
            'displayMediaKey': 'display/key',
            'mediaProviderVersion': 1,
            'imagePublicId': 'public-id',
          },
        ],
        'video': null,
      };

  String catalog(List<Map<String, Object?>> memories) => jsonEncode(
        <String, Object?>{
          'schemaVersion': 1,
          'kind': 'active-memory-catalog',
          'generatedAtUtc': '2026-08-27T00:00:00.000Z',
          'memories': memories,
        },
      );

  test('builds a date-sorted, read-only restore preview from a valid catalog',
      () {
    final preview = FamilyRecoveryRestoreService.previewFromCatalogJson(
      catalog(<Map<String, Object?>>[
        memory(id: 'older', dateUtc: '2024-01-01T00:00:00.000Z'),
        memory(id: 'newer', dateUtc: '2025-02-03T00:00:00.000Z'),
      ]),
    );

    expect(preview.memoryCount, 2);
    expect(preview.memories.first.id, 'newer');
    expect(preview.memories.first.photos, hasLength(1));
    expect(preview.earliestDate, DateTime.utc(2024, 1, 1));
    expect(preview.latestDate, DateTime.utc(2025, 2, 3));
  });

  test('rejects a catalog with duplicate stable post IDs', () {
    expect(
      () => FamilyRecoveryRestoreService.previewFromCatalogJson(
        catalog(<Map<String, Object?>>[
          memory(id: 'same-id', dateUtc: '2024-01-01T00:00:00.000Z'),
          memory(id: 'same-id', dateUtc: '2024-02-01T00:00:00.000Z'),
        ]),
      ),
      throwsFormatException,
    );
  });

  test('rejects a catalog post with no parseable timeline date', () {
    expect(
      () => FamilyRecoveryRestoreService.previewFromCatalogJson(
        catalog(<Map<String, Object?>>[
          memory(id: 'bad-date', dateUtc: 'not-a-date'),
        ]),
      ),
      throwsFormatException,
    );
  });
}
