# Magpie-Kanban

**[English](./README.md) | 简体中文**

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Runtime](https://img.shields.io/badge/Runtime-KOReader%20%2F%20LuaJIT-blue.svg)](https://koreader.rocks/)

在 [KOReader](https://koreader.rocks/) 上查看你自己的 [Magpie](https://usemagpie.ai/) 用量、配额、项目费用、在飞任务和趋势。

插件运行在阅读器上，Gateway、Web 和 Agent Office 运行在你的主机上。插件只发 GET 请求，不修改 Magpie 配置。界面为中文，两份 README 介绍的是同一个插件。

[功能](#feature) · [安装](#install) · [使用](#usage) · [开发](#dev)

| 今日用量 | 在飞项目 | 30 日趋势 |
| --- | --- | --- |
| ![阅读器上的 Magpie 用量与配额看板](https://raw.githubusercontent.com/blizhan/magpie.koplugin/main/docs/images/dashboard-usage.jpg) | ![阅读器上的 Magpie 在飞项目看板](https://raw.githubusercontent.com/blizhan/magpie.koplugin/main/docs/images/dashboard-inflight.jpg) | ![阅读器上的 Magpie 30 日费用趋势](https://raw.githubusercontent.com/blizhan/magpie.koplugin/main/docs/images/dashboard-trends.jpg) |

维护者实际使用的设备实拍，已确认作为验收依据；账号和项目标签已隐藏。

## Feature

三个页面：**今日用量**、**在飞**、**趋势**。

| 能力 | 展示内容 | 依赖 |
| --- | --- | --- |
| 用量 | 费用、请求、token；后端提供时还显示缓存、解码速度、会话数和 TTFT | Gateway 和你的 Gateway key |
| 配额 | 主配额窗口及重置时间；可见范围由 key 权限决定 | Gateway 配额权限 |
| 项目费用 | 按目录最后一级名称归并；小额项目和未归属费用并入「其余」 | Magpie Web 及其管理 key |
| 在飞 | 按需要处理、工作、完成和闲置状态展示项目；打开项目查看会话详情 | Web 和已启用的 Agent Office |
| 趋势 | 今日 / 7 日 / 30 日，费用或请求；多日费用可按主要项目堆叠 | Gateway；项目明细另需 Web |

今日图表和请求图表使用普通条形。项目费用显示在用量页和所选周期的趋势页；在飞项目旁还显示 Gateway 并发汇总。

看板打开时默认每 60 秒刷新，关闭或设备挂起后停止。已有的 `auto_refresh_sec` 偏好会保留，界面没有修改间隔的菜单；重新打开或恢复不会叠加计时器。单项请求失败时保留上次数据并标明错误，首次失败则显示不可用状态。

仓库只提供插件，不附带后端、默认服务器或演示服务，也不提供 RSS、天气、阅读统计、同步或首页替换。界面、网络和 JSON 库由 KOReader 提供，本插件不是 KOReader 官方组件。

**当前状态：**版本 `0.4.0`，User-Agent 为 `magpie-koreader/0.4.0`；没有 Git tag 或公开发行 ZIP。

**真机使用：**维护者已确认在自己的阅读器上实际使用，照片作为用量、配额、项目费用、在飞项目列表和 30 日费用趋势的验收依据。具体设备型号和软件/构建版本尚未记录，暂不声明最低 KOReader 版本或其他设备兼容性。独立首次使用和商店兼容性仍待验证。详见[验证记录](https://github.com/blizhan/magpie.koplugin/blob/main/docs/release-readiness.md)。

---

## Install

### 1. 复制插件

主机需要 Git、POSIX shell，以及对阅读器 KOReader 存储的写入权限。先找到这台 KOReader 实际使用的 `plugins` 目录；路径因设备而异。

```sh
git clone https://github.com/blizhan/magpie.koplugin.git
cd magpie.koplugin
printf 'KOReader plugins directory: '
IFS= read -r KOREADER_PLUGINS
test -n "$KOREADER_PLUGINS" && test -d "$KOREADER_PLUGINS" || exit 1
mkdir -p "$KOREADER_PLUGINS/magpie.koplugin"
cp _meta.lua main.lua dashview.lua office.lua projcost.lua LICENSE README.md README.zh-CN.md "$KOREADER_PLUGINS/magpie.koplugin/"
```

只复制这八个文件。安装后应存在 `plugins/magpie.koplugin/_meta.lua`，不要再套一层插件目录。若按 Dev 自行打包，将 ZIP 中唯一的 `magpie.koplugin/` 根目录解到同一个 `plugins` 目录。个人配置放在插件目录之外。

### 2. 配置 Gateway

按 [Usage](#usage) 准备自己的 Gateway，在 KOReader 设置目录的 `magpie/` 下写入 `base_url.txt` 和 `gateway-key.txt`。项目相关功能再按需配置 Web 和 Agent Office。

### 3. 打开看板

完全退出 KOReader，再重新启动，打开：

**工具 → 更多工具 → Magpie 看板 → 打开看板**

刷新后，将费用、请求和 token 与这个 Gateway key 能看到的数据核对。有权限时才显示配额。未配置时，看板会说明缺少的文件，对应一侧不发请求。

---

## Usage

### 准备后端

1. 从 [Magpie 官网](https://usemagpie.ai/#cli) 安装官方发行。
2. 开启[局域网共享](https://usemagpie.ai/docs/remote#share)，使用 Address 行提供的 Gateway 地址，确认阅读器可以访问。
3. 在 Gateway keys 界面创建 key，或在 Magpie 主机上执行：

   ```sh
   magpie gateway-key add "Kindle"
   ```

   标签只是名称。按需要授予配额可见权限；受限 key 可能看不到全局数据，不必为了填满面板而扩大权限。

需要项目费用和在飞时，另用自己的管理 key 启动 Magpie Web。以下示例用 OpenSSL 生成 key，请自行妥善保管，供设备配置使用：

```sh
export MAGPIE_WEB_KEY="$(openssl rand -hex 16)"
magpie web --addr 0.0.0.0:3430 --no-open
```

这组参数见[官方 Web CLI 源码](https://github.com/yetone/magpie/blob/4869d0c9665e1a815fee3a1a4d67a575e0baab93/internal/cli/web_cli.go)。设备填写可达主机地址和实际端口，不填 `0.0.0.0`。已有 Web 或 daemon 进程可能被复用，新环境变量不会替换那个进程的 key；应使用实际提供页面的进程的 key。Web 端口不会从 Gateway 推算。

在飞项目卡片还需要在同一个 Web 进程上启用 Agent Office：

```sh
magpie plugin add @magpie-community/page-agent-office
```

**维护者阅读器上的在飞显示已确认。**公共 Office 安装流程仍待复现：registry 查询曾返回 404，实际安装方式和后端版本尚未记录。来源包元数据要求 Magpie ≥ 0.1.1318，这不是实测版本范围。公共包不可用时，按插件作者公开的源码安装说明操作，并记录版本和结果；这项安装复现检查不否定已确认的真机使用。

### 写入四个配置文件

配置目录为 `DataStorage:getSettingsDir() .. "/magpie/"`，常见位置是 KOReader 数据目录中的 `settings/magpie/`。没有时自行创建，以本机设置位置为准，不放在插件目录中。

| 文件 | 用途 | 示例值 |
| --- | --- | --- |
| `base_url.txt` | Gateway 用量、趋势和配额 | `http://gateway.example.invalid:8080` |
| `gateway-key.txt` | Gateway 认证 | `EXAMPLE_ONLY_NOT_A_REAL_KEY` |
| `web_url.txt` | 项目费用和在飞 | `http://web.example.invalid:3430` |
| `web-key.txt` | Web 认证 | `EXAMPLE_ONLY_NOT_A_REAL_KEY` |

上表都是不可用的虚构示例，请在设备文件中填写自己的值。每个文件只取去掉首尾空白后，第一行非空、且不以 `#` 开头的内容。空文件、只有注释或无法读取都视为未配置，错误不会回显文件内容。

- Gateway 地址支持 `http` 或 `https`，Web 只支持 `http`。地址需要非空主机，不允许用户信息、查询参数或片段；尾部斜线会移除，不支持的协议会被拒绝，不会降级连接。
- Web key 至少 16 个字符，只能含字母、数字和 `-._~`。无效 key 不发送 Web 请求。
- 菜单 **网关地址…** 只编辑 `base_url.txt`，写入失败会提示，也不会显示 key。Web 地址和两个 key 通过文件修改。
- 每次手动或定时刷新都会重读配置。URL 或 key 改变时清除对应缓存；Web 还会清除只存在内存中的 cookie 和已发现的 Office 路径。Gateway 与 Web 独立工作，缺少完整配置的一侧不发请求。

配好 Gateway 后，核对用量并切换趋势周期和指标。配好 Web 后，用量页和趋势页可显示项目费用；启用 Agent Office 后，在飞页可打开项目查看会话详情。

### 导航与刷新

| 操作 | 结果 |
| --- | --- |
| 左右滑动 | 下一页 / 上一页；项目详情中右滑返回列表 |
| 下滑或 **↻** | 刷新 |
| **用量 / 在飞 / 趋势** | 切页 |
| **×** | 关闭 |
| Dispatcher `magpie_open` / `magpie_refresh` | 通过自行分配的手势或配置方案打开 / 刷新 |

工具菜单还提供 **刷新数据**、**用量页**、**在飞页**、**趋势页**和 **网关地址…**。

### 错误与恢复

| 情况 | 结果与处理 |
| --- | --- |
| 缺配置，或地址/key 无效 | 对应一侧不发请求，按提示检查文件和支持的协议 |
| 网络不通、key 错误、HTTP 错误或 JSON 无效 | 只显示错误类别/状态；旧数据标为过期。排除原因后刷新，其他成功数据项仍会更新 |
| 切换趋势周期后请求失败 | 不会把其他周期的数据标成新周期；可重试当前周期 |
| 配额权限不足 | 显示权限说明，与成功返回的空配额不同；已有配额会保留失败提示，直到恢复 |
| 配额或项目统计为空 | 显示空状态，不算网络错误 |
| 未配 Web 或未启用 Office | Gateway 用量仍可用；为受影响功能配置 Web 或启用 Office |
| Web 返回 401 | 重新登录并重试一次，再失败就停止；登录不跟随跳转 |
| 已发现的 Office 路径返回 404 | 清除路径并重新发现一次 |

### 升级、迁移与卸载

- **升级：**替换插件目录并完全重启 KOReader，保留 `settings/magpie/` 和 `settings/magpie.lua` 中的非敏感偏好。
- **从旧版本迁移：**手动将地址/key 写入上述四个文件。本版不读取旧外部路径、插件内的 `apikey.txt` 或 settings 凭据。加载时删除 `magpie.lua` 中旧 `api_key`、`base_url` 字段，保存其余偏好，包括刷新间隔和 User-Agent，不使用删除的值连接。旧文件、备份和同步副本仍会留下，请自行清理含秘密的副本。
- **卸载：**删除 `plugins/magpie.koplugin/`。若还要移除个人配置，显式删除 `settings/magpie/` 和 `settings/magpie.lua`，不要删除其他 KOReader 设置。

### 安全与数据

- Web key 是**管理凭据**，不是只读看板 token。持有者能修改 Magpie 并查看 key，尽管本插件只发 GET 请求。
- Web 使用 HTTP，并通过 `GET /?k=<web-key>` 登录。服务器、代理或访问日志可能保留查询字符串，插件无法控制这些日志。cookie 只留在内存。
- 本客户端的 Gateway HTTPS **不校验证书**。Web 不支持 HTTPS，也不会把 HTTPS 地址降级为 HTTP。
- 目录 `0700`、写入文件 `0600` 权限是尽力设置；FAT 忽略这些权限位，保护依赖设备访问控制。
- 不向 issue 或附件提供真实 key、带凭据的 URL、cookie、私人主机、设置文件和含 key 的命令历史。项目名、会话标题和截图也可能是个人内容，请使用合成示例。

---

## Dev

### 本地检查

需要 Git、POSIX shell 和 LuaJIT；打包需要 `zip`，检查归档需要 `unzip`，发布隐私检查需要 Gitleaks **8.x**。可选 Web key 生成示例使用 OpenSSL。

在仓库根目录执行：

```sh
luajit tests/run.lua
```

测试使用临时设置和合成响应，失败时非零退出，不读真实设备配置或 key。它不能证明 Gateway/Web/Office 已安装，也不能验证真实 KOReader 绘制、触摸、计时器、挂起或重启。请求或界面修改还需在自有可达主机、后端和 KOReader 上核对。

### 打包

使用 `_meta.lua` 已声明的版本：

```sh
sh scripts/package.sh 0.4.0
unzip -Z1 dist/magpie.koplugin-0.4.0.zip
```

归档只有一个 `magpie.koplugin/` 根目录，内含 Install 中的八个文件。脚本拒绝覆盖已有输出，请另存旧候选；打包成功不等于通过发布验收。

隐私检查覆盖拟公开历史、公开源码和临时解包的候选，分别使用 `gitleaks git --redact .`、`gitleaks dir --redact .` 和对解包目录执行 `gitleaks dir --redact`。还需人工检查私人地址、路径、名称和附件。逐项判断扫描结果，不把扫描器当作安全证明，也不公开含秘密的报告。

### 贡献与反馈

在 [GitHub issue](https://github.com/blizhan/magpie.koplugin/issues) 中描述可复现的问题或有明确边界的提议。Fork/clone 后建立分支，一次完成一个有边界的修改，运行本地检查；请求或界面修改还需用自己的后端和 KOReader 核对成功与失败路径。提交 [pull request](https://github.com/blizhan/magpie.koplugin/pulls)，写清修改、实际执行的检查和尚缺的依赖。

反馈问题时提供插件/KOReader 版本、设备型号（不含序列号或账号）、页面、预期行为、错误类别和 HTTP 状态。不要附真实设置、响应正文、`live.js`、会话内容、凭据，以及未脱敏的日志或截图。

### 文档与验证

- [验证记录](https://github.com/blizhan/magpie.koplugin/blob/main/docs/release-readiness.md)：实际检查、候选包和未通过的门禁。
- [验收 quickstart](https://github.com/blizhan/magpie.koplugin/blob/main/specs/001-open-source-magpie/quickstart.md)：真实设备、后端和独立首次使用步骤。
- [来源记录](https://github.com/blizhan/magpie.koplugin/blob/main/docs/provenance.md)：来源与 MIT 再分发依据。
- [社区路径](https://github.com/blizhan/magpie.koplugin/blob/main/docs/community.md)：发现、收录和商店安装状态。

剩余发布检查包括最终候选 ZIP 的干净安装，照片未覆盖的功能、错误恢复和生命周期场景，环境/构建版本记录，独立中英文使用者各在 30 分钟内首次使用，以及外部开发者在 60 分钟内完成有边界的修改。这些项目与已通过的真机结果分别记录，整体发布验收仍为 **BLOCKED**。
