# DSH Remote Mobile

[English](README.md) | [简体中文](README.zh-CN.md)

> **非官方社区项目：** 本项目由社区独立开发和维护，未经 DeepSeek 审核、推荐或支持。

这是一个 Flutter 移动客户端，用于通过 DSH Relay 安全地打开电脑本地运行的 DeepSeek Harness。

<table>
  <tr>
    <td><img src="docs/images/mobile-login.png" alt="DSH Mobile 登录与 Relay 选择" width="320"></td>
    <td><img src="docs/images/mobile-devices.png" alt="已配对的 DSH 电脑" width="320"></td>
  </tr>
</table>

## 安装 Android 应用

从 [DSH Mobile Suite 最新 Release](https://github.com/april-jk/dsh-mobile-suite/releases/latest) 下载带版本号的已签名 APK。Android 提示时，允许浏览器或文件管理器安装未知应用，然后打开 **DSH Remote**。

APK 的应用 ID 是 `io.github.apriljk.dshremote`。安装前请使用同一 Release 中的 `SHA256SUMS` 校验下载文件。

## 环境要求

- Flutter 3.38.10（Dart 3.10）
- iOS 14 或更高版本
- Android 8.0（API 26）或更高版本

## 使用生产 Relay 运行

默认构建连接 `https://relay.dshmobile.online`：

```bash
flutter run
```

## 使用 Mock Relay 运行

Mock 模式必须显式启用，支持可重复的登录、配对、设备管理和会话状态测试。

```bash
flutter run --dart-define=DSH_USE_MOCK=true
```

可以使用任意有效邮箱、至少八位的密码和任意六位配对码。

## 准备电脑端

将 `@april-jk/dsh-mobile` 插件安装到 DSH Web profile，然后启动 DSH：

```bash
npx @deepseek-ai/dsh plugin --profile web add "github:april-jk/dsh-mobile-plugin#v0.1.5"
npx @deepseek-ai/dsh web
```

Companion 随 DSH Web 进程启停，不需要单独运行后台进程。

## 配对并远程打开 DSH

1. 打开移动应用并注册或登录。
2. 在电脑 DSH 中打开 **Settings > Remote Access**，创建六位配对码或二维码。
3. 在手机上点 **+**，扫描二维码或输入六位配对码，然后选择在线电脑。
4. 应用内会打开正常的 DSH Web UI，可以像在电脑上一样创建任务并提交指令。

电脑上的 DSH 始终监听 `127.0.0.1:3080`；插件只会向 Relay 建立加密的出站连接。

## 使用自建 Relay

```bash
flutter run \
  --dart-define=DSH_USE_MOCK=false \
  --dart-define=DSH_RELAY_URL=http://127.0.0.1:8787
```

Android 模拟器请使用 `http://10.0.2.2:8787`。实体设备需要 HTTPS Relay，或设备能够访问的开发域名。生产构建必须使用 HTTPS。

公开构建无需重新编译即可连接私有 Relay。登录前点击 **Relay** 服务器按钮，或登录后打开 **设置 > Relay 服务器**，输入 Relay 的 HTTPS Origin。电脑端必须使用相同地址，例如 `DSH_RELAY=https://relay.example.com npx @deepseek-ai/dsh web`。切换 Relay 会退出当前账号，因为 Token 属于原来的服务器。

## 验证

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --release --no-codesign
```

## Android Release 签名

Android 应用 ID 是 `io.github.apriljk.dshremote`。Release 构建绝不会回退使用 Android Debug 证书。

将 `android/key.properties.example` 复制为被 Git 忽略的 `android/key.properties`，并配置 Release keystore；也可以在 CI 中提供以下环境变量：

- `DSH_ANDROID_STORE_FILE`
- `DSH_ANDROID_STORE_PASSWORD`
- `DSH_ANDROID_KEY_ALIAS`
- `DSH_ANDROID_KEY_PASSWORD`

然后构建 Play Store Bundle：

```bash
flutter build appbundle --release
```

请将原始 keystore 和密码保存在可靠的密钥存储中。Android 后续更新必须使用同一密钥签名。

## 自动发布

GitHub Actions 会验证每个 Pull Request 和推送到 `main` 的提交。推送与应用版本（不含 build number）完全一致的 tag 会运行全部测试并发布产物，例如 `version: 0.1.5+1005` 对应 `v0.1.5`。发布内容包括：

- 已签名的 Android APK 和 AAB；
- 用于验证构建、不能直接安装的无签名 iOS `.app` 归档；
- 覆盖全部发布产物的 `SHA256SUMS`。

推送发布 tag 前，请在 GitHub Actions 中配置以下仓库 Secrets：

- `DSH_ANDROID_KEYSTORE_BASE64`：Release keystore 的 base64 编码；
- `DSH_ANDROID_STORE_PASSWORD`；
- `DSH_ANDROID_KEY_ALIAS`；
- `DSH_ANDROID_KEY_PASSWORD`。

任何签名 Secret 缺失时，发布任务都会失败，不会生成 Android Release。Apple 签名证书和 Provisioning Profile 配置完成前，暂不提供 iOS App Store 分发包。

Android versionCode 固定按 `MAJOR * 1,000,000 + MINOR * 1,000 + PATCH` 计算。`pubspec.yaml` 的 build suffix 必须与该值保持一致，确保 standalone 与 Suite 发布的版本码单调递增且可以相互覆盖升级。

## 许可证

[MIT](LICENSE)
