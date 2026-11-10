# Configuration and User Interface Contract

本契约定义开源整理后的目标行为；源插件的旧位置与回退规则不属于新版本兼容承诺。对应 FR-001 至 FR-008。

## 配置接口

基目录为 `DataStorage:getSettingsDir() .. "/magpie/"`。示例仅使用 `http://gateway.example.invalid:8080`、`http://web.example.invalid:3430` 等不可用虚构域名和 `EXAMPLE_ONLY_NOT_A_REAL_KEY`，不能提供会连接维护者服务的默认值。

|文件|是否必需|用途|
|---|---|---|
|base_url.txt|Gateway 功能必需|用户自己的 Gateway 基地址|
|gateway-key.txt|Gateway 功能必需|用户专用 Gateway key，权限影响用量与配额可见性|
|web_url.txt|Web 功能必需|用户明确提供的 Web 基地址；不推导端口|
|web-key.txt|Web 功能必需|实际 Web 进程的管理 key，至少 16 字符|

读取首个 trim 后非空且不以 `#` 起始的行。空文件、只有注释或不可读视为未配置；不在错误中回显内容。地址必须是支持的 scheme 和非空主机，不允许 userinfo、query、fragment；移除尾部 `/`。Gateway 支持现有 HTTP/HTTPS transport，但不得将其现有 TLS 行为宣传为证书已验证。Web 仅声明现有 HTTP transport；不支持的 scheme 显示明确说明，不尝试降级连接。

每次用户刷新或定时刷新前更新连接配置；如果 URL/key 变化，清除对应旧缓存、Web cookie 及发现路径，再请求新目标。缺 URL 或 key 时不发送该类请求。Gateway 与 Web 独立判断，附加功能缺失不阻止已配置功能展示。

工具菜单的网关地址编辑入口写入同一个 `base_url.txt`；写入失败须提示失败，不显示“已保存”。不增加第二套配置来源。Web key 只能由用户文件提供，界面不显示 key 内容。配置目录与文件创建应使用平台可支持的用户私有权限；FAT 等不支持权限的设备须说明依赖设备访问控制，不能声称权限位提供了保护。

## 干净切换与升级

- 首次加载新版本时删除 `magpie.lua` settings 中旧 `api_key` 与 `base_url` 字段，再保存非敏感偏好；不从旧值自动建立连接。
- 不再读取旧 Kindle 外部目录、插件内 `apikey.txt` 或 settings 凭据。保留这些 fallback 不符合本契约。
- 用户按 README 将自己的值手动迁移到上述文件；文档提醒旧文件、备份及同步副本仍可能含秘密，新版本不会替用户删除这些文件。
- 升级只替换插件目录；`settings/magpie/` 与非敏感偏好保留。卸载插件默认保留这些配置，彻底移除须显式删除专用目录和 `settings/magpie.lua`；不删除其他 KOReader 设置。
- 对来源仓库的原始配置和文件不做修改。

## 用户入口与页面

保持工具菜单的 Magpie 看板入口、打开/刷新动作及三个页面：今日用量、在飞、趋势。保留 `magpie_open`、`magpie_refresh` Dispatcher 动作、左右切页、手动刷新和项目详情。README 以真实目标版本菜单文字为准；本功能不要求 UI 双语改造。

无配置时可打开插件并看到所需配置及位置，不应崩溃或显示虚假成功数据。联网失败标记错误；有旧数据时可继续显示但注明过期。权限不足、空配额、Office 未启用等情况分别给出可执行提示。用户错误信息只包含类别、状态码和非敏感操作建议。

60 秒默认自动刷新保持不变；完整刷新继续请求各 Gateway 项，Web 按当前页面需求请求。关闭与挂起停止计时；重新打开/恢复不能重复注册多个计时器。保留原有一次 401 重认证和一次 Office 404 重新发现，不新增通用重试策略。

## README 与 Dev 接口

英文 `README.md` 和中文 `README.zh-CN.md` 顶部互链，均具有 Feature / Install / Usage / Dev。安装包含发布包根目录、放置位置、完全重启与菜单入口；Usage 包含自备服务、key 权限、配置、成功判据、失败与数据保留；Dev 包含合成数据测试、真实宿主 smoke、需要自备后端的场景和脱敏报告要求。

文档必须说明 Web key 是管理凭据、现有传输限制，以及项目名/标题/截图可能包含个人内容。不得建议将真实 key 放进公开 issue、命令示例、截图或调试附件。演示素材只采用人工合成数据。

## 公开取得后端的操作契约

1. 从 [Magpie 官网](https://usemagpie.ai/#cli) 安装官方发行；按 [共享说明](https://usemagpie.ai/docs/remote#share) 开启局域网共享，使用 Address 行给出的可达地址。
2. 在 Gateway keys 界面或通过 `magpie gateway-key add "Kindle"` 创建自己的 key。需要配额时按官方说明授予合适的可见权限；不保证受限 key 具有全局数据。
3. 需要 Web 功能时，按 [官方 Web CLI](https://github.com/yetone/magpie/blob/4869d0c9665e1a815fee3a1a4d67a575e0baab93/internal/cli/web_cli.go) 设置个人 `MAGPIE_WEB_KEY`，使用 `magpie web --addr 0.0.0.0:3430 --no-open`。设备填写可达主机地址，不填写 `0.0.0.0`。已有 Web/daemon 实例可能被复用，必须取得实际实例的 key。
4. 按官方插件安装机制启用 Agent Office。来源包证据要求 Magpie ≥0.1.1318；其实际安装方式与兼容版本必须在实施验收时确认。registry 调查返回 404，因此不能把 npm 安装成功写成已确认事实。若公共包安装失败，按官方仓库提供的源码安装流程完成并记录；若无可复现方式，完整 Office 功能发布验收保持阻塞，不删除该功能以绕过门禁。
