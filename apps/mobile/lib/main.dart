import 'l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'application/app_controller.dart';
import 'ui/app.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  for (final asset in [
    'WHISPER_LICENSE.txt',
    'MODEL_LICENSE.txt',
    'SILERO_LICENSE.txt',
    'NATIVE_NOTICES.txt',
  ]) {
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks([
        asset == 'WHISPER_LICENSE.txt'
            ? 'whisper.cpp / ggml'
            : asset == 'NATIVE_NOTICES.txt'
            ? 'Native source attributions'
            : asset == 'SILERO_LICENSE.txt'
            ? 'Silero VAD'
            : 'OpenAI Whisper models',
      ], await rootBundle.loadString('assets/licenses/$asset'));
    });
  }
  runApp(_Bootstrap());
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();
  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late Future<AppController> _controller = AppController.create();
  @override
  Widget build(BuildContext context) => FutureBuilder<AppController>(
    future: _controller,
    builder: (context, snapshot) {
      if (snapshot.hasData) return LingoScribeApp(controller: snapshot.data!);
      final messages = localeMessages('system');
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: appTheme(),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        localeResolutionCallback: (locale, _) => locale?.languageCode == 'zh'
            ? const Locale('zh')
            : const Locale('en'),
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BrandMark(size: 72),
                    SizedBox(height: 24),
                    if (snapshot.hasError) ...[
                      Text(
                        messages.libraryUnavailable,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 12),
                      Builder(
                        builder: (context) => Text(
                          friendlyError(context, snapshot.error!),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => setState(
                          () => _controller = AppController.create(),
                        ),
                        child: Text(messages.retry),
                      ),
                    ] else ...[
                      Text(
                        'LingoScribe',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 24),
                      CircularProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
