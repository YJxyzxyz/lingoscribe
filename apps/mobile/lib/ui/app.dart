import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../application/app_controller.dart';
import 'home_screen.dart';
import 'theme.dart';

class LingoScribeApp extends StatelessWidget {
  const LingoScribeApp({super.key, required this.controller, this.fontFamily});
  final AppController controller;
  final String? fontFamily;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '聆写 · LingoScribe',
    debugShowCheckedModeBanner: false,
    theme: appTheme(fontFamily: fontFamily),
    locale: const Locale('zh'),
    supportedLocales: const [Locale('zh'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: ListenableBuilder(
      listenable: controller,
      builder: (context, _) => controller.onboarded
          ? HomeScreen(controller: controller)
          : _Onboarding(controller: controller),
    ),
  );
}

class _Onboarding extends StatelessWidget {
  const _Onboarding({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    BrandMark(),
                    SizedBox(width: 12),
                    Text(
                      'LingoScribe',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 56),
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xffe5eddc),
                    borderRadius: BorderRadius.circular(36),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [BrandMark(size: 110)],
                  ),
                ),
                const SizedBox(height: 36),
                Text(
                  '声音留在这里。\n文字随你前行。',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 16),
                const Text(
                  '把录音变成可回听、可编辑的文字。\n支持中文、英文与双语录音，全程在设备上转写。',
                  style: TextStyle(color: muted, fontSize: 16, height: 1.8),
                ),
                const SizedBox(height: 28),
                const SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PrivacyBadge(),
                      SizedBox(height: 12),
                      Text('无需账号 · 不上传录音 · 没有广告'),
                      SizedBox(height: 8),
                      Text(
                        '首次需联网下载模型，也可以导入已下载的官方模型。之后可以断网转写。模型效果会随设备与录音质量变化。',
                        style: TextStyle(
                          color: muted,
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: controller.finishOnboarding,
                    child: const Text('开始聆写  →'),
                  ),
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    '在录音前，请征得参与者同意。',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
