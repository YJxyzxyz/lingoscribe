# 验证计划与实际证据

## 已运行

- Flutter 静态检查：通过，零问题。
- 领域、导出、SQLite 持久化和模型传输/校验测试：16 项通过，包含长篇内容的有界预览与全文检索。
- 真实 Flutter 资料库/模型页面、搜索和窄屏大字体检查：4 项通过。UI 测试的麦克风通道采用测试隔离，不代表验证了原生录音。
- 校对弹窗保存/返回/标题校验：3 项通过；中断录音 WAV 头恢复与损坏文件拒绝：2 项通过。当前合计 25 项。
- Android API 35 x86_64 模拟器：实际系统文件选择器导入、飞行模式原生英文转写、录音权限拒绝/允许、暂停/继续/保存、取消转写、编辑保存及 SRT 文件与系统分享面板已验证。未向任何外部收件人发送数据。
- 原生 Android 集成测试已通过真实模型导入、归一化、isolate 推理、时间戳、数据库校对原文及标记检查。11 秒英文样例在此模拟器 Debug 构建中约 135 秒完成；不能当作 Release 或实际手机的性能。
- 实际 Android 解码通过 44.1/48 kHz 双声道 WAV、MP3、M4A、FLAC、Opus/OGG：归一化为 PCM16/单声道/16 kHz，时长差小于 200 ms，与原始语音的波形相关性大于 0.9；损坏输入拒绝并清理输出。数据见 `validation/android-native-integration.json`。
- 原生 C++ Windows 烟测：真实加载官方 Base Q5 模型，转写上游 11 秒英文音频。报告见 `validation/native-smoke-windows.json`，包含模型及音频 SHA-256、实际文本、时间戳与取消/坏文件检查。
- Windows 桌面烟测的速度仅适用于该台桌面机，不代表 Android / iPhone 速度，也不构成中文准确率报告。
- 界面截图来自实际 Flutter 渲染；测试可加载本机字体，不打包该字体。需在原生模拟器/真机复核字体、图标和系统控件。

## 自动化命令

```sh
cd apps/mobile
flutter pub get
flutter analyze
flutter test --coverage
```

原生桌面烟测：先用 CMake 编译 `packages/offline_engine/src`，然后：

```sh
python tools/native_smoke.py --library <原生动态库> --model <官方模型.bin> --audio <16kHz单声道PCM16.wav>
```

专用 Android QA 设备的真实集成测试（安装的是测试入口 APK，夹具不进入生产安装包）：

```sh
cd apps/mobile
flutter pub get --enforce-lockfile
flutter build apk --debug --target-platform android-x64 --target integration_test/native_pipeline_test.dart
cd ../..
python tools/run_android_native_test.py --device <QA设备序列号> --apk apps/mobile/build/app/outputs/flutter-apk/app-debug.apk --model <官方BaseQ5.bin> --audio <whisper.cpp上游samples/jfk.wav> --report build/android-native-result.json
```

该脚本通过 `run-as` 写入测试安装的私有夹具，无需 root；必须使用专用测试设备及相容的测试签名。
FFmpeg 仅用于测试工具生成不同编码的真实音频夹具，不进入 App；可通过 `--ffmpeg` 指定本机路径。
构建入口改变后用正常 `lib/main.dart` 重新构建安装。直接调用 Gradle 之前必须生成匹配构建模式的 Flutter 插件注册表。
切换 Debug/Release 时使用完整 `flutter build`，不要跳过需要按构建模式生成的插件配置；不要与同一工程的 pub/analyze 命令并行执行。
CI 与正式构建使用 `pub get --enforce-lockfile`，避免依赖来源变化时悄悄升级版本。

产物检查：`tools/check_android_artifact.py` 检查实际 ELF、APK 存储对齐和完整 ABI；`tools/check_ios_bundle.py` 检查实际 App 内的 FFI 导出、检测模型哈希与隐私声明。
当前 ARM64 AAB 及已下载的 iOS unsigned App 静态检查通过。它们分别不能代替 16 KB 设备执行和签名 iPhone 验证。

测试 UI、仓储或网络边界时允许隔离平台通道；离线推理、音频解码和录音验收必须调用真实原生实现。
测试夹具不进入用户资料库，产品不能预置虚构录音或伪造推理进度。

## 手机与双语验收

录音：权限拒绝/允许、暂停/继续、后台自动暂停、来电中断、2 小时上限、低存储与进程退出后恢复。
导入：16/44.1/48 kHz、单/双声道，WAV/MP3/M4A/AAC/FLAC，系统支持的 OGG/视频轨；损坏文件和无音轨必须明确报错。
转写：模型下载/取消/损坏校验、模型文件导入、飞行模式、中文/英语/混合、专业名词、无语音、噪声与长音频。
校对：时间戳点击回听，编辑保留原文，标记筛选，文本搜索，文件名安全与字幕播放器可读性。
隐私：抓包确认音频/文字从不上传；模型下载只含模型请求。测试两端备份与数据删除行为。
升级：保留 SQLite 记录、音频和校对内容，不破坏以前的发布数据。

基准集需记录授权、录音条件、人工参考文本、设备、系统、模型哈希、线程数、CER/WER、RTF、内存、耗电和温度。
中英混合同时报告中文 CER 与英文 WER；不以单一英文样例代替双语评测。

## 仍待验证

Android 完整构建与 iOS macOS CI 未签名编译已通过，见 [构建记录](https://github.com/YJxyzxyz/lingoscribe/actions/runs/37938864297)。模拟器集成继续覆盖新增修复；手机准确率、耗电、长音频、签名及商店审核尚未通过。
最新状态见 `STATUS.md`，发布门槛见 `STORE_READINESS.md`。

## 混合语言问题与改进

本机 Windows TTS 合成的 11.555 秒中英混合片段在 Small Q5 上漏掉了英文句子；保留了失败报告。
按停顿拆分后英文恢复，但同一次桌面测试处理时间从约 6.8 秒增加至 25.2 秒。
随后改为只重新识别时间戳未覆盖且包含可听信号的区间，保留已有分段；该片段恢复了英文，约 12.9 秒完成。
这些数据是单个合成测试和桌面机器的实际结果，不能作为真实录音准确率或手机性能宣传。
加入 Silero 神经网络语音检测后，该片段仍保留英文，桌面耗时约 13.7 秒；这不构成总体准确率改善证明。
模拟器实际录下的 190.208 秒极低幅度环境噪声在桌面检测中约 1.4 秒完成并返回空文本，见 `validation/non-speech-vad-windows.json`。
检测器不做说话人分离。需继续扩展真实双语、低音量、连读、噪声与长音频的回归集，检查漏检风险。

## 中断录音恢复

Android 录音器在正常结束前可能留有 44 字节空 WAV 头。应用启动时只修复路径匹配的自身中断 PCM16 单声道 16 kHz 录音，保留原始 PCM 字节。
此行为有文件级回归测试；进程被系统杀死、iOS 录音容器及低存储恢复仍需设备验收。
