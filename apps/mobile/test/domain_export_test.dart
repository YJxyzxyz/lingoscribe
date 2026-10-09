import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoscribe/domain/transcript.dart';
import 'package:lingoscribe/services/export_service.dart';

void main() {
  final transcript = Transcript(
    id: 'test',
    title: '访谈 / Interview',
    createdAt: DateTime.utc(2026, 10, 9),
    audioPath: '/private/audio.wav',
    status: TranscriptStatus.ready,
    durationMs: 3662000,
    segments: const [
      Segment(startMs: 1234, endMs: 5678, text: '今天 review 这个版本。'),
      Segment(startMs: 3600001, endMs: 3662000, text: '第二段\n\n不要 --> 注入字幕。'),
    ],
  );

  test(
    'editing retains original ASR text through multiple edits and persistence',
    () {
      final edited = transcript.segments.first
          .edit('修订一')
          .edit('修订二')
          .toggleBookmark();
      final restored = Segment.fromJson(
        jsonDecode(jsonEncode(edited.toJson())),
      );
      expect(restored.text, '修订二');
      expect(restored.originalText, transcript.segments.first.text);
      expect(restored.bookmarked, true);
      expect(restored.startMs, 1234);
      expect(restored.endMs, 5678);
    },
  );
  test('SRT preserves milliseconds, hours and bilingual text', () {
    final value = exportTranscript(transcript, ExportFormat.srt);
    expect(value, contains('00:00:01,234 --> 00:00:05,678'));
    expect(value, contains('01:00:00,001 --> 01:01:02,000'));
    expect(value, contains('今天 review 这个版本。'));
    expect(value.split('-->').length, 3);
    expect(value.split('\n\n').where((cue) => cue.isNotEmpty).length, 2);
  });
  test('VTT uses decimal separator and required header', () {
    final value = exportTranscript(transcript, ExportFormat.vtt);
    expect(value, startsWith('WEBVTT\n\n'));
    expect(value, contains('00:00:01.234 --> 00:00:05.678'));
  });
  test(
    'JSON contains versioned portable transcript but no private device path',
    () {
      final value = exportTranscript(transcript, ExportFormat.json);
      expect(value, isNot(contains('/private/')));
      final decoded = jsonDecode(value) as Map<String, dynamic>;
      expect(decoded['schemaVersion'], 1);
      expect(decoded['segments'], hasLength(2));
    },
  );
  test(
    'empty and zero-length segments cannot produce invalid subtitle cues',
    () {
      final value = transcript.copyWith(
        segments: const [
          Segment(startMs: 1, endMs: 1, text: 'empty time'),
          Segment(startMs: 1, endMs: 2, text: ' '),
        ],
      );
      expect(exportTranscript(value, ExportFormat.srt), isEmpty);
    },
  );
  test(
    'export filenames prevent path traversal and invalid Windows characters',
    () {
      final value = safeExportName('../../CON:访谈<>|?*');
      expect(value.contains('/'), false);
      expect(value.contains(':'), false);
      expect(safeExportName('  ... '), 'LingoScribe');
    },
  );
}
