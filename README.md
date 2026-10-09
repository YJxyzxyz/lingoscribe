# 聆写 · LingoScribe

隐私优先的 iOS / Android 离线语音转写应用。Flutter 共享界面与业务，whisper.cpp 在设备上真实执行多语言转写。
当前正在完善商业发布验收，未宣称已通过手机性能验证或商店审核。

## 已实现的源码能力

本地录音与暂停、系统音频导入、端侧转写与取消、逐段时间戳回听、文本校对并保留原文、段落标记、本地搜索、TXT/Markdown/SRT/VTT/JSON 导出，以及可验证下载/导入/切换/删除的离线模型。
无需账号，没有音频上传、广告或统计 SDK；第一次下载模型需要联网，之后可断网使用。
付费下载是拟定商业模式，尚未配置商店价格和发行账号。

## 开发与验证

固定 Flutter 3.47.7，Java 17；Android 8+、iOS 15+。

```sh
cd apps/mobile
flutter pub get
flutter analyze
flutter test
flutter run
```

iOS 原生库需先在 macOS 运行 `bash tools/build_ios_engine.sh`。Android 原生库由 NDK/CMake 从固定上游源码直接构建。
正式签名、构建命令和账号需求见 [上架准备](docs/STORE_READINESS.md)。
产品研究见 [产品决策](docs/PRODUCT.md)，真实验证结果见 [测试说明](docs/TESTING.md)，尚未完成的工作见 [交付状态](docs/STATUS.md)。
[隐私说明](docs/PRIVACY.md)与[第三方许可](docs/THIRD_PARTY_NOTICES.md)随实际实现更新。

## 分支约定

- `main`：经过验证、可用于发布的代码。
- `feature/<名称>`：功能开发，完成验证后合并到 `main`。
- `fix/<名称>`：问题修复，完成验证后合并到 `main`。
- `release/<版本号>`：需要独立稳定和测试阶段时使用的可选发布分支。

## 日常开发

```powershell
git switch main
git switch -c feature/first-feature
# 开发完成后先检查差异，再提交明确选定的文件。
git status
git diff
git add <文件路径>
git commit -m "feat: 描述本次功能"
git switch main
git merge feature/first-feature
```

建议提交前缀：`feat:` 功能、`fix:` 修复、`docs:` 文档、`chore:` 工程维护。
仅提交源码和必要配置，不提交签名私钥、密码、本地环境或构建产物。
依赖锁文件应提交，以便复现构建。

## 版本与发布

用户可见版本采用 `主版本.次版本.修订版本`，例如 `1.0.0`。
Git 发布标签采用 `v<版本号>`，例如 `v1.0.0`，指向实际提交商店的源码。
iOS 与 Android 的构建编号分别记录和递增；同一版本重新提交构建时也应使用新的构建编号。
详细流程见 [发布指南](docs/RELEASING.md)，版本变更见 [更新日志](CHANGELOG.md)。

## 远程仓库

本地仓库初始化后，需接入 GitHub、GitLab 或其他 Git 服务以备份和协作。
将下面的占位符替换为自己创建的远程仓库地址：

```powershell
git remote add origin <远程仓库地址>
git push -u origin main
```

连接远程后，建议为 `main` 开启分支保护，并要求构建检查通过后合并。
