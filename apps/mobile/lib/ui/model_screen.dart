import '../l10n/l10n.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../application/app_controller.dart';
import '../services/model_manager.dart';
import 'theme.dart';

class ModelScreen extends StatefulWidget {
  const ModelScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<ModelScreen> createState() => _ModelScreenState();
}

class _ModelScreenState extends State<ModelScreen> {
  bool mirror = false;
  AppController get app => widget.controller;
  Future<void> _import() async {
    try {
      final selected = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['bin'],
        withData: false,
      );
      if (selected?.files.single.path != null) {
        await app.models.importFile(selected!.files.single.path!);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _remove(ModelSpec model) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n(context).deleteModelQuestion),
        content: Text(l10n(context).removeModelExplanation(model.sizeLabel)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n(context).keep),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n(context).deleteModel),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await app.models.remove(model);
      } catch (e) {
        if (mounted) showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: app.models,
    builder: (context, _) => ListView(
      padding: EdgeInsets.all(24),
      children: [
        SizedBox(height: 20),
        Text(
          l10n(context).modelsHeadline,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        SizedBox(height: 10),
        Text(
          l10n(context).modelsDescription,
          style: TextStyle(color: muted, height: 1.8),
        ),
        SizedBox(height: 24),
        SurfaceCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_user_outlined, color: forest),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n(context).modelVerificationExplanation,
                  style: TextStyle(color: muted, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 20),
        for (final model in models) ...[_model(model), SizedBox(height: 16)],
        if (app.models.error != null)
          Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              friendlyError(context, app.models.error!),
              style: TextStyle(color: Colors.brown),
            ),
          ),
        OutlinedButton.icon(
          onPressed: app.busy || app.models.downloadingId != null
              ? null
              : _import,
          icon: Icon(Icons.folder_open_outlined),
          label: Text(l10n(context).importOfficialModel),
        ),
        SizedBox(height: 20),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: mirror,
          onChanged: app.models.downloadingId != null
              ? null
              : (value) => setState(() => mirror = value),
          title: Text(l10n(context).useModelMirror),
          subtitle: Text(
            l10n(context).modelSourceExplanation,
            style: TextStyle(fontSize: 12),
          ),
        ),
        SizedBox(height: 12),
        Text(
          l10n(context).modelAccuracyExplanation,
          style: TextStyle(fontSize: 12, color: muted),
        ),
      ],
    ),
  );
  Widget _model(ModelSpec model) {
    final installed = app.models.installed.contains(model.id);
    final selected = app.models.activeId == model.id && installed;
    final downloading = app.models.downloadingId == model.id;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.memory, color: forest),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  localizedLabel(context, model.name),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (selected) Icon(Icons.check_circle, color: forest),
            ],
          ),
          SizedBox(height: 12),
          Text(
            localizedLabel(context, model.description),
            style: TextStyle(color: muted, fontSize: 13),
          ),
          SizedBox(height: 12),
          Text(
            l10n(context).modelLanguagesAndLicense(model.sizeLabel),
            style: TextStyle(color: forest, fontSize: 12),
          ),
          SizedBox(height: 18),
          if (downloading) ...[
            LinearProgressIndicator(
              value: app.models.verifying ? null : app.models.progress,
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    app.models.verifying
                        ? l10n(context).verifyingModel
                        : l10n(context).downloadProgress(
                            (app.models.progress * 100).toStringAsFixed(0),
                          ),
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                if (!app.models.verifying)
                  TextButton(
                    onPressed: app.models.cancelDownload,
                    child: Text(l10n(context).cancel),
                  ),
              ],
            ),
          ] else if (installed)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: selected || app.busy
                        ? null
                        : () => app.models.select(model.id),
                    child: Text(
                      selected
                          ? l10n(context).currentModel
                          : l10n(context).selectModel,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  tooltip: l10n(context).deleteModel,
                  onPressed: app.busy || app.models.downloadingId != null
                      ? null
                      : () => _remove(model),
                  icon: Icon(Icons.delete_outline),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: app.busy || app.models.downloadingId != null
                    ? null
                    : () => app.models.download(model, mirror: mirror),
                icon: Icon(Icons.download_outlined),
                label: Text(l10n(context).downloadModelSize(model.sizeLabel)),
              ),
            ),
        ],
      ),
    );
  }
}
