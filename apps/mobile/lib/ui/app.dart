import '../l10n/l10n.dart';
import 'package:flutter/material.dart';
import '../application/app_controller.dart';
import 'home_screen.dart';
import 'theme.dart';

class LingoScribeApp extends StatelessWidget {
  const LingoScribeApp({super.key, required this.controller, this.fontFamily});
  final AppController controller;
  final String? fontFamily;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: controller.displayLanguage,
    builder: (context, language, _) => MaterialApp(
      title: 'LingoScribe',
      debugShowCheckedModeBanner: false,
      theme: appTheme(fontFamily: fontFamily),
      locale: language == 'system' ? null : Locale(language),
      localeResolutionCallback: (locale, _) => locale?.languageCode == 'zh'
          ? const Locale('zh')
          : const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => controller.onboarded
            ? HomeScreen(controller: controller)
            : _Onboarding(controller: controller),
      ),
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
          constraints: BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                SizedBox(height: 56),
                Container(
                  padding: EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Color(0xffe5eddc),
                    borderRadius: BorderRadius.circular(36),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [BrandMark(size: 110)],
                  ),
                ),
                SizedBox(height: 36),
                Text(
                  l10n(context).onboardingHeadline,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                SizedBox(height: 16),
                Text(
                  l10n(context).onboardingDescription,
                  style: TextStyle(color: muted, fontSize: 16, height: 1.8),
                ),
                SizedBox(height: 28),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PrivacyBadge(),
                      SizedBox(height: 12),
                      Text(l10n(context).noAccountNoAds),
                      SizedBox(height: 8),
                      Text(
                        l10n(context).firstModelExplanation,
                        style: TextStyle(
                          color: muted,
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: controller.finishOnboarding,
                    child: Text(l10n(context).getStarted),
                  ),
                ),
                SizedBox(height: 12),
                Center(
                  child: Text(
                    l10n(context).recordingConsent,
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
