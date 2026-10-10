# 真实语音回归与模型决策

2026-10-10 在同一份固定 ASCEND 测试子集上实际执行推理。两个说话人、18 条片段、合计约 66.5 秒；每种语言仅六条。选样规则在推理前固定，不按识别结果筛选。
这些是桌面回归结果，不能用于宣传总体准确率、手机速度或耗电。

| 模型 / 设置 | 中文组原始 CER | 混合组原始中文 CER | 混合组英文 WER | 英文组 WER |
| --- | ---: | ---: | ---: | ---: |
| Whisper Base Q5 / auto | 52.8% | 56.6% | 95.0% | 46.9% |
| Whisper Small Q5 / auto | 23.6% | 47.0% | 65.0% | 38.8% |
| Whisper Small Q5 / 固定语言 | 23.6% | 47.0% | 65.0% | 38.8% |
| Whisper Small Q5 / 固定语言与简体提示 | 18.1% | 49.4% | 80.0% | 38.8% |
| Whisper Large v3 Turbo Q5_0 / auto | 19.4% | 30.1% | 45.0% | 30.6% |
| SenseVoiceSmall int8 / auto | 9.7% | 18.1% | 20.0% | 22.4% |
| Qwen3-ASR 0.6B int8 / auto | 9.7% | 15.7% | 35.0% | 26.5% |

原始 CER 不将简繁体视为相同字形。标点忽略，语气词、重复词及缩写拆分仍计入错误；因此这些数值同时受到书写格式和语料标注规范影响。混合组仅有 20 个英文参考词，四个错误即为 20%，波动非常大。
默认没有增加实验提示，它使混合英文结果退步。固定语言在本子集没有减少错误数；运行时长记录受并行宿主任务影响，不据此承诺加速。
另已实际评测许可明确的 Whisper Large v3 Turbo Q5_0，固定模型 574,041,195 字节，SHA-256 见 `validation/ascend-turbo-evaluation.json`。在本机 CPU 的这组短片段上，含每条模型载入的 RTF 为约 7.5–11.6，准确率收益不足以直接替换轻量模型，因此未加入产品目录；这不是手机性能结论。后续评估设备加速和长音频时须重新测量。

SenseVoice 的这次结果更适合进入下一轮评估。当前 App 仍使用已经在两端实际运行验证的 whisper.cpp；研究工具没有成为产品功能，也没有把另一套模型放进安装包或下载目录。
后续需扩展独立、长对话、多说话人、低音量和噪声集，并实际检查分段时间戳、取消、峰值内存、移动端速度及功耗，再决定是否增加第二种引擎。

## Qwen3 候选引擎

2026-10-10 对固定 Qwen3-ASR 0.6B int8 ONNX 快照实际运行 sherpa-onnx 1.13.8 的 CPU 推理，完整文件哈希及 18 条结果见 `validation/qwen3-research-evaluation.json`。沿用同一原始 CER/WER 规则，未增加术语提示或人工修改输出。它在这份小样本改善了中文和混合语音结果，纯英文仍有误识别。
三项 ONNX 文件合计 982,554,174 字节，另有约 4.5 MB tokenizer；桌面进程运行前六条时已观察到约 1.44 GB 的进程峰值工作集。这是 Windows 进程观察，不能推算手机内存或耗电。短音频的模型载入时间占比较高，报告分别记录载入和推理；本轮宿主另有回归/构建任务，运行时间不作模型速度排名。

上游 [固定官方模型卡](https://huggingface.co/Qwen/Qwen3-ASR-0.6B/blob/5eb144179a02acc5e5ba31e748d22b0cf3e303b0/README.md) 标注 Apache-2.0，[sherpa-onnx 官方说明](https://k2-fsa.github.io/sherpa/onnx/qwen3-asr/pretrained.html) 提供相应导出用法。实际使用的 [ONNX 固定快照](https://huggingface.co/csukuangfj2/sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25/tree/68818b2313fe77bd06f6a7c5068ff3ef59d02b8a) 归属 Qwen / Alibaba、Wasser1462 / zengshuishui 与托管者 Fangjun Kuang；尚未将其作为产品下载或随 App 分发。
下一步先做扩大语料对照、移动端内存和时延验证，再处理原生依赖许可、可靠时间戳、取消与多文件模型的原子安装。不能用另一款模型的研究结果冒充当前 App 能力。

## 扩大到 90 条的对照

同一固定 test split 按预设轮转规则选取中文、英文、混合各 30 条，共约 316.6 秒。中文和混合组各为每位说话人 15 条；英文组一位只有 10 条满足时长条件，另一位取 20 条。该子集包含原先 18 条，仍只有两位说话人，不是独立人群验证。

| 模型 / 自动语言 | 中文组原始 CER | 混合组原始中文 CER | 混合组英文 WER | 英文组 WER |
| --- | ---: | ---: | ---: | ---: |
| Whisper Base Q5 | 50.7% | 60.7% | 93.1% | 36.1% |
| Whisper Small Q5 | 42.0% | 51.4% | 73.6% | 27.1% |
| Qwen3-ASR 0.6B int8 | 8.7% | 16.9% | 33.3% | 18.4% |

两份真实执行报告分别为 `validation/ascend-expanded-evaluation.json` 和 `validation/qwen3-expanded-evaluation.json`，使用相同音频与参考清单 SHA-256。结果显示当前 Small 的自然混合语音仍是产品短板。Qwen3 是优先进入移动端验证的候选，而不是已经实现的产品能力；数据覆盖、简繁体、语气词、缩写与数字评分规则等限制仍适用。
Qwen3 每条重新载入模型，线程数为四，输出 token 上限 128；长音频和更长输出不在该回归范围内。真实执行有其他宿主任务交叠，不将两报告的桌面 RTF 用于速度排名。

## 来源与许可范围

- 音频：[HKUST CAiRE ASCEND](https://huggingface.co/datasets/CAiRE/ASCEND/tree/737e9800ae31be9932ba8464c80366559bd28424)，数据许可 CC-BY-SA-4.0，归属 HKUST CAiRE / Lovenia 等（LREC 2022）。音频和参考正文只保存在本机被忽略的 `build/`，不进入 App。
- SenseVoice 来源：[固定 ONNX 导出快照](https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/tree/2365baeacb507f821a0c8120fcee3d484dba7a07)。模型归属 Alibaba / FunAudioLLM，导出归属 k2-fsa / Fangjun Kuang。
- [官方模型卡](https://huggingface.co/FunAudioLLM/SenseVoiceSmall) 指向独立的 [FunASR 模型协议](https://github.com/modelscope/FunASR/blob/main/MODEL_LICENSE)。工具源码的 MIT / Apache 许可不等于权重许可。当前仅做参考研究；商业再分发条件需单独确认，不将其标成已获商业发布许可。

实际哈希、逐条错误数、评测规则与作用范围分别保存在 `validation/ascend-regression-evaluation.json`、`ascend-prompt-comparison.json` 和 `sensevoice-research-evaluation.json`。
`tools/evaluate_sensevoice.py` 使用本机 sherpa-onnx 1.13.8，校验模型和 tokens 的固定 SHA-256；每条重新加载模型，执行真实 CPU 推理，没有预置答案。默认输出省略参考和转写正文。
