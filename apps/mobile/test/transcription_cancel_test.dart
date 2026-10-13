import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoscribe/application/app_controller.dart';
import 'package:lingoscribe/data/transcript_repository.dart';
import 'package:lingoscribe/domain/transcript.dart';
import 'package:lingoscribe/services/model_manager.dart';
import 'package:offline_engine/offline_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DelayedModelVerification extends ModelManager {
  DelayedModelVerification(super.directory);
  final entered = Completer<void>(), release = Completer<void>();
  @override
  Future<void> verify(ModelSpec model) async {
    entered.complete();
    await release.future;
  }
}

class TrackingPreparation extends OfflineEngine {
  var normalizationCalls = 0;
  @override
  Future<int> normalize(String source, String destination) async {
    normalizationCalls++;
    throw StateError('Unexpected normalization after cancellation');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test(
    'cancel during verification never starts audio preparation and retains the saved audio',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.llfbandit.record/messages'),
            (_) async => null,
          );
      SharedPreferences.setMockInitialValues({});
      final root = await Directory.systemTemp.createTemp(
        'lingoscribe-cancel-verification',
      );
      final manager = DelayedModelVerification(
        Directory('${root.path}/models'),
      );
      manager.installed.add(models.first.id);
      manager.activeId = models.first.id;
      final engine = TrackingPreparation();
      final app = AppController(
        repository: await TranscriptRepository.open(
          inMemoryDatabasePath,
          factory: databaseFactoryFfi,
        ),
        root: root,
        models: manager,
        engine: engine,
        preferences: await SharedPreferences.getInstance(),
      );
      final audio = await File(
        '${root.path}/retained.wav',
      ).writeAsString('Domain cancellation fixture; no inference');
      final entry = Transcript(
        id: 'cancel-qa',
        title: 'Domain cancellation',
        createdAt: DateTime.now(),
        audioPath: audio.path,
      );
      try {
        await app.save(entry);
        final pending = app.transcribe(entry);
        await manager.entered.future;
        app.cancelTranscription();
        expect(app.phase, '正在取消转写');
        manager.release.complete();
        await pending;
        expect(engine.normalizationCalls, 0);
        expect(
          (await app.find(entry.id))!.status,
          TranscriptStatus.interrupted,
        );
        expect(
          await audio.readAsString(),
          'Domain cancellation fixture; no inference',
        );
        expect(app.busy, false);
      } finally {
        await app.recorder.dispose();
        await app.repository.close();
        manager.dispose();
        await root.delete(recursive: true);
      }
    },
  );
}
