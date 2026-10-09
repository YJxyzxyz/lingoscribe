import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoscribe/services/model_manager.dart';
import 'package:path/path.dart' as p;

void main() {
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
