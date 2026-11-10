# 社区渠道准备

原始渠道调查日期：2026-11-10。当时只读取公开页面、公开源码片段和 GitHub API，没有打开 pull request、issue 或发送对外消息，也没有通过 KOReader、AppStore 或 Storefront 安装本插件。后续用户提供的实机使用确认已在下文单独补入。

社区渠道状态仍为 **materials-ready**：条目、提交正文和渠道条件已写成可审阅文本，尚无对方接受、目录收录或商店安装结果。用户自用阅读器的实机使用另有验收记录。

## 仓库身份

`git -C /home/blizhan/repo/github/magpie.koplugin remote get-url origin` 的结果是 `git@github.com:blizhan/magpie.koplugin.git`。对应的 HTTPS 地址是：

https://github.com/blizhan/magpie.koplugin

2026-11-10 的公开 API（`https://api.github.com/repos/blizhan/magpie.koplugin` 与其 `contents/`）观察到：仓库公开、默认分支 `main`、不是 fork、`topics` 为空数组、根目录只有 `.gitignore` 和 `LICENSE`。没有 `README.md`，也没有插件运行文件。GitHub 仓库描述原文是 “View today's Magpie usage, live concurrency, and trends in KOReader.” 本地 `_meta.lua` 的 `name` 是 `magpie`，`fullname` 是 “Magpie 看板”。这些是当天快照，不是收录结果。

| 项 | 值 |
|---|---|
| 名称 | `magpie.koplugin`（插件 id：`magpie`） |
| 用途 | KOReader 上的 Magpie 用量、配额、在飞项目状态和趋势看板 |
| Awesome 分类 | 已存在的 **Utilities & Tools** |
| 支持入口 | 上述仓库的 GitHub Issues（API 当天 `has_issues` 为 true） |
| 准备中的 topic | `koreader-plugin`（当天尚未打上） |

## 介绍

English: magpie.koplugin is a KOReader dashboard for Magpie usage, quotas, in-flight project status, and trends. It talks only to a Magpie gateway and Magpie web that the user runs; those services are not included in this repository.

中文：magpie.koplugin 是 KOReader 上的 Magpie 看板，用来看用量、配额、在飞项目状态和趋势。它只连接使用者自己的 Magpie gateway 和 Magpie web，本仓库不附带这些服务。

功能依赖与使用证据（契约描述和后续用户实机确认分别注明，未做商店实测）：

- 宿主是 KOReader。后续用户已用实拍确认自用阅读器上的三页正常使用，已接受为实机验收；具体设备型号和 KOReader 版本尚未记录，见 [用户实机使用验收](release-readiness.md#用户实机使用验收)。
- 用量、并发和配额依赖使用者自己的 Magpie gateway。缺 gateway 地址或 key 时，这一侧不发请求。
- 项目费用依赖使用者自己的 Magpie web。该客户端的 web 地址只按 HTTP 使用，并且不从 gateway 地址猜测端口。缺 web 地址或 key 时，这一侧不发请求。
- 在飞页还要求该 web 上启用 `@magpie-community/page-agent-office`（页面名匹配该包名，或 key 为 `plugin-agent-office`）。这里不把 npm 安装写成已成功。
- 三个页面是今日用量、在飞、趋势。菜单在「工具菜单 → Magpie 看板」。Dispatcher 动作是 `magpie_open` 和 `magpie_refresh`。

## 五渠道

| 渠道 | 一手链接（2026-11-10 已打开） | 状态 |
|---|---|---|
| 自动发现 / plugin index | https://github.com/omer-faruq/koreader-plugin-index/blob/main/README.md | materials-ready |
| Awesome KOReader | https://github.com/jannick-holm/awesome-koreader/blob/main/README.md | materials-ready |
| koreader/contrib | https://github.com/koreader/contrib/blob/main/README.md | materials-ready |
| AppStore | https://github.com/omer-faruq/appstore.koplugin/blob/main/README.md | materials-ready |
| Storefront | https://github.com/ultimatejimmy/storefront.koplugin/blob/main/README.md | materials-ready |

推荐顺序沿用研究结论，不是上游批准：先让公开仓库能被 topic 和仓库名发现，再使用下面的 Awesome 材料；contrib 留到上游项目可工作并写清功能之后。没有看到 AppStore 或 Storefront 要求作者另交一份目录 PR。发现、人工收录和安装能否成功是三件不同的事。任何渠道都没有承诺收录时限或推荐等级。

### 自动发现 / plugin index

主文档是上面的 index README。同日还读了 `scripts/build.py` 里的 `PLUGIN_QUERIES`：

- `topic:koreader-plugin`
- `topic:koreader-plugin fork:only stars:>=1`
- `in:name ".koplugin"`
- `in:name ".koplugin" fork:only stars:>=1`

非 fork 走前一类查询；fork 查询要求至少一颗星。本仓库 API 显示不是 fork，仓库名含 `.koplugin`，因此名字查询在仓库可被 GitHub 搜索到时即覆盖它。topic 仍然要准备，因为这是同一发现面使用的另一条查询。

README 写明：两条查询都找不到的仓库，才用 `curation.toml` 的 `[discovery].extra_plugins` 补种。在名字已经符合 `in:name ".koplugin"` 时，不先写补种。`curation.toml` 的人工评级盖在抽取结果之上，重建不会覆盖它。发现不等于进入推荐档。本次没有重读 `scripts/extract.py`，不推测质量档。

README 记载的调度是每日 diff（03:23 UTC 的计划时刻）和每月 1 日全量重建，并写明 GitHub 调度是 best-effort。这不构成收录截止时间。索引会从英文文档抽描述；公开默认分支目前没有 `README.md`，不能指望仅靠中文文件名被检索。

Topic / 名字准备：

- topic 字符串：`koreader-plugin`
- 仓库名：`magpie.koplugin`
- 2026-11-10 API 的 `topics` 仍是 `[]`，所以 topic 只是准备项，还没有打到公开仓库上

### Awesome KOReader

分类来自同日 README 的现有目录，不是新类。选用 **Utilities & Tools**（节首说明为 “Miscellaneous plugins that add useful functionality.”）。不放进 AI & Assistants：该节现有条目是阅读时调用的语言模型助手。不放进 Reading Tracking & Goals：该节现有条目跟踪的是阅读，不是 Magpie 服务用量。贡献说明要求新类通常至少三条；一条插件不新开分类。

贡献说明（https://github.com/jannick-holm/awesome-koreader/blob/main/CONTRIBUTING.md）要求：公开可访问、README 有说明和安装步骤、近期 KOReader 兼容或写明兼容版本、链到规范来源、在 PR 里披露作者身份。条目格式是一行，描述以大写字母开头、以句号结束，不含星数。优先方式是改 `main` 上的 README 并发 PR，分类内尽量按字母序；也可改用 “Add Resource” issue。同日 PR 模板在 https://github.com/jannick-holm/awesome-koreader/blob/main/.github/PULL_REQUEST_TEMPLATE.md 。

当天 Utilities & Tools 里看到的名字是 `kindle-quran`、`webbrowser.koplugin`、`localsend.koplugin`、`ink-away.koplugin`，顺序本身不完全按字母。若按字母插入，`magpie.koplugin` 在 `localsend.koplugin` 之后、`webbrowser.koplugin` 之前。

建议条目（尚未写进对方 README）：

```markdown
- [magpie.koplugin](https://github.com/blizhan/magpie.koplugin) - Shows Magpie usage, quotas, in-flight project status, and trends on KOReader, using a separate Magpie gateway and web service.
```

没有兼容性证据链接。公开默认分支当天没有安装说明，本地也还没有把设备安装结果记到任何 URL。

提交正文（准备稿，不是已发出的 PR）：

```markdown
## What are you adding/changing?

Add magpie.koplugin under the existing Utilities & Tools section, alphabetically after localsend.koplugin and before webbrowser.koplugin.

It is a KOReader dashboard for a separate Magpie service: usage and quotas from the user's gateway; project cost, in-flight project status, and trends from the user's Magpie web. The gateway, the web service, and @magpie-community/page-agent-office are not bundled.

Author disclosure: I am blizhan, the author of https://github.com/blizhan/magpie.koplugin.

Feature dependencies:

- KOReader as the host. The maintainer has confirmed real-device use with photos covering usage/quotas, project costs, the in-flight project list, and 30-day trends. The exact device and KOReader version are not yet recorded.
- A user-operated Magpie gateway for usage, concurrency, and quotas. If that side is not configured, the plugin sends no gateway request.
- A user-operated Magpie web for project costs. This client uses HTTP for the web and does not guess the web port from the gateway. If that side is not configured, the plugin sends no web request.
- The in-flight page also needs @magpie-community/page-agent-office enabled on that web. Installing that package from the public npm registry was not verified.

Store compatibility and clean installation from the final candidate ZIP are not yet verified. The maintainer's photographed real-device use is accepted separately. This request does not say that the plugin index, Awesome KOReader, koreader/contrib, AppStore, or Storefront has accepted the project.

## Checklist

- [ ] I have read the CONTRIBUTING.md guide
- [ ] The project is publicly accessible with a working link
- [ ] The project has a README with installation instructions
- [ ] It is compatible with a recent version of KOReader (or the compatible version is noted in my entry)
- [ ] My entry follows the correct format: `- [name](url) - One-sentence description.`
- [ ] I placed the entry in the most appropriate existing category
- [ ] The description starts with a capital letter and ends with a period
- [ ] I am not adding a duplicate of an existing entry

The entry line above matches the format, capitalisation, and Utilities & Tools placement. The boxes remain open: at the original investigation, the public default branch had no README or plugin files. Subsequent maintainer photos and confirmation now provide real-device usage evidence, but the tested KOReader version and store-installation results are not recorded. Complete the compatibility details before checking that box.

## Self-promotion disclosure

- [x] I am the author or maintainer of the project I'm adding *(if yes, that's fine — just check the box)*

Submitter: blizhan.

## Additional context

There is no device-compatibility evidence to link. App Store and Storefront compatibility were not tested.
```

作者披露框是材料的一部分。其余模板框保持未勾，因为对应事实当天不成立。

### koreader/contrib（可选，后做）

主文档：https://github.com/koreader/contrib/blob/main/README.md 。同日 API `https://api.github.com/repos/koreader/contrib` 的默认分支是 `main`，仓库描述为 “Collection of non-official plugins designed for KOReader”，`license.spdx_id` 为 `AGPL-3.0`。

README 对开发者的条件：

- 合并时必须能工作；明确不收未完成或已废弃功能。
- 每个应用是指向上游仓库的 git submodule。若以后走这条路，上游应是 https://github.com/blizhan/magpie.koplugin 。
- 用 `README.md` 或 `README` 说明功能。
- 只适用于某些设备时，在 README 或 `COMPATIBILITY` 里写兼容性。现已有用户实机使用记录，具体设备型号和 KOReader 版本待补，不将这一记录扩大成其他设备或商店兼容性声明。

README 对使用者的界限：这些插件不在 KOReader 想维护的核心逻辑里，更新 KOReader 后可能失效；失效应向上游报。被放进该组织仓库不等于随 KOReader 捆绑、不等于兼容认证、也不等于 KOReader 持续维护。

API 的 AGPL-3.0 标签只说明 contrib 仓库元数据。当天读到的开发者三条没有写“每个上游插件都必须改成同一许可证”。真正要提交 submodule 之前，须按当时的许可证文本单独判断。本文件不代替那个判断。

因此这条只保留条件说明。上游尚未以可工作、带功能说明的公开树存在，现在不准备 submodule diff。

### AppStore

主文档：https://github.com/omer-faruq/appstore.koplugin/blob/main/README.md 。同日在该仓库 `main.lua` 看到插件发现常量与刷新查询：`PLUGIN_TOPICS = { "koreader-plugin" }`，`PLUGIN_NAME_QUERIES = { 'in:name ".koplugin"' }`，刷新时拼接 `topic:koreader-plugin` 与 `in:name ".koplugin"`。README 还写了按 GitHub owner/repo 手动安装、下载仓库 ZIP、校验元数据、使用 release 资产，以及没有 release 资产时的源码下载。典型安装流程写的是下载 zipball、检查 `_meta.lua`、复制进插件目录、重启 KOReader。README 没有作者投稿表，也没有写必须另交目录 PR。

README 的缓存说明：增量刷新按推送时间，并写明它看不到“只改了 topic 或 star、没有新 push”的变化，要等下一次全量刷新。加上 topic 不会自动变成立即可见。AppStore 读取的是仓库 HEAD 上的 `README.md`；当天公开根目录没有这个文件。

按已调查的格式，安装包应是单一的 `magpie.koplugin/` 根。这只是准备约定。没有用 AppStore 安装过，不能称为与该商店兼容。

### Storefront

主文档：https://github.com/ultimatejimmy/storefront.koplugin/blob/main/README.md 。它描述设备内目录、release/版本安装和 Git 分支跟踪，并指向管理 wiki。本次没有重读该 wiki，所以不转述其中未核对的归档布局。

同日 `tools/build_catalog.py` 的插件查询是 `topic:koreader-plugin` 和 `in:name ".koplugin"`。`process_single_repo` 丢掉 0 star 的 fork。本仓库不是 fork，这条排除不适用。`.github/workflows/build-catalog.yml` 在推送到 `main` 或手动 `workflow_dispatch` 时构建并部署目录，文件里没有 nightly 调度。不能承诺目录何时捡到新仓库。

同日 `storefront.koplugin/storefront_net_github.lua` 里没有 `koreader-plugin` 或 `.koplugin` 这两个发现字符串；目录查询以 `tools/build_catalog.py` 为准。README 没有作者投稿表，也没有写必须另交目录 PR。

没有用 Storefront 安装过，不能称为与该商店兼容。

## 当天仍未知或不成立

- 公开 `main` 还没有插件文件和安装 README，topic 也还没打上。材料写好不等于已经被搜到。
- 没有 KOReader 版本、设备型号或商店安装记录。
- 没有查询 plugin index、AppStore 缓存或 Storefront `catalog.json`，因此没有“已出现”或“未出现”的目录结论。
- Agent Office 的公开安装方式不在本次复核范围内，不能写成用户已经可以装上。
- index 的自动质量档没有重读实现，不指定档位。
- contrib 的许可证后果未决，且上游工作状态不满足 README 的合并条件。
