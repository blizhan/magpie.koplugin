# Data Model: Magpie 安全开源

此文定义现有运行数据和发布记录，不引入数据库、在线发布管理系统或新的持久化框架。运行数据保持原插件的数据表；发布记录使用 Markdown。字段名为设计契约，后端原始字段见 [backend.md](contracts/backend.md)。

## 1. UserConfiguration

|字段|来源 / 生命周期|约束|
|---|---|---|
|gateway_url|专用配置目录 `base_url.txt`|用户显式给定的 HTTP(S) 基地址；禁止内置私人默认值、userinfo、查询参数和 fragment；结尾斜线归一化|
|gateway_key|`gateway-key.txt`；请求时读取|首个非空非注释行；不得含 CR/LF；不得写入 settings、日志或公开材料|
|web_url|`web_url.txt`|显式给定；现有 Web transport 支持 HTTP，HTTPS 不宣称可用；不从 gateway 推导|
|web_key|`web-key.txt`；cookie 仅内存|至少 16 字符、字符集 `[A-Za-z0-9._~-]`；是管理凭据|
|auto_refresh_sec|`settings/magpie.lua` 的非敏感偏好|沿用 60 秒默认值；不新增用户入口或更密集轮询|
|user_agent|同上|公开插件身份，不含用户、主机或设备标识|

配置目录由 KOReader `DataStorage:getSettingsDir()` 派生，通常为其 settings 下的 `magpie/`，不硬编码安装根路径。密钥与地址仅在用户设备保存。主机上的 Magpie key 管理不属于插件存储。

**关系**：一份 UserConfiguration 可启用 Gateway 数据及可选 Web 数据；未配置的能力保持不可用，不创建假的成功数据。

**状态**：Gateway URL/key 均有效 → gateway-ready；Web URL/key 均有效 → web-configured；登录成功 → web-authenticated。缺失或格式错误 → configuration-required；错误提示仅包含缺失项名称。更改 Web 连接或 key 后清空内存 cookie 和发现路径，下一次访问重新认证。旧服务的缓存不能显示为新配置的数据。

## 2. DashboardSnapshot

|字段|意义与存储|
|---|---|
|usage|当前周期用量与趋势序列；内存|
|concurrency|请求、等待、工具计数；内存|
|quotas|供应商/账户窗口信息；内存，真实账户信息不进入 fixture 或截图|
|project_costs|从 Web stats 聚合的项目费用；内存|
|office|压缩的项目/会话状态及详情；内存|
|last_success / error|每类数据的最后成功时间与错误状态；错误为安全的类别，不包含响应正文或凭据|
|period / metric / page|今日、7 日、30 日；费用或请求；当前页面，沿用既有视图行为|

**关系**：DashboardSnapshot 由一份 UserConfiguration 下的多个独立请求更新；其中一项失败不应覆盖其他项的成功值。错误后的旧值必须标记为旧数据。首次失败不得显示为真实零消费或成功示例。

**状态**：未请求 → loading → ready；请求失败且有旧值 → stale-with-error；无旧值 → unavailable。成功恢复后清除相应错误。关闭/挂起停止刷新；恢复行为按真实宿主事件验收，不能仅由离屏渲染推断。

## 3. Project / Session / CostBucket

|实体|字段|行为约束|
|---|---|---|
|Project|项目标识/展示名、会话集合、聚合状态、更新时间|沿用现有分组；显示名可能包含私人内容，不等于匿名标识|
|Session|phase、updated、touched、inflight、last；可选 agent/model/title/step 等|时间为 epoch 毫秒；详情字段截短不等于脱敏；正文不进入公开 fixture|
|CostBucket|日期、项目目录末级名、费用、其余费用|沿用末级名称合并；同名目录会归并；不能声称目录全路径身份隔离|

闲置判断必须同时满足“无需处理且无工作会话”与更新时间阈值；不将仅有时间较旧的工作项目归入闲置。时间边界、同名项目、缺少 cwd 和残差费用由固定时间/合成数据回归测试覆盖。

## 4. PublicCandidate

|字段|意义|
|---|---|
|version / source_revision / package_digest|拟发布版本、来源 revision 和最终 ZIP 摘要；版本身份一致|
|runtime_files|五个 Lua 文件的允许清单|
|public_materials|仓库、拟公开历史、文档、图片、附件、分发包的完整审计范围|
|provenance|每项来源、授权证据、适用许可和第三方 notice|
|privacy_review|检查范围、工具版本、日期、脱敏结论与尚未解决项|
|validation_records|按能力、环境、语言、渠道记录真实验收结果|
|state|draft、blocked、verified、release-ready|

**状态迁移**：draft → blocked（授权/隐私/验收条件未满足）；所有适用检查完成且无未解决项 → verified；版本与最终包摘要固定且全部门禁通过 → release-ready。任何候选内容、打包输入或依赖兼容声明变化使受影响的验收失效，回到 blocked。真实公开操作不由该记录自动触发。

**约束**：不能把扫描“零命中”写成不存在任何秘密；不能从许可证文件存在推导来源已授权。调查记录不含真实 key、私人地址或个人业务数据。

## 5. DocumentationPair / CapabilityEvidence

DocumentationPair 包含 `README.md` 与 `README.zh-CN.md`，共享版本和 Feature / Install / Usage / Dev 覆盖表。CapabilityEvidence 包含能力名、前置依赖、场景、实际环境、结果和证据位置。

两种语言必须分别覆盖配置、首次成功、错误、升级、卸载、数据保留和开发验证。每项保留能力至少一条实跑记录；语言核对是人工语义检查，不能用标题存在代替。

## 6. CommunityRoute

字段：channel、canonical_url、category、discovery_or_submission、requirements、source_url、checked_at、prepared_materials、status。

status 为 researched / materials-ready / submitted / listed / installation-verified；这些状态不是线性替代关系，商店安装验证与清单收录独立。只有对应证据才能设置 submitted、listed 或 installation-verified。本次规划记录的状态最多为 researched。
