import 'dart:convert';
import '../domain/transcript.dart';

enum ExportFormat { txt, markdown, srt, vtt, json }

extension ExportFormatDetails on ExportFormat {
  String get extension => switch (this) {
    ExportFormat.markdown => 'md',
    _ => name,
  };
  String get label => switch (this) {
    ExportFormat.txt => '纯文本 · TXT',
    ExportFormat.markdown => '笔记 · Markdown',
    ExportFormat.srt => '字幕 · SRT',
    ExportFormat.vtt => '网页字幕 · VTT',
    ExportFormat.json => '完整数据 · JSON',
  };
}

String _timestamp(int ms, String separator) =>
    '${clock(ms, hours: true)}$separator${(ms % 1000).toString().padLeft(3, '0')}';
String exportTranscript(Transcript transcript, ExportFormat format) {
  switch (format) {
    case ExportFormat.txt:
      return '${transcript.title}\n\n${transcript.plainText}\n';
    case ExportFormat.markdown:
      final title = transcript.title.replaceAll(RegExp(r'[\r\n]'), ' ');
      return '# $title\n\n${transcript.segments.map((s) => '**${clock(s.startMs)}** ${s.text.replaceAll('\n', '  \n')}').join('\n\n')}\n';
    case ExportFormat.srt:
    case ExportFormat.vtt:
      final vtt = format == ExportFormat.vtt;
      final result = StringBuffer(vtt ? 'WEBVTT\n\n' : '');
      var index = 0;
      for (final s in transcript.segments) {
        if (s.text.trim().isEmpty || s.endMs <= s.startMs) continue;
        index++;
        // A blank line terminates a cue; untrusted edited text cannot inject cues.
        final text = s.text
            .replaceAll(RegExp(r'[\r\n]+'), ' ')
            .replaceAll('-->', '→');
        result.write(
          '$index\n${_timestamp(s.startMs, vtt ? '.' : ',')} --> ${_timestamp(s.endMs, vtt ? '.' : ',')}\n$text\n\n',
        );
      }
      return result.toString();
    case ExportFormat.json:
      return const JsonEncoder.withIndent('  ').convert({
        'schemaVersion': 1,
        'id': transcript.id,
        'title': transcript.title,
        'createdAt': transcript.createdAt.toUtc().toIso8601String(),
        'durationMs': transcript.durationMs,
        'language': transcript.language,
        'model': transcript.modelId,
        'segments': transcript.segments.map((s) => s.toJson()).toList(),
      });
  }
}

String safeExportName(String title) {
  final value = title
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
      .replaceAll(RegExp(r'[. ]+$'), '')
      .trim();
  return value.isEmpty
      ? 'LingoScribe'
      : String.fromCharCodes(value.runes.take(60));
}
