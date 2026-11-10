# 信息收集依据

以下为两个只读 worker 的脱敏调查结果；静态调查不代表运行验收通过。

## 插件现状

已完成限定目录的源码静态调查。**未写入 `local://magpie-source-research.md`：当前工具仅支持读取/搜索，且分工明确要求只读，无法创建该 artifact。**以下为可直接保存的脱敏内容；未输出私人地址、配置值、密钥或设备标识。

# Magpie KOReader 插件源码调查

以下路径均相对于 `/home/blizhan/repo/github/magpie-band-bridge/`。

## 已确认的用户功能

| 功能 | 实际行为 | 源码依据 |
|---|---|---|
| 今日用量 | 今日费用、请求数、输入输出 Token、缓存命中率、解码速度；有数据时补充会话数与平均首 Token 延迟。金额按整美元展示。 | `kindle/magpie.koplugin/main.lua:1264-1308`；`projcost.lua:119-130` |
| 配额 | 最多展示六个可用账户/供应商窗口，含使用比例及重置倒计时；优先选择五小时窗口，否则选择周窗口。重复供应商/套餐可能显示邮箱域的部分文字以区分账户。 | `main.lua:249-269,1169-1220` |
| 按项目费用 | 今日用量页列出最多六个项目；趋势页最多五个。以工作目录末级名称归并项目，低额项目、未归属消费等合并为“其余”。 | `main.lua:1232-1308,1349-1410`；`projcost.lua:13-115` |
| 在飞 | “需要你 / 工作中 / 网关在飞”汇总；项目卡片与项目详情；待批准、待回答、错误、工具执行、无进展、完成、中断等状态。 | `main.lua:1310-1347`；`office.lua:157-335`；`dashview.lua:861-1006` |
| 趋势 | 今日、七日、三十日切换；费用/请求切换。多日费用按前三项目堆叠，其余为残差；今日和请求指标使用普通柱图。 | `main.lua:1349-1410,1564-1582` |
| 操作与刷新 | 三个底部标签，左右滑切换，下滑或顶部按钮刷新，关闭按钮；默认约每分钟刷新，关闭/挂起停止计时，失败保留上次数据并显示错误状态。 | `dashview.lua:103-148,172-237`；`main.lua:497-504,1428-1459,1486-1545,1598-1630` |

**状态语义限制：**源码只把“没有需处理/工作会话且最后更新时间超过闲置阈值”的项目折叠为闲置。README 将其概括为长期无动静，表述比实际条件宽泛。`office.lua:260-304`。

## 依赖与结构

- **运行宿主：**KOReader 的插件、菜单、Dispatcher、网络管理、设置存储、UIManager 和各类 UI 控件；绘制依赖 KOReader 的字体、屏幕及 blitbuffer。不是独立 Lua 应用。依据：`main.lua:22-36,358-427`；`dashview.lua:9-35`。
- **网络与解析：**LuaSocket `socket.http`、LuaSec `ssl.https`、`ltn12`、`json`；办公室/项目统计解码优先尝试 `rapidjson`，缺失时回退 `json`。依据：`main.lua:554-558,641-643,739-744`。
- **后端：**Magpie gateway 提供 usage、concurrency、quotas；Magpie web 提供项目统计与插件页面发现；在飞项目视图还要求启用 `@magpie-community/page-agent-office`。依据：`main.lua:718-736,789-811,830-845`。
- **模块连接：**`main.lua` 管理配置、鉴权、获取、缓存和页面模型 → `office.lua` 转换会话快照，`projcost.lua` 汇总项目费用 → `dashview.lua` 展示并通过回调发起刷新、切页和详情操作。`_meta.lua:1-6` 提供插件描述。

完整刷新会获取各项 gateway 数据；web 数据按当前页面选择获取。不能把“按页获取”描述为全部网络请求均按页裁剪。`main.lua:830-914`。

## 安装与使用入口

- README 的部署方式是复制/同步整个插件目录到 KOReader 的 `plugins/magpie.koplugin/`，排除本地密钥和示例文件，随后完全退出并重新进入 KOReader。没有在目标目录发现安装器或独立打包入口。依据：`kindle/README.md:57-68`；目标目录文件列表。
- 用户入口：**工具 → 更多工具 → Magpie 看板 → 打开看板**。菜单还提供刷新、三个页面入口和网关地址设置。依据：`kindle/README.md:18-25`；`main.lua:441-488`。
- 注册两个通用 Dispatcher 动作：`magpie_open`、`magpie_refresh`。依据：`main.lua:411-424`。
- README 记录了一个设备/KOReader 版本组合；这不是已验证的广泛兼容性矩阵。本调查没有部署、连接后端、运行测试或执行渲染。

## 配置类别

| 类别 | 配置与优先级 |
|---|---|
| Gateway 鉴权 | 外部 gateway 密钥文件 → 插件目录 `apikey.txt` → 已存 settings 中的 `api_key`。文件读取忽略空行与注释。 |
| Gateway 地址 | 内置默认地址、KOReader 已存地址、外部 `base_url.txt`；初始化时外部文件覆盖已存值。菜单可保存地址。 |
| Web 鉴权 | 独立外部 `web-key.txt`；登录交换 cookie，cookie 保存在内存。 |
| Web 地址 | 外部 `web_url.txt` 优先；否则从 gateway 主机部分推导 web 地址。 |
| 刷新与客户端 | settings 包含刷新秒数与 User-Agent；没有对应菜单编辑入口。 |
| 视图状态 | 页面、趋势周期/指标、项目详情属于初始化后的内存状态，未见独立持久化。 |

依据：`main.lua:48-79,329-439,506-550,626-699`。所有部署地址值已省略。

## 开源与隐私边界

1. **客户端请求行为与凭据权限不同。**已检查的传输代码使用 GET，没有发现修改 Magpie 配置的客户端请求。README 明确提醒 web key 的权限高于 gateway key，可修改服务端设置；因此不能把整个系统称为“只读凭据”。`main.lua:554-599,641-715`；`kindle/README.md:38-49`。

2. **Gateway 密钥可能进入 KOReader settings。**初始化把文件读取的密钥赋给 `settings.api_key`；保存设置时深复制整个 settings，没有删除密钥字段。因此不能宣称密钥只保存在外部文件中。`main.lua:367-369,430-438`。

3. **传输保护有限。**Gateway HTTPS 请求显式关闭证书验证；web 请求走 `socket.http`，没有与 gateway 相同的 HTTPS transport 分支。Web 登录把凭据放进查询参数；即使插件不主动记录密钥，服务端/代理是否记录该请求仍未核实。`main.lua:565-583,641-699`。

4. **会话数据在接收后才缩减。**完整 `live.js` 先下载、解码，再删除消息/query/reply等字段；这不代表敏感正文从未进入设备内存。压缩结果仍保留项目、agent、模型、标题、步骤、状态、时间与上下文统计；标题和步骤只是截短，仍可能含私人内容。`office.lua:101-153`；`main.lua:748-780`。

5. **聚合不等于匿名。**项目费用以目录末级名称归并，原始统计先进入内存；项目名仍可敏感，同名目录还会合并。配额 UI 可能包含套餐及部分邮箱域信息。Gateway 响应整体保存在缓存，没有与办公室快照同等的字段筛选。`projcost.lua:13-43`；`main.lua:1169-1220,850-899`。

6. **发布排除有限。**插件 `.gitignore` 排除了两个密钥文件名，但没有穷尽 web key、地址覆盖文件或调试快照。README 明确提醒调试 `live.js` 可含 prompt 原文，应删除。发布材料应只使用人工构造的示例、占位地址和脱敏截图。依据：`kindle/magpie.koplugin/.gitignore:1-2`；`kindle/README.md:80-84`。

7. **授权未确认。**对目标仓库递归检索 `LICENSE*`、`COPYING*` 未找到许可证文件；不能据此确认其已授予开源分发许可。依赖许可证与发布权利未做进一步审查。

## 图规则与调查限制

已读取 `gitnexus-exploring` skill，并尝试发现 `gitnexus://repos`。工具返回没有可用 MCP resource；目标仓库也未检索到 `.gitnexus` 文件。因此**没有绑定任何图索引，索引新鲜度未知，未取得图调用链证据**。上述架构关系来自源码直接引用及调用，不能标注为图验证结果。

调查仅覆盖本地静态源码及相邻 README；未读取真实密钥文件、私人运行配置或真实会话快照，未连接服务、构建、运行测试、发布或修改文件。后端权限执行、日志留存、实际安装兼容性及真实网络行为均未验证。

## 社区渠道

Research completed against the five repositories’ own documentation and source. No submissions, publishing, messages, builds, or tests were performed. **I could not write `local://magpie-community-research.md`: this worker has only read/search tools and an explicit read-only assignment.** The complete cited artifact content follows for the parent agent to save.

```markdown
# Magpie community entry research

Research date: 2026-11-10. Scope: actionable preparation for community discovery, distribution, and a possible listing request. No external submissions were made. Inclusion and acceptance are not promised.

## Recommendation

Prepare one canonical public Magpie repository with an English README, clear installation and compatibility instructions, an installable `magpie.koplugin` package, and consistent plugin metadata. Prepare the `koreader-plugin` topic for the eventual public repository. Prepare one concise Awesome KOReader entry and a submission description disclosing authorship.

Treat public hosting, adding topics, releasing artifacts, and opening upstream submissions as future actions outside this research. Make completion of the community preparation package the specification’s acceptance criterion; do not require third-party indexing, ranking, or acceptance.

Use automatic GitHub discovery as the initial distribution route. Make Awesome KOReader the first bounded human-reviewed listing route. Keep `koreader/contrib` as an optional later route because it requires a submodule contribution and a working upstream project. There is no evidence here that separate AppStore or Storefront listing PRs are required.

This recommendation is an inference from the documented mechanisms below, not a statement of upstream approval.

## Findings by destination

| Destination | What it provides | Confirmed entry mechanism and preparation |
| --- | --- | --- |
| koreader-plugin-index | Searchable index, extracted descriptions, categories, and quality tiers. | Its discovery queries search `topic:koreader-plugin` and `.koplugin` in repository names. Fork queries require at least one star. Its README welcomes curation PRs and provides `[discovery].extra_plugins` for repositories those searches cannot find. An ordinary well-named/tagged Magpie repository should not need a manual discovery seed. Discovery does not guarantee a recommended tier. [1][2] |
| awesome-koreader | Human-curated directory linking to canonical projects. | Preferred route is a PR editing README on `main`, in the appropriate category and alphabetical order where possible, with the PR template completed. An “Add Resource” issue is an alternative. Public accessibility, README description and installation instructions, recent KOReader compatibility or a stated compatible version, canonical source link, and authorship disclosure are explicit requirements. [4] |
| koreader/contrib | KOReader-organization collection of non-official plugins. | Each application should be a Git submodule pointing upstream. Developers must ensure it works when merging; work in progress and deprecated features are expressly excluded. README/README.md must explain functionality; device-specific applications need compatibility information in README or COMPATIBILITY. This is a source collection route rather than merely a directory link. [5][6] |
| appstore.koplugin | On-device discovery, installation, updates, removal, and README viewing. | README documents GitHub-topic/name discovery, manual install by GitHub owner/repo, repository ZIP download, metadata validation, release assets, and source download fallback. `_meta.lua` must be locatable in the archive for the inspected installer path. No author submission form or mandatory catalog PR was identified in the inspected documentation. [7][8] |
| storefront.koplugin | On-device catalog and installation, including releases and branches. | Catalog builder searches `topic:koreader-plugin` and `.koplugin` in repository names, and excludes zero-star forks. README and management wiki document release/version installation and branch tracking. No author submission form or mandatory catalog PR was identified in inspected documentation and discovery code. Its checked catalog deployment workflow is triggered by pushes to `main` or manual dispatch; do not promise a nightly catalog pickup. [9][10][11][12] |

### Index discoverability and ranking are separate

The index README explicitly says curation is merged over extracted data and never overwritten by regeneration. Manual additions go in `curation.toml`; missing discovery seeds use `[discovery].extra_plugins`. The index also seeds discovery from contrib. [1][2]

The source checks for plugin files at the repository root or one directory below. Markers include loadable files or a directory ending in `.koplugin`. Its automatic quality calculation demotes missing plugin markers, zero-star forks, archived projects, dormant projects without its “settled” exception, and READMEs shorter than 300 bytes. Otherwise the automatic result is tier B; a curated tier can override it. These are implementation heuristics, not evidence of functional testing or a submission checklist to game. [2][3]

An English README is useful for Magpie: the index extracts searchable descriptions from documentation, and AppStore fetches an exact `README.md` on the repository’s HEAD. Do not depend solely on localized filenames or images to explain installation and purpose. [1][7][8]

### Awesome KOReader submission details

The required entry format is:

    - [project-name](https://github.com/author/repo) - One-sentence description.

The description should begin with a capital letter and end with a period. Star counts are optional and can be omitted. Use the most specific existing category; a new category ordinarily needs at least three entries. Self-promotion is welcome when authorship is disclosed. Incomplete undocumented projects, forks without meaningful changes, and abandoned known-broken projects are excluded. [4]

For the Magpie specification, prepare:
- The verified canonical repository URL.
- One sentence describing confirmed user-facing functionality.
- One appropriate existing category.
- A PR description disclosing that the submitter is the author/maintainer.
- Links to installation instructions and the recorded compatible KOReader version.

Do not invent a Magpie description or choose a category before its actual functionality is confirmed. Do not include unverified stars, user counts, device coverage, or claims of adoption.

### Contrib requirements and limits

The contrib README warns that these plugins are outside KOReader’s maintained core logic and may stop working after KOReader updates. Users are asked to report issues upstream. Inclusion under the KOReader organization therefore must not be described as bundled availability, compatibility certification, or ongoing maintenance by KOReader. [5]

The repository metadata labels contrib AGPL-3.0. That label alone does not establish a blanket relicensing requirement for every linked upstream plugin. The inspected developer instructions do not state such a requirement; resolve any actual proposed contribution against its terms before submitting. [5][6]

### Distribution preparation

Keep two concepts distinct: the installed plugin directory and the upstream repository/archive layout. AppStore supports repository ZIPs and release assets; Storefront supports nested roots and targeted installation from archives containing multiple plugin directories. A single unambiguous `magpie.koplugin` folder in the prepared release ZIP is a conservative compatibility choice, not a universal upstream listing rule. [7][8][9][10]

Prepare:
- Runtime files under one installable `magpie.koplugin` root, including `main.lua` and `_meta.lua`.
- Metadata with a stable plugin identity and an explicit version consistent with the intended release tag. AppStore’s inspected archive code extracts literal `name` and `version` fields from `_meta.lua`; keep these easy to read. [8]
- Installation instructions covering the correct plugin directory and KOReader restart.
- Explicit supported/tested KOReader versions and device limitations, based on actual recorded evidence.
- A public README containing purpose, installation, configuration prerequisites, limitations, and support/reporting instructions.
- An intended source/tag and package identity so manual installation and future store-managed installation can refer to the same upstream project.

A GitHub Release is useful for a bounded, versioned installation but is not a discovery prerequisite established by these sources. AppStore documents direct repository download when release assets are absent, and Storefront documents branch installation. [7][10]

This research did not inspect a finished Magpie package, exercise either installer, or establish any Magpie compatibility result. Packaging and compatibility remain preparation requirements rather than completed verification.

## Counts and freshness

No ecosystem/plugin count was independently verified. The index README currently presents different kinds of numbers in different sections: a generated status block, older explanatory examples, and historical first-run figures. Store catalog sizes, GitHub repository search counts, individual patch-file counts, stars, and README snapshots are not interchangeable.

Do not use supplied or displayed counts as a product requirement or popularity claim. If a later document needs a number, collect the dated generated dataset, identify the unit and filtering rules, deduplicate it, and report that method. No recount was necessary for the bounded community entry recommendation. [1][2][9]

Index scheduling is documented as nightly differences and a monthly full rebuild, with best-effort GitHub scheduling. AppStore documents cache refresh behavior, including incremental refreshes and limitations around renames/topic-only changes and star updates. Storefront’s inspected deployment workflow has push/manual triggers. None establishes a guaranteed inclusion deadline. [1][7][11]

## Bounded specification acceptance criteria

The community preparation task is complete when:

1. Canonical repository identity, public description, intended `koreader-plugin` topic, and support contact mechanism are documented.
2. README has a concise English introduction, installation instructions, compatible KOReader version information, and known device limitations.
3. A release/package plan names the single installed `magpie.koplugin` directory, required runtime files, metadata identity/version, and intended upstream tag.
4. Compatibility claims reference actual evidence, or are explicitly left unclaimed pending testing.
5. One Awesome KOReader entry and authorship-disclosing submission description are prepared locally.
6. The record distinguishes automatic discovery, human curation, and actual installer compatibility.
7. No acceptance criterion requires third-party approval, a particular quality tier, a count/rank, or a catalog refresh deadline.

Deferred optional route: prepare a contrib submodule contribution only after Magpie is working and documented. A missing index entry can later justify a narrowly scoped discovery-seed proposal if it is not reachable by supported discovery queries. Neither action is part of this research, and no external submission is authorized here.

## Sources

[1] Plugin index README, discovery, curation, scheduling, and reported counts:
https://github.com/omer-faruq/koreader-plugin-index/blob/main/README.md

[2] Plugin index discovery queries and marker/seed handling, especially lines 45–77, 342–389, and 729–779:
https://github.com/omer-faruq/koreader-plugin-index/blob/main/scripts/build.py

[3] Plugin index automatic tier thresholds and calculation, lines 669–803:
https://github.com/omer-faruq/koreader-plugin-index/blob/main/scripts/extract.py

[4] Awesome KOReader contribution requirements and entry format:
https://github.com/jannick-holm/awesome-koreader/blob/main/CONTRIBUTING.md

[5] Contrib developer requirements and maintenance warning:
https://github.com/koreader/contrib/blob/main/README.md

[6] Contrib repository metadata and source tree:
https://api.github.com/repos/koreader/contrib
https://github.com/koreader/contrib/blob/main/.gitmodules

[7] AppStore README, discovery, installation, direct download, releases, forks, refresh behavior:
https://github.com/omer-faruq/appstore.koplugin/blob/main/README.md

[8] AppStore implementation: archive metadata detection and README fetching:
https://github.com/omer-faruq/appstore.koplugin/blob/main/main.lua#L9164-L9189
https://github.com/omer-faruq/appstore.koplugin/blob/main/appstore_repo_content.lua#L31-L33

[9] Storefront catalog discovery queries and zero-star fork exclusion:
https://github.com/ultimatejimmy/storefront.koplugin/blob/main/tools/build_catalog.py#L25-L28
https://github.com/ultimatejimmy/storefront.koplugin/blob/main/tools/build_catalog.py#L247-L258

[10] Storefront capabilities and management, including nested archives and version/branch tracking:
https://github.com/ultimatejimmy/storefront.koplugin/blob/main/README.md
https://github.com/ultimatejimmy/storefront.koplugin/wiki/3.-Management

[11] Storefront catalog deployment workflow:
https://github.com/ultimatejimmy/storefront.koplugin/blob/main/.github/workflows/build-catalog.yml

[12] Storefront live GitHub search implementation:
https://github.com/ultimatejimmy/storefront.koplugin/blob/main/storefront.koplugin/storefront_net_github.lua#L254-L268

## Method and limits

Used read-only direct access to GitHub repository pages, raw project-owned documentation, GitHub repository/tree metadata, and targeted source searches. No web search queries were used; OpenCLI and background-worker tools were unavailable in this worker. An initial contrib `master` tree lookup returned 404; repository metadata established `main`, whose tree and README were subsequently read. All five requested repositories were reachable. No external submissions or runtime verification occurred.
```
