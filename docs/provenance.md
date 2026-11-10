# 来源与再分发记录（T002）

调查日期：2026-11-10。只读查看来源仓库 `magpie-band-bridge` 中 `kindle/magpie.koplugin/` 的五个 Lua 文件。未改来源仓库，未对外联系，未把本记录当作授权。

G-LICENSE: BLOCKED

## 1. 逐文件记录

来源 `HEAD` 为 `70da69047ac255faf80546c512d3deff04cfa161`（`git rev-parse HEAD`）。`git log --all` 对这五个路径只列出这一次提交。`git shortlog -sne HEAD --` 这五个路径只有一行：`blizhan <parcevalry@gmail.com>`。`git log -1` 显示作者与提交者都是该身份，日期 `2026-11-04T11:41:58+08:00`，标题 `Kindle KOReader Magpie dashboard: plugin, designs, tools`，正文为空，没有 Co-authored-by。对每个文件单独 `git log --follow` 也只有这一次提交，没有更名前历史。`git status --short -- kindle/magpie.koplugin/` 无输出。`git log --numstat` 的新增行数与 `wc -l` 一致，工作区字节与该修订相同。

五个文件内都没有 SPDX 标识、Copyright 行或许可证名。检索覆盖 SPDX、copyright、license、©、版权、Apache、GPL、BSD。下表「版权 / SPDX」因此均为「none in file」。`office.lua` 里指向另一插件的注释不是版权头，记在第 4 节。

| 路径 | 观察到的修订（完整哈希 + 路径） | 版权 / SPDX | git 作者 |
|---|---|---|---|
| `kindle/magpie.koplugin/_meta.lua` | `70da69047ac255faf80546c512d3deff04cfa161:kindle/magpie.koplugin/_meta.lua` | none in file | `blizhan <parcevalry@gmail.com>`（该修订的唯一作者与提交者） |
| `kindle/magpie.koplugin/main.lua` | `70da69047ac255faf80546c512d3deff04cfa161:kindle/magpie.koplugin/main.lua` | none in file | 同上 |
| `kindle/magpie.koplugin/dashview.lua` | `70da69047ac255faf80546c512d3deff04cfa161:kindle/magpie.koplugin/dashview.lua` | none in file | 同上 |
| `kindle/magpie.koplugin/office.lua` | `70da69047ac255faf80546c512d3deff04cfa161:kindle/magpie.koplugin/office.lua` | none in file | 同上 |
| `kindle/magpie.koplugin/projcost.lua` | `70da69047ac255faf80546c512d3deff04cfa161:kindle/magpie.koplugin/projcost.lua` | none in file | 同上 |

`git rev-parse HEAD:<path>` 的 blob 只标识字节，不是许可证：

| 路径 | blob | 该提交新增行数 |
|---|---|---|
| `_meta.lua` | `acc31a8963c21fc766a4bc71fdfb42ef2c08edea` | 6 |
| `main.lua` | `2337d3099c3a03850c0cb49873be6b68879de483` | 1624 |
| `dashview.lua` | `e771b9d655c84733cd691bc5babf913f717d19e6` | 1692 |
| `office.lua` | `f2539e9e03df2a550c97d5cef6b344d3131d3d23` | 337 |
| `projcost.lua` | `1fa7a04fa803f2bcd6c2e5c77de0d6ee1f5bc521` | 130 |

没有第二位 git 作者。git 作者名与目标 `LICENSE` 上的名字相同，这不被当作授权。

## 2. MIT 再分发依据

目标仓库根目录 `LICENSE` 已读。标题是 `MIT License`，版权行是 `Copyright (c) 2026 blizhan`。正文允许获得副本的人使用、复制、修改、合并、发布、分发、再许可和出售本软件；条件是所有副本或实质部分保留上述版权声明和许可声明；软件按 “AS IS” 提供，不提供适销性、特定用途适用性或不侵权等明示或默示担保。

这份文件只出现在目标仓库。它没有点名五个来源文件，也没有记载来源仓库的授权，因此不能单独许可这些来源文件。

来源仓库根目录列表只有 `.git`、`.gitignore` 和 `kindle/`。在仓库根执行 `find . -maxdepth 5`，匹配 `LICENSE*`、`LICENCE*`、`COPYING*`、`NOTICE*`、`COPYRIGHT*`、`UNLICENSE*`，无输出。`git ls-files` 用同一组文件名过滤，无输出。`kindle/README.md` 中没有许可、版权或 SPDX 字样。

适用性：UNCONFIRMED。不得把五个来源文件写成 MIT 许可，也不得把再分发写成已经获准。本地用户名、目录所有权和目标 `LICENSE` 的版权行都不是授权。

## 3. 宿主依赖与实际捆绑字节

`find kindle/magpie.koplugin -maxdepth 2 -type f` 只有七个文件：五个 Lua，以及不得迁入的 `.gitignore`、`apikey.txt.example`。没有子目录、vendor 目录、第三方 `.lua` / `.so` 或 NOTICE。下面的模块只出现在 `require` 中，对应字节不在插件目录里，因此不是本插件捆绑的第三方代码。只依赖宿主提供的库，不等于在包内再分发这些库。本次没有打开 KOReader 安装树，不能用这次检查证明宿主里一定带有这些模块。

| 模块 | 出现位置 | 捆绑情况 |
|---|---|---|
| `gettext` | `_meta.lua:1`，`main.lua:35`，`dashview.lua:34` | 未随插件目录提供 |
| `datastorage`（DataStorage） | `main.lua:22` | 未随插件目录提供 |
| `device`、`dispatcher`、`luasettings`、`logger`、`util` | `main.lua:23-27`、`main.lua:33-34`；`dashview.lua:14` 另 require `device` | 未随插件目录提供 |
| UI：`ui/widget/infomessage`、`ui/network/manager`、`ui/uimanager`、`ui/widget/container/widgetcontainer`、`ui/widget/multiinputdialog` | `main.lua:25-27`、`main.lua:31-32`、`main.lua:507` | 未随插件目录提供 |
| UI：blitbuffer、button、各类 container、font、geometry、gesturerange、horizontal/vertical group 与 span、linewidget、overlapgroup、progresswidget、size、textwidget、textboxwidget | `dashview.lua:9-34` | 未随插件目录提供 |
| `ffi/util`（template） | `main.lua:36` | 未随插件目录提供 |
| `ffi/blitbuffer` | `dashview.lua:9` | 未随插件目录提供 |
| `socket.http` | `main.lua:555`、`main.lua:642` | 未随插件目录提供 |
| `ssl.https` | `main.lua:556` | 未随插件目录提供 |
| `ltn12` | `main.lua:557`、`main.lua:643` | 未随插件目录提供 |
| `json` | `main.lua:558`、`main.lua:724`、`main.lua:744` | 未随插件目录提供 |
| `rapidjson`（可选） | `main.lua:739-744`：`decode_any` 先 `pcall(require, "rapidjson")`，有 `decode` 才使用，否则调用 `require("json").decode` | 未随插件目录提供 |

`office.lua` 与 `projcost.lua` 全文没有 `require`。`office.lua:4` 写明纯 Lua、以便用普通 luajit 测试。`projcost.lua:3` 同样写明纯 Lua。

插件自身引用不是第三方捆绑：`main.lua:28-30` require `dashview`、`office`、`projcost`。

插件目录里没有实际捆绑的第三方代码文件。

不得迁入的同目录文件：

- `.gitignore`：2 行、27 字节。内容是两个本地密钥文件名 `apikey.txt` 与 `gateway-key.txt`，没有密钥值，也没有端点。
- `apikey.txt.example`：3 行、187 字节，已读，只用于分类。example file contains a non-fictional-looking value; not copied.

## 4. 文件内声称的派生关系

`office.lua:5-7` 的头注释写明：输入是 `@magpie-community/page-agent-office` 的 `page/live.js` 赋值文本；状态映射 follows 该插件 `page/model.js` 的 `state()`。同一包名字符串在 `main.lua:59` 记为 `OFFICE_PLUGIN`。`office.lua:8-12` 用文字列出 phase 到 need / work / done 的对照。`Office.classify`（`office.lua:157` 起）用 Lua 实现这组分类，并加上超时后的副状态；这里没有嵌入 JavaScript 源码。

`find . -maxdepth 5 -name model.js` 无输出，插件目录也没有该文件。因此看不到 `model.js` 的许可证，也不能在此判定这段 Lua 是否构成需要单独授权的派生作品。`kindle/README.md:70` 和 `kindle/design-concurrency/README.md:113` 复述了「状态映射同 model.js」，这两处同样不是许可证。

`_meta.lua` 没有头注释。`main.lua:1-20`、`dashview.lua:1-7`、`projcost.lua:1-9` 只描述本插件的看板、界面和按项目费用计算，没有 SPDX，也没有「摘自某文件」的声明。未发现整段第三方片段。没有这种声明，不等于已经证明原创。

## 5. 权利人仍须回答的问题

以下各项工具无法代替权利人回答。本记录不发起询问。

1. 五个文件各自的版权人是谁？文件内没有版权声明。git 只证明修订 `70da69047ac255faf80546c512d3deff04cfa161` 的作者和提交者是 `blizhan <parcevalry@gmail.com>`，以及这些行在该提交中一次性加入。这不能确定版权归属。
2. 该权利人是否有权把上表五个 blob 再许可，并按目标 `LICENSE` 的 MIT 条件再分发？授权若存在，是否覆盖每个文件的全部行？
3. `office.lua` 相对于 `@magpie-community/page-agent-office` 的 `page/model.js` 是否为派生作品？若是，该上游文件的许可证是什么，是否允许这种重新实现，并允许改以目标 MIT 分发？该 JS 文件不在来源仓库中。
4. 是否还有 git 历史以外的贡献者、生成内容，或抄自 KOReader 示例及其他项目但未在文件中署名的片段？
5. 来源仓库没有 LICENSE、COPYING 或 NOTICE。在有明确授权之前，这些文件是否仍不得再分发？

第 5 节的问题已由本节之后的权利人选择回答，不再阻止迁入。

G-LICENSE: 迁入授权已确认；安装包内许可证尚未随 ZIP 复核。

## 6. T004 授权缺口处理

检查日期：2026-11-10。对照第 5 节，检索了可获得的证据，没有发现可核对的再分发授权：

- 来源提交 `70da69047ac255faf80546c512d3deff04cfa161` 的说明只有标题，正文为空，没有许可或权利人声明。
- 来源仓库没有 LICENSE、COPYING、NOTICE，五个文件内也没有 SPDX 或版权行。
- 目标 `LICENSE` 未点名这些文件。git 作者名与版权行同为 blizhan，只证明提交身份，不是授权。
- 本次实施指令没有单独给出版权归属或 MIT 再许可声明。

上述文件证据本身仍不是授权。2026-11-10 实施会话中，权利人明确选择「授权全部五个文件」：其本人是唯一权利人，授权按目标仓库 MIT（`LICENSE`，Copyright (c) 2026 blizhan）迁入五个文件的全部行；并说明 `office.lua` 的状态分类是独立实现，不需要 `page/model.js` 上游另行许可。据此确认目标 MIT 适用于已迁入内容。

## 7. T005 迁入范围

来源修订：`70da69047ac255faf80546c512d3deff04cfa161`。未复制来源 Git 历史、`apikey.txt.example`、来源 `.gitignore`、截图或运行配置。

迁入时剔除了私人默认地址和设备绝对路径。工作区与来源 blob 对比（`git hash-object` 对 `git rev-parse HEAD:kindle/magpie.koplugin/<file>`）：

| 文件 | 迁入时结果 |
|---|---|
| `dashview.lua` | 与 blob `e771b9d655c84733cd691bc5babf913f717d19e6` 相同 |
| `office.lua` | 与 blob `f2539e9e03df2a550c97d5cef6b344d3131d3d23` 相同 |
| `projcost.lua` | 与 blob `1fa7a04fa803f2bcd6c2e5c77de0d6ee1f5bc521` 相同 |
| `_meta.lua` | 已改。来源 blob `acc31a8963c21fc766a4bc71fdfb42ef2c08edea` 没有 version；现为 `0.4.0`，与迁入前用户代理里的唯一版本字符串一致 |
| `main.lua` | 已改。来源 blob `2337d3099c3a03850c0cb49873be6b68879de483`。配置改为设置目录 `magpie/` 下四个文件，不再包含私人默认地址或设备绝对路径 |

迁入时对五个运行文件做过私人部署地址和设备绝对路径的字面检查。后续复核发现公开审计文字的否定句仍复述了这两类私人值；本轮已改为类别描述，并重新扫描拟公开历史、文件快照及修正候选，结果见 [发布就绪记录](release-readiness.md#当前审查修复与验证)。上表保留迁入时的字节比较；审查修复又修改了 `main.lua` 与 `dashview.lua`，不再将当前 `dashview.lua` 视为与来源 blob 相同。

G-LICENSE: 来源再分发授权已确认。修正候选 `dist/review-fix/magpie.koplugin-0.4.0.zip`（SHA-256 `ccded365a093764e8231102d9be9d8e9e598b7e91e2b0444d13f31e0cddb0073`）含目标 MIT `LICENSE`。原根目录候选保留为历史产物。用户实机正常显示已确认；未覆盖的运行场景和独立验收尚未完成，整体发布判定见 [发布就绪记录](release-readiness.md)。
