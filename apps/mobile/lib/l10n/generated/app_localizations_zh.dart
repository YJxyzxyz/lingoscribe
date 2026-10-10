// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get libraryUnavailable => '无法打开本地资料库';

  @override
  String get retry => '重试';

  @override
  String get recordingRecovered => '任务被中断，音频已恢复或确认可读取，可重试转写。';

  @override
  String get finishCurrentTask => '请先结束当前任务';

  @override
  String get microphonePermission => '需要麦克风权限才能录音，请在系统设置中允许。';

  @override
  String get recordingSaveFailed => '录音已停止，保存记录失败。请重启应用以恢复本地音频。';

  @override
  String get recordingInterrupted => '录音中断，已恢复本地音频，可继续转写。';

  @override
  String get recordingIncomplete => '录音未正常结束。请检查麦克风权限后重新录音。';

  @override
  String get importingAudio => '正在导入音频';

  @override
  String get fileTooLarge => '文件超过 2 GB，请先裁剪音频';

  @override
  String get preserveEditsBeforeRetry => '请先复制或导出已有校对文本，重转写功能暂不覆盖已有内容';

  @override
  String get prepareModelFirst => '请在模型管理中下载或导入模型，然后离线转写';

  @override
  String get verifyingLocalModel => '正在验证本地模型';

  @override
  String get preparingAudio => '正在准备音频';

  @override
  String get transcribingOnDevice => '正在设备上转写';

  @override
  String get loadingLocalModel => '正在载入本地模型';

  @override
  String get checkingSpeechGaps => '正在检查可能遗漏的语音';

  @override
  String get detectingSpeech => '正在检测语音区间';

  @override
  String get transcriptionCancelled => '转写已取消，音频已保留。';

  @override
  String get preparingRevision => '正在准备新转写';

  @override
  String get taskInterrupted => '任务被中断，音频已保留，请重试。';

  @override
  String get detectorIntegrityFailed => '内置语音检测模型校验失败';

  @override
  String get exportText => '纯文本 · TXT';

  @override
  String get exportMarkdown => '笔记 · Markdown';

  @override
  String get exportSrt => '字幕 · SRT';

  @override
  String get exportVtt => '网页字幕 · VTT';

  @override
  String get exportJson => '完整数据 · JSON';

  @override
  String get baseModel => '轻量 · Base';

  @override
  String get baseModelDescription => '较小下载体积，适合短笔记。多语言，Q5 量化。';

  @override
  String get smallModel => '精细 · Small';

  @override
  String get smallModelDescription => '更大的多语言模型，适合访谈与双语录音。速度与内存取决于设备。';

  @override
  String get modelIntegrityFailed => '模型校验失败，请重新下载官方模型';

  @override
  String get modelRequired => '请先下载或导入一个模型';

  @override
  String get downloadCancelled => '下载已取消';

  @override
  String get modelSizeInvalid => '模型文件大小异常';

  @override
  String get waitForModelOperation => '请等待当前模型操作完成';

  @override
  String get officialModelsOnly => '只支持目录中列出的官方 Base / Small Q5 模型';

  @override
  String get applicationTitle => '聆写 · LingoScribe';

  @override
  String get onboardingHeadline => '声音留在这里。\n文字随你前行。';

  @override
  String get onboardingDescription =>
      '把录音变成可回听、可编辑的文字。\n支持中文、英文与双语录音，全程在设备上转写。';

  @override
  String get noAccountNoAds => '无需账号 · 不上传录音 · 没有广告';

  @override
  String get firstModelExplanation =>
      '首次需联网下载模型，也可以导入已下载的官方模型。之后可以断网转写。模型效果会随设备与录音质量变化。';

  @override
  String get getStarted => '开始聆写  →';

  @override
  String get recordingConsent => '在录音前，请征得参与者同意。';

  @override
  String get rename => '重命名';

  @override
  String get exportThisTranscript => '导出这份转写';

  @override
  String get shareExplanation => '只在你主动分享时，文件才会交给其他应用。';

  @override
  String get deleteTranscriptQuestion => '删除音频和转写？';

  @override
  String get deleteTranscriptExplanation => '删除后无法恢复。已经分享给其他应用的文件不会被删除。';

  @override
  String get keep => '保留';

  @override
  String get delete => '删除';

  @override
  String get replayAndEdit => '回听与校对';

  @override
  String get exportTranscript => '导出转写';

  @override
  String get transcribeNewCopy => '重新转写，保留原稿';

  @override
  String get deleteAudioAndTranscript => '删除音频和转写';

  @override
  String get preparingTranscription => '准备转写';

  @override
  String get cancel => '取消';

  @override
  String get searchThisTranscript => '在这份转写中查找';

  @override
  String get bookmarksOnly => '只看标记';

  @override
  String get noSpeechDetected => '没有识别到可转写的语音';

  @override
  String get audioKeptLocally => '音频已留在本机';

  @override
  String get checkAudioQuality => '请回听确认是否包含清晰的语音。';

  @override
  String get transcribeWhenReady => '准备好模型后，把它写成文字。';

  @override
  String get startOfflineTranscription => '开始离线转写';

  @override
  String get noModelInstalled => '尚未安装模型：返回“离线模型”下载或导入。';

  @override
  String get noMatchingSegments => '没有符合条件的段落';

  @override
  String get removeBookmark => '取消标记';

  @override
  String get bookmarkSegment => '标记段落';

  @override
  String get editSegment => '编辑段落';

  @override
  String get edited => '已校对';

  @override
  String get pausePlayback => '暂停回放';

  @override
  String get playAudio => '回放音频';

  @override
  String get tapTimestamp => '点击时间戳回听原音';

  @override
  String get playbackSpeed => '播放速度';

  @override
  String get library => '资料库';

  @override
  String get offlineModels => '离线模型';

  @override
  String get settings => '设置';

  @override
  String get brandName => '聆写';

  @override
  String get transcriptionPreferences => '转写偏好';

  @override
  String get yourAudioLibrary => '你的声音资料库';

  @override
  String get searchLibrary => '搜索标题或转写内容';

  @override
  String get allRecords => '全部记录';

  @override
  String get searchResults => '搜索结果';

  @override
  String get startRecording => '开始录音';

  @override
  String get importAudio => '导入音频';

  @override
  String get emptyLibraryTitle => '给声音一个归处';

  @override
  String get noRecordsFound => '没有找到相关记录';

  @override
  String get emptyLibraryDescription => '录下一个想法，或导入一段访谈。\n你的录音和文字只保存在本机。';

  @override
  String get tryAnotherKeyword => '试试不同的关键词。';

  @override
  String get prepareOfflineModel => '先准备离线模型';

  @override
  String get statusRecording => '录音中';

  @override
  String get statusSaved => '音频已保存 · 待转写';

  @override
  String get statusTranscribing => '本地转写中';

  @override
  String get statusReady => '转写完成';

  @override
  String get statusFailed => '转写失败 · 可重试';

  @override
  String get statusInterrupted => '任务中断 · 音频已保留';

  @override
  String get deleteModelQuestion => '删除这个模型？';

  @override
  String get deleteModel => '删除模型';

  @override
  String get modelsHeadline => '把 AI 留在本机';

  @override
  String get modelsDescription => '下载一次，离线使用。\n模型只处理本地音频，录音不会上传。';

  @override
  String get modelVerificationExplanation =>
      '每个模型安装前都会验证 SHA-256。转写前再次检查文件，确保模型完整。';

  @override
  String get importOfficialModel => '从文件导入官方模型';

  @override
  String get useModelMirror => '使用备用模型下载站';

  @override
  String get modelSourceExplanation =>
      '默认 Hugging Face；备用 hf-mirror.com。下载站会收到 IP 和模型请求，不会收到录音。';

  @override
  String get modelAccuracyExplanation =>
      '准确率取决于录音质量、语言及模型。更大模型通常需要更多内存和处理时间；尚未对本设备测得速度。';

  @override
  String get verifyingModel => '正在校验模型…';

  @override
  String get currentModel => '当前使用';

  @override
  String get selectModel => '使用这个模型';

  @override
  String get discardRecordingQuestion => '丢弃这段录音？';

  @override
  String get discardRecordingExplanation => '这段录音会被删除。也可以返回后先保存。';

  @override
  String get resumeRecording => '继续录音';

  @override
  String get discard => '丢弃';

  @override
  String get listening => '正在聆听';

  @override
  String get pausedRecording => '已暂停 · 点击继续';

  @override
  String get recordingMoment => '记录此刻的声音';

  @override
  String get pauseRecording => '暂停录音';

  @override
  String get saving => '正在保存…';

  @override
  String get stopAndSave => '结束并保存';

  @override
  String get backgroundPauseExplanation => '退出到后台时会自动暂停。\n保存后可选择模型进行离线转写。';

  @override
  String get settingsHeadline => '按你的方式聆写';

  @override
  String get newAudioDefaults => '新录音与导入的默认偏好';

  @override
  String get audioLanguage => '音频语言';

  @override
  String get autoLanguage => '自动识别 · 包括中英混合';

  @override
  String get chinese => '中文';

  @override
  String get glossaryPrompt => '术语提示';

  @override
  String get glossaryHint => '例如：LingoScribe、产品名、人名、专业术语';

  @override
  String get glossaryExplanation => '术语会作为模型提示，不能保证识别结果。不会修改已保存记录的设置。';

  @override
  String get privacyByDefault => '隐私是默认设置';

  @override
  String get privacyDescription =>
      '录音、导入音频、转写与搜索均在本机处理。应用没有账号、广告或统计 SDK，也不会上传这些内容。\n\n联网仅用于你主动下载模型。主动导出和分享后，接收应用会按照自己的隐私规则处理文件。\n\n数据保存在系统应用沙箱中；未使用额外的应用级加密。卸载应用会删除本地资料，请先导出重要内容。';

  @override
  String get clearExportCache => '清除临时导出缓存';

  @override
  String get exportCacheExplanation => '保留录音与资料库，已分享的副本不受影响。';

  @override
  String get noTemporaryExports => '没有临时导出文件';

  @override
  String get openSourceLicenses => '开源许可';

  @override
  String get licenseApplicationName => 'LingoScribe · 聆写';

  @override
  String get usageReminder =>
      '请征得录音参与者同意。AI 转写可能有误，重要信息请回听核对。转写期间保持应用在前台，长音频建议连接电源。';

  @override
  String get title => '标题';

  @override
  String get transcriptText => '转写内容';

  @override
  String get enterTitle => '请输入标题';

  @override
  String get save => '保存';

  @override
  String get brandSemantics => '聆写标志';

  @override
  String get onYourDeviceOnly => '仅在你的设备上';

  @override
  String recordCount(int count) {
    return '$count 条';
  }

  @override
  String proofreadAt(String time) {
    return '校对 $time';
  }

  @override
  String originalTranscript(String text) {
    return '原始转写：$text';
  }

  @override
  String removeModelExplanation(String size) {
    return '释放 $size。你的录音和转写内容会保留，以后可以重新下载模型。';
  }

  @override
  String downloadModelSize(String size) {
    return '下载 $size';
  }

  @override
  String downloadProgress(String percent) {
    return '下载 $percent%';
  }

  @override
  String modelLanguagesAndLicense(String size) {
    return '$size · 中文 / English · MIT';
  }

  @override
  String exportFilesCleared(int count) {
    return '已清理 $count 个临时导出文件';
  }

  @override
  String get interfaceLanguage => '界面语言';

  @override
  String get followSystem => '跟随系统';

  @override
  String get operationFailed => '操作未完成，请重试。';

  @override
  String get audioUnreadable => '无法读取音频，请确认文件包含音轨且格式受系统支持。';

  @override
  String get audioTooLong => '仅支持两小时以内的音频，请先裁剪。';

  @override
  String get storageFull => '存储空间不足，请释放空间后重试。';

  @override
  String get modelConnectionFailed => '无法连接模型下载站，可尝试备用站或导入模型文件。';

  @override
  String get modelLoadFailed => '模型无法载入，请检查文件完整性或尝试轻量模型。';

  @override
  String get fileAccessFailed => '无法访问所选文件，请重新选择并授予访问权限。';

  @override
  String get engineUnavailable => '转写引擎无法加载，请更新应用后重试。';

  @override
  String recordingTitle(String date, String time) {
    return '录音 $date $time';
  }

  @override
  String revisionTitle(String title) {
    return '$title · 新转写';
  }
}
