# 上架准备与发布门槛

当前版本是持续开发中的真实实现，尚未声称通过商店审核或完成手机性能验收。

## 商店资料草案

- 名称：聆写 · LingoScribe（需核查商标和商店名称可用性）。
- 定位：设备上的双语语音转写、回听校对和字幕导出。
- 拟定价格：$4.99 / ¥28 付费下载，以商店价格档位及税费为准。
- 说明：无需账户；首次下载模型联网，之后离线工作；没有服务端音频上传或按分钟收费。
- 支持语言：中文、英文、自动语言识别；中英混合效果待测试集验证，不宣传“百分百准确”。
- 当前 UI：中文。正式国际发行需完成英文 UI 本地化和对应截图。
- 内容：用户自有音频，不自带第三方受版权保护音频。

## 必须补齐

- 开发者经营主体、支持邮箱、公开隐私 URL、支持 URL、商标/名称核查。
- Apple Developer 团队 ID、证书、Provisioning Profile、App Store Connect 应用及 TestFlight。
- Android 商店选择、开发者账号、上传密钥及 Play App Signing；需要发行大陆 Android 市场时另行核对各市场要求。
- 真实设备截图、权限行为、后台/中断、低存储、飞行模式及升级迁移验证。
- 中英与混合语音基准及可复现测试报告；低端设备内存与耗电实测。
- 最终依赖锁定、完整许可审计、隐私表单与 Apple Privacy Manifest 汇总审查。

## 构建方式

固定 Flutter 3.47.7，Java 17，Android SDK 36，NDK 28.2.13676358，CMake 3.22.1；iOS 15+，Android 8+，正式 Android 首发目标 arm64。

```sh
cd apps/mobile
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --target-platform android-arm64,android-x64
flutter build appbundle --release --target-platform android-arm64
```

没有 `android/key.properties` 时 release 产物未签名，不可直接提交商店。复制 `key.properties.example` 并在本地/CI 私密配置签名。
密钥不得入库，密钥备份应存放于独立安全位置，丢失密钥会影响后续更新。

macOS / Xcode 上：

```sh
bash tools/build_ios_engine.sh
cd apps/mobile
flutter config --no-enable-swift-package-manager
flutter pub get
flutter build ios --release --no-codesign
# 在 Xcode 中配置真实 Team、Signing，并执行 Archive；或配置专用签名 CI。
```

CI 的 unsigned AAB / iOS .app 仅用于编译验证，不能当作已签名商店包。正式发布标签必须在真机验收及签名验证之后建立。

## 官方依据（2026-10-09 核查）

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)：真实功能、隐私、许可和商店审核资料需与实际构建一致。
- [Apple Privacy Manifest](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)：依赖及访问受管 API 的声明需要根据最终构建复核。
- [Android 16 KB page sizes](https://developer.android.com/guide/practices/page-sizes)：应用包含原生库，需要检查实际 ELF 与 APK/AAB 对齐；已配置 NDK 28 和 16 KB 链接对齐，尚需检查产物。
- [Google Play review preparation](https://support.google.com/googleplay/android-developer/answer/9859455)：隐私、数据安全与应用访问资料需填写。
