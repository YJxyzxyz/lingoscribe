# 第三方许可与来源

本应用原创代码默认保留所有权利，仓库公开不等于授予商业再发行权。第三方组件按各自许可使用。
发布前需根据最终 lockfile 和两端打包依赖生成完整许可清单，并检查新增 SDK 的隐私清单。
当前已从本机解析的 lockfile 导出 110 个 Dart 依赖及全部许可，见 `licenses/dart-dependencies.json` 与 `licenses/DART_NOTICES.txt`。
其中包含开发/测试依赖，不意味着它们全部进入 release 包；Android Maven 与 iOS 原生传递依赖仍需在最终归档后审计。

| 组件 | 来源 | 许可 / 处理 |
| --- | --- | --- |
| Flutter / Dart | https://github.com/flutter/flutter | BSD-3-Clause，保留上游声明 |
| whisper.cpp 1.9.4 | https://github.com/ggml-org/whisper.cpp/tree/v1.9.4 | MIT；固定源码及许可保存在 native/vendor |
| ggml | whisper.cpp 自带固定快照 | 保留所有文件中的原始许可，包含 MIT 与部分额外声明 |
| Whisper 模型 | https://github.com/openai/whisper、https://huggingface.co/ggerganov/whisper.cpp | OpenAI MIT；官方量化模型按固定 commit 和 SHA-256 下载，不随安装包重复打包 |
| Silero VAD 6.2.0 | https://github.com/snakers4/silero-vad、https://huggingface.co/ggml-org/whisper-vad | MIT；内置 885,098 字节检测模型，固定来源及 SHA-256 见 assets/brand/VAD_MODEL_SOURCE.md |
| record | https://pub.dev/packages/record | BSD-3-Clause |
| just_audio | https://pub.dev/packages/just_audio | MIT |
| file_picker | https://pub.dev/packages/file_picker | MIT |
| share_plus / path_provider / shared_preferences | https://pub.dev | BSD-3-Clause，见实际包内 LICENSE |
| sqflite | https://pub.dev/packages/sqflite | BSD-2-Clause |
| crypto / http / path | https://pub.dev | BSD-3-Clause |
| uuid | https://pub.dev/packages/uuid | MIT |

Flutter 依赖许可证通过应用“设置 → 开源许可”展示。Whisper 引擎、模型和 Silero MIT 文本另行注册到同一许可页面。
品牌声波标志由原创 SVG 和确定性渲染脚本生成，无第三方图片或商用字体打包。
开发机系统字体只用于本地截图校验，不进入应用资源或分发包。
开发与测试用桌面模型、SDK、二进制产物及测试音频不提交到 Git。

原生英文烟测使用上游 samples/jfk.wav，结果仅用于功能验证，不作为中文或中英混合效果宣传。
