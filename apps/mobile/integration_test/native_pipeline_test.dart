import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lingoscribe/application/app_controller.dart';
import 'package:lingoscribe/domain/transcript.dart';
import 'package:path/path.dart' as p;

// Inject test media into this test installation's private files/qa directory.
// Fixtures are not bundled into the production application and no inference is mocked.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native decoding, verified model import, isolate inference and persisted transcript',
    (tester) async {
      final app = await AppController.create();
      try {
        final qa = p.join(p.dirname(app.root.path), 'qa');
        final audio = File(p.join(qa, 'sample.wav'));
        final model = File(p.join(qa, 'ggml-base-q5_1.bin'));
        expect(
          await audio.exists(),
          true,
          reason:
              'Install licensed test audio in the private qa directory first',
        );
        expect(
          await model.exists(),
          true,
          reason:
              'Install the verified official model in the private qa directory first',
        );
        await app.models.importFile(model.path);
        expect(app.models.active?.id, 'base-q5');
        final folder = Directory(p.join(app.root.path, 'audio'));
        await folder.create(recursive: true);
        final imported = await audio.copy(p.join(folder.path, 'native-qa.wav'));
        final entry = Transcript(
          id: 'native-qa',
          title: 'Native integration test',
          createdAt: DateTime.now(),
          audioPath: imported.path,
        );
        await app.save(entry);
        await app.transcribe(entry);
        final result = await app.find(entry.id);
        expect(result?.status, TranscriptStatus.ready, reason: result?.error);
        expect(result!.segments, isNotEmpty);
        expect(result.durationMs, greaterThan(1000));
        expect(result.plainText.toLowerCase(), contains('country'));
        expect(
          result.segments.last.endMs,
          lessThanOrEqualTo(result.durationMs),
        );
        final normalized = File(
          p.join(folder.path, 'native-qa.normalized.wav'),
        );
        expect(await normalized.length(), greaterThan(44));
        final segments = List<Segment>.of(result.segments);
        segments[0] = segments[0].edit('测试校对').toggleBookmark();
        await app.save(result.copyWith(segments: segments));
        final edited = await app.find(entry.id);
        expect(edited!.segments.first.originalText, result.segments.first.text);
        expect(edited.segments.first.bookmarked, true);
      } finally {
        await app.recorder.dispose();
        await app.repository.close();
        app.models.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
