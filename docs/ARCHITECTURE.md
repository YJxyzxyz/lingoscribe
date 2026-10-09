# 架构与维护

- `apps/mobile`：Flutter iOS / Android 客户端；领域实体、SQLite 仓储、应用控制器、原生音频归一化和 UI 分层。
- `packages/offline_engine`：Dart FFI 与 whisper.cpp C++ 桥接。原生推理在后台 isolate 执行，UI 主线程只查询原子进度和发出取消。
- `native/vendor/whisper.cpp`：固定提交的上游源码快照，保留上游许可；Android 使用 CMake，iOS 从同一源码生成静态 XCFramework。
- `docs`：产品研究、隐私、许可、测试、发布与外部依赖清单。

## 数据流

录音/系统文件选择 → 应用私有目录 → 原生解码为 16 kHz 单声道 PCM WAV → 本地模型 → 带毫秒时间戳的分段 → SQLite → 本地回放/编辑/搜索/用户主动导出。
模型下载是唯一产品网络通路，不提供音频上传、远程转写或账户 API。
录音与文本由系统应用沙箱保护；不宣称已实现应用级数据库加密。Android 禁用自动备份，iOS 为私有音频及模型设置不参与备份。

## 引擎决策

采用 [whisper.cpp](https://github.com/ggml-org/whisper.cpp)，理由是成熟多语言 Whisper、原生时间戳、原文转写及现成 Apple/Android 集成。
使用多语言 base 和 small 量化模型，避免英文专用 `.en` 模型；模型按下载的实际字节数与 SHA-256 校验。
内置约 0.85 MiB 的 Silero 6.2.0 检测模型，在设备上识别语音区间，跳过无语音块，并减少静音误转写。检测按 30 秒窗口执行，保留窗口之间的状态；它不识别说话人。
自动语言模式仅对未覆盖且含语音的时间戳间隙补充识别；已有分段保留。真实双语准确率需用合法参考语料测量。
首版限制并行推理为一项，限制输入长度，分块读取 WAV，CPU 默认最多 4 线程，执行结束立即释放模型；大模型的内存和热表现必须真机测量。
Apple GPU 加速应在确认框架及设备表现后开启，CPU 路径作为可测基线。
研究过 [sherpa-onnx SenseVoice](https://k2-fsa.github.io/sherpa/onnx/sense-voice/index.html)，后续以同一双语测试集比较；当前不凭主观判断宣称某模型更准。

## 故障与约束

所有真实任务保存状态。异常退出后的 processing 状态恢复为 interrupted，保留音频并允许重试。
下载写入 `.part`，校验通过后原子重命名；取消、校验失败或网络断开不安装半成品。
录音进行中限制退出并提示保存/丢弃；首次权限只在录音动作请求。
后台长时间执行、来电中断和低存储行为需要在两端真机完成验证，未通过时不宣传后台持续转写。
