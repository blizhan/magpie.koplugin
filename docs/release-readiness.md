# 发布就绪记录

本文汇总命令实跑、用户验收确认与图像证据，并区分各自覆盖范围。它和仓库忽略规则都不能代替密钥或个人信息检查。当前仍有未完成的发布验收项。

## T001 工具与隔离环境

检查日期：2026-11-10。平台：Linux arm64（`uname -m` 为 `aarch64`）。

| 工具 | 版本（命令输出） | 路径 | 状态 |
| --- | --- | --- | --- |
| luajit | `LuaJIT 2.1.1703358377 -- Copyright (C) 2005-2023 Mike Pall. https://luajit.org/`（`luajit -v`） | `~/.local/bin/luajit`（包装脚本，实际二进制在用户前缀 `~/.local/opt/luajit-prefix/usr/bin/luajit`） | 可用。原先不在 PATH。 |
| zip | `This is Zip 3.0 (July 5th 2008), by Info-ZIP.`（`zip -v`） | `/usr/bin/zip` | 可用 |
| unzip | `UnZip 6.00 of 20 April 2009, by Debian. Original by Info-ZIP.`（`unzip -v`） | `/usr/bin/unzip` | 可用 |
| git | `git version 2.43.0`（`git --version`） | `/usr/bin/git` | 可用 |
| gitleaks | `8.30.1`（`gitleaks version`） | `~/.local/bin/gitleaks` | 可用。主版本为 v8。`gitleaks git --help` 与 `gitleaks dir --help` 均存在。未对仓库做扫描。 |
| KOReader（隔离运行环境） | 未观测到版本、设备、屏幕或该环境自带的 LuaJIT | 无 | NOT AVAILABLE |

安装依据：

- LuaJIT：系统包候选为 Ubuntu noble-updates/universe 的 `luajit` `2.1.0+git20231223.c525bcb+dfsg-1ubuntu0.1`，依赖同版本 `libluajit-5.1-2` 与 `libluajit-5.1-common`。`sudo -n apt-get install` 失败（`sudo: 需要密码`），因此用 `apt-get download` 取得上述三个 deb，解压到用户前缀，并用包装脚本设置 `LD_LIBRARY_PATH` 后执行。未写入系统目录。
- Gitleaks：上游发行包 `gitleaks_8.30.1_linux_arm64.tar.gz`（https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_arm64.tar.gz）。SHA-256 与同页 `gitleaks_8.30.1_checksums.txt` 中对应行一致：`e4a487ee7ccd7d3a7f7ec08657610aa3606637dab924210b3aee62570fb4b080`。解压到 `~/.local/bin`。

未满足条件：

- 不能用 apt 安装到系统路径：非交互 `sudo` 需要密码，当前没有该权限。LuaJIT 因此只在用户前缀可用。
- 隔离 KOReader 运行环境 NOT AVAILABLE。已查找且未发现：文件名 `koreader` / `koreader-appimage` / `reader.lua`（`/home` 下当前用户目录、`/opt`、`/usr`、`/var`、`/snap`，深度上限 7）；`flatpak list`；`snap list`；`docker images`。规格或源设备笔记中的 KOReader 2026.07.1 / Kindle Basic 7th gen 不是本机运行记录，此处不记为已安装或已验证。

当前门禁（历史结果与本轮复核分开记录，不得据本地检查宣称可发布）：

| 门禁 | 状态 |
| --- | --- |
| G-LICENSE | 来源再分发已确认。候选 ZIP 含 MIT `LICENSE`。见第 7 节与下文 T019 候选包。发布仍因运行和独立验收未完成而 BLOCKED。 |
| G-PRIVACY | 本轮 69 个可进入 Git 的文件快照、1 个历史提交及修正候选解包的 Gitleaks 扫描无发现；60 个公开文本文件未再出现审查指出的两类私人部署字面值。全工作区扫描另有 4 项，均已核对为被忽略的 GitNexus 示例文件 SHA-256 指纹。扫描及已知值复核不代替完整人工隐私验收。 |
| G-RUNTIME | 部分通过。用户确认实际在阅读器上使用，三张实拍已作为用量/配额/项目费用、在飞列表和 30 日趋势的真机验收依据，见「用户实机使用验收」。未覆盖的错误恢复、生命周期和候选 ZIP 安装场景另记待验；本机无隔离 KOReader 不再被用来否定用户实机证据。 |
| G-DOCS | 双语安装命令在临时目录实跑，均安装相同八文件；开发前提、贡献步骤及安全限制已核对。独立用户计时 NOT RUN。 |
| G-COMMUNITY | 五渠道材料为 materials-ready。未提交、未收录、未做商店安装验证。 |

## T004 来源授权

检查日期：2026-11-10。依据 `docs/provenance.md`：五个来源文件只出现在 `70da69047ac255faf80546c512d3deff04cfa161`，文件内无版权声明，来源仓库无 LICENSE/COPYING/NOTICE。目标 MIT 不自动覆盖这些文件。`office.lua` 对 `page/model.js` 的状态分类是否构成派生作品，仓库内没有该 JS 文件，无法判定。

结果：2026-11-10 权利人授权按目标 MIT 迁入全部五个文件，并确认 `office.lua` 状态分类为独立实现。五个文件已迁入。发布门禁仍等待最终包复核。

## T006 修改前影响面

检查日期：2026-11-10。仓库 `/home/blizhan/repo/github/magpie.koplugin`，工作区即当前检出，分支 `main`，索引提交 `1e91c14`。`node .gitnexus/run.cjs analyze --index-only --skip-agents-md --skip-skills .` 得到 177 个节点。Cypher 能看到 `main.lua` 等文件节点，但 `impact` 对 `Magpie:init`、`Magpie:httpGet`、`Magpie:webSignIn`、`Magpie:fetchAll`、`Magpie:findOfficePath` 均返回 target not found，`risk: UNKNOWN`。这不是“无调用者”，图没有解析出 Lua 方法。

源码检索补证：这些方法的调用都在 `main.lua` 内部（`fetchAll`、`webGet`、菜单回调、`refreshAndShow`）。`dashview.lua`、`office.lua`、`projcost.lua` 不调用它们。KOReader 从插件外部调用 `init` 和 Dispatcher 事件，索引无法表示。未把该结果写成图分析成功，也没有 HIGH/CRITICAL 图警告。随后才改配置相关方法。

## 合成测试与候选包

2026-11-10，仓库根目录：

- `luajit tests/run.lua` 退出 0。覆盖 Office 状态边界、`Office.decode`、项目费用归并与“其余”、旧 settings 清理、无配置不发请求、唯一配置目录、更换连接清缓存、Web 303/401、一次 401 重认证、外部 origin 不请求、Office 404 一次重新发现、网关错误不含 key、失败保留旧数据。输出只有场景名。
- 将同一脚本复制到临时文件并强制第一个场景失败后，退出码为 1，stderr 只有 `FAIL` 和场景名。临时副本已删除。这不代替 KOReader smoke。
- `sh scripts/package.sh 0.4.0` 生成 `dist/magpie.koplugin-0.4.0.zip`。SHA-256：`1f228831287234291267919731812937ceb80eadec73c1a98ae77ed5a2ce202c`。`unzip -Z1` 只有单一 `magpie.koplugin/` 根下的八个允许文件。已存在输出、路径型版本 `../0.4.0` 与 `0.4.0/x`、不匹配版本 `9.9.9` 均非零退出且不覆盖。
- 解包目录的 `gitleaks dir --redact` 无发现，临时解包目录已删除。

版本 `0.4.0` 来自迁入前用户代理 `magpie-koreader/0.4.0`，没有 Git tag。`_meta.lua` 的 name 仍是 `magpie`。

## T011 宿主 smoke

用户已确认实际在阅读器上使用，三页正常显示的真机验收已通过，证据见「用户实机使用验收」。本条中无配置启动及无预置网络请求的受控真机检查仍为 NOT RUN；已有合成请求观察不冒充该项实机结果。

## T012 脱敏检查

工具：Gitleaks 8.30.1。`gitleaks git --redact .` 扫描 1 个提交，无发现。`gitleaks dir --redact .` 扫描当时工作树，无发现。解包扫描见上。

人工类别的历史结论不完整：当时运行源码已移除私人 Gateway 地址与设备绝对部署路径，但公开审计和规划记录仍在否定句中复述这些值。后续人工复核确认这是隐私遗漏，本次已将相关复述改为类别描述，并撤回先前「未解决敏感发现数：0」的断言。本轮扫描与已知值复核结果见末节，不能沿用旧扫描推定当前状态。历史记录称仓库内未发现图片附件，未改写 Git 历史；扫描器无发现不等于完整人工隐私验收通过。

## T018 后端

`magpie version` 输出 `magpie 0.1.2777`。当时已有进程监听 `3425` 与 `3430`（pid 802555），属于现有环境。随后用临时 `HOME`、`XDG_CONFIG_HOME`、`XDG_DATA_HOME`、`MAGPIE_NO_ACCOUNTS=1` 和虚构 `MAGPIE_WEB_KEY` 执行 `magpie web --addr 127.0.0.1:18765 --no-open --gateway`。新进程只绑定了 `127.0.0.1:18765`，但日志写明 `127.0.0.1:3425` 仍由另一个 magpie 提供，且该页面显示同一套设置和账户。因此这不是隔离环境。进程已停止，临时目录已删除，没有调用 3425/3430 的 API，也没有读取 key。Agent Office 未安装。此项保持未完成。

后续用户确认补充：其实际使用环境已有用量、配额、项目费用、在飞列表和 30 日趋势的数据展示，已接受为正常使用的实机验收。上文「Agent Office 未安装」仅描述当时尝试构建的隔离环境，不适用于用户现有使用环境。公开安装路径、实际后端版本及错误恢复场景仍待记录。

## 未完成的真实验收

- T020–T022：部分通过。用户实机正常使用及截图覆盖的能力已验收；仍缺最终候选 ZIP 的干净安装、无配置启动、未覆盖的功能/异常/生命周期流程，以及对应环境和服务版本记录。隔离环境用于补充可复现验证，不取消已有用户实机结果。
- 独立中文与英文首次使用验收均 BLOCKED / NOT RUN：各需未参与实现的独立使用者按对应 README 在 30 分钟内完成首次安装、配置和查看自己的数据。没有可用参与者或已完成独立验收的证据。
- T028：BLOCKED / NOT RUN。缺未参与实现的外部开发者，按 Dev 在 60 分钟内完成有边界的修改、本地测试及所需真实后端/界面核对；须记录耗时和结果。
- T030：用户自用阅读器上的三页正常显示已有实机验收。设备型号与软件版本尚未记录，其他设备兼容性待验证。补充步骤与记录标准见 [quickstart](../specs/001-open-source-magpie/quickstart.md)。
- 社区状态只有 materials-ready。没有 submitted、listed 或 installation-verified。

## T033 发布判定

| 项 | 证据 | 结果 |
|---|---|---|
| FR-001、FR-004 | 五文件保留；合成行为回归；用户确认和三张实拍 | 用户实机正常使用通过；无配置实机与其余场景待验 |
| FR-002、FR-003 | 四文件配置、虚构示例、本轮扫描与已知私人值复核 | 审查指出的文本遗漏已修正；完整人工隐私验收与设备无配置启动未完成 |
| FR-005–FR-007 | 双语四节与打包脚本 | 文档完成；独立用户 NOT RUN |
| FR-008 | `luajit tests/run.lua` 成功与失败退出码 | 本地完成；外部开发者 NOT RUN |
| FR-009 | `docs/provenance.md` 权利人授权与包内 LICENSE | 迁入授权已确认 |
| FR-010、FR-011 | `docs/community.md` 五渠道与 Awesome 条目 | materials-ready |
| FR-012 | 本文件 | 未全部通过 |
| SC-001–SC-006 | 隐私扫描、文档核对及用户实机正常使用已有证据；独立计时和部分运行场景未完成 | 部分达标，逐项保留结果 |

结果：ERROR/BLOCKED。不是 release-ready。未推送、未发布、未联系社区。

## 当前审查修复与验证

本轮修复已落地：保存结果检查文件关闭错误；配额单独失败仍展示旧条形并提示过期，恢复后清除提示；趋势快照绑定其请求周期；项目费用错误保留 Web 配置恢复说明。旧文本渲染链及专用格式化辅助已移除，页面分派、左右滑动、打包成员与预设排序的重复实现已合并。双语文档补齐源码安装、开发前提及贡献步骤；公开审计改用隐私类别描述。

- `luajit tests/run.lua`：18 个场景通过。新增四个故障回归均先在修复前观测到失败，修复后通过。
- 临时 Lua smoke 使用真实 `main.lua` / `dashview.lua` 和受控宿主适配器：无配置页面包含两个必需 Web 文件说明；六种左右切页和详情返回正确；真实 `/dev/full` 关闭失败后保存对话框保持打开并提示失败；旧 25% 配额条形显示 HTTP 503 与过期提示；失败的 30 日切换没有重新标注 7 日总额或条形。适配器只验证组件构建、内容与回调，未验证真实字体、像素布局或触摸。
- 两份 README 的本地复制命令均在含空格的临时安装路径成功执行，结果恰好为八个允许文件。未将远程源码获取或独立首次使用记为通过。
- 两个模板解析入口的受控 CLI smoke 通过：优先级、同优先级排序、非法/布尔/非正优先级、禁用及无效 ID、成功空注册表、损坏注册表与缺 Python 时的回退。回退路径按实际解析内容核对。
- `sh scripts/package.sh 0.4.0` 在隔离源码副本生成候选；八个成员与副本逐字节一致。已有输出、缺少 README、不匹配版本及路径型版本均被拒绝。
- 修正候选保存在 `dist/review-fix/magpie.koplugin-0.4.0.zip`，SHA-256：`ccded365a093764e8231102d9be9d8e9e598b7e91e2b0444d13f31e0cddb0073`。原 `dist/magpie.koplugin-0.4.0.zip` 保留为历史产物，不是本轮候选。
- Gitleaks 8.30.1：拟公开历史 1 个提交、由 Git 跟踪/未忽略未跟踪清单复制的 69 文件快照及修正候选解包均无发现。完整本地工作区扫描非零，4 项均位于被忽略的 `.gitnexus/meta.json` / `gitnexus.json`，已通过重新计算两个虚构 key 示例的 SHA-256 确认是文件指纹，无扫描豁免规则。对 60 个公开文本文件另做审查已知地址/设备路径类别的字面检查，未再命中；这不是对未知私人信息的绝对保证。

用户实机正常使用的覆盖项已通过。未覆盖的安装、功能/异常/生命周期场景、环境版本记录和独立中英文使用者/外部开发者验收仍需完成，整体发布判定保持 **ERROR/BLOCKED**。没有发布、推送或联系社区。

## README 设备实拍

用户本轮提供三张 HEIC，分别展示用量、在飞和 30 日趋势。完整 JPEG 转换件保存在被忽略的 `dist/converted-photos/`，保持 3024×4032 分辨率，供本地使用；原 HEIC 未修改。README 使用 `docs/images/dashboard-usage.jpg`、`dashboard-inflight.jpg`、`dashboard-trends.jpg`：裁去电脑账户背景并校正视角，遮挡项目名及账号标签，数值保留自用户提供的实拍。两份 README 均注明标签已隐藏。

三个公开 JPEG 均为 1200×1600，合计 792594 字节。已重新解码核对文件完整性，EXIF、XMP 和 ICC 均不存在，并逐张检查了裁切与遮挡。Git 公开候选清单只包含这三个明确允许的图片，完整转换件仍被 `dist/` 规则忽略。README 使用仓库的原始图片 URL，供源码页及安装包内的说明引用；远程图片要随仓库发布后才可访问。

用户已明确确认这些照片来自其实际使用，并指定可作为验收依据；截图覆盖的正常使用项目已按下节登记为通过。已有 ZIP 是此前验证的快照，不包含本轮 README 图片说明。

## 用户实机使用验收

登记日期：2026-11-10。来源：本会话用户提供的三张 HEIC，以及明确确认「我前面的截图就是我用的证明，可以是验收依据」。验证者为用户本人；证据类型为用户实机使用确认与照片，不记成助手亲自操作。此前将设备运行整体写成 NOT RUN 的结论已更正。

| 验收项 | 依据 | 结果 |
| --- | --- | --- |
| 阅读器上启动并显示三个看板页 | 用户实际使用确认及三张页面实拍 | PASS（用户实机确认） |
| 今日用量、配额窗口和今日项目费用 | `IMG_5268.HEIC`；公开脱敏图 [用量](images/dashboard-usage.jpg) | PASS（截图覆盖的正常显示） |
| 在飞汇总、项目列表及工作/完成/闲置信息 | `IMG_5269.HEIC`；公开脱敏图 [在飞](images/dashboard-inflight.jpg) | PASS（截图覆盖的正常显示） |
| 30 日费用趋势、条形图及项目费用明细 | `IMG_5270.HEIC`；公开脱敏图 [趋势](images/dashboard-trends.jpg) | PASS（截图覆盖的正常显示） |

这些结果计入 FR-001、FR-004 及 SC-004 中已覆盖的实际使用验收。设备型号、KOReader/LuaJIT、Magpie/Office 版本及插件提交或候选 ZIP 摘要尚未随本次确认提供，记为待补记录，不推定为旧笔记中的组合，也不将该证据外推到其他设备。项目详情、其他趋势周期/指标、错误恢复、无配置启动、升级和休眠等未覆盖项，以及独立参与者计时，仍按各项原有标准补验。

## Docker 验证可行性

本轮只读检查：`docker version --format '{{json .}}'` 成功连到 Docker Engine 29.2.1，服务端为 Linux arm64；`docker manifest inspect --verbose koreader/koappimage:latest` 确认官方镜像包含 linux/arm64。该平台镜像 digest 为 `sha256:3a435915c530fbd5461a3874507a1ad1cd0a30be2244cdff8870a7c9f11ee682`。未拉取镜像、构建 KOReader 或运行容器内验收，以下是可行方案，不是通过记录。

一手依据：[KOReader 构建说明](https://github.com/koreader/koreader/blob/HEAD/doc/Building.md) 提供模拟器构建/运行入口；[官方 Docker 开发环境](https://github.com/koreader/virdevenv) 明确支持容器内运行模拟器，并给出 Xvfb/VNC 环境示例。

- 可容器化的软件验证：最终 ZIP 干净安装、无配置打开真实 KOReader、菜单与 Dispatcher、真实控件构建/绘制、页面与详情切换、计时器及宿主事件逻辑、升级迁移，以及受控网络错误与恢复。
- 自备服务验收可使用独立容器网络和全新数据卷承载实际 Magpie Gateway/Web/Office，不挂载宿主 HOME 或复用已有私人服务。必须实际安装并记录后端与 Office 版本；本地 fixture 仍不能替代真实后端，Docker 本身不解决 Office 包安装不可复现的问题。
- 真实设备触摸、墨水屏显示和实际电源休眠/唤醒不能由桌面模拟器替代。模拟事件只证明应用事件处理逻辑。
- 独立中英文使用者的 30 分钟验收、外部开发者的 60 分钟验收可以借助容器环境，但仍须真实且未参与实现的参与者；不能由当前实现者自动代跑后标为通过。

容器环境可补充可复现的 KOReader 运行环境和未覆盖场景；实际容器验收仍为 NOT RUN。用户已经确认的实机使用项目无需因本机没有运行时而重新证明；其余设备场景、公开后端安装复现和独立人工验收仍各自记录。
