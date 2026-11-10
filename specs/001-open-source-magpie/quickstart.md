# Quickstart Validation Guide

本指南用于实施完成后的验收，**本次规划尚未运行以下产品场景**。`scripts/package.sh`、`tests/run.lua`、运行源码和正式 README 均是待实施产物；入口契约见 [distribution.md](contracts/distribution.md)。所有命令在插件仓库根目录执行，设备路径由验证者输入，不使用维护者的设备或服务默认值。

## 1. 前置条件

- 来源授权已确认后再迁入运行源码；发布前所有 [发布门禁](contracts/distribution.md#发布门禁) 必须通过。
- 本机有 POSIX shell、LuaJIT、zip/unzip、Git、Gitleaks v8（支持 `git` / `dir` 子命令）。实际执行 `command -v luajit zip unzip git gitleaks` 和相应版本命令并记录；缺失时安装工具后继续，不跳过检查。
- 有隔离的 KOReader 运行环境或测试设备；记录 KOReader 版本、设备型号、屏幕和 LuaJIT 版本。来源记录的 2026.07.1 / Kindle Basic 7th gen 只是首个验证目标，不代表本轮已通过。
- 后端完整场景需要自备 Magpie、Gateway key、可达的 Web 和 Agent Office。按 [配置契约](contracts/configuration.md#公开取得后端的操作契约) 准备，记录实际版本；禁止使用维护者私有端点。
- 所有截图/共享日志采用合成项目名、账户和内容；真实凭据不进入终端录屏或命令历史。Web key 权限与传输限制必须由验证者理解。

## 2. 离线行为验证

```sh
luajit tests/run.lua
```

预期退出 0，场景包含：配置缺失不发送请求；新目录是唯一配置来源；旧 settings 不再保留 key；更换连接不显示旧服务缓存；Office 状态和时间边界；项目费用归并与“其余”；错误后保留旧数据并标记过期。测试必须使用临时目录与合成数据，不读真实 key 或 `live.js`。

对于网络相关修改，用本地受控服务或请求适配器的行为测试覆盖 [backend.md](contracts/backend.md#合成场景与真实验收) 中的失败与恢复场景；验证可观察的请求/状态结果，不以 mock 回显、源码字符串或“不抛错”作为断言。设备 smoke 仍须独立完成。

## 3. 生成并检查最终候选包

输入与 `_meta.lua` 一致的候选版本；使用一个尚不存在的输出文件名。

```sh
set -eu
printf 'Candidate version: '
read -r PLUGIN_VERSION
sh scripts/package.sh "$PLUGIN_VERSION"
CHECK_ROOT=$(mktemp -d)
unzip -q "dist/magpie.koplugin-${PLUGIN_VERSION}.zip" -d "$CHECK_ROOT"
unzip -Z1 "dist/magpie.koplugin-${PLUGIN_VERSION}.zip"
sha256sum "dist/magpie.koplugin-${PLUGIN_VERSION}.zip"
```

预期只有 [分发允许清单](contracts/distribution.md#仓库与安装包) 中的 8 个文件；额外路径、嵌套的第二个插件根、配置、快照或测试文件均失败。记录 SHA-256，后续设备安装必须来自此包。

```sh
set -eu
gitleaks version
gitleaks git --redact .
gitleaks dir --redact .
gitleaks dir --redact "$CHECK_ROOT"
```

每次扫描必须成功结束；非零结果按工具错误或发现处理。所有日志保持脱敏。另行人工核对：历史范围、未跟踪/忽略文件是否可能被公开、私人地址/账号/目录、图片/附件、许可及研究文件。扫描器无法证明无任何私人信息，不能替代人工检查。

结束后仅移除自己创建的 CHECK_ROOT 临时目录；保留记录的候选包和脱敏结果用于后续验收。

## 4. 干净安装与无配置启动

使用没有 Magpie 插件和配置的隔离 KOReader 环境。输入其数据根目录，确认其中有 `plugins/`；不要指向当前个人阅读环境。

```sh
set -eu
printf 'Isolated KOReader data directory: '
read -r KOREADER_DIR
test -d "$KOREADER_DIR/plugins"
test ! -e "$KOREADER_DIR/plugins/magpie.koplugin"
unzip -q "dist/magpie.koplugin-${PLUGIN_VERSION}.zip" -d "$KOREADER_DIR/plugins"
```

完全退出并重启真实 KOReader，从工具菜单打开 Magpie。预期可进入看板，显示缺少的配置项及位置，不崩溃、不连接任何预置服务、不显示假数据。用该测试环境的网络观察确认未发送后端请求；只有 UI 截图不足以证明没有请求。

通过 KOReader `DataStorage:getSettingsDir()` 确认设置目录，按 [配置契约](contracts/configuration.md) 建立自己的文件；默认布局通常是数据根下 `settings/magpie/`。不要把安装目录与设置目录混为一谈。

## 5. Gateway 首次成功

按官方共享说明获得用户自己的地址和专用 key，仅配置 Gateway 两个文件。打开并刷新：

- 今日费用、请求与 token 信息符合该 key 可见的数据；有配额权限时显示窗口，无权限时出现权限说明。
- 三个趋势周期及费用/请求切换可用；用量和趋势均取自实际自备服务。
- 未配置 Web 时，项目费用/Office 显示所需依赖，不阻断 Gateway 信息。
- 修改网关地址入口写入唯一配置文件；重启后使用相同地址，没有旧路径覆盖。

用权限有限的 key 验证配额拒绝与空配额的差异；不为验收给 key 增加无必要权限。

## 6. Web、项目费用与 Office

按照官方固定 key 启动/daemon 说明配置实际服务。在设备写入可达 Web 地址与对应 key，启用与该 Magpie 兼容的 Agent Office。

验收项目费用今日/7日/30日，项目归并与“其余”；在飞需要处理/工作/完成/闲置状态；项目详情；Web cookie 过期后的一次恢复；Office 页面重载导致旧路径 404 后的一次重新发现。测试服务的状态输入用合成项目和会话产生，不能共享真实 prompt 或标题。

若 Agent Office 公共安装方式无法复现，记录错误和版本并保持该项阻塞；不能把该功能从保留范围移除，或用本地 fixture 冒充完成真实安装。

## 7. 失败、生命周期与迁移

|场景|期望结果|
|---|---|
|缺 URL / key、只有注释、不可读文件|明确配置提示；该类请求不发送|
|错误 key、服务断网、非法 JSON|安全错误；已有数据标记过期，无旧数据时不可用|
|空统计、空配额、Office 未启用|说明空状态或依赖缺失，不混淆网络错误|
|更换 URL 或 key|清除对应旧缓存与 cookie，不显示旧服务数据|
|刷新、左右切页、项目详情|真实触摸/按键操作正确，未重复注册计时器|
|关闭、挂起、重新打开/恢复|关闭/挂起后无周期刷新；恢复符合宿主行为且不重复计时|
|仅存在旧目录或 settings key|不会悄悄回退；旧敏感 settings 字段被清除；提示手动迁移|
|升级安装包|专用配置保留，插件仍可启动|
|卸载及彻底清理|按文档区分保留配置和主动删除；不影响其他 KOReader 设置|

只使用虚构 legacy key 验证清理，不把真实 key 放进回归 fixture。离屏 PNG 能辅助发现布局问题，不能替代触摸、计时器、休眠和网络结果。

## 8. 双语与外部贡献验收

中文、英文各一名未参与整理的验证者，仅凭对应 README，在前置条件满足后计时：30 分钟内完成安装、启动和首次真实成功使用。记录时间、卡点和需要补充的信息，不记录私人值。逐项核对两种语言四节与升级/卸载、依赖、安全限制的一致性。

至少一名外部开发者依据 Dev 在 60 分钟内完成一次本地修改验证；记录所用合成场景和结果。不得以主维护者代跑替代独立验证者验收。

## 9. 社区与发布判定

按 `docs/community.md` 核对五渠道及至少一套完整材料，真实 canonical URL、作者披露和兼容性证据必须齐全。AppStore/Storefront 若未实际安装验证，只记录格式准备状态。此步骤不发送 PR 或消息。

将候选版本、ZIP 摘要、环境、每项能力结果、双语时长、授权依据和脱敏检查范围写入 `docs/release-readiness.md`。任何门禁未通过时结果为 ERROR/BLOCKED；全部通过才为 release-ready。公开操作另行依据用户授权执行。
