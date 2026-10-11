import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lingoscribe/application/app_controller.dart';
import 'package:lingoscribe/domain/transcript.dart';
import 'package:lingoscribe/services/model_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'native_service_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final qa = p.join((await getApplicationSupportDirectory()).path, 'qa');
    unawaited(
      binding.allTestsPassed.future.then((passed) async {
        final part = File(p.join(qa, 'test-status.json.part'));
        await part.writeAsString(
          jsonEncode({
            'passed': passed,
            'testCount': 1,
            'failures': binding.failureMethodsDetails
                .map((failure) => failure.toString())
                .toList(),
          }),
          flush: true,
        );
        await part.rename(p.join(qa, 'test-status.json'));
      }),
    );
  });
  nativeTest(
    'Qwen3 real verified bundle, speech detection, native decode and persistence',
    () async {
      final app = await AppController.create();
      try {
        final qa = p.join(p.dirname(app.root.path), 'qa');
        final spec = models.singleWhere((model) => model.engine == 'qwen3');
        final inputs = [
          for (final asset in spec.assets) p.join(qa, 'qwen', asset.path),
        ];
        await app.models.importFiles(inputs);
        app.models.select(spec.id);
        await app.models.verifyActive();
        final folder = Directory(p.join(app.root.path, 'audio'));
        await folder.create(recursive: true);
        final audio = await File(
          p.join(qa, 'sample.wav'),
        ).copy(p.join(folder.path, 'qwen-native-qa.wav'));
        final entry = Transcript(
          id: 'qwen-native-qa',
          title: 'Qwen native integration',
          createdAt: DateTime.now(),
          audioPath: audio.path,
        );
        await app.save(entry);
        final clock = Stopwatch()..start();
        await app.transcribe(entry);
        clock.stop();
        final actual = (await app.find(entry.id))!;
        expect(actual.status, TranscriptStatus.ready, reason: actual.error);
        expect(actual.modelId, spec.id);
        expect(actual.plainText.toLowerCase(), contains('country'));
        expect(actual.segments, isNotEmpty);
        expect(
          actual.segments.last.endMs,
          lessThanOrEqualTo(actual.durationMs),
        );
        final edited = actual.copyWith(
          segments: [
            actual.segments.first.edit('Native edit').toggleBookmark(),
            ...actual.segments.skip(1),
          ],
        );
        await app.save(edited);
        final restored = (await app.find(entry.id))!;
        expect(
          restored.segments.first.originalText,
          actual.segments.first.text,
        );
        expect(restored.segments.first.bookmarked, true);
        final revision = await app.createRevision(restored);
        final cancelTask = app.transcribe(revision);
        app.cancelTranscription();
        await cancelTask;
        expect(
          (await app.find(revision.id))!.status,
          TranscriptStatus.interrupted,
        );
        expect(await File(revision.audioPath).exists(), true);
        final report = {
          'platform': Platform.operatingSystem,
          'engine': 'qwen3',
          'buildMode': 'debug',
          'modelHashes': {
            for (final asset in spec.assets) asset.path: asset.sha256,
          },
          'audioSha256': (await sha256.bind(audio.openRead()).first).toString(),
          'durationMs': actual.durationMs,
          'elapsedSeconds': clock.elapsedMilliseconds / 1000,
          'timestampSource': 'speech_intervals',
          'segments': actual.segments
              .map((segment) => segment.toJson())
              .toList(),
          'checks': [
            'six_file_hash_import',
            'native_normalization',
            'native_vad',
            'isolate_qwen_asr',
            'speech_interval_timestamps',
            'sqlite_edit_bookmark',
            'preparation_cancel_keeps_audio',
          ],
          'scope':
              'Real native simulator pipeline; not physical-device accuracy, performance, power or commercial acceptance',
        };
        await File(
          p.join(qa, 'native-result.json'),
        ).writeAsString(jsonEncode(report), flush: true);
      } finally {
        await app.recorder.dispose();
        await app.repository.close();
        app.models.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}
