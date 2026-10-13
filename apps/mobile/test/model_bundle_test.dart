import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lingoscribe/services/model_manager.dart';

void main() {
  late Directory root;
  final bytes = {
    'encoder.onnx': [1, 2, 3],
    'tokenizer/vocab.json': [4, 5],
  };
  final spec = ModelSpec(
    'qa-bundle',
    'Transport QA',
    'qa-bundle',
    5,
    '',
    'Transport only',
    assets: [
      for (final entry in bytes.entries)
        ModelAsset(
          entry.key,
          entry.value.length,
          sha256.convert(entry.value).toString(),
        ),
    ],
  );
  setUp(
    () async =>
        root = await Directory.systemTemp.createTemp('lingoscribe-bundle-qa'),
  );
  tearDown(() async => root.delete(recursive: true));
  ModelManager manager({bool corrupt = false}) => ModelManager(
    root,
    catalog: [spec],
    clientFactory: () => MockClient((request) async {
      final key = bytes.keys.firstWhere(
        (name) => request.url.path.endsWith(name),
      );
      return http.Response.bytes(
        corrupt && key.endsWith('.json') ? [5, 4] : bytes[key]!,
        200,
      );
    }),
  );
  test(
    'all bundle files install together and survive a restart with explicit selection',
    () async {
      final first = manager();
      try {
        await first.initialize(null);
        await first.download(spec);
        expect(first.error, isNull);
        await first.verify(spec);
        expect(first.active?.id, spec.id);
        expect(await Directory('${first.pathFor(spec)}.part').exists(), false);
        final restarted = manager();
        try {
          await restarted.initialize(spec.id);
          expect(restarted.active?.id, spec.id);
        } finally {
          restarted.dispose();
        }
      } finally {
        first.dispose();
      }
    },
  );
  test('corrupted last asset cannot expose a half-installed model', () async {
    final value = manager(corrupt: true);
    try {
      await value.download(spec);
      expect(value.error, contains('校验失败'));
      expect(value.installed, isEmpty);
      expect(await Directory(value.pathFor(spec)).exists(), false);
      expect(await Directory('${value.pathFor(spec)}.part').exists(), false);
    } finally {
      value.dispose();
    }
  });
  test(
    'failed replacement retains the previous verified installation',
    () async {
      final first = manager(), replacement = manager(corrupt: true);
      try {
        await first.download(spec);
        await replacement.initialize(spec.id);
        await replacement.download(spec);
        expect(replacement.error, contains('校验失败'));
        await replacement.verify(spec);
        expect(replacement.active?.id, spec.id);
      } finally {
        first.dispose();
        replacement.dispose();
      }
    },
  );
  test(
    'startup recovers a directory swap interrupted before new installation',
    () async {
      final value = manager();
      try {
        await value.download(spec);
        final target = value.pathFor(spec);
        await Directory(target).rename('$target.previous');
        await Directory('$target.part').create();
        await File('$target.part/incomplete').writeAsString('partial');
        await value.initialize(spec.id);
        await value.verify(spec);
        expect(value.active?.id, spec.id);
        expect(await Directory('$target.previous').exists(), false);
        expect(await Directory('$target.part').exists(), false);
      } finally {
        value.dispose();
      }
    },
  );
  test(
    'unsafe asset paths are rejected before touching staging or outside files',
    () async {
      final value = manager();
      final outside = File('${root.path}/keep.txt');
      await outside.writeAsString('keep');
      final invalid = ModelSpec(
        'bad',
        'bad',
        'safe',
        1,
        '',
        '',
        assets: [ModelAsset('../keep.txt', 1, 'bad')],
      );
      try {
        await expectLater(value.download(invalid), throwsFormatException);
        expect(await outside.readAsString(), 'keep');
        expect(value.downloadingId, isNull);
      } finally {
        value.dispose();
      }
    },
  );
  test('bundle cancellation never commits staged files', () async {
    final value = manager();
    value.addListener(() {
      if (value.verifying) value.cancelDownload();
    });
    try {
      await value.download(spec);
      expect(value.installed, isEmpty);
      expect(await Directory(value.pathFor(spec)).exists(), false);
      expect(await Directory('${value.pathFor(spec)}.part').exists(), false);
    } finally {
      value.dispose();
    }
  });
}
