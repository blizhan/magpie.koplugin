--[[--
Magpie fullscreen dashboard (nav-v3 chrome).

Top: ☰ + HH:MM | Magpie · page | ↻ + ×
Bottom: 用量 | 在飞 | 趋势 (selected inverted)
Pages: usage (KPI+quotas), concurrency, trend (series bars)
]]

local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local CenterContainer = require("ui/widget/container/centercontainer")
local BottomContainer = require("ui/widget/container/bottomcontainer")
local TopContainer = require("ui/widget/container/topcontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InputContainer = require("ui/widget/container/inputcontainer")
local LeftContainer = require("ui/widget/container/leftcontainer")
local LineWidget = require("ui/widget/linewidget")
local OverlapGroup = require("ui/widget/overlapgroup")
local ProgressWidget = require("ui/widget/progresswidget")
local RightContainer = require("ui/widget/container/rightcontainer")
local ScrollableContainer = require("ui/widget/container/scrollablecontainer")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local TextBoxWidget = require("ui/widget/textboxwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("gettext")
local Screen = Device.screen

local BLACK = Blitbuffer.COLOR_BLACK
local WHITE = Blitbuffer.COLOR_WHITE
local GRAY = Blitbuffer.COLOR_DARK_GRAY

local MagpieDash = InputContainer:extend{
    covers_fullscreen = true,
    page = "usage", -- "usage" | "concurrency" | "trend"
    model = nil,
    on_refresh = nil,
    on_tab = nil, -- function(page_name)
    on_close = nil,
    on_period = nil, -- function("today"|"7d"|"30d")
    on_metric = nil, -- function("cost"|"calls")
    on_project = nil, -- function(name) — 在飞 project detail
    on_back = nil,    -- function() — leave project detail
}

local function face(name, size)
    return Font:getFace(name, size)
end

function MagpieDash:init()
    self.model = self.model or {}
    self.width = Screen:getWidth()
    self.height = Screen:getHeight()
    self.dimen = Geom:new{ x = 0, y = 0, w = self.width, h = self.height }
    self.pad = Screen:scaleBySize(12)
    self.inner_w = self.width - 2 * self.pad

    self.face_title = face("infofont", 18)
    self.face_meta = face("smallinfofont", 13)
    self.face_label = face("smallinfofont", 13)
    self.face_value = face("infofont", 20)
    self.face_sec = face("infofont", 15)
    self.face_row = face("smallinfofont", 15)
    self.face_bar = face("smallinfofontbold", 14)
    self.face_chip = face("smallinfofontbold", 13)
    self.face_stat = face("infofont", 28)
    self.face_kpi = face("infofont", 18)
    self.face_sub = face("smallinfofont", 11)
    self.face_clock = face("smallinfofontbold", 13)
    self.face_name = face("infofont", 17)
    self.face_sum = face("infofont", 22)
    self.face_hero = face("infofont", 44)
    self.face_mini = face("infofont", 22)
    self.face_qname = face("smallinfofont", 15)
    self.face_money = face("infofont", 16)

    self:build()

    if Device:hasKeys() then
        self.key_events.Close = { { Device.input.group.Back } }
        self.key_events.Refresh = { { "Press" } }
    end
    if Device:isTouchDevice() then
        local range = Geom:new{ x = 0, y = 0, w = self.width, h = self.height }
        self.ges_events.Swipe = {
            GestureRange:new{ ges = "swipe", range = range },
        }
    end

    UIManager:setDirty(self, function()
        return "ui", self.dimen
    end)
end

function MagpieDash:onClose()
    if self.on_close then
        self.on_close()
    else
        UIManager:close(self)
    end
    return true
end

function MagpieDash:onRefresh()
    if self.on_refresh then self.on_refresh() end
    return true
end

function MagpieDash:onSwipe(arg, ges)
    if not ges then return false end
    local dir = ges.direction
    if dir == "east" and self.page == "concurrency" and self.model and self.model.detail then
        if self.on_back then self.on_back() end
        return true
    end
    if dir == "west" or dir == "east" then
        local order = { "usage", "concurrency", "trend" }
        local idx = 1
        for i, p in ipairs(order) do
            if p == self.page then idx = i break end
        end
        local offset = dir == "west" and 1 or -1
        local target = order[((idx - 1 + offset) % #order) + 1]
        if self.on_tab then self.on_tab(target) end
        return true
    elseif dir == "south" then
        if self.on_refresh then self.on_refresh() end
        return true
    elseif dir == "north" then
        return true
    end
    return false
end

function MagpieDash:hline()
    return LineWidget:new{
        background = BLACK,
        dimen = Geom:new{ w = self.inner_w, h = Size.line.medium },
    }
end

function MagpieDash:vspan(px)
    return VerticalSpan:new{ width = Screen:scaleBySize(px or 6) }
end

function MagpieDash:text(str, f, fg)
    return TextWidget:new{
        text = tostring(str or ""),
        face = f or self.face_row,
        fgcolor = fg or BLACK,
        max_width = self.inner_w,
    }
end

function MagpieDash:buildTopBar()
    local m = self.model
    local title = m.title or _("Magpie")
    local clock = tostring(m.clock or "—")
    if m.refreshing then
        clock = "…"
    end
    -- Wider side rails + taller bar so ☰/↻/× are e-ink friendly hit targets.
    local side_w = Screen:scaleBySize(118)
    local mid_w = self.width - 2 * side_w
    local bar_h = Screen:scaleBySize(52)
    local icon_h = bar_h - Screen:scaleBySize(2)
    local that = self

    local in_detail = (self.page == "concurrency") and (m.detail ~= nil)
    local menu_btn = Button:new{
        text = in_detail and "‹" or "☰",
        bordersize = 0,
        padding_h = Screen:scaleBySize(8),
        padding_v = Screen:scaleBySize(8),
        radius = 0,
        text_font_face = "infofont",
        text_font_size = 24,
        text_font_bold = true,
        callback = function()
            -- ☰ is decorative chrome; ‹ leaves the project detail.
            if in_detail and that.on_back then that.on_back() end
        end,
        show_parent = self,
    }

    local left = HorizontalGroup:new{
        align = "center",
        menu_btn,
        HorizontalSpan:new{ width = Screen:scaleBySize(2) },
        TextWidget:new{ text = clock, face = self.face_clock, fgcolor = BLACK },
    }

    local refresh_btn = Button:new{
        text = "↻",
        bordersize = 0,
        padding_h = Screen:scaleBySize(10),
        padding_v = Screen:scaleBySize(8),
        radius = 0,
        text_font_face = "infofont",
        text_font_size = 24,
        text_font_bold = true,
        callback = function()
            if that.on_refresh then that.on_refresh() end
        end,
        show_parent = self,
    }
    local close_btn = Button:new{
        text = "×",
        bordersize = 0,
        padding_h = Screen:scaleBySize(10),
        padding_v = Screen:scaleBySize(8),
        radius = 0,
        text_font_face = "infofont",
        text_font_size = 26,
        text_font_bold = true,
        callback = function()
            that:onClose()
        end,
        show_parent = self,
    }

    local right = HorizontalGroup:new{
        align = "center",
        refresh_btn,
        close_btn,
    }

    return FrameContainer:new{
        width = self.width,
        height = bar_h,
        background = WHITE,
        bordersize = 0,
        padding = 0,
        margin = 0,
        VerticalGroup:new{
            align = "left",
            OverlapGroup:new{
                dimen = Geom:new{ w = self.width, h = icon_h },
                allow_mirroring = false,
                LeftContainer:new{
                    dimen = Geom:new{ w = self.width, h = icon_h },
                    HorizontalGroup:new{
                        HorizontalSpan:new{ width = Screen:scaleBySize(4) },
                        LeftContainer:new{
                            dimen = Geom:new{ w = side_w, h = icon_h },
                            left,
                        },
                    },
                },
                CenterContainer:new{
                    dimen = Geom:new{ w = self.width, h = icon_h },
                    TextWidget:new{
                        text = title,
                        face = self.face_title,
                        fgcolor = BLACK,
                        max_width = mid_w,
                    },
                },
                RightContainer:new{
                    dimen = Geom:new{ w = self.width, h = icon_h },
                    HorizontalGroup:new{
                        RightContainer:new{
                            dimen = Geom:new{ w = side_w, h = icon_h },
                            right,
                        },
                        HorizontalSpan:new{ width = Screen:scaleBySize(2) },
                    },
                },
            },
            LineWidget:new{
                background = BLACK,
                dimen = Geom:new{ w = self.width, h = Size.line.medium },
            },
        },
    }
end

function MagpieDash:buildQuotaBar(pct, reset_text)
    pct = tonumber(pct) or 0
    if pct < 0 then pct = 0 end
    if pct > 100 then pct = 100 end
    local bar_h = Screen:scaleBySize(26)
    local bar_w = self.inner_w
    local ratio = pct / 100

    local progress = ProgressWidget:new{
        width = bar_w,
        height = bar_h,
        percentage = ratio,
        bordercolor = BLACK,
        bgcolor = WHITE,
        fillcolor = BLACK,
        bordersize = Screen:scaleBySize(2),
        margin_h = 0,
        margin_v = 0,
        radius = 0,
        ticks = nil,
        last = nil,
    }

    local pct_color = (pct >= 22) and WHITE or BLACK
    local reset_color = (pct >= 88) and WHITE or BLACK
    local pad = Screen:scaleBySize(8)

    local left = LeftContainer:new{
        dimen = Geom:new{ w = bar_w, h = bar_h },
        HorizontalGroup:new{
            HorizontalSpan:new{ width = pad },
            TextWidget:new{
                text = string.format("%d%%", math.floor(pct + 0.5)),
                face = self.face_bar,
                fgcolor = pct_color,
            },
        },
    }
    local right = RightContainer:new{
        dimen = Geom:new{ w = bar_w, h = bar_h },
        HorizontalGroup:new{
            TextWidget:new{
                text = "↻ " .. tostring(reset_text or "—"),
                face = self.face_bar,
                fgcolor = reset_color,
            },
            HorizontalSpan:new{ width = pad },
        },
    }

    return OverlapGroup:new{
        dimen = Geom:new{ w = bar_w, h = bar_h },
        allow_mirroring = false,
        progress,
        left,
        right,
    }
end

function MagpieDash:buildStatCell(label, value, inverted, cell_w, cell_h)
    local fg = inverted and WHITE or BLACK
    local bg = inverted and BLACK or WHITE
    return FrameContainer:new{
        width = cell_w,
        height = cell_h,
        background = bg,
        bordersize = Screen:scaleBySize(2),
        bordercolor = BLACK,
        padding = Screen:scaleBySize(6),
        margin = 0,
        CenterContainer:new{
            dimen = Geom:new{
                w = cell_w - Screen:scaleBySize(16),
                h = cell_h - Screen:scaleBySize(16),
            },
            VerticalGroup:new{
                align = "center",
                TextWidget:new{ text = tostring(label), face = self.face_chip, fgcolor = fg },
                VerticalSpan:new{ width = Screen:scaleBySize(2) },
                TextWidget:new{ text = tostring(value), face = self.face_stat, fgcolor = fg },
            },
        },
    }
end

function MagpieDash:buildKpiCell(label, value, sub, cell_w, cell_h)
    -- FrameContainer:getSize() sizes from child, ignoring width/height.
    -- Pin an inner LeftContainer dimen so every cell shares the same box.
    local border = Screen:scaleBySize(2)
    local pad = Screen:scaleBySize(6)
    local inner_w = cell_w - (border + pad) * 2
    local inner_h = cell_h - (border + pad) * 2
    if inner_w < Screen:scaleBySize(24) then inner_w = Screen:scaleBySize(24) end
    if inner_h < Screen:scaleBySize(24) then inner_h = Screen:scaleBySize(24) end

    local kids = {
        TextWidget:new{
            text = tostring(label),
            face = self.face_label,
            fgcolor = GRAY,
            max_width = inner_w,
        },
        VerticalSpan:new{ width = Screen:scaleBySize(2) },
        TextWidget:new{
            text = tostring(value),
            face = self.face_kpi,
            fgcolor = BLACK,
            max_width = inner_w,
        },
    }
    if sub and sub ~= "" then
        table.insert(kids, VerticalSpan:new{ width = Screen:scaleBySize(1) })
        table.insert(kids, TextWidget:new{
            text = tostring(sub),
            face = self.face_sub,
            fgcolor = GRAY,
            max_width = inner_w,
        })
    end
    local vg = VerticalGroup:new{ align = "left" }
    for _, w in ipairs(kids) do
        table.insert(vg, w)
    end
    return FrameContainer:new{
        background = WHITE,
        bordersize = border,
        color = BLACK,
        padding = pad,
        margin = 0,
        LeftContainer:new{
            dimen = Geom:new{ w = inner_w, h = inner_h },
            vg,
        },
    }
end

function MagpieDash:buildSummaryGrid(summary)
    summary = summary or {}
    local gap = Screen:scaleBySize(6)
    local avail = self.inner_w - 2 * gap
    local cell_w = math.floor(avail / 3)
    local rem = avail - cell_w * 3
    -- Same height for both rows so column lines align like nav-v3 CSS grid.
    local cell_h = Screen:scaleBySize(72)
    local widths = { cell_w, cell_w, cell_w + rem }
    local rows = {
        {
            { "请求", summary.requests or "—", nil },
            { "费用", summary.cost or "—", nil },
            { "Token", summary.tokens or "—", nil },
        },
        {
            { "缓存命中", summary.cache_hit or "—", summary.cache_hit_sub },
            { "速度", summary.speed or "—", summary.speed_sub },
            { "会话", summary.sessions or "—", summary.sessions_sub },
        },
    }
    local vg = VerticalGroup:new{ align = "left" }
    for ri, row in ipairs(rows) do
        local hg = HorizontalGroup:new{ align = "top" }
        for i, cell in ipairs(row) do
            table.insert(hg, self:buildKpiCell(cell[1], cell[2], cell[3], widths[i], cell_h))
            if i < 3 then
                table.insert(hg, HorizontalSpan:new{ width = gap })
            end
        end
        table.insert(vg, hg)
        if ri == 1 then
            table.insert(vg, self:vspan(6))
        end
    end
    return vg
end

function MagpieDash:buildStatusBanner()
    local m = self.model
    if m.refreshing then
        return FrameContainer:new{
            background = BLACK,
            bordersize = Screen:scaleBySize(2),
            padding = Screen:scaleBySize(4),
            TextWidget:new{
                text = _("刷新中…"),
                face = self.face_chip,
                fgcolor = WHITE,
            },
        }
    end
    if m.failed and m.fail_text then
        return FrameContainer:new{
            background = WHITE,
            bordersize = Screen:scaleBySize(2),
            bordercolor = BLACK,
            padding = Screen:scaleBySize(6),
            width = self.inner_w,
            TextBoxWidget:new{
                text = tostring(m.fail_text),
                face = self.face_meta,
                width = self.inner_w - Screen:scaleBySize(16),
                fgcolor = BLACK,
            },
        }
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- 用量 A (design-project-cost): hero cost + 4 minis, one-line quotas, 按项目

local SWATCH = {
    Blitbuffer.COLOR_BLACK,
    Blitbuffer.COLOR_GRAY_6,
    Blitbuffer.COLOR_LIGHT_GRAY,
}

function MagpieDash:buildUsageKpis(sm)
    sm = sm or {}
    local gap = Screen:scaleBySize(6)
    local total_h = Screen:scaleBySize(150)
    local hero_w = Screen:scaleBySize(232)
    local mini_w = math.floor((self.inner_w - hero_w - 2 * gap) / 2)
    local mini_w2 = self.inner_w - hero_w - 2 * gap - mini_w
    local mini_h = math.floor((total_h - gap) / 2)
    local pad = Screen:scaleBySize(10)

    local hero_inner_w = hero_w - 2 * pad
    local hero = FrameContainer:new{
        background = BLACK,
        bordersize = 0,
        padding = pad,
        margin = 0,
        TopContainer:new{
            dimen = Geom:new{ w = hero_inner_w, h = total_h - 2 * pad },
            VerticalGroup:new{
                align = "left",
                TextWidget:new{ text = _("今日费用"), face = self.face_chip, fgcolor = WHITE },
                VerticalSpan:new{ width = Screen:scaleBySize(10) },
                TextWidget:new{ text = tostring(sm.cost or "—"), face = self.face_hero, bold = true, fgcolor = WHITE, max_width = hero_inner_w },
                VerticalSpan:new{ width = Screen:scaleBySize(8) },
                TextWidget:new{ text = tostring(sm.hero_sub or ""), face = self.face_sub, fgcolor = WHITE, max_width = hero_inner_w },
            },
        },
    }
    local function mini(value, label, w)
        local border = Screen:scaleBySize(2)
        local mpad = Screen:scaleBySize(8)
        local iw = w - 2 * (border + mpad)
        return FrameContainer:new{
            background = WHITE,
            bordersize = border,
            color = BLACK,
            padding = 0,
            padding_left = mpad,
            padding_right = mpad,
            margin = 0,
            LeftContainer:new{
                dimen = Geom:new{ w = iw, h = mini_h - 2 * border },
                VerticalGroup:new{
                    align = "left",
                    TextWidget:new{ text = tostring(value or "—"), face = self.face_mini, bold = true, fgcolor = BLACK, max_width = iw },
                    TextWidget:new{ text = tostring(label), face = self.face_sub, fgcolor = GRAY, max_width = iw },
                },
            },
        }
    end
    return HorizontalGroup:new{
        align = "top",
        hero,
        HorizontalSpan:new{ width = gap },
        VerticalGroup:new{
            align = "left",
            HorizontalGroup:new{ align = "top",
                mini(sm.requests, _("请求"), mini_w), HorizontalSpan:new{ width = gap }, mini(sm.tokens, "Token", mini_w2) },
            VerticalSpan:new{ width = gap },
            HorizontalGroup:new{ align = "top",
                mini(sm.cache_hit, _("缓存命中"), mini_w), HorizontalSpan:new{ width = gap }, mini(sm.speed, "tok/s", mini_w2) },
        },
    }
end

-- one line: name (+gray sub) | bar with "5h 58%" inside | ↻ reset
function MagpieDash:buildQuotaRow(q)
    local row_h = Screen:scaleBySize(29)
    local name_w = Screen:scaleBySize(156)
    local reset_w = Screen:scaleBySize(66)
    local gap = Screen:scaleBySize(8)
    local bar_w = self.inner_w - name_w - reset_w - 2 * gap
    local bar_h = Screen:scaleBySize(20)
    local pct = tonumber(q.pct) or 0
    if pct < 0 then pct = 0 elseif pct > 100 then pct = 100 end

    local name = TextWidget:new{ text = tostring(q.name or ""), face = self.face_qname, bold = true, fgcolor = BLACK, max_width = name_w }
    local name_g = HorizontalGroup:new{ align = "center", name }
    local left = name_w - name:getSize().w - Screen:scaleBySize(4)
    if q.sub and q.sub ~= "" and left > Screen:scaleBySize(24) then
        table.insert(name_g, HorizontalSpan:new{ width = Screen:scaleBySize(4) })
        table.insert(name_g, TextWidget:new{ text = q.sub, face = self.face_sub, fgcolor = GRAY, max_width = left })
    end

    local progress = ProgressWidget:new{
        width = bar_w, height = bar_h, percentage = pct / 100,
        bordercolor = BLACK, bgcolor = WHITE, fillcolor = BLACK,
        bordersize = Screen:scaleBySize(2), margin_h = 0, margin_v = 0, radius = 0,
    }
    local bar = OverlapGroup:new{
        dimen = Geom:new{ w = bar_w, h = bar_h },
        allow_mirroring = false,
        progress,
        LeftContainer:new{
            dimen = Geom:new{ w = bar_w, h = bar_h },
            HorizontalGroup:new{
                -- short fill: start the label after the black part so it stays readable
                HorizontalSpan:new{ width = (pct >= 22) and Screen:scaleBySize(6)
                    or (math.floor(bar_w * pct / 100) + Screen:scaleBySize(5)) },
                TextWidget:new{
                    text = string.format("%s %d%%", tostring(q.tag or ""), math.floor(pct + 0.5)),
                    face = self.face_sub, bold = true,
                    fgcolor = (pct >= 22) and WHITE or BLACK,
                },
            },
        },
    }
    local reset = (q.reset and q.reset ~= "—") and ("↻ " .. q.reset) or "—"
    return HorizontalGroup:new{
        align = "center",
        LeftContainer:new{ dimen = Geom:new{ w = name_w, h = row_h }, name_g },
        HorizontalSpan:new{ width = gap },
        bar,
        HorizontalSpan:new{ width = gap },
        RightContainer:new{
            dimen = Geom:new{ w = reset_w, h = row_h },
            TextWidget:new{ text = reset, face = self.face_chip, fgcolor = BLACK, max_width = reset_w },
        },
    }
end

function MagpieDash:secHeader(left, right)
    local l = TextWidget:new{ text = tostring(left), face = self.face_sec, bold = true, fgcolor = BLACK }
    local r = right and TextWidget:new{ text = tostring(right), face = self.face_sub, fgcolor = GRAY } or nil
    return self:lineLR(self.inner_w, l:getSize().h, l, r)
end

-- ranked project cost table; legend = swatches for the stacked chart
function MagpieDash:buildProjectCostTable(pm, legend)
    local vg = VerticalGroup:new{ align = "left" }
    if pm and pm.err then
        table.insert(vg, TextBoxWidget:new{
            text = string.format("项目费用拉不到：%s · %s\n%s", tostring(pm.err.title), tostring(pm.err.at or ""),
                tostring(pm.err.detail or "")),
            face = self.face_sub, width = self.inner_w, fgcolor = GRAY,
        })
        table.insert(vg, self:vspan(4))
    end
    if not pm or not pm.ok then
        if not (pm and pm.err) then
            table.insert(vg, self:text(self.model.refreshing and "正在拉项目费用…" or "还没有项目费用 · 点 ↻", self.face_meta, GRAY))
        end
        return vg
    end
    local w = self.inner_w
    local row_h = Screen:scaleBySize(30)
    local sw_w = legend and Screen:scaleBySize(26) or 0
    local idx_w = Screen:scaleBySize(22)
    local share_w = Screen:scaleBySize(118)
    local pct_w = Screen:scaleBySize(44)
    local money_w = Screen:scaleBySize(66)
    local gap = Screen:scaleBySize(8)
    local name_w = w - sw_w - idx_w - share_w - pct_w - money_w - 3 * gap

    local function swatch(i)
        local color = SWATCH[i]
        return FrameContainer:new{
            background = color or WHITE,
            bordersize = Screen:scaleBySize(1),
            color = BLACK,
            padding = 0,
            margin = 0,
            CenterContainer:new{ dimen = Geom:new{ w = Screen:scaleBySize(16), h = Screen:scaleBySize(12) }, VerticalSpan:new{ width = 0 } },
        }
    end
    local function line(i, idx, name, share, pct, money, dim)
        local fg = dim and GRAY or BLACK
        local left = HorizontalGroup:new{ align = "center" }
        if legend then
            table.insert(left, LeftContainer:new{ dimen = Geom:new{ w = sw_w, h = row_h }, swatch(i) })
        end
        table.insert(left, LeftContainer:new{ dimen = Geom:new{ w = idx_w, h = row_h },
            TextWidget:new{ text = idx, face = self.face_sub, bold = true, fgcolor = GRAY } })
        table.insert(left, LeftContainer:new{ dimen = Geom:new{ w = name_w, h = row_h },
            TextWidget:new{ text = name, face = self.face_qname, bold = not dim, fgcolor = fg, max_width = name_w } })
        table.insert(left, HorizontalSpan:new{ width = gap })
        if share then
            table.insert(left, CenterContainer:new{ dimen = Geom:new{ w = share_w, h = row_h },
                ProgressWidget:new{
                    width = share_w, height = Screen:scaleBySize(9), percentage = share,
                    bordercolor = BLACK, bgcolor = WHITE, fillcolor = BLACK,
                    bordersize = Screen:scaleBySize(1), margin_h = 0, margin_v = 0, radius = 0,
                } })
        else
            table.insert(left, HorizontalSpan:new{ width = share_w })
        end
        table.insert(left, HorizontalSpan:new{ width = gap })
        table.insert(left, RightContainer:new{ dimen = Geom:new{ w = pct_w, h = row_h },
            TextWidget:new{ text = pct, face = self.face_sub, fgcolor = GRAY } })
        table.insert(left, HorizontalSpan:new{ width = gap })
        table.insert(left, RightContainer:new{ dimen = Geom:new{ w = money_w, h = row_h },
            TextWidget:new{ text = money, face = self.face_money, bold = not dim, fgcolor = fg } })
        return left
    end
    local function sep()
        return LineWidget:new{ background = Blitbuffer.COLOR_LIGHT_GRAY, dimen = Geom:new{ w = w, h = Size.line.thin } }
    end
    for i, r in ipairs(pm.rows or {}) do
        if i > 1 then table.insert(vg, sep()) end
        table.insert(vg, line(i, tostring(r.idx), r.name, r.share, r.pct, r.money, false))
    end
    if pm.rest then
        if #(pm.rows or {}) > 0 then table.insert(vg, sep()) end
        table.insert(vg, line(99, "…", pm.rest.label, nil, pm.rest.pct, pm.rest.money, true))
    end
    return vg
end

function MagpieDash:buildUsageBody()
    local m = self.model
    local body = VerticalGroup:new{ align = "left" }
    local banner = self:buildStatusBanner()
    if banner then
        table.insert(body, banner)
        table.insert(body, self:vspan(8))
    end
    table.insert(body, self:buildUsageKpis(m.summary))
    table.insert(body, self:vspan(8))
    table.insert(body, self:hline())
    table.insert(body, self:vspan(6))

    table.insert(body, self:secHeader(_("配额"), _("主窗口 · ↻ 重置")))
    table.insert(body, self:vspan(4))
    local quotas = m.quotas or {}
    if m.quotas_note and #quotas > 0 then
        table.insert(body, TextBoxWidget:new{
            text = m.quotas_note, face = self.face_meta, width = self.inner_w, fgcolor = GRAY,
        })
    end
    if #quotas == 0 then
        table.insert(body, self:text(m.quotas_note or "（无配额数据）", self.face_meta, GRAY))
    else
        for _, q in ipairs(quotas) do
            table.insert(body, self:buildQuotaRow(q))
        end
    end
    table.insert(body, self:vspan(6))
    table.insert(body, self:hline())
    table.insert(body, self:vspan(6))

    local pm = m.projects or {}
    table.insert(body, self:secHeader(_("按项目 · 今日"), pm.total and ("合计 " .. pm.total) or nil))
    table.insert(body, self:vspan(2))
    table.insert(body, self:buildProjectCostTable(pm, false))
    table.insert(body, self:vspan(12))
    return body
end

function MagpieDash:buildPhaseChip(phase)
    phase = tostring(phase or "?")
    local inv = (phase == "stream")
    return FrameContainer:new{
        background = inv and BLACK or WHITE,
        bordersize = Screen:scaleBySize(1),
        bordercolor = BLACK,
        padding = Screen:scaleBySize(3),
        margin = 0,
        TextWidget:new{
            text = phase,
            face = self.face_chip,
            fgcolor = inv and WHITE or BLACK,
        },
    }
end

-- ---------------------------------------------------------------------------
-- 在飞 tab · by project (design inflight-project-v1: A list, C stale, D detail)

-- Tappable wrapper; only fires inside the visible scroller area.
local TapBox = InputContainer:extend{
    callback = nil,
    dash = nil,
}

function TapBox:init()
    local size = self[1]:getSize()
    self.dimen = Geom:new{ x = 0, y = 0, w = size.w, h = size.h }
    self.ges_events = {
        TapCard = {
            GestureRange:new{
                ges = "tap",
                range = function() return self.dimen end,
            },
        },
    }
end

function TapBox:onTapCard(_, ges)
    local crop = self.dash and self.dash.cropping_widget
    if crop and crop.dimen and ges and ges.pos and not ges.pos:intersectWith(crop.dimen) then
        return false
    end
    if self.callback then self.callback() end
    return true
end

-- style: "inv" (black) | "line" (outlined) | "dim" (gray outline)
function MagpieDash:buildTag(text, style, faded)
    local fg, bg, border = BLACK, WHITE, BLACK
    if style == "inv" then
        fg, bg = WHITE, (faded and GRAY or BLACK)
        border = bg
    elseif style == "dim" or faded then
        fg, border = GRAY, GRAY
    end
    return FrameContainer:new{
        background = bg,
        bordersize = Screen:scaleBySize(1),
        color = border,
        radius = Screen:scaleBySize(3),
        padding = 0,
        padding_left = Screen:scaleBySize(5),
        padding_right = Screen:scaleBySize(5),
        padding_top = Screen:scaleBySize(1),
        padding_bottom = Screen:scaleBySize(1),
        margin = 0,
        TextWidget:new{ text = tostring(text), face = self.face_chip, fgcolor = fg },
    }
end

-- left widget + right widget on one line of width w
function MagpieDash:lineLR(w, h, left, right)
    local kids = {
        dimen = Geom:new{ w = w, h = h },
        allow_mirroring = false,
        LeftContainer:new{ dimen = Geom:new{ w = w, h = h }, left },
    }
    if right then
        table.insert(kids, RightContainer:new{ dimen = Geom:new{ w = w, h = h }, right })
    end
    return OverlapGroup:new(kids)
end

function MagpieDash:buildSumCell(label, value, sub, inverted, thin, cell_w, cell_h)
    local fg = inverted and WHITE or BLACK
    local sub_fg = inverted and WHITE or GRAY
    local border = thin and Screen:scaleBySize(1) or Screen:scaleBySize(2)
    local inner_w = cell_w - 2 * border
    local inner_h = cell_h - 2 * border
    return FrameContainer:new{
        background = inverted and BLACK or WHITE,
        bordersize = border,
        color = BLACK,
        padding = 0,
        margin = 0,
        CenterContainer:new{
            dimen = Geom:new{ w = inner_w, h = inner_h },
            VerticalGroup:new{
                align = "center",
                TextWidget:new{ text = tostring(label), face = self.face_chip, fgcolor = fg, max_width = inner_w - 4 },
                TextWidget:new{ text = tostring(value), face = self.face_sum, fgcolor = fg, max_width = inner_w - 4 },
                TextWidget:new{ text = tostring(sub or ""), face = self.face_sub, fgcolor = sub_fg, max_width = inner_w - 4 },
            },
        },
    }
end

function MagpieDash:buildOfficeSummary(m)
    local o, gw, err = m.office, m.gw or {}, m.office_err
    local gap = Screen:scaleBySize(6)
    local cell_w = math.floor((self.inner_w - 2 * gap) / 3)
    local last_w = self.inner_w - 2 * gap - 2 * cell_w
    local cell_h = Screen:scaleBySize(80)

    local need_v, need_s, work_v, work_s = "—", "", "—", ""
    if o and not err then
        need_v, need_s = o.need, (o.need > 0) and o.need_sub or "无"
        work_v, work_s = o.work, string.format("%d 个项目", o.work_projects)
    elseif o then
        need_s, work_s = "上次 " .. o.need, "上次 " .. o.work
    end
    local gw_v = gw.known and gw.inflight or "—"
    local gw_s = gw.failed and "网关失败"
        or string.format("工具 %d · 等待 %d", gw.tools or 0, gw.waiting or 0)
    local hot = (o and not err and o.need > 0)
    return HorizontalGroup:new{
        align = "center",
        self:buildSumCell("需要你", need_v, need_s, hot, false, cell_w, cell_h),
        HorizontalSpan:new{ width = gap },
        self:buildSumCell("工作中", work_v, work_s, false, false, cell_w, cell_h),
        HorizontalSpan:new{ width = gap },
        self:buildSumCell("网关在飞", gw_v, gw_s, false, true, last_w, cell_h),
    }
end

function MagpieDash:buildSessionLine(r, w, faded)
    local fg = faded and GRAY or BLACK
    local style = (r.group == "need" or r.sub) and "inv" or (r.group == "done" and "dim" or "line")
    local label = r.sub and (r.label .. "·" .. r.sub) or r.label
    local tag = self:buildTag(label, style, faded)
    local age = TextWidget:new{ text = tostring(r.age or ""), face = self.face_chip, fgcolor = fg }
    local gap = Screen:scaleBySize(6)
    local text_w = w - tag:getSize().w - age:getSize().w - 3 * gap
    local who = r.agent or "?"
    if r.meta and r.meta ~= "" then who = who .. " · " .. r.meta end
    local left = HorizontalGroup:new{
        align = "center",
        tag,
        HorizontalSpan:new{ width = gap },
        TextWidget:new{
            text = who,
            face = self.face_meta,
            fgcolor = (r.group == "done") and GRAY or fg,
            max_width = text_w,
        },
    }
    local h = math.max(tag:getSize().h, age:getSize().h)
    return self:lineLR(w, h, left, age)
end

function MagpieDash:buildProjectCard(p, faded)
    local that = self
    local need = (p.need or 0) > 0
    local border = need and Screen:scaleBySize(3) or Screen:scaleBySize(2)
    local pad = Screen:scaleBySize(7)
    local inner_w = self.inner_w - 2 * border
    local line_w = inner_w - 2 * pad
    local head_bg = need and (faded and GRAY or BLACK) or WHITE
    local head_fg = need and WHITE or (faded and GRAY or BLACK)

    local chips = HorizontalGroup:new{ align = "center" }
    local function chip(text, style)
        if #chips > 0 then table.insert(chips, HorizontalSpan:new{ width = Screen:scaleBySize(4) }) end
        table.insert(chips, self:buildTag(text, style, faded))
    end
    if need then chip("需要你 " .. p.need, "line") end
    if (p.work or 0) > 0 then chip("工作 " .. p.work, need and "line" or "inv") end
    if (p.done or 0) > 0 then chip("完成 " .. p.done, "line") end
    local chips_w = chips:getSize().w
    local name = TextWidget:new{
        text = tostring(p.name),
        face = self.face_name,
        bold = true,
        fgcolor = head_fg,
        max_width = math.max(Screen:scaleBySize(80), line_w - chips_w - Screen:scaleBySize(8)),
    }
    local head_h = math.max(name:getSize().h, chips:getSize().h)
    local head = FrameContainer:new{
        background = head_bg,
        bordersize = 0,
        padding = 0,
        padding_left = pad,
        padding_right = pad,
        padding_top = Screen:scaleBySize(3),
        padding_bottom = Screen:scaleBySize(3),
        margin = 0,
        self:lineLR(line_w, head_h, name, chips),
    }

    local vg = VerticalGroup:new{ align = "left", head }
    if not need then
        table.insert(vg, LineWidget:new{
            background = Blitbuffer.COLOR_LIGHT_GRAY,
            dimen = Geom:new{ w = inner_w, h = Size.line.thin },
        })
    end
    local rows = VerticalGroup:new{ align = "left" }
    for i, r in ipairs(p.rows or {}) do
        if i > 1 then table.insert(rows, VerticalSpan:new{ width = Screen:scaleBySize(4) }) end
        table.insert(rows, self:buildSessionLine(r, line_w, faded))
        if r.group == "need" then
            local why = r.title or r.step
            if why and r.step and r.title then why = r.title .. " · " .. r.step end
            if why then
                table.insert(rows, VerticalSpan:new{ width = Screen:scaleBySize(2) })
                table.insert(rows, TextWidget:new{
                    text = why, face = self.face_sub, fgcolor = faded and GRAY or BLACK, max_width = line_w,
                })
            end
        end
    end
    if (p.more or 0) > 0 then
        table.insert(rows, VerticalSpan:new{ width = Screen:scaleBySize(2) })
        table.insert(rows, TextWidget:new{
            text = string.format("+%d 个会话 · 点开看全部", p.more), face = self.face_sub, fgcolor = GRAY,
        })
    end
    table.insert(vg, FrameContainer:new{
        bordersize = 0,
        padding = 0,
        padding_left = pad,
        padding_right = pad,
        padding_top = Screen:scaleBySize(5),
        padding_bottom = Screen:scaleBySize(5),
        margin = 0,
        rows,
    })

    local card = FrameContainer:new{
        background = WHITE,
        bordersize = border,
        color = faded and GRAY or BLACK,
        padding = 0,
        margin = 0,
        vg,
    }
    return TapBox:new{
        dash = self,
        callback = function()
            if that.on_project then that.on_project(p.name) end
        end,
        card,
    }
end

function MagpieDash:buildOfficeError(m)
    local err = m.office_err
    local w = self.inner_w - 2 * (Screen:scaleBySize(3) + Screen:scaleBySize(8))
    local vg = VerticalGroup:new{
        align = "left",
        TextWidget:new{ text = tostring(err.title or "项目数据拉不到"), face = self.face_sec, bold = true, fgcolor = BLACK, max_width = w },
        VerticalSpan:new{ width = Screen:scaleBySize(3) },
        TextBoxWidget:new{ text = tostring(err.detail or ""), face = self.face_meta, width = w, fgcolor = BLACK },
    }
    local tail
    if m.stale and m.office_hm then
        tail = string.format("%s 失败 · 上次成功 %s · 下面是那时的列表", tostring(err.at or "—"), m.office_hm)
    else
        tail = string.format("%s 失败 · 网关数字照常更新 · 点 ↻ 重试", tostring(err.at or "—"))
    end
    table.insert(vg, VerticalSpan:new{ width = Screen:scaleBySize(3) })
    table.insert(vg, TextBoxWidget:new{ text = tail, face = self.face_sub, width = w, fgcolor = GRAY })
    return FrameContainer:new{
        background = WHITE,
        bordersize = Screen:scaleBySize(3),
        color = BLACK,
        padding = Screen:scaleBySize(8),
        margin = 0,
        vg,
    }
end

function MagpieDash:buildIdleBox(idle, faded)
    local parts = {}
    for _, p in ipairs(idle) do
        table.insert(parts, string.format("%s %s", p.name, p.last_age))
    end
    local pad = Screen:scaleBySize(7)
    return FrameContainer:new{
        background = WHITE,
        bordersize = Screen:scaleBySize(1),
        color = GRAY,
        padding = pad,
        margin = 0,
        TextBoxWidget:new{
            text = string.format("闲置 %d · %s", #idle, table.concat(parts, " · ")),
            face = self.face_meta,
            width = self.inner_w - 2 * (pad + Screen:scaleBySize(1)),
            fgcolor = faded and GRAY or BLACK,
        },
    }
end

function MagpieDash:buildConcurrencyBody()
    local m = self.model
    if m.detail then
        return self:buildProjectDetail(m.detail)
    end
    local body = VerticalGroup:new{ align = "left" }
    if m.refreshing then
        local banner = self:buildStatusBanner()
        if banner then
            table.insert(body, banner)
            table.insert(body, self:vspan(6))
        end
    end
    table.insert(body, self:buildOfficeSummary(m))
    table.insert(body, self:vspan(8))

    if m.office_err then
        table.insert(body, self:buildOfficeError(m))
        table.insert(body, self:vspan(8))
    end

    local o = m.office
    if not o then
        if not m.office_err then
            table.insert(body, self:text(m.refreshing and "正在拉项目数据…" or "还没有项目数据 · 点 ↻", self.face_meta, GRAY))
        end
        table.insert(body, self:vspan(12))
        return body
    end
    local faded = m.stale

    table.insert(body, self:hline())
    table.insert(body, self:vspan(5))
    local sec_left = TextWidget:new{ text = string.format("项目 %d", o.total_projects), face = self.face_sec, bold = true, fgcolor = faded and GRAY or BLACK }
    local sec_right = TextWidget:new{
        text = faded and string.format("%s 的快照", tostring(m.office_hm or "—"))
            or string.format("活跃 %d · 闲置 %d", #o.active, #o.idle),
        face = self.face_meta, fgcolor = GRAY,
    }
    table.insert(body, self:lineLR(self.inner_w, sec_left:getSize().h, sec_left, sec_right))
    table.insert(body, self:vspan(5))

    if #o.active == 0 and not faded then
        table.insert(body, FrameContainer:new{
            background = WHITE,
            bordersize = Screen:scaleBySize(2),
            color = BLACK,
            padding = Screen:scaleBySize(12),
            margin = 0,
            CenterContainer:new{
                dimen = Geom:new{ w = self.inner_w - Screen:scaleBySize(28), h = Screen:scaleBySize(56) },
                VerticalGroup:new{
                    align = "center",
                    TextWidget:new{ text = "当前没有在干活的 agent", face = self.face_sec, bold = true, fgcolor = BLACK },
                    TextWidget:new{ text = "自动刷新仍在跑 · 有活会亮起", face = self.face_meta, fgcolor = GRAY },
                },
            },
        })
        table.insert(body, self:vspan(7))
    end
    for _, p in ipairs(o.active) do
        table.insert(body, self:buildProjectCard(p, faded))
        table.insert(body, self:vspan(7))
    end
    if #o.idle > 0 then
        table.insert(body, self:buildIdleBox(o.idle, faded))
    end
    table.insert(body, self:vspan(12))
    return body
end

function MagpieDash:buildCtxBar(pct)
    local bar = ProgressWidget:new{
        width = Screen:scaleBySize(44),
        height = Screen:scaleBySize(9),
        percentage = (tonumber(pct) or 0) / 100,
        bordercolor = BLACK,
        bgcolor = WHITE,
        fillcolor = BLACK,
        bordersize = Screen:scaleBySize(1),
        margin_h = 0,
        margin_v = 0,
        radius = 0,
    }
    return HorizontalGroup:new{
        align = "center",
        TextWidget:new{ text = "ctx ", face = self.face_sub, fgcolor = BLACK },
        bar,
        TextWidget:new{ text = string.format(" %d%%", pct), face = self.face_sub, fgcolor = BLACK },
    }
end

function MagpieDash:buildProjectDetail(p)
    local body = VerticalGroup:new{ align = "left" }
    local m = self.model
    if m.refreshing then
        local banner = self:buildStatusBanner()
        if banner then
            table.insert(body, banner)
            table.insert(body, self:vspan(6))
        end
    elseif m.office_err then
        table.insert(body, self:buildOfficeError(m))
        table.insert(body, self:vspan(8))
    end

    -- HorizontalGroup caches offsets on getSize(): track width by hand.
    local head = HorizontalGroup:new{ align = "center" }
    local head_w = 0
    local function add(w)
        if #head > 0 then
            table.insert(head, HorizontalSpan:new{ width = Screen:scaleBySize(5) })
            head_w = head_w + Screen:scaleBySize(5)
        end
        table.insert(head, w)
        head_w = head_w + w:getSize().w
    end
    if (p.need or 0) > 0 then add(self:buildTag("需要你 " .. p.need, "inv")) end
    if (p.work or 0) > 0 then add(self:buildTag("工作 " .. p.work, "inv")) end
    if (p.done or 0) > 0 then add(self:buildTag("完成 " .. p.done, "line")) end
    local agents = {}
    for _, a in ipairs(p.agents or {}) do
        table.insert(agents, string.format("%s %d", a, (p.agent_counts or {})[a] or 0))
    end
    local total = (p.need or 0) + (p.work or 0) + (p.done or 0)
    add(TextWidget:new{
        text = string.format("· %d 个会话 · %s", total, table.concat(agents, " · ")),
        face = self.face_meta, fgcolor = BLACK,
        max_width = math.max(Screen:scaleBySize(100), self.inner_w - head_w - Screen:scaleBySize(8)),
    })
    table.insert(body, head)
    table.insert(body, self:vspan(6))
    table.insert(body, self:hline())

    local w = self.inner_w
    for _, r in ipairs(p.sessions or {}) do
        local done = (r.group == "done")
        local fg = done and GRAY or BLACK
        local style = (r.group == "need" or r.sub) and "inv" or (done and "dim" or "line")
        local tag = self:buildTag(r.sub and (r.label .. "·" .. r.sub) or r.label, style)
        local age = TextWidget:new{ text = tostring(r.age or ""), face = self.face_chip, fgcolor = fg }
        local gap = Screen:scaleBySize(6)
        local title = r.title or r.step or "（无标题）"
        if r.subagent then title = "↳ " .. title end
        local l1 = HorizontalGroup:new{
            align = "center",
            tag,
            HorizontalSpan:new{ width = gap },
            TextWidget:new{
                text = title, face = self.face_row, bold = not done, fgcolor = fg,
                max_width = w - tag:getSize().w - age:getSize().w - 3 * gap,
            },
        }
        local right2
        if r.ctx_pct then
            right2 = self:buildCtxBar(r.ctx_pct)
        elseif (r.turns or 0) > 0 then
            right2 = TextWidget:new{ text = string.format("%d 轮", r.turns), face = self.face_sub, fgcolor = GRAY }
        end
        local who = r.agent or "?"
        if r.meta and r.meta ~= "" then who = who .. " · " .. r.meta end
        local l2_left = TextWidget:new{
            text = who, face = self.face_meta, fgcolor = GRAY,
            max_width = w - (right2 and right2:getSize().w or 0) - gap,
        }
        table.insert(body, self:vspan(6))
        table.insert(body, self:lineLR(w, math.max(tag:getSize().h, age:getSize().h), l1, age))
        table.insert(body, self:vspan(3))
        table.insert(body, self:lineLR(w, math.max(l2_left:getSize().h, right2 and right2:getSize().h or 0), l2_left, right2))
        table.insert(body, self:vspan(6))
        table.insert(body, LineWidget:new{
            background = Blitbuffer.COLOR_LIGHT_GRAY,
            dimen = Geom:new{ w = w, h = Size.line.thin },
        })
    end
    if (p.hidden or 0) > 0 then
        table.insert(body, self:vspan(6))
        table.insert(body, self:text(string.format("另有 %d 个更早的会话未列出", p.hidden), self.face_sub, GRAY))
    end
    table.insert(body, self:vspan(14))
    return body
end

function MagpieDash:buildChip(label, selected, callback)
    return Button:new{
        text = tostring(label),
        bordersize = Screen:scaleBySize(2),
        padding_h = Screen:scaleBySize(8),
        padding_v = Screen:scaleBySize(6),
        radius = Screen:scaleBySize(3),
        text_font_face = "smallinfofontbold",
        text_font_size = 14,
        text_font_bold = true,
        preselect = not not selected,
        callback = function()
            if callback then callback() end
        end,
        show_parent = self,
    }
end

function MagpieDash:buildBarChart(series, metric, stacked)
    series = series or {}
    local chart_h = Screen:scaleBySize(230)
    local pad = Screen:scaleBySize(8)
    local border = Screen:scaleBySize(2)
    local inner_w = self.inner_w - (border + pad) * 2
    local inner_h = chart_h - (border + pad) * 2

    if #series == 0 then
        return FrameContainer:new{
            background = WHITE,
            bordersize = border,
            color = BLACK,
            padding = pad,
            margin = 0,
            CenterContainer:new{
                dimen = Geom:new{ w = inner_w, h = inner_h },
                TextWidget:new{
                    text = _("暂无序列数据"),
                    face = self.face_meta,
                    fgcolor = GRAY,
                },
            },
        }
    end

    -- Layout matches trend-nav-v3: plot area flex-end (shared baseline),
    -- then a separate x-axis row for day labels.
    local label_h = Screen:scaleBySize(18)
    local axis_gap = Screen:scaleBySize(4)
    local axis_line = Size.line.thin
    local plot_h = inner_h - label_h - axis_gap - axis_line
    if plot_h < Screen:scaleBySize(80) then plot_h = Screen:scaleBySize(80) end

    local n = #series
    local dense = n > 12 -- 30 日 / 今日(24h): thin bars, sparse labels
    local gap = dense and Screen:scaleBySize(4) or Screen:scaleBySize(6)
    local col_w = math.floor((inner_w - gap * math.max(0, n - 1)) / n)
    if col_w < Screen:scaleBySize(8) then col_w = Screen:scaleBySize(8) end

    local max_v = 0.0001
    for _, s in ipairs(series) do
        if type(s) == "table" then
            local v = (metric == "calls") and (tonumber(s.calls) or 0) or (tonumber(s.cost) or 0)
            if v > max_v then max_v = v end
        end
    end

    -- Leave room above the tallest bar for the value label.
    local val_slot = Screen:scaleBySize(14)
    local val_gap = Screen:scaleBySize(3)
    local bar_max = plot_h - val_slot - val_gap
    if bar_max < Screen:scaleBySize(24) then bar_max = Screen:scaleBySize(24) end
    local zero_h = Screen:scaleBySize(3)

    local plot_row = HorizontalGroup:new{ align = "bottom" }
    local label_row = HorizontalGroup:new{ align = "center" }
    local max_i, last_i = 1, n
    for i, s in ipairs(series) do
        local v = (metric == "calls") and (tonumber(s.calls) or 0) or (tonumber(s.cost) or 0)
        if v >= max_v then max_i = i end
    end
    if dense then
        -- 今日 is hourly: hours still to come are 0, label the latest one with data
        for i = n, 1, -1 do
            local s = series[i]
            local v = (metric == "calls") and (tonumber(s.calls) or 0) or (tonumber(s.cost) or 0)
            if v > 0 then last_i = i break end
        end
    end

    for i, s in ipairs(series) do
        if type(s) ~= "table" then s = {} end
        local v = (metric == "calls") and (tonumber(s.calls) or 0) or (tonumber(s.cost) or 0)
        local h
        if v <= 0 then
            h = zero_h
        else
            h = math.floor(bar_max * (v / max_v) + 0.5)
            if h < zero_h then h = zero_h end
            if h > bar_max then h = bar_max end
        end
        local bar_w = dense and col_w or math.min(col_w - Screen:scaleBySize(4), Screen:scaleBySize(48))
        if bar_w < Screen:scaleBySize(6) then bar_w = Screen:scaleBySize(6) end

        local val_txt
        if metric == "calls" then
            if v <= 0 then val_txt = "—"
            elseif v >= 1000 then val_txt = string.format("%.1fK", v / 1000)
            else val_txt = tostring(math.floor(v + 0.5)) end
        else
            if v <= 0 then val_txt = "—"
            elseif v < 0.5 then val_txt = "<$1"
            else val_txt = string.format("$%d", math.floor(v + 0.5)) end
        end
        if dense and not (i == max_i or i == last_i) then val_txt = "" end

        -- FrameContainer needs a child; fixed dimen child pins bar size.
        local bar
        if stacked and v > 0 then
            -- outlined bar; project segments bottom-up (black/dark/light), rest white
            local bw = Screen:scaleBySize(1)
            local in_w, in_h = math.max(1, bar_w - 2 * bw), math.max(1, h - bw)
            local segs = VerticalGroup:new{ align = "center" }
            local used = 0
            local list = {}
            for k, pv in ipairs(s.parts or {}) do
                local sh = math.floor(in_h * (tonumber(pv) or 0) / v + 0.5)
                if sh > in_h - used then sh = in_h - used end
                if sh > 0 then
                    table.insert(list, 1, { color = SWATCH[k] or BLACK, h = sh })
                    used = used + sh
                end
            end
            if in_h - used > 0 then
                table.insert(segs, LineWidget:new{ background = WHITE, dimen = Geom:new{ w = in_w, h = in_h - used } })
            end
            for _, seg in ipairs(list) do
                table.insert(segs, LineWidget:new{ background = seg.color, dimen = Geom:new{ w = in_w, h = seg.h } })
            end
            bar = FrameContainer:new{
                background = WHITE, bordersize = bw, color = BLACK, padding = 0, margin = 0,
                segs,
            }
        else
            bar = FrameContainer:new{
                background = (v > 0) and BLACK or Blitbuffer.COLOR_LIGHT_GRAY,
                bordersize = 0,
                padding = 0,
                margin = 0,
                CenterContainer:new{
                    dimen = Geom:new{ w = bar_w, h = h },
                    VerticalSpan:new{ width = 0 },
                },
            }
        end

        -- BottomContainer pins value+bar to the shared plot floor (like flex-end).
        -- dense: labels may spill into the (label-less) neighbours; the last
        -- one is right-aligned so it stays inside the chart frame
        local Anchor = (dense and i >= n - 1) and RightContainer or CenterContainer
        local stack = VerticalGroup:new{
            align = "center",
            Anchor:new{
                dimen = Geom:new{ w = col_w, h = val_slot },
                TextWidget:new{
                    text = val_txt,
                    face = self.face_sub,
                    fgcolor = BLACK,
                    max_width = dense and Screen:scaleBySize(60) or col_w,
                },
            },
            VerticalSpan:new{ width = val_gap },
            bar,
        }
        table.insert(plot_row, BottomContainer:new{
            dimen = Geom:new{ w = col_w, h = plot_h },
            stack,
        })

        local xl = tostring(s.label or "")
        if dense and not ((i - 1) % 5 == 0 or i == n) then xl = "" end
        table.insert(label_row, Anchor:new{
            dimen = Geom:new{ w = col_w, h = label_h },
            TextWidget:new{
                text = xl,
                face = self.face_chip,
                fgcolor = BLACK,
                max_width = dense and Screen:scaleBySize(40) or col_w,
            },
        })

        if i < n then
            table.insert(plot_row, HorizontalSpan:new{ width = gap })
            table.insert(label_row, HorizontalSpan:new{ width = gap })
        end
    end

    local body = VerticalGroup:new{
        align = "left",
        plot_row,
        VerticalSpan:new{ width = axis_gap },
        LineWidget:new{
            background = Blitbuffer.COLOR_GRAY,
            dimen = Geom:new{ w = inner_w, h = axis_line },
        },
        label_row,
    }

    return FrameContainer:new{
        background = WHITE,
        bordersize = border,
        color = BLACK,
        padding = pad,
        margin = 0,
        -- Top-align plot+axis; never vertically center the whole chart body.
        TopContainer:new{
            dimen = Geom:new{ w = inner_w, h = inner_h },
            body,
        },
    }
end

function MagpieDash:buildTrendBody()
    local m = self.model
    local body = VerticalGroup:new{ align = "left" }
    local banner = self:buildStatusBanner()
    if banner then
        table.insert(body, banner)
        table.insert(body, self:vspan(8))
    end

    local that = self
    local period = m.period or "7d"
    local metric = m.metric or "cost"

    -- period chips
    local periods = {
        { "today", _("今日") },
        { "7d", _("7日") },
        { "30d", _("30日") },
    }
    local chip_row = HorizontalGroup:new{ align = "center" }
    local chip_w = math.floor((self.inner_w - Screen:scaleBySize(16)) / 3)
    for i, p in ipairs(periods) do
        local sel = (period == p[1])
        local btn = Button:new{
            text = p[2],
            width = chip_w,
            bordersize = Screen:scaleBySize(2),
            padding_v = Screen:scaleBySize(6),
            radius = Screen:scaleBySize(3),
            text_font_face = "smallinfofontbold",
            text_font_size = 14,
            text_font_bold = true,
            preselect = sel,
            callback = function()
                if that.on_period then that.on_period(p[1]) end
            end,
            show_parent = self,
        }
        table.insert(chip_row, btn)
        if i < 3 then
            table.insert(chip_row, HorizontalSpan:new{ width = Screen:scaleBySize(8) })
        end
    end
    table.insert(body, chip_row)
    table.insert(body, self:vspan(8))

    -- metric toggle + totals
    local cost_sel = (metric == "cost")
    local metric_row = HorizontalGroup:new{ align = "center" }
    table.insert(metric_row, Button:new{
        text = _("费用"),
        bordersize = Screen:scaleBySize(2),
        padding_h = Screen:scaleBySize(10),
        padding_v = Screen:scaleBySize(5),
        radius = Screen:scaleBySize(3),
        text_font_face = "smallinfofontbold",
        text_font_size = 13,
        text_font_bold = true,
        preselect = cost_sel,
        callback = function()
            if that.on_metric then that.on_metric("cost") end
        end,
        show_parent = self,
    })
    table.insert(metric_row, HorizontalSpan:new{ width = Screen:scaleBySize(8) })
    table.insert(metric_row, Button:new{
        text = _("请求"),
        bordersize = Screen:scaleBySize(2),
        padding_h = Screen:scaleBySize(10),
        padding_v = Screen:scaleBySize(5),
        radius = Screen:scaleBySize(3),
        text_font_face = "smallinfofontbold",
        text_font_size = 13,
        text_font_bold = true,
        preselect = (not cost_sel),
        callback = function()
            if that.on_metric then that.on_metric("calls") end
        end,
        show_parent = self,
    })
    table.insert(metric_row, HorizontalSpan:new{ width = Screen:scaleBySize(10) })
    table.insert(metric_row, TextWidget:new{
        text = string.format("合计 %s · %s 次", tostring(m.total_cost or "—"), tostring(m.total_calls or "—")),
        face = self.face_meta,
        fgcolor = BLACK,
        max_width = Screen:scaleBySize(260),
    })
    table.insert(body, metric_row)
    table.insert(body, self:vspan(8))

    table.insert(body, self:buildBarChart(m.series, metric, m.stacked))
    table.insert(body, self:vspan(10))

    local pm = m.projects or {}
    table.insert(body, self:secHeader(
        string.format("Top 项目 · %s", tostring(m.period_label or "")),
        m.stacked and _("色块 = 柱内同色段") or _("按费用")))
    table.insert(body, self:vspan(2))
    table.insert(body, self:buildProjectCostTable(pm, m.stacked))
    table.insert(body, self:vspan(16))
    return body
end

function MagpieDash:buildTabBar()
    local that = self
    local tabs = {
        { "usage", _("用量") },
        { "concurrency", _("在飞") },
        { "trend", _("趋势") },
    }
    local hg = HorizontalGroup:new{ align = "center" }
    local tab_w = math.floor(self.width / 3)
    local tab_h = Screen:scaleBySize(52)
    for i, t in ipairs(tabs) do
        local sel = (self.page == t[1])
        local btn = Button:new{
            text = t[2],
            width = tab_w,
            height = tab_h,
            bordersize = 0,
            text_font_face = "infofont",
            text_font_size = 16,
            text_font_bold = true,
            padding = 0,
            radius = 0,
            preselect = sel,
            callback = function()
                if that.on_tab then that.on_tab(t[1]) end
            end,
            show_parent = self,
        }
        table.insert(hg, btn)
        if i < 3 then
            -- visual divider via thin black frame between — Button width already tiles
        end
    end
    return FrameContainer:new{
        width = self.width,
        height = tab_h,
        background = WHITE,
        bordersize = 0,
        padding = 0,
        margin = 0,
        VerticalGroup:new{
            align = "left",
            LineWidget:new{
                background = BLACK,
                dimen = Geom:new{ w = self.width, h = Size.line.medium },
            },
            -- draw vertical dividers with overlapping line? keep simple 3 buttons
            OverlapGroup:new{
                dimen = Geom:new{ w = self.width, h = tab_h - Screen:scaleBySize(2) },
                hg,
                -- mid dividers
                LeftContainer:new{
                    dimen = Geom:new{ w = self.width, h = tab_h - Screen:scaleBySize(2) },
                    HorizontalGroup:new{
                        HorizontalSpan:new{ width = tab_w },
                        LineWidget:new{
                            background = BLACK,
                            dimen = Geom:new{ w = Size.line.medium, h = tab_h - Screen:scaleBySize(2) },
                        },
                        HorizontalSpan:new{ width = tab_w - Size.line.medium },
                        LineWidget:new{
                            background = BLACK,
                            dimen = Geom:new{ w = Size.line.medium, h = tab_h - Screen:scaleBySize(2) },
                        },
                    },
                },
            },
        },
    }
end

function MagpieDash:build()
    local top = self:buildTopBar()
    local footer = self:buildTabBar()
    local title_h = top:getSize().h
    local footer_h = footer:getSize().h
    local body_h = self.height - title_h - footer_h - Screen:scaleBySize(2)

    local function build_content()
        if self.page == "concurrency" then
            return self:buildConcurrencyBody()
        elseif self.page == "trend" then
            return self:buildTrendBody()
        end
        return self:buildUsageBody()
    end
    local content = build_content()
    local wrap_w = self.width
    if content:getSize().h > body_h then
        -- A vertical scrollbar takes 3×its width; build narrower so no
        -- horizontal scrollbar appears (which also clipped the right edge).
        local reserve = ScrollableContainer:getScrollbarWidth()
        wrap_w = self.width - reserve
        self.inner_w = wrap_w - self.pad
        content = build_content()
    end

    local scroller = ScrollableContainer:new{
        dimen = Geom:new{ w = self.width, h = body_h },
        show_parent = self,
        CenterContainer:new{
            dimen = Geom:new{ w = wrap_w, h = content:getSize().h },
            LeftContainer:new{
                dimen = Geom:new{ w = wrap_w, h = content:getSize().h },
                HorizontalGroup:new{
                    HorizontalSpan:new{ width = self.pad },
                    content,
                },
            },
        },
    }
    self.cropping_widget = scroller

    self[1] = FrameContainer:new{
        background = WHITE,
        bordersize = 0,
        padding = 0,
        width = self.width,
        height = self.height,
        VerticalGroup:new{
            align = "left",
            top,
            scroller,
            footer,
        },
    }
end

return MagpieDash
