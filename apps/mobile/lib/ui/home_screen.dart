import '../l10n/l10n.dart';
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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int tab = 0;
  Timer? _search;
  Completer<void>? _permissionFocus;
  AppController get app => widget.controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.inactive &&
        !(_permissionFocus?.isCompleted ?? true)) {
      _permissionFocus!.complete();
    }
    if (state != AppLifecycleState.resumed) {
      unawaited(
        app.pauseRecording().catchError((Object error) {
          if (mounted) showError(context, error);
        }),
      );
    }
  }

  Future<void> _settlePermissionFocus() async {
    // The native permission result can arrive just before the dialog restores focus.
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.inactive) {
      return;
    }
    final waiter = _permissionFocus = Completer<void>();
    try {
      await waiter.future.timeout(const Duration(seconds: 1), onTimeout: () {});
    } finally {
      _permissionFocus = null;
    }
  }

  Future<void> _record() async {
    try {
      await app.startRecording(
        isForeground: () =>
            mounted &&
            (WidgetsBinding.instance.lifecycleState == null ||
                WidgetsBinding.instance.lifecycleState ==
                    AppLifecycleState.resumed),
        settlePermissionFocus: _settlePermissionFocus,
      );
      if (!mounted) {
        await app.stopRecording();
        return;
      }
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
    if (!(_permissionFocus?.isCompleted ?? true)) _permissionFocus!.complete();
    WidgetsBinding.instance.removeObserver(this);
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
            constraints: BoxConstraints(maxWidth: 760),
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
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books),
            label: l10n(context).library,
          ),
          NavigationDestination(
            icon: Icon(Icons.memory_outlined),
            selectedIcon: Icon(Icons.memory),
            label: l10n(context).offlineModels,
          ),
          NavigationDestination(
            icon: Icon(Icons.tune),
            label: l10n(context).settings,
          ),
        ],
      ),
    ),
  );
  Widget _library() => Column(
    children: [
      Expanded(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _libraryHeader()),
            if (app.items.isEmpty)
              SliverToBoxAdapter(child: _empty())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
                sliver: SliverList.separated(
                  itemCount: app.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _item(app.items[index]),
                ),
              ),
          ],
        ),
      ),
      if (MediaQuery.viewInsetsOf(context).bottom == 0) _libraryActions(),
    ],
  );
  Widget _libraryHeader() => Padding(
    padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            BrandMark(size: 34),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n(context).brandName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: l10n(context).transcriptionPreferences,
              onPressed: () => setState(() => tab = 2),
              icon: Icon(Icons.tune),
            ),
          ],
        ),
        SizedBox(height: 28),
        Text(
          l10n(context).yourAudioLibrary,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        SizedBox(height: 8),
        PrivacyBadge(),
        SizedBox(height: 24),
        TextField(
          onChanged: (value) {
            _search?.cancel();
            _search = Timer(
              Duration(milliseconds: 180),
              () => unawaited(app.refresh(query: value)),
            );
          },
          decoration: InputDecoration(
            hintText: l10n(context).searchLibrary,
            prefixIcon: Icon(Icons.search),
          ),
        ),
        SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(
              app.query.isEmpty
                  ? l10n(context).allRecords
                  : l10n(context).searchResults,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              l10n(context).recordCount(app.items.length),
              style: TextStyle(color: muted),
            ),
          ],
        ),
        if (app.importing || app.taskId != null || app.startingRecording) ...[
          SizedBox(height: 16),
          LinearProgressIndicator(
            value:
                app.importing || app.startingRecording || app.phase != '正在设备上转写'
                ? null
                : app.progress,
          ),
          SizedBox(height: 8),
          Text(
            app.startingRecording
                ? l10n(context).preparingRecording
                : localizedLabel(context, app.phase ?? ''),
            style: TextStyle(color: forest, fontSize: 13),
          ),
        ],
        SizedBox(height: 12),
      ],
    ),
  );
  Widget _libraryActions() => Padding(
    padding: EdgeInsets.fromLTRB(24, 12, 24, 18),
    child: Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: app.busy ? null : _record,
            icon: Icon(Icons.mic_none),
            label: Text(l10n(context).startRecording),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: app.busy ? null : _import,
            icon: Icon(Icons.file_upload_outlined),
            label: Text(l10n(context).importAudio),
          ),
        ),
      ],
    ),
  );
  Widget _empty() => SingleChildScrollView(
    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 30),
    child: Column(
      children: [
        Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xffe7eedf),
          ),
          child: Icon(
            app.query.isEmpty ? Icons.graphic_eq : Icons.search_off,
            size: 46,
            color: forest,
          ),
        ),
        SizedBox(height: 22),
        Text(
          app.query.isEmpty
              ? l10n(context).emptyLibraryTitle
              : l10n(context).noRecordsFound,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: 10),
        Text(
          app.query.isEmpty
              ? l10n(context).emptyLibraryDescription
              : l10n(context).tryAnotherKeyword,
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, height: 1.8),
        ),
        if (app.models.active == null && app.query.isEmpty) ...[
          SizedBox(height: 24),
          TextButton.icon(
            onPressed: () => setState(() => tab = 1),
            icon: Icon(Icons.download_outlined, size: 18),
            label: Text(l10n(context).prepareOfflineModel),
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
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Color(0xffedf3e8),
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
              SizedBox(width: 12),
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
                    SizedBox(height: 4),
                    Text(
                      '${value.createdAt.month}/${value.createdAt.day} · ${clock(value.durationMs)}',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.chevron_right, color: muted),
            ],
          ),
          SizedBox(height: 14),
          if (value.preview.isNotEmpty)
            Text(
              value.preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: muted),
            ),
          SizedBox(height: 10),
          Text(
            localizedLabel(context, statusLabel(value.status)),
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
