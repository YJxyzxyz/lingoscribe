import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../application/app_controller.dart';
import '../domain/transcript.dart';
import '../services/export_service.dart';
import 'home_screen.dart';
import 'theme.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({
    super.key,
    required this.controller,
    required this.initial,
  });
  final AppController controller;
  final Transcript initial;
  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late Transcript item = widget.initial;
  final player = AudioPlayer();
  StreamSubscription<PlayerException>? _errors;
  bool loading = true, bookmarksOnly = false, exporting = false;
  String search = '';
  int _serial = 0;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    _errors = player.errorStream.listen((error) {
      if (mounted) showError(context, '回放失败：${error.message}');
    });
    unawaited(_loadAudio());
  }

  Future<void> _loadAudio() async {
    try {
      final normalized = File(
        p.join(
          widget.controller.root.path,
          'audio',
          '${item.id}.normalized.wav',
        ),
      );
      await player.setFilePath(
        await normalized.exists() ? normalized.path : item.audioPath,
      );
    } catch (e) {
      if (mounted) showError(context, '无法回放音频：$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _refresh() {
    final serial = ++_serial;
    unawaited(
      widget.controller.find(item.id).then((value) {
        if (mounted && serial == _serial && value != null) {
          setState(() => item = value);
        }
      }),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    unawaited(_errors?.cancel());
    unawaited(player.dispose());
    super.dispose();
  }

  Future<void> _edit(int index) async {
    final segment = item.segments[index];
    final text = TextEditingController(text: segment.text);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('校对 ${clock(segment.startMs)}'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: text,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 8,
                  maxLength: 10000,
                  decoration: const InputDecoration(labelText: '转写内容'),
                ),
                if (segment.originalText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      '原始转写：${segment.originalText}',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, text.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    text.dispose();
    if (value == null) return;
    final segments = List<Segment>.of(item.segments);
    segments[index] = segment.edit(value.trim());
    try {
      await widget.controller.save(item.copyWith(segments: segments));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _bookmark(int index) async {
    final segments = List<Segment>.of(item.segments);
    segments[index] = segments[index].toggleBookmark();
    try {
      await widget.controller.save(item.copyWith(segments: segments));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _rename() async {
    final text = TextEditingController(text: item.title);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(controller: text, maxLength: 120, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (text.text.trim().isNotEmpty) {
                Navigator.pop(context, text.text.trim());
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    text.dispose();
    if (value != null) {
      try {
        await widget.controller.save(item.copyWith(title: value));
      } catch (e) {
        if (mounted) showError(context, e);
      }
    }
  }

  Future<void> _export() async {
    final format = await showModalBottomSheet<ExportFormat>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  '导出这份转写',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('只在你主动分享时，文件才会交给其他应用。'),
              ),
              for (final format in ExportFormat.values)
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(format.label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, format),
                ),
            ],
          ),
        ),
      ),
    );
    if (format == null || !mounted) return;
    setState(() => exporting = true);
    try {
      final directory = Directory(
        p.join((await getTemporaryDirectory()).path, 'lingoscribe-exports'),
      );
      await directory.create(recursive: true);
      final file = File(
        p.join(
          directory.path,
          '${safeExportName(item.title)}.${format.extension}',
        ),
      );
      await file.writeAsString(exportTranscript(item, format), flush: true);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          title: item.title,
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除音频和转写？'),
        content: const Text('删除后无法恢复。已经分享给其他应用的文件不会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('保留'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await player.stop();
        await widget.controller.remove(item);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) showError(context, e);
      }
    }
  }

  Future<void> _transcribe() async {
    try {
      await player.pause();
      await widget.controller.transcribe(item);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _play({int? at}) async {
    try {
      if (at != null) await player.seek(Duration(milliseconds: at));
      if (at == null && player.playing) {
        await player.pause();
        return;
      }
      if (player.processingState == ProcessingState.completed) {
        await player.seek(Duration.zero);
      }
      unawaited(
        player.play().catchError((Object e) {
          if (mounted) showError(context, e);
        }),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final running = widget.controller.taskId == item.id;
    return Scaffold(
      appBar: AppBar(
        title: const Text('回听与校对'),
        actions: [
          IconButton(
            tooltip: '导出转写',
            onPressed: item.segments.isEmpty || exporting ? null : _export,
            icon: const Icon(Icons.ios_share_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'rename') {
                _rename();
              } else {
                _delete();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'rename', child: Text('重命名')),
              PopupMenuItem(
                value: 'delete',
                enabled: !running,
                child: const Text('删除音频和转写'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${clock(item.durationMs)} · ${statusLabel(item.status)}',
                        style: const TextStyle(color: muted, fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      const PrivacyBadge(),
                      if (running) ...[
                        const SizedBox(height: 20),
                        LinearProgressIndicator(
                          value: widget.controller.phase == '正在设备上转写'
                              ? widget.controller.progress
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.controller.phase ?? '准备转写',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            if (widget.controller.phase == '正在设备上转写')
                              TextButton(
                                onPressed:
                                    widget.controller.cancelTranscription,
                                child: const Text('取消'),
                              ),
                          ],
                        ),
                      ],
                      if (item.segments.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        TextField(
                          onChanged: (value) =>
                              setState(() => search = value.toLowerCase()),
                          decoration: const InputDecoration(
                            hintText: '在这份转写中查找',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                        const SizedBox(height: 6),
                        FilterChip(
                          selected: bookmarksOnly,
                          onSelected: (value) =>
                              setState(() => bookmarksOnly = value),
                          avatar: const Icon(Icons.bookmark_outline, size: 16),
                          label: const Text('只看标记'),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: item.segments.isEmpty
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: SurfaceCard(
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.text_snippet_outlined,
                                  size: 44,
                                  color: forest,
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  item.status == TranscriptStatus.ready
                                      ? '没有识别到可转写的语音'
                                      : '音频已留在本机',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  item.error ??
                                      (item.status == TranscriptStatus.ready
                                          ? '请回听确认是否包含清晰的语音。'
                                          : '准备好模型后，把它写成文字。'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: muted),
                                ),
                                if (!running &&
                                    item.status != TranscriptStatus.ready) ...[
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: widget.controller.busy
                                          ? null
                                          : _transcribe,
                                      icon: const Icon(
                                        Icons.auto_awesome_outlined,
                                      ),
                                      label: const Text('开始离线转写'),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    widget.controller.models.active?.name ??
                                        '尚未安装模型：返回“离线模型”下载或导入。',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: muted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : StreamBuilder<Duration>(
                          stream: player.positionStream,
                          builder: (context, snapshot) {
                            final position = snapshot.data?.inMilliseconds ?? 0;
                            final visible = item.segments
                                .asMap()
                                .entries
                                .where(
                                  (entry) =>
                                      (!bookmarksOnly ||
                                          entry.value.bookmarked) &&
                                      entry.value.text.toLowerCase().contains(
                                        search,
                                      ),
                                )
                                .toList();
                            if (visible.isEmpty) {
                              return const Center(
                                child: Text(
                                  '没有符合条件的段落',
                                  style: TextStyle(color: muted),
                                ),
                              );
                            }
                            return ListView.separated(
                              padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                              itemCount: visible.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, i) {
                                final index = visible[i].key;
                                final segment = visible[i].value;
                                final active =
                                    position >= segment.startMs &&
                                    position < segment.endMs;
                                return Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: active
                                          ? forest
                                          : const Color(0xffe2e7df),
                                      width: active ? 1.5 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    color: active
                                        ? const Color(0xffedf3e8)
                                        : Colors.white,
                                  ),
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    16,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          TextButton.icon(
                                            onPressed: loading
                                                ? null
                                                : () => _play(
                                                    at: segment.startMs,
                                                  ),
                                            icon: const Icon(
                                              Icons.play_arrow,
                                              size: 16,
                                            ),
                                            label: Text(clock(segment.startMs)),
                                          ),
                                          const Spacer(),
                                          IconButton(
                                            tooltip: segment.bookmarked
                                                ? '取消标记'
                                                : '标记段落',
                                            onPressed: () => _bookmark(index),
                                            icon: Icon(
                                              segment.bookmarked
                                                  ? Icons.bookmark
                                                  : Icons.bookmark_border,
                                              size: 20,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: '编辑段落',
                                            onPressed: () => _edit(index),
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                              size: 18,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SelectableText(
                                        segment.text,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          height: 1.8,
                                        ),
                                      ),
                                      if (segment.originalText != null)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 8),
                                          child: Text(
                                            '已校对',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: muted,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
                _player(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _player() => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 24, 14),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Color(0xffe2e7df))),
    ),
    child: Column(
      children: [
        StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (context, snapshot) {
            final total = player.duration?.inMilliseconds ?? item.durationMs;
            final position = (snapshot.data?.inMilliseconds ?? 0).clamp(
              0,
              total > 0 ? total : 1,
            );
            return Row(
              children: [
                Text(
                  clock(position),
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
                Expanded(
                  child: Slider(
                    value: position.toDouble(),
                    max: (total > 0 ? total : 1).toDouble(),
                    onChanged: loading
                        ? null
                        : (value) => player.seek(
                            Duration(milliseconds: value.toInt()),
                          ),
                  ),
                ),
                Text(
                  clock(total),
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
              ],
            );
          },
        ),
        Row(
          children: [
            StreamBuilder<PlayerState>(
              stream: player.playerStateStream,
              builder: (context, snapshot) => IconButton.filled(
                tooltip: player.playing ? '暂停回放' : '回放音频',
                onPressed: loading ? null : () => _play(),
                icon: Icon(
                  snapshot.data?.playing == true &&
                          snapshot.data?.processingState !=
                              ProcessingState.completed
                      ? Icons.pause
                      : Icons.play_arrow,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '点击时间戳回听原音',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ),
            PopupMenuButton<double>(
              tooltip: '播放速度',
              onSelected: (value) async {
                await player.setSpeed(value);
                if (mounted) setState(() {});
              },
              itemBuilder: (_) => [.75, 1.0, 1.25, 1.5, 2.0]
                  .map(
                    (speed) =>
                        PopupMenuItem(value: speed, child: Text('$speed×')),
                  )
                  .toList(),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '${player.speed}×',
                  style: const TextStyle(color: forest, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
