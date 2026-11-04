# Codex 开发指引

本项目是独立 Flutter 插件，面向 iOS 和 Android。设计规格见 [Dart / Flutter 移动端 Agent 设计](https://github.com/gsmlg-app/secrethub_agent/blob/main/DESIGN.md)。以检出的设计规格和当前任务指令确定工作范围。

当前仓库交付设计文档，SDK 尚未实现。收到开发任务后按其授权范围实施；文档任务保持文档范围，提交、发布和部署分别遵循任务指令。

## 项目边界

- 交付 Dart API、Swift/Kotlin 原生适配、示例 App、协议向量、测试与使用文档。
- Core 是外部服务；本项目不包含服务端源码、数据库迁移或管理界面。
- 缺少 Core 必需能力时报告不兼容并列明集成依赖，不使用弱化身份或授权的替代协议。
- 不引入用户账户或管理登录系统。

## 安全约束

- 安装身份和 TLS 私钥由原生密钥设施生成并使用，必须不可导出；不通过 Dart 或临时 PEM 传递。
- secret 明文越过原生边界前完成原生审计准入及交付检查；离线读取还须验证 grant、缓存、时钟和失效状态。
- 已知 Core 拒绝、吊销、TLS 信任错误和同步屏障优先于离线缓存。
- 离线冷启动依赖可信 OS 时间；不宣称能抵抗整机时间与存储联合回滚。
- secret、token、私钥、缓存密钥和 secret-derived digest 不进入日志、异常文本或示例输出。

## 工作与验证

- 开工前检查现有改动，保留他人的工作。优先使用现有依赖和直接的数据流，避免无关抽象。
- 使用当前分支；仅在用户明确要求时创建分支或 Git worktree。
- 先验证两端原生密钥、CSR、Core 签发和 mTLS WSS 的完整链路，再展开其余实现。
- 以设计中的 30 条验收标准组织证据。分别报告通过、失败、未执行和环境阻塞；模拟器或编译成功不能代替真机结果。
- 未经请求不发布到 pub.dev，不部署生产服务；不修改外部 Core 项目。

## Agent skills

- [verification-before-completion](https://github.com/obra/superpowers/blob/main/skills/verification-before-completion/SKILL.md)：用实际命令结果支持完成结论，保留测试与设备验证的边界。
