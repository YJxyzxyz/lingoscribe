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
    padding: const EdgeInsets.all(24),
    children: [
      const SizedBox(height: 20),
      Text('按你的方式聆写', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 24),
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '新录音与导入的默认偏好',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: widget.controller.language,
              decoration: const InputDecoration(labelText: '音频语言'),
              items: const [
                DropdownMenuItem(value: 'auto', child: Text('自动识别 · 包括中英混合')),
                DropdownMenuItem(value: 'zh', child: Text('中文')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (value) {
                if (value != null) widget.controller.settings(language: value);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _terms,
              minLines: 3,
              maxLines: 5,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: '术语提示',
                hintText: '例如：LingoScribe、产品名、人名、专业术语',
              ),
              onChanged: (value) => widget.controller.settings(prompt: value),
            ),
            const Text(
              '术语会作为模型提示，不能保证识别结果。不会修改已保存记录的设置。',
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PrivacyBadge(),
            SizedBox(height: 14),
            Text('隐私是默认设置', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 10),
            Text(
              '录音、导入音频、转写与搜索均在本机处理。应用没有账号、广告或统计 SDK，也不会上传这些内容。\n\n联网仅用于你主动下载模型。主动导出和分享后，接收应用会按照自己的隐私规则处理文件。\n\n数据保存在系统应用沙箱中；未使用额外的应用级加密。卸载应用会删除本地资料，请先导出重要内容。',
              style: TextStyle(fontSize: 13, color: muted),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      ListTile(
        leading: const Icon(Icons.cleaning_services_outlined),
        title: const Text('清除临时导出缓存'),
        subtitle: const Text(
          '保留录音与资料库，已分享的副本不受影响。',
          style: TextStyle(fontSize: 12),
        ),
        onTap: () async {
          try {
            final count = await clearExportCache();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(count == 0 ? '没有临时导出文件' : '已清理 $count 个临时导出文件'),
                ),
              );
            }
          } catch (e) {
            if (context.mounted) showError(context, e);
          }
        },
      ),
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: const Icon(Icons.code_outlined),
        title: const Text('开源许可'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showLicensePage(
          context: context,
          applicationName: 'LingoScribe · 聆写',
          applicationVersion: '0.1.0',
        ),
      ),
      const Divider(),
      const SizedBox(height: 12),
      const Row(
        children: [
          BrandMark(size: 30),
          SizedBox(width: 10),
          Text('LingoScribe  0.1.0', style: TextStyle(color: muted)),
        ],
      ),
      const SizedBox(height: 12),
      const Text(
        '请征得录音参与者同意。AI 转写可能有误，重要信息请回听核对。转写期间保持应用在前台，长音频建议连接电源。',
        style: TextStyle(fontSize: 12, color: muted),
      ),
    ],
  );
}
