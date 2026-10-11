import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_engine/offline_engine.dart';

// Explicit development-host native assertions. No platform normalization mock
// is counted as Android/iOS validation; the input is already normalized PCM.
void main() {
  test(
    'real native VAD and Qwen worker transcribe upstream English audio',
    () async {
      final root = Platform.environment['LINGO_RESEARCH_ROOT']!;
      final audio = Platform.environment['LINGO_NATIVE_AUDIO']!;
      final engine = OfflineEngine();
      final detected = await engine.detectSpeech(
        wav: audio,
        vad: '$root/../apps/mobile/assets/models/ggml-silero-v6.2.0.bin',
      );
      final intervals = (detected['segments'] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      expect(intervals, isNotEmpty);
      final fractions = <double>[];
      final result = await QwenEngine().transcribe(
        model: '$root/research/qwen3-asr',
        wav: audio,
        intervals: intervals,
        durationMs: detected['durationMs'] as int,
        onProgress: fractions.add,
      );
      final segments = (result['segments'] as List)
          .cast<Map<String, dynamic>>();
      expect(segments, isNotEmpty);
      expect(segments.map((row) => row['text']).join(' '), contains('country'));
      expect(result['timestampSource'], 'speech_intervals');
      expect(
        segments.last['endMs'] as int,
        lessThanOrEqualTo(result['durationMs'] as int),
      );
      expect(fractions, orderedEquals([...fractions]..sort()));
    },
    skip: !const bool.fromEnvironment('RUN_NATIVE_QWEN'),
    timeout: const Timeout(Duration(minutes: 5)),
  );
  test(
    'production Dart worker and native VAD on the fixed licensed 90-clip corpus',
    () async {
      final root = Platform.environment['LINGO_RESEARCH_ROOT']!;
      final directory = '$root/corpus/ascend-expanded';
      final manifest =
          jsonDecode(await File('$directory/manifest.json').readAsString())
              as Map<String, dynamic>;
      final engine = OfflineEngine(), qwen = QwenEngine();
      final outputs = <Map<String, dynamic>>[];
      for (final clip in manifest['clips'] as List) {
        final audio = File('$directory/${clip['file']}');
        expect(clip['kind'], 'licensed_human');
        expect(
          (await sha256.bind(audio.openRead()).first).toString(),
          clip['sha256'],
        );
        final clock = Stopwatch()..start();
        final detected = await engine.detectSpeech(
          wav: audio.path,
          vad: '$root/../apps/mobile/assets/models/ggml-silero-v6.2.0.bin',
        );
        final result = await qwen.transcribe(
          model: '$root/research/qwen3-asr',
          wav: audio.path,
          intervals: (detected['segments'] as List)
              .map((row) => Map<String, dynamic>.from(row as Map))
              .toList(),
          durationMs: detected['durationMs'] as int,
        );
        outputs.add({
          'id': clip['id'],
          'audioSha256': clip['sha256'],
          'hypothesis': (result['segments'] as List)
              .map((segment) => segment['text'])
              .join(' '),
          'elapsedSeconds': clock.elapsedMilliseconds / 1000,
          'speechIntervals': detected['segments'],
        });
        // Progress only; reference/hypothesis text stays in ignored local build/.
        // ignore: avoid_print
        print(
          'Native corpus ${outputs.length}/${(manifest['clips'] as List).length}',
        );
      }
      await File('$root/qwen-dart-native-outputs.json').writeAsString(
        jsonEncode({
          'manifestSha256':
              (await sha256
                      .bind(File('$directory/manifest.json').openRead())
                      .first)
                  .toString(),
          'scope':
              'Production Dart worker and GGML VAD on Windows using the explicit upstream reference runtime. Not shipped Android/iOS binaries or phone performance.',
          'outputs': outputs,
        }),
      );
    },
    skip: !const bool.fromEnvironment('RUN_QWEN_CORPUS'),
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
