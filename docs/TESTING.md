# 验证计划与实际证据

## 已运行

- Flutter 静态检查：通过，零问题。
- 新增六项录音时序回归：权限等待期间重复启动、后台权限返回、原生启动期间切后台、权限焦点恢复、继续期间收到重复后台通知、启动失败后的真实 PCM 文件保留。当前合计 38 项；这些测试控制平台操作时序，不冒充麦克风硬件验收。
- 领域、导出、SQLite 持久化和模型传输/校验测试：17 项通过，包含长篇内容的有界预览、全文检索及中断下载清理。
- 真实 Flutter 资料库/模型页面、搜索和窄屏大字体检查：4 项通过；新增自动结束后的页面切换及空停止路径保留音频：2 项通过。UI 测试的麦克风通道采用测试隔离，不代表验证了原生录音。
- 校对弹窗保存/返回/标题校验：3 项通过；中断录音 WAV 头恢复与损坏文件拒绝：2 项通过。另有 4 项英文切换、窄屏、键盘与错误隐私回归；加上录音时序回归，当前合计 38 项。
- Android API 35 x86_64 模拟器：实际系统文件选择器导入、飞行模式原生英文转写、录音权限拒绝/允许、暂停/继续/保存、取消转写、编辑保存及 SRT 文件与系统分享面板已验证。未向任何外部收件人发送数据。
- 后台暂停已实际验证：进入 Home 后文件停止增长，返回应用仍为暂停，手动继续后恢复采集并保存；不构成后台持续录音或来电测试。
- Android 原生播放器已验证播放进度推进、暂停和拖动定位：实际进度从 00:20 定位至 00:35；模拟器关闭音频输出，不声称已检验听感。
- 原生 Android 集成测试已通过真实模型导入、归一化、isolate 推理、时间戳、数据库校对原文及标记检查。11 秒英文样例在此模拟器 Debug 构建中约 135 秒完成；不能当作 Release 或实际手机的性能。
- 实际 Android 解码通过 44.1/48 kHz 双声道 WAV、MP3、M4A、FLAC、Opus/OGG：归一化为 PCM16/单声道/16 kHz，时长差小于 200 ms，与原始语音的波形相关性大于 0.9；损坏输入拒绝并清理输出。数据见 `validation/android-native-integration.json`。
- iOS 18.5 / iPhone 16 模拟器真实运行也通过上述六种编码（含本次运行支持的 OGG）、模型校验、isolate 推理、时间戳及校对持久化，见 `validation/ios-native-integration.json`。不同 iOS 系统的解码支持仍需验收；不构成 iPhone 真机性能证据。
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

参考文本回归工具：`tools/evaluate_transcription.py` 对真实原生输出计算中文字符 CER、英文单词 WER 与实际 RTF。音频需要来源说明；人声语料需要许可或已取得同意的记录。
默认报告省略参考与转写正文，写入被 Git 忽略的 `build/`；只有明确使用 `--include-text` 时才保存正文。
真实人声小规模回归使用 HKUST CAiRE 的 [ASCEND 数据集](https://huggingface.co/datasets/CAiRE/ASCEND)，数据许可为 CC-BY-SA-4.0；其 GitHub 工具代码的 MIT 许可不能代替数据许可。
`tools/prepare_ascend_corpus.py` 校验固定测试 Parquet 的 SHA-256，按预先设定规则选取最多三个说话人、每人每种语言前三条不少于两秒的片段，输出音频和参考清单均留在被忽略的 `build/`。
实际测试 split 只有两个说话人，选出 18 条、约 66.5 秒音频。此样本不能代表真实用户、长会议或整体准确率。
另使用 `--clips-per-language 30 --output build/corpus/ascend-expanded`，按语言与说话人轮转、保留每人的原始行顺序，预先选取中文、英文、混合各 30 条（共约 316.6 秒）。说话人仍只有两位；这增加回归覆盖，不增加人群代表性。实际结果见 `validation/ascend-expanded-evaluation.json`，原始 18 条基线保留。
两模型实际推理的聚合指标见 `validation/ascend-regression-evaluation.json`：Small 的中文组原始 CER 23.6%，混合组原始中文 CER 47.0%、英文 WER 65.0%；错误包含简繁体差异、语气词省略、英文词误识别和缩写分词差异。
这些结果显示混合自然对话仍需优化，不能以两个合成片段的良好结果宣传高准确率。后续调参需保留当前基线和失败样例，并用额外语料验证，防止只适配此子集。
另行试验固定语言与“简体中文、保留英文”提示：固定语言没有降低本子集的错误数；提示虽降低纯中文原始 CER，却使混合英文 WER 从 65% 增至 80%，还出现新的漏词和误识别。因此没有将该提示设为产品默认值。比较记录见 `validation/ascend-prompt-comparison.json`，桌面运行时间受同时执行任务影响，不作为速度改善结论。

```sh
pip install -r tools/corpus-requirements.txt
python tools/prepare_ascend_corpus.py <固定ASCEND测试Parquet>
python tools/evaluate_transcription.py --library <真实原生库> --model <模型.bin> --vad apps/mobile/assets/models/ggml-silero-v6.2.0.bin --manifest build/corpus/ascend/manifest.json --audio-root build/corpus/ascend
```

Qwen3 引擎候选用 `tools/evaluate_qwen3.py --model-directory <固定快照目录> --manifest <同一语料清单> --audio-root <音频目录>` 执行真实 sherpa-onnx CPU 推理，校验三项模型和 tokenizer 的 SHA-256，默认不保存参考和识别正文。依赖沿用 `tools/sensevoice-research-requirements.txt`；这只用于开发机研究，不进入手机 App。

`tools/synthetic_corpus.json` 配合本机 Windows TTS 生成器用于合成回归。报告 `validation/synthetic-regression-evaluation.json` 仅包含两个合成片段，不是人声准确率证据。
原始 CER 不转换简繁体：Base 的一个结果输出了繁体中文，导致较高的原始字面错误率；不能将该数值直接解释成语音识别错误率。参考与输出、规范化规则均已记录，不能隐藏这类差异来夸大效果。

专用 Android QA 设备的真实集成测试（安装的是测试入口 APK，夹具不进入生产安装包）：

```sh
cd apps/mobile
flutter pub get --enforce-lockfile
flutter build apk --debug --target-platform android-x64 --target integration_test/native_pipeline_test.dart
cd ../..
python tools/run_android_native_test.py --device <QA设备序列号> --apk apps/mobile/build/app/outputs/flutter-apk/app-debug.apk --model <官方BaseQ5.bin> --audio <whisper.cpp上游samples/jfk.wav> --report build/android-native-result.json
```

该脚本通过 `run-as` 写入测试安装的私有夹具，无需 root；必须使用专用测试设备及相容的测试签名。
当前 Android 测试入口增加真实原生麦克风采集、暂停/继续及 WAV 保存断言；脚本会在指定 QA 安装上预授予麦克风权限。虚拟麦克风结果不代表真实人声或物理手机麦克风质量。
`android-runtime` CI 在专用 Linux/KVM 模拟器上已通过此入口，见 `validation/android-native-ci-integration.json`。首次未优化的 Debug 原生运行中，11 秒英文推理为约 292 秒；后续 Debug 内核启用 `-O3` 并保留调试符号。Android 发布构建使用已优化的 `RelWithDebInfo` 配置（本机实际编译指令为 `-O2`），该变更不修改发布配置。不同宿主和构建模式的时间不能作为手机速度比较。
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
此行为有文件级回归测试，并已在 Android 模拟器真实录音后通过 `SIGKILL` 验证：重启修复 51.904 秒录音的容器，原始 PCM 字节与 SHA-256 完全保持，资料库恢复为中断状态。见 `validation/android-recording-recovery.json`。
iOS 录音容器、物理手机系统中断及低存储恢复仍需设备验收。
