import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../domain/transcript.dart';

typedef TranscriptionOptions = ({String language, String prompt});

class TranscriptionOptionsDialog extends StatefulWidget {
  const TranscriptionOptionsDialog({super.key, required this.transcript});
  final Transcript transcript;
  @override
  State<TranscriptionOptionsDialog> createState() => _OptionsState();
}

class _OptionsState extends State<TranscriptionOptionsDialog> {
  late String language = widget.transcript.language;
  late final terms = TextEditingController(text: widget.transcript.prompt);
  @override
  void dispose() {
    terms.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(l10n(context).transcriptionPreferences),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: language,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n(context).audioLanguage),
          items: [
            DropdownMenuItem(
              value: 'auto',
              child: Text(
                l10n(context).autoLanguage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(value: 'zh', child: Text(l10n(context).chinese)),
            DropdownMenuItem(value: 'en', child: Text('English')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => language = value);
          },
        ),
        SizedBox(height: 12),
        Text(l10n(context).audioLanguageAdvice),
        SizedBox(height: 16),
        TextField(
          controller: terms,
          minLines: 2,
          maxLines: 4,
          maxLength: 500,
          decoration: InputDecoration(
            labelText: l10n(context).glossaryPrompt,
            hintText: l10n(context).glossaryHint,
          ),
        ),
        Text(l10n(context).recordOptionsExplanation),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(l10n(context).cancel),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, (
          language: language,
          prompt: terms.text.trim(),
        )),
        child: Text(l10n(context).applyOptions),
      ),
    ],
  );
}
