# Implementation Plan: Magpie 安全开源与社区接入准备

**Branch**: 实际 Git 分支 `main`；setup-plan 返回功能解析标识 `001-open-source-magpie`，本轮未创建或切换分支。
**Date**: 2026-11-10
**Spec**: [spec.md](spec.md)
**Input**: `specs/001-open-source-magpie/spec.md`

## Summary

将现有五文件 KOReader 插件整理为当前仓库中的独立开源交付，保留今日用量、配额、项目费用、在飞项目及详情、趋势与刷新行为。采用 KOReader 设置目录下的唯一配置来源，移除私人默认地址、旧路径回退及通用 settings 中的凭据；以明确允许清单生成安装包。补齐中英文 README、来源授权记录、脱敏发布检查及五个社区渠道材料。

信息收集由 `RuntimeContracts`、`ReleaseValidation` 两个只读 subagent worker 完成，复用上一阶段 `PluginFacts`、`CommunityFacts` 的调查。研究决策见 [research.md](research.md)。本轮截止 Phase 1：不迁移源码、不运行产品、不创建发布包、不发布或提交社区申请。

## Technical Context

**Language/Version**: Lua 5.1 兼容代码，使用 KOReader 自带 LuaJIT；本地工具采用 POSIX shell。精确宿主 LuaJIT 版本在实施运行记录中取得，不根据系统 Lua 版本推断。

**Primary Dependencies**: KOReader UI/字体/FFI/设置/网络管理；宿主 `socket.http`、`ssl.https`、`ltn12`、`json`，现有可选 `rapidjson`。外部 Magpie Gateway、Magpie Web 与 `@magpie-community/page-agent-office` 保持为自备依赖，不捆绑后端。官方获取、共享、key、Web 启动与登录依据已核实；Office 包公共安装仍需真实复现。

**Storage**: `DataStorage:getSettingsDir()/magpie/` 中四个用户配置文件；原 `magpie.lua` 只保存非敏感偏好；请求数据、cookie、页面及发现路径为内存状态。无数据库或新配置框架。

**Testing**: LuaJIT 合成输入行为回归；真实 KOReader 干净安装与交互 smoke；实际自备后端的完整功能验收；ZIP 成员检查；Gitleaks v8 脱敏扫描加人工检查；中文/英文各一名独立用户与至少一名开发者验收。源 `t_*.lua` 仅作方法参考，不直接复制其中私人路径或真实快照依赖。

**Target Platform**: KOReader 插件。来源记录的 KOReader 2026.07.1 / Kindle Basic 7th gen / 600×800 是首个验收目标，不是本轮已验证兼容矩阵。其他设备按实际结果声明。

**Project Type**: 单一 `.koplugin` 仓库，附文档、有限开发测试和本地打包脚本。

**Performance Goals**: 保持 60 秒默认自动刷新、关闭/挂起停止刷新、各数据项失败保留旧值并标记过期；不新增轮询、遥测或通用重试。30 分钟双语首次使用与 60 分钟开发验证为规格中的验收目标，不是网络延迟指标。

**Constraints**: 不公开真实凭据、私人配置或个人内容；不导入来源历史；已有目标历史仍需检查。旧 settings 凭据和配置位置采用明确手动迁移，不保留隐式 fallback。不顺带改写后端认证或传输栈，但必须披露现有 HTTP/TLS/Web 管理凭据限制。目标仓库已有 MIT，来源授权未确认前不得把迁入内容标为已许可或公开。

**Scale/Scope**: 五个 Lua 文件、三个主页面及详情、两种 README 语言、五个社区渠道；无新 AI/RSS/知识卡片产品能力。worker 未确认本地 LuaJIT、KOReader、scanner 可执行环境，实施前须安装/核实，不能跳过验证。

## Constitution Check

*GATE: Phase 0 前检查，并在 Phase 1 后复核。*

|检查|Phase 0 前|Phase 1 后|
|---|---|---|
|constitution 是否包含已批准原则|文件存在但仍是模板，无可执行原则|相同；不编造原则，也不称宪章已获批准|
|用户要求的信息收集方式|已分配只读 worker|满足：技术与社区结论均有 worker 依据|
|范围与公开边界|仅规划，不接触私人服务|满足：设计保留原能力，无对外写入|
|敏感信息处理|禁止读取真实 key 和输出私人值|调查与设计仅记录类别、文件名及公开来源；最终公开仍需完整扫描|
|仓库图分析规则|本轮无函数修改/提交，不触发 impact 或 detect-changes|相同；后续每次源码修改先 impact，UNKNOWN 必须补证；提交前 detect-changes 不可省略|
|设计是否引入无必要架构|保留五文件结构|满足：没有新后端、数据库或配置框架|

**Design gate result**: PASS（没有已知未解释的治理规则违反项；constitution 未批准不是被宣称通过）。所有技术研究问题已形成决策，无待选择的技术方案。

**Implementation/publication gates**: 来源授权为 BLOCKED；最终隐私扫描、宿主运行、双语独立验收均为 NOT RUN。这些不是本轮设计已完成的工作。完整状态见 [distribution.md](contracts/distribution.md#发布门禁)；任何未通过项在发布评估时必须报 ERROR/BLOCKED。许可前提不能通过把 MIT 文件复制过去来解除。

## Project Structure

### Documentation (this feature)

```text
specs/001-open-source-magpie/
├── spec.md
├── plan.md
├── research.md
├── specification-evidence.md
├── planning-evidence.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── configuration.md
│   ├── backend.md
│   └── distribution.md
└── checklists/requirements.md
```

`tasks.md` 留给 `/speckit.tasks`，本轮不生成。证据文件保留调查时的限制与后续补充，最终设计决策以 research.md 和 contracts 为准；证据未经过发布扫描前不能直接称可公开。

### Source Code (repository root, implementation target)

```text
_meta.lua
main.lua
dashview.lua
office.lua
projcost.lua
LICENSE
README.md
README.zh-CN.md
CHANGELOG.md
.gitignore
examples/
├── base_url.txt.example
├── gateway-key.txt.example
├── web_url.txt.example
└── web-key.txt.example
scripts/package.sh
tests/run.lua
docs/
├── provenance.md
├── community.md
└── release-readiness.md
dist/                         # 本地产物，忽略，不随源码发布
```

**Structure Decision**: 沿用源插件模块职责；仅在 `main.lua` 内集中处理新的配置位置、缺配置状态及安全错误，不预先拆出抽象层。纯数据转换仍由 `office.lua` / `projcost.lua` 承担，`dashview.lua` 保持视图。测试通过真实行为接口验证，不以源文本或转发次数作为永久断言。包只含允许清单中的运行源码、许可证和双语 README；研究、测试、脚本和示例不打入包。

## Phase 0 — Research Decisions

已完成，详见 [research.md](research.md)：

1. 保留 KOReader/LuaJIT 与现有模块职责，不新增后端。
2. 配置采用设置目录下四文件的干净切换，明确手动迁移；无私人地址默认值或 settings key fallback。
3. 官方 Gateway 与 Web 公开部署路径已找到；Web 登录固定源码证据与现有客户端相容，运行与 Office 安装仍需验收。
4. 沿用目标 MIT 的策略以来源授权为前提，不推定权利。
5. 单根目录 ZIP + 允许清单，英文标准 README 与中文 README 互链。
6. 行为测试、真实宿主 smoke、公开材料扫描及独立用户验收分层记录。
7. 自动发现优先、Awesome 人工清单材料其次、contrib 可选，不承诺外部接受。

## Phase 1 — Design and Contracts

已生成：

- [data-model.md](data-model.md)：配置、快照、项目/会话、候选版本、双语文档与社区状态；不引入新的在线系统。
- [configuration.md](contracts/configuration.md)：配置唯一来源、菜单写入、缺失状态、迁移、升级/卸载及公开服务取得步骤。
- [backend.md](contracts/backend.md)：现有 Gateway/Web 消费形状、鉴权恢复、缓存与错误行为；只定义客户端所需内容。
- [distribution.md](contracts/distribution.md)：包成员、版本、待实现命令接口、审计范围和发布门禁。
- [quickstart.md](quickstart.md)：可执行的离线、打包、扫描、干净安装、真实后端、错误/生命周期、双语及社区验证指南。

### Implementation Order and Dependencies

1. **来源与材料确认**：建立五个源文件的来源和授权记录；确认 MIT 可适用。任何权利不明项阻止相关源内容的再分发；不擅自更换许可证。确认图工具可用性，零符号索引或 UNKNOWN 不能当零风险。
2. **独立插件与配置切换**：只迁入允许的运行文件；移除私人默认值与部署绝对路径。更新全部旧配置读写位置、菜单保存和文档；不保留兼容别名或回退。修复因本次切换造成的缺配置、凭据落盘和旧缓存显示问题。
3. **行为验证与说明**：保留全能力，编写必要行为回归与人工数据；完成真实宿主 smoke 后更新双语 README/CHANGELOG。最终能力依赖可获得性按真实安装记录填写，失败不以缩减能力范围绕过。
4. **打包与候选审计**：版本化 metadata、允许清单打包；候选工作树、拟公开历史及最终 ZIP 扫描，人工查私人配置与素材。若现有历史有问题，停止公开并提出具体处置，不能擅自改写用户历史。
5. **独立验收与社区材料**：达到规格时间/覆盖要求，填写发布门禁记录与实际 canonical URL，准备提交材料。未获独立实测的商店兼容性保持未验证。此阶段不自动对外提交。

第一项中不依赖授权事实的文档和工具准备可推进；授权问题未解除时不能宣布整体开源交付完成。按上述依赖拆任务，避免把许可或真实设备验收藏到“后续优化”。

### Requirement Coverage

|规格|设计落点|验证|
|---|---|---|
|FR-001、FR-004|模块保留、配置/后端契约|全部能力及无配置启动，SC-004|
|FR-002、FR-003、FR-012|配置切换、公开候选模型、分发门禁|四类配置、历史/工作树/包/素材检查，SC-001|
|FR-005、FR-006、FR-007|双语文档接口、兼容性证据、升级/卸载|四节语义核对及两名用户计时，SC-002、SC-003|
|FR-008|Dev、合成行为测试与真实宿主指南|独立开发者验证，SC-005|
|FR-009|provenance 与 MIT 条件|授权证据与包内 notice，SC-001|
|FR-010、FR-011|五渠道评估与本地提交材料|来源/日期/材料/状态核对，SC-006|

## Complexity Tracking

没有需要豁免的已知治理违规项，也没有额外架构复杂度。constitution 仍未填充、来源授权仍未确认、运行验收尚未执行，均按上述状态如实保留，不作为复杂度豁免理由。

## Planning Validation Record

2026-11-10：检查 7 份核心设计产物、21 个本地文档链接、12 条 FR 覆盖；4 个 shell 示例块通过 `sh -n`。必需计划章节齐全，无未解决澄清标记或模板占位符，检查错误为 0。

前置与后置检查均未发现 `.specify/extensions.yml`，因此没有需执行的 before_plan / after_plan 钩子。实际插件、测试入口、打包工具和设备验收尚未实施或运行；本记录不改变发布门禁状态。
