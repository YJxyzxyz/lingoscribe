import 'dart:io';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lingoscribe/services/model_manager.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'startup removes known interrupted downloads without deleting unrelated files',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lingoscribe-model-recovery',
      );
      final manager = ModelManager(directory);
      final partial = File('${manager.pathFor(models.first)}.part');
      final unrelated = File(p.join(directory.path, 'unrelated.bin'));
      await partial.writeAsString('interrupted download');
      await unrelated.writeAsString('keep');
      try {
        await manager.initialize(null);
        expect(await partial.exists(), false);
        expect(await unrelated.readAsString(), 'keep');
        expect(manager.installed, isEmpty);
      } finally {
        manager.dispose();
        await directory.delete(recursive: true);
      }
    },
  );
  ModelSpec fixture(List<int> bytes, {String? digest}) => ModelSpec(
    'qa-model',
    'Test only',
    'test-model.bin',
    bytes.length,
    digest ?? sha256.convert(bytes).toString(),
    'Transport test only',
  );
  test(
    'download installs only verified bytes and removes temporary file',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lingoscribe-download-test',
      );
      final bytes = List<int>.generate(65536, (i) => i % 256);
      final spec = fixture(bytes);
      final manager = ModelManager(
        directory,
        clientFactory: () => MockClient((request) async {
          expect(request.url.scheme, 'https');
          expect(request.url.path, contains(ModelSpec.revision));
          return http.Response.bytes(bytes, 200);
        }),
      );
      try {
        await manager.initialize(null);
        await manager.download(spec);
        expect(manager.error, isNull);
        expect(await File(manager.pathFor(spec)).readAsBytes(), bytes);
        expect(await File('${manager.pathFor(spec)}.part').exists(), false);
        expect(manager.installed, contains(spec.id));
      } finally {
        manager.dispose();
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'same-size corrupted download cannot replace an installed model',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lingoscribe-download-test',
      );
      final spec = fixture([1, 2, 3, 4]);
      final manager = ModelManager(
        directory,
        clientFactory: () =>
            MockClient((_) async => http.Response.bytes([4, 3, 2, 1], 200)),
      );
      try {
        await manager.initialize(null);
        final existing = File(manager.pathFor(spec));
        await existing.writeAsBytes([1, 2, 3, 4]);
        await manager.download(spec);
        expect(manager.error, contains('校验失败'));
        expect(await existing.readAsBytes(), [1, 2, 3, 4]);
        expect(await File('${existing.path}.part').exists(), false);
        expect(manager.downloadingId, isNull);
      } finally {
        manager.dispose();
        await directory.delete(recursive: true);
      }
    },
  );
  test('cancelled stream leaves no installed or partial model', () async {
    final directory = await Directory.systemTemp.createTemp(
      'lingoscribe-download-test',
    );
    final body = StreamController<List<int>>();
    final connected = Completer<void>();
    final spec = fixture([1, 2, 3, 4]);
    final manager = ModelManager(
      directory,
      clientFactory: () => MockClient.streaming((_, _) async {
        connected.complete();
        return http.StreamedResponse(body.stream, 200);
      }),
    );
    try {
      await manager.initialize(null);
      final task = manager.download(spec);
      await connected.future;
      body.add([1, 2]);
      manager.cancelDownload();
      body.add([3, 4]);
      await body.close();
      await task;
      expect(manager.error, isNull);
      expect(manager.installed, isEmpty);
      expect(await File(manager.pathFor(spec)).exists(), false);
      expect(await File('${manager.pathFor(spec)}.part').exists(), false);
      expect(manager.downloadingId, isNull);
    } finally {
      manager.dispose();
      await directory.delete(recursive: true);
    }
  });
  test(
    'missing model cannot be selected or used as a fake successful engine',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lingoscribe-model-test',
      );
      final manager = ModelManager(directory);
      try {
        await manager.initialize('base-q5');
        manager.select('base-q5');
        expect(manager.active, isNull);
        await expectLater(manager.verifyActive(), throwsStateError);
      } finally {
        manager.dispose();
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'unknown model is rejected without installing partial content',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lingoscribe-model-test',
      );
      final source = File(p.join(directory.path, 'bad.bin'));
      await source.writeAsString('wrong model');
      final manager = ModelManager(Directory(p.join(directory.path, 'models')));
      try {
        await manager.initialize(null);
        await expectLater(
          manager.importFile(source.path),
          throwsFormatException,
        );
        expect(manager.installed, isEmpty);
        expect(manager.downloadingId, isNull);
      } finally {
        manager.dispose();
        await directory.delete(recursive: true);
      }
    },
  );
}
