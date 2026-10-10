import 'dart:convert';

enum TranscriptStatus {
  recording,
  saved,
  transcribing,
  ready,
  failed,
  interrupted,
}

/// Lightweight library projection; never use it to save or export a transcript.
class TranscriptSummary {
  const TranscriptSummary({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.durationMs,
    required this.status,
    required this.source,
    required this.preview,
  });
  final String id, title, source, preview;
  final DateTime createdAt;
  final int durationMs;
  final TranscriptStatus status;
  factory TranscriptSummary.fromRow(Map<String, Object?> row) =>
      TranscriptSummary(
        id: row['id'] as String,
        title: row['title'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['createdAt'] as int),
        durationMs: row['durationMs'] as int,
        status: TranscriptStatus.values.byName(row['status'] as String),
        source: row['source'] as String,
        preview: row['preview'] as String,
      );
}

class Segment {
  const Segment({
    required this.startMs,
    required this.endMs,
    required this.text,
    this.originalText,
    this.bookmarked = false,
  });
  final int startMs, endMs;
  final String text;
  final String? originalText;
  final bool bookmarked;
  Segment edit(String value) => Segment(
    startMs: startMs,
    endMs: endMs,
    text: value,
    originalText: originalText ?? text,
    bookmarked: bookmarked,
  );
  Segment toggleBookmark() => Segment(
    startMs: startMs,
    endMs: endMs,
    text: text,
    originalText: originalText,
    bookmarked: !bookmarked,
  );
  Map<String, dynamic> toJson() => {
    'startMs': startMs,
    'endMs': endMs,
    'text': text,
    'originalText': originalText,
    'bookmarked': bookmarked,
  };
  factory Segment.fromJson(Map<String, dynamic> json) => Segment(
    startMs: json['startMs'] as int,
    endMs: json['endMs'] as int,
    text: (json['text'] as String).trim(),
    originalText: json['originalText'] as String?,
    bookmarked: json['bookmarked'] as bool? ?? false,
  );
}

class Transcript {
  const Transcript({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.audioPath,
    this.durationMs = 0,
    this.status = TranscriptStatus.saved,
    this.segments = const [],
    this.language = 'auto',
    this.prompt = '',
    this.modelId,
    this.error,
    this.source = 'recording',
  });
  final String id, title, audioPath, language, prompt, source;
  final DateTime createdAt;
  final int durationMs;
  final TranscriptStatus status;
  final List<Segment> segments;
  final String? modelId, error;
  String get plainText => segments.map((s) => s.text).join('\n');
  Transcript copyWith({
    String? title,
    int? durationMs,
    TranscriptStatus? status,
    List<Segment>? segments,
    String? language,
    String? prompt,
    String? modelId,
    String? error,
    bool clearError = false,
  }) => Transcript(
    id: id,
    title: title ?? this.title,
    createdAt: createdAt,
    audioPath: audioPath,
    durationMs: durationMs ?? this.durationMs,
    status: status ?? this.status,
    segments: segments ?? this.segments,
    language: language ?? this.language,
    prompt: prompt ?? this.prompt,
    modelId: modelId ?? this.modelId,
    error: clearError ? null : error ?? this.error,
    source: source,
  );
  Map<String, Object?> toRow() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'audioPath': audioPath,
    'durationMs': durationMs,
    'status': status.name,
    'segments': jsonEncode(segments.map((s) => s.toJson()).toList()),
    'plainText': plainText,
    'language': language,
    'prompt': prompt,
    'modelId': modelId,
    'error': error,
    'source': source,
  };
  factory Transcript.fromRow(Map<String, Object?> row) => Transcript(
    id: row['id'] as String,
    title: row['title'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['createdAt'] as int),
    audioPath: row['audioPath'] as String,
    durationMs: row['durationMs'] as int,
    status: TranscriptStatus.values.byName(row['status'] as String),
    segments: (jsonDecode(row['segments'] as String) as List)
        .map((s) => Segment.fromJson(s as Map<String, dynamic>))
        .toList(),
    language: row['language'] as String,
    prompt: row['prompt'] as String,
    modelId: row['modelId'] as String?,
    error: row['error'] as String?,
    source: row['source'] as String,
  );
}

String clock(int ms, {bool hours = false}) {
  final seconds = ms ~/ 1000;
  String two(int value) => value.toString().padLeft(2, '0');
  return hours || seconds >= 3600
      ? '${two(seconds ~/ 3600)}:${two(seconds ~/ 60 % 60)}:${two(seconds % 60)}'
      : '${two(seconds ~/ 60)}:${two(seconds % 60)}';
}
