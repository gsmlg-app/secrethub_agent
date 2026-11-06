# 验证报告

日期：2026-11-05。范围：仓库初始化。规格：[DESIGN.md](../DESIGN.md)，验收要求见第 17 节。

本报告区分插件骨架检查与 SDK 验收。系统版本诊断不验证不可导出密钥、注册、TLS、读取授权、缓存或审计。完整 SDK 尚未实现，以下 30 项均不能据骨架测试判为通过。

## 初始化检查

| 检查 | 命令或证据 | 结果 |
| --- | --- | --- |
| Dart 格式 | Flutter SDK 自带 `dart format --output=none --set-exit-if-changed lib test example/lib example/test example/integration_test` | 通过；8 个文件，0 个修改 |
| 插件静态检查 | 仓库根目录 `flutter analyze` | 通过；`No issues found` |
| 插件 Dart 测试 | 仓库根目录 `flutter test` | 通过；5 项测试；诊断委托、无参数通道调用、平台错误和插件缺失传播 |
| 示例静态检查 | 在 `example/` 执行 `flutter analyze` | 通过；`No issues found` |
| 示例 widget 测试 | 在 `example/` 执行 `flutter test` | 通过；4 项测试；注册与 SDK 状态区分、错误脱敏、插件缺失及 null 响应 |
| Android debug 编译 | 在 `example/` 执行 `flutter build apk --debug` | 通过；退出码 0，275.9 秒；产物 `example/build/app/outputs/flutter-apk/app-debug.apk` |
| Android 原生单元测试 | 在 `example/android/` 执行 `./gradlew :secrethub_agent:testDebugUnitTest` | 通过；2 项测试，`BUILD SUCCESSFUL`；覆盖系统版本诊断和未知方法拒绝 |
| iOS 未签名 debug 编译 | 在 `example/` 执行 `flutter build ios --debug --no-codesign` | 通过；退出码 0，Xcode 编译 33.0 秒；产物 `example/build/ios/iphoneos/Runner.app`；产物最低 iOS 15 |
| Swift 原生单元测试 | `example/ios/RunnerTests/RunnerTests.swift` | 未执行；普通 App 编译不运行 XCTest |
| 原生注册集成测试 | `example/integration_test/plugin_integration_test.dart` | 未执行；没有安装或运行到设备/模拟器 |
| 变更检查 | `git diff --check` 及全部新增文件的 `git diff --no-index --check` | 通过；新增文件无空白错误；`DESIGN.md`、`AGENTS.md` 无改动 |
| 文档链接与验收编号 | 检查 README/开发说明/本报告的本地链接与矩阵编号 | 通过；链接有效，AC-01 至 AC-30 各出现一次 |

Dart 共 9 项、Kotlin 共 2 项测试通过。Dart channel/widget 测试使用 mock，不证明原生设施或 TLS 互操作。Kotlin XML 证据位于 `example/build/secrethub_agent/test-results/testDebugUnitTest/TEST-app.gsmlg.secrethub_agent.SecrethubAgentPluginTest.xml`，记录 2 tests、0 failures、0 errors。

示例最初的 missing-plugin 测试曾失败：`pumpAndSettle` 不等待未 mock 的 host channel 响应，导致断言时 UI 尚未更新。改为明确返回 `MissingPluginException` 的 mock 后，保留原断言，最终 4 项测试通过。无尚未解决的初始化测试失败。

Android APK 构建只证明编译与打包，未安装到设备；iOS 产物未签名，未进行设备部署或启动验证。Kotlin 测试输出含 AGP/Kotlin 旧 DSL 兼容设置的弃用提示，以及 Mockito/Byte Buddy 动态 Java agent 提示；当前检查通过，未为消除提示改写 Flutter 模板兼容设置。

## 真机与外部集成

环境枚举可见 Pixel Fold（Android 17 / API 37）、Pocket DS（Android 13 / API 33）、iPhone 11 和 iPad Air 13-inch M3（iOS 27.0.1）。本次初始化未在设备安装或运行插件；可见设备不等于设备验收通过。

未提供 Core 地址、受控信任材料、审批环境或 Core SHA，真实 Core 互操作未执行。没有尝试连接文档示例地址。模拟器运行未执行；Xcode 的 iOS 27.2 Simulator 目前未安装。编译、单元测试和 mock channel 不能替代真机密钥及 mTLS 验证。

## 设计验收矩阵

状态含义：通过须有覆盖该项的实际证据；失败表示已执行但结果不符合；未执行表示实现或测试尚未执行；环境阻塞表示缺少必需的外部集成条件。某项同时缺实现和环境时，保留两者说明。

| 编号 | 场景 | 当前状态 | 尚需的证据 |
| --- | --- | --- | --- |
| AC-01 | 安装实例隔离 | 未执行 | 两个安装实例的独立密钥、Agent、策略、缓存及 grant 互换拒绝 |
| AC-02 | 首次注册与审批前读取 | 未执行 | 真实 pending 状态及审批前无 secret/grant 交付 |
| AC-03 | CSR 替换与 challenge 重放 | 未执行；Core 环境阻塞 | proof/CSR 跨语言向量和真实 Core 拒绝结果 |
| AC-04 | iOS 真机 mTLS | 未执行；Core 环境阻塞 | Secure Enclave key、CSR、SecIdentity、真实 WSS join；记录设备与 Core SHA |
| AC-05 | Android 真机 mTLS | 未执行；Core 环境阻塞 | Keystore 私钥句柄的真实 WSS join、不可导出检查及实际 security level |
| AC-06 | 密钥设施不可用或永久失效 | 未执行 | 两端拒绝读取、明确错误且无软件/PEM/token fallback |
| AC-07 | floor 2 与新旧客户端 | 未执行；Core 环境阻塞 | 真实 Core 能力协商及旧服务器/UDS 客户端安全回归 |
| AC-08 | 在线授权与权威拒绝 | 未执行；Core 环境阻塞 | allow、deny、损坏策略、sealed、审计失败及离线不覆盖拒绝 |
| AC-09 | 值格式与数值精度 | 未执行 | Text/Structured、换行、`value` 字段、大整数和 legacy 格式向量 |
| AC-10 | 离线权限与 TTL 缺失 | 未执行 | 在线 read 成功与 offline 未准备的独立结果 |
| AC-11 | 离线无法验证的策略条件 | 未执行 | IP/实时配额/时间等条件的 grant 拒绝及在线授权结果 |
| AC-12 | TTL 和证书截止 | 未执行 | 各项 min 截断、`exp` 边界立即过期及无宽限 |
| AC-13 | 网络断开和超时 | 未执行 | 仅允许的网络错误触发合法离线读取，保留真实授权时间 |
| AC-14 | 离线冷启动 | 未执行 | 系统终止 App 后依靠原生持久状态、可信时间和审计完成读取 |
| AC-15 | 挂起与深度休眠 | 未执行 | 真机休眠计入 TTL，过期唤醒后拒绝 |
| AC-16 | 时间异常及损坏锚 | 未执行 | 持久化 block、高水位、重启/清缓存不解除；保留整机回滚限制 |
| AC-17 | 缓存与 grant 篡改 | 未执行 | AEAD、签名、绑定、digest、高水位和未知 kid 拒绝向量 |
| AC-18 | 中断、磁盘满、队列满 | 未执行 | 原子缓存恢复、离线准备失败、交付前审计容量检查 |
| AC-19 | 在线拒绝后断网或重启 | 未执行 | 持久化拒绝优先于旧 grant，清缓存不解除 |
| AC-20 | 离线期间撤销/rotation | 未执行 | 到期边界、恢复后先同步失效及明确的可信时间前提 |
| AC-21 | 同步部分返回或掉线 | 未执行 | 同步屏障持续阻止交付，不凭 join 成功放行 |
| AC-22 | signer 轮换及 bundle 回退 | 未执行 | key 先分发、generation 高水位及旧 grant 到期 |
| AC-23 | 续证激活与崩溃恢复 | 未执行 | CSR/activation 幂等、响应丢失恢复、旧身份和 grant 不回退 |
| AC-24 | 证书过期及身份撤销 | 未执行 | 过期 mTLS/grant/token 无法续期，人工恢复审批边界 |
| AC-25 | 审计积压、重放、冲突和断传 | 未执行 | 交付前持久化、提交后确认、去重和冲突证据保留 |
| AC-26 | 原生交付边界崩溃 | 未执行 | unknown 观察保留，不虚报业务使用或重发 secret |
| AC-27 | 卸载残留与备份恢复 | 未执行 | iOS 新安装隔离、Android 缺钥拒绝、旧审计不冒名补传 |
| AC-28 | 多 isolate 与连接竞态 | 未执行 | 单协调器、generation 隔离、取消/迟到响应及 Future 只完成一次 |
| AC-29 | 敏感材料泄漏检查 | 未执行（完整 SDK） | 实现后检查日志、错误、示例、缓存及审计；当前示例不处理 secret |
| AC-30 | 最终证据报告 | 未执行（最终验收） | 完整 Core 回归、Dart/模拟器和两端真机结果；本报告仅记录初始化 |

本次未提交、推送、发布、合并或部署。
