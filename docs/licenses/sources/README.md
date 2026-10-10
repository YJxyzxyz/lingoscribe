# 附加原生许可文本来源

- `LLVM_LICENSE.txt`：从 LLVM 官方仓库固定标签 [llvmorg-19.1.7](https://github.com/llvm/llvm-project/blob/llvmorg-19.1.7/LICENSE.TXT) 下载，保留完整 Apache 2.0、LLVM exception 和上游附带声明。用于固定 ggml 快照中标记为 `Apache-2.0 WITH LLVM-exception` 的可选 SYCL 源码；当前移动端未启用 SYCL / OpenVINO。
- `YARN_MIT.txt`：从 [YaRN 上游 LICENSE](https://github.com/jquesnelle/yarn/blob/master/LICENSE) 下载，保留 Jeffrey Quesnelle 与 Bowen Peng 的 MIT 声明；ggml CPU `ops.cpp` 引用了其算法。
- 其余声明直接从固定 `native/vendor/whisper.cpp` 文件读取，不改写上游源码。

执行 `python tools/audit_native_licenses.py` 会生成带原文件 SHA-256 的归属清单，并同步应用内原生许可文本。
此清单记录源码中的显式归属，不能替代对未来新增依赖的人工复核。
