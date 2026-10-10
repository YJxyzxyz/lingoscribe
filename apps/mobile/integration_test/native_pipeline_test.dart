import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lingoscribe/application/app_controller.dart';
import 'package:lingoscribe/domain/transcript.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:offline_engine/offline_engine.dart';
import 'package:flutter/services.dart';

// Inject test media into this test installation's private files/qa directory.
// Fixtures are not bundled into the production application and no inference is mocked.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // iOS routes Dart print output through unified logging, not simctl's console.
  // Export the binding's actual completed assertion result for host runners.
  unawaited(
    binding.allTestsPassed.future.then((passed) async {
      final qa = p.join((await getApplicationSupportDirectory()).path, 'qa');
      final status = File(p.join(qa, 'test-status.json.part'));
      await status.writeAsString(
        jsonEncode({
          'passed': passed,
          'testCount': binding.results.length,
          'failures': binding.failureMethodsDetails
              .map((failure) => failure.details)
              .toList(),
        }),
        flush: true,
      );
      await status.rename(p.join(qa, 'test-status.json'));
    }),
  );
  if (Platform.isAndroid) {
    testWidgets(
      'native microphone capture pauses, resumes and saves actual WAV',
      (tester) async {
        final app = await AppController.create();
        try {
          await app.startRecording();
          await Future<void>.delayed(const Duration(milliseconds: 800));
          await app.pauseRecording();
          await Future<void>.delayed(const Duration(milliseconds: 350));
          final audio = File(app.recording!.audioPath);
          final pausedBytes = await audio.length();
          await Future<void>.delayed(const Duration(milliseconds: 300));
          expect(
            await audio.length(),
            pausedBytes,
            reason: 'Paused native recording must stop growing',
          );
          expect(app.paused, true);
          await app.togglePause();
          await Future<void>.delayed(const Duration(milliseconds: 650));
          expect(await audio.length(), greaterThan(pausedBytes));
          final saved = await app.stopRecording();
          expect(saved!.status, TranscriptStatus.saved);
          expect(saved.durationMs, greaterThan(500));
          expect(saved.durationMs, lessThan(5000));
          expect((await app.find(saved.id))!.durationMs, saved.durationMs);
          final qa = p.join(p.dirname(app.root.path), 'qa');
          await File(p.join(qa, 'microphone-result.json')).writeAsString(
            jsonEncode({
              'durationMs': saved.durationMs,
              'bytes': await audio.length(),
              'pausedBytes': pausedBytes,
              'checks': [
                'native_capture',
                'pause_stops_file_growth',
                'resume_grows_file',
                'wav_duration',
                'sqlite_persistence',
              ],
              'scope':
                  'Native virtual-device microphone lifecycle; not human voice quality or a physical microphone test',
            }),
            flush: true,
          );
        } finally {
          if (app.recording != null) await app.stopRecording();
          await app.recorder.dispose();
          await app.repository.close();
          app.models.dispose();
        }
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );
  }
  testWidgets('native codecs preserve real audio, downmix and sample rate', (
    tester,
  ) async {
    final qa = p.join((await getApplicationSupportDirectory()).path, 'qa');
    final engine = OfflineEngine();
    List<double> pcm(Uint8List bytes) {
      final view = ByteData.sublistView(bytes);
      var offset = 12;
      while (offset + 8 <= bytes.length) {
        final size = view.getUint32(offset + 4, Endian.little);
        if (String.fromCharCodes(bytes.sublist(offset, offset + 4)) == 'data') {
          return List<double>.generate(
            size ~/ 2,
            (i) => view.getInt16(offset + 8 + i * 2, Endian.little) / 32768,
          );
        }
        offset += 8 + size + size % 2;
      }
      throw const FormatException('Missing audio data');
    }

    final reference = pcm(await File(p.join(qa, 'sample.wav')).readAsBytes());
    final reports = <Map<String, Object>>[];
    for (final name in [
      'stereo48.wav',
      'stereo44.wav',
      'sample.mp3',
      'sample.m4a',
      'sample.flac',
      'sample.ogg',
    ]) {
      final output = p.join(qa, '$name.normalized.wav');
      expect(await File(p.join(qa, name)).exists(), true, reason: name);
      int duration;
      try {
        duration = await engine.normalize(p.join(qa, name), output);
      } on PlatformException catch (error) {
        // OGG container support is platform-dependent; an explicit rejection is required.
        if (Platform.isIOS &&
            name == 'sample.ogg' &&
            error.code == 'decode' &&
            error.message == 'No supported audio track') {
          expect(await File(output).exists(), false);
          reports.add({
            'format': name,
            'supported': false,
            'behavior': 'explicit_unsupported_audio_track',
          });
          continue;
        }
        rethrow;
      }
      expect((duration - 11000).abs(), lessThan(200), reason: name);
      final bytes = await File(output).readAsBytes();
      final header = ByteData.sublistView(bytes);
      expect(header.getUint32(24, Endian.little), 16000, reason: name);
      expect(header.getUint16(22, Endian.little), 1, reason: name);
      expect(header.getUint16(34, Endian.little), 16, reason: name);
      final decoded = pcm(bytes);
      double best = 0;
      // Codec padding may shift the waveform. Check the real signal, not a mock duration.
      for (var shift = -3200; shift <= 3200; shift += 16) {
        double dot = 0, left = 0, right = 0;
        for (
          var i = 3200;
          i < min(reference.length, decoded.length) - 3200;
          i += 8
        ) {
          final a = reference[i], b = decoded[i + shift];
          dot += a * b;
          left += a * a;
          right += b * b;
        }
        if (left > 0 && right > 0) best = max(best, dot / sqrt(left * right));
      }
      expect(best, greaterThan(.9), reason: '$name signal correlation');
      reports.add({
        'format': name,
        'durationMs': duration,
        'signalCorrelation': best,
      });
    }
    final invalid = File(p.join(qa, 'not-audio.wav'));
    await invalid.writeAsString('invalid audio');
    await expectLater(
      engine.normalize(invalid.path, p.join(qa, 'invalid-out.wav')),
      throwsA(isA<Exception>()),
    );
    expect(await File(p.join(qa, 'invalid-out.wav')).exists(), false);
    await File(
      p.join(qa, 'codec-result.json'),
    ).writeAsString(jsonEncode(reports), flush: true);
  }, timeout: const Timeout(Duration(minutes: 2)));
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
        final elapsed = Stopwatch()..start();
        await app.transcribe(entry);
        elapsed.stop();
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
        final report = <String, dynamic>{
          'platform': Platform.operatingSystem,
          'buildMode': 'debug',
          'fixtureKind': 'upstream',
          'modelSha256': (await sha256.bind(model.openRead()).first).toString(),
          'audioSha256': (await sha256.bind(audio.openRead()).first).toString(),
          'elapsedSeconds': elapsed.elapsedMilliseconds / 1000,
          'durationMs': result.durationMs,
          'segments': result.segments
              .map((segment) => segment.toJson())
              .toList(),
          'checks': [
            'model_import_hash',
            'native_normalization',
            'isolate_asr',
            'timestamps',
            'sqlite_persistence',
            'original_text_retained',
            'bookmark',
          ],
        };
        binding.reportData = report;
        await File(p.join(qa, 'native-result.json')).writeAsString(
          const JsonEncoder.withIndent('  ').convert(report),
          flush: true,
        );
      } finally {
        await app.recorder.dispose();
        await app.repository.close();
        app.models.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
