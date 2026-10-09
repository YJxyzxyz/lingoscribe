# App 项目

用于管理面向 iOS 和 Android 的应用源码、版本变更和发布记录。
当前已建立 Git 仓库，应用名称、技术栈和构建流程将在开发时补充。

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
