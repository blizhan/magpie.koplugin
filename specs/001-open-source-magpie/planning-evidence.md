# Planning worker evidence

2026-11-10。只读、脱敏调查；不是运行验证记录。

## RuntimeContracts

> `RuntimeContracts` is running a newer turn. The output below is from its PREVIOUS run (published 1m ago), not the current one. Live progress: `history://RuntimeContracts`; its next result auto-delivers to its owner.现有契约已明确；**Agent Office 有本地安装包及公开仓库坐标证据，Magpie 主程序的公开安装/自托管完整步骤仍未由本次本地资料确认**。未读取真实 key、运行配置或会话文件，未运行程序、测试或网络请求。

以下 `P` 表示源目录 `kindle/magpie.koplugin/`；`D` 表示 KOReader data directory。路径相对化基于 README 所记的 Kindle 布局，**外部文件目前仍是源码硬编码绝对路径，并非动态相对于 D 定位**。

| 配置 | 相对 D 的现有位置 / 字段 | 优先级与行为 | 证据 |
|---|---|---|---|
| 持久化设置 | 默认布局为 `settings/magpie.lua`；实际使用 `DataStorage:getSettingsDir() .. "/magpie.lua"`，顶层 `settings` 表 | 字段：`api_key`、`base_url`、`user_agent`、`auto_refresh_sec`。默认刷新 60 秒。文件取得的 gateway key 会写进 `self.settings.api_key`，flush 时整个 settings 被持久化 | `P/main.lua:48-58,358-374,430-438` |
| Gateway key | `../magpie-band/gateway-key.txt` → `plugins/magpie.koplugin/apikey.txt` → `settings.api_key` | 首个可用值胜出；每次 gateway 请求重新解析。文本文件读取首个非空、非 `#` 注释行 | `P/main.lua:66-79,329-344,546-551` |
| Gateway URL | `../magpie-band/base_url.txt`；否则 `settings.base_url`；否则内置默认 | 初始化时外部文件覆盖已存 URL；菜单修改 settings，但重启又会被外部文件覆盖。去除结尾 `/`。真实默认地址省略 | `P/main.lua:346-352,358-374,506-539` |
| Web key | `../magpie-band/web-key.txt`，内容对应 `MAGPIE_WEB_KEY` | 无 settings 或插件目录 fallback。只允许字母、数字、`-._~`；登录 cookie 只保存在内存 | `P/main.lua:626-628,669-697` |
| Web URL | `../magpie-band/web_url.txt` | 每次取外部文件；无文件则从 gateway URL 提取 scheme/host，再接 `:3430`。该推导不保留原端口/路径，不能据此声称通用 IPv6/反向代理兼容 | `P/main.lua:630-637` |

| 数据契约 | 方法、鉴权 | 实际消费的最小结构 / 错误语义 | 证据 |
|---|---|---|---|
| Gateway 今日用量、趋势 | `GET /v1/magpie/usage?period=today\|7d\|30d`；`Authorization: Bearer <key>` | 展示字段：`cost,calls,input,output,cache_read`；速度用 `decode_out,decode_ms`；附加信息用 `sessionCount,ttft_ms,timed`。趋势用 `series[].{label,time,cost,calls}`。解析门槛仅为 JSON table，缺字段多显示 0 或 `—`，并非严格 schema 校验 | `P/main.lua:107-143,554-599,830-839,1264-1308,1349-1385` |
| Gateway 并发 | `GET /v1/magpie/concurrency`；同上 | 当前看板只需 `{requests,waiting,tools}`。旧文本构建器还消费 `active[]`，但当前项目卡片来自 office 数据 | `P/main.lua:1310-1347`；文本消费见 `1097-1166` |
| Gateway 配额 | `GET /v1/magpie/quotas?kept=1`；失败再 `GET /v1/magpie/quotas/cards`；同上 | `{data:[{name或provider,plan?,last?,user?,windows:[{name或pool,used或remaining,resetsAt}]}]}`。窗口优先 5h，再周窗口，再首个；`used` 缺失时按 `100-remaining`。无 `data` 或窗口为空显示“无配额数据/无可用窗口”；失败保留旧值 | `P/main.lua:249-269,840-845,893-899,1169-1220` |
| Web 登录 / 会话 | `GET /?k=<web-key>`；随后 `Cookie` | 登录只要求响应 `set-cookie` 字符串可匹配 `magpie_web_[%w_]*=<value>`，没有要求固定成功状态码；关闭自动跳转。后续 401 重新登录并重试一次。响应 `Date` 可用于办公室时间校正 | `P/main.lua:641-715` |
| Web 项目费用 | `GET /api/sessions/stats?days=1\|7\|30`；上述 cookie | `{days:[{date:"YYYY-MM-DD",usage:[{cwd,cost}]}]}`；`days` 必须为 table，否则解析失败；项目按 `cwd` 最后一级合并，无 cwd 的费用计入未归属。`agent/model` 不需要 | `P/main.lua:789-818`；`P/projcost.lua:13-43` |
| Office 页面发现 | `GET /api/plugin-pages`；上述 cookie | 顶层数组，元素满足 `name=="@magpie-community/page-agent-office"` **或** `key=="plugin-agent-office"`，且 `url` 为字符串；取 URL 所在目录拼接 `live.js`。未找到匹配项报告插件未开启 | `P/main.lua:718-736` |
| Office 数据 | `GET <发现的目录>/live.js`；上述 cookie | JS 包装或裸 JSON 均可：截取首 `{` 到末 `}`；必须 `{sessions:[...]}`。有效项目状态最小字段为 `sessions[].{project或cwd,phase,updated,touched}`；gateway 推断状态用 `inflight,last.{outcome,at}`；详情可选 `agent,model,title,step,turns,context,contextWindow,subagent,source`。时间按 epoch 毫秒使用。404 清除发现路径并重新发现一次 | `P/main.lua:748-780`；`P/office.lua:101-180` |

通用 gateway 错误为 `missing_key`、`network`、`http_<status>`、`bad_json`，只接受 HTTP 200；缺 key 在发请求前返回。Web 缺 key、格式错误、登录无匹配 cookie、非 200 数据响应、解析失败均有独立 UI 错误。完整刷新仍拉全部 gateway 项；web 只取当前页所需 stats 或 office。失败保留上次成功数据，首次失败显示空值/错误，而不是成功的示例数据。依据：`P/main.lua:554-599,669-715,748-914,1264-1347`。

| 依赖 / 基线 | 确定证据与可获得性边界 |
|---|---|
| KOReader / Lua | `kindle/README.md:5-16` 记录 KOReader **2026.07.1** 和一个 Kindle Basic 7th gen 部署；`kindle/probe-2026-11-03.md:54-65` 记录系统 Lua **5.1.4**、KOReader socket/SSL/JSON；`kindle/README.md:78-84` 明确工具用 KOReader 自带 **luajit**。系统 Lua 版本不能充当 KOReader LuaJIT 精确版本证据，也没有最低 KOReader 版本矩阵。 |
| 客户端运行库 | 主程序 require KOReader 设置、菜单、UI、网络模块；网络使用 `socket.http`、`ssl.https`、`ltn12`、`json`。Web 大响应优先 `rapidjson`、缺失回退 `json`。UI 依赖 `ffi/blitbuffer` 等 KOReader 控件。依据 `P/main.lua:22-36,554-558,739-744`；`P/dashview.lua:9-35`。 |
| Agent Office 已安装包 | 本地插件 manifest 明确依赖 `@magpie-community/page-agent-office` 的 **0.3.4 本地 tgz**；同时找到解包后的 `package.json`、README 和 tgz 文件。证据：本地插件管理目录 `plugins/package.json:1-14`、`plugins/node_modules/@magpie-community/page-agent-office/package.json:1-3`。这是安装材料存在证据，不是当前 npm 可下载验证。 |
| Agent Office 公开坐标与安装说明 | 包元数据指向 [`magpie-community/plugins`, `packages/agent-office`](https://github.com/magpie-community/plugins/tree/main/packages/agent-office)，要求 **Magpie ≥0.1.1318**；README 给出 `magpie plugin add @magpie-community/page-agent-office`，并引用独立公开项目 [`QingJ01/magpie-agent-office`](https://github.com/QingJ01/magpie-agent-office)。依据上述 package metadata `:39-52`、README `:1-35`。README 的独立服务使用不同 token/路径契约，不能直接替换现客户端的 Magpie web 登录和页面发现。 |
| Magpie 主程序 / gateway / web | Office README 链接公开产品站点 [usemagpie.ai](https://usemagpie.ai)，本地桌面 launcher 表明存在主程序二进制。目标仓库及相邻文档未提供主程序 package manifest、gateway/web 的完整公开自托管步骤或源仓库坐标；已对 README/设计文档及包元数据路径换策略搜索。**不能据现有证据承诺新用户可独立复现完整后端，也不能断言其不存在。** |

最小兼容迁移建议 **[INFERENCE]**：保留现有五个 Lua 文件及全部接口契约，用 `DataStorage` 派生可移植配置路径，保留现有四个外部文件名、`apikey.txt` 和 settings 字段/优先级；文档明确旧 Kindle 外部位置与新路径的对应关系。移除真实内置地址后，缺 URL 与缺 key 均应明确呈现配置缺失，并允许打开看板完成配置；现状只处理缺 key，缺 URL 会回落到内置地址。无需新增后端；web 配置缺失时继续保留 gateway 展示。若选择改变优先级或取消 settings 存 key，属于另外的显式迁移决定，不能描述为原样兼容。

图工具不可用：尝试发现 GitNexus 资源返回无 MCP resources，因此没有绑定图索引，索引新鲜度未知；以上是直接源码证据。未将许可未知、后端公开安装未确认或设备兼容性未验证视为通过。

## ReleaseValidation

调查结论：目的仓库已有 MIT 许可证，但尚无插件运行源码、测试或打包入口；来源仓库有完整的五文件插件和设备侧调试脚本，**未找到来源代码许可证或可确认后端公开可获取性的证据**。当前不能把已有 MIT 文件当成迁入来源代码、后端或参考资料的授权证明。

本次仅阅读和搜索，没有修改文件、运行测试、构建、格式化、连接私人后端或读取 git 历史、remote、真实配置及密钥。

**实际分支与工具限制**

- 目的仓库 `.git/HEAD:1` 为 `ref: refs/heads/main`，因此文件层面的当前分支证据是 **`main`**，与 `setup-plan` 输出的分支名不同。
- 本 worker 只有 read、glob、grep、web_search，无命令执行工具，**无法执行要求的 `git branch --show-current`，也无法执行 version / `command -v` 检查**。没有切换分支。
- 已读取 `gitnexus-exploring` 和 `research` skill。GitNexus resource 发现返回无可用 MCP resource；目的仓库 `AGENTS.md:1-4` 自述索引为零 symbols/relationships/flows。没有取得可用图证据或新鲜度结论。以下关系来自直接源码引用。

| 工具类别 | 本地文件定位结果 | 能支持的结论 |
|---|---|---|
| Git | 找到 `/usr/bin/git` | 存在文件；版本和可执行性未检查 |
| 归档 | 找到 `/usr/bin/zip`、`/usr/bin/unzip`、`/usr/bin/tar`，`/bin` 下亦有对应条目 | 有可供主代理后续做 harmless version/path 检查的候选 |
| Lua / LuaJIT | `/usr/bin`、`/usr/local/bin`、`/bin`、用户 `.local/bin` 中定向 glob 未找到匹配项 | 无法确认本机已安装；不等于全系统不存在 |
| KOReader | 标准 bin 位置及仓库位置查询未找到匹配项；来源设备部署目录也不能作为本机运行时证据 | 未确认有本地 KOReader runtime；来源 README 中的设备路径不能算本机运行时 |
| Secret scanners | 同上位置未找到 `gitleaks`、`trufflehog`、`detect-secrets`，另检查了用户 `.cargo/bin` 中前两项 | 未确认 scanner 可用；未运行扫描 |
| 其他归档工具 | 未找到定向查询的 `7z*`、`bsdtar` | 未确认可用 |

主代理仍需用执行工具完成准确分支与工具版本检查。以上是文件存在性调查，不是已经完成的 CLI 检查。

**现有开发、测试和打包约定**

以下来源路径相对于 `/home/blizhan/repo/github/magpie-band-bridge/`。

| 文件 / 范围 | 发现及用途 |
|---|---|
| `kindle/README.md:18-25,53-64` | 用户从 KOReader 工具菜单打开插件；部署方式是同步整个插件目录，排除 `apikey.txt` 和 `*.example`，然后完全退出再进入 KOReader |
| `kindle/README.md:73-75` | 调试约定是在设备的 KOReader 目录使用捆绑 LuaJIT，脚本置于临时目录 |
| `kindle/tools/t_office.lua:1-27` | 从本地 `live.js` 解码并打印分组、项目、会话及状态；依赖 JSON decoder，主要是诊断输出，没有预期结果断言 |
| `kindle/tools/t_render.lua:1-63` | 真 KOReader 控件、Blitbuffer 和字体，stub Device/UIManager，600×800 离屏 PNG；即使选择用量 `U`，前面仍先读取 `live.js` |
| `kindle/tools/t_pages.lua:1-76` | 真 `main.lua` 拉取数据、构建模型并渲染各页；有私人部署耦合，属于在线集成/渲染脚本 |
| `kindle/tools/t_web.lua:1-35` | 真 web 登录、页面发现、过期路径、cookie 重新登录、错误/缺失 key；会访问配置后端，不能作为默认离线 smoke |
| `kindle/magpie.koplugin/.gitignore:1-2` | 只列出两个密钥文件名，不能作为全面发布过滤器 |
| 目的仓库根目录与文件 glob | 有 LICENSE、规格文档和规划脚本；未发现插件运行文件、测试框架或发布流水线 |
| 来源仓库完整非 git 文件清单与定向 glob | 未发现 Makefile、rockspec、package manifest、CI workflow、测试框架配置或发布/打包脚本 |

现有 `t_*.lua` 是设备侧人工诊断和渲染惯例，不能描述为已建立的自动化回归测试套件。来源 `kindle/AGENTS.md` 是 TRMNL 通用指导，不包含本 Lua 插件的独立 package/test 约定。

**可安装 artifact 的最小真实源码集合**

```text
magpie.koplugin/
  _meta.lua
  main.lua
  dashview.lua
  office.lua
  projcost.lua
```

- `main.lua:22-36` 直接引用 `dashview`、`office`、`projcost` 及 KOReader 模块。
- `dashview.lua:9-35` 引用 KOReader 控件、字体、设备及 FFI Blitbuffer；插件不是独立 Lua 程序。
- `office.lua:1-35` 与 `projcost.lua:1-40` 为纯 Lua 数据转换，不需要另附第三方源码文件。
- 来源插件目录中未发现额外运行资产或二进制依赖文件。
- `_meta.lua:1-6` 具有 `name`、`fullname`、`description`，**没有 `version` 字段**。`main.lua:51` 的 User-Agent 带有版本字符串，不能据此认定已有发布版本/tag。
- 后续发布包还应携带已确认适用于这些文件的许可证和公开安装说明；私人配置、密钥、真实 `live.js`、诊断输出及来源截图不应随包直接迁入。

建议采用显式五文件 allowlist，加入经确认的 LICENSE/README 后形成单一 `magpie.koplugin/` 根目录 ZIP。该布局是结合已有社区调查形成的打包建议，尚未进行商店安装验证。

**依赖、后端及兼容性证据**

调用链为 `main.lua` 获取和缓存数据 → `office.lua` / `projcost.lua` 转换模型 → `dashview.lua` 展示。宿主提供 KOReader UI、LuaJIT/FFI、字体、设置和网络模块；HTTP/HTTPS/JSON 依赖是 `socket.http`、`ssl.https`、`ltn12`、`json`，部分解码优先使用 `rapidjson`。这些不是当前五文件包内捆绑的依赖。

后端的实际接口证据：

- `main.lua:830-845`：gateway usage、concurrency、quotas 及 quotas/cards fallback。
- `main.lua:718-736`：web `/api/plugin-pages`，查找 `@magpie-community/page-agent-office` 并发现其 `live.js`。
- `main.lua:789-811`：web `/api/sessions/stats?days=…`。
- `office.lua:5-7`：明确记录上述页面插件名称和快照格式。

安全本地文档未提供 Magpie gateway/web 的规范公共源码地址、版本、许可证或可供用户重现安装的公共发行入口。没有根据项目名称猜测其他公开仓库。

仅对源码已记录的准确 npm package 名做了第一方 registry 检查：

- `https://registry.npmjs.org/@magpie-community%2fpage-agent-office/latest`
- `https://registry.npmjs.org/@magpie-community%2Fpage-agent-office`

两者均返回 HTTP 404。**这只能说明本次 registry 查询未取得公开元数据**，不能证明该组件不存在、永远不可用或没有许可证，也不能据此推断 gateway/web 的公开性。

兼容性只能作如下有限表述：

| 已有证据 | 允许的表述 | 不足之处 |
|---|---|---|
| `kindle/README.md:3-10` 记录 Kindle Basic 7th gen、600×800、KOReader `2026.07.1` | “来源文档记录的部署组合” | 本次未运行；不能扩展为最低版本或全设备支持 |
| `kindle/design-concurrency/README.md:118-122` | 文档报告已部署，并用真 KOReader 控件做离屏渲染 | 部分截图状态人为构造；不是全交互验收 |
| `kindle/design-project-cost/README.md:43-52` | 文档报告用真 main.lua 拉取数据并渲染用量、错误态及趋势页 | 无新的运行记录、可重现 fixture 或 assertion 结果 |
| `_meta.lua:1-6` | 没有兼容版本声明 | 不能从缺失字段推导兼容范围 |

**可靠的后续 smoke 策略**

以下是待执行的验收设计，本次没有运行：

1. **离线模型层**：使用人工构造的数据表和固定时间直接调用 `Office.compact/build`、`ProjCost.compact` 及相关汇总方法；断言需要处理/工作/完成/闲置边界、缺字段、项目聚合和“其余”计算。现有 `t_office.lua` 的真实快照输入和打印输出不足以承担这一层。
2. **真实 KOReader runtime 离屏层**：保留 `t_render.lua` 的实际控件/字体/Blitbuffer 方法，在隔离目录使用合成快照，覆盖三页、错误/旧数据、项目详情和趋势。应先移除对真实快照和部署目录的默认依赖。PNG 能证明构建与绘制完成；计时器、触摸、网络与休眠仍需单独验证。
3. **本地受控 HTTP 集成层**：在明确配置的回环 fixture 服务上覆盖 gateway、web 登录、cookie 重登录、页面发现、404 重新发现及 stats。现有 `t_web.lua` / `t_pages.lua` 必须解除私人部署耦合后才适合作为此层入口。
4. **目标设备人工验收**：在记录的 KOReader/device 组合上验证从干净 ZIP 安装、菜单和 Dispatcher、刷新/切页、网络失败、关闭/挂起恢复及完全重启。离屏 stub 不能代替这些检查。
5. **包验收**：查看归档成员和根目录结构，确认五个运行文件、公开文档和许可证齐全；扫描实际发布目录/ZIP 的内容与文件名。选择源码迁移和干净发布策略后，再确定需要检查的 Git 对象范围，避免默认导入来源历史。

**许可证与发布 gates**

| Gate | 现状与明确下一步 |
|---|---|
| 来源授权 | 目的 `LICENSE:1-21` 是 MIT，声明单一版权持有人。来源递归 `LICENSE*`/`COPYING*`、大小写扩展名称与源码 license/SPDX/copyright 搜索均未找到授权。需要权利人确认五个文件的版权来源和授权，以及是否含第三方衍生代码；不要用目录目标许可证自动补齐这一缺口 |
| 作者类别 | 目前只有目的许可证中的单一版权声明；没有足够证据断言来源为唯一作者、所有贡献均获授权，或 `office.lua` 所称“状态映射 follows model.js”涉及何种可版权内容 |
| 后端获取与许可 | 需要维护者提供规范公共 upstream/发行入口、license 和支持版本；若依赖不可公开获取，应清楚披露，并避免宣称公众可独立复现完整功能 |
| 依赖许可 | 区分宿主提供与发布包实际捆绑的依赖，记录适用许可证和 notice。不要把 KOReader 或社区仓库的许可证标签自动当作本插件授权要求或已解决的许可结论 |
| 清理与隐私 | 原说明、调试脚本、截图含部署耦合或真实数据风险；迁移前需人工合成 fixture、公开安装文档、完整排除规则及实际 scanner 检查 |
| 版本与支持范围 | 确定发布版本/tag、metadata 版本和准确测试组合；当前仅有文档记录组合，没有已确认的广泛支持范围 |
| 安装与运行 | 五文件集合已静态确认；仍需从最终 ZIP 做干净安装及上述 smoke，才可声称 artifact 可安装且工作 |
| 工具与分支 | 主代理执行 `git branch --show-current` 和 harmless path/version 检查；本 worker 已提供 `main` 的 HEAD 证据及候选工具路径 |
| 社区提交 | 既有 `specs/001-open-source-magpie/research.md:137-149` 支持单一安装目录、明确版本和兼容信息的准备方向；不必重复社区调研。公开可用性、许可、可安装包和可信兼容说明应先解决 |

主要剩余阻碍是**来源授权未确认、后端公共获取/许可未知，以及最终包和目标 runtime 尚未运行验收**，并非五个运行源码文件定位不清。


## 官方 Web 配置补充

公开源码可访问，web 缺口已补齐。证据固定于官方仓库 commit [`4869d0c9665e1a815fee3a1a4d67a575e0baab93`](https://github.com/yetone/magpie/tree/4869d0c9665e1a815fee3a1a4d67a575e0baab93)，文件先由 GitHub tree API 定位，未猜路径。

可写入安装文档的启动形式如下；这是供用户部署时执行的公开命令，本轮未执行：

```sh
# 在运行 Magpie 的主机上生成并固定本人的 web key。
export MAGPIE_WEB_KEY="$(openssl rand -hex 16)"
magpie web --addr 0.0.0.0:3430 --no-open
```

| 契约 | 已确认行为与证据 |
|---|---|
| 参数 | 使用 **`--addr host:port`**，没有 `--host` / `--port`；也支持 `--addr=host:port`。默认 `127.0.0.1:3430`；`--lan` 将默认监听改为 `0.0.0.0:3430`；`--no-open` 禁止自动开浏览器。[`internal/cli/web_cli.go:17-51`](https://github.com/yetone/magpie/blob/4869d0c9665e1a815fee3a1a4d67a575e0baab93/internal/cli/web_cli.go#L17-L51) |
| web key 来源 | 设置 `MAGPIE_WEB_KEY` 时使用该值；不设则每次启动产生新 key。固定 key **至少 16 字符**，只允许字母、数字及 `-._~`；源码直接推荐 `openssl rand -hex 16`。[`internal/gui/web.go:152-198`](https://github.com/yetone/magpie/blob/4869d0c9665e1a815fee3a1a4d67a575e0baab93/internal/gui/web.go#L152-L198) |
| 获得设备用 URL | 启动输出页面链接，并在监听非 loopback 地址时输出 network links。KOReader 的 `web_url.txt` 填用户主机可达的 `http://<主机局域网地址>:3430`，**不要填 `0.0.0.0`**；`web-key.txt` 填此次主机使用的同一个 `MAGPIE_WEB_KEY`。[`internal/cli/web_cli.go:126-155`](https://github.com/yetone/magpie/blob/4869d0c9665e1a815fee3a1a4d67a575e0baab93/internal/cli/web_cli.go#L126-L155) |
| `/?k=` 登录 | 查询参数含 `k` 时校验 key；错误返回 **401**。正确时设置 `Set-Cookie` 并 **303** 跳转到移除 `k` 的 URL。cookie 名是 **`magpie_web_<port>`**，Path `/`、HttpOnly、SameSite=Lax。后续请求接受该 cookie。这与现有 Lua“不跟随跳转，直接取 Set-Cookie”的实现相容。[`internal/gui/web.go:206-235`](https://github.com/yetone/magpie/blob/4869d0c9665e1a815fee3a1a4d67a575e0baab93/internal/gui/web.go#L206-L235)、[`web.go:351-353`](https://github.com/yetone/magpie/blob/4869d0c9665e1a815fee3a1a4d67a575e0baab93/internal/gui/web.go#L351-L353) |
| 已有服务的例外 | 若 daemon 已提供 web 页面，`magpie web` 会打印已有服务页面链接并退出；若应用已在目标端口提供页面，也会复用其链接。因此上述环境变量不保证覆盖已经运行的服务 key；设备应使用**实际提供页面的进程**的 key。[`internal/cli/web_cli.go:52-74`](https://github.com/yetone/magpie/blob/4869d0c9665e1a815fee3a1a4d67a575e0baab93/internal/cli/web_cli.go#L52-L74) |
| 常驻部署 | 官方 reference 记载 `magpie daemon install --web` / `magpie daemon web on`；`--lan` 提供 `0.0.0.0:3430`，`--addr host:port` 指定监听。服务自行生成 key 并作为 `MAGPIE_WEB_KEY` 保存在用户可读的 service 文件，`magpie daemon status` 输出链接。[`docs/reference.md:3224-3235`](https://github.com/yetone/magpie/blob/4869d0c9665e1a815fee3a1a4d67a575e0baab93/docs/reference.md#L3224-L3235) |

一个需要保留的实际限制：web key 是**管理凭据**，官方启动代码明确提示持有链接者可以更改 Magpie 并查看 key；它与 gateway key 权限不同。[`internal/cli/web_cli.go:158-164`](https://github.com/yetone/magpie/blob/4869d0c9665e1a815fee3a1a4d67a575e0baab93/internal/cli/web_cli.go#L158-L164)。当前 KOReader web 传输只使用 `socket.http`，所以公开源码支持 TLS 不等于现客户端已经支持该启动模式的 HTTPS 连接。

现在可确认“公开可获得且存在明确配置步骤”；仍需把主机网络可达性、安装版本及 KOReader 端联通验证作为部署验收，不能用静态源码相容推断替代运行通过。
