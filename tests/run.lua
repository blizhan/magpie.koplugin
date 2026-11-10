-- Dev behavior checks for office.lua, projcost.lua, and Magpie config/auth.
-- Run from the repository root: luajit tests/run.lua
-- Uses a temporary settings directory and scripted socket responses only.

local script = (arg and arg[0]) or "tests/run.lua"
local root = script:match("^(.*)/[^/]+$") or "."
if root == "tests" then
    root = "."
elseif root:match("/tests$") then
    root = root:gsub("/tests$", "")
    if root == "" then root = "." end
end
package.path = root .. "/?.lua;" .. package.path

local GW_URL = "http://gateway.example.invalid:8080"
local GW_URL_2 = "http://other.example.invalid:9090"
local WEB_URL = "http://web.example.invalid:3430"
local OLD_URL = "http://old.example.invalid:9"
local GW_KEY = "EXAMPLE_GW_NOT_A_REAL_KEY"
local WEB_KEY = "EXAMPLE_ONLY_NOT_A_REAL_KEY"
local OLD_KEY = "OLD_EXAMPLE_KEY"
local COOKIE = "magpie_web_3430=abc"

local failed = 0
local tmp
local settings_dir
local settings_doc = {}
local saved_settings
local calls = {}
local logs = {}
local queue = {}
local http_n, https_n = 0, 0

local function sh_quote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function redact(s)
    s = tostring(s)
    local secrets = { GW_KEY, WEB_KEY, OLD_KEY, COOKIE, "magpie_web_3430=" }
    for i = 1, #secrets do
        s = s:gsub(secrets[i], "[redacted]")
    end
    s = s:gsub("%?k=[^%s\"']+", "?k=[redacted]")
    s = s:gsub("Bearer%s+%S+", "Bearer [redacted]")
    return s
end

local function expect(cond, msg)
    if not cond then
        error(msg or "assertion failed", 2)
    end
end

local function contains(hay, needle)
    if hay == nil or needle == nil or needle == "" then return false end
    return tostring(hay):find(needle, 1, true) ~= nil
end

local function collect_strings(v, out)
    out = out or {}
    local tv = type(v)
    if tv == "string" then
        out[#out + 1] = v
    elseif tv == "table" then
        for k, val in pairs(v) do
            collect_strings(k, out)
            collect_strings(val, out)
        end
    end
    return out
end

local function no_secret(v, secret, what)
    local parts = collect_strings(v)
    for i = 1, #parts do
        expect(not contains(parts[i], secret), what or "secret leaked")
    end
end

local function logs_clean(secret)
    for i = 1, #logs do
        expect(not contains(logs[i], secret), "log contains a secret")
    end
end

-- Minimal JSON decoder for synthetic fixtures. null in an array is unsupported.
local function json_decode(str)
    if type(str) ~= "string" then error("json: not a string") end
    local i, n = 1, #str
    local function peek()
        return str:sub(i, i)
    end
    local function skip()
        while true do
            local c = peek()
            if c == " " or c == "\t" or c == "\n" or c == "\r" then
                i = i + 1
            else
                break
            end
        end
    end
    local parse_value
    local function parse_string()
        i = i + 1
        local parts = {}
        while i <= n do
            local c = peek()
            if c == '"' then
                i = i + 1
                return table.concat(parts)
            end
            if c == "\\" then
                local e = str:sub(i + 1, i + 1)
                if e == "n" then parts[#parts + 1] = "\n"
                elseif e == "r" then parts[#parts + 1] = "\r"
                elseif e == "t" then parts[#parts + 1] = "\t"
                elseif e == '"' or e == "\\" or e == "/" then parts[#parts + 1] = e
                elseif e == "u" then
                    local cp = tonumber(str:sub(i + 2, i + 5), 16)
                    if not cp then error("json: bad unicode") end
                    if cp < 128 then
                        parts[#parts + 1] = string.char(cp)
                    elseif cp < 2048 then
                        parts[#parts + 1] = string.char(192 + math.floor(cp / 64), 128 + (cp % 64))
                    else
                        parts[#parts + 1] = string.char(
                            224 + math.floor(cp / 4096),
                            128 + (math.floor(cp / 64) % 64),
                            128 + (cp % 64))
                    end
                    i = i + 4
                else
                    error("json: bad escape")
                end
                i = i + 2
            else
                parts[#parts + 1] = c
                i = i + 1
            end
        end
        error("json: unterminated string")
    end
    local function parse_number()
        local start = i
        if peek() == "-" then i = i + 1 end
        while peek():match("%d") do i = i + 1 end
        if peek() == "." then
            i = i + 1
            while peek():match("%d") do i = i + 1 end
        end
        local e = peek()
        if e == "e" or e == "E" then
            i = i + 1
            local s = peek()
            if s == "+" or s == "-" then i = i + 1 end
            while peek():match("%d") do i = i + 1 end
        end
        local num = tonumber(str:sub(start, i - 1))
        if not num then error("json: bad number") end
        return num
    end
    local function parse_array()
        i = i + 1
        local arr = {}
        skip()
        if peek() == "]" then
            i = i + 1
            return arr
        end
        while true do
            arr[#arr + 1] = parse_value()
            skip()
            local c = peek()
            if c == "]" then
                i = i + 1
                return arr
            end
            if c ~= "," then error("json: expected comma") end
            i = i + 1
            skip()
        end
    end
    local function parse_object()
        i = i + 1
        local obj = {}
        skip()
        if peek() == "}" then
            i = i + 1
            return obj
        end
        while true do
            skip()
            if peek() ~= '"' then error("json: expected key") end
            local key = parse_string()
            skip()
            if peek() ~= ":" then error("json: expected colon") end
            i = i + 1
            obj[key] = parse_value()
            skip()
            local c = peek()
            if c == "}" then
                i = i + 1
                return obj
            end
            if c ~= "," then error("json: expected comma") end
            i = i + 1
        end
    end
    function parse_value()
        skip()
        local c = peek()
        if c == '"' then return parse_string() end
        if c == "{" then return parse_object() end
        if c == "[" then return parse_array() end
        if c == "t" and str:sub(i, i + 3) == "true" then
            i = i + 4
            return true
        end
        if c == "f" and str:sub(i, i + 4) == "false" then
            i = i + 5
            return false
        end
        if c == "n" and str:sub(i, i + 3) == "null" then
            i = i + 4
            return nil
        end
        if c == "-" or c:match("%d") then return parse_number() end
        error("json: unexpected")
    end
    return parse_value()
end

local function request_host(url)
    return (url or ""):match("^https?://([^/:]+)")
end

local function request_path(url)
    local rest = (url or ""):match("^https?://[^/]+(.*)$") or ""
    local q = rest:find("?", 1, true)
    if not q then return rest, "" end
    return rest:sub(1, q - 1), rest:sub(q)
end

local function snapshot_request(req)
    local headers = {}
    local method, url, redirect
    if type(req) == "table" then
        method = req.method
        url = req.url
        redirect = req.redirect
        if type(req.headers) == "table" then
            for k, v in pairs(req.headers) do
                headers[k] = v
            end
        end
    end
    return {
        method = method,
        url = url,
        headers = headers,
        redirect = redirect,
    }
end

local function reset_net()
    calls = {}
    logs = {}
    queue = {}
    http_n, https_n = 0, 0
end

local function push(item)
    queue[#queue + 1] = item
end

local function handle_request(kind, req)
    if kind == "https" then
        https_n = https_n + 1
    else
        http_n = http_n + 1
    end
    local snap = snapshot_request(req)
    snap.transport = kind
    calls[#calls + 1] = snap
    local item = table.remove(queue, 1) or { fail = "down" }
    if item.fail then
        return nil, item.fail
    end
    if type(req) == "table" and type(req.sink) == "function" and item.body then
        req.sink(item.body)
    end
    return 1, item.status or 200, item.headers or {}
end

local function widget_class()
    local cls = {}
    cls.__index = cls
    function cls:extend(proto)
        local sub = setmetatable(proto or {}, { __index = self })
        sub.__index = sub
        return sub
    end
    function cls:new(o)
        o = setmetatable(o or {}, self)
        if o.init then o:init() end
        return o
    end
    return cls
end

local function preload(name, mod)
    package.preload[name] = function()
        return mod
    end
end

local function install_stubs()
    preload("datastorage", {
        getSettingsDir = function()
            return settings_dir
        end,
    })
    preload("device", {
        screen = {
            getWidth = function() return 600 end,
            getHeight = function() return 800 end,
            scaleBySize = function(_, n) return n end,
        },
        hasKeys = function() return false end,
        isTouchDevice = function() return false end,
        input = { group = { Back = "Back" } },
    })
    preload("dispatcher", { registerAction = function() end })
    preload("ui/widget/infomessage", widget_class())
    preload("ui/widget/multiinputdialog", widget_class())
    preload("luasettings", {
        open = function(_, _)
            return {
                readSetting = function(_, key)
                    if key ~= "settings" then return nil end
                    local copy = {}
                    for k, v in pairs(settings_doc) do
                        copy[k] = v
                    end
                    return copy
                end,
                saveSetting = function(_, key, value)
                    if key == "settings" and type(value) == "table" then
                        local copy = {}
                        for k, v in pairs(value) do
                            copy[k] = v
                        end
                        saved_settings = copy
                        settings_doc = copy
                    end
                end,
                flush = function() end,
            }
        end,
    })
    preload("ui/network/manager", {
        runWhenConnected = function(_, cb)
            if cb then cb() end
        end,
    })
    preload("ui/uimanager", {
        show = function() end,
        close = function() end,
        setDirty = function() end,
        schedule = function() end,
        unschedule = function() end,
        scheduleIn = function() end,
        nextTick = function(cb) if cb then cb() end end,
    })
    preload("ui/widget/container/widgetcontainer", widget_class())
    preload("logger", {
        warn = function(...)
            local n = select("#", ...)
            local parts = {}
            for i = 1, n do parts[i] = tostring(select(i, ...)) end
            logs[#logs + 1] = table.concat(parts, " ")
        end,
        info = function(...)
            local n = select("#", ...)
            local parts = {}
            for i = 1, n do parts[i] = tostring(select(i, ...)) end
            logs[#logs + 1] = table.concat(parts, " ")
        end,
        dbg = function() end,
        err = function(...)
            local n = select("#", ...)
            local parts = {}
            for i = 1, n do parts[i] = tostring(select(i, ...)) end
            logs[#logs + 1] = table.concat(parts, " ")
        end,
    })
    local function deep_copy(v, seen)
        if type(v) ~= "table" then return v end
        seen = seen or {}
        if seen[v] then return seen[v] end
        local out = {}
        seen[v] = out
        for k, val in pairs(v) do
            out[deep_copy(k, seen)] = deep_copy(val, seen)
        end
        return out
    end
    preload("util", { tableDeepCopy = deep_copy })
    preload("gettext", function(s) return s end)
    preload("ffi/util", {
        template = function(fmt, ...)
            local args = { ... }
            return (tostring(fmt):gsub("%%(%d+)", function(n)
                local v = args[tonumber(n)]
                if v == nil then return "" end
                return tostring(v)
            end))
        end,
    })
    preload("libs/libkoreader-lfs", {
        mkdir = function(path)
            os.execute("mkdir -p " .. sh_quote(path))
            return true
        end,
        chmod = function() return true end,
    })
    preload("ltn12", {
        sink = {
            table = function(t)
                return function(chunk)
                    if chunk then t[#t + 1] = chunk end
                    return 1
                end
            end,
        },
    })
    preload("json", { decode = json_decode })
    preload("socket.http", {
        TIMEOUT = 0,
        request = function(req) return handle_request("http", req) end,
    })
    preload("ssl.https", {
        request = function(req) return handle_request("https", req) end,
    })

    local widgets = {
        "ffi/blitbuffer",
        "ui/widget/button",
        "ui/widget/container/centercontainer",
        "ui/widget/container/bottomcontainer",
        "ui/widget/container/topcontainer",
        "ui/font",
        "ui/widget/container/framecontainer",
        "ui/geometry",
        "ui/gesturerange",
        "ui/widget/horizontalgroup",
        "ui/widget/horizontalspan",
        "ui/widget/container/inputcontainer",
        "ui/widget/container/leftcontainer",
        "ui/widget/linewidget",
        "ui/widget/overlapgroup",
        "ui/widget/progresswidget",
        "ui/widget/container/rightcontainer",
        "ui/widget/container/scrollablecontainer",
        "ui/size",
        "ui/widget/textwidget",
        "ui/widget/textboxwidget",
        "ui/widget/verticalgroup",
        "ui/widget/verticalspan",
    }
    for i = 1, #widgets do
        local cls = widget_class()
        if widgets[i] == "ffi/blitbuffer" then
            cls.COLOR_BLACK = 0
            cls.COLOR_WHITE = 1
            cls.COLOR_DARK_GRAY = 2
        elseif widgets[i] == "ui/font" then
            function cls:getFace()
                return {}
            end
        elseif widgets[i] == "ui/size" then
            cls.line = { medium = 1, thin = 1, thick = 2 }
        end
        preload(widgets[i], cls)
    end
end

local case_n = 0

local function use_home()
    case_n = case_n + 1
    settings_dir = tmp .. "/case-" .. tostring(case_n)
    os.execute("mkdir -p " .. sh_quote(settings_dir))
    reset_net()
end

local function prime_settings(t)
    settings_doc = {}
    saved_settings = nil
    for k, v in pairs(t or {}) do
        settings_doc[k] = v
    end
end

local function write_cfg(filename, value)
    local dir = settings_dir .. "/magpie"
    os.execute("mkdir -p " .. sh_quote(dir))
    local f = assert(io.open(dir .. "/" .. filename, "w"))
    f:write("# synthetic\n\n", value, "\n")
    f:close()
end

local function write_gateway(url, key)
    write_cfg("base_url.txt", url or GW_URL)
    write_cfg("gateway-key.txt", key or GW_KEY)
end

local function write_web()
    write_cfg("web_url.txt", WEB_URL)
    write_cfg("web-key.txt", WEB_KEY)
end

local function scenario(name, fn)
    io.write(name, "\n")
    io.flush()
    local ok, err = xpcall(fn, debug.traceback)
    if not ok then
        failed = failed + 1
        io.stderr:write("FAIL ", name, "\n", redact(err), "\n")
    end
end


local function run_office(Office)
    scenario("Office 状态和时间边界", function()
        local now = 1700000000000
        local stuck = Office.STUCK_MS
        local quiet = Office.NOPROGRESS_MS
        local approval = Office.APPROVAL_MS
        expect(type(stuck) == "number" and stuck > 0, "STUCK_MS missing")
        expect(type(quiet) == "number" and quiet > 0, "NOPROGRESS_MS missing")
        expect(type(approval) == "number" and approval > 0, "APPROVAL_MS missing")

        local g, label, sub = Office.classify({ phase = "approval", touched = 1 }, now)
        expect(g == "need" and label == "待批准" and sub == nil, "approval is not need")
        g, label = Office.classify({ phase = "ask", touched = now }, now)
        expect(g == "need" and label == "等你回答", "ask is not need")
        g, label = Office.classify({ phase = "error", touched = now }, now)
        expect(g == "need" and label == "出错", "error is not need")

        g, label, sub = Office.classify({ phase = "tool", touched = now - stuck }, now)
        expect(g == "work" and label == "工具" and sub == nil, "tool at STUCK_MS is already stuck")
        g, label, sub = Office.classify({ phase = "tool", touched = now - stuck - 1 }, now)
        expect(g == "work" and label == "工具" and sub == "卡住", "tool beyond STUCK_MS is not stuck")

        g, label, sub = Office.classify({ phase = "thinking", touched = now - quiet }, now)
        expect(g == "work" and label == "思考" and sub == nil, "thinking at NOPROGRESS_MS has no-progress")
        g, label, sub = Office.classify({ phase = "stream", touched = now - quiet - 1 }, now)
        expect(g == "work" and label == "思考" and sub == "无进展", "thinking beyond NOPROGRESS_MS is not flagged")

        g, label = Office.classify({ phase = "done", touched = 1 }, now)
        expect(g == "done" and label == "完成", "done phase")
        g, label = Office.classify({ phase = "aborted", touched = now }, now)
        expect(g == "done" and label == "中断", "aborted phase")

        g, label = Office.classify({ inflight = 2, last_outcome = "error" }, now)
        expect(g == "work" and label == "请求中", "inflight is not in work")

        g, label = Office.classify({ last_outcome = "error" }, now)
        expect(g == "need" and label == "出错", "last outcome error")
        g, label = Office.classify({ last_outcome = "ask" }, now)
        expect(g == "need" and label == "等你回答", "last outcome ask")
        g, label, sub = Office.classify({ last_outcome = "tools", last_at = now - approval }, now)
        expect(g == "work" and label == "工具" and sub == nil, "tools at APPROVAL_MS is already need")
        g, label = Office.classify({ last_outcome = "tools", last_at = now - approval - 1 }, now)
        expect(g == "need" and label == "待批准", "tools beyond APPROVAL_MS is not need")
        g, label = Office.classify({}, now)
        expect(g == "work" and label == "思考", "missing last outcome")
        g, label = Office.classify({ last_outcome = "stop" }, now)
        expect(g == "done" and label == "完成", "terminal last outcome")
    end)

    scenario("Office.decode 拒绝空、非 JSON、缺 sessions，接受 JS 包装", function()
        local data, err = Office.decode("", json_decode)
        expect(data == nil and err == "empty", "empty string")
        data, err = Office.decode(nil, json_decode)
        expect(data == nil and err == "empty", "nil body")
        data, err = Office.decode("not json", json_decode)
        expect(data == nil and err == "no_json", "non-json")
        data, err = Office.decode("{bad}", function() error("nope") end)
        expect(data == nil and err == "bad_json", "decoder error")
        data, err = Office.decode("{}", function() return {} end)
        expect(data == nil and err == "no_sessions", "missing sessions")
        data, err = Office.decode("{x}", function() return "x" end)
        expect(data == nil and err == "bad_json", "non-table decode")
        local wrapped = '/* synthetic */ window.LIVE = {"sessions":[{"phase":"done"}]};'
        data, err = Office.decode(wrapped, json_decode)
        expect(err == nil and type(data) == "table" and type(data.sessions) == "table", "JS wrapper")
        expect(#data.sessions == 1 and data.sessions[1].phase == "done", "wrapper sessions")
    end)
end

local function run_cost(ProjCost)
    scenario("项目费用归并与“其余”", function()
        local none_pc, none_err = ProjCost.compact(nil)
        expect(none_pc == nil and none_err == "no_days", "nil stats")
        none_pc, none_err = ProjCost.compact({})
        expect(none_pc == nil and none_err == "no_days", "stats without days")
        none_pc, none_err = ProjCost.compact({ days = "nope" })
        expect(none_pc == nil and none_err == "no_days", "days not a table")

        local pc = ProjCost.compact({
            days = {
                {
                    date = "2026-11-01",
                    usage = {
                        { cwd = "/work/alpha", cost = 2 },
                        { cwd = "/other/alpha/", cost = 3 },
                        { cwd = "/work/beta", cost = 4 },
                        { cost = 1.5 },
                        { cwd = "", cost = 0.5 },
                        { cwd = "/tiny/gamma", cost = 0.25 },
                    },
                },
                {
                    date = "2026-11-02",
                    usage = {
                        { cwd = "/elsewhere/alpha", cost = 1 },
                    },
                },
            },
        })
        expect(type(pc) == "table" and pc.days and #pc.days == 2, "compact days")
        expect(pc.days[1].by.alpha == 5, "same final segment was not merged")
        expect(pc.days[1].by.beta == 4, "beta cost")
        expect(pc.days[1].none == 2, "missing cwd was not counted as none")
        expect(pc.days[1].by.gamma == 0.25, "gamma kept")

        local cross = ProjCost.summarize({
            days = {
                { date = "2026-11-01", by = { alpha = 5 }, none = 0 },
                { date = "2026-11-02", by = { alpha = 4 }, none = 0 },
            },
        }, nil)
        expect(cross.rows[1].name == "alpha" and cross.rows[1].cost == 9, "cross-day segment merge")

        local sum = ProjCost.summarize(pc, 20.25)
        expect(math.abs(sum.total - 20.25) < 1e-9, "gateway total ignored")
        local listed = 0
        for i = 1, #sum.rows do
            listed = listed + sum.rows[i].cost
            expect(sum.rows[i].name ~= "none", "none listed as a project")
            expect(sum.rows[i].cost >= 0.5, "sub-dollar row was listed")
        end
        expect(math.abs(listed - 10) < 1e-9, "listed projects")
        -- rest = gateway total - listed, which still holds none and gamma.
        expect(math.abs(sum.rest.cost - (20.25 - listed)) < 1e-9, "rest is not the remainder")
        expect(sum.rest.cost > pc.days[1].none, "rest dropped the missing-cwd cost")

        local exact = ProjCost.summarize({
            days = {
                { date = "2026-11-03", by = { alpha = 10 }, none = 4 },
            },
        }, 14)
        expect(#exact.rows == 1 and exact.rows[1].name == "alpha", "only alpha listed")
        expect(math.abs(exact.rest.cost - 4) < 1e-9, "rest is not gateway total minus listed")
    end)
end

local function run_magpie(Magpie)
    local function new_magpie()
        return Magpie:new{
            ui = { menu = { registerToMainMenu = function() end } },
        }
    end

    scenario("配置关闭写入失败不报告保存成功", function()
        use_home()
        prime_settings({ auto_refresh_sec = 60 })
        local m = new_magpie()
        local open = io.open
        local target = m:configPath("base_url")
        io.open = function(path, mode)
            if path == target and mode == "w" then
                return {
                    write = function(self) return self end,
                    close = function() return nil, "No space left on device" end,
                }
            end
            return open(path, mode)
        end
        local called, saved, err = pcall(m.writeConfigLine, m, "base_url", GW_URL)
        io.open = open
        expect(called, "configuration save raised instead of reporting failure")
        expect(saved == false and err == "write_failed", "buffered failure was reported as saved")
    end)

    scenario("配额单独失败时旧数据保留并提示过期，恢复后清除提示", function()
        use_home()
        prime_settings({ auto_refresh_sec = 60 })
        write_gateway()
        local m = new_magpie()
        local function response(quotas_ok)
            push({ body = '{"cost":4,"calls":2}' })
            push({ body = '{"cost":7,"calls":7,"series":[]}' })
            push({ body = '{"requests":0,"waiting":0,"tools":0}' })
            if quotas_ok then
                push({ body = '{"data":[{"name":"Synthetic","windows":[{"name":"5h","used":25}]}]}' })
            else
                push({ status = 503 })
                push({ status = 503 })
            end
            m:fetchAll()
        end
        response(true)
        response(false)
        local model = m:buildUsageModel()
        expect(model.quotas[1].pct == 25, "quota failure discarded the previous quota")
        expect(not model.failed, "quota failure was reported as a usage failure")
        expect(contains(model.quotas_note, "503") and contains(model.quotas_note, "上次"),
            "cached quota error is not visible as stale data")
        response(true)
        expect(m:buildUsageModel().quotas_note == nil, "quota recovery retained its error")
    end)

    scenario("趋势失败只保留相同周期的数据", function()
        use_home()
        prime_settings({ auto_refresh_sec = 60 })
        write_gateway()
        local m = new_magpie()
        m.page = Magpie.PAGE_TREND
        local function response(cost)
            push({ body = '{"cost":4,"calls":2}' })
            push({ body = '{"cost":' .. tostring(cost) .. ',"calls":7,"series":[{"label":"day 7","cost":7,"calls":7}]}' })
            push({ body = '{"requests":0,"waiting":0,"tools":0}' })
            push({ body = '{"data":[]}' })
            m:fetchAll()
        end
        response(7)
        reset_net()
        m:fetchAll()
        local model = m:buildTrendModel()
        expect(model.failed and model.total_cost == "$7", "same-period failure lost its cached total")
        m.trend_period = "30d"
        model = m:buildTrendModel()
        expect(model.total_cost == "—" and #model.series == 0, "period switch relabelled cached data before refresh")
        m:fetchAll()
        model = m:buildTrendModel()
        expect(model.period == "30d" and model.failed and model.total_cost == "—" and #model.series == 0,
            "failed new period displayed another period's data")
        response(30)
        model = m:buildTrendModel()
        expect(not model.failed and model.total_cost == "$30", "new-period recovery did not replace data")
    end)

    scenario("项目费用错误显示缺少文件和 Web 协议恢复说明", function()
        local Dash = require("dashview")
        for _, https in ipairs({ false, true }) do
            use_home()
            prime_settings({ auto_refresh_sec = 60 })
            if https then
                write_cfg("web_url.txt", "https://web.example.invalid:3430")
                write_cfg("web-key.txt", WEB_KEY)
            end
            local m = new_magpie()
            m:fetchAll()
            local model = m:buildUsageModel()
            local view = setmetatable({ inner_w = 576, model = model }, { __index = Dash })
            local tree = view:buildProjectCostTable(model.projects, false)
            local text = table.concat(collect_strings(tree), "\n")
            expect(contains(text, "web_url.txt"), "rendered hint omits the Web configuration file")
            if https then
                expect(contains(text, "http"), "rendered hint omits the supported protocol")
            else
                expect(contains(text, "web-key.txt"), "rendered hint omits the required Web key file")
            end
            no_secret(tree, WEB_KEY, "rendered recovery hint leaks the key")
        end
    end)

    scenario("旧 settings 不再保留 key", function()
        use_home()
        prime_settings({
            api_key = OLD_KEY,
            base_url = OLD_URL,
            auto_refresh_sec = 45,
        })
        local m = new_magpie()
        expect(saved_settings ~= nil, "dirty settings were not saved")
        expect(saved_settings.api_key == nil, "api_key still saved")
        expect(saved_settings.base_url == nil, "base_url still saved")
        expect(saved_settings.auto_refresh_sec == 45, "auto_refresh_sec dropped")
        expect(m.settings.api_key == nil, "api_key kept on the instance")
        expect(m.settings.base_url == nil, "base_url kept on the instance")
        expect(m.settings.auto_refresh_sec == 45, "instance refresh interval")
        no_secret(saved_settings, OLD_KEY, "saved settings contain the old key")
        no_secret(saved_settings, OLD_URL, "saved settings contain the old url")
    end)

    scenario("配置缺失不发送请求", function()
        use_home()
        prime_settings({
            api_key = OLD_KEY,
            base_url = OLD_URL,
            auto_refresh_sec = 60,
        })
        local m = new_magpie()
        reset_net()
        local data = m:httpGet("/v1/magpie/usage?period=today")
        local signed = m:webSignIn()
        expect(data == nil, "httpGet returned data without config")
        expect(signed == false, "webSignIn succeeded without config")
        expect(http_n == 0 and https_n == 0, "a request was sent without config")
        expect(#calls == 0, "socket request recorded without config")
    end)

    scenario("新目录是唯一配置来源", function()
        use_home()
        prime_settings({
            api_key = OLD_KEY,
            base_url = OLD_URL,
            auto_refresh_sec = 60,
        })
        write_gateway(GW_URL, GW_KEY)
        local m = new_magpie()
        reset_net()
        push({ fail = "down" })
        m:httpGet("/v1/magpie/usage?period=today")
        expect(#calls == 1, "configured gateway did not request once")
        expect(calls[1].transport == "http", "http gateway used the https client")
        expect(calls[1].method == "GET", "gateway method")
        expect(request_host(calls[1].url) == "gateway.example.invalid", "request host is not the file")
        expect(request_host(calls[1].url) ~= "old.example.invalid", "old settings host was requested")
        expect(calls[1].headers["Authorization"] == "Bearer " .. GW_KEY, "authorization header mismatch")
        expect(saved_settings == nil or saved_settings.api_key == nil, "old key saved beside the new directory")
        expect(saved_settings == nil or saved_settings.base_url == nil, "old url saved beside the new directory")
    end)

    scenario("更换连接不显示旧服务缓存", function()
        use_home()
        prime_settings({ auto_refresh_sec = 60 })
        write_gateway(GW_URL, GW_KEY)
        local m = new_magpie()
        m.cache.usage = { cost = 9, marker = "first-host" }
        m:reloadConnection()
        expect(m.cache.usage ~= nil and m.cache.usage.marker == "first-host", "same connection cleared usage")
        write_gateway(GW_URL_2, GW_KEY)
        m:reloadConnection()
        expect(m.cache.usage == nil, "usage cache survived a host change")
    end)


    scenario("web 登录 303 与 cookie", function()
        use_home()
        prime_settings({ auto_refresh_sec = 60 })
        write_web()
        local m = new_magpie()
        reset_net()
        push({
            status = 303,
            headers = { ["set-cookie"] = COOKIE .. "; Path=/; HttpOnly" },
            body = "",
        })
        local ok = m:webSignIn()
        expect(ok == true, "303 plus cookie did not sign in")
        expect(m.web.cookie == COOKIE, "cookie was not stored")
        expect(#calls == 1, "sign-in request count")
        expect(calls[1].method == "GET", "sign-in method")
        expect(calls[1].redirect == false, "sign-in followed redirects")
        expect(request_host(calls[1].url) == "web.example.invalid", "sign-in host")
        local path, query = request_path(calls[1].url)
        expect(path == "/", "sign-in path")
        expect(query == "?k=" .. WEB_KEY, "sign-in query is not the configured web key")
        logs_clean(WEB_KEY)
        logs_clean(COOKIE)
    end)

    scenario("web 登录 401 不保留 cookie", function()
        use_home()
        prime_settings({ auto_refresh_sec = 60 })
        write_web()
        local m = new_magpie()
        m.web.cookie = COOKIE
        reset_net()
        push({
            status = 401,
            headers = { ["set-cookie"] = COOKIE .. "; Path=/" },
            body = "",
        })
        local ok = m:webSignIn()
        expect(ok == false, "401 plus cookie was accepted")
        expect(m.web.cookie == nil, "401 cookie was kept")
        expect(#calls == 1, "failed sign-in retried")
        logs_clean(WEB_KEY)
        logs_clean(COOKIE)
    end)

    scenario("web 401 重认证一次后停止", function()
        use_home()
        prime_settings({ auto_refresh_sec = 60 })
        write_web()
        local m = new_magpie()
        m.web.cookie = "magpie_web_3430=stale"
        reset_net()
        push({ status = 401, body = "" })
        push({
            status = 303,
            headers = { ["set-cookie"] = COOKIE .. "; Path=/; HttpOnly" },
            body = "",
        })
        push({ status = 401, body = "" })
        local code = m:webGet("/api/plugin-pages")
        expect(code == 401, "second 401 was not returned")
        local signins, data_gets = 0, 0
        for i = 1, #calls do
            local path, query = request_path(calls[i].url)
            if query:sub(1, 3) == "?k=" then
                signins = signins + 1
            else
                data_gets = data_gets + 1
                expect(path == "/api/plugin-pages", "recovery requested an unexpected path")
            end
            expect(request_host(calls[i].url) == "web.example.invalid", "recovery left the web host")
        end
        expect(signins == 1, "401 caused more than one new sign-in")
        expect(data_gets == 2, "401 did not retry exactly once")
        expect(#calls == 3, "a further request followed the second 401")
        logs_clean(WEB_KEY)
        logs_clean(COOKIE)
    end)

    scenario("外部 origin 的发现链接不请求", function()
        use_home()
        prime_settings({ auto_refresh_sec = 60 })
        write_web()
        local m = new_magpie()
        m.web.cookie = COOKIE
        reset_net()
        push({
            status = 200,
            body = '[{"name":"@magpie-community/page-agent-office","url":"https://evil.example.invalid/live.js"}]',
        })
        local path, err = m:findOfficePath()
        expect(path == nil, "off-origin discovery returned a path")
        expect(err ~= nil, "off-origin discovery did not fail")
        expect(#calls == 1, "discovery did not stop after the plugin list")
        for i = 1, #calls do
            expect(request_host(calls[i].url) ~= "evil.example.invalid", "request reached the other origin")
            expect(not contains(calls[i].url, "evil.example.invalid"), "other origin appeared in a request")
        end
        logs_clean(WEB_KEY)
        logs_clean(COOKIE)
    end)

    scenario("Office 404 重新发现一次", function()
        use_home()
        prime_settings({ auto_refresh_sec = 60 })
        write_web()
        local m = new_magpie()
        m.web.cookie = COOKIE
        m.web.office_path = "/stale/live.js"
        reset_net()
        push({ status = 404, body = "missing" })
        push({
            status = 200,
            body = '[{"name":"@magpie-community/page-agent-office","url":"/plugins/office/"}]',
        })
        push({ status = 404, body = "still-missing" })
        local ok = m:fetchOffice()
        expect(ok == false, "second 404 was treated as success")
        local paths = {}
        for i = 1, #calls do
            local path = request_path(calls[i].url)
            paths[#paths + 1] = path
            expect(request_host(calls[i].url) == "web.example.invalid", "office fetch left the web host")
        end
        expect(paths[1] == "/stale/live.js", "404 did not hit the previous path")
        expect(paths[2] == "/api/plugin-pages", "404 did not discover again")
        expect(paths[3] == "/plugins/office/live.js", "discovery result was not fetched")
        expect(#paths == 3, "discovery ran more than once")
        expect(m.web.office_path ~= "/stale/live.js", "404 did not clear the stale path")
        logs_clean(WEB_KEY)
        logs_clean(COOKIE)
    end)

    scenario("网关错误不含 key", function()
        use_home()
        prime_settings({ auto_refresh_sec = 60 })
        write_gateway(GW_URL, GW_KEY)
        local m = new_magpie()
        reset_net()
        push({ fail = "transport " .. GW_KEY })
        local data, err, msg = m:httpGet("/v1/magpie/usage?period=today")
        expect(data == nil, "transport failure returned data")
        expect(#calls == 1, "transport failure did not request")
        no_secret(err, GW_KEY, "gateway error code contains the key")
        no_secret(msg, GW_KEY, "gateway error text contains the key")
        logs_clean(GW_KEY)

        reset_net()
        push({ status = 500, body = GW_KEY })
        data, err, msg = m:httpGet("/v1/magpie/usage?period=today")
        expect(data == nil, "HTTP failure returned data")
        no_secret(err, GW_KEY, "HTTP error code contains the key")
        no_secret(msg, GW_KEY, "HTTP error text contains the key")
        no_secret(err, "Bearer", "HTTP error contains authorization")
        no_secret(msg, "Bearer", "HTTP error text contains authorization")
        logs_clean(GW_KEY)
    end)
    scenario("错误后保留旧数据并标记过期", function()
        use_home()
        prime_settings({ auto_refresh_sec = 60 })
        write_gateway(GW_URL, GW_KEY)
        local m = new_magpie()
        reset_net()
        local body = '{"cost":4,"calls":2,"input":8,"output":1}'
        push({ status = 200, body = body })
        push({ status = 200, body = body })
        push({ status = 200, body = '{"requests":1,"waiting":0,"tools":0}' })
        push({ status = 200, body = '{"data":[]}' })
        local ok = m:fetchAll()
        expect(ok == true, "synthetic fetch did not succeed")
        expect(type(m.cache.usage) == "table" and m.cache.usage.cost == 4, "usage was not stored")
        local kept = m.cache.usage
        reset_net()
        m:fetchAll()
        expect(m.cache.usage == kept, "failed refresh dropped the previous usage")
        expect(m.cache.usage_err ~= nil and m.cache.usage_err ~= "", "usage error was not marked")
        expect(m.cache.fail_msg ~= nil and m.cache.fail_msg ~= "", "stale marker missing")
        no_secret(m.cache.usage_err, GW_KEY, "stale marker contains the gateway key")
        no_secret(m.cache.fail_msg, GW_KEY, "fail marker contains the gateway key")
        logs_clean(GW_KEY)
    end)
end

local function cleanup()
    if tmp and tmp:sub(1, 5) == "/tmp/" and not tmp:find("%.%.", 1, true) then
        os.execute("rm -rf " .. sh_quote(tmp))
    end
end

local function main()
    local base = os.tmpname()
    os.remove(base)
    tmp = base
    settings_dir = tmp
    os.execute("mkdir -p " .. sh_quote(tmp))
    install_stubs()
    local Office = require("office")
    local ProjCost = require("projcost")
    run_office(Office)
    run_cost(ProjCost)
    local Magpie = require("main")
    run_magpie(Magpie)
end

local ok, err = xpcall(main, debug.traceback)
cleanup()
if not ok then
    io.stderr:write("FAIL setup\n", redact(err), "\n")
    os.exit(1)
end
os.exit(failed == 0 and 0 or 1)
