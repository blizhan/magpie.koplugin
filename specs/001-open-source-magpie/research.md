# Phase 0 Research: Magpie 安全开源

**Date**: 2026-11-10
**Method**: 信息收集由只读 worker `RuntimeContracts`、`ReleaseValidation` 完成；规格阶段的 `PluginFacts`、`CommunityFacts` 结果继续复用。主代理负责设计决策。未读取真实密钥、连接私人后端或执行产品测试。

## 1. 产品与运行基线

**Decision**: 保留 `_meta.lua`、`main.lua`、`dashview.lua`、`office.lua`、`projcost.lua` 五文件插件结构，运行目标为 KOReader 自带的 LuaJIT/Lua 5.1 兼容环境。保留今日用量、配额、项目费用、在飞项目及详情、趋势和刷新行为。以来源文档记录的 KOReader 2026.07.1 / Kindle Basic 7th gen 作为首个验证组合，不宣称最低版本或所有设备兼容。

**Rationale**: 现有入口、控件、字体、设置、HTTP/HTTPS 和 JSON 均依赖 KOReader 宿主；两个数据转换模块可独立验证。来源没有现成测试框架或发布入口。系统 Lua 5.1.4 的探测记录不能替代 KOReader LuaJIT 版本证明。

**Alternatives considered**: 改写界面、引入通用看板框架、随包捆绑 KOReader 或新增后端均超出需求；拆出大量模块会增加迁移面，当前不采用。

**Evidence**: 来源插件 `main.lua:22-36`、`dashview.lua:9-35`；来源 `kindle/README.md:5-16,73-84`。详细调查见 [specification-evidence.md](specification-evidence.md) 与 [planning-evidence.md](planning-evidence.md)。

## 2. 配置与隐私清理

**Decision**: 采用单一配置位置：`DataStorage:getSettingsDir() .. "/magpie/"` 下的 `base_url.txt`、`gateway-key.txt`、`web_url.txt`、`web-key.txt`。地址必须由使用者显式提供，Web 地址不再从 Gateway 地址推导。四个文件均读取首个非空、非注释行。原 `magpie.lua` settings 仅保存非敏感偏好；不再读取或写入 `api_key` / `base_url`。现有设置读取后清除这两个旧字段并保存；旧配置文件由用户按迁移说明自行转移或删除，不修改来源项目。

**Rationale**: 来源有硬编码的设备绝对路径、私人默认地址、多层凭据回退和密钥写入 settings。沿用这些行为会使用户难以确定实际连接与认证来源。配置目录位于插件目录之外，可与升级包分离。保留现有文件名降低手动迁移成本；设置菜单写入同一个 `base_url.txt`，避免第二来源。

**Alternatives considered**: 保留旧绝对路径、插件内 `apikey.txt` 和 settings fallback 会维持歧义与泄漏风险；自动读取旧位置迁移可能悄悄连接旧服务；新增配置框架或数据库没有必要。此处是显式干净切换，不承诺旧位置自动兼容。

**Evidence**: 来源 `main.lua:48-79,329-374,430-438,506-551,626-637`。旧路径、优先级及新配置行为分别在调查记录和 [配置契约](contracts/configuration.md) 中区分。

## 3. 后端边界与公开取得路径

**Decision**: 插件继续作为现有 Magpie gateway/web 的客户端，不增加后端。Gateway 是用量/并发/配额前提；Web 与 Agent Office 分别是项目费用、在飞详情的附加前提。缺少附加配置时保持 Gateway 页面可用，并显示依赖缺失，不能用虚构数据表示成功。

**Rationale**: 官方公开资料已说明 Magpie 安装、`magpie serve`、局域网共享、Gateway keys 和 stats 接口。配额可见范围取决于 key 权限，不能保证任意 key 返回全部配额。Agent Office 元数据给出 Magpie ≥0.1.1318 和公开项目坐标，但 registry 的两次查询返回 404；记录这个结果，不能推导为插件不存在，也不能将独立 Agent Office 服务当作现客户端的直接替换。

**Alternatives considered**: 把维护者的服务作为默认演示环境会泄漏私人配置并造成外部依赖；重新实现后端或改接独立 Agent Office 改变功能范围，不采用。

**Evidence**: [官方安装入口](https://usemagpie.ai/#cli)、[运行与 Web 启动](https://usemagpie.ai/docs/start#faq)、[共享、key 和 stats](https://usemagpie.ai/docs/remote)、[插件与权限](https://usemagpie.ai/docs/integrate)、[Agent Office 来源](https://github.com/magpie-community/plugins/tree/main/packages/agent-office)。运行契约来自源插件实际消费的字段，详见 [后端契约](contracts/backend.md)。

## 4. 安全声明的范围

**Decision**: 消除公开材料中的真实密钥、私人默认值和个人内容；禁止把认证值、cookie、含 key 的完整请求 URL 或响应正文写入用户错误信息与公开诊断。保留既有服务鉴权协议，本轮不设计服务端认证改造。文档明确 Web 登录参数、Web 凭据权限、HTTP 及现有 TLS 校验行为的实际限制，不宣称只读凭据、端到端安全或设备内绝不接触原始内容。

**Rationale**: 原客户端 Web 登录使用查询参数，Gateway HTTPS 显式关闭证书校验，Web 使用 HTTP transport；原始会话数据先接收后压缩。公开源码清理不能证明传输安全或消除服务端日志风险。

**Alternatives considered**: 仅扩大 `.gitignore` 不覆盖历史、截图及打包输入；宣称所有凭据只读或仅存在外部文件与现状矛盾；顺带重做认证和网络栈超出此次开源整理范围。

**Evidence**: 来源 `main.lua:565-583,641-715,748-780`；规格 FR-002、FR-003、FR-012。公开使用说明必须如实描述这些限制，禁止无证据的安全承诺。

## 5. 许可证与来源权利

**Decision**: 沿用目标仓库已有 MIT 许可作为目标许可，不新选或自动替换许可证；迁入五个源文件前建立来源/权利记录，确认其可按该许可再分发。无法确认的源文件不得被宣布为已授权，也不得发布。宿主依赖与实际捆绑内容分别列出。

**Rationale**: worker 找到目的仓库 MIT LICENSE，但来源未找到 LICENSE/COPYING/SPDX 授权依据。目的许可证不能自动覆盖来源贡献或派生内容。没有可由代码调查替代的权利人授权。

**Alternatives considered**: 因 KOReader 或 contrib 的许可证标签自动给插件套用许可证、或把用户拥有本地目录视为第三方权利已核实，均不成立。

**Resolution**: 许可策略已定；授权事实仍是实施/发布门禁，状态为 blocked，只有可引用的授权或来源证明才能解除。此为明确的外部前提，不是待选择的技术方案。

## 6. 分发与双语文档

**Decision**: 源码位于仓库根目录；打包脚本采用显式允许清单，产出单一 `magpie.koplugin/` 根目录 ZIP。包含五个运行文件、LICENSE、英文 `README.md` 和中文 `README.zh-CN.md`。配置示例只放仓库 `examples/`，不进入安装包；README 内提供自给自足的配置说明。发布包不包含研究记录、真实快照、诊断图片、本地设置和开发工具。`_meta.lua` 增加与发行版本一致的明确版本字段。

**Rationale**: 现有运行集只有五个文件；AppStore 会获取标准 README.md。显式清单避免忽略文件被打包；版本身份支持安装和升级识别。规格和研究文件即使不在安装包，若随仓库公开仍必须审计。

**Alternatives considered**: 全目录压缩配合黑名单容易遗漏私人文件；中英混排的大 README 不利于单语用户验证；仅中文 README 限制社区入口。

**Evidence**: [AppStore](https://github.com/omer-faruq/appstore.koplugin/blob/main/README.md)、[Storefront](https://github.com/ultimatejimmy/storefront.koplugin/blob/main/README.md)，以及五文件依赖调查。

## 7. 验证与开发工具

**Decision**: 使用 LuaJIT 执行少量行为回归测试；以合成输入替代真实会话快照。配置缺失/优先级清理、凭据不持久化、项目聚合、状态边界和既有鉴权恢复行为是测试重点。真实 KOReader 干净安装与交互是必需 smoke；离屏渲染只证明绘制路径。分发用 shell + zip/unzip；发布安全检查选用 Gitleaks v8 的脱敏输出，加人工配置/图片/历史范围审查。

**Rationale**: 来源 `t_*.lua` 是人工诊断工具，部分使用真实后端或快照，不能直接迁入默认离线测试。本机 worker 仅定位到部分工具文件，未执行版本检查，也未确认 LuaJIT、KOReader 或 Gitleaks 已安装。它们必须作为实施验证环境的显式前置条件，不能将“找不到”当成测试通过。

**Alternatives considered**: 引入大型测试框架、只做语法检查、用 mock 结果冒充真实 UI 或真实服务验收均不满足本需求。合成 HTTP 服务只能验证客户端契约，不证明后端部署和最终用户成功。

## 8. 社区路线

**Decision**: 先准备公开仓库身份与 `koreader-plugin` topic，再准备 Awesome KOReader 的一条介绍与披露作者身份的提交正文；contrib 为可选后续路径。自动索引、人工精选和商店安装兼容分别记录。

**Rationale**: 五个渠道的一手机制已由 CommunityFacts 调查。发现机制不保证收录时限或推荐等级；contrib 要求可工作的上游项目。公开前置条件未通过时只准备本地材料。

**Alternatives considered**: 同时提交多个社区或宣称已获支持不必要；基于未核验的数量宣传不符合证据要求。

**Evidence**: [plugin-index](https://github.com/omer-faruq/koreader-plugin-index/blob/main/README.md)、[Awesome 贡献要求](https://github.com/jannick-holm/awesome-koreader/blob/main/CONTRIBUTING.md)、[contrib](https://github.com/koreader/contrib/blob/main/README.md)。完整来源见 [规格阶段调查](specification-evidence.md)。

## 9. 分支与治理

**Decision**: 保持当前实际 Git 分支 `main`。`setup-plan.sh` 返回的 `BRANCH=001-open-source-magpie` 作为功能解析标识记录，不解释为已经切换分支。功能目录由 `.specify/feature.json` 定位。

**Rationale**: worker 读取 `.git/HEAD` 确认 `refs/heads/main`。constitution 仍为空模板；不编造原则、不将模板示例当作治理规定。设计阶段没有改动函数或提交代码；实施时仍须按仓库规则执行 impact，UNKNOWN 不视为安全证据。

**Alternatives considered**: 为迎合功能编号擅自创建/切换分支、伪造已批准宪章或零影响结果均不采用。

## 10. Web 配置缺口的最终结论

**Decision**: 使用官方 `magpie web --addr 0.0.0.0:3430 --no-open` 启动形式；用户自行生成并保管 `MAGPIE_WEB_KEY`，至少 16 字符且限字母、数字与 `-._~`。设备填写主机可达地址和同一 key；不填写监听通配地址。已有 daemon/web 进程存在时必须使用实际提供页面的进程的 key，不能假定新环境变量会覆盖它。常驻方式参照官方 daemon 文档，不把服务文件或含 key 的页面链接放入问题报告。

**Rationale**: RuntimeContracts 在官方公开源码中证实 `--addr`、环境变量校验、正确 key 返回 cookie 和 303、错误 key 返回 401，以及已有服务复用行为。Web key 是管理凭据，不是 Gateway key 的同义词。主程序与所需部署步骤公开可获得；运行兼容性仍需验证。

**Alternatives considered**: 猜测 `--host/--port`、从 Gateway 地址猜 Web 端口、拿独立 Office 服务替换现有协议均与已核实契约不符。

**Evidence**: 官方 commit `4869d0c9665e1a815fee3a1a4d67a575e0baab93`：[Web CLI](https://github.com/yetone/magpie/blob/4869d0c9665e1a815fee3a1a4d67a575e0baab93/internal/cli/web_cli.go#L17-L74)、[key 与登录](https://github.com/yetone/magpie/blob/4869d0c9665e1a815fee3a1a4d67a575e0baab93/internal/gui/web.go#L152-L235)、[daemon reference](https://github.com/yetone/magpie/blob/4869d0c9665e1a815fee3a1a4d67a575e0baab93/docs/reference.md#L3224-L3235)。本轮未执行这些部署命令。

## 研究关闭状态

技术选型、配置切换、后端获取与鉴权、许可策略、验证层次及社区路线均已形成决策，没有未选择的技术方案。来源代码再分发授权、测试环境准备及发布验收仍须按实施门禁取得事实证据；这些状态不能被规划文档消除或标为通过。
