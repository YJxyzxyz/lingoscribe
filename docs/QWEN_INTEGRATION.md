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

两平台 CI 增加真实 Qwen 六文件导入、音频归一化、语音检测、原生推理、区间时间戳、SQLite 校对与准备阶段取消断言；结果需实际运行通过后归档。
当前本机没有连接真机。正式验收还需要更广且有授权的人声、长对话、噪声、不同手机的速度/峰值内存/功耗/热状态、系统中断及低存储测试，随后完成签名和商店审核。

## 手动开发宿主回归

设置 `LINGO_ENGINE_LIBRARY` 为本机已编译的 VAD/Whisper 动态库，`LINGO_SHERPA_LIBRARY` 为参考运行库目录，`LINGO_RESEARCH_ROOT` 为本机 `build/`，`LINGO_NATIVE_AUDIO` 为固定上游 JFK WAV。
运行 `flutter test test/qwen_desktop_native_test.dart --dart-define=RUN_NATIVE_QWEN=true --dart-define=RUN_QWEN_CORPUS=true`。
原始识别正文仅保存在被忽略的 `build/qwen-dart-native-outputs.json`；`score_native_qwen_outputs.py` 输出无正文的聚合与逐条错误数。
