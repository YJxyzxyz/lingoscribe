import '../l10n/l10n.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../application/app_controller.dart';
import '../domain/transcript.dart';
import 'detail_screen.dart';
import 'theme.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen>
    with WidgetsBindingObserver {
  bool saving = false;
  final List<double> levels = [];
  Timer? _meter;
  String? _recordingId;
  String? _lastLimitError;
  @override
  void initState() {
    super.initState();
    _recordingId = widget.controller.recording?.id;
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onLimitSaved);
    _meter = Timer.periodic(Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {
        levels.add(
          widget.controller.paused
              ? 0
              : ((widget.controller.amplitude + 60) / 60).clamp(0, 1),
        );
        if (levels.length > 36) levels.removeAt(0);
      });
    });
  }

  void _onLimitSaved() {
    if (!mounted || saving) return;
    final error = widget.controller.recordingLimitError;
    if (error != null && error != _lastLimitError) {
      _lastLimitError = error;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showError(context, error);
      });
    }
    final saved = widget.controller.autoSavedRecording;
    if (saved == null || saved.id != _recordingId) return;
    setState(() => saving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showSaved(saved);
    });
  }

  void _showSaved(Transcript item) => Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) =>
          DetailScreen(controller: widget.controller, initial: item),
    ),
  );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        widget.controller.recording != null &&
        !widget.controller.paused) {
      unawaited(
        widget.controller.togglePause().catchError((Object e) {
          if (mounted) showError(context, e);
        }),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_onLimitSaved);
    _meter?.cancel();
    super.dispose();
  }

  Future<void> _save() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      final item = await widget.controller.stopRecording();
      if (!mounted) return;
      if (item == null) {
        Navigator.pop(context);
        return;
      }
      _showSaved(item);
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        showError(context, e);
      }
    }
  }

  Future<void> _discard() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n(context).discardRecordingQuestion),
        content: Text(l10n(context).discardRecordingExplanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n(context).resumeRecording),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n(context).discard),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await widget.controller.stopRecording(discard: true);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: widget.controller.recording == null,
    onPopInvokedWithResult: (popped, _) {
      if (!popped && !saving) _discard();
    },
    child: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(l10n(context).listening),
          actions: [
            TextButton(
              onPressed: saving ? null : _discard,
              child: Text(l10n(context).discard),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(28),
                child: Column(
                  children: [
                    SizedBox(height: 36),
                    PrivacyBadge(),
                    SizedBox(height: 48),
                    Text(
                      clock(widget.controller.recordingMs, hours: true),
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w300,
                        color: ink,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      widget.controller.paused
                          ? l10n(context).pausedRecording
                          : l10n(context).recordingMoment,
                      style: TextStyle(color: muted),
                    ),
                    SizedBox(height: 36),
                    SizedBox(
                      height: 110,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _MeterPainter(List.of(levels)),
                      ),
                    ),
                    SizedBox(height: 36),
                    OutlinedButton.icon(
                      onPressed: saving
                          ? null
                          : () async {
                              try {
                                await widget.controller.togglePause();
                              } catch (e) {
                                if (context.mounted) showError(context, e);
                              }
                            },
                      icon: Icon(
                        widget.controller.paused
                            ? Icons.play_arrow
                            : Icons.pause,
                      ),
                      label: Text(
                        widget.controller.paused
                            ? l10n(context).resumeRecording
                            : l10n(context).pauseRecording,
                      ),
                    ),
                    SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: saving ? null : _save,
                        icon: Icon(Icons.stop_rounded),
                        label: Text(
                          saving
                              ? l10n(context).saving
                              : l10n(context).stopAndSave,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      l10n(context).backgroundPauseExplanation,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: muted, height: 1.8),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _MeterPainter extends CustomPainter {
  _MeterPainter(this.values);
  final List<double> values;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = forest
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;
    for (var i = 0; i < 36; i++) {
      final value = i < 36 - values.length
          ? 0.0
          : values[i - (36 - values.length)];
      final height = 5 + value * (size.height - 8);
      final x = size.width * (i + .5) / 36;
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MeterPainter oldDelegate) => true;
}
