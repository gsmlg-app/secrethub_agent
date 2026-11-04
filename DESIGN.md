# Dart / Flutter 移动端 Agent 设计

日期：2026-10-29。修订：2026-11-05。状态：供 Codex 或开发者创建独立项目的设计规格。

项目名称：`secrethub_agent`。目标项目：[gsmlg-app/secrethub_agent](https://github.com/gsmlg-app/secrethub_agent)。本项目是独立的 Flutter 插件，公开 Dart API，原生适配 iOS、Android，连接外部 SecretHub Core 服务。

本文可单独交给另一环境中的 Codex，用于从空项目开始开发；项目不依赖 SecretHub 服务端的源码目录、构建系统或其他设计文件。本文包含客户端设计、服务端必须提供的协议契约和验收标准，不代表功能已经实现。文中的 HTTPS/WSS 地址是网络接口，dot path 是 secret 的逻辑名称，均不是文件系统位置。

实施环境需要提供 Flutter/Dart 工具链、Android 构建工具链，以及用于 iOS 构建的 macOS/Xcode；真机验收需要对应设备和支持本协议的 Core。Core 地址、CA、审批操作者及 App 标识由集成环境提供，示例域名不代表已部署服务。Core 的内部实现、数据库迁移和管理界面由服务端项目负责；本文以外部契约说明其协作要求。开发、提交、发布和部署范围以实施者收到的任务指令为准。

## Agent skills

以下为公开的执行技能参考；技能不扩大任务授权。项目的功能、安全及验收要求均在本文中定义，不依赖某台机器预装的技能文件。

- [verification-before-completion](https://github.com/obra/superpowers/blob/main/skills/verification-before-completion/SKILL.md)：按第 17 节提供实际证据，分别报告协议测试、模拟器测试、真机验证和部署验收结果。

## 1. 目标与已经确认的需求

提供一个嵌入 Flutter App 的 Agent 插件。每个 App 安装实例拥有独立的 Agent 身份，直接连接 SecretHub Core，通过配置读取获准的 secret。

已经确认：

1. 面向 iOS、Android，采用 Flutter 插件，公开 Dart API。
2. 每个安装实例直接作为 Agent；身份和授权不由一个独立手机 App 共享。
3. 身份私钥在原生密钥系统中生成、使用，必须不可导出；mTLS 使用原生密钥接口完成。
4. 支持在线读取、加密离线缓存、缓存有效期及明确的吊销延迟。
5. 支持离线冷启动：App 被系统终止后，可以读取仍有效的已有缓存。
6. 交付形式为独立项目的设计文档，供 Codex 或开发者实施。

第一版覆盖静态 secret 的显式 Text、Structured 格式，注册审批、mTLS、在线读取、离线读取、续证、失效处理和访问审计。

第一版不包含 secret 写入、动态凭据、SSH Agent、UDS 服务、跨 App 共享、Human Vault 客户端、独立管理 App、远程设备证明、后台常驻保证、pub.dev 发布或生产部署。对未显式分类的 legacy value format 返回格式不支持，不自行推断。

## 2. 设计默认值与安全保证

以下数值是本稿的设计默认值，不是用户已经确认的业务要求。实施者应按本稿实现为有界配置，产品评审可以调整配置默认值。

| 项目 | 默认或上限 | 决定方 |
| --- | --- | --- |
| 每个 secret 的离线使用 | 默认关闭，Core 策略和 App 配置均显式开启 | Core 授权，App 只能收窄 |
| 请求的离线 TTL | 1 小时 | App 可以请求更短时间 |
| Core 离线 TTL 硬上限 | 24 小时 | Core 配置 |
| 单安装实例配置路径数 | 最多 128 | 插件与 Core 共同限制 |
| 单 secret 解码后数据 | 最多 64 KiB | 插件与 Core 共同限制 |
| 单条运行时 JSON 帧 | 最多 256 KiB，解析前限制 | 原生 transport 与 Core |
| 单个 compact grant | 最多 8 KiB | 原生校验器与 Core |
| 加密 secret 缓存 | 最多 8 MiB、128 项 | 插件限制；满时拒绝新增，不淘汰未过期项 |
| 并发业务读取 | 最多 8 个 | 插件限制 |
| 在线读取超时 | 5 秒 | App 可在 1–30 秒内配置 |
| 重连退避 | 1 秒起，最多 60 秒，加入随机抖动 | 插件 |
| 本地审计积压 | 最多 10,000 条且最多 8 MiB，先达到者生效 | 原生审计队列 |
| 计时异常容差 | 5 秒；不增加 grant 的有效期 | 插件 |

TLS 与注册遵守第 3 节定义的 Core 信任边界。在线读取要求当前 Core 授权和成功的审计持久化。离线读取采用 Core 预先签发的有限期授权，允许在该授权期限内使用对应版本的缓存。

**离线冷启动依赖可信操作系统及其时间。** 本稿不承诺抵抗越狱/root、内核被控制、或跨冷启动对整机时间与受保护存储的联合回滚。回拨检测和时间高水位可以发现部分异常，不能证明离线绝对时间。本稿中的离线吊销延迟上限以该时间信任条件成立为前提。若以后要求无此条件的严格时限，需要重新评审可信计时或放弃离线冷启动，不能仅靠加密缓存宣称满足。

不可导出的保证针对身份私钥、TLS 私钥及原生存储保护密钥。已经返回 Dart 的 secret 是业务可使用的明文；插件不能收回业务保存的副本，也不能承诺阻止已被控制的 App 进程调用其仍有权使用的密钥。

## 3. 外部服务边界与兼容要求

SecretHub Core 是外部服务，负责 CA、安装实例审批、策略、secret 存储和审计。本项目只通过本文定义的网络协议与其交互，不调用 Core 内部函数，不共享服务端数据库。下列要求是集成契约：

| 范围 | 服务端要求 | 插件要求 |
| --- | --- | --- |
| 运行时身份 | 只从已验证的 Core-issued mTLS 证书确定 Agent 及证书状态 | 不通过请求体、token 或 App 标识选择运行时身份 |
| 安装实例注册 | 支持 `mobile_installation` 身份、公钥绑定、人工审批及 CSR 证明 | 使用原生安装实例密钥；不伪造 SSH 主机身份 |
| 网络入口 | 提供 HTTPS 注册和专用 mTLS WSS；通常使用端口 4665 | 连接受信的 Agent origin，不连接管理端实现读取 |
| 静态读取 | 按当前 Agent、证书、策略和 secret revision 授权并持久化审计 | 使用 `secret:read_agent`，严格区分在线结果与离线 grant |
| 能力协商 | 按服务端登记的身份类型检查能力，满足第 7 节完整集合 | 只声明实际支持的移动端能力 |
| 离线授权 | 额外验证 `read_offline` 并签发有限期、绑定身份和内容的 grant | 只在第 9、10 节准入条件成立时释放缓存 |
| 审计 | 支持第 14 节完整 v2 契约、去重和提交后确认 | 不把离线设备观察伪装为 Core 当前批准 |
| 续证 | 支持第 11 节 CSR 准备、激活和恢复协议 | 不依赖返回 501 或其他未实现的续证入口 |

离线授权只适用于本设计的新移动端协议。其他客户端若采用“每次缓存交付重新向 Core 授权”的模型，继续保持原语义；移动端不得虚报 `uds_auth_v2`、`local_socket_read_v1` 或 SSH 能力。服务器 Agent 要求 `uds_auth_v2` 的安全级别称为 floor 2；Core 按身份类型处理移动端能力，不降低服务器 Agent 的 floor。旧审计 v1 和现有客户端兼容性由服务端维护。

管理端仍由部署方通过 Caddy mTLS 保护；本插件不引入用户账户、注册登录或另一套管理认证。pending token 仅用于注册流程，不能读取 secret。

本文描述的移动端能力需要 Core 配合实现，不保证任意已有 Core 版本都已支持。缺少必需能力时，插件明确返回 `INCOMPATIBLE_VERSION`；协议替身可以支持独立开发，但不能作为真实服务端互操作已完成的证据。

## 4. 组件与责任边界

业务调用链为：Flutter 业务代码 → Dart Agent API → 原生安全与连接适配 → Core。

以一个独立 Flutter 插件项目交付，建议 Dart 包名为 `secrethub_agent`。项目包含 Dart 公共 API、Swift 原生实现、Kotlin 原生实现、示例 App、协议测试向量和开发文档；内部文件组织由新项目确定。

| 组件 | 负责 | 不持有或不决定 |
| --- | --- | --- |
| Dart Agent | 配置、状态流、Phoenix 消息封装、请求关联、公开 API、生命周期协调 | 身份私钥字节、TLS 私钥字节、Core 授权结论 |
| Native Identity | 原生密钥生成、CSR、注册签名、证书安装、密钥句柄 | Dart 提供的任意 Agent 身份声明 |
| Native Transport | 注册 HTTPS、运行时 WSS、证书选择、服务端链和 hostname 校验 | 忽略 TLS 错误的降级策略 |
| Native Cache | grant 验证、计时检查、AEAD 加解密、持久化失效标记、离线读取准入 | 修改 grant 的 TTL 或路径 |
| Native Audit | 有界持久化、序列号、交付前预留、上传确认和重放 | 伪造 Core 在线批准记录 |
| Core | 审批、身份绑定、签发、在线授权、离线 grant、同步、吊销、审计入库 | App 是否实际使用了返回值 |

Dart 与原生层之间传递配置、公钥、证书、受限协议消息、密钥引用和业务读取结果。禁止增加导出私钥、导出缓存密钥或任意签名的公共 API。

原生层的安全边界不依赖 Dart 是否正确实现检查。离线 grant、失效标记、身份匹配和期限检查必须在原生层再次执行；业务通过 platform channel 绕过 Dart 包装，仍不能要求插件忽略这些检查。

Dart 可以组织协议命令，原生层对最终帧、允许的事件和连接 generation 再校验。原生 transport 收到的 secret reply 必须经过本地审计准入、grant/cache 处理和交付检查后，才能以 `SecretResult` 越过原生边界；不能先把含明文的原始 WebSocket 帧发给 Dart，再补审计。同步及失效消息也先在原生层应用，再通知 Dart 更新状态。通用、不受约束的 `sendFrame`、任意 HTTPS URL 和原始 secret 响应流不属于插件桥接 API。

## 5. 原生密钥与平台适配

### 5.1 密钥分工

| 密钥 | 生命周期 | 用途 |
| --- | --- | --- |
| Installation identity key | 安装实例内稳定 | 证明注册与续证申请来自该安装实例 |
| TLS client key | 随客户端证书轮换 | mTLS 客户端认证；与 identity key 不同 |
| Cache protection key | 安装实例内独立 | 保护离线数据、grant 及其完整性元数据 |
| Audit protection key | 安装实例内独立 | 保护积压审计，避免清缓存影响审计 |

身份和 TLS 签名密钥统一使用 P-256 / ECDSA-SHA256。私钥在原生设施内产生，导出的只有 SPKI 公钥、CSR、签名和证书。禁止先生成 PEM 私钥再导入，禁止为兼容库 API 临时导出。

### 5.2 iOS

- 身份和 TLS 密钥使用 Secure Enclave `SecKey`，Keychain 保存受 App 访问控制的引用。
- 默认仅在设备解锁时可使用，采用 `ThisDeviceOnly` 保护，不进行 iCloud 同步，不要求每次连接弹出 Face ID。
- `URLSessionWebSocketTask` 承载 WSS，通过客户端证书 challenge 提供与原生密钥关联的 `SecIdentity`。
- CSR 与安装实例证明由原生密钥签名；证书导入后按公钥匹配到原有密钥，不导入另一份私钥。
- 缓存采用 AES-256-GCM。随机数据密钥只在原生内存短暂使用，落盘前由独立 Secure Enclave 保护密钥封装；采用平台支持的 ECIES 算法完成封装，不自创密码协议。该存储密钥不与签名密钥复用。
- 硬件不支持或关联证书失败时返回明确错误，不回退为可导出私钥。模拟器可以执行协议与 UI 测试，不能作为不可导出或 mTLS 真机验收依据。

### 5.3 Android

- 身份、TLS 密钥在 App 私有 Android Keystore 中生成，保留 alias 与 `PrivateKey` 句柄。
- 使用原生 TLS / OkHttp WebSocket，`X509KeyManager` 提供证书链及 Keystore 私钥句柄；不复制到需要私钥编码的临时 PKCS12/BKS 容器。
- 缓存与审计使用不同的 Keystore AES-256-GCM 密钥。密钥使用受设备解锁状态限制。
- 报告实际 key security level，区分软件 Keystore、TEE、StrongBox；平台不可导出与硬件背书分别描述。Core 不把客户端自报的等级当作远程硬件证明。
- Keystore 失败、密钥永久失效或算法不支持时拒绝读取，并进入恢复状态；不生成 Dart 软件私钥继续运行。

本稿建议最低平台 iOS 13、Android 9 / API 28；这是设计平台基线，实施时须按选用的 Flutter 稳定版本和原生依赖核对并记录最低版本。低于该基线不承诺兼容。

Core 验证的是公钥持有及审批关系。第一版不增加 App Attest、Android key attestation 或应用包真实性的远程证明，不宣称 Core 能仅凭 CSR 证明客户端密钥位于安全硬件。

## 6. 安装实例与注册

### 6.1 安装实例标识

`installation_id` 为原生生成的随机 UUID，不使用 IMEI、广告 ID 或 SSH 主机信息。`app_identifier` 为 bundle ID / application ID，用于显示、分组和审批提示，不能独立作为认证凭据。

本地同时保存不参与备份的 App 容器安装标记。iOS Keychain 数据可能在卸载后仍存在，安装标记缺失时不能直接复用旧 Agent 身份；应创建新的安装实例和注册申请。旧身份与未确认审计独立保留或隔离，不自动认领为新实例。

Android 备份/恢复规则排除插件身份、缓存、信任状态和审计目录。恢复的数据存在而密钥不存在时返回 `IDENTITY_UNAVAILABLE`，不能将损坏状态当作全新安装静默修复。更换 Core origin、重装或清除 App 数据均不能复制旧 grant 到新身份。

### 6.2 注册协议

通过受信 HTTPS 创建移动端注册申请，请求体为：

```json
{
  "identity_kind": "mobile_installation",
  "installation_id": "<uuid>",
  "identity_public_key_spki": "<base64url DER SPKI>",
  "identity_key_algorithm": "ES256",
  "platform": "ios",
  "app_identifier": "com.example.ownerapp",
  "agent_version": "<plugin version>"
}
```

上述尖括号字符串是协议示例的字段说明，不是可直接发送的值。Core 严格限制字段、长度和类型，核对 P-256 公钥并由服务端计算指纹。非敏感设备显示名称允许配置，不纳入认证。

注册接口契约如下。表中使用完整示例 URL；部署时只替换为已配置并验证的 Agent origin。JSON 请求和响应均为 UTF-8。

| 方法与完整示例 URL | 输入与保护 | 必须返回的逻辑结果 |
| --- | --- | --- |
| `POST https://core.example.com:4665/v1/agent/enrollments` | 上述创建请求；无需已有 Agent 证书，但必须验证服务端 TLS | 201；`enrollment_id`、`pending_token`、`status`、`poll_interval_ms` |
| `GET https://core.example.com:4665/v1/agent/enrollments/{enrollment_id}/status` | `Authorization: Bearer <pending_token>` | 状态、`agent_id` 和批准后必需的 `required_csr_fields` |
| `POST https://core.example.com:4665/v1/agent/enrollments/{enrollment_id}/csr` | 同一 pending token；`csr_pem` 和 `identity_proof` compact JWS | `agent_id`、`certificate_pem`、`ca_chain_pem`、`certificate_serial`、`certificate_fingerprint` |
| `GET https://core.example.com:4665/v1/agent/enrollments/{enrollment_id}/connect-info` | 同一 pending token；证书已签发 | `trusted_websocket_endpoint`、`expected_core_server_name`、`heartbeat_interval_ms`、`connect_timeout_ms` |
| `POST https://core.example.com:4665/v1/agent/enrollments/{enrollment_id}/finalize` | 同一 pending token；成功时提交 `status=trusted_connected` | 注册最终状态；Core 确认对应证书已真实连接，不能只信客户端声明 |

轮询状态包括 `pending_registered`、`approved_waiting_for_csr`、`csr_invalid`、`certificate_issued`、`connect_info_delivered`、`trusted_connected`、`rejected`、`expired`；创建响应中的 `pending` 映射为待审批。`required_csr_fields` 包含 `subject`、`san`、`challenge` 及其有效期，客户端只接受与本安装实例、服务端指派 Agent 和自己的公钥一致的字段。CSR 提交成功后，客户端先持久化密钥引用和证书，再继续连接。

pending token 只在原生受保护存储中保存，不进入 Dart、日志或 URL。按 Core 返回的轮询间隔请求；限流时遵守 retry-after。401 表示 token 不可用，404 表示申请不存在，410 表示过期；其他失败使用有界错误码，不把服务端诊断原文直接暴露给业务。返回的证书链、连接地址或 CA 信息不能取代预配的服务端信任，跨 origin 连接需要显式受控配置。

流程：

1. 原生层校验 HTTPS origin 与预配的系统信任或 CA 配置。
2. 生成安装身份密钥，创建 pending enrollment；pending token 只进入原生受保护存储。
3. App 状态流暴露 `pendingApproval`；管理端显示移动端类型、公钥指纹、App 标识和平台，操作者核对指纹、审批并配置 Agent 策略。
4. Core 返回有期限的一次性 challenge 与必需 CSR 字段。
5. 原生生成独立 TLS 密钥和 CSR；CSR 使用该 TLS 密钥自签名。另用安装身份密钥签名注册证明。
6. Core 同时验证 pending token、批准状态、challenge、证明、公钥类型、CSR 自签名、身份字段及两把密钥确实不同；消费 challenge 后签发客户端证书。
7. 原生安装证书并连接可信运行时，成功 join 后提交 `trusted_connected` 完成注册。

安装实例证明采用 ES256 JWS compact，签名输入为 JWS 定义的原始 signing input。受保护 header 固定 `alg=ES256`、`typ=secrethub-mobile-enrollment+jwt`。payload 字段为 `schema_version=1`、准确的 HTTPS `core_origin`、`enrollment_id`、`installation_id`、`challenge` 和 `csr_sha256`；摘要为 CSR DER 的 SHA-256 base64url。Core 从 pending enrollment 取验证公钥，不接受证明自选公钥。

CSR proof 的 JWS ECDSA 签名为 64 字节 `r || s`；原生 DER 签名与 JOSE 格式的转换必须有跨语言测试向量。CSR 公钥证明不能省略，也不能用 TLS key 代替独立安装身份 key。

移动端证书具有 `clientAuth` 用途、Agent URI SAN `urn:secrethub:agent:<agent_id>`，以及安装公钥指纹 SAN `urn:secrethub:installkey-sha256:<base64url fingerprint>`。Core 按持久化的 identity kind 核对相应绑定；移动端不填充虚假的 SSH host key 字段。

生产环境不接受 HTTP、首次连接时下载并无条件信任的 CA、忽略 hostname 校验或跨 origin 的自动重定向。pending token、二维码或审批状态均不授权运行时读取。

## 7. 运行时连接与能力协商

WSS 完整示例 URL 为 `wss://core.example.com:4665/agent/socket/websocket?vsn=2.0.0`，topic 为 `agent:runtime`。使用 Phoenix V2 JSON serializer 的五元素帧 `[join_ref, ref, topic, event, payload]`；ref 为字符串，事件只能由匹配的连接 generation 和 ref 完成。`phx_join` payload 包含 `runtime_capabilities` 字符串数组，不传运行时身份声明。

`phx_reply` payload 为 `status=ok|error` 与 `response` 对象。成功 join 的 response 包含 `status=accepted`、协商后的 `runtime_capabilities`、`agent_id`、`certificate_id`、`certificate_serial`、`certificate_fingerprint`；客户端核对证书绑定与必需能力。失败 response 使用 `reason` 有界错误码。`phx_close`、`phx_error` 使连接失效；未完成请求依错误分类结束或重试。

Phoenix 心跳在 topic `phoenix` 上发送事件 `heartbeat` 和空 payload，每次有独立 ref；业务侧 `agent:heartbeat` 更新 Agent 在线状态，两者不能混同。使用受信 connect-info 中的心跳间隔，默认 30 秒；超过约定期限没有对应回复则关闭连接并重连。

移动端协商：

| Capability | 含义 |
| --- | --- |
| `mobile_agent_v1` | Core 已登记的安装实例身份类型 |
| `agent_secret_read_v1` | Agent 自身权限下的直接静态读取 |
| `offline_secret_v1` | 签名离线 grant、加密缓存及同步契约 |
| `access_audit_v2` | 明确区分在线决策和离线设备观察 |
| `agent_cert_renewal_v1` | 本稿定义的 CSR 续证与切换 |

第一版插件需要上述完整集合；Core 缺少任何必需能力时返回 `INCOMPATIBLE_VERSION`。旧 Core 不能签发本协议 grant；没有完成过该协议的安装实例不能创建离线 ready 状态。

Core 按已登记的 `identity_kind` 选择 join 和升级门检查。移动端按上述能力检查，不能通过请求体改类型。服务器 Agent 原有的 `uds_auth_v2` 安全门由服务端保持；未知类型拒绝。移动端不声明 `uds_auth_v2`、`local_socket_read_v1` 或 SSH 能力。

单个原生连接由一个协调器拥有。换网、App 恢复和连接超时触发有界重连；后台不假设持续运行。回到前台先刷新设备锁定和计时状态，随后尝试连接/同步。每次新连接使用新的 generation；旧连接回调、超时 reply 和取消请求不能完成新 generation 的读取。

连接成功后进入同步屏障，完成第 10 节的同步后才能在线交付。首次原生支持验证失败必须报告具体平台阻塞，禁止退回 token HTTP 或导出私钥绕过。

## 8. 在线读取与值格式

运行时事件为 `secret:read_agent`。Core 只使用 socket 中的 mTLS 身份，按当前 Agent、证书状态及策略进行静态读取授权；授权、版本检查和审计与状态变更保持一致的事务顺序。

请求允许字段：

```json
{
  "path": "prod.mobile.service_token",
  "known_revision": null,
  "offline_requested_ttl_seconds": 3600,
  "audit_request_id": "<uuid>",
  "audit_attempt_id": "<uuid>"
}
```

拒绝 Agent ID、application ID、证书指纹等调用方身份声明和其他未知字段。secret 使用大小写敏感的 canonical dot path，例如 `prod.mobile.service_token`：1–512 字节，由非空 ASCII 字母、数字、下划线或连字符片段组成，以单个点分隔；不接受文件系统路径、空片段或隐式大小写转换。TTL 为 0 表示不请求离线授权；否则为正整数并受 Core 上限约束。

成功 response 的逻辑字段：

| 字段 | 契约 |
| --- | --- |
| `status` | `value` 或 `not_modified` |
| `version`、`revision` | 当前 secret version 与单调路径 revision，作为十进制字符串传输 |
| `value_format` | `text` 或 `structured` |
| `authorized_at` | 此次在线授权的服务端 UTC 时间，不使用客户端收到响应的时间代替 |
| `payload_b64` | `value` 时包含精确 UTF-8 JSON envelope 的 base64url 字节；`not_modified` 时省略 |
| `offline_grant` | 符合策略时为 compact JWS，否则为 null |
| `offline_status` | `granted`、`not_requested`、`not_allowed` 或 `unsupported_conditions` |
| `core_audit_event_id` | 此次在线请求对应的 Core 记录 |
| `grant_issuance_event_id` | 有 grant 时为对应签发审计 UUID，否则为 null；原生层随缓存保存，用于离线观察关联 |

JSON envelope 为 `{"value_format":"text","value":"..."}` 或 `{"value_format":"structured","value":{...}}`。Core 使用确定性 JSON 编码生成一次，原生层以原始字节验证摘要、保存和解码，不重新编码后再计算摘要。Text 精确保留空白、换行和 JSON 形状的文本；Structured 返回完整对象，不抽取名为 `value` 的字段。

revision/version 用十进制字符串避免跨运行时数值精度差异；Core 做正整数字符串校验。Structured 业务值中的数值另按 JSON 数值契约处理，客户端不得静默把不能精确表示的整数舍入。

即使 `known_revision` 相同，Core 也重新授权。要继续离线缓存，必须返回绑定原有 payload 摘要、当前授权和新期限的新 grant；旧 grant 的时间不能由客户端更新。原生层没有与 `not_modified` 完全匹配的 payload 时，以新 attempt 重试一次完整读取，不能返回另一 revision。

为 `not_modified` 签发新 grant 时，Core 仍在本次授权事务内读取对应版本并计算精确 payload 摘要，不接受客户端提供的摘要作为签发依据。该路径节约传输，不承诺省去服务器解密和签名工作。

请求离线授权被策略拒绝时，合法在线读取仍可返回 value，且明确 `offline_status`；它不产生离线可用承诺。`not_allowed` / `unsupported_conditions` 还须持久化该路径的 offline block 并使旧 grant 失效，但不拒绝本次合法在线值；`not_requested` 不表示 Core 作出了离线 deny。要求离线预取的 API 将未获 grant 的项报告为预取失败，不把普通在线成功计作离线已准备。

## 9. 离线授权、有效期和持久化

### 9.1 授权是独立能力

Core 仅在普通 `read` 已允许后，再验证显式的 `read_offline` 授权与正整数 `offline_max_ttl_seconds`。策略没有该操作或字段时离线默认关闭，不能把普通 read 权限推导为离线权限。

策略示意：

```json
{
  "version": "1.1",
  "allowed_secrets": ["prod.mobile.service_token"],
  "allowed_operations": ["read", "read_offline"],
  "conditions": {}
}
```

Core 的策略模型需要独立的 `offline_max_ttl_seconds` 属性，例如 3600；它不复用动态凭据的 TTL 含义。策略校验和管理端配置需要识别 `read_offline`，不含此操作的策略仍按原语义执行。这些策略由 Core 管理，插件配置不能自授予权限。

离线签发要求相关授权不依赖离线无法重新验证的 IP、实时配额、会话状态或时间窗口条件。第一版遇到这些条件拒绝离线授予，普通在线读取仍由 Core 按当前条件判断；只允许无条件或明确的 TTL 限制，不静默丢弃未知条件。显式 deny、适用的损坏策略、证书无效、Vault sealed、审计不可用均不能签发 grant。

有效截止时间为以下各项的最早值：

```text
issued_at + requested_offline_ttl
issued_at + applicable_offline_policy_max_ttl
issued_at + agent_offline_max_ttl
issued_at + core_offline_hard_cap
runtime_certificate.not_after
offline_signing_key.not_after
secret 的显式可交付截止时间（若存在）
```

多个匹配的离线 allow 策略的 TTL 取最小值，任意适用 deny 优先。Agent 的 `offline_max_ttl_seconds` 未配置时继承 Core 上限，配置为 0 时禁止该 Agent 获得离线 grant；其他合法值只能更小。Core/Agent 上限、App 请求都只能收窄。到达截止时间即过期，不增加网络失败宽限期。TTL 变化不改写已签发 grant；要收回现有授权需失效通知或等待其到期。

### 9.2 Grant 格式与签名信任

Core 使用独立的 P-256 离线签名密钥签发符合 JOSE 标准的 ES256 compact JWS。签名密钥由 Vault 保护，不复用 CA 私钥、TLS 私钥或 audit HMAC key。header 固定 `alg=ES256`、`typ=secrethub-offline-grant+jwt`，`kid` 只能引用已受信的签名 key。插件使用原生密码接口验证，不依赖服务端使用哪种语言或 JOSE 库。

payload 必须完整绑定：

| 字段 | 类型与含义 |
| --- | --- |
| `schema_version` | 固定整数 1 |
| `iss` | Core 持久化的 `core_instance_id` |
| `aud` | 固定 `secrethub-mobile-offline` |
| `jti` | 唯一 grant UUID |
| `core_origin` | 精确的受信 Agent HTTPS origin |
| `agent_id`、`installation_id` | Core 指派 Agent ID 和安装 UUID |
| `identity_key_fingerprint` | 安装身份 SPKI DER 的 SHA-256 base64url |
| `certificate_id` | 签发时有效的运行时证书 UUID |
| `path` | canonical dot path |
| `version`、`revision` | 正整数的十进制字符串 |
| `value_format` | `text` 或 `structured` |
| `payload_sha256` | 第 8 节精确 payload 字节的 SHA-256 base64url |
| `authorization_epoch` | 该次签发绑定的授权 epoch，十进制字符串 |
| `iat`、`nbf`、`exp` | Unix 秒整数，`nbf=iat`，`exp>iat` |
| `clock_mode` | 固定 `trusted_system_clock_v1`，显式声明冷启动的时间信任模型 |

grant 是特定安装、路径、版本的本地使用凭据，不是 Core HTTP bearer token。服务端不接受它替代 mTLS 或申请新 secret。

签名公钥 bundle 仅通过已验证的注册/可信运行时同步面下发，并与 `core_instance_id`、origin 和安装身份一起保存在原生完整性保护状态中。token 中不接受 `jku`、内嵌自选公钥、任意 key URL 或算法切换；未知 `kid` 要求联网更新信任。

签名 key 轮换先分发验证公钥再签发新 grant；旧公钥至少保留到其所有 grant 到期。客户端持久化 key bundle generation，不接受正常同步中的 generation 回退。离线期间无法获知紧急 signer 撤销，此项受同一离线期限和时间信任边界约束。

Core 在相同授权事务内持久化 grant 元数据及 grant-issuance 审计，事务提交后才发送 grant。记录 grant ID、绑定身份、路径 revision、epoch、期限和签名 key ID，不存 secret value、完整 token 或 payload 摘要到审计。

### 9.3 原生缓存结构

每项缓存包含完整 grant、精确 payload 字节、Core scope、身份与证书绑定。使用 AES-256-GCM，96 位随机 nonce、128 位 tag；每次写入使用新 nonce。同一 key 的 nonce 不得重用。

AEAD 的 associated data 包含 schema version、Core scope、installation ID、规范路径、revision、grant ID。所有这些字段也必须与已验证的签名 claims 一致。路径/alias 不直接拼接为文件路径，防止目录穿越。

采用临时文件写入、文件同步、原子替换及原生目录持久化；先持久化 grant 和 payload，再发布为可读取项。崩溃恢复只接受完整且校验成功的版本。加密数据写入失败时，在线读取可以返回在线结果，并将 SDK 的 `offlineAvailability` 标为 `cacheWriteFailed`；Core 的 wire `offline_status=granted` 不代表设备已经落盘，客户端不能据此标记已准备离线。

信任 bundle、计时高水位、已知拒绝、路径 revision 下限、sync-required 标记独立保存在受完整性保护的原生状态中，不随清空 value 缓存一起删除。已知较新 revision 或失效信息优先于旧缓存文件。清缓存不能解除已知吊销或恢复旧 grant。

App 缓存、身份、信任状态和审计均排除系统备份和云同步。不得将 value、grant、私钥、缓存数据密钥或 secret-derived digest 写入日志、崩溃报告、剪贴板或普通偏好设置。

### 9.4 离线读取准入

每次离线交付在原生层依次检查：

1. 设备解锁，相关原生密钥可用；Core scope 与当前安装完全一致。
2. 当前 alias 仍在配置中且显式允许离线；路径与 grant 相同。
3. 没有已知吊销、拒绝、TLS 信任错误、同步屏障或恢复要求。
4. grant 算法、签名 key、签名、所有 claims 和本地绑定有效。
5. 有效时间满足 `nbf <= now < exp`，运行时证书仍在有效期内。
6. AEAD 解密成功；payload 摘要、格式、revision 与 grant 一致，未低于本地已知 revision 下限。
7. 审计队列已为本次操作预留容量，并持久化准入与 release intent。
8. 返回值及其 `source=offline`、版本、上次授权时间、截止时间给 Dart。

原生层串行化交付检查与失效标记写入。已完成的失效状态持久化先于后续读取生效；在途的并发读取必须在 release intent 前再次核对 generation，不能用旧快照越过已知拒绝。

### 9.5 离线冷启动与时钟

Core 在成功的可信同步中给出服务器时间。原生层保存服务器时间锚 `S0`、当时的设备墙钟 `W0`、连续单调时钟值 `M0` 和最高已使用有效时间 `H`，均受完整性保护。时间计算统一使用毫秒；验证 grant 时与 `exp * 1000` 比较，容差不得增加 grant 的期限。

同一原生会话的候选时间为 `S0 + (Mnow - M0)`，墙钟估算为 `S0 + (Wnow - W0)`。有效时间取二者与 `H` 的最大值；发现异常时直接进入时间 block，不因取最大值而忽略异常。这样初次设备墙钟相对 Core 的固定偏差不会直接改变 TTL。

同一原生会话内，用包含设备休眠时间的连续单调计时计算已过去时间，并与墙钟核对；不能使用因 App 暂停而停止推进的 Dart timer 作为 TTL 时钟。观察到超过 5 秒的时间回拨、异常漂移或不可解释的单调时钟重置时持久化 `CLOCK_UNTRUSTED`，要求重新可信同步。

冷启动时：

- 校验完整缓存、身份、信任及持久化控制状态，使用墙钟估算 `S0 + (Wnow - W0)`，并与 `H` 取最大值，判断期限。
- 墙钟估算早于 `H` 超过容差时拒绝；将时间向前调整到过期后，不能再靠回拨使其恢复有效。
- 原生平台能够可靠确认同一开机周期时，可继续用持久化的连续计时锚增强检查；无法确认时不能声称具有该保证，按本稿明确的 OS 时间信任模型处理。
- 没有任何可信在线时间锚、存储损坏或观察到时间异常时拒绝冷启动离线读取，不把本地当前时间直接当作 Core 授权时间。
- 时间高水位必须在交付前持久化；进程崩溃后不能回到上一次已使用的更早时间。

以上机制不会使普通手机获得防回滚可信时钟。设备在进程终止期间被冻结时间、重启并恢复受保护状态等攻击未必可检测。测试及产品说明必须保留这一限制，不将 24 小时签发上限写成不依赖设备信任的无条件吊销保证。

## 10. 断网、恢复连接与失效处理

### 10.1 读取模式与失败分类

| 模式 | 行为 |
| --- | --- |
| `onlineOnly` | 必须取得当前 Core 结果，任何失败都不返回离线缓存 |
| `preferOnline`（默认） | 先在线；仅明确的网络不可达、连接断开或超时可尝试已有离线 grant |
| `offlineOnly` | 不为本次读取发起网络请求；仍执行全部原生准入检查 |

`offlineOnly` 不能绕过已经知道的 Core 拒绝、同步屏障或时间异常。App 配置不能扩大 Core 签发的期限；当前配置缩短 TTL 时，本地按 `iat + local_max_age` 进一步截断，之后再增大配置不能恢复本地已判定失效的 grant。

Core 明确返回权限拒绝、Agent/证书吊销、secret 删除、版本不兼容、Vault sealed 或审计不可用时，本次请求不能转换为离线成功，并持久化相应范围的 block。普通未知服务端错误也不视为“断网”。TLS 链、hostname 或身份校验失败同样禁止隐式离线 fallback。

路径拒绝阻止该路径，Agent/证书拒绝阻止整个安装身份；Vault/审计/协议等权威不可用响应设置 Core scope 的 block，直到成功同步明确解除。网络恢复事件、重启、清缓存或等待退避不能解除 block。

### 10.2 同步屏障

可信运行时 join 成功后，原生层先持久化 `sync_required=true`，暂停缓存交付，执行 `agent:sync`。请求列出当前配置中最多 128 个不同 path，每项附带可空的缓存 grant ID、revision 及已有路径 block 状态；同时带客户端已知 bundle generation。不发送 secret value 或 payload 摘要。没有缓存但存在路径 block 的项也参加同步，避免清缓存后无法重新核对权限。

Core 重新验证 Agent、证书、当前 typed authorization gate、Vault readiness 与审计状态；对清单中的每条 grant 检查当前 read/offline 权限及最新 path revision。grant 为历史签发记录，不因为还未到期就跳过当前权限检查。

完整同步结果含服务器时间、Core instance ID、信任 bundle generation、当前授权 epoch，以及每项的当前 online/offline 允许状态、可空的 grant 处理结论 `retain` / `invalidate` 和有界原因。没有缓存的项也必须有当前权限结果。`retain` 不延长原始 grant 期限。同步只是对各项检查时刻的判断，不宣称对未来策略变更拥有原子快照保证。

客户端先持久化全部 invalidation、scope block 变化、信任和时间状态，再解除同步屏障；任何部分结果、解析错误或落盘失败都保持屏障。按 Core scope 保存最高已确认授权 epoch 与 bundle generation；可信 Core 返回更小值时进入 `CORE_STATE_ROLLBACK`，不自动接受恢复出的旧授权状态。首次 join 以后同步中断，必须再完成一次可信同步才能解除；仅在尚未成功 join 的网络连接失败时，原有有效 grant 可以按离线规则继续使用。block 不禁止联网核对或恢复 RPC，只阻止不满足条件的明文交付。

同步失效的项在线按需重读；App 可调用预取补齐离线数据。不因握手成功就认为旧缓存仍被授权，不把 `not_modified` 用作全局授权。

### 10.3 吊销、策略变化与 rotation

Core 为本协议发送 `agent:invalidate`，携带 generation、scope、路径或 grant ID 和有界原因；SDK 持久化后再确认。失效消息必须支持重复及乱序应用，不能因为先收到另一条路径的较大 generation 就丢弃该路径的失效；失效只收窄，解除由完整可信同步决定。普通断开连接不是完整吊销通知，不能据此推断所有状态。

Agent/证书撤销、policy deny、offline allow 取消、secret 删除或 rotation 都应进入相同失效与同步路径。rotation 后旧 revision 的本地高水位被推进；连接中必须清除旧项，离线设备则可能在旧 grant 到期前继续使用旧值。

在第 2 节时间信任前提下，新读取的吊销延迟受“收到并应用可信失效信息/同步”与“原 grant 到期”的较早者限制。最长可接近剩余 grant TTL。离线设备不能承诺立即获知吊销；已经交给业务的值及业务长期持有的凭据也不受该读取期限收回机制控制。

## 11. 续证与身份恢复

证书 TTL 由 Core Agent 策略决定；建议在有效期约 70% 时、App 有运行机会且联网时尝试续证。不能依赖手机后台定时任务保证到点执行。离线 grant 的截止时间不超过签发时运行时证书有效期。

可信 `agent:runtime` 增加以下 RPC，均要求实时重新校验当前 Agent 与证书：

1. `agent:certificate_challenge`：生成绑定 Agent、当前 certificate ID 和五分钟期限的 renewal ID 与 nonce。
2. `agent:certificate_renew`：提交新原生 TLS key 的 CSR 及安装身份签名证明。证明绑定 origin、renewal ID、nonce、旧 certificate ID、CSR DER 摘要，header 使用独立的 `secrethub-mobile-renewal+jwt` domain。
3. `agent:certificate_activate`：客户端持久化新密钥引用和证书后，请求原子切换有效证书。

同一 renewal ID 和相同 CSR 的重试幂等，CSR 不同返回冲突。签发阶段的新证书为 prepared 状态，不取得普通读取权限。activate 在 Core 事务内切换当前证书、使旧证书失效并持久化审计，再断开旧运行时；无需使两张证书同时具有普通读取权限。

客户端在发送 activate 前持久化切换状态并暂停旧 grant 交付。响应丢失时先尝试新身份连接；若尚未切换，可通过仍有效的旧 mTLS 连接重试相同 activation。新、旧身份的尝试都必须验证同一服务端信任，旧身份仅用于续证恢复，不能恢复旧 grant 交付；普通网络超时不能被解释为新证书确定处于 prepared。两条恢复路径均失败时保持切换状态并有界重试，不静默丢掉新密钥。切换后使用新证书完成同步并获取新 grant；旧 certificate ID 绑定的 grant 不继续使用。

证书已过期时不能通过已过期 mTLS 续证，也不能把离线 grant 或 pending token 当作运行时身份。使用仍存在的安装身份提交受挑战的恢复注册申请，由操作者重新批准；审批前不可获取新值或新 grant。被明确 revoked/suspended 的身份不自动恢复，必须由操作者处理并审批新身份。

密钥丢失或永久失效时保留可诊断的非敏感状态和积压审计，停止读取，进入 `needsRecovery`。离线冷启动只使用已有未过期的 grant，不自动延长证书或注册信任。

## 12. Dart API 与配置契约

以下为设计接口示例，不是已存在、可编译运行的 SDK：

```dart
final agent = SecretHubAgent(
  config: AgentConfig(
    coreUrl: Uri.parse('https://core.example.com:4665'),
    trust: AgentTrust.system(),
    secrets: {
      'serviceToken': SecretBinding(
        path: 'prod.mobile.service_token',
        offline: OfflineAccess.allow(maxAge: Duration(hours: 1)),
      ),
      'liveConfig': SecretBinding(
        path: 'prod.mobile.live_config',
        offline: OfflineAccess.deny(),
      ),
    },
  ),
);

await agent.start();
final subscription = agent.states.listen(renderAgentStatus);

final token = await agent.read('serviceToken');
final cached = await agent.read(
  'serviceToken',
  mode: ReadMode.offlineOnly,
);
final report = await agent.prefetch(['serviceToken']);

await subscription.cancel();
await agent.close();
```

| API | 约定 |
| --- | --- |
| `start()` | 完成本地初始化并启动协调器后返回，不等待人工审批；冷启动可以进入 readyOffline |
| `states` | 有界、去重的状态流；不携带 secret value 或 token |
| `read(alias, mode)` | 仅允许配置的 alias；返回明确的值、版本、来源和授权期限，或 typed error |
| `prefetch(aliases)` | 在线获取并持久化离线 grant；逐项报告结果，只有 durable cache 成功才为 prepared |
| `clearCache(aliases)` | 删除 secret payload 和 grant；保留控制状态、已知拒绝、revision 下限及审计 |
| `close()` | 取消定时器、关闭本插件连接、同步本地必要状态；不注销 Agent 或删除身份 |

`SecretResult` 包含 `value`、`valueFormat`、`version`、`revision`、`source`（online/offline）、`authorizedAt`、可空的 `offlineExpiresAt` 及 `offlineAvailability`。后者为 `prepared`、`notRequested`、`notAllowed`、`unsupportedConditions` 或 `cacheWriteFailed`，区分服务端 grant 与设备实际准备结果。离线结果的 `authorizedAt` 是 grant 签发时间，不是此次本地读取时间；在线结果取 Core 的 `authorized_at`。禁止默认 `toString()` 输出 value；异常、状态、诊断也须脱敏。

App 配置只包含 origin、信任选择、非敏感显示信息、alias/path 映射、读取超时及更严格的缓存偏好。私钥、共享引导密钥、长期 Core token 不进入源码、assets 或配置。CA 是公开信任材料，但必须通过受控配置提供；不从未认证连接接受替代 CA。

相同 Core/安装范围只有一个实例协调器，所有 Dart isolate 共用原生控制状态。并发启动重复协调器应返回明确错误，不能并发续证或覆盖身份。UI 不需要使用 SecretHub 管理端登录；注册审批仍在已有受保护管理端完成。

### 12.1 Dart 与原生的内部桥接契约

下表为插件内部接口；宿主只使用上面的 Dart API。所有引用均为原生维护的 opaque handle，不接受宿主提供的任意文件路径或私钥字节。

| 内部操作 | 输入 | 返回与边界 |
| --- | --- | --- |
| `identity.loadOrCreate` | 已验证的 Core scope、安装标记、非敏感显示信息 | identity reference、SPKI、指纹、真实 key protection 信息；损坏状态不自动重建 |
| `identity.prepareCsr` | Core 要求的 subject/SAN、enrollment 或 renewal reference | CSR DER 和新 TLS key reference；原生约束字段、签名并验证 key 角色 |
| `identity.proveEnrollment` / `proveRenewal` | 对应流程 reference 与 Core challenge | 限定 domain 的 JWS；CSR 摘要由原生从自己生成的 CSR 计算，不提供通用签名器 |
| `enrollment.request` | 有界的已定义 enrollment 操作和字段 | 安全状态/公开证书数据；pending token 留在原生，origin 与路径受白名单限制 |
| `runtime.open` | scope、已安装的 certificate/key reference、generation | 连接引用及安全状态事件；prepared 证书不得进入普通读取状态 |
| `runtime.request` | 白名单事件、受限 payload、关联 ID 和 generation | 安全控制 reply 或经过原生交付检查的 `SecretResult`；每个 secret 操作先做审计预留 |
| `cache.read` | alias/path binding、读取关联 ID、本地更严格的 maxAge | 完整执行离线准入后返回 `SecretResult`；不提供直接解密任意 blob 的 API |
| `cache.clear` | 当前 scope 中的 alias 列表 | 删除 value/grant，保留控制状态和审计 |
| `audit.nextBatch` / `applyAck` | 有界批次请求，或原生 transport 已验证的 Core ack reference | 脱敏事件批次；不能用 Dart 构造的事件 ID 列表删除未确认记录 |
| `runtime.close` | 本插件持有的连接 reference | 关闭连接、持久化必要状态；不删除身份 |

原生层自己校验和应用来自真实连接的 sync、invalidation、audit ack；不接受 Dart 直接调用“解除 block”“设置服务器时间”或“标记审计已确认”。RPC 失败、超时和迟到回复返回有界 typed error。bridge 的 schema、错误码与跨语言测试向量由 iOS、Android、Dart 共用。

## 13. 状态、错误和重试

状态定义：

| 状态 | 允许的业务行为 |
| --- | --- |
| `unregistered` / `enrolling` / `pendingApproval` | 显示注册进度；不可读 |
| `connecting` | 未成功 join 前，符合离线准入的旧 grant 仍可用 |
| `syncing` | 已持久化同步屏障；不可交付缓存 |
| `readyOnline` | 允许在线读取；offlineOnly 仍须有效 grant |
| `readyOffline` | 至少一项缓存可离线读；每个 alias 独立检查 |
| `locked` | 原生密钥不可用，拒绝明文交付 |
| `needsRecovery` / `revoked` / `incompatible` | 拒绝读取，提示明确的恢复或升级原因 |
| `closed` | 不再发起操作；必须重新创建协调器才能启动 |

连接状态不等于某项 secret 可读。没有有效缓存时的网络断开不能标成 readyOffline。

| 错误 | 自动重试 | 是否允许默认离线 fallback |
| --- | --- | --- |
| `NETWORK_UNAVAILABLE`、`CONNECTION_CLOSED`、`REQUEST_TIMEOUT` | 有界退避 | 有效 grant 且无 block 时允许 |
| `PENDING_APPROVAL` | 前台低频轮询，遵守 Core 限流 | 不允许 |
| `PERMISSION_DENIED`、`SECRET_NOT_FOUND` | 不自动重试 | 不允许，持久化路径 block |
| `IDENTITY_REVOKED`、`CERTIFICATE_EXPIRED` | 明确恢复流程 | 不允许，作用于身份 |
| `TLS_UNTRUSTED`、`IDENTITY_UNAVAILABLE`、`KEY_INVALIDATED` | 不生成替代软件身份 | 不允许 |
| `CLOCK_UNTRUSTED`、`OFFLINE_GRANT_EXPIRED`、`OFFLINE_NOT_PREPARED` | 联网后同步或预取 | 不允许 |
| `CACHE_INTEGRITY_FAILED`、`PAYLOAD_UNSUPPORTED` | 隔离坏项，要求新在线结果 | 不允许 |
| `VAULT_SEALED`、`AUDIT_UNAVAILABLE`、`INCOMPATIBLE_VERSION` | 仅在状态变化后恢复 | 不允许 |
| `CORE_STATE_ROLLBACK` | 由操作者核对 Core 恢复状态 | 不允许，保留本地最高已知状态 |
| `RATE_LIMITED` | 遵守 retry-after | 不允许把服务端限流当断网 |

每个业务调用有一个 request UUID，每个在线 attempt 有独立 UUID。超时/取消只完成一次 Future；迟到响应不交付给已取消调用。已返回的值不自动重发。SDK 不记录远端原始异常文本或 secret 响应体。

## 14. 审计契约

采用“准入、attempt、release intent、response sent/failed”的观察模型；Core 在线决策与 Agent 交付观察分别保留。离线读取是设备在既有 grant 下的观察，不伪造此次 `core_decision` 或 `core_access`。

### 14.1 Schema v2

`access_audit_v2` 使用下面完整的字段白名单。客户端无需取得其他审计文档即可实现；Core 继续保留旧 v1 的独立校验与历史语义，不将 v2 事件伪装成 v1 上传。

| 基础字段 | 类型与约束 |
| --- | --- |
| `schema_version` | 必需，固定整数 2 |
| `event_id`、`producer_id`、`request_id` | 必需，规范 UUID 字符串；producer ID 与持久化队列绑定 |
| `producer_sequence` | 必需，持久化递增正整数，最大 `9007199254740991` |
| `source` | 必需，插件上传固定为 `agent`；`core` 由 Core 自己产生 |
| `phase` | 必需，使用下文闭合枚举 |
| `observed_at` | 必需，UTC ISO8601 字符串，最多 40 字节；设备观察时间不冒充服务端接收时间 |
| `identity_status`、`attribution` | 必需，移动端固定为 `unverified`、`none` |
| `operation` | 必需，`read`、`invalid` 或 `authenticate`；业务 secret 读取使用 `read` |
| `outcome` | 必需，`success`、`denied`、`error` 或 `unknown` |
| `reason_code`、`cache_status` | 必需，使用下文闭合枚举 |
| `attempt_id` | 可空 UUID；attempt、Core decision/access、release/send 阶段必须非空 |
| `agent_id` | 可空的 1–128 字节标识，字符限字母、数字、下划线、点、冒号和连字符；Core 从认证连接绑定身份 |
| `application_id` | 移动端固定 null，不把 bundle ID 当作已认证 application ID |
| `secret_id`、`policy_id`、`core_event_id`、`client_correlation_id` | 可空 UUID；业务传入的 correlation 不用于可信关联 |
| `secret_path` | 可空；有值时必须满足第 8 节 dot path 约束，非法输入不原样写入审计 |
| `secret_version`、`policy_version` | 可空的可精确表示正整数，最大 `9007199254740991`；不可静默舍入 |
| `duration_us` | 可空的非负整数，最大 `9007199254740991` |

离线扩展字段同属 v2 白名单：

| 新字段 | 含义 |
| --- | --- |
| `authorization_mode` | `online` 或 `offline_grant` |
| `grant_id` | 已验证 grant 的 UUID；在线 grant 签发操作可关联 |
| `secret_revision` | 可空的正整数十进制字符串 |
| `grant_expires_at` | 已验证 grant 的 UTC 截止时间 |
| `grant_issuance_event_id` | grant 签发时的 Core 事件 UUID，不冒充此次在线决定 |

`authorization_mode` 在 v2 中必需。实际依据 grant 交付缓存的记录必须有 `grant_id`、`grant_expires_at` 和 `grant_issuance_event_id`；在取得合法 grant 前拒绝的离线尝试不填造 grant 关联。不适用的可空字段显式为 null。未知字段、重复 JSON key、类型错误及越界值均拒绝。

Agent phase 只允许 `admitted`、`attempt`、`release_intent`、`response_sent`、`response_failed`、`rejected`。Core 可另外产生 `core_decision`、`core_access`，插件不能上传这些阶段。`admitted`、`attempt`、`release_intent` 的 outcome 为 `unknown`；`response_failed` 为 `error`；`rejected` 为 `denied` 或 `error`。`response_sent` 描述已交付响应的结果，不直接等同于 secret 成功。

`cache_status` 只允许 `none`、`miss`、`hit`、`validated`、`invalidated`、`offline`。`reason_code` 只允许以下值：

```text
none allowed permission_denied unauthorized invalid_request invalid_identity
invalid_application invalid_principal invalid_revision invalid_path incompatible_version
revoked disabled expired not_found secret_not_found core_unavailable authorization_unavailable
audit_unavailable sealed timeout transport_error response_error internal_error unsupported_schema
invalid_event event_conflict journal_full journal_corrupt proof_required proof_failed
certificate_invalid connection_closed rate_limited offline_grant_valid offline_grant_expired
clock_untrusted cache_integrity_failed
```

未分类实现错误映射为 `internal_error`，不序列化原始异常。Core 的 `core_access` outcome 为 `success`，`core_decision` 为 `success`、`denied` 或 `error`。Core 按认证 Agent namespace 关联观测、按校验后的规范事件判断幂等，并独立记录 `received_at`；不把客户端编码空白当作不同事件。

移动端没有独立 application certificate，保持 `application_id=null`、`identity_status=unverified`、`attribution=none`；这里表示没有已验证的 application attribution，不能解释成 mTLS Agent 未认证。Core 入库时从可信 socket 绑定 Agent namespace，不接受事件声明更换 Agent。

事件不得包含 value、payload、grant token、签名、任何私钥/数据密钥、secret-derived digest 或任意诊断 metadata。每事件至多 4096 字节，每批至多 100 项及 131072 字节，通过能力协商后的 `audit:batch` 传输。payload 为只含 `events` 数组的对象；成功 reply 的 response 含 `accepted` 和 `duplicates` 两个事件 UUID 数组，合并后恰好覆盖本批事件。Core 只在完整批次通过校验且事务提交后确认；失败不确认任何事件。原生层核对确认集合，不凭超时、发送完成或 Dart 声明删除队列记录。

### 14.2 本地持久化与补传

原生审计队列使用独立加密文件、持久化 producer UUID 和递增 sequence。每次读取在准入时预留完整后续事件容量；容量不足、同步失败或损坏时返回 `AUDIT_UNAVAILABLE`，不为了可读性丢弃未确认记录。缓存淘汰和 `clearCache` 不清审计。

离线 release intent 在明文跨原生边界前持久化。`response_sent` 仅表示插件观察到完成交付，不证明业务使用；交付前后崩溃保留 unknown，不因重启自动重放 secret 响应。

恢复连接后先处理身份与缓存失效，再按有界批次补传审计。Core 事务提交后才确认事件 ID，客户端确认落盘后才压缩队列。重复事件幂等，不同内容重用 event/sequence 为冲突；损坏或永久拒绝项隔离，不无限热重试。

每个离线业务读取使用新的 request/attempt ID；以 `grant_id` 关联最初签发记录，不复用签发请求 ID来合并多次读取。UI 分别展示在线读取、grant 签发、离线设备观察、延迟上报和缺失/矛盾信息，不把设备观察计入新的 Core 在线批准次数。

身份被吊销后可能无法通过该身份补传积压，这是显式限制。禁止增加绕过吊销的审计连接；保留旧 namespace 的加密积压并展示待处理状态。新安装实例不能将其冒充为自身事件；隔离和人工恢复必须保留证据，不能在重新注册时静默删除。

## 15. 外部 Core 的协作要求

本节供 Core 维护者对齐协议，描述服务端需要保存的逻辑信息与保证；不规定其源码布局、数据库技术或编程语言。本 Flutter 项目不包含服务端实现和数据库迁移。

| 范围 | 需要的逻辑数据与约束 |
| --- | --- |
| Agent / enrollment | `identity_kind`、installation UUID、SPKI 公钥/指纹、App 标识、平台；移动端字段按类型必填，旧 SSH 类型保持原验证 |
| Certificate metadata | 安装 key SAN、证书准备/激活绑定、renewal ID；issuer/verifier/runtime 必须一致 |
| Policy | `read_offline` 操作和 `offline_max_ttl_seconds`；缺失即无离线权限 |
| Core identity | 稳定 `core_instance_id`，备份恢复保留逻辑实例身份；新独立 Core 不复用 |
| Offline signing keys | key ID、公钥、有效期、generation、受 Vault 保护的私钥；分发、轮换及禁用状态 |
| Offline grants | 唯一 grant ID、Agent/安装/证书、path/revision、epoch、签发/截止时间、signer ID、issuance audit ID；不保存 secret 明文 |
| Renewal | 唯一 renewal ID、旧证书、新 CSR 摘要、prepared certificate、状态、期限；同一 ID 的冲突检测 |
| AccessAudit | v2 事件校验、字段持久化、查询/投影及计数来源区分；v1 保持可读 |

离线 grant 的授权检查、读取 revision、签发元数据及审计持久化必须共享同一授权事务，并与权限及版本变更串行化。锁顺序为全局授权 epoch、Agent/证书、secret/revision；策略或吊销变更必须遵守兼容顺序，防止读取与变更之间出现旧授权签发窗口。不能先提交一次 read，再在无锁的后台用旧结果签发新 TTL。旧客户端和其他访问通道的安全性不因新增移动端能力而弱化。

移动端读取入口应有覆盖上述步骤的完整事务边界，不能在已提交的授权结果之后追加独立签发事务。grant 签名或持久化失败时不交付声称已成功的 grant。

升级采用先 Core、后插件、最后由操作者为具体路径开启离线策略的顺序。数据库变化为 additive；不删除旧字段、不批量解密分类已有 secret、不迁移现有 Agent 身份。降级到不识别新策略/能力的 Core 不属于透明兼容；不得通过降低 auth floor 恢复连接。

## 16. 独立项目交付与开发边界

新项目以标准 Flutter 插件为交付单位，提供可供宿主 App 引用的 Dart 包、iOS/Android 原生注册、测试与示例 App。插件自身不启动 Core、不管理服务端数据库、不复制服务端应用。Dart、Swift、Kotlin 及依赖版本由实施者在开始开发时选择兼容的稳定版本并记录。

项目交付物必须包含：公开 API 与配置说明；注册审批和设备恢复使用说明；跨语言协议 schema 与测试向量；缓存格式及升级规则；两端原生实现；不泄漏 secret 的示例 App；按第 17 节逐项记录的验证报告。项目名称、代码组织与运行脚本由本项目管理，不要求放进其他项目的子目录。

开发按以下责任组织。Core 一行是外部集成依赖，其服务端代码由对应维护者提供；本项目开发者可使用严格遵守本文的协议替身进行确定性测试，随后以真实 Core 和真机完成联调。

| 责任 | 交付物 | 集成前证据 |
| --- | --- | --- |
| 协议 / Core | 移动端身份、直接读取、离线策略/grant、同步、续证、审计 v2 | 一致的协议向量、真实 Core 授权回归 |
| Dart | 配置与公开 API、Phoenix serializer、ref/generation、状态、错误映射 | Fake transport 的确定性状态与并发测试；不能代替真实 TLS |
| iOS | Secure Enclave 密钥、CSR、SecIdentity、原生 WSS、缓存和审计持久化 | 真机非导出验证及对真实 Core 的完整链路 |
| Android | Keystore、原生 key manager/WSS、缓存和审计持久化 | 真机 security level 与完整 Core 链路 |
| 集成验收 | example App、设备测试说明、协议/运维文档和最终结果 | 逐条验收矩阵及明确未验证项 |

最先验证两端的原生密钥 → CSR → Core 签发 → 原生 mTLS WSS 垂直路径；不能先用可导出 PEM 完成大部分开发，再把不可导出称为未来优化。如果某平台真实 key handle 与 TLS 适配不成立，应报告该平台阻塞，不能降低私钥要求。

开发者需要交付 example App 展示注册待审批、按配置读取、来源与期限、离线冷启动、拒绝/过期提示；不要在 example 默认日志中打印 secret。App 业务 UI 由宿主决定，本插件不附带一套管理登录系统。

## 17. 验收标准

下表为实现后的验收要求，实施者须逐条记录实际结果及证据，未执行或受环境阻塞的项目应明确标注。

| 编号 | 场景 | 必须观察到的结果 |
| --- | --- | --- |
| AC-01 | 同一 App 两个安装实例 | 独立密钥、Agent、策略、缓存；不能交换 grant |
| AC-02 | 首次注册、审批前读取 | pending 状态明确；无 secret 或离线授权泄漏 |
| AC-03 | 安装 proof 替换 CSR、challenge 重放 | Core 拒绝，CSR 私钥持有及独立 key 约束有效 |
| AC-04 | iOS 真机 mTLS | 原生 Secure Enclave key 完成 CSR、证书关联和真实 WSS join；Dart 无私钥字节 |
| AC-05 | Android 真机 mTLS | Keystore key handle 完成真实 WSS join，记录实际 security level，不能导出私钥 |
| AC-06 | 私钥设施不可用、密钥永久失效 | 明确失败，没有 PEM、HTTP token 或软件密钥 fallback |
| AC-07 | floor 2 与新旧客户端 | 移动端诚实协商后可读；旧 UDS floor、服务器 Agent 安全回归仍成立 |
| AC-08 | 在线允许、deny、损坏策略、sealed、审计失败 | 继承真实 Core 结果；拒绝不被离线缓存覆盖 |
| AC-09 | Text / Structured、换行及 `value` 字段 | 值与格式完整保持，数值不静默失真，legacy 格式明确拒绝 |
| AC-10 | 未给 read_offline 或缺少 TTL | 在线可按 read 成功；无可用离线 grant，预取报告未准备 |
| AC-11 | 离线权限受 IP/时间等实时条件影响 | 第一版拒绝 grant，不忽略条件 |
| AC-12 | TTL 边界和证书截止 | min 截断正确；到 exp 立即拒绝，无超时续期或宽限 |
| AC-13 | 断网与网络超时 | preferOnline 可返回合法离线值，标记来源和真实授权时间 |
| AC-14 | App 被系统终止后离线启动 | 未过期且身份/时钟/审计有效时成功；不依赖仍存活的 Dart timer |
| AC-15 | 挂起、深度休眠、过期后唤醒 | 休眠时间计入 TTL，过期缓存不可恢复 |
| AC-16 | 回拨、前拨过期再回拨、损坏时间锚 | 已检测异常持续 block；重启/清缓存不能清掉，文档不宣称防整机回滚 |
| AC-17 | 缓存篡改、替换路径/版本、替换 grant、未知 kid | AEAD、签名、绑定、digest 和高水位检查拒绝 |
| AC-18 | 缓存写入中断、磁盘满、队列满 | 无半项可用；离线准备失败或审计阻止交付，未确认审计不丢失 |
| AC-19 | 在线得知拒绝后主动断网/重启 | 持久化 block 优先，不能恢复旧 grant |
| AC-20 | 失联期间 Core 撤销/rotation | 在约定时间信任前提下，旧 grant 仅能用到截止；恢复后先失效同步 |
| AC-21 | join 成功、同步部分返回或掉线 | 同步屏障保留；不以握手成功放行旧缓存 |
| AC-22 | signer 轮换、bundle 回退 | 新 key 先受信；正常同步拒绝 generation 回退，旧 grant 只存活至其期限 |
| AC-23 | 续证、activate 响应丢失、切换后崩溃 | 幂等恢复至明确证书状态；不自动回退旧身份或旧 grant |
| AC-24 | 证书离线过期与身份撤销 | 不能用过期 mTLS/grant/token续期；审批恢复边界有效 |
| AC-25 | 审计离线积压、重放、冲突、传输中断 | 持久化后交付、提交后确认、重复不重复计数、冲突保留证据 |
| AC-26 | 原生交付边界崩溃 | 保留 unknown，不虚报业务已使用，也不自动重发 secret |
| AC-27 | iOS 卸载残留 Keychain、Android 备份恢复 | 新安装不继承旧身份/缓存，缺钥时拒绝，旧积压不冒名补传 |
| AC-28 | 多 isolate、换网、旧连接迟到响应、取消 | 单一身份协调，generation 隔离，Future 只完成一次 |
| AC-29 | 日志/错误/example/缓存文件检查 | 无明文 secret、token、私钥及 secret-derived digest 进入日志或审计 |
| AC-30 | 最终证据报告 | 分别列 Core 回归、Dart 测试、模拟器和两端真机结果；发布部署另列 |

原生密钥和 TLS 验收至少在一台真实 iOS 设备和一台真实 Android 设备完成，并记录设备、系统版本、插件版本、Core SHA 和 key security level。模拟器、mock transport、单元测试或仅成功编译不能替代这些项目。

## 18. 公开参考与设计说明

本文所需的产品、协议和安全约束已经在正文中给出。以下完整 HTTPS 链接只提供公开平台和标准参考，实施无需取得其他项目的设计文件：

- [Flutter：Developing packages and plugins](https://docs.flutter.dev/packages-and-plugins/developing-packages)
- [Apple：Protecting keys with the Secure Enclave](https://developer.apple.com/documentation/security/protecting-keys-with-the-secure-enclave)
- [Apple：URLSessionWebSocketTask](https://developer.apple.com/documentation/foundation/urlsessionwebsockettask)
- [Apple：客户端证书 URLCredential](https://developer.apple.com/documentation/foundation/urlcredential/init(identity:certificates:persistence:))
- [Android：Android Keystore system](https://developer.android.com/privacy-and-security/keystore)
- [Dart：SecurityContext.usePrivateKey](https://api.dart.dev/dart-io/SecurityContext/usePrivateKey.html)
- [RFC 7515：JSON Web Signature](https://www.rfc-editor.org/rfc/rfc7515)
- [RFC 7518：JSON Web Algorithms](https://www.rfc-editor.org/rfc/rfc7518)

文档依据支持该原生路线的设计选择，不等于已验证 Secure Enclave 证书关联、Android 厂商 TLS provider 或完整 Core 互操作。实施者必须按验收表提供实际证据。

本稿规定功能边界、线上/离线授权差异及时间信任模型。1 小时默认 TTL、24 小时上限、容量及平台基线属于可评审设计参数；调整这些参数不能弱化不可导出要求、在线拒绝优先、审计持久化和离线冷启动的明确限制。实施任务应引用本文，并列明承担的交付项和验证范围。
