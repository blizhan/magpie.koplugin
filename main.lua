--[[--
Magpie dashboard plugin for KOReader (Kindle Basic 600×800).

Read-only LAN GETs:
  GET /v1/magpie/usage?period=today
  GET /v1/magpie/concurrency
  GET /v1/magpie/quotas?kept=1  (soft-fail; optional /quotas/cards)

在飞 tab (by project): magpie web :3430 with the web key —
  GET /?k=<web key> → session cookie (memory only)
  GET /api/plugin-pages → agent-office plugin path (re-looked-up on 404)
  GET <plugin path>/live.js → sessions grouped by project (office.lua)

UI: MagpieDash nav-v3 — usage KPI / concurrency / trend; top clock+refresh, bottom 3 tabs.
Auto-refresh 60s while any dashboard page is open.

Auth: Gateway key and base URL from the KOReader settings directory magpie/
base_url.txt and gateway-key.txt. Web key and URL from web-key.txt and web_url.txt.
Do not log/display either key. Do not POST. Do not change Magpie config.
]]

local DataStorage = require("datastorage")
local Device = require("device")
local Dispatcher = require("dispatcher")
local InfoMessage = require("ui/widget/infomessage")
local LuaSettings = require("luasettings")
local NetworkMgr = require("ui/network/manager")
local MagpieDash = require("dashview")
local Office = require("office")
local ProjCost = require("projcost")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
local util = require("util")
local _ = require("gettext")
local T = require("ffi/util").template

local Magpie = WidgetContainer:extend{
    name = "magpie",
    is_doc_only = false,
}

Magpie.PAGE_USAGE = 1
Magpie.PAGE_CONCURRENCY = 2
Magpie.PAGE_TREND = 3
Magpie.AUTO_REFRESH_SEC = 60

local PAGES = {
    [Magpie.PAGE_USAGE] = { name = "usage", model = "buildUsageModel" },
    [Magpie.PAGE_CONCURRENCY] = { name = "concurrency", model = "buildConcurrencyModel" },
    [Magpie.PAGE_TREND] = { name = "trend", model = "buildTrendModel" },
}

Magpie.default_settings = {
    user_agent = "magpie-koreader/0.4.0",
    auto_refresh_sec = 60,
}

local CONFIG_FILE = {
    base_url = "base_url.txt",
    gateway_key = "gateway-key.txt",
    web_url = "web_url.txt",
    web_key = "web-key.txt",
}
local OFFICE_PLUGIN = "@magpie-community/page-agent-office"

local function trim(s)
    if not s then return nil end
    return (s:match("^%s*(.-)%s*$"))
end

local function read_first_line(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*all")
    f:close()
    if not content then return nil end
    for line in content:gmatch("[^\r\n]+") do
        local t = trim(line)
        if t and t ~= "" and not t:match("^#") then
            return t
        end
    end
    return nil
end

local function load_lfs()
    for _, name in ipairs({ "libs/libkoreader-lfs", "lfs" }) do
        local ok, lfs = pcall(require, name)
        if ok and type(lfs) == "table" then return lfs end
    end
    return nil
end

-- scheme + non-empty host. No userinfo, query, or fragment. Web stays http.
local function validate_url(raw, role)
    local s = trim(raw)
    if not s then return nil, "missing" end
    if s:find("%s") or s:find("#", 1, true) or s:find("?", 1, true) or s:find("@", 1, true) then
        return nil, "bad_url"
    end
    local scheme, rest = s:match("^(https?)://(.+)$")
    if not scheme or rest == "" or rest:sub(1, 1) == "/" then
        return nil, "bad_url"
    end
    if role == "web" and scheme ~= "http" then
        return nil, "unsupported_scheme"
    end
    if role == "gateway" and scheme ~= "http" and scheme ~= "https" then
        return nil, "unsupported_scheme"
    end
    rest = rest:gsub("/+$", "")
    local hostport = rest:match("^([^/]+)")
    if not hostport or hostport == "" or hostport:sub(1, 1) == ":" then
        return nil, "bad_url"
    end
    local host = hostport:match("^([^:]+)")
    if not host or host == "" then return nil, "bad_url" end
    return scheme .. "://" .. rest, nil
end

local function log_path(path)
    path = tostring(path or "")
    local q = path:find("?", 1, true)
    if q then path = path:sub(1, q - 1) .. "?<redacted>" end
    return path
end

function Magpie:configDir()
    return DataStorage:getSettingsDir() .. "/magpie/"
end

function Magpie:configPath(kind)
    return self:configDir() .. CONFIG_FILE[kind]
end

function Magpie:ensureConfigDir()
    local dir = self:configDir()
    local lfs = load_lfs()
    if lfs and lfs.mkdir then
        local acc = ""
        local bare = dir:gsub("/+$", "")
        for part in bare:gmatch("[^/]+") do
            acc = (acc == "" and part:match("^/") == nil and (bare:sub(1, 1) == "/" and "/" or "")) or acc
            if acc == "" or acc == "/" then
                acc = (bare:sub(1, 1) == "/" and "/" or "") .. part
            else
                acc = acc .. "/" .. part
            end
            lfs.mkdir(acc)
        end
        if lfs.chmod then pcall(lfs.chmod, dir:gsub("/+$", ""), 448) end
    end
    return dir
end

function Magpie:writeConfigLine(kind, value)
    self:ensureConfigDir()
    local path = self:configPath(kind)
    local f = io.open(path, "w")
    if not f then return false, "write_failed" end
    local ok = f:write(value, "\n")
    local closed = f:close()
    if not ok or not closed then return false, "write_failed" end
    local lfs = load_lfs()
    if lfs and lfs.chmod then pcall(lfs.chmod, path, 384) end
    return true
end

function Magpie:readConfigValue(kind, role)
    local line = read_first_line(self:configPath(kind))
    if kind == "base_url" or kind == "web_url" then
        return validate_url(line, role)
    end
    if not line then return nil, "missing" end
    return line, nil
end

function Magpie:clearGatewayCache()
    local c = self.cache
    if not c then return end
    c.usage, c.trend, c.concurrency, c.quotas = nil, nil, nil, nil
    c.trend_period = nil
    c.usage_err, c.trend_err, c.concurrency_err, c.quotas_err = nil, nil, nil, nil
    c.fetched_at, c.fetched_hm = nil, nil
    c.trend_fetched_at, c.trend_fetched_hm = nil, nil
    c.conc_fetched_at, c.conc_fetched_hm = nil, nil
    c.fail_at, c.fail_msg, c.trend_fail_msg, c.conc_fail_msg = nil, nil, nil, nil
end

function Magpie:clearWebState()
    if self.web then
        self.web.cookie = nil
        self.web.office_path = nil
    end
    local c = self.cache
    if not c then return end
    c.office, c.office_now_ms, c.office_hm, c.office_err, c.office_at = nil, nil, nil, nil
    c.pc, c.pc_err = {}, {}
end

function Magpie:reloadConnection()
    self.conn = self.conn or {}
    local g_url, g_err = self:readConfigValue("base_url", "gateway")
    local g_key = select(1, self:readConfigValue("gateway_key"))
    local w_url, w_err = self:readConfigValue("web_url", "web")
    local w_key, w_key_read_err = self:readConfigValue("web_key")
    local w_key_err = nil
    if w_key and (#w_key < 16 or not w_key:match("^[%w%-%._~]+$")) then
        w_key, w_key_err = nil, "bad_key"
    elseif not w_key then
        w_key_err = w_key_read_err
    end
    local gid = (g_url and g_key) and (g_url .. "\0" .. g_key) or ""
    local wid = (w_url and w_key) and (w_url .. "\0" .. w_key) or ""
    if self.conn.gateway_id and self.conn.gateway_id ~= gid then
        self:clearGatewayCache()
    end
    if self.conn.web_id and self.conn.web_id ~= wid then
        self:clearWebState()
    end
    self.conn.gateway_url = g_url
    self.conn.gateway_key = g_key
    self.conn.gateway_err = (g_url and g_key) and nil or (g_err or "missing")
    self.conn.web_url = w_url
    self.conn.web_key = w_key
    self.conn.web_err = (w_url and w_key) and nil or (w_key_err or w_err or "missing")
    self.conn.gateway_id = gid
    self.conn.web_id = wid
    return self.conn
end

function Magpie:gatewayBlockReason()
    local c = self.conn or {}
    if c.gateway_url and c.gateway_key then return nil end
    if c.gateway_err == "bad_url" or c.gateway_err == "unsupported_scheme" then
        return _("网关地址无效。使用 http 或 https，不要写账号、查询参数或片段。文件在设置目录 magpie/base_url.txt。")
    end
    return _("缺少网关配置。在设置目录 magpie/ 写入 base_url.txt 和 gateway-key.txt。")
end

function Magpie:webBlockReason()
    local c = self.conn or {}
    if c.web_url and c.web_key then return nil end
    if c.web_err == "unsupported_scheme" then
        return _("Web 目前只支持 http。请修改设置目录 magpie/web_url.txt。")
    end
    if c.web_err == "bad_url" then
        return _("Web 地址无效。不要写账号、查询参数或片段。文件在设置目录 magpie/web_url.txt。")
    end
    if c.web_err == "bad_key" then
        return _("web-key.txt 至少 16 位，只能有字母、数字和 - . _ ~。")
    end
    return _("缺少 Web 配置。在设置目录 magpie/ 写入 web_url.txt 和 web-key.txt。Gateway 用量不受影响。")
end

function Magpie:loadPreferences()
    self.settings_file = LuaSettings:open(DataStorage:getSettingsDir() .. "/magpie.lua")
    local saved = self.settings_file:readSetting("settings")
    local src = type(saved) == "table" and saved or {}
    local dirty = src.api_key ~= nil or src.base_url ~= nil
    local kept = {}
    for k, v in pairs(src) do
        if k ~= "api_key" and k ~= "base_url" then kept[k] = v end
    end
    self.settings_extra = kept
    local ua = kept.user_agent
    if type(ua) ~= "string" or ua == "" then ua = self.default_settings.user_agent end
    self.settings = {
        user_agent = ua,
        auto_refresh_sec = tonumber(kept.auto_refresh_sec) or Magpie.AUTO_REFRESH_SEC,
    }
    if dirty then self:saveSettings() end
end


-- whole dollars everywhere: $53 · $1,392 · <$1
local fmt_money = ProjCost.money

local function fmt_int(n)
    n = tonumber(n) or 0
    local a = math.abs(n)
    if a >= 1000000 then
        return string.format("%.1fM", n / 1000000)
    elseif a >= 1000 then
        return string.format("%.1fK", n / 1000)
    end
    return tostring(math.floor(n + 0.5))
end

-- KPI Token: input+output (cache shown separately as hit%).
local function tokens_io(row)
    if type(row) ~= "table" then return 0 end
    return (tonumber(row.input) or 0) + (tonumber(row.output) or 0)
end

local function cache_hit_pct(row)
    if type(row) ~= "table" then return nil end
    local cr = tonumber(row.cache_read) or 0
    local inn = tonumber(row.input) or 0
    local den = cr + inn
    if den <= 0 then return nil end
    return (cr / den) * 100
end

local function decode_tok_s(row)
    if type(row) ~= "table" then return nil end
    local ms = tonumber(row.decode_ms) or 0
    local out = tonumber(row.decode_out) or 0
    if ms <= 0 then return nil end
    return (out / ms) * 1000
end

local function avg_ttft_ms(row)
    if type(row) ~= "table" then return nil end
    local timed = tonumber(row.timed) or 0
    local ttft = tonumber(row.ttft_ms) or 0
    if timed <= 0 then return nil end
    return ttft / timed
end

local function series_day_label(label, time_s)
    label = tostring(label or "")
    -- "Oct 28" / "00" / "Nov 3" → prefer day number
    local d = label:match("(%d+)$")
    if d then return d end
    if time_s then
        local dd = tostring(time_s):match("%-(%d%d)T") or tostring(time_s):match("%-(%d%d)$")
        if dd then return tostring(tonumber(dd)) end
    end
    if #label > 4 then return label:sub(1, 4) end
    return label
end


-- Kindle clock is typically UTC; show Asia/Shanghai wall time.
local function shanghai_now()
    return os.time() + 8 * 3600
end

local function shanghai_hm(ts)
    ts = ts or shanghai_now()
    return os.date("!%H:%M", ts)
end

local function shanghai_ymd_hm(ts)
    ts = ts or shanghai_now()
    return os.date("!%Y-%m-%d %H:%M", ts)
end

local function parse_iso_to_epoch(s)
    if type(s) ~= "string" or s == "" then return nil end
    local y, mo, d, H, M, S = s:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)[T ](%d%d):(%d%d):(%d%d)")
    if not y then return nil end
    y, mo, d, H, M, S = tonumber(y), tonumber(mo), tonumber(d), tonumber(H), tonumber(M), tonumber(S)
    local offset_sec = 0
    local z = s:match("Z$")
    local oh, om = s:match("([%+%-]%d%d):?(%d%d)$")
    if z then
        offset_sec = 0
    elseif oh then
        local sign = (oh:sub(1, 1) == "-") and -1 or 1
        offset_sec = sign * (math.abs(tonumber(oh)) * 3600 + (tonumber(om) or 0) * 60)
    else
        -- bare local — treat as Asia/Shanghai
        offset_sec = 8 * 3600
    end
    -- os.time interprets table as local device time; build as if UTC then adjust.
    local utc_guess = os.time({
        year = y, month = mo, day = d,
        hour = H, min = M, sec = S,
        isdst = false,
    })
    if not utc_guess then return nil end
    -- Device local may already be UTC. Convert ISO instant → epoch:
    -- epoch = utc_guess_as_if_local - device_utc_offset, but Kindle is UTC so utc_guess is wrong
    -- when table is "local". Safer: treat constructed time as UTC components:
    local as_utc = os.time({
        year = y, month = mo, day = d,
        hour = H, min = M, sec = S,
        isdst = false,
    })
    -- If device TZ is UTC, as_utc equals epoch for those UTC fields when offset applied:
    -- actual_epoch = as_utc - offset_sec  if as_utc interpreted local==UTC for those numbers...
    -- On UTC device: os.time({UTC fields}) returns the epoch for that UTC wall. Then subtract?
    -- Example: 2026-11-03T17:10:00+08:00 → UTC 09:10 → epoch E.
    -- as_utc with H=17 on UTC device = epoch for 17:10 UTC which is wrong.
    -- Correct: as_utc_for_wall - offset_sec when os.time treats fields as local and local=UTC.
    return as_utc - offset_sec
end

local function fmt_reset_remain(resets_at)
    local epoch = parse_iso_to_epoch(resets_at)
    if not epoch then return "—" end
    -- compare using real epoch; shanghai_now is wall+8 offset hack — use os.time()
    local now = os.time()
    local sec = epoch - now
    if sec < 0 then sec = 0 end
    local d = math.floor(sec / 86400)
    local h = math.floor((sec % 86400) / 3600)
    local m = math.floor((sec % 3600) / 60)
    if d > 0 then
        return string.format("%dd%dh", d, h)
    elseif h > 0 then
        return string.format("%dh%02d", h, m)
    else
        return string.format("%dm", m)
    end
end

local function window_tag(name)
    local n = string.lower(tostring(name or ""))
    if n:find("5%s*h", 1) or n:find("5%s*hour", 1) then return "5h" end
    if n:find("7%s*d", 1) or n:find("7%s*day", 1) then return "7d" end
    if n:find("week", 1) or n == "wk" then return "wk" end
    if #n <= 6 then return tostring(name) end
    return tostring(name):sub(1, 6)
end

local function is_5h_window(name)
    local n = string.lower(tostring(name or ""))
    return n:find("5%s*h", 1) ~= nil or n:find("5%s*hour", 1) ~= nil
end

local function is_week_window(name)
    local n = string.lower(tostring(name or ""))
    return n:find("7%s*d", 1) ~= nil
        or n:find("7%s*day", 1) ~= nil
        or n:find("week", 1) ~= nil
        or n == "wk"
end

-- Band rule: show 5h if present else 7d/wk.
local function pick_primary_window(windows)
    if type(windows) ~= "table" then return nil end
    local week
    for _, w in ipairs(windows) do
        if type(w) == "table" then
            local name = w.name or w.pool or ""
            if is_5h_window(name) then
                return w
            end
            if not week and is_week_window(name) then
                week = w
            end
        end
    end
    if week then return week end
    for _, w in ipairs(windows) do
        if type(w) == "table" then return w end
    end
    return nil
end

function Magpie:intervalSec()
    return tonumber(self.settings.auto_refresh_sec) or Magpie.AUTO_REFRESH_SEC
end

function Magpie:init()
    self:loadPreferences()

    self.page = Magpie.PAGE_USAGE
    self.trend_period = "7d"   -- today | 7d | 30d
    self.trend_metric = "cost" -- cost | calls
    self.cache = {
        usage = nil,
        trend = nil,
        concurrency = nil,
        quotas = nil,
        usage_err = nil,
        trend_err = nil,
        concurrency_err = nil,
        quotas_err = nil,
        fetched_at = nil,      -- last successful usage clock string
        fetched_hm = nil,
        trend_fetched_at = nil,
        trend_fetched_hm = nil,
        conc_fetched_at = nil, -- last successful concurrency clock
        conc_fetched_hm = nil,
        fail_at = nil,
        fail_msg = nil,        -- usage-oriented fail (kept for usage page)
        trend_fail_msg = nil,
        conc_fail_msg = nil,   -- concurrency-oriented fail
        office = nil,          -- compact sessions (office.lua)
        office_now_ms = nil,   -- server-clock ms at fetch
        office_hm = nil,       -- last successful office fetch HH:MM
        office_err = nil,      -- { title=, detail= } when last fetch failed
    }
    self.cache.pc = {}        -- days → ProjCost.compact(stats)
    self.cache.pc_err = {}    -- days → { title=, detail=, at= }
    self.cache.tried = {}     -- fetch key → os.time() of last attempt
    self.web = { cookie = nil, office_path = nil, skew = 0 }
    self.office_detail = nil   -- project name when D detail is open
    self.viewer = nil
    self.refreshing = false
    self.auto_refresh_on = false
    self.next_refresh_at = nil
    self._refresh_task = nil

    self.conn = {}
    self:reloadConnection()
    Dispatcher:registerAction("magpie_open", {
        category = "none",
        event = "MagpieOpen",
        title = _("Magpie: 打开看板"),
        general = true,
    })
    Dispatcher:registerAction("magpie_refresh", {
        category = "none",
        event = "MagpieRefresh",
        title = _("Magpie: 刷新"),
        general = true,
    })

    self.ui.menu:registerToMainMenu(self)
end

function Magpie:onFlushSettings()
    if not self.settings_file or not self.settings then return end
    local to_save = {}
    if type(self.settings_extra) == "table" then
        for k, v in pairs(self.settings_extra) do
            if k ~= "api_key" and k ~= "base_url" then to_save[k] = v end
        end
    end
    to_save.user_agent = self.settings.user_agent or self.default_settings.user_agent
    to_save.auto_refresh_sec = tonumber(self.settings.auto_refresh_sec) or Magpie.AUTO_REFRESH_SEC
    self.settings_extra = to_save
    self.settings_file:saveSetting("settings", to_save)
    self.settings_file:flush()
end

function Magpie:saveSettings()
    self:onFlushSettings()
end

function Magpie:addToMainMenu(menu_items)
    menu_items.magpie_dashboard = {
        text = _("Magpie 看板"),
        sorting_hint = "more_tools",
        sub_item_table = {
            {
                text = _("打开看板"),
                callback = function()
                    self:openDashboard(true)
                end,
            },
            {
                text = _("刷新数据"),
                callback = function()
                    self:refreshAndShow(false)
                end,
            },
            {
                text = _("用量页"),
                callback = function()
                    self.page = Magpie.PAGE_USAGE
                    self:openDashboard(false)
                end,
            },
            {
                text = _("在飞页"),
                callback = function()
                    self.page = Magpie.PAGE_CONCURRENCY
                    self:openDashboard(false)
                end,
            },
            {
                text = _("趋势页"),
                callback = function()
                    self.page = Magpie.PAGE_TREND
                    self:openDashboard(false)
                end,
            },
            {
                text = _("网关地址…"),
                callback = function()
                    self:showBaseUrlDialog()
                end,
            },
        },
    }
end

function Magpie:onMagpieOpen()
    self:openDashboard(true)
end

function Magpie:onMagpieRefresh()
    self:refreshAndShow(false)
end

function Magpie:onCloseWidget()
    self:stopAutoRefresh()
    self:closeViewer()
end

function Magpie:onSuspend()
    self:stopAutoRefresh()
end

function Magpie:showBaseUrlDialog()
    self:reloadConnection()
    local MultiInputDialog = require("ui/widget/multiinputdialog")
    local dialog
    dialog = MultiInputDialog:new{
        title = _("Magpie 网关"),
        fields = {
            {
                text = self.conn.gateway_url or "",
                hint = _("例如 http://gateway.example.invalid:8080"),
                input_type = "string",
            },
        },
        buttons = {
            {
                {
                    text = _("取消"),
                    id = "close",
                    callback = function()
                        UIManager:close(dialog)
                    end,
                },
                {
                    text = _("保存"),
                    callback = function()
                        local fields = dialog:getFields()
                        local url = trim(fields[1] or "")
                        local norm = validate_url(url, "gateway")
                        if not norm then
                            UIManager:show(InfoMessage:new{
                                text = _("地址无效，未写入。使用 http 或 https，不要带账号、查询或片段。"),
                                timeout = 3,
                            })
                            return
                        end
                        local ok = self:writeConfigLine("base_url", norm)
                        if not ok then
                            UIManager:show(InfoMessage:new{
                                text = _("写入 base_url.txt 失败，未保存。"),
                                timeout = 3,
                            })
                            return
                        end
                        self:reloadConnection()
                        UIManager:close(dialog)
                    end,
                },
            },
        },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function Magpie:httpGet(path_with_query)
    self:reloadConnection()
    local base = self.conn.gateway_url
    local key = self.conn.gateway_key
    if not base or not key then
        return nil, "missing_config", self:gatewayBlockReason()
    end
    local http = require("socket.http")
    local https = require("ssl.https")
    local ltn12 = require("ltn12")
    local JSON = require("json")
    local url = base .. path_with_query
    local sink = {}
    local request = {
        url = url,
        method = "GET",
        headers = {
            ["Accept"] = "application/json",
            ["Authorization"] = "Bearer " .. key,
            ["User-Agent"] = self.settings.user_agent or self.default_settings.user_agent,
        },
        sink = ltn12.sink.table(sink),
        protocol = "any",
        options = { "all", "no_sslv2", "no_sslv3" },
        verify = "none",
    }
    local httpx = url:match("^https://") and https or http
    http.TIMEOUT = 8
    local ok, status = httpx.request(request)
    if not ok or ok ~= 1 then
        logger.warn("Magpie: gateway request failed", path_with_query)
        return nil, "network", _("网络错误")
    end
    if status ~= 200 then
        logger.warn("Magpie: gateway HTTP", tostring(status), path_with_query)
        return nil, "http_" .. tostring(status), T(_("HTTP %1"), tostring(status))
    end
    local body = table.concat(sink)
    local decoded_ok, data = pcall(JSON.decode, body)
    if not decoded_ok or type(data) ~= "table" then
        return nil, "bad_json", _("JSON 解析失败")
    end
    return data, nil, nil
end

-- ---------------------------------------------------------------------------
-- magpie web (:3430) — session cookie from the web key; only GETs.

local function days_from_civil(y, m, d)
    y = (m <= 2) and (y - 1) or y
    local era = math.floor(y / 400)
    local yoe = y - era * 400
    local mp = (m + 9) % 12
    local doy = math.floor((153 * mp + 2) / 5) + d - 1
    local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
    return era * 146097 + doe - 719468
end

local MONTHS = { Jan = 1, Feb = 2, Mar = 3, Apr = 4, May = 5, Jun = 6,
    Jul = 7, Aug = 8, Sep = 9, Oct = 10, Nov = 11, Dec = 12 }

-- "Wed, 04 Nov 2026 02:51:57 GMT" → epoch seconds
local function parse_http_date(s)
    if type(s) ~= "string" then return nil end
    local d, mon, y, hh, mm, ss = s:match("(%d+) (%a+) (%d+) (%d+):(%d+):(%d+)")
    if not d or not MONTHS[mon] then return nil end
    return days_from_civil(tonumber(y), MONTHS[mon], tonumber(d)) * 86400
        + tonumber(hh) * 3600 + tonumber(mm) * 60 + tonumber(ss)
end

function Magpie:webBase()
    return self.conn and self.conn.web_url or nil
end

function Magpie:webRaw(path)
    local base = self:webBase()
    if not base then
        return nil, "missing_config"
    end
    local http = require("socket.http")
    local ltn12 = require("ltn12")
    local sink = {}
    local headers = {
        ["User-Agent"] = (self.settings and self.settings.user_agent) or self.default_settings.user_agent,
    }
    if self.web and self.web.cookie then
        headers["Cookie"] = self.web.cookie
    end
    http.TIMEOUT = 8
    local ok, code, resp_headers = http.request{
        url = base .. path,
        method = "GET",
        headers = headers,
        redirect = false,
        sink = ltn12.sink.table(sink),
    }
    if not ok or type(code) ~= "number" then
        logger.warn("Magpie: web request failed", log_path(path))
        return nil, "network"
    end
    local date = resp_headers and parse_http_date(resp_headers["date"])
    if date and self.web then
        self.web.skew = date - os.time()
    end
    return code, resp_headers or {}, table.concat(sink)
end

local function web_cookie(headers)
    local set = headers and headers["set-cookie"]
    if type(set) ~= "string" then return nil end
    local name, value = set:match("(magpie_web_[%w_]*)=([^;,%s]+)")
    if not name or not value or value == "" then return nil end
    return name .. "=" .. value
end

function Magpie:webSignIn()
    self:reloadConnection()
    self.web = self.web or { cookie = nil, office_path = nil, skew = 0 }
    local key = self.conn.web_key
    if not self.conn.web_url or not key then
        self.web.cookie = nil
        return false, { title = _("缺少 Web 配置"), detail = self:webBlockReason() }
    end
    self.web.cookie = nil
    local code, headers = self:webRaw("/?k=" .. key)
    local cookie = web_cookie(headers)
    if type(code) == "number" and code >= 200 and code < 400 and cookie then
        self.web.cookie = cookie
        logger.info("Magpie: web signed in")
        return true
    end
    self.web.cookie = nil
    logger.warn("Magpie: web sign-in failed", tostring(code or "network"))
    return false, {
        title = _("web 登录失败"),
        detail = _("检查设置目录 magpie/web-key.txt 是否为当前 Web 进程的管理 key。"),
    }
end

function Magpie:webGet(path)
    self:reloadConnection()
    if not (self.conn.web_url and self.conn.web_key) then
        return nil, nil, { title = _("缺少 Web 配置"), detail = self:webBlockReason() }
    end
    self.web = self.web or { cookie = nil, office_path = nil, skew = 0 }
    if not self.web.cookie then
        local ok, err = self:webSignIn()
        if not ok then return nil, nil, err end
    end
    local code, headers, body = self:webRaw(path)
    if code == 401 then
        local ok, err = self:webSignIn()
        if not ok then return nil, nil, err end
        code, headers, body = self:webRaw(path)
    end
    if not code then
        return nil, nil, { title = _("web 连不上"), detail = _("网络错误") }
    end
    return code, body, nil
end

local function discovery_live_path(base, item_url)
    if type(item_url) ~= "string" or item_url == "" then return nil, "bad" end
    local origin = base:match("^(https?://[^/]+)")
    if not origin then return nil, "bad" end
    if item_url:match("^//") or item_url:match("^%a[%w+.-]*:") then
        local abs = item_url:match("^//") and ("http:" .. item_url) or item_url
        local got = abs:match("^(https?://[^/]+)")
        if got ~= origin then return nil, "origin" end
        item_url = abs:sub(#got + 1)
        if item_url == "" then item_url = "/" end
    end
    if not item_url:match("^/") then item_url = "/" .. item_url end
    local dir = item_url:match("^(.*)/") or ""
    return (dir == "" and "/" or (dir .. "/")) .. "live.js"
end

function Magpie:findOfficePath()
    local base = self.conn and self.conn.web_url
    if not base then
        return nil, { title = _("缺少 Web 配置"), detail = self:webBlockReason() }
    end
    local code, body, err = self:webGet("/api/plugin-pages")
    if err then return nil, err end
    if code ~= 200 then
        return nil, { title = T(_("插件列表 HTTP %1"), tostring(code)), detail = "/api/plugin-pages" }
    end
    local ok, list = pcall(require("json").decode, body)
    if not ok or type(list) ~= "table" then
        return nil, { title = _("插件列表解析失败"), detail = "/api/plugin-pages" }
    end
    for i, p in ipairs(list) do
        if type(p) == "table" and (p.name == OFFICE_PLUGIN or p.key == "plugin-agent-office")
            and type(p.url) == "string" then
            local live, why = discovery_live_path(base, p.url)
            if why == "origin" then
                return nil, { title = _("不支持的发现结果"),
                    detail = _("插件地址不在已配置的 Web 来源内，已拒绝连接。") }
            end
            if live then return live end
        end
    end
    return nil, { title = _("agent-office 插件没开"),
        detail = _("magpie 里没找到 Agent Office 页面插件。在 magpie 的插件里打开它后点 ↻。") }
end

local function decode_any(s)
    local okr, rj = pcall(require, "rapidjson")
    if okr and rj and rj.decode then
        return rj.decode(s)
    end
    return require("json").decode(s)
end

-- Returns true on success; fills cache.office / office_err.
function Magpie:fetchOffice()
    local code, body, err
    for attempt = 1, 2 do
        if not self.web.office_path then
            local path
            path, err = self:findOfficePath()
            if not path then break end
            self.web.office_path = path
        end
        code, body, err = self:webGet(self.web.office_path)
        if err then break end
        if code == 404 and attempt == 1 then
            -- plugin path changed (restart / upgrade): look it up again
            self.web.office_path = nil
        else
            break
        end
    end
    if not err and code ~= 200 then
        err = { title = T(_("项目数据 HTTP %1"), tostring(code)), detail = self.web.office_path or "" }
    end
    if not err then
        local data, derr = Office.decode(body, decode_any)
        body = nil
        if not data then
            err = { title = _("项目数据解析失败"), detail = tostring(derr) }
        else
            self.cache.office = Office.compact(data)
            self.cache.office_now_ms = (os.time() + (self.web.skew or 0)) * 1000
            self.cache.office_hm = shanghai_hm()
            self.cache.office_at = os.time()
            self.cache.office_err = nil
            return true
        end
    end
    err.at = shanghai_hm()
    self.cache.office_err = err
    logger.warn("Magpie: office fetch failed:", err.title)
    return false
end

-- /api/sessions/stats?days=N → cache.pc[N] (per-project cost)
function Magpie:fetchProjCost(days)
    local code, body, err = self:webGet("/api/sessions/stats?days=" .. tostring(days))
    if not err and code ~= 200 then
        err = { title = T(_("项目费用 HTTP %1"), tostring(code)), detail = "/api/sessions/stats" }
    end
    if not err then
        local ok, data = pcall(decode_any, body)
        body = nil
        local pc = ok and ProjCost.compact(data) or nil
        if pc then
            self.cache.pc[days] = pc
            self.cache.pc_err[days] = nil
            return true
        end
        err = { title = _("项目费用解析失败"), detail = "/api/sessions/stats" }
    end
    err.at = shanghai_hm()
    self.cache.pc_err[days] = err
    logger.warn("Magpie: project cost fetch failed:", err.title)
    return false
end

-- days of session stats the current page needs (nil: none)
function Magpie:projDays()
    if self.page == Magpie.PAGE_USAGE then return 1 end
    if self.page == Magpie.PAGE_TREND then
        local p = self.trend_period or "7d"
        if p == "today" then return 1 elseif p == "30d" then return 30 end
        return 7
    end
    return nil
end

-- web data for the current page: office (在飞) or per-project cost
function Magpie:webFetchKey()
    if self.page == Magpie.PAGE_CONCURRENCY then return "office" end
    local d = self:projDays()
    return d and ("pc" .. d) or nil
end

function Magpie:fetchAll()
    self:reloadConnection()
    local period = self.trend_period or "7d"
    if period ~= "today" and period ~= "7d" and period ~= "30d" then
        period = "7d"
    end
    local usage, trend, conc, quotas
    local umsg, tmsg, cmsg, qmsg
    local g_block = self:gatewayBlockReason()
    if g_block then
        umsg, tmsg, cmsg, qmsg = g_block, g_block, g_block, g_block
    else
        local qcode, ccode, gcode
        usage, gcode, umsg = self:httpGet("/v1/magpie/usage?period=today")
        trend, gcode, tmsg = self:httpGet("/v1/magpie/usage?period=" .. period)
        conc, gcode, cmsg = self:httpGet("/v1/magpie/concurrency")
        quotas, qcode, qmsg = self:httpGet("/v1/magpie/quotas?kept=1")
        if not quotas then
            local cards, cards_code, cards_msg = self:httpGet("/v1/magpie/quotas/cards")
            ccode = cards_code
            if cards then
                quotas = cards
                qmsg = nil
            elseif qcode == "http_401" or qcode == "http_403"
                or ccode == "http_401" or ccode == "http_403" then
                qmsg = _("配额权限不足。这和空配额不同：空配额会显示空列表。")
            elseif not qmsg then
                qmsg = cards_msg
            end
        end
    end

    local clock = shanghai_ymd_hm()
    local hm = shanghai_hm()
    local any_ok = false

    if usage then
        self.cache.usage = usage
        self.cache.usage_err = nil
        self.cache.fetched_at = clock
        self.cache.fetched_hm = hm
        self.cache.fail_msg = nil
        any_ok = true
    else
        self.cache.usage_err = umsg
        self.cache.fail_at = hm
        self.cache.fail_msg = umsg
    end

    if trend then
        self.cache.trend = trend
        self.cache.trend_period = period
        self.cache.trend_err = nil
        self.cache.trend_fetched_at = clock
        self.cache.trend_fetched_hm = hm
        self.cache.trend_fail_msg = nil
        any_ok = true
    else
        self.cache.trend_err = tmsg
        self.cache.trend_fail_msg = tmsg
    end

    if conc then
        self.cache.concurrency = conc
        self.cache.concurrency_err = nil
        self.cache.conc_fetched_at = clock
        self.cache.conc_fetched_hm = hm
        self.cache.conc_fail_msg = nil
        any_ok = true
    else
        self.cache.concurrency_err = cmsg
        self.cache.conc_fail_msg = cmsg
        if not self.cache.fail_msg then
            self.cache.fail_msg = cmsg
            self.cache.fail_at = hm
        end
    end

    if quotas then
        self.cache.quotas = quotas
        self.cache.quotas_err = nil
        any_ok = true
    else
        self.cache.quotas_err = qmsg
    end

    local wkey = self:webFetchKey()
    if wkey then
        self.cache.tried[wkey] = os.time()
        local w_block = self:webBlockReason()
        if w_block then
            local err = { title = _("Web 未配置"), detail = w_block, at = shanghai_hm() }
            if wkey == "office" then
                self.cache.office_err = err
            else
                local days = self:projDays()
                if days then self.cache.pc_err[days] = err end
            end
        else
            local ok
            if wkey == "office" then
                ok = self:fetchOffice()
            else
                ok = self:fetchProjCost(self:projDays())
            end
            if ok then any_ok = true end
        end
    end

    return any_ok
end

function Magpie:collectUsageQuotas()
    local out = {}
    local quotas = self.cache.quotas
    if type(quotas) ~= "table" or type(quotas.data) ~= "table" then
        return out, self.cache.quotas_err and ("配额暂不可用：" .. tostring(self.cache.quotas_err)) or "（无配额数据）"
    end
    -- same provider + plan twice (two Codex accounts): tell them apart by mail domain
    local seen = {}
    for _, row in ipairs(quotas.data) do
        if type(row) == "table" then
            local k = tostring(row.name or row.provider or "") .. "|" .. tostring(row.plan or "")
            seen[k] = (seen[k] or 0) + 1
        end
    end
    local shown = 0
    for _, row in ipairs(quotas.data) do
        if shown >= 6 then break end
        if type(row) == "table" then
            local win = pick_primary_window(row.windows)
            if win then
                local name = tostring(row.name or row.provider or "quota")
                local sub = {}
                if row.plan and tostring(row.plan) ~= "" then
                    local plan = tostring(row.plan):gsub("%s+[Pp]lan$", "")
                    table.insert(sub, plan)
                end
                if row.last == true then table.insert(sub, "last") end
                local k = tostring(row.name or row.provider or "") .. "|" .. tostring(row.plan or "")
                local dom = type(row.user) == "string" and row.user:match("@([^%.]+)")
                if seen[k] > 1 and dom then table.insert(sub, dom) end
                local used = tonumber(win.used)
                if not used and tonumber(win.remaining) then
                    used = 100 - tonumber(win.remaining)
                end
                used = used or 0
                table.insert(out, {
                    name = name,
                    sub = table.concat(sub, " · "),
                    tag = window_tag(win.name or win.pool),
                    pct = used,
                    reset = fmt_reset_remain(win.resetsAt),
                })
                shown = shown + 1
            end
        end
    end
    if self.cache.quotas_err then
        return out, "配额拉取失败：" .. tostring(self.cache.quotas_err) .. "（仍显示上次数据，点 ↻ 重试）"
    end
    if shown == 0 then
        return out, "（无可用窗口）"
    end
    return out, nil
end

function Magpie:clockForPage()
    if self.page == Magpie.PAGE_CONCURRENCY then
        return self.cache.office_hm or self.cache.conc_fetched_hm or self.cache.fetched_hm or "—"
    elseif self.page == Magpie.PAGE_TREND then
        return self.cache.trend_period == (self.trend_period or "7d") and self.cache.trend_fetched_hm or "—"
    end
    return self.cache.fetched_hm or "—"
end

-- per-project cost for `days` against a gateway total; nil when not fetched
function Magpie:projModel(days, gw_total, top)
    local pc = self.cache.pc[days]
    local err = self.cache.pc_err[days]
    local sum = pc and ProjCost.summarize(pc, gw_total, { top = top or 5 }) or nil
    local rows = {}
    if sum then
        for i, r in ipairs(sum.rows) do
            table.insert(rows, {
                idx = i, name = r.name, money = fmt_money(r.cost),
                pct = string.format("%d%%", math.floor(r.pct + 0.5)), share = r.share,
            })
        end
    end
    local rest = nil
    if sum and sum.rest.cost >= 0.5 then
        rest = {
            label = (sum.rest.n > 0) and string.format("其余 %d 个项目 · 含未归属", sum.rest.n) or "其余 · 未归属",
            money = fmt_money(sum.rest.cost),
            pct = string.format("%d%%", math.floor(sum.rest.pct + 0.5)),
        }
    end
    return {
        ok = sum ~= nil,
        rows = rows,
        rest = rest,
        total = sum and fmt_money(sum.total) or nil,
        stack_names = sum and sum.stack_names or {},
        per_day = sum and sum.per_day or {},
        err = (not self.refreshing) and err or nil,
    }
end

function Magpie:buildUsageModel()
    local u = self.cache.usage
    local summary = {
        cost = "—", requests = "—", tokens = "—", cache_hit = "—", speed = "—",
        hero_sub = nil,
    }
    if u then
        summary.cost = fmt_money(u.cost)
        summary.requests = fmt_int(u.calls)
        summary.tokens = fmt_int(tokens_io(u))
        local hit = cache_hit_pct(u)
        if hit then summary.cache_hit = string.format("%.1f%%", hit) end
        local spd = decode_tok_s(u)
        if spd then summary.speed = string.format("%.0f", spd) end
        local sub = {}
        if tonumber(u.sessionCount) then table.insert(sub, fmt_int(u.sessionCount) .. " 会话") end
        local ttft = avg_ttft_ms(u)
        if ttft then
            table.insert(sub, (ttft >= 1000) and string.format("均 TTFT %.1fs", ttft / 1000)
                or string.format("均 TTFT %.0fms", ttft))
        end
        if #sub > 0 then summary.hero_sub = table.concat(sub, " · ") end
    end
    local quotas, quotas_note = self:collectUsageQuotas()
    local failed = (not not self.cache.fail_msg) and (not self.refreshing)
    local fail_text = nil
    if failed then
        if self.cache.usage then
            fail_text = T(_("⚠ 拉取失败：%1（仍显示上次）"), tostring(self.cache.fail_msg))
        else
            fail_text = T(_("⚠ 拉取失败：%1 · 点 ↻ 重试"), tostring(self.cache.fail_msg))
        end
    end
    return {
        title = _("Magpie · 用量"),
        clock = self:clockForPage(),
        refreshing = self.refreshing,
        failed = failed,
        fail_text = fail_text,
        summary = summary,
        quotas = quotas,
        quotas_note = quotas_note,
        projects = self:projModel(1, u and u.cost, 6),
    }
end

function Magpie:buildConcurrencyModel()
    -- gateway strip (cannot be attributed to projects: no cwd on requests)
    local c = self.cache.concurrency or {}
    local gw = {
        inflight = tonumber(c.requests) or 0,
        waiting = tonumber(c.waiting) or 0,
        tools = tonumber(c.tools) or 0,
        known = self.cache.concurrency ~= nil,
        failed = (not not self.cache.conc_fail_msg) and (not self.refreshing),
    }

    local office = nil
    if self.cache.office then
        office = Office.build(self.cache.office, self.cache.office_now_ms or (os.time() * 1000))
    end

    local detail = nil
    if self.office_detail and office then
        detail = office.by_name[self.office_detail]
        if not detail then
            self.office_detail = nil
        end
    end

    local err = self.cache.office_err
    return {
        title = detail and detail.name or _("Magpie · 在飞"),
        clock = self:clockForPage(),
        refreshing = self.refreshing,
        gw = gw,
        office = office,
        detail = detail,
        office_err = (not self.refreshing) and err or nil,
        office_hm = self.cache.office_hm,
        -- C: an error with an older snapshot still on screen
        stale = (err ~= nil) and (office ~= nil),
    }
end

function Magpie:buildTrendModel()
    local period = self.trend_period or "7d"
    local u = self.cache.trend_period == period and self.cache.trend or nil
    local metric = self.trend_metric or "cost"
    local days = (period == "today") and 1 or ((period == "30d") and 30 or 7)
    local proj = self:projModel(days, u and u.cost, 5)
    -- stack by project only for daily cost (no per-project calls; today is hourly)
    local stacked = proj.ok and metric == "cost" and period ~= "today" and #proj.stack_names > 0
    local series = {}
    local total_cost, total_calls = "—", "—"
    if u then
        total_cost = fmt_money(u.cost)
        total_calls = fmt_int(u.calls)
        if type(u.series) == "table" then
            for _, s in ipairs(u.series) do
                if type(s) == "table" then
                    local cost = tonumber(s.cost) or 0
                    local parts = nil
                    if stacked then
                        local date = tostring(s.time or ""):match("^(%d%d%d%d%-%d%d%-%d%d)")
                        parts = date and proj.per_day[date] or {}
                        -- bar = max(gateway, projects): stats can predate gateway logging
                        local psum = 0
                        for _, v in ipairs(parts) do psum = psum + v end
                        if psum > cost then cost = psum end
                    end
                    table.insert(series, {
                        label = series_day_label(s.label, s.time),
                        cost = cost,
                        calls = tonumber(s.calls) or 0,
                        parts = parts,
                    })
                end
            end
        end
    end
    local failed = (not not self.cache.trend_fail_msg) and (not self.refreshing)
    local fail_text = nil
    if failed then
        if u then
            fail_text = T(_("⚠ 拉取失败：%1（仍显示上次）"), tostring(self.cache.trend_fail_msg))
        else
            fail_text = T(_("⚠ 拉取失败：%1 · 点 ↻ 重试"), tostring(self.cache.trend_fail_msg))
        end
    end
    local period_label = ({ today = "今日", ["7d"] = "7日", ["30d"] = "30日" })[period] or period
    return {
        title = _("Magpie · 趋势"),
        clock = self:clockForPage(),
        refreshing = self.refreshing,
        failed = failed,
        fail_text = fail_text,
        period = period,
        period_label = period_label,
        metric = metric,
        stacked = stacked,
        total_cost = total_cost,
        total_calls = total_calls,
        series = series,
        projects = proj,
    }
end

function Magpie:stopAutoRefresh()
    if self._refresh_task then
        UIManager:unschedule(self._refresh_task)
    end
    self.auto_refresh_on = false
    self.next_refresh_at = nil
end

function Magpie:scheduleAutoRefresh()
    self:stopAutoRefresh()
    -- Auto-refresh while any dashboard page is open.
    if self.page ~= Magpie.PAGE_USAGE
        and self.page ~= Magpie.PAGE_CONCURRENCY
        and self.page ~= Magpie.PAGE_TREND then
        return
    end
    if not self.viewer then
        return
    end
    local interval = self:intervalSec()
    local page_at_schedule = self.page
    self.auto_refresh_on = true
    self.next_refresh_at = os.time() + interval
    self._refresh_task = function()
        if not self.auto_refresh_on then return end
        if self.page ~= page_at_schedule then return end
        if not self.viewer then return end
        self:refreshAndShow(true)
    end
    UIManager:scheduleIn(interval, self._refresh_task)
end

function Magpie:closeViewer()
    self:stopAutoRefresh()
    if self.viewer then
        UIManager:close(self.viewer)
        self.viewer = nil
    end
end

function Magpie:pageName()
    return (PAGES[self.page] or PAGES[Magpie.PAGE_USAGE]).name
end

function Magpie:modelForPage()
    local page = PAGES[self.page] or PAGES[Magpie.PAGE_USAGE]
    return self[page.model](self)
end

function Magpie:showViewer()
    if self.viewer then
        UIManager:close(self.viewer)
        self.viewer = nil
    end

    local that = self
    local page = self:pageName()
    local model = self:modelForPage()

    local viewer = MagpieDash:new{
        page = page,
        model = model,
        on_refresh = function()
            that:refreshAndShow(false)
        end,
        on_tab = function(name)
            that:gotoPage(name)
        end,
        on_period = function(period)
            that:setTrendPeriod(period)
        end,
        on_metric = function(metric)
            that:setTrendMetric(metric)
        end,
        on_project = function(name)
            that:openProject(name)
        end,
        on_back = function()
            that:openProject(nil)
        end,
        on_close = function()
            that:closeViewer()
        end,
    }
    self.viewer = viewer
    UIManager:show(viewer)
end

function Magpie:gotoPage(name)
    self:stopAutoRefresh()
    self.office_detail = nil
    if name == "concurrency" then
        self.page = Magpie.PAGE_CONCURRENCY
    elseif name == "trend" then
        self.page = Magpie.PAGE_TREND
    else
        self.page = Magpie.PAGE_USAGE
    end
    -- web data is fetched per page: pull now if this page's is none / old
    local wkey = self:webFetchKey()
    local tried = wkey and self.cache.tried[wkey]
    if wkey and (not tried or os.time() - tried >= self:intervalSec()) then
        self:refreshAndShow(true)
        return
    end
    self:showViewer()
    self:scheduleAutoRefresh()
end

-- D: project detail (name) or back to the list (nil). No fetch.
function Magpie:openProject(name)
    if self.page ~= Magpie.PAGE_CONCURRENCY then return end
    self.office_detail = name
    self:showViewer()
end

function Magpie:switchPage()
    -- swipe fallback: cycle usage → concurrency → trend
    if self.page == Magpie.PAGE_USAGE then
        self:gotoPage("concurrency")
    elseif self.page == Magpie.PAGE_CONCURRENCY then
        self:gotoPage("trend")
    else
        self:gotoPage("usage")
    end
end

function Magpie:setTrendPeriod(period)
    if period ~= "today" and period ~= "7d" and period ~= "30d" then
        return
    end
    if self.trend_period == period and self.cache.trend_period == period and self.cache.trend then
        self:showViewer()
        return
    end
    self.trend_period = period
    self:refreshAndShow(false)
end

function Magpie:setTrendMetric(metric)
    if metric ~= "cost" and metric ~= "calls" then
        return
    end
    self.trend_metric = metric
    self:showViewer()
end

function Magpie:ensureWifiThen(callback)
    NetworkMgr:runWhenConnected(callback)
end

function Magpie:openDashboard(do_fetch)
    if do_fetch or (not self.cache.usage and not self.cache.concurrency and not self.cache.trend) then
        self:refreshAndShow(false)
        return
    end
    self:showViewer()
    self:scheduleAutoRefresh()
end

-- quiet=true: auto-refresh path (C: show 刷新中 without InfoMessage wipe)
function Magpie:refreshAndShow(quiet)
    quiet = not not quiet
    self.refreshing = true
    self:reloadConnection()
    local need_net = (self.conn.gateway_url and self.conn.gateway_key)
        or (self.conn.web_url and self.conn.web_key)
    if self.viewer or self.cache.usage or self.cache.concurrency or self.cache.trend then
        self:showViewer()
    elseif not quiet and need_net then
        UIManager:show(InfoMessage:new{
            text = _("正在拉取 Magpie…"),
            timeout = 1.2,
        })
    end
    if not quiet then
        self:stopAutoRefresh()
    end
    local function finish()
        self:fetchAll()
        self.refreshing = false
        self:showViewer()
        self:scheduleAutoRefresh()
    end
    if not need_net then
        finish()
        return
    end
    self:ensureWifiThen(finish)
end

return Magpie
