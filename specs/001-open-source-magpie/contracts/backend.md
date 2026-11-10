# Backend Consumer Contract

这是现有客户端所消费接口的记录，用于保留行为和构造合成验证输入；不是新增后端 API，也不承诺任意 Magpie 版本都兼容。实际版本须随运行验收记录。协议来源为原插件 `main.lua`、`office.lua`、`projcost.lua`；公开 Web 登录证据固定于 Magpie commit `4869d0c9665e1a815fee3a1a4d67a575e0baab93`。

## Gateway

所有请求携带 `Authorization: Bearer <用户自己的 key>`，只接受数据响应 HTTP 200；当前数据解析要求 JSON table。不得记录 Authorization。没有 URL/key 时不发请求。

|请求|最小消费字段|页面与语义|
|---|---|---|
|`GET /v1/magpie/usage?period=today`|cost、calls、input、output、cache_read；可选 decode_out、decode_ms、sessionCount、ttft_ms、timed；series 数组|今日汇总、速度与趋势|
|`GET /v1/magpie/usage?period=7d` 或 `30d`|同上；`series[].label,time,cost,calls`|趋势周期|
|`GET /v1/magpie/concurrency`|requests、waiting、tools|在飞汇总|
|`GET /v1/magpie/quotas?kept=1`|`data[]` 内 name/provider、plan、last、user、windows|配额窗口|
|`GET /v1/magpie/quotas/cards`|同上|保留现有主配额请求失败时的回退|

`windows[]` 消费 name/pool、used/remaining、resetsAt；优先 5h，再周窗口，否则首个窗口。只有 remaining 时按 `100 - remaining` 展示。配额权限拒绝必须与空配额区分；显示数据由 key 权限决定，不扩大授权。

保留既有缺字段的 0/破折号显示逻辑，但请求失败不能伪装成完整成功的零用量结果。错误类别至少区分缺配置、network、HTTP status、bad_json。错误中不包含请求 URL、key、响应正文或原始异常中的敏感内容。

## Web 认证

1. 对用户明确指定的 Web 基地址请求 `GET /?k=<web-key>`；禁止自动跟随跳转。
2. 固定官方源码中，正确 key 设置 `magpie_web_<port>` cookie 并返回 303，错误返回 401。客户端接受成功状态与匹配 cookie；拒绝没有 cookie 的响应和失败状态，不因某个错误响应含 cookie 而认为认证成功。
3. 后续请求携带 Cookie，只在内存保存；401 时重新认证并重试一次，第二次失败直接报错。不得输出含 `k` 的 URL 或 Set-Cookie。
4. 现有客户端使用 HTTP；该契约不新增 HTTPS 支持。查询参数会经过服务器，日志风险必须在使用说明披露，不能宣称插件已控制服务器日志。

## Web 数据

|请求|消费形状|约束与恢复|
|---|---|---|
|`GET /api/sessions/stats?days=1`、`7`、`30`|`days[].date` 与 `days[].usage[].cwd,cost`|days 必须为 table；项目按目录末级名合并，无 cwd 计未归属|
|`GET /api/plugin-pages`|顶层数组；项含 name、key、url|name 为 `@magpie-community/page-agent-office` 或 key 为 `plugin-agent-office`；url 必须为字符串|
|`GET <发现目录>/live.js`|裸 JSON 或 JS 包装内的对象；`sessions[]`|404 清空路径并重新发现一次；sessions 必须为 table|

Office 会话最小字段为 project 或 cwd、phase、updated、touched；状态推断可能使用 inflight 与 last.outcome/at。详情可用 agent、model、title、step、turns、context、contextWindow、subagent、source。时间按 epoch 毫秒，响应 Date 可校正当前时间。

保持来源现有目录发现方式；将 discovery URL 约束在已配置 Web 服务的路径内，不把 cookie 转发到其他主机。遇到其他 origin 的链接显示不支持的发现结果，不自动连接；这防止公开客户端把管理 cookie 发给无关目标。该条件须用真实来源的发现结果及合成越界结果验证。

## 缓存与恢复

各数据项独立更新。一次失败保留该项旧值并标记过期；其他成功项继续更新。首次失败没有伪造成功快照。连接身份变化时清理对应缓存，避免把旧服务的数据显示为新服务数据。

保留现有完整刷新获取所有 Gateway 项、Web 根据页面选择 stats 或 Office 的行为。不新增后台内容抓取、重试循环或遥测。

## 合成场景与真实验收

合成服务仅用于开发测试，明确使用 loopback、虚构 key 和人工数据，不随插件打包、不作为用户可用后端。

必需场景：正常数据；空数组；缺必需容器；HTTP 错误；非法 JSON；Web 登录 303 + cookie；错误 key 401；一次认证恢复及第二次失败停止；Office 未安装；Office 路径 404 后重新发现；外部 origin 的发现链接不泄漏 cookie。真实服务再分别验证用量、配额权限、项目费用与 Office，记录实际版本。

来源版本没有固定公开稳定的 Web stats/Office API 承诺；若某发行不匹配，应记录兼容范围和失败证据，不以静态源码相似性宣布兼容。
