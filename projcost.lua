--[[--
Per-project cost from magpie web GET /api/sessions/stats?days=N
(design-project-cost A). Pure Lua — testable with plain luajit.

stats.days[] = { date = "YYYY-MM-DD", usage = [{ cwd, agent, model, cost, … }] }
Project = last path segment of cwd (same naming as the 在飞 tab).
"其余" = gateway total − listed projects: the smaller projects, sessions
without a cwd and requests without a session, in one row (user's call).
]]

local ProjCost = {}

local function basename(p)
    if type(p) ~= "string" or p == "" then return nil end
    p = p:gsub("/+$", "")
    return p:match("([^/]+)$")
end

-- Keep only { date, by = { project → cost }, none = cost without cwd }.
function ProjCost.compact(stats)
    if type(stats) ~= "table" or type(stats.days) ~= "table" then
        return nil, "no_days"
    end
    local days = {}
    for _, d in ipairs(stats.days) do
        if type(d) == "table" and type(d.date) == "string" then
            local by, none = {}, 0
            for _, u in ipairs(type(d.usage) == "table" and d.usage or {}) do
                if type(u) == "table" then
                    local cost = tonumber(u.cost) or 0
                    local name = basename(u.cwd)
                    if name then
                        by[name] = (by[name] or 0) + cost
                    else
                        none = none + cost
                    end
                end
            end
            table.insert(days, { date = d.date, by = by, none = none })
        end
    end
    return { days = days }
end

--[[ Summarize for a list + optional stacked chart.
gw_total: gateway cost for the same period (nil → sum of stats).
opts.top (5), opts.stack (3).
Returns {
  total, rows = {{ name, cost, pct, share }}, rest = { n, cost, pct },
  stack_names = { up to 3 names }, per_day = { [date] = { c1, c2, c3 } },
}
pct = share of total (0..100), share = cost / top row (0..1, for the bar).
]]
function ProjCost.summarize(pc, gw_total, opts)
    opts = opts or {}
    local top_n = opts.top or 5
    local stack_n = opts.stack or 3
    local totals, order = {}, {}
    local none = 0
    for _, d in ipairs(pc and pc.days or {}) do
        none = none + (d.none or 0)
        for name, cost in pairs(d.by) do
            if not totals[name] then
                totals[name] = 0
                table.insert(order, name)
            end
            totals[name] = totals[name] + cost
        end
    end
    table.sort(order, function(a, b)
        if totals[a] ~= totals[b] then return totals[a] > totals[b] end
        return a < b
    end)
    local named = 0
    for _, name in ipairs(order) do named = named + totals[name] end
    local total = tonumber(gw_total)
    if not total or total <= 0 then total = named + none end

    local rows, listed = {}, 0
    local top_cost = (#order > 0) and totals[order[1]] or 0
    for i = 1, math.min(top_n, #order) do
        local name = order[i]
        local c = totals[name]
        if c < 0.5 then break end -- would print as <$1/$0: leave it to 其余
        listed = listed + c
        table.insert(rows, {
            name = name,
            cost = c,
            pct = (total > 0) and (c * 100 / total) or 0,
            share = (top_cost > 0) and (c / top_cost) or 0,
        })
    end
    local rest_cost = total - listed
    if rest_cost < 0 then rest_cost = 0 end
    local rest = {
        n = #order - #rows, -- projects folded in (plus unattributed spend)
        cost = rest_cost,
        pct = (total > 0) and (rest_cost * 100 / total) or 0,
    }

    local stack_names = {}
    for i = 1, math.min(stack_n, #rows) do stack_names[i] = rows[i].name end
    local per_day = {}
    for _, d in ipairs(pc and pc.days or {}) do
        local parts = {}
        for i, name in ipairs(stack_names) do parts[i] = d.by[name] or 0 end
        per_day[d.date] = parts
    end

    return {
        total = total,
        rows = rows,
        rest = rest,
        stack_names = stack_names,
        per_day = per_day,
    }
end

-- $53 · $1,392 · <$1 · $0
function ProjCost.money(n)
    n = tonumber(n) or 0
    if n < 0.5 then
        return (n > 0) and "<$1" or "$0"
    end
    local s = tostring(math.floor(n + 0.5))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return "$" .. out
end

return ProjCost
