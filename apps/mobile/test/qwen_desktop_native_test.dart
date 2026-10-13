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
    'production Dart worker and native VAD on the fixed licensed corpus',
    () async {
      final root = Platform.environment['LINGO_RESEARCH_ROOT']!;
      final directory =
          Platform.environment['LINGO_CORPUS_DIRECTORY'] ??
          '$root/corpus/ascend-expanded';
      final manifest =
          jsonDecode(await File('$directory/manifest.json').readAsString())
              as Map<String, dynamic>;
      final engine = OfflineEngine(), qwen = QwenEngine();
      final outputs = <Map<String, dynamic>>[];
      final destination = File(
        Platform.environment['LINGO_CORPUS_OUTPUT'] ??
            '$root/qwen-dart-native-outputs.json',
      );
      final manifestHash =
          (await sha256.bind(File('$directory/manifest.json').openRead()).first)
              .toString();
      final policyInputs = <String, String>{};
      final paths = {
        'hostTest': 'test/qwen_desktop_native_test.dart',
        'qwenWorker': '$root/../packages/offline_engine/lib/qwen_engine.dart',
        'windows': '$root/../packages/offline_engine/lib/qwen_windows.dart',
        'pcm': '$root/../packages/offline_engine/lib/pcm_wave.dart',
        'ffi': '$root/../packages/offline_engine/lib/offline_engine.dart',
        'modelManifest': '$root/../tools/qwen_model_manifest.json',
        'detector': '$root/../apps/mobile/assets/models/ggml-silero-v6.2.0.bin',
        'nativeVad': Platform.environment['LINGO_ENGINE_LIBRARY']!,
      };
      final runtimeFiles =
          await Directory(Platform.environment['LINGO_SHERPA_LIBRARY']!)
              .list()
              .where((file) => file is File && file.path.endsWith('.dll'))
              .toList();
      for (final file in runtimeFiles) {
        paths['runtime/${file.uri.pathSegments.last}'] = file.path;
      }
      for (final entry in paths.entries) {
        policyInputs[entry.key] =
            (await sha256.bind(File(entry.value).openRead()).first).toString();
      }
      final policyKeys = policyInputs.keys.toList()..sort();
      final policyHash = sha256
          .convert(
            utf8.encode(
              jsonEncode({
                for (final key in policyKeys) key: policyInputs[key],
              }),
            ),
          )
          .toString();
      if (Platform.environment['LINGO_RESUME_CORPUS'] == '1' &&
          await destination.exists()) {
        final saved =
            jsonDecode(await destination.readAsString())
                as Map<String, dynamic>;
        expect(saved['manifestSha256'], manifestHash);
        expect(saved['policySha256'], policyHash);
        outputs.addAll(
          (saved['outputs'] as List).map(
            (row) => Map<String, dynamic>.from(row as Map),
          ),
        );
        expect(outputs.map((row) => row['id']).toSet().length, outputs.length);
      }
      Future<void> checkpoint({bool complete = false}) async {
        final temporary = File('${destination.path}.part');
        await temporary.writeAsString(
          jsonEncode({
            'manifestSha256': manifestHash,
            'policySha256': policyHash,
            'policyInputsSha256': policyInputs,
            'complete': complete,
            'scope':
                'Production Dart worker and GGML VAD on Windows using the explicit upstream reference runtime. Not shipped Android/iOS binaries or phone performance.',
            'outputs': outputs,
          }),
          flush: true,
        );
        await temporary.rename(destination.path);
      }

      for (final clip in manifest['clips'] as List) {
        final audio = File('$directory/${clip['file']}');
        expect(clip['kind'], 'licensed_human');
        expect(
          (await sha256.bind(audio.openRead()).first).toString(),
          clip['sha256'],
        );
        final previous = outputs.where((row) => row['id'] == clip['id']);
        if (previous.isNotEmpty) {
          expect(previous.single['audioSha256'], clip['sha256']);
          continue;
        }
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
          'inputContextPolicy': result['inputContextPolicy'],
          'pcmReadPolicy': result['pcmReadPolicy'],
          'decodedWindows': result['decodedWindows'],
        });
        await checkpoint();
        // Progress only; reference/hypothesis text stays in ignored local build/.
        // ignore: avoid_print
        print(
          'Native corpus ${outputs.length}/${(manifest['clips'] as List).length}',
        );
      }
      expect(outputs.length, (manifest['clips'] as List).length);
      await checkpoint(complete: true);
    },
    skip: !const bool.fromEnvironment('RUN_QWEN_CORPUS'),
    timeout: const Timeout(Duration(minutes: 60)),
  );
}
