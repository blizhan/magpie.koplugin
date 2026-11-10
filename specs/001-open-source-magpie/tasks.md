---
description: "Magpie 安全开源与社区接入准备的可执行任务清单"
---

# Tasks: Magpie 安全开源与社区接入准备

**Input**: `specs/001-open-source-magpie/` 下的设计文档。
**Prerequisites**: [plan.md](plan.md)、[spec.md](spec.md)、[research.md](research.md)、[data-model.md](data-model.md)、[contracts/](contracts/)、[quickstart.md](quickstart.md)。
**Tests**: 规格要求真实使用、安全检查和独立用户验收，但未要求 TDD 或新增自动化测试套件；本清单不增加独立的 test-first 阶段。计划已约定的 `tests/run.lua` 作为 Dev 的可运行验证入口交付，验证结果不能替代真实宿主 smoke。
**Organization**: 按 US1/P1、US2/P2、US3/P3 分组。全部复选框表示待执行，文档生成不代表任务完成。

## Format: `[ID] [P?] [Story] Description`

- `[P]` 仅表示在所在阶段入口依赖满足后，可与明确列出的其他任务并行；不得跳过阶段门禁。
- 用户故事任务必须含 `[US1]`、`[US2]` 或 `[US3]`；Setup、Foundational、最终阶段不含故事标签。
- 所有路径相对于目标仓库根目录，除明确给出的来源绝对路径。用户文件、授权、真实兼容性不足时记录阻塞，不编造结果。

## Path Conventions

运行文件位于仓库根：`_meta.lua`、`main.lua`、`dashview.lua`、`office.lua`、`projcost.lua`。文档在根目录及 `docs/`，示例在 `examples/`，打包入口为 `scripts/package.sh`，开发验证入口为 `tests/run.lua`。

源插件为 `/home/blizhan/repo/github/magpie-band-bridge/kindle/magpie.koplugin/`。只迁移明确允许的源码，不读取真实 key，不复制原历史、真实会话、截图或私人运行配置。后续信息收集继续由 subagent worker 完成，负责人合并结论并持有共享文件的编辑权。

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: 准备工具、独立验证环境与发布范围；不假定现有工具或授权已满足。

- [x] T001 [P] 核实并准备 LuaJIT、zip/unzip、Git、支持 git/dir 子命令的 Gitleaks v8，以及隔离 KOReader 运行环境；将实际版本、安装依据与未满足条件记录到 `docs/release-readiness.md`，不得把来源设备文档当作本机实跑记录。
- [x] T002 [P] 通过 worker 核查五个来源文件的版权、贡献和派生内容，结合目标 `LICENSE` 在 `docs/provenance.md` 记录 MIT 再分发依据、宿主依赖与实际捆绑内容；工具无法取得授权证据时列出精确待确认项，不自动宣称授权或对外询问。
- [x] T003 [P] 在 `.gitignore` 排除真实密钥/地址配置、会话快照、诊断图像及 `dist/`，允许明确的 `.example` 文件；不删除用户已有文件，不将 ignore 规则当作扫描结果。

**Checkpoint**: 三项准备完成；T002 可如实记录授权缺口，但 Phase 2 的源码迁移必须等待权利依据满足。

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: 形成三个故事共用的、已确认可迁入的运行基线。

- [x] T004 依据 `docs/provenance.md` 逐文件解决来源授权缺口并确认 `LICENSE` 对迁入内容适用；检查已存在的用户授权与可获得证据，仅对确实不可由工具解决的权利事实请求确认；未解决则标记 BLOCKED，禁止开始 T005。
- [x] T005 将已获授权的五个源文件迁入目标 `_meta.lua`、`main.lua`、`dashview.lua`、`office.lua`、`projcost.lua`，在写入前剔除私人默认地址与设备绝对路径，不带入真实配置、源码历史或新增框架；在 `docs/provenance.md` 记录脱敏来源 revision 和迁入范围。
- [x] T006 对将修改的 `main.lua`、`dashview.lua`、`_meta.lua` 实际符号执行 GitNexus impact 并记录到 `docs/release-readiness.md`；必要时刷新索引，HIGH/CRITICAL 先报告，空图/UNKNOWN 用源码引用补证但不得冒充图分析成功；后续每次新增符号修改仍须重新分析。

**Checkpoint**: 已授权的运行基线与修改风险依据具备。三个故事可开始其无冲突工作；许可未解决时不能勾选 T004/T005 或宣称此阶段完成。

## Phase 3: User Story 1 - 维护者安全公开项目 (Priority: P1)

**Goal**: 建立不依赖私人默认环境的候选源码与可审计的公开范围。

**Independent Test**: 对当时的候选源码、拟公开历史和全部材料做脱敏检查；隔离环境无配置启动不连接预置服务，旧敏感设置不再保留，来源授权有证据。后续新增 README/ZIP 仍需最终复审，US1 通过不代表整个产品可发布。

### Implementation for User Story 1

- [x] T007 [P] [US1] 在 `main.lua` 将配置统一到 `DataStorage:getSettingsDir()/magpie/` 的四个文件，读取首个非空非注释行、校验地址和 key、移除私人默认值及旧目录/插件内 key/settings fallback；Gateway 与 Web 独立判断，无配置不发送对应请求，遵守 `specs/001-open-source-magpie/contracts/configuration.md`。
- [x] T008 [P] [US1] 创建 `examples/base_url.txt.example`、`examples/gateway-key.txt.example`、`examples/web_url.txt.example`、`examples/web-key.txt.example`，只使用 `.invalid` 域名和明确虚构的 key，注释说明必要项、可选 Web 权限和唯一目标位置，不含真实配置。
- [x] T009 [US1] 在 `main.lua` 清除并保存旧 settings 的 `api_key`/`base_url`，保持非敏感偏好；网关菜单写入唯一 `base_url.txt` 并报告写入失败，刷新时连接身份变化清空对应缓存/cookie/发现路径；不自动删除用户的旧文件或备份，依赖 T007。
- [x] T010 [US1] 在 `main.lua` 统一安全错误输出，禁止回显 key、cookie、完整认证 URL 和响应正文；Web 登录只接受成功状态及匹配 cookie，发现 URL 限于配置 origin；保留一次 401 重认证、一次 Office 404 重新发现及原有配额回退，不新增通用重试，依赖 T009。
- [ ] T011 [US1] 按 `specs/001-open-source-magpie/quickstart.md` 用虚构旧凭据和受控请求观察验证无配置无请求、旧 settings 清理、配置变化清缓存及错误不泄漏；运行真实 KOReader 无配置入口 smoke，将可观察结果记录到 `docs/release-readiness.md`，依赖 T010。
- [ ] T012 [US1] 用 Gitleaks 脱敏模式和人工审查检查当前候选、目标拟公开历史、全部规格/研究文档及已有图片附件，将范围、发现类别和处置写入 `docs/release-readiness.md`；敏感发现整改后复验，未解决不得标记 US1 通过，不擅自改写历史，依赖 T008、T011。

**Checkpoint**: 授权已确认，US1 候选范围无未解决敏感发现，配置行为实跑成立；最终包和后续材料的公开检查仍在 T032。

## Phase 4: User Story 2 - 中英文用户独立安装与使用 (Priority: P2)

**Goal**: 双语用户凭文档完成真实安装、配置和首次使用，保留所有既有能力。

**Independent Test**: 最终候选包在隔离 KOReader 完成全部能力、失败、升级/卸载验收；中文、英文各一名未参与整理的用户在前置条件满足后，仅凭对应 README 于 30 分钟内完成首次成功使用。

### Implementation for User Story 2

- [x] T013 [P] [US2] 完成 `README.md` 英文 Feature/Install/Usage/Dev，写明实际能力、依赖、安装根目录、完全重启、菜单、四文件配置、手动迁移、升级/卸载数据处理及 HTTP/TLS/Web 管理 key 限制，互链中文入口；Dev 明确本地和自备后端验证边界，依据已批准契约起草，待 T023 核对实跑差异。
- [x] T014 [P] [US2] 独立完成 `README.zh-CN.md` 的 Feature/Install/Usage/Dev 与英文同等信息，包含用户自行取得 Gateway/Web key 和 Office 的公开步骤、配额权限与问题反馈脱敏要求；互链英文入口，不把来源记录写成新版本已验证兼容。
- [x] T015 [P] [US2] 在 `scripts/package.sh` 实现 `VERSION` 参数与 `_meta.lua` version 校验，只打入契约允许的八个文件，输出 `dist/magpie.koplugin-VERSION.zip` 单根目录；拒绝路径型版本、缺文件、不匹配版本和已有输出，清理独立临时目录并在失败时非零退出。
- [x] T016 [US2] 核实既有版本约定，在 `_meta.lua` 设置明确 version 并保留 name=`magpie`，同步 `main.lua` 的公开 User-Agent 身份且不带用户/设备标识；依赖 T010，避免与 US1 同时修改 `main.lua`。
- [x] T017 [US2] 在 `main.lua` 和 `dashview.lua` 完成缺配置、权限不足、空内容、Office 未启用与网络错误的可执行提示及旧数据标记，保留三个页面、详情、趋势周期/指标、手势、Dispatcher 和关闭/挂起计时行为；先观察现有路径，仅修复不满足契约处，不重写数据转换，依赖 T016。
- [ ] T018 [US2] 在隔离自备环境按公开说明实际取得并启动 Magpie Gateway/Web 和 Agent Office，验证 key 权限、Web 实际进程 key 与设备可达性；将完整可复现步骤和版本记录到 `docs/release-readiness.md`，若公共 Office 包不可用则核实官方源码安装路径，不能用 fixture 冒充安装成功。
- [ ] T019 [US2] 在 T013–T018 完成后运行 `scripts/package.sh`，核对 ZIP 仅含八个允许文件、单一根目录和一致版本，检查缺文件/不匹配版本/已有输出的失败结果，将实际包 SHA-256 和命令结果写入 `docs/release-readiness.md`。
- [ ] T020 [US2] 从 T019 的实际 ZIP 干净安装并按 `specs/001-open-source-magpie/quickstart.md` 实跑 Gateway 用量/配额/并发、项目费用、Office 详情、三周期趋势和手势/Dispatcher；每项保留能力至少一条成功证据，记录环境到 `docs/release-readiness.md`。
- [ ] T021 [US2] 在同一隔离环境实跑缺配置、不可达服务、空内容、错误 key/JSON、cookie 过期与 Office 404 恢复、关闭/挂起/恢复，并验证升级保留配置及卸载/彻底清理不影响其他设置，记录到 `docs/release-readiness.md`，依赖 T020。
- [ ] T022 [US2] 由中文、英文各一名未参与整理的验证者仅凭对应 `README.md`/`README.zh-CN.md` 完成首次安装使用，记录各自不超过 30 分钟的实际时长、卡点与反馈到 `docs/release-readiness.md`；人员或环境不可得时保留未完成，不由主维护者代称通过，依赖 T021。
- [x] T023 [US2] 根据 T020–T022 的结果修正并逐项对齐 `README.md` 和 `README.zh-CN.md` 四节、前置条件、限制与安全说明，补入真实兼容范围；文档或包内容有变则在最终阶段重建并补验受影响路径，不将失败验收改写为通过。

**Checkpoint**: 两种语言可独立使用；所有保留能力与必要失败流程都有真实结果。最终打包内容若有变化，旧摘要不能用于发布验收。

## Phase 5: User Story 3 - 外部开发者贡献与社区发现 (Priority: P3)

**Goal**: 提供不依赖维护者私人环境的开发验证入口与有一手依据的社区提交材料。

**Independent Test**: 一名未参与原项目的开发者在 60 分钟内按 Dev 完成一次本地修改验证；五渠道评估完整，至少一条接入路径的介绍、实际项目链接、兼容证据和作者披露齐备，无无证据收录/兼容声明。

### Implementation for User Story 3

- [x] T024 [P] [US3] 实现计划约定的 `tests/run.lua` 开发验证入口，以隔离目录、固定时间和合成输入覆盖真实 `office.lua`/`projcost.lua` 的状态边界、同名目录/缺 cwd/残差费用行为，并通过真实接口覆盖配置清理及认证恢复；失败非零退出且输出脱敏，不读取个人快照、不增加大型框架；入口最后集成依赖 T017，禁止同时修改运行文件。
- [x] T025 [P] [US3] 由 worker 复核既有五渠道一手依据与日期，将自动发现、Awesome 精选、contrib、AppStore、Storefront 条件及未知项整理到 `docs/community.md`，从可用仓库元数据核实 canonical URL，不猜地址、不发送消息或提交 PR。
- [x] T026 [US3] 运行 `luajit tests/run.lua` 并核实失败场景确实返回非零；在 `README.md` 和 `README.zh-CN.md` 的 Dev 中对齐实际命令、依赖、贡献步骤、错误报告脱敏及真实宿主验证边界，依赖 T024、T023。
- [x] T027 [US3] 在 `docs/community.md` 完成至少一条 Awesome KOReader 现有分类下的可审阅条目与提交正文，包含实际公开项目入口、功能依赖、安装/兼容证据及作者身份披露，同时记录 topic/命名准备与可选 contrib 条件；未公开入口或未实测商店如实标记，不伪称收录，依赖 T025、T023。
- [ ] T028 [US3] 由一名外部开发者按更新后的 Dev 在 60 分钟内完成一次修改验证，记录实际时间、步骤及阻碍到 `docs/release-readiness.md`；必要修正同步 `README.md`、`README.zh-CN.md` 和 `tests/run.lua`，依赖 T026。
- [ ] T029 [US3] 对照 `docs/community.md` 核对五渠道覆盖、来源日期、推荐路径材料和状态证据，将结果写入 `docs/release-readiness.md`；区分 materials-ready、submitted、listed 与 installation-verified，未执行外部动作不得勾选相应状态，依赖 T027、T028。

**Checkpoint**: 开发者流程和社区准备可独立审阅；社区是否最终接受不属于可控验收，本清单不授权自动提交。

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: 固定最终候选，完成跨故事复审，不扩大功能范围。

- [ ] T030 在真实 smoke 已完成后更新 `CHANGELOG.md`，记录配置干净切换、旧字段清理、手动迁移和实际支持范围；核对 `README.md`、`README.zh-CN.md` 与 `docs/provenance.md` 的许可和版本信息，仅清理本任务产生的临时脚本/数据，不删除用户文件。
- [ ] T031 使用 `scripts/package.sh` 对最终文档和源码生成新候选 ZIP，更新 `docs/release-readiness.md` 中版本/摘要，从该 ZIP 重做干净安装并补验自 T020 以来受影响的路径；文档修改影响独立用户流程时补做对应语言/开发者验收，不重复无关已通过场景。
- [ ] T032 对最终工作树、拟公开历史、文档/规格/研究/图片/附件和 T031 解包内容完成 Gitleaks 脱敏扫描及人工私人配置检查，将完整类别覆盖、工具版本和未解决发现数记录到 `docs/release-readiness.md`；发现后整改并复验受影响产物，不输出秘密原值。
- [x] T033 在 `docs/release-readiness.md` 逐条汇总 FR-001–FR-012 和 SC-001–SC-006 的证据及五个发布门禁；任一授权、隐私、运行或独立验收未完成则结果为 ERROR/BLOCKED，全部通过才标记 release-ready；如随后准备提交，先按仓库规则完成 detect-changes 并处理 partial/truncated，未获明确发布指令不推送、发布或联系社区。

## Dependencies & Execution Order

### Phase Dependencies

顺序图（箭头表示完成依赖）：

```text
Phase 1 Setup → Phase 2 Foundation → US1 → US2 → US3 → Phase 6
                                    │      │      │
                                    └──────┴──────┴──→ 最终候选复审
```

这是故事**完成**顺序；US2 文档/打包和 US3 渠道研究可在 Foundation 之后提前进行。其独立验收不要求外部社区收录，但真实完成依赖共享运行基线，不能声称三个故事完全无依赖。

### User Story Dependencies

- US1：T007 与 T008 并行，之后 T007 → T009 → T010 → T011；T008 + T011 → T012。
- US2：Foundation 后 T013/T014/T015 并行；T010 → T016 → T017。T018 可在前述工作不占同一环境时准备，但由同一负责人写共享验收记录。T013–T018 → T019 → T020 → T021 → T022 → T023。US1 的候选审查 T012 必须在 US2 完成前通过。
- US3：T024 与 T025 使用不同文件；T024 可先写纯模型部分，但配置集成待 T017。T023 + T024 → T026 → T028；T023 + T025 → T027；T027 + T028 → T029。
- Final：T012、T023、T029 → T030 → T031 → T032 → T033。
- `docs/release-readiness.md`、`main.lua` 和双语 README 都是共享写入点：单一负责人按依赖合并，不安排并发修改。编号表示推荐执行序，不替代显式依赖。

### Parallel Opportunities

标记 `[P]` 的十项组成四组：T001/T002/T003；T007/T008；T013/T014/T015；T024/T025。最后两组仅在其前置满足时启动；T024 的完整集成不能越过 T017。未标 `[P]` 的任务默认顺序执行，避免共同操作设备或验收记录。

## Parallel Example: User Story 1

Foundation 完成后，worker A 执行 T007（`main.lua` 唯一配置来源），worker B 执行 T008（四个 `examples/*.example`）。配置字段与目标目录以 configuration 契约为共同输入；A 完成后再顺序执行 T009/T010。

## Parallel Example: User Story 2

Foundation 完成后，worker A 按契约编写 T013（`README.md`），worker B 编写 T014（`README.zh-CN.md`），worker C 编写 T015（`scripts/package.sh`）。三者不编辑同一文件；主负责人在 T023 根据实际运行结果统一术语与语义，不以并行起草等同双语验收。

## Parallel Example: User Story 3

T017 后可让 worker A 执行 T024（`tests/run.lua`），worker B 执行 T025（`docs/community.md` 的来源核实）。没有真实运行环境时 A 不伪造测试通过；B 只做只读信息收集，不提交社区材料。

## Implementation Strategy

### MVP First (User Story 1 Only)

先完成 Setup、Foundation 和 US1，得到经过当前范围隐私审查、无私人默认连接且授权清楚的源码候选。这是首个可验收增量，不是整个开源项目已完成，也不满足最终双语/完整分发要求；不据此提前公开。

### Incremental Delivery

随后交付 US2 的双语真实使用，再交付 US3 的开发验证和社区材料，最终对固定包摘要复审。所有故事均为本功能必交付范围；“MVP first”仅是实施顺序，不允许省略 US2/US3。

### Parallel Team Strategy

信息收集继续交给只读 worker；编辑按上方无冲突分组。每组的代码/文档成果由一个负责人集成后运行相应检查，worker 中途不各自跑构建或测试。源码改动前执行 impact，导出符号改动按规则先查引用；零符号图不得解释为无调用者。

## Requirement and Entity Coverage

|要求|任务|实体/契约|
|---|---|---|
|FR-001、FR-004 / SC-004|T005、T007、T017–T021|UserConfiguration、DashboardSnapshot、Project/Session/CostBucket；configuration/backend|
|FR-002、FR-003 / SC-001|T003、T007–T012、T032|UserConfiguration、PublicCandidate；configuration/distribution|
|FR-005、FR-006、FR-007 / SC-002、SC-003|T013–T023、T031|DocumentationPair、CapabilityEvidence；configuration/distribution|
|FR-008 / SC-005|T024、T026、T028|Dev 验证入口、DocumentationPair|
|FR-009 / SC-001|T002、T004、T030、T033|PublicCandidate.provenance；distribution|
|FR-010、FR-011 / SC-006|T025、T027、T029|CommunityRoute；distribution|
|FR-012|T011、T012、T019–T022、T028–T033|PublicCandidate、CapabilityEvidence；发布门禁|

## Notes

- 当前来源授权仍未确认；任务已明确解决步骤与阻塞位置，不等同于现在请求用户重复授权。
- constitution 仍为未填写模板；不得从其中示例推导 TDD 或额外治理要求。
- 本清单是执行计划，不填入虚构测试结果。需要真实设备、独立验证者或权利证据的任务保持未完成直至实际满足。
- 前后置扩展钩子检查结果由本次任务生成流程记录；本清单不隐式授权提交、推送或对外联系。

## Generation Validation

2026-11-10：33 项任务编号 T001–T033 连续且唯一；全部符合复选框、ID、适用故事标签和明确文件路径格式。US1 为 6 项，US2 为 11 项，US3 为 6 项，共享准备/收尾为 10 项；10 项标记可并行。12 条功能要求均已映射，文档链接检查通过。前置与后置均未发现 `.specify/extensions.yml`，无 before_tasks / after_tasks 钩子需要执行。本记录仅验证任务文档，不代表实施验收通过。
