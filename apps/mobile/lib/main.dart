import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'application/app_controller.dart';
import 'ui/app.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  for (final asset in ['WHISPER_LICENSE.txt', 'MODEL_LICENSE.txt']) {
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks([
        asset == 'WHISPER_LICENSE.txt'
            ? 'whisper.cpp / ggml'
            : 'OpenAI Whisper models',
      ], await rootBundle.loadString('assets/licenses/$asset'));
    });
  }
  runApp(const _Bootstrap());
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
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: appTheme(),
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BrandMark(size: 72),
                    const SizedBox(height: 24),
                    if (snapshot.hasError) ...[
                      const Text(
                        '无法打开本地资料库',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('${snapshot.error}', textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => setState(
                          () => _controller = AppController.create(),
                        ),
                        child: const Text('重试'),
                      ),
                    ] else ...[
                      const Text(
                        'LingoScribe',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(),
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
