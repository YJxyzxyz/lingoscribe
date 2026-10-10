import '../l10n/l10n.dart';
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
import 'text_editor_dialog.dart';

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
  int _revision = -1;
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
    if (mounted) setState(() {});
    if (_revision == widget.controller.dataRevision) return;
    _revision = widget.controller.dataRevision;
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
    final value = await showDialog<String>(
      context: context,
      builder: (_) => TextEditorDialog(
        title: l10n(context).proofreadAt(clock(segment.startMs)),
        initialText: segment.text,
        originalText: segment.originalText,
      ),
    );
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
    final value = await showDialog<String>(
      context: context,
      builder: (_) => TextEditorDialog(
        title: l10n(context).rename,
        initialText: item.title,
        singleLine: true,
        requireNonempty: true,
      ),
    );
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
          padding: EdgeInsets.fromLTRB(12, 4, 12, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  l10n(context).exportThisTranscript,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(l10n(context).shareExplanation),
              ),
              for (final format in ExportFormat.values)
                ListTile(
                  leading: Icon(Icons.description_outlined),
                  title: Text(localizedLabel(context, format.label)),
                  trailing: Icon(Icons.chevron_right),
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
        title: Text(l10n(context).deleteTranscriptQuestion),
        content: Text(l10n(context).deleteTranscriptExplanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n(context).keep),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n(context).delete),
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

  Future<void> _newRevision() async {
    try {
      await player.pause();
      final revision = await widget.controller.createRevision(item);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              DetailScreen(controller: widget.controller, initial: revision),
        ),
      );
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
        title: Text(l10n(context).replayAndEdit),
        actions: [
          IconButton(
            tooltip: l10n(context).exportTranscript,
            onPressed: item.segments.isEmpty || exporting ? null : _export,
            icon: Icon(Icons.ios_share_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'rename') {
                _rename();
              } else if (value == 'revision') {
                _newRevision();
              } else {
                _delete();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'rename', child: Text(l10n(context).rename)),
              PopupMenuItem(
                value: 'revision',
                enabled: !widget.controller.busy,
                child: Text(l10n(context).transcribeNewCopy),
              ),
              PopupMenuItem(
                value: 'delete',
                enabled: !widget.controller.busy,
                child: Text(l10n(context).deleteAudioAndTranscript),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: MediaQuery.viewInsetsOf(context).bottom > 0
                            ? 1
                            : 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      SizedBox(height: 10),
                      Text(
                        '${clock(item.durationMs)} · ${localizedLabel(context, statusLabel(item.status))}',
                        style: TextStyle(color: muted, fontSize: 13),
                      ),
                      SizedBox(height: 14),
                      PrivacyBadge(),
                      if (running) ...[
                        SizedBox(height: 20),
                        LinearProgressIndicator(
                          value: widget.controller.phase == '正在设备上转写'
                              ? widget.controller.progress
                              : null,
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                localizedLabel(
                                  context,
                                  widget.controller.phase ??
                                      l10n(context).preparingTranscription,
                                ),
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            if (widget.controller.phase == '正在设备上转写' ||
                                widget.controller.phase == '正在检查可能遗漏的语音' ||
                                widget.controller.phase == '正在检测语音区间')
                              TextButton(
                                onPressed:
                                    widget.controller.cancelTranscription,
                                child: Text(l10n(context).cancel),
                              ),
                          ],
                        ),
                      ],
                      if (item.segments.isNotEmpty) ...[
                        SizedBox(height: 20),
                        TextField(
                          onChanged: (value) =>
                              setState(() => search = value.toLowerCase()),
                          decoration: InputDecoration(
                            hintText: l10n(context).searchThisTranscript,
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                        SizedBox(height: 6),
                        FilterChip(
                          selected: bookmarksOnly,
                          onSelected: (value) =>
                              setState(() => bookmarksOnly = value),
                          avatar: Icon(Icons.bookmark_outline, size: 16),
                          label: Text(l10n(context).bookmarksOnly),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: item.segments.isEmpty
                      ? SingleChildScrollView(
                          padding: EdgeInsets.all(24),
                          child: SurfaceCard(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.text_snippet_outlined,
                                  size: 44,
                                  color: forest,
                                ),
                                SizedBox(height: 18),
                                Text(
                                  item.status == TranscriptStatus.ready
                                      ? l10n(context).noSpeechDetected
                                      : l10n(context).audioKeptLocally,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  item.error != null
                                      ? friendlyError(context, item.error!)
                                      : (item.status == TranscriptStatus.ready
                                            ? l10n(context).checkAudioQuality
                                            : l10n(
                                                context,
                                              ).transcribeWhenReady),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: muted),
                                ),
                                if (!running &&
                                    item.status != TranscriptStatus.ready) ...[
                                  SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: widget.controller.busy
                                          ? null
                                          : _transcribe,
                                      icon: Icon(Icons.auto_awesome_outlined),
                                      label: Text(
                                        l10n(context).startOfflineTranscription,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    widget.controller.models.active != null
                                        ? localizedLabel(
                                            context,
                                            widget
                                                .controller
                                                .models
                                                .active!
                                                .name,
                                          )
                                        : l10n(context).noModelInstalled,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
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
                              return Center(
                                child: Text(
                                  l10n(context).noMatchingSegments,
                                  style: TextStyle(color: muted),
                                ),
                              );
                            }
                            return ListView.separated(
                              padding: EdgeInsets.fromLTRB(24, 4, 24, 24),
                              itemCount: visible.length,
                              separatorBuilder: (_, _) => SizedBox(height: 12),
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
                                          : Color(0xffe2e7df),
                                      width: active ? 1.5 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    color: active
                                        ? Color(0xffedf3e8)
                                        : Colors.white,
                                  ),
                                  padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        alignment: WrapAlignment.spaceBetween,
                                        children: [
                                          TextButton.icon(
                                            onPressed: loading
                                                ? null
                                                : () => _play(
                                                    at: segment.startMs,
                                                  ),
                                            icon: Icon(
                                              Icons.play_arrow,
                                              size: 16,
                                            ),
                                            label: Text(clock(segment.startMs)),
                                          ),
                                          IconButton(
                                            tooltip: segment.bookmarked
                                                ? l10n(context).removeBookmark
                                                : l10n(context).bookmarkSegment,
                                            onPressed: () => _bookmark(index),
                                            icon: Icon(
                                              segment.bookmarked
                                                  ? Icons.bookmark
                                                  : Icons.bookmark_border,
                                              size: 20,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: l10n(context).editSegment,
                                            onPressed: () => _edit(index),
                                            icon: Icon(
                                              Icons.edit_outlined,
                                              size: 18,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SelectableText(
                                        segment.text,
                                        style: TextStyle(
                                          fontSize: 16,
                                          height: 1.8,
                                        ),
                                      ),
                                      if (segment.originalText != null)
                                        Padding(
                                          padding: EdgeInsets.only(top: 8),
                                          child: Text(
                                            l10n(context).edited,
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
                if (MediaQuery.viewInsetsOf(context).bottom == 0) _player(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _player() => Container(
    padding: EdgeInsets.fromLTRB(16, 10, 24, 14),
    decoration: BoxDecoration(
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
                  style: TextStyle(fontSize: 11, color: muted),
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
                  style: TextStyle(fontSize: 11, color: muted),
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
                tooltip: player.playing
                    ? l10n(context).pausePlayback
                    : l10n(context).playAudio,
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
            SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n(context).tapTimestamp,
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ),
            PopupMenuButton<double>(
              tooltip: l10n(context).playbackSpeed,
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
                padding: EdgeInsets.all(12),
                child: Text(
                  '${player.speed}×',
                  style: TextStyle(color: forest, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
