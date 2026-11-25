import 'package:aule/core/api/fake/demo_data.dart';
import 'package:aule/core/api/models/models.dart';
import 'package:aule/features/privacy/delete_account_screen.dart';
import 'package:aule/features/privacy/memories_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/harness.dart';

void main() {
  test('the typed email matches trimmed and in any case', () {
    expect(confirmEmailMatches(' ANA@example.com ', 'ana@example.com'), isTrue);
    expect(confirmEmailMatches('ana@example.org', 'ana@example.com'), isFalse);
    expect(confirmEmailMatches('', 'ana@example.com'), isFalse);
  });

  group('MemoriesModel', () {
    test('loads what Aule remembers, newest first', () async {
      final model = MemoriesModel(
        api: instantApi(),
        childId: DemoData.childMati,
      );
      await model.load();
      final memories = model.memories!;
      expect(memories, hasLength(4));
      for (var i = 1; i < memories.length; i++) {
        expect(
          memories[i - 1].createdAt.isAfter(memories[i].createdAt),
          isTrue,
        );
      }
    });

    test('forgetting removes one memory on the server and here', () async {
      final api = instantApi();
      final model = MemoriesModel(api: api, childId: DemoData.childMati);
      await model.load();
      final first = model.memories!.first;
      expect(await model.forget(first.id), isTrue);
      expect(
        model.memories!.map((memory) => memory.id),
        isNot(contains(first.id)),
      );
      expect(await api.memories(DemoData.childMati), hasLength(3));
      // Already gone counts as forgotten.
      expect(await model.forget(first.id), isTrue);
    });

    test('withdrawing memory leaves nothing to show', () async {
      final api = instantApi();
      await api.recordConsent(
        DemoData.childMati,
        const ConsentAnswer(
          purpose: ConsentPurpose.memory,
          granted: false,
          policyVersion: 'app-2026-11-v1',
          locale: 'es-PE',
        ),
      );
      final model = MemoriesModel(api: api, childId: DemoData.childMati);
      await model.load();
      expect(model.memories, isEmpty);
    });
  });
}
