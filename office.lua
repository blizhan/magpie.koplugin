--[[--
Agent-office snapshot → per-project model for the 在飞 tab (design A + D).

Pure Lua (no KOReader requires) so it can be tested with plain luajit.
Input: page/live.js of @magpie-community/page-agent-office
  "globalThis.AgentOfficeLive = {v:2, written, text, sessions:[...]};"
Status mapping follows the plugin's page/model.js state():
  approval→待批准 / ask→等你回答 / error→出错        = need
  tool→工具 (>10m 卡住) / thinking→思考 (>8m 无进展) = work
  done→完成 / aborted→中断                           = done
Gateway-only sessions (no phase): inflight>0 → 请求中; last.outcome
  error/ask → need; tools → 工具, or 待批准 after 90s; else done.
]]

local Office = {}

Office.STUCK_MS = 10 * 60 * 1000
Office.NOPROGRESS_MS = 8 * 60 * 1000
Office.IDLE_MS = 20 * 60 * 1000
Office.APPROVAL_MS = 90 * 1000
Office.NO_PROJECT = "（无项目）"

local RANK = { need = 1, work = 2, done = 3 }

local function str(v)
    if type(v) == "string" then return v end
    if type(v) == "number" then return tostring(v) end
    return nil
end

local function num(v)
    if type(v) == "number" then return v end
    if type(v) == "string" then return tonumber(v) end
    return nil
end

-- One line, collapsed whitespace, at most n UTF-8 chars (TextWidget still
-- ellipsizes to pixel width; this only bounds string size).
function Office.oneLine(s, n)
    s = str(s)
    if not s or s == "" then return nil end
    s = s:gsub("[\r\n\t]+", " "):gsub("%s%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    s = s:gsub("%*%*", ""):gsub("`", ""):gsub("^#+%s*", "")
    if s == "" then return nil end
    n = n or 60
    local out, count = {}, 0
    for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        count = count + 1
        if count > n then
            table.insert(out, "…")
            break
        end
        table.insert(out, ch)
    end
    return table.concat(out)
end

-- "codex/gpt-6.1-sol" → "gpt-6.1-sol"; "claude/claude-opus-5-5" → "opus-5-5"
function Office.shortModel(m)
    m = str(m)
    if not m or m == "" then return nil end
    m = m:match("([^/]+)$") or m
    m = m:gsub("^claude%-", "")
    return m
end

-- "bash · git status …" → "bash"; "mcp__magpie__bash · …" → "bash"
function Office.toolName(step)
    step = str(step)
    if not step or step == "" then return nil end
    local name = step:match("^(.-)%s+·%s") or step:match("^(%S+)") or step
    name = name:gsub("^mcp__[%w_-]-__", "")
    if #name > 24 then name = name:sub(1, 24) end
    return name
end

function Office.fmtAge(ms)
    ms = num(ms)
    if not ms then return "—" end
    if ms < 0 then ms = 0 end
    local s = ms / 1000
    if s < 60 then return "刚刚" end
    local m = s / 60
    if m < 60 then return string.format("%dm", math.floor(m)) end
    local h = m / 60
    if h < 10 then
        local v = string.format("%.1f", h):gsub("%.0$", "")
        return v .. "h"
    end
    if h < 48 then return string.format("%dh", math.floor(h)) end
    return string.format("%dd", math.floor(h / 24))
end

local function basename(p)
    p = str(p)
    if not p or p == "" then return nil end
    p = p:gsub("/+$", "")
    return p:match("([^/]+)$")
end

-- Strip the JS wrapper and decode. decode_fn(json_string) → table.
function Office.decode(body, decode_fn)
    if type(body) ~= "string" or body == "" then
        return nil, "empty"
    end
    local a = body:find("{", 1, true)
    local b
    for i = #body, 1, -1 do
        if body:byte(i) == 125 then b = i break end -- '}'
    end
    if not a or not b or b < a then
        return nil, "no_json"
    end
    local ok, data = pcall(decode_fn, body:sub(a, b))
    if not ok or type(data) ~= "table" then
        return nil, "bad_json"
    end
    if type(data.sessions) ~= "table" then
        return nil, "no_sessions"
    end
    return data
end

-- Keep only what the Kindle page needs (drops messages/query/reply).
function Office.compact(data)
    local out = {}
    for _, s in ipairs(data.sessions or {}) do
        if type(s) == "table" then
            local last = type(s.last) == "table" and s.last or nil
            local project = str(s.project)
            if not project or project == "" then project = basename(s.cwd) end
            table.insert(out, {
                agent = str(s.agent) or "agent",
                model = Office.shortModel(s.model),
                project = project or Office.NO_PROJECT,
                title = Office.oneLine(s.title, 48),
                step = Office.oneLine(s.step, 60),
                tool = Office.toolName(s.step),
                phase = str(s.phase),
                source = str(s.source),
                updated = num(s.updated) or 0,
                touched = num(s.touched) or num(s.updated) or 0,
                turns = num(s.turns) or 0,
                context = num(s.context) or 0,
                context_window = num(s.contextWindow) or 0,
                subagent = s.subagent == true,
                inflight = num(s.inflight) or 0,
                last_outcome = last and str(last.outcome) or nil,
                last_at = last and num(last.at) or nil,
            })
        end
    end
    return out
end

-- → group ("need"|"work"|"done"), label, sub (nil | "卡住" | "无进展")
function Office.classify(s, now_ms)
    local quiet = now_ms - ((s.touched and s.touched > 0) and s.touched or s.updated or now_ms)
    local ph = s.phase
    if ph and ph ~= "" then
        if ph == "approval" then return "need", "待批准" end
        if ph == "ask" then return "need", "等你回答" end
        if ph == "error" then return "need", "出错" end
        if ph == "aborted" then return "done", "中断" end
        if ph == "done" then return "done", "完成" end
        if ph == "tool" then
            if quiet > Office.STUCK_MS then return "work", "工具", "卡住" end
            return "work", "工具"
        end
        if quiet > Office.NOPROGRESS_MS then return "work", "思考", "无进展" end
        return "work", "思考"
    end
    -- gateway-only session
    if (s.inflight or 0) > 0 then return "work", "请求中" end
    local o = s.last_outcome
    if o == "error" then return "need", "出错" end
    if o == "ask" then return "need", "等你回答" end
    if o == "tools" then
        if s.last_at and now_ms - s.last_at > Office.APPROVAL_MS then
            return "need", "待批准"
        end
        return "work", "工具"
    end
    if not s.last_outcome then return "work", "思考" end
    return "done", "完成"
end

local function row_of(s, now_ms)
    local group, label, sub = Office.classify(s, now_ms)
    local who = {}
    if s.model then table.insert(who, s.model) end
    if s.tool then table.insert(who, s.tool) end
    local ctx_pct = nil
    if s.context_window and s.context_window > 0 and s.context and s.context > 0 then
        ctx_pct = math.min(100, math.floor(s.context * 100 / s.context_window + 0.5))
    end
    return {
        group = group,
        label = label,
        sub = sub,
        agent = s.agent,
        meta = table.concat(who, " · "),
        title = s.title,
        step = s.step,
        age = Office.fmtAge(now_ms - (s.updated or now_ms)),
        updated = s.updated or 0,
        turns = s.turns or 0,
        ctx_pct = ctx_pct,
        subagent = s.subagent,
    }
end

local function by_group_then_recent(a, b)
    if RANK[a.group] ~= RANK[b.group] then return RANK[a.group] < RANK[b.group] end
    return (a.updated or 0) > (b.updated or 0)
end

--[[ Build the page model.
opts.rows_per_card (2), opts.detail_cap (40)
Returns {
  need, need_sub, work, work_projects, total_projects,
  active = {project...}, idle = {project...}, by_name = {name → project}
}
project = { name, need, work, done, last, last_age, rank, rows (≤N active, or 1 done),
            more (hidden active count), sessions (all rows, sorted) }
]]
function Office.build(sessions, now_ms, opts)
    opts = opts or {}
    local per_card = opts.rows_per_card or 2
    local cap = opts.detail_cap or 40
    local projects, order = {}, {}
    local need_labels, need_label_order = {}, {}
    local total_need, total_work = 0, 0

    for _, s in ipairs(sessions or {}) do
        local r = row_of(s, now_ms)
        local name = s.project or Office.NO_PROJECT
        local p = projects[name]
        if not p then
            p = { name = name, need = 0, work = 0, done = 0, last = 0, all = {} }
            projects[name] = p
            table.insert(order, p)
        end
        p[r.group] = p[r.group] + 1
        if r.updated > p.last then p.last = r.updated end
        table.insert(p.all, r)
        if r.group == "need" then
            total_need = total_need + 1
            if not need_labels[r.label] then
                need_labels[r.label] = 0
                table.insert(need_label_order, r.label)
            end
            need_labels[r.label] = need_labels[r.label] + 1
        elseif r.group == "work" then
            total_work = total_work + 1
        end
    end

    local active, idle = {}, {}
    local work_projects = 0
    for _, p in ipairs(order) do
        table.sort(p.all, by_group_then_recent)
        p.last_age = Office.fmtAge(now_ms - p.last)
        if p.need > 0 then
            p.rank = 1
        elseif p.work > 0 then
            p.rank = 2
        elseif now_ms - p.last <= Office.IDLE_MS then
            p.rank = 3
        else
            p.rank = 4
        end
        if p.work > 0 then work_projects = work_projects + 1 end

        p.rows = {}
        local live = p.need + p.work
        if live > 0 then
            for i = 1, math.min(per_card, live) do
                table.insert(p.rows, p.all[i])
            end
            p.more = live - #p.rows
        else
            table.insert(p.rows, p.all[1])
            p.more = 0
        end
        p.sessions = {}
        for i = 1, math.min(cap, #p.all) do
            table.insert(p.sessions, p.all[i])
        end
        p.hidden = #p.all - #p.sessions
        p.agents = {}
        local seen = {}
        for _, r in ipairs(p.all) do
            if not seen[r.agent] then
                seen[r.agent] = 0
                table.insert(p.agents, r.agent)
            end
            seen[r.agent] = seen[r.agent] + 1
        end
        p.agent_counts = seen
        p.all = nil
        if p.rank == 4 then
            table.insert(idle, p)
        else
            table.insert(active, p)
        end
    end

    local function by_rank_recent(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.last > b.last
    end
    table.sort(active, by_rank_recent)
    table.sort(idle, function(a, b) return a.last > b.last end)

    local need_sub = {}
    for _, l in ipairs(need_label_order) do
        table.insert(need_sub, l .. " " .. need_labels[l])
    end

    local by_name = {}
    for _, p in ipairs(active) do by_name[p.name] = p end
    for _, p in ipairs(idle) do by_name[p.name] = p end

    return {
        need = total_need,
        need_sub = (#need_sub > 0) and table.concat(need_sub, " · ") or "—",
        work = total_work,
        work_projects = work_projects,
        total_projects = #order,
        active = active,
        idle = idle,
        by_name = by_name,
    }
end

return Office
