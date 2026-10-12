import 'package:flutter/material.dart';
import 'theme.dart';

/// Highlights literal matches while preserving the original selectable text.
class SearchableTranscriptText extends StatelessWidget {
  const SearchableTranscriptText({
    super.key,
    required this.text,
    this.query = '',
  });
  final String text, query;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 16, height: 1.6, color: ink);
    if (query.isEmpty) return SelectableText(text, style: style);
    final matches = RegExp(
      RegExp.escape(query),
      caseSensitive: false,
      unicode: true,
    ).allMatches(text);
    final spans = <TextSpan>[];
    var start = 0;
    for (final match in matches) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: const TextStyle(backgroundColor: Color(0xffffedbd)),
        ),
      );
      start = match.end;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
    return SelectableText.rich(TextSpan(style: style, children: spans));
  }
}
