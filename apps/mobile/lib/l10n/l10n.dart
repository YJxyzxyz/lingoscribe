import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/widgets.dart';
import 'generated/app_localizations.dart';
import 'generated/app_localizations_en.dart';
import 'generated/app_localizations_zh.dart';

export 'generated/app_localizations.dart';

AppLocalizations localeMessages(String preference) {
  final language = preference == 'system'
      ? PlatformDispatcher.instance.locale.languageCode
      : preference;
  return language == 'zh' ? AppLocalizationsZh() : AppLocalizationsEn();
}

final _fallbackZh = AppLocalizationsZh();
AppLocalizations l10n(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    _fallbackZh;

final _translations = Expando<Map<String, String>>();

/// Translate application-owned status and model labels. Never translate user text.
String localizedLabel(BuildContext context, String text) {
  final messages = l10n(context);
  final values = _translations[messages] ??= <String, String>{
    "无法打开本地资料库": messages.libraryUnavailable,
    "重试": messages.retry,
    "任务被中断，音频已恢复或确认可读取，可重试转写。": messages.recordingRecovered,
    "请先结束当前任务": messages.finishCurrentTask,
    "需要麦克风权限才能录音，请在系统设置中允许。": messages.microphonePermission,
    "录音已停止，保存记录失败。请重启应用以恢复本地音频。": messages.recordingSaveFailed,
    "录音中断，已恢复本地音频，可继续转写。": messages.recordingInterrupted,
    "录音未正常结束。请检查麦克风权限后重新录音。": messages.recordingIncomplete,
    "正在导入音频": messages.importingAudio,
    "文件超过 2 GB，请先裁剪音频": messages.fileTooLarge,
    "请先复制或导出已有校对文本，重转写功能暂不覆盖已有内容": messages.preserveEditsBeforeRetry,
    "请在模型管理中下载或导入模型，然后离线转写": messages.prepareModelFirst,
    "正在验证本地模型": messages.verifyingLocalModel,
    "正在准备音频": messages.preparingAudio,
    "正在设备上转写": messages.transcribingOnDevice,
    "正在载入本地模型": messages.loadingLocalModel,
    "正在检查可能遗漏的语音": messages.checkingSpeechGaps,
    "正在检测语音区间": messages.detectingSpeech,
    "转写已取消，音频已保留。": messages.transcriptionCancelled,
    "正在准备新转写": messages.preparingRevision,
    "任务被中断，音频已保留，请重试。": messages.taskInterrupted,
    "内置语音检测模型校验失败": messages.detectorIntegrityFailed,
    "纯文本 · TXT": messages.exportText,
    "笔记 · Markdown": messages.exportMarkdown,
    "字幕 · SRT": messages.exportSrt,
    "网页字幕 · VTT": messages.exportVtt,
    "完整数据 · JSON": messages.exportJson,
    "轻量 · Base": messages.baseModel,
    "较小下载体积，适合短笔记。多语言，Q5 量化。": messages.baseModelDescription,
    "精细 · Small": messages.smallModel,
    "更大的多语言模型，适合访谈与双语录音。速度与内存取决于设备。": messages.smallModelDescription,
    "模型校验失败，请重新下载官方模型": messages.modelIntegrityFailed,
    "请先下载或导入一个模型": messages.modelRequired,
    "下载已取消": messages.downloadCancelled,
    "模型文件大小异常": messages.modelSizeInvalid,
    "请等待当前模型操作完成": messages.waitForModelOperation,
    "只支持目录中列出的官方 Base / Small Q5 模型": messages.officialModelsOnly,
    "聆写 · LingoScribe": messages.applicationTitle,
    "声音留在这里。\n文字随你前行。": messages.onboardingHeadline,
    "把录音变成可回听、可编辑的文字。\n支持中文、英文与双语录音，全程在设备上转写。": messages.onboardingDescription,
    "无需账号 · 不上传录音 · 没有广告": messages.noAccountNoAds,
    "首次需联网下载模型，也可以导入已下载的官方模型。之后可以断网转写。模型效果会随设备与录音质量变化。":
        messages.firstModelExplanation,
    "开始聆写  →": messages.getStarted,
    "在录音前，请征得参与者同意。": messages.recordingConsent,
    "重命名": messages.rename,
    "导出这份转写": messages.exportThisTranscript,
    "只在你主动分享时，文件才会交给其他应用。": messages.shareExplanation,
    "删除音频和转写？": messages.deleteTranscriptQuestion,
    "删除后无法恢复。已经分享给其他应用的文件不会被删除。": messages.deleteTranscriptExplanation,
    "保留": messages.keep,
    "删除": messages.delete,
    "回听与校对": messages.replayAndEdit,
    "导出转写": messages.exportTranscript,
    "重新转写，保留原稿": messages.transcribeNewCopy,
    "删除音频和转写": messages.deleteAudioAndTranscript,
    "准备转写": messages.preparingTranscription,
    "取消": messages.cancel,
    "在这份转写中查找": messages.searchThisTranscript,
    "只看标记": messages.bookmarksOnly,
    "没有识别到可转写的语音": messages.noSpeechDetected,
    "音频已留在本机": messages.audioKeptLocally,
    "请回听确认是否包含清晰的语音。": messages.checkAudioQuality,
    "准备好模型后，把它写成文字。": messages.transcribeWhenReady,
    "开始离线转写": messages.startOfflineTranscription,
    "尚未安装模型：返回“离线模型”下载或导入。": messages.noModelInstalled,
    "没有符合条件的段落": messages.noMatchingSegments,
    "取消标记": messages.removeBookmark,
    "标记段落": messages.bookmarkSegment,
    "编辑段落": messages.editSegment,
    "已校对": messages.edited,
    "暂停回放": messages.pausePlayback,
    "回放音频": messages.playAudio,
    "点击时间戳回听原音": messages.tapTimestamp,
    "播放速度": messages.playbackSpeed,
    "资料库": messages.library,
    "离线模型": messages.offlineModels,
    "设置": messages.settings,
    "聆写": messages.brandName,
    "转写偏好": messages.transcriptionPreferences,
    "你的声音资料库": messages.yourAudioLibrary,
    "搜索标题或转写内容": messages.searchLibrary,
    "全部记录": messages.allRecords,
    "搜索结果": messages.searchResults,
    "开始录音": messages.startRecording,
    "导入音频": messages.importAudio,
    "给声音一个归处": messages.emptyLibraryTitle,
    "没有找到相关记录": messages.noRecordsFound,
    "录下一个想法，或导入一段访谈。\n你的录音和文字只保存在本机。": messages.emptyLibraryDescription,
    "试试不同的关键词。": messages.tryAnotherKeyword,
    "先准备离线模型": messages.prepareOfflineModel,
    "录音中": messages.statusRecording,
    "音频已保存 · 待转写": messages.statusSaved,
    "本地转写中": messages.statusTranscribing,
    "转写完成": messages.statusReady,
    "转写失败 · 可重试": messages.statusFailed,
    "任务中断 · 音频已保留": messages.statusInterrupted,
    "删除这个模型？": messages.deleteModelQuestion,
    "删除模型": messages.deleteModel,
    "把 AI 留在本机": messages.modelsHeadline,
    "下载一次，离线使用。\n模型只处理本地音频，录音不会上传。": messages.modelsDescription,
    "每个模型安装前都会验证 SHA-256。转写前再次检查文件，确保模型完整。":
        messages.modelVerificationExplanation,
    "从文件导入官方模型": messages.importOfficialModel,
    "使用备用模型下载站": messages.useModelMirror,
    "默认 Hugging Face；备用 hf-mirror.com。下载站会收到 IP 和模型请求，不会收到录音。":
        messages.modelSourceExplanation,
    "准确率取决于录音质量、语言及模型。更大模型通常需要更多内存和处理时间；尚未对本设备测得速度。":
        messages.modelAccuracyExplanation,
    "正在校验模型…": messages.verifyingModel,
    "当前使用": messages.currentModel,
    "使用这个模型": messages.selectModel,
    "丢弃这段录音？": messages.discardRecordingQuestion,
    "这段录音会被删除。也可以返回后先保存。": messages.discardRecordingExplanation,
    "继续录音": messages.resumeRecording,
    "丢弃": messages.discard,
    "正在聆听": messages.listening,
    "已暂停 · 点击继续": messages.pausedRecording,
    "记录此刻的声音": messages.recordingMoment,
    "暂停录音": messages.pauseRecording,
    "正在保存…": messages.saving,
    "结束并保存": messages.stopAndSave,
    "退出到后台时会自动暂停。\n保存后可选择模型进行离线转写。": messages.backgroundPauseExplanation,
    "按你的方式聆写": messages.settingsHeadline,
    "新录音与导入的默认偏好": messages.newAudioDefaults,
    "音频语言": messages.audioLanguage,
    "自动识别 · 包括中英混合": messages.autoLanguage,
    "中文": messages.chinese,
    "术语提示": messages.glossaryPrompt,
    "例如：LingoScribe、产品名、人名、专业术语": messages.glossaryHint,
    "术语会作为模型提示，不能保证识别结果。不会修改已保存记录的设置。": messages.glossaryExplanation,
    "隐私是默认设置": messages.privacyByDefault,
    "录音、导入音频、转写与搜索均在本机处理。应用没有账号、广告或统计 SDK，也不会上传这些内容。\n\n联网仅用于你主动下载模型。主动导出和分享后，接收应用会按照自己的隐私规则处理文件。\n\n数据保存在系统应用沙箱中；未使用额外的应用级加密。卸载应用会删除本地资料，请先导出重要内容。":
        messages.privacyDescription,
    "清除临时导出缓存": messages.clearExportCache,
    "保留录音与资料库，已分享的副本不受影响。": messages.exportCacheExplanation,
    "没有临时导出文件": messages.noTemporaryExports,
    "开源许可": messages.openSourceLicenses,
    "LingoScribe · 聆写": messages.licenseApplicationName,
    "请征得录音参与者同意。AI 转写可能有误，重要信息请回听核对。转写期间保持应用在前台，长音频建议连接电源。":
        messages.usageReminder,
    "标题": messages.title,
    "转写内容": messages.transcriptText,
    "请输入标题": messages.enterTitle,
    "保存": messages.save,
    "聆写标志": messages.brandSemantics,
    "仅在你的设备上": messages.onYourDeviceOnly,
  };
  return values[text] ?? text;
}

String friendlyError(BuildContext context, Object error) {
  final messages = l10n(context);
  final raw = error.toString();
  final text = raw.replaceFirst(
    RegExp(r'^(Bad state:|FormatException:|HttpException:)\s*'),
    '',
  );
  final translated = localizedLabel(context, text);
  if (_translations[messages]?.containsKey(text) == true ||
      text.startsWith('需要麦克风') ||
      text == messages.operationFailed) {
    return translated;
  }
  final lower = raw.toLowerCase();
  if (lower.contains('no space') ||
      lower.contains('errno = 28') ||
      lower.contains('not enough storage')) {
    return messages.storageFull;
  }
  if (lower.contains('two hour') || lower.contains('two-hour')) {
    return messages.audioTooLong;
  }
  if (lower.contains('socketexception') ||
      lower.contains('clientexception') ||
      lower.contains('timeoutexception') ||
      text.startsWith('下载失败')) {
    return messages.modelConnectionFailed;
  }
  if (lower.contains('unable to load model')) {
    return messages.modelLoadFailed;
  }
  if (lower.contains('permission denied') ||
      lower.contains('access is denied')) {
    return messages.fileAccessFailed;
  }
  if (lower.contains('failed to lookup symbol') ||
      lower.contains('failed to load dynamic library')) {
    return messages.engineUnavailable;
  }
  if (lower.contains('platformexception(decode') ||
      lower.contains('wav') ||
      lower.contains('audio track')) {
    return messages.audioUnreadable;
  }
  // Strip known storage prefixes before translating a persisted error.
  for (final prefix in ['转写失败：', '无法回放音频：', '回放失败：']) {
    if (text.startsWith(prefix)) {
      return friendlyError(context, text.substring(prefix.length));
    }
  }
  return messages.operationFailed;
}
