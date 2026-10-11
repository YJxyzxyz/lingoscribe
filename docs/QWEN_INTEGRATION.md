# Qwen3 客户端接入与验收

2026-10-11 在 `codex/qwen-offline` 分支推进。尚未宣称达到商业发布验收。

## 实际实现

- 固定六文件快照，共 987,015,347 字节；流式下载、独立 SHA-256 校验、整套目录提交、失败保留旧模型、安装中断恢复、完整文件导入和删除。
- 通过真实 GGML Silero 检测语音区间，按不超过 20 秒的区间有界读取 PCM；Qwen 模型在一个转写任务中只加载一次，在独立 Dart 工作线程执行真实原生推理。
- Qwen 时间戳来自实际检测的语音区间，不是逐字对齐；模型说明和 JSON 导出明确记录来源。
- 取消覆盖模型校验、音频准备与原生区间之间；区间推理期间采取协作取消，完成当前原生调用后释放模型，不强杀工作线程。
- 暂设至少 6 GB 设备总内存；Android 另检查可用内存。阈值是保守开发保护，不代表所有满足条件的手机都已通过性能验收。

## 原生运行库与许可

维护者已明确上游通用 TTS 运行包存在 espeak/piper 许可约束，见 [说明](https://github.com/k2-fsa/sherpa-onnx/issues/3731)。实际参考 Windows DLL 包含相关字符串，不能把顶层 Apache-2.0 标签当作全部预编译依赖的许可结论。
客户端已移除全部上游平台预编译包依赖；只保留已核对来源的原生 Dart API 文件。Android/iOS 从固定 sherpa-onnx 1.13.8 源码构建，强制关闭 TTS、说话人分离、GPU、网络服务和示例，启用 Eigen 的 MPL2-only 保护。
构建脚本校验源码归档和 ONNX Runtime 字节摘要；许可页保留 Qwen 权重声明、原生依赖完整许可及 ONNX Runtime 完整第三方通知。实际构建另运行 `audit_sherpa_build.py`，检查解析依赖、配置与打包通知。

源码归档 SHA-256：`0a8db6c55dd318f4a688faba85f7760b99a6c92e8ef8864479d418531bee1ac2`，上游提交 `11afbd009a7f8c08f4bcf2fc1b265d0df4670fbf`。准备工具将公开 GitHub 源码归档 URL 改为其直接 codeload 地址，保留原始依赖摘要；不会下载或链接 piper/espeak。

## 已验证与待验证

45 项应用测试通过；另显式运行真实 Windows 原生 VAD + Dart Qwen 烟测及 90 条许可人声回归。该开发宿主使用明确指定的上游参考 DLL，参考 DLL不随手机 App 分发；不能代替新 ASR-only Android/iOS 运行库验证。
90 条真实路径回归：中文原始 CER 9.5%，混合原始中文 CER 17.5% / 英文 WER 31.9%，纯英文 WER 22.9%。仅两位说话人，仍不是独立人群或商业准确率验收。

两平台 CI 的真实 Qwen 六文件导入、音频归一化、语音检测、原生推理、区间时间戳、SQLite 校对与准备阶段取消断言已在 8a3075a 实际通过，双平台构建及许可/静态检查也通过。iOS 语义句柄测试入口问题修复已验证。四份原生报告见 `validation/*-native-8a3075a.json`，构建记录：<https://github.com/YJxyzxyz/lingoscribe/actions/runs/38108630652>。模拟器结果不能代替物理手机。
已授权连接 vivo V2073A / Android 13，独立 `.qa` Debug 安装已通过真实录音、六种解码及 Base 推理/SQLite 测试，见 `validation/android-physical-base-8a3075a.json`。Qwen 更新安装被手机系统再次拒绝，等待下一次安装提示确认；Qwen 真机性能仍未验证。正式验收还需要更广且有授权的人声、长对话、噪声、不同手机的速度/峰值内存/功耗/热状态、系统中断及低存储测试，随后完成签名和商店审核。
三位额外说话人的初次 90 条评测显示混合中文 CER 26.6% / 英文 WER 44.3%。后续诊断复用该子集，统一 token 配置的整段输入为 17.4% / 36.7%，与另一 token 配置的整段结果相同；说明保留上下文值得继续验证。诊断不再视为新独立验收样本，结果见 `validation/qwen-context-diagnostic.json`。cbfde89 加入短音频完整上下文、长音频邻近区间合并和最多 200 ms 邻近静音上下文；保持单次读取 ≤20 秒，时间戳为实际 VAD 语音段的包络，非逐字对齐。实际 180 条合计混合中文 CER 22.0% → 17.2%、英文 WER 40.4% → 35.7%，原先一批混合英文有轻微退步，见 `validation/qwen-context-comparison.json`。仍未满足准确率验收，且不是新的独立验收集。
94150a8 另修复不足一毫秒的 PCM 尾部样本丢失，读取器保留全部尾部样本，同时严格限制每次不超过 320,000 帧（20 秒）。51 项本机测试和原生英文烟测通过；此读取修复的完整 180 条真实回归正在执行。cbfde89 的已存报告保留旧读取策略标记，不能混用源码版本。

## 手动开发宿主回归

设置 `LINGO_ENGINE_LIBRARY` 为本机已编译的 VAD/Whisper 动态库，`LINGO_SHERPA_LIBRARY` 为参考运行库目录，`LINGO_RESEARCH_ROOT` 为本机 `build/`，`LINGO_NATIVE_AUDIO` 为固定上游 JFK WAV。
运行 `flutter test test/qwen_desktop_native_test.dart --dart-define=RUN_NATIVE_QWEN=true --dart-define=RUN_QWEN_CORPUS=true`。
原始识别正文仅保存在被忽略的 `build/qwen-dart-native-outputs.json`；`score_native_qwen_outputs.py` 输出无正文的聚合与逐条错误数。
