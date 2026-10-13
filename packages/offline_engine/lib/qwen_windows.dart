import 'dart:math' as math;

/// Display timestamps remain VAD-derived speech envelopes; decoding can also
/// include nearby quiet context. Neither boundary is a word alignment.
class QwenDecodeWindow {
  const QwenDecodeWindow({
    required this.startMs,
    required this.endMs,
    required this.audioStartMs,
    required this.audioEndMs,
  });
  final int startMs, endMs, audioStartMs, audioEndMs;
}

List<QwenDecodeWindow> qwenDecodeWindows(
  List<Map<String, dynamic>> intervals,
  int durationMs,
) {
  if (durationMs <= 0 || durationMs > 7200000) {
    throw const FormatException('Invalid audio duration');
  }
  var previousEnd = 0;
  for (final interval in intervals) {
    final start = interval['startMs'], end = interval['endMs'];
    if (start is! int ||
        end is! int ||
        start < previousEnd ||
        end <= start ||
        end > durationMs ||
        end - start > 20000) {
      throw const FormatException('Invalid speech intervals');
    }
    previousEnd = end;
  }
  if (intervals.isEmpty) return const [];
  // Tiny boundary trims can change automatic language detection in mixed
  // short utterances. VAD still gates inference: silence never loads a model.
  if (durationMs <= 20000) {
    return [
      QwenDecodeWindow(
        startMs: intervals.first['startMs'] as int,
        endMs: intervals.last['endMs'] as int,
        audioStartMs: 0,
        audioEndMs: durationMs,
      ),
    ];
  }
  final groups = <List<int>>[];
  for (final interval in intervals) {
    final start = interval['startMs'] as int, end = interval['endMs'] as int;
    if (groups.isNotEmpty &&
        start - groups.last[1] <= 600 &&
        end - groups.last[0] <= 19600) {
      groups.last[1] = end;
    } else {
      groups.add([start, end]);
    }
  }
  return [
    for (var index = 0; index < groups.length; index++)
      _withContext(groups, index, durationMs),
  ];
}

QwenDecodeWindow _withContext(List<List<int>> groups, int index, int duration) {
  final start = groups[index][0], end = groups[index][1];
  final available = 20000 - (end - start);
  final before = index == 0 ? 0 : groups[index - 1][1];
  final after = index == groups.length - 1 ? duration : groups[index + 1][0];
  final left = math.min(200, math.min(available ~/ 2, start - before));
  final right = math.min(200, math.min(available - left, after - end));
  return QwenDecodeWindow(
    startMs: start,
    endMs: end,
    audioStartMs: start - left,
    audioEndMs: end + right,
  );
}
