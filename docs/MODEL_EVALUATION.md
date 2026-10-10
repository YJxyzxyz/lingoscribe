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

原始 CER 不将简繁体视为相同字形。标点忽略，语气词、重复词及缩写拆分仍计入错误；因此这些数值同时受到书写格式和语料标注规范影响。混合组仅有 20 个英文参考词，四个错误即为 20%，波动非常大。
默认没有增加实验提示，它使混合英文结果退步。固定语言在本子集没有减少错误数；运行时长记录受并行宿主任务影响，不据此承诺加速。
另已实际评测许可明确的 Whisper Large v3 Turbo Q5_0，固定模型 574,041,195 字节，SHA-256 见 `validation/ascend-turbo-evaluation.json`。在本机 CPU 的这组短片段上，含每条模型载入的 RTF 为约 7.5–11.6，准确率收益不足以直接替换轻量模型，因此未加入产品目录；这不是手机性能结论。后续评估设备加速和长音频时须重新测量。

SenseVoice 的这次结果更适合进入下一轮评估。当前 App 仍使用已经在两端实际运行验证的 whisper.cpp；研究工具没有成为产品功能，也没有把另一套模型放进安装包或下载目录。
后续需扩展独立、长对话、多说话人、低音量和噪声集，并实际检查分段时间戳、取消、峰值内存、移动端速度及功耗，再决定是否增加第二种引擎。

## 来源与许可范围

- 音频：[HKUST CAiRE ASCEND](https://huggingface.co/datasets/CAiRE/ASCEND/tree/737e9800ae31be9932ba8464c80366559bd28424)，数据许可 CC-BY-SA-4.0，归属 HKUST CAiRE / Lovenia 等（LREC 2022）。音频和参考正文只保存在本机被忽略的 `build/`，不进入 App。
- SenseVoice 来源：[固定 ONNX 导出快照](https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/tree/2365baeacb507f821a0c8120fcee3d484dba7a07)。模型归属 Alibaba / FunAudioLLM，导出归属 k2-fsa / Fangjun Kuang。
- [官方模型卡](https://huggingface.co/FunAudioLLM/SenseVoiceSmall) 指向独立的 [FunASR 模型协议](https://github.com/modelscope/FunASR/blob/main/MODEL_LICENSE)。工具源码的 MIT / Apache 许可不等于权重许可。当前仅做参考研究；商业再分发条件需单独确认，不将其标成已获商业发布许可。

实际哈希、逐条错误数、评测规则与作用范围分别保存在 `validation/ascend-regression-evaluation.json`、`ascend-prompt-comparison.json` 和 `sensevoice-research-evaluation.json`。
`tools/evaluate_sensevoice.py` 使用本机 sherpa-onnx 1.13.8，校验模型和 tokens 的固定 SHA-256；每条重新加载模型，执行真实 CPU 推理，没有预置答案。默认输出省略参考和转写正文。
