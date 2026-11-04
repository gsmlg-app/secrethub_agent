# secrethub_agent

嵌入 Flutter App 的 SecretHub 移动端 Agent，面向 iOS 和 Android。每个安装实例拥有独立身份，直接连接外部 SecretHub Core。

当前处于设计阶段，尚未实现 SDK。仓库初始内容为设计规格和开发交接说明，供后续 Codex 或开发者实施。

设计要求包括：

- Dart 公共 API，配合 Swift、Kotlin 原生安全与连接适配。
- 不可导出的安装身份及 TLS 私钥，通过原生接口完成 mTLS。
- 配置 secret 读取、签名离线授权、加密缓存和离线冷启动。
- 明确的授权期限、吊销延迟、恢复规则及持久化访问审计。

[完整设计规格](https://github.com/gsmlg-app/secrethub_agent/blob/main/DESIGN.md)包含客户端与外部 Core 的协议契约，以及 30 条验收标准。本文档可独立交接，不依赖其他项目的源码布局。

Core 由外部服务端项目提供；完整联调需要 Core 支持设计中的移动端能力。协议替身、单元测试和模拟器验证分别记录，真机互操作以实际结果为准。

[Codex 开发指引](https://github.com/gsmlg-app/secrethub_agent/blob/main/AGENTS.md)规定工作范围、安全约束和验证要求。
