import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoscribe/application/app_controller.dart';
import 'package:lingoscribe/data/transcript_repository.dart';
import 'package:lingoscribe/domain/transcript.dart';
import 'package:lingoscribe/services/model_manager.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Controlled platform timings verify concurrency and recovery, not microphone hardware.
class DelayedRecorder extends AudioRecorder {
  Completer<bool>? permission;
  Completer<void>? startGate, resumeGate;
  final startEntered = Completer<void>();
  final resumeEntered = Completer<void>();
  final calls = <String>[];
  String? path;
  bool failStart = false;

  @override
  Future<bool> hasPermission({bool request = true}) async =>
      permission == null ? true : await permission!.future;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    calls.add('start');
    this.path = path;
    startEntered.complete();
    if (startGate != null) await startGate!.future;
    await File(path).writeAsBytes([
      ...List<int>.filled(44, 0),
      ...List<int>.generate(6400, (i) => i % 256),
    ]);
    if (failStart) throw PlatformException(code: 'capture');
  }

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> resume() async {
    calls.add('resume');
    resumeEntered.complete();
    if (resumeGate != null) await resumeGate!.future;
  }

  @override
  Future<String?> stop() async {
    calls.add('stop');
    return path;
  }

  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) =>
      const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppController app;
  late DelayedRecorder recorder;
  late Directory root;
  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          (_) async => null,
        );
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('lingoscribe-capture-races');
    recorder = DelayedRecorder();
    final models = ModelManager(Directory('${root.path}/models'));
    app = AppController(
      repository: await TranscriptRepository.open(
        inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      ),
      root: root,
      models: models,
      preferences: await SharedPreferences.getInstance(),
      recorder: recorder,
    );
  });
  tearDown(() async {
    if (app.recording != null) await app.stopRecording();
    await recorder.dispose();
    await app.repository.close();
    app.models.dispose();
    await root.delete(recursive: true);
  });

  test(
    'permission request reserves capture so a double tap cannot create two recordings',
    () async {
      recorder.permission = Completer<bool>();
      final first = app.startRecording();
      expect(app.busy, true);
      await expectLater(app.startRecording(), throwsStateError);
      recorder.permission!.complete(true);
      await first;
      expect(recorder.calls.where((call) => call == 'start'), hasLength(1));
      expect(await app.repository.summaries(), hasLength(1));
      final saved = await app.stopRecording();
      expect(saved!.durationMs, 200);
      expect(app.busy, false);
    },
  );

  test(
    'permission granted after leaving the app does not start the microphone',
    () async {
      var foreground = true;
      recorder.permission = Completer<bool>();
      final starting = app.startRecording(isForeground: () => foreground);
      final rejection = expectLater(starting, throwsStateError);
      foreground = false;
      recorder.permission!.complete(true);
      await rejection;
      expect(recorder.calls, isEmpty);
      expect(await app.repository.summaries(), isEmpty);
      expect(app.busy, false);
    },
  );

  test(
    'leaving during native startup pauses immediately when capture becomes available',
    () async {
      var foreground = true;
      recorder.startGate = Completer<void>();
      final starting = app.startRecording(isForeground: () => foreground);
      await recorder.startEntered.future;
      foreground = false;
      recorder.startGate!.complete();
      await starting;
      expect(app.paused, true);
      expect(recorder.calls, ['start', 'pause']);
    },
  );

  test(
    'permission dialog focus settles before capture without losing the start request',
    () async {
      var foreground = false;
      final focused = Completer<void>();
      final starting = app.startRecording(
        isForeground: () => foreground,
        settlePermissionFocus: () => focused.future,
      );
      await Future<void>.delayed(Duration.zero);
      expect(recorder.calls, isEmpty);
      foreground = true;
      focused.complete();
      await starting;
      expect(recorder.calls, ['start']);
      expect(app.paused, false);
    },
  );

  test(
    'duplicate background notifications wait for resume then pause once',
    () async {
      await app.startRecording();
      await app.togglePause();
      recorder.resumeGate = Completer<void>();
      final resuming = app.togglePause();
      await recorder.resumeEntered.future;
      final background = app.pauseRecording();
      final repeated = app.pauseRecording();
      recorder.resumeGate!.complete();
      await Future.wait([resuming, background, repeated]);
      expect(app.paused, true);
      expect(recorder.calls, ['start', 'pause', 'resume', 'pause']);
    },
  );

  test('failed native startup retains captured PCM in the library', () async {
    recorder.failStart = true;
    await expectLater(app.startRecording(), throwsA(isA<PlatformException>()));
    final summaries = await app.repository.summaries();
    expect(summaries, hasLength(1));
    final saved = (await app.find(summaries.single.id))!;
    expect(saved.status, TranscriptStatus.interrupted);
    expect(saved.durationMs, 200);
    expect(
      (await File(saved.audioPath).readAsBytes()).sublist(44),
      List<int>.generate(6400, (i) => i % 256),
    );
    expect(app.busy, false);
  });
}
