import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoscribe/data/transcript_repository.dart';
import 'package:lingoscribe/domain/transcript.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late TranscriptRepository repository;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('lingoscribe-db-test');
    repository = await TranscriptRepository.open(
      p.join(directory.path, 'library.sqlite'),
      factory: databaseFactoryFfi,
    );
  });
  tearDown(() async {
    await repository.close();
    await directory.delete(recursive: true);
  });
  Transcript item(
    String id,
    String text, {
    TranscriptStatus status = TranscriptStatus.ready,
  }) => Transcript(
    id: id,
    title: '记录 $id',
    audioPath: '/audio/$id.wav',
    createdAt: DateTime.utc(2026, 10, 9),
    status: status,
    segments: [Segment(startMs: 0, endMs: 1000, text: text)],
  );

  test(
    'Chinese and mixed-language full text search survives database restart',
    () async {
      await repository.save(item('1', '今天讨论 Flutter 和离线转写'));
      await repository.save(item('2', 'English interview'));
      await repository.close();
      repository = await TranscriptRepository.open(
        p.join(directory.path, 'library.sqlite'),
        factory: databaseFactoryFfi,
      );
      expect((await repository.list(query: '离线')).single.id, '1');
      expect((await repository.list(query: 'flutter')).single.id, '1');
      expect((await repository.list(query: 'English')).single.id, '2');
    },
  );
  test(
    'search wildcard and SQL punctuation are treated as literal user text',
    () async {
      await repository.save(item('1', '100% stable_under_score'));
      await repository.save(item('2', 'other content'));
      expect((await repository.list(query: '%')).single.id, '1');
      expect((await repository.list(query: '_')).single.id, '1');
      expect(await repository.list(query: "' OR 1=1 --"), isEmpty);
    },
  );
  test(
    'process death recovers unfinished jobs without erasing existing text',
    () async {
      await repository.save(
        item('1', '保留的文字', status: TranscriptStatus.transcribing),
      );
      await repository.close();
      repository = await TranscriptRepository.open(
        p.join(directory.path, 'library.sqlite'),
        factory: databaseFactoryFfi,
      );
      final restored = (await repository.list()).single;
      expect(restored.status, TranscriptStatus.interrupted);
      expect(restored.plainText, '保留的文字');
      expect(restored.error, isNotNull);
    },
  );
  test('edit updates searchable content and delete removes the row', () async {
    final value = item('1', '错误文字');
    await repository.save(value);
    await repository.save(
      value.copyWith(segments: [value.segments.first.edit('正确校对')]),
    );
    expect(await repository.list(query: '错误文字'), isEmpty);
    expect(
      (await repository.list(query: '正确校对')).single.segments.first.originalText,
      '错误文字',
    );
    await repository.delete('1');
    expect(await repository.list(), isEmpty);
  });
}
