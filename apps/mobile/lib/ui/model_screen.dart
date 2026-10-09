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
        title: const Text('删除这个模型？'),
        content: Text('释放 ${model.sizeLabel}。你的录音和转写内容会保留，以后可以重新下载模型。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('保留'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除模型'),
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
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 20),
        Text('把 AI 留在本机', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        const Text(
          '下载一次，离线使用。\n模型只处理本地音频，录音不会上传。',
          style: TextStyle(color: muted, height: 1.8),
        ),
        const SizedBox(height: 24),
        const SurfaceCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_user_outlined, color: forest),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '每个模型安装前都会验证 SHA-256。转写前再次检查文件，确保模型完整。',
                  style: TextStyle(color: muted, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        for (final model in models) ...[
          _model(model),
          const SizedBox(height: 16),
        ],
        if (app.models.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              app.models.error!,
              style: const TextStyle(color: Colors.brown),
            ),
          ),
        OutlinedButton.icon(
          onPressed: app.busy || app.models.downloadingId != null
              ? null
              : _import,
          icon: const Icon(Icons.folder_open_outlined),
          label: const Text('从文件导入官方模型'),
        ),
        const SizedBox(height: 20),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: mirror,
          onChanged: app.models.downloadingId != null
              ? null
              : (value) => setState(() => mirror = value),
          title: const Text('使用备用模型下载站'),
          subtitle: const Text(
            '默认 Hugging Face；备用 hf-mirror.com。下载站会收到 IP 和模型请求，不会收到录音。',
            style: TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '准确率取决于录音质量、语言及模型。更大模型通常需要更多内存和处理时间；尚未对本设备测得速度。',
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
              const Icon(Icons.memory, color: forest),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  model.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (selected) const Icon(Icons.check_circle, color: forest),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            model.description,
            style: const TextStyle(color: muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Text(
            '${model.sizeLabel} · 中文 / English · MIT',
            style: const TextStyle(color: forest, fontSize: 12),
          ),
          const SizedBox(height: 18),
          if (downloading) ...[
            LinearProgressIndicator(
              value: app.models.verifying ? null : app.models.progress,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    app.models.verifying
                        ? '正在校验模型…'
                        : '下载 ${(app.models.progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                if (!app.models.verifying)
                  TextButton(
                    onPressed: app.models.cancelDownload,
                    child: const Text('取消'),
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
                    child: Text(selected ? '当前使用' : '使用这个模型'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: '删除模型',
                  onPressed: app.busy || app.models.downloadingId != null
                      ? null
                      : () => _remove(model),
                  icon: const Icon(Icons.delete_outline),
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
                icon: const Icon(Icons.download_outlined),
                label: Text('下载 ${model.sizeLabel}'),
              ),
            ),
        ],
      ),
    );
  }
}
