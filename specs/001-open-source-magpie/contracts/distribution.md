# Distribution and Publication Contract

对应 FR-002、FR-005 至 FR-012。此契约定义待实现工具与公开材料；本次规划没有生成发布包或执行发布。

## 仓库与安装包

仓库根目录保留五个 Lua 文件和标准 README。发布 ZIP 只有一个 `magpie.koplugin/` 根目录，其允许成员为：

```text
magpie.koplugin/_meta.lua
magpie.koplugin/main.lua
magpie.koplugin/dashview.lua
magpie.koplugin/office.lua
magpie.koplugin/projcost.lua
magpie.koplugin/LICENSE
magpie.koplugin/README.md
magpie.koplugin/README.zh-CN.md
```

源码 `_meta.lua` 的 name 固定为 `magpie`，version 与所选发行版本一致。首个版本在实施时由维护者已有发布约定或版本历史确定；打包工具不替维护者自动加版本。ZIP 的安装目录固定为 `magpie.koplugin`，不随 tag 改名。

## 待实现的本地命令接口

|命令|输入与输出|失败行为|
|---|---|---|
|`sh scripts/package.sh VERSION`|在仓库根运行；VERSION 是已写入 `_meta.lua` 的版本；生成 `dist/magpie.koplugin-VERSION.zip`|缺允许文件、版本格式非法、版本不匹配、输出已存在或归档失败时非零退出；不打印配置内容|
|`luajit tests/run.lua`|运行人工数据的行为回归测试；使用临时隔离设置目录，不读真实设备配置|失败非零退出，输出场景名和脱敏断言信息|

脚本只复制允许成员，不使用全仓库递归拷贝；输出不得为允许目录以外的路径，版本参数不得包含路径分隔符。临时工作目录必须独立，结束后清理。已有同名归档不被覆盖，候选变化使用新的版本或由操作者明确移除旧产物。

这些命令将在实施阶段创建；规划阶段运行它们不存在的入口不构成有效验收。`tests/run.lua` 不作为真实设备 smoke 的替代。

## 公开材料与安全检查

- `.gitignore` 排除所有真实配置文件、密钥、快照、渲染输出和 `dist/`；`.example` 只允许人工构造内容。忽略规则不等于发布安全检查。
- 不导入原仓库历史；当前目标仓库拟公开的历史仍须完整检查。不得擅自重写或删除已有历史；发现问题时阻止发布并制定具体处置。
- 使用 Gitleaks v8 的 redacted 输出扫描拟公开历史、候选工作树与最终解包内容；记录工具版本、范围和结果。工具未安装或运行失败即未完成扫描，不能当“零命中”。
- 人工检查扫描器不可靠识别的私人部署地址、目录、邮箱域、设备标识、图片与业务内容；不将被发现的值复制进报告。
- 开发规划、研究与证据文件若随仓库公开同样纳入检查，不能因为未打入 ZIP 而豁免。
- 授权记录确认五个源文件的来源及 MIT 再分发权利；新增或捆绑第三方素材必须提供适用 notice。只依赖宿主提供的库不等同于在包中再分发它们。

## 发布门禁

|门禁|通过条件|当前规划状态|
|---|---|---|
|G-LICENSE|来源权利和实际包内许可证已确认，无未解决问题|BLOCKED：缺来源授权证据|
|G-PRIVACY|所有公开材料类别检查完成，未解决发现为零|NOT RUN|
|G-RUNTIME|最终 ZIP 干净安装；所有保留能力和错误场景在真实宿主通过|NOT RUN|
|G-DOCS|双语四节及关键步骤语义核对完成，独立用户验收达标|NOT RUN|
|G-COMMUNITY|五渠道评估有来源，至少一路材料完整，未夸大兼容或收录|研究完成，提交材料待实施|

任一适用门禁不通过时，发布检查结果必须是 ERROR/BLOCKED，不能称为 release-ready。计划设计完成不是发布检查通过。对外发布或社区提交仍需用户的明确指令。

## 社区提交材料

`docs/community.md` 记录五渠道、核验日期和一手链接，并准备以下可直接审阅的内容：

- 真实 canonical repository URL、名称、用途和分类；URL 尚未确定时从实际发布目标核实，不能猜测。
- 简洁英文介绍及中文对应说明：KOReader 上的 Magpie 用量、配额、项目状态和趋势看板，明确外部服务依赖。
- Awesome KOReader 现有合适分类下的一行条目、作者身份披露、安装与兼容性证据链接。
- 自动发现所需仓库命名/topic 信息；缺失索引时再依据其规则准备补录，不承诺发现时限。
- contrib 可选路径及其可工作上游和兼容性要求；AppStore/Storefront 安装证据与收录状态分别列出。

README 不引用未核验插件数量，不把 `koreader/contrib` 收录解释为 KOReader 官方维护承诺。真实商店安装验证前只称“按已调查格式准备”，不能称已兼容。
