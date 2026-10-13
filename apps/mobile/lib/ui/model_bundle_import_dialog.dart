import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../l10n/l10n.dart';
import '../services/model_manager.dart';
import 'theme.dart';

class ModelBundleImportDialog extends StatefulWidget {
  const ModelBundleImportDialog({
    super.key,
    required this.model,
    required this.initialPaths,
    required this.pickMore,
  });
  final ModelSpec model;
  final List<String> initialPaths;
  final Future<List<String>?> Function() pickMore;
  @override
  State<ModelBundleImportDialog> createState() => _BundleImportState();
}

class _BundleImportState extends State<ModelBundleImportDialog> {
  final paths = <String, String>{};
  bool selecting = false;
  Object? error;
  @override
  void initState() {
    super.initState();
    _add(widget.initialPaths);
  }

  void _add(List<String> selected) {
    final expected = {
      for (final asset in widget.model.assets) p.basename(asset.path),
    };
    var unexpected = false;
    for (final path in selected) {
      final name = p.basename(path);
      if (expected.contains(name)) {
        paths[name] = path;
      } else {
        unexpected = true;
      }
    }
    error = unexpected
        ? const FormatException('请选择一个官方模型文件，或完整的 Qwen3 六个文件')
        : null;
  }

  Future<void> _pick() async {
    setState(() => selecting = true);
    try {
      final selected = await widget.pickMore();
      if (mounted && selected != null) setState(() => _add(selected));
    } catch (failure) {
      if (mounted) setState(() => error = failure);
    } finally {
      if (mounted) setState(() => selecting = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !selecting,
    child: AlertDialog(
      scrollable: true,
      title: Text(l10n(context).importOfficialModel),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n(context).bundleImportExplanation),
          SizedBox(height: 12),
          for (final asset in widget.model.assets)
            Row(
              children: [
                Icon(
                  paths.containsKey(p.basename(asset.path))
                      ? Icons.check_circle_outline
                      : Icons.radio_button_unchecked,
                  color: paths.containsKey(p.basename(asset.path))
                      ? forest
                      : muted,
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(asset.path, style: TextStyle(fontSize: 12)),
                ),
                IconButton(
                  tooltip: l10n(context).removeSelectedFile,
                  onPressed:
                      selecting || !paths.containsKey(p.basename(asset.path))
                      ? null
                      : () => setState(
                          () => paths.remove(p.basename(asset.path)),
                        ),
                  icon: Icon(Icons.close, size: 18),
                ),
              ],
            ),
          if (error != null)
            Text(
              friendlyError(context, error!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          SizedBox(height: 8),
          Text(
            l10n(
              context,
            ).bundleFilesSelected(paths.length, widget.model.assets.length),
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: selecting ? null : () => Navigator.pop(context),
          child: Text(l10n(context).cancel),
        ),
        FilledButton(
          onPressed: selecting
              ? null
              : paths.length != widget.model.assets.length
              ? _pick
              : () => Navigator.pop(context, [
                  for (final asset in widget.model.assets)
                    paths[p.basename(asset.path)]!,
                ]),
          child: Text(
            paths.length == widget.model.assets.length
                ? l10n(context).verifyAndInstall
                : l10n(context).addModelFiles,
          ),
        ),
      ],
    ),
  );
}
