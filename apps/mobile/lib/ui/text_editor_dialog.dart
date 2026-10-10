import '../l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'theme.dart';

class TextEditorDialog extends StatefulWidget {
  const TextEditorDialog({
    super.key,
    required this.title,
    required this.initialText,
    this.originalText,
    this.singleLine = false,
    this.requireNonempty = false,
  });
  final String title, initialText;
  final String? originalText;
  final bool singleLine, requireNonempty;
  @override
  State<TextEditorDialog> createState() => _TextEditorDialogState();
}

class _TextEditorDialogState extends State<TextEditorDialog> {
  late final text = TextEditingController(text: widget.initialText);
  bool invalid = false;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  void _save() {
    if (widget.requireNonempty && text.text.trim().isEmpty) {
      setState(() => invalid = true);
      return;
    }
    Navigator.pop(context, text.text.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: text,
              autofocus: true,
              minLines: widget.singleLine ? 1 : 3,
              maxLines: widget.singleLine ? 1 : 8,
              maxLength: widget.singleLine ? 120 : 10000,
              decoration: InputDecoration(
                labelText: widget.singleLine
                    ? l10n(context).title
                    : l10n(context).transcriptText,
                errorText: invalid ? l10n(context).enterTitle : null,
              ),
            ),
            if (widget.originalText != null)
              Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  l10n(context).originalTranscript(widget.originalText!),
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(l10n(context).cancel),
      ),
      FilledButton(onPressed: _save, child: Text(l10n(context).save)),
    ],
  );
}
