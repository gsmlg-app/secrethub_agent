# secrethub_agent

嵌入 Flutter App 的 SecretHub 移动端 Agent，面向 iOS 和 Android。每个安装实例拥有独立身份，直接连接外部 SecretHub Core。

仓库已开始初始化为独立 Flutter 插件。当前提供 Dart 入口、Swift/Kotlin 原生注册和示例 App；`getPlatformVersion()` 只用于检查原生插件是否注册，不表示安全设施或 Agent 运行时已经可用。注册审批、secret 读取、离线缓存、审计和续证尚未实现。

设计要求包括：

- Dart 公共 API，配合 Swift、Kotlin 原生安全与连接适配。
- 不可导出的安装身份及 TLS 私钥，通过原生接口完成 mTLS。
- 配置 secret 读取、签名离线授权、加密缓存和离线冷启动。
- 明确的授权期限、吊销延迟、恢复规则及持久化访问审计。

[完整设计规格](DESIGN.md)包含客户端与外部 Core 的协议契约，以及 30 条验收标准。先完成两端的不可导出原生密钥 → CSR → Core 签发 → 原生 mTLS WSS 真机链路，再展开其余 SDK 实现。

## 本地开发

初始化使用 Flutter 3.47.9 stable / Dart 3.13.7。目标为 iOS 15+、Android 9 / API 28+，仅注册这两个平台；当前包禁止发布。iOS 最低版本随当前 Flutter 引擎要求提高，详见开发说明。

```sh
flutter pub get
flutter analyze
flutter test
cd example
flutter pub get
flutter analyze
flutter test
flutter run
```

示例仅展示初始化状态和原生系统版本，不请求或显示 secret，也不连接 Core。检查原生注册的 Dart 入口：

```dart
import 'package:secrethub_agent/secrethub_agent.dart';

final platformVersion = await SecretHubAgent().getPlatformVersion();
```

`DESIGN.md` 第 12 节中的 `start()`、`read()` 等是待实现的目标接口，目前不能用于业务接入。

- [开发环境与首条原生链路](docs/development.md)
- [验证结果与 30 条验收状态](docs/verification.md)

Core 由外部服务端项目提供；完整联调需要 Core 支持设计中的移动端能力。协议替身、单元测试和模拟器验证分别记录，真机互操作以实际结果为准。

[Codex 开发指引](AGENTS.md)规定工作范围、安全约束和验证要求。
