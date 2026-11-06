# 开发说明

## 初始化边界

本次初始化建立标准 Flutter 插件、两端原生注册、示例及测试入口。原生系统版本诊断只证明 method channel 注册，不生成密钥、不发起网络连接、不持有安装身份，也不提供 secret API。

宿主通过路径依赖进行本地开发：

```yaml
dependencies:
  secrethub_agent:
    path: ../secrethub_agent
```

`example/` 已配置本地插件依赖。它不包含管理登录、Core 凭据或真实 secret。注册审批、按配置读取、来源与期限、离线冷启动及拒绝/过期展示，须随真实 SDK 实现后加入。

## 工具链与平台

初始化环境记录于 2026-11-05：

| 项目 | 版本 |
| --- | --- |
| Flutter | 3.47.9 stable，framework `c197ca5199` |
| Dart | Flutter 自带 3.13.7 |
| Xcode | 27.2，build `27B52` |
| Swift 编译器 | 6.4.2 |
| Android SDK | 36.1.0 |
| Android 构建 JDK | OpenJDK 21.0.13.0.3 |
| Android 构建设置 | Kotlin 2.4.0、AGP 9.1.0、Gradle 9.3.1；JVM target 17 |
| Swift 构建设置 | Package tools 5.9；CocoaPods Swift 语言模式 5.0 |
| 插件目标基线 | iOS 15；Android API 28 |

Swift、Kotlin 的语言/构建设置以检入的原生工程为准；编译器版本不等于 Swift 源码语言模式。示例 App 使用开发用标识，宿主 App 的正式 bundle/application ID 由集成环境提供。

设计建议的 iOS 13 基线需要按选用的 Flutter 版本核对。Flutter 3.47.9 的平台工具和 `ios-arm64/Flutter.framework/Info.plist` 均要求最低 iOS 15，因此插件 podspec、Swift Package 和示例统一为 iOS 15，不能宣称兼容 iOS 13/14。

Dart 约束为 `sdk: ^3.13.7`、`flutter: >=3.47.9`。除 Flutter SDK 依赖外，插件使用模板的 `plugin_platform_interface: ^2.0.2`（初始化解析为 2.1.8）及开发检查 `flutter_lints: ^6.0.0`。示例检入 `pubspec.lock` 以固定解析结果；库包的根 lockfile 按 Flutter 模板忽略。

`flutter doctor -v` 当前报告两项工具链提示：PATH 中独立的 Dart shim 与 Flutter SDK 不一致，以及 Xcode 27.2 对应的 iOS 27.2 Simulator 未安装。执行 Dart 检查时优先使用当前 Flutter SDK 自带的 `bin/dart`。安装模拟器不是不可导出密钥或 mTLS 真机验收的替代方式。

## 首条实现与集成门槛

按 [设计第 5、6、7、16 节](../DESIGN.md)优先完成以下整条路径，然后开始读取、缓存、同步、审计和续证功能：

1. iOS 在真实设备 Secure Enclave 中生成独立的安装身份 key 和 TLS key，使用 ThisDeviceOnly、设备解锁访问控制；Android 在 App 私有 Keystore 中生成独立 key，记录实际 software / TEE / StrongBox 等级。
2. 原生 TLS key 签名 CSR，安装身份 key 签名受限 domain 的 enrollment proof；核对 subject/SAN、challenge、CSR 摘要及两把 key 的独立性。添加 DER ECDSA / JOSE `r || s` 跨语言向量。
3. 由真实 Core 创建和审批 mobile enrollment，签发绑定安装公钥及 Agent SAN 的客户端证书。pending token 只留在原生受保护存储中。
4. iOS 将证书关联到原有 Secure Enclave key 的 `SecIdentity`；Android 通过 `X509KeyManager` 使用 Keystore 私钥句柄。以预配服务端信任建立原生 mTLS WSS，完成真实 `agent:runtime` join。
5. 验证五项移动端必需能力及证书绑定，记录设备、系统、插件版本、Core SHA 和 key security level。任何平台不支持真实 key handle 或证书关联时报告阻塞。

开始联调前，集成环境须提供：受信的 Core HTTPS origin、系统信任或受控 CA 材料、审批操作者、宿主 App 标识，以及支持设计中移动端协议的 Core 版本/SHA。当前任务未提供这些材料，仓库中的 `core.example.com` 只是文档示例，不能作为部署地址使用。

不得以可导出 PEM、Dart 软件私钥、HTTP/token 读取、忽略 TLS 错误或弱化服务端能力检查来完成此门槛。协议替身可以用于确定性测试，不能证明真实 Core 互操作。

## 后续交付约束

[设计第 16 节](../DESIGN.md)要求的完整 SDK 交付仍包括目标 Dart API、两端安全实现、跨语言 schema 与测试向量、缓存格式/升级规则、注册恢复说明以及完整示例。初始化骨架不代表这些交付物已经完成。

原生层必须在明文跨越 platform channel 前完成审计准入、grant/cache 和交付检查；不增加通用签名、任意 URL、任意帧发送或原始 secret 响应接口。身份、缓存、信任和审计数据须排除备份；清缓存不解除已知拒绝、吊销、同步屏障或时间异常。

离线冷启动依赖可信 OS 时间，不能承诺抵抗整机时间与存储联合回滚。私钥、secret、token、缓存密钥和 secret-derived digest 不进入日志、错误或示例输出。

本仓库不包含 Core 服务端，不部署生产服务，不发布到 pub.dev。真机结果与构建、模拟器、单元测试结果分别记录于 [验证报告](verification.md)。
