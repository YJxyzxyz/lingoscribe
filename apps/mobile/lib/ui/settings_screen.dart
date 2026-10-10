import '../l10n/l10n.dart';
import 'package:flutter/material.dart';
import '../application/app_controller.dart';
import '../services/export_service.dart';
import 'theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _terms = TextEditingController(text: widget.controller.prompt);
  @override
  void dispose() {
    _terms.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.all(24),
    children: [
      SizedBox(height: 20),
      Text(
        l10n(context).settingsHeadline,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      SizedBox(height: 24),
      DropdownButtonFormField<String>(
        initialValue: widget.controller.displayLanguage.value,
        decoration: InputDecoration(labelText: l10n(context).interfaceLanguage),
        items: [
          DropdownMenuItem(
            value: 'system',
            child: Text(l10n(context).followSystem),
          ),
          const DropdownMenuItem(value: 'zh', child: Text('中文')),
          const DropdownMenuItem(value: 'en', child: Text('English')),
        ],
        onChanged: (value) {
          if (value != null) widget.controller.setDisplayLanguage(value);
        },
      ),
      const SizedBox(height: 20),
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n(context).newAudioDefaults,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: widget.controller.language,
              decoration: InputDecoration(
                labelText: l10n(context).audioLanguage,
              ),
              items: [
                DropdownMenuItem(
                  value: 'auto',
                  child: Text(l10n(context).autoLanguage),
                ),
                DropdownMenuItem(
                  value: 'zh',
                  child: Text(l10n(context).chinese),
                ),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (value) {
                if (value != null) widget.controller.settings(language: value);
              },
            ),
            SizedBox(height: 16),
            TextField(
              controller: _terms,
              minLines: 3,
              maxLines: 5,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: l10n(context).glossaryPrompt,
                hintText: l10n(context).glossaryHint,
              ),
              onChanged: (value) => widget.controller.settings(prompt: value),
            ),
            Text(
              l10n(context).glossaryExplanation,
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ],
        ),
      ),
      SizedBox(height: 20),
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PrivacyBadge(),
            SizedBox(height: 14),
            Text(
              l10n(context).privacyByDefault,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 10),
            Text(
              l10n(context).privacyDescription,
              style: TextStyle(fontSize: 13, color: muted),
            ),
          ],
        ),
      ),
      SizedBox(height: 20),
      ListTile(
        leading: Icon(Icons.cleaning_services_outlined),
        title: Text(l10n(context).clearExportCache),
        subtitle: Text(
          l10n(context).exportCacheExplanation,
          style: TextStyle(fontSize: 12),
        ),
        onTap: () async {
          try {
            final count = await clearExportCache();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    count == 0
                        ? l10n(context).noTemporaryExports
                        : l10n(context).exportFilesCleared(count),
                  ),
                ),
              );
            }
          } catch (e) {
            if (context.mounted) showError(context, e);
          }
        },
      ),
      ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 12),
        leading: Icon(Icons.code_outlined),
        title: Text(l10n(context).openSourceLicenses),
        trailing: Icon(Icons.chevron_right),
        onTap: () => showLicensePage(
          context: context,
          applicationName: l10n(context).licenseApplicationName,
          applicationVersion: '0.1.0',
        ),
      ),
      Divider(),
      SizedBox(height: 12),
      Row(
        children: [
          BrandMark(size: 30),
          SizedBox(width: 10),
          Text('LingoScribe  0.1.0', style: TextStyle(color: muted)),
        ],
      ),
      SizedBox(height: 12),
      Text(
        l10n(context).usageReminder,
        style: TextStyle(fontSize: 12, color: muted),
      ),
    ],
  );
}
