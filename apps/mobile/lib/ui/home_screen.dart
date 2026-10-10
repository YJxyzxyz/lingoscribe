import 'dart:async';
import 'package:flutter/material.dart';
import '../application/app_controller.dart';
import '../domain/transcript.dart';
import 'detail_screen.dart';
import 'model_screen.dart';
import 'recording_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  Timer? _search;
  AppController get app => widget.controller;
  Future<void> _record() async {
    try {
      await app.startRecording();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RecordingScreen(controller: app)),
      );
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _import() async {
    try {
      final item = await app.importAudio();
      if (item != null && mounted) _open(item);
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  void _open(Transcript item) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => DetailScreen(controller: app, initial: item),
    ),
  );
  Future<void> _openSaved(String id) async {
    try {
      final item = await app.find(id);
      if (item != null && mounted) _open(item);
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  void dispose() {
    _search?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: app,
    builder: (context, _) => Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: switch (tab) {
              1 => ModelScreen(controller: app),
              2 => SettingsScreen(controller: app),
              _ => _library(),
            },
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books),
            label: '资料库',
          ),
          NavigationDestination(
            icon: Icon(Icons.memory_outlined),
            selectedIcon: Icon(Icons.memory),
            label: '离线模型',
          ),
          NavigationDestination(icon: Icon(Icons.tune), label: '设置'),
        ],
      ),
    ),
  );
  Widget _library() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const BrandMark(size: 34),
                const SizedBox(width: 10),
                const Text(
                  '聆写',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '转写偏好',
                  onPressed: () => setState(() => tab = 2),
                  icon: const Icon(Icons.tune),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text('你的声音资料库', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const PrivacyBadge(),
            const SizedBox(height: 24),
            TextField(
              onChanged: (value) {
                _search?.cancel();
                _search = Timer(
                  const Duration(milliseconds: 180),
                  () => unawaited(app.refresh(query: value)),
                );
              },
              decoration: const InputDecoration(
                hintText: '搜索标题或转写内容',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  app.query.isEmpty ? '全部记录' : '搜索结果',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  '${app.items.length} 条',
                  style: const TextStyle(color: muted),
                ),
              ],
            ),
            if (app.importing || app.taskId != null) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: app.importing || app.phase != '正在设备上转写'
                    ? null
                    : app.progress,
              ),
              const SizedBox(height: 8),
              Text(
                app.phase ?? '',
                style: const TextStyle(color: forest, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
      Expanded(
        child: app.items.isEmpty
            ? _empty()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
                itemCount: app.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _item(app.items[index]),
              ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: app.busy ? null : _record,
                icon: const Icon(Icons.mic_none),
                label: const Text('开始录音'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: app.busy ? null : _import,
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('导入音频'),
              ),
            ),
          ],
        ),
      ),
    ],
  );
  Widget _empty() => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 30),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xffe7eedf),
          ),
          child: Icon(
            app.query.isEmpty ? Icons.graphic_eq : Icons.search_off,
            size: 46,
            color: forest,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          app.query.isEmpty ? '给声音一个归处' : '没有找到相关记录',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Text(
          app.query.isEmpty ? '录下一个想法，或导入一段访谈。\n你的录音和文字只保存在本机。' : '试试不同的关键词。',
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted, height: 1.8),
        ),
        if (app.models.active == null && app.query.isEmpty) ...[
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () => setState(() => tab = 1),
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('先准备离线模型'),
          ),
        ],
      ],
    ),
  );
  Widget _item(TranscriptSummary value) => InkWell(
    borderRadius: BorderRadius.circular(24),
    onTap: () => _openSaved(value.id),
    child: SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xffedf3e8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  value.source == 'import'
                      ? Icons.audio_file_outlined
                      : Icons.mic_none,
                  color: forest,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${value.createdAt.month}/${value.createdAt.day} · ${clock(value.durationMs)}',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: muted),
            ],
          ),
          const SizedBox(height: 14),
          if (value.preview.isNotEmpty)
            Text(
              value.preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: muted),
            ),
          const SizedBox(height: 10),
          Text(
            statusLabel(value.status),
            style: TextStyle(
              fontSize: 12,
              color: value.status == TranscriptStatus.failed
                  ? Colors.brown
                  : forest,
            ),
          ),
        ],
      ),
    ),
  );
}

String statusLabel(TranscriptStatus value) => switch (value) {
  TranscriptStatus.recording => '录音中',
  TranscriptStatus.saved => '音频已保存 · 待转写',
  TranscriptStatus.transcribing => '本地转写中',
  TranscriptStatus.ready => '转写完成',
  TranscriptStatus.failed => '转写失败 · 可重试',
  TranscriptStatus.interrupted => '任务中断 · 音频已保留',
};
