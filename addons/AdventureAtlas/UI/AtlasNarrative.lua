-- AdventureAtlas / UI / AtlasNarrative.lua
--
-- The narrative view of the "Your adventure" atlas tab (UI/Atlas.lua builds and refreshes it through
-- ns.AtlasNarrative.build / .refresh while the character is in narrative mode). Everything comes from
-- ns.Narrative (Core/Narrative.lua; the shapes of res / gs / candidate / Where() are in its header).
-- Top to bottom (y from the top of the view, 532 x 410):
--      0   "Where now" + the quest log counts
--    -18   the main suggestion + Lead / Stop (Narrative:Lead(main, follow = true))
--    -40   up to 4 detours of the other aspects (a click leads to it, without follow)
--   -118   one row per aspect (5): label button (selects the list), progress bar, done/total and missed
--   -220   "hide done", "only new in Forever" (ns.db.narrative) + the captions of the two check box columns
--   -248   the goals of the selected aspect, a virtual list: ROWS pooled rows, zone header and goal rows; a
--          goal row leads to the goal's best candidate on click, explains the goal in its tooltip (profession
--          goals: skill, next rank, leveling brackets, camp blueprints; dungeons: blueprints for the character's
--          professions) and has the "did it myself" / "not interested" check boxes (Narrative:Mark)
-- Without the knowledge base addon the view only says how to install it.

-- luacheck: ignore 212/self

local _, ns = ...

local UI = ns.UI
local L = UI.L

local type, ipairs, pairs, tostring, format, concat = type, ipairs, pairs, tostring, string.format, table.concat
local floor, max, min = math.floor, math.max, math.min

local AN = {}
ns.AtlasNarrative = AN

local PAGE_WIDTH = 532   -- the atlas page (UI/Atlas.lua: WIDTH - 2 * PAD)
local MAIN_WIDTH, LEAD_WIDTH = 436, 90
local ALONG_ROWS, ALONG_HEIGHT = 4, 18
local LABEL_WIDTH, BAR_WIDTH = 120, 260
local ROWS, ROW_HEIGHT = 8, 20
local SLIDER_WIDTH = 16
local LIST_WIDTH = PAGE_WIDTH - SLIDER_WIDTH - 6
local MARK_W, LEVEL_W, COUNT_W, TAG_W, COL_W = 14, 54, 110, 16, 50
local NEXT_SLOTS = 5     -- tooltip: open slots listed at most
local PREP_LINES = 10    -- tooltip: lead-in quests of a dungeon listed at most
local BRACKET_ITEMS = 3  -- tooltip: items named per leveling bracket at most
local ASPECTS_TOP, FILTERS_TOP, LIST_TOP = -118, -220, -248

local EMPTY = {}
local GOLD, GREEN, GREY, RED, WHITE = { 1, 0.82, 0 }, { 0.45, 0.9, 0.45 }, { 0.6, 0.6, 0.6 }, { 1, 0.35, 0.3 },
    { 1, 1, 1 }

-- Row mark and color of a goal state (gs.state of Core/Narrative.lua); skipped goals are dimmed, unmarked.
local STATE_LOOK = {
    done = { "+", GREEN }, active = { ">", GOLD }, open = { "o", WHITE }, later = { "-", GREY },
    missed = { "x", RED }, skip = { "", { 0.45, 0.45, 0.45 } },
}

-- The view's saved options (ns.db.narrative = { aspect, hideDone, onlyNew }); an unknown aspect falls back to
-- the first one.
local function options()
    local db = ns.db
    if type(db.narrative) ~= "table" then db.narrative = {} end
    local o = db.narrative
    local known = false
    for _, a in ipairs(ns.Narrative.ASPECTS) do
        if o.aspect == a then known = true end
    end
    if not known then o.aspect = ns.Narrative.ASPECTS[1] end
    return o
end

-- Localized label of an aspect (literal keys: the locale check of the specs finds them).
local function aspectLabel(a)
    if a == "dungeon" then return L.UI_NAR_ASPECT_DUNGEON end
    if a == "class" then return L.UI_NAR_ASPECT_CLASS end
    if a == "novelty" then return L.UI_NAR_ASPECT_NOVELTY end
    if a == "profession" then return L.UI_NAR_ASPECT_PROFESSION end
    return L.UI_NAR_ASPECT_STORY
end

-- Level band "lo-hi", or one level when both are the same.
local function levelsText(lo, hi)
    return lo == hi and tostring(lo) or format(L.UI_NAR_LEVELS_FMT, lo, hi)
end

-- "done/total" of a { done, open } sum (missed slots are not in the total).
local function countText(s)
    return format(L.UI_NAR_BAR_FMT, s.done, s.done + s.open)
end

-- Can the arrow lead to the candidate (a known place on this continent)? Same rule as Narrative:Lead.
local function leadable(c)
    return c ~= nil and c.map ~= nil and c.bucket < 4
end

-- Lead the arrow to a candidate without follow, or stop when it already leads there.
local function toggleLead(page, cand)
    local N = ns.Narrative
    if not cand then return end
    if N:IsLeading(cand) then N:Stop() else N:Lead(cand, false) end
    AN.refresh(page)
end

-- A font string of the view: left-justified, one line.
local function text(parent, font, width)
    local fs = parent:CreateFontString(nil, "OVERLAY", font)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    if width then fs:SetWidth(width) end
    return fs
end

-- Tooltip with the region's whole text (cut off in the view).
local function textTooltip(region)
    UI.ShowTooltip(region, region.text:GetText())
end

---------------------------------------------------------------------------
-- where now
---------------------------------------------------------------------------

-- The "where now" block: header, the main suggestion with its Lead / Stop button, the detour rows.
local function buildWhere(page, body)
    local header = text(body, "GameFontNormal", MAIN_WIDTH)
    header:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
    header:SetText(L.UI_NAR_WHERE)
    page.header = header
    local inLog = body:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    inLog:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, -2)
    inLog:SetJustifyH("RIGHT")
    page.inLog = inLog

    local main = CreateFrame("Frame", nil, body)
    main:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -18)
    main:SetSize(MAIN_WIDTH, 20)
    main.mark = text(main, "GameFontNormal", MARK_W)
    main.mark:SetPoint("LEFT", main, "LEFT", 0, 0)
    main.text = text(main, "GameFontHighlight", MAIN_WIDTH - MARK_W - 2)
    main.text:SetPoint("LEFT", main, "LEFT", MARK_W + 2, 0)
    main:EnableMouse(true)
    main:SetScript("OnEnter", textTooltip)
    main:SetScript("OnLeave", UI.HideTooltip)
    page.main = main

    local lead = UI.CreateButton(body, L.UI_NAR_LEAD, nil, function()
        local N = ns.Narrative
        local w = N:Where()
        if N:IsFollowing() or (w and N:IsLeading(w.main)) then
            N:Stop()
        elseif w then
            N:Lead(w.main, true)
        end
        AN.refresh(page)
    end, LEAD_WIDTH, 20)
    lead:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, -18)
    page.leadButton = lead

    page.along = {}
    for i = 1, ALONG_ROWS do
        local row = CreateFrame("Button", nil, body)
        row:SetSize(PAGE_WIDTH, ALONG_HEIGHT)
        row:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -40 - (i - 1) * ALONG_HEIGHT)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.mark = text(row, "GameFontNormalSmall", MARK_W)
        row.mark:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.text = text(row, "GameFontHighlightSmall", PAGE_WIDTH - MARK_W - 2)
        row.text:SetPoint("LEFT", row, "LEFT", MARK_W + 2, 0)
        row:SetScript("OnClick", function(self) toggleLead(page, self.cand) end)
        row:SetScript("OnEnter", textTooltip)
        row:SetScript("OnLeave", UI.HideTooltip)
        page.along[i] = row
    end
end

-- Fill the "where now" block from Narrative:Where() (the level to wait for: in place of the main suggestion, or
-- after the header when the main suggestion is a hint).
local function renderWhere(page, w)
    local N = ns.Narrative
    page.header:SetText(w.main and w.wait and format(L.UI_NAR_WHERE_WAIT_FMT, w.wait) or L.UI_NAR_WHERE)
    page.inLog:SetText(format(L.NAR_INLOG_FMT, w.inLog, w.ready))
    local main = page.main
    if w.main then
        main.mark:SetText(">")
        main.mark:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        main.text:SetText(N:Describe(w.main))
    else
        main.mark:SetText("")
        main.text:SetText(w.wait and format(L.NAR_WAIT_FMT, w.wait) or L.UI_NAR_EMPTY)
    end
    local stop = N:IsFollowing() or N:IsLeading(w.main)
    page.leadButton:SetText(stop and L.UI_NAR_STOP or L.UI_NAR_LEAD)
    page.leadButton:SetEnabled(stop or leadable(w.main))
    for i, row in ipairs(page.along) do
        local c = w.along[i]
        row.cand = c
        if c then
            row.mark:SetText(N:IsLeading(c) and ">" or "")
            row.mark:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
            row.text:SetText(format("%s: %s", aspectLabel(c.goal.a), N:Describe(c)))
            row:Show()
        else
            row:Hide()
        end
    end
end

---------------------------------------------------------------------------
-- aspects and filters
---------------------------------------------------------------------------

-- One row per aspect: a label button that selects the list, a progress bar and the counts.
local function buildAspects(page, body)
    page.aspects = {}
    for i, a in ipairs(ns.Narrative.ASPECTS) do
        local y = ASPECTS_TOP - (i - 1) * 20
        local label = UI.CreateButton(body, aspectLabel(a), nil, function()
            options().aspect = a
            page.offset = 0
            AN.refresh(page)
        end, LABEL_WIDTH, 18)
        label:SetPoint("TOPLEFT", body, "TOPLEFT", 0, y)
        local bar = CreateFrame("StatusBar", nil, body)
        bar:SetPoint("LEFT", label, "RIGHT", 8, 0)
        bar:SetSize(BAR_WIDTH, 12)
        bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        bar:SetStatusBarColor(0.2, 0.7, 0.3)
        bar:SetMinMaxValues(0, 1)
        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(bar)
        bg:SetColorTexture(0, 0, 0, 0.5)
        local count = text(body, "GameFontHighlightSmall", PAGE_WIDTH - LABEL_WIDTH - BAR_WIDTH - 16)
        count:SetPoint("LEFT", bar, "RIGHT", 8, 0)
        page.aspects[a] = { label = label, bar = bar, count = count }
    end
end

-- Bars of res.aspect: done / (done + open); the missed slots of started goals after the count.
local function renderAspects(page, res, selected)
    for a, v in pairs(page.aspects) do
        local s = res.aspect[a]
        local total = s.done + s.open
        v.bar:SetValue(total > 0 and s.done / total or 0)
        local t = countText(s)
        if s.missed > 0 then t = t .. " " .. format(L.UI_NAR_MISSED_FMT, s.missed) end
        v.count:SetText(t)
        if a == selected then v.label:LockHighlight() else v.label:UnlockHighlight() end
    end
end

-- A check box with a label on its right (the filters).
local function filterCheck(page, body, key, label)
    local cb = CreateFrame("CheckButton", nil, body, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    local fs = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", cb, "RIGHT", 0, 1)
    fs:SetText(label)
    cb.label = fs
    cb:SetScript("OnClick", function(self)
        options()[key] = self:GetChecked() and true or false
        page.offset = 0
        AN.refresh(page)
    end)
    return cb
end

-- The filter line and the captions of the check box columns.
local function buildFilters(page, body)
    local hideDone = filterCheck(page, body, "hideDone", L.UI_NAR_HIDE_DONE)
    hideDone:SetPoint("TOPLEFT", body, "TOPLEFT", 0, FILTERS_TOP)
    local onlyNew = filterCheck(page, body, "onlyNew", L.UI_NAR_ONLY_NEW)
    onlyNew:SetPoint("LEFT", hideDone.label, "RIGHT", 14, -1)
    page.checks = { hideDone = hideDone, onlyNew = onlyNew }
end

---------------------------------------------------------------------------
-- goal list
---------------------------------------------------------------------------

-- Zone of the first positioned starter of a quest (goal.startObj: objects first, NPCs only when no start
-- object has a place, as Narrative's suggestions do), or nil.
local function startZone(goal, rec)
    local K = ns.Knowledge
    local s = rec.s or EMPTY
    for _, kind in ipairs(goal.startObj and { "o", "n" } or { "n", "o" }) do
        for _, id in ipairs(s[kind] or EMPTY) do
            local _, map = K:Entity(kind, id)
            if map then return ns.Compat.GetMapName(map) end
        end
    end
    return nil
end

-- Tooltip line of one quest of a goal: + done, > in the log, o otherwise with where to take it, the required
-- level when above the player's and the skill rank it still needs (r.need).
local function questLine(goal, q, r, level)
    local K = ns.Knowledge
    local title = K:Title(q)
    if r.done then return { "+ " .. title, GREEN[1], GREEN[2], GREEN[3] } end
    if r.inLog then return { format("> %s - %s", title, L.UI_KB_STATUS_ACTIVE), GOLD[1], GOLD[2], GOLD[3] } end
    local rec = K:Get(q) or EMPTY
    local t = format("o %s - %s", title, startZone(goal, rec) or L.NAR_NO_PLACE)
    if (rec.r or 1) > level then t = t .. " (" .. format(L.UI_NAR_FROM_FMT, rec.r) .. ")" end
    if r.need then t = t .. " (" .. format(L.UI_NAR_SKILL_FMT, r.need) .. ")" end
    return { t, WHITE[1], WHITE[2], WHITE[3] }
end

-- A colored tooltip line { text, r, g, b }.
local function line(t, c)
    return { t, c[1], c[2], c[3] }
end

-- "Name, Zone" of the nearest positioned NPC of a list, else the first one's name.
local function npcPlace(ids)
    local K, C = ns.Knowledge, ns.Compat
    local best, bestYards
    for _, id in ipairs(ids or EMPTY) do
        local name, map, x, y = K:Entity("n", id)
        if map then
            local yards = C.DistanceTo(map, x, y)
            if not best or (yards and (not bestYards or yards < bestYards)) then
                best, bestYards = format(L.NAR_PLACE_FMT, name, C.GetMapName(map) or ""), yards
            end
        end
    end
    return best or (ids and ids[1] and K:Entity("n", ids[1])) or L.NAR_NO_PLACE
end

-- Item names of a list, at most n, joined with ", ".
local function itemNames(ids, n)
    local names = {}
    for i, id in ipairs(ids or EMPTY) do
        if i > n then break end
        names[i] = ns.Narrative:ItemName(id)
    end
    return concat(names, ", ")
end

-- One blueprint line: "<blueprint> -- <boss>, <dungeon> (skill N)" + " (in your bags)".
local function blueprintLine(bp)
    local where = {}
    if bp.n then where[#where + 1] = ns.Knowledge:Entity("n", bp.n) end
    where[#where + 1] = ns.Compat.AreaName(bp.d)
    local t = format(L.UI_NAR_BLUEPRINT_FMT, ns.Narrative:ItemName(bp.i),
        #where > 0 and concat(where, ", ") or L.NAR_NO_PLACE, bp.need)
    if ns.Compat.ItemCount(bp.i) > 0 then t = t .. L.UI_NAR_IN_BAGS_TAG end
    return line(t, WHITE)
end

-- One leveling bracket: "lo-hi: items -- zones" (items only / zones only when the other is missing).
local function bracketLine(b, c)
    local zones = {}
    for _, map in ipairs(b.m or EMPTY) do zones[#zones + 1] = ns.Compat.GetMapName(map) or tostring(map) end
    local items, where = b.i and itemNames(b.i, BRACKET_ITEMS), concat(zones, ", ")
    local t = items and (#zones > 0 and format(L.UI_NAR_BRACKET_ZONES_FMT, items, where) or items) or where
    return line(format(L.UI_NAR_BRACKET_FMT, b.lo, b.hi, t), c)
end

-- The profession lines of a goal tooltip before its quests: the skill and the next rank (the level only where it
-- gates: not goal.nolv; green when it can be trained now), appended to `lines`.
local function skillLines(goal, lines)
    local N = ns.Narrative
    local rank, maxRank = N:Skill(goal.line)
    if not rank then return end
    lines[#lines + 1] = line(format(L.UI_NAR_SKILL_TT_FMT, rank, maxRank), GOLD)
    local tier, e, can = N:NextRank(goal)
    if not tier then return end
    local place = npcPlace(e.n)
    local t
    if e.i and goal.nolv then
        t = format(L.UI_NAR_BOOK_TT_FMT, tier.to, tier.need, N:ItemName(e.i), place)
    elseif e.i then
        t = format(L.UI_NAR_BOOK_LV_TT_FMT, tier.to, tier.need, tier.lv, N:ItemName(e.i), place)
    elseif goal.nolv then
        t = format(L.UI_NAR_TRAIN_SEC_TT_FMT, tier.to, tier.need, place)
    else
        t = format(L.UI_NAR_TRAIN_TT_FMT, tier.to, tier.need, tier.lv, place)
    end
    lines[#lines + 1] = line(t, can and GREEN or WHITE)
end

-- The leveling brackets (the current ones in green, the next one in white; without the skill the first two) and
-- the camp blueprints of a profession goal tooltip.
local function professionLines(goal, lines)
    local N = ns.Narrative
    local rank = N:Skill(goal.line)
    local brackets = {}
    for _, b in ipairs(goal.brackets or EMPTY) do
        if not rank then
            if #brackets < 2 then brackets[#brackets + 1] = bracketLine(b, WHITE) end
        elseif b.lo <= rank and rank < b.hi then
            brackets[#brackets + 1] = bracketLine(b, GREEN)
        elseif b.lo > rank then
            brackets[#brackets + 1] = bracketLine(b, WHITE)
            break
        end
    end
    if #brackets > 0 then
        lines[#lines + 1] = line(L.UI_NAR_BRACKETS, GOLD)
        for _, l in ipairs(brackets) do lines[#lines + 1] = l end
    end
    if goal.blueprints and #goal.blueprints > 0 then
        lines[#lines + 1] = line(L.UI_NAR_BLUEPRINTS, GOLD)
        for _, bp in ipairs(goal.blueprints) do lines[#lines + 1] = blueprintLine(bp) end
    end
end

-- The camp blueprints dropping in a dungeon for the professions the character has.
local function lootLines(goal, lines)
    local N = ns.Narrative
    local header = false
    for _, e in ipairs(N:Blueprints(goal.d)) do
        if N:Skill(e.goal.line) then
            if not header then
                header = true
                lines[#lines + 1] = line(L.UI_NAR_LOOT, GOLD)
            end
            lines[#lines + 1] = blueprintLine(e.bp)
        end
    end
end

-- The goal tooltip: (profession: the skill and the next rank) the next open slots, the optional quests, a
-- dungeon's lead-in quests and blueprints, (profession: the leveling brackets and the camp blueprints) the
-- curated note, source and "not checked in game".
local function goalTooltip(row)
    local N = ns.Narrative
    local goal, gs = row.goal, row.gs
    if not goal then return end
    local res = N:Get()
    local level = UI.PlayerLevel() or 1
    local lines = {}
    if goal.line then skillLines(goal, lines) end
    local n = 0
    for i, slot in ipairs(goal.q) do
        if gs.slot[i] == "open" and n < NEXT_SLOTS then
            for _, q in ipairs(type(slot) == "table" and slot or { slot }) do
                local r = res.q[q]
                if r and r.mine and not r.lost then
                    n = n + 1
                    lines[#lines + 1] = questLine(goal, q, r, level)
                    break
                end
            end
        end
    end
    local header = false -- the optional quests this character can do (or did)
    for _, q in ipairs(goal.opt or EMPTY) do
        local r = res.q[q]
        if r and r.mine and (r.done or not r.lost) then
            if not header then
                header = true
                lines[#lines + 1] = { L.UI_NAR_OPT, GOLD[1], GOLD[2], GOLD[3] }
            end
            lines[#lines + 1] = questLine(goal, q, r, level)
        end
    end
    if goal.prep then
        lines[#lines + 1] = { L.UI_NAR_PREP, GOLD[1], GOLD[2], GOLD[3] }
        local shown = 0
        for _, q in ipairs(goal.prep) do
            local r = res.q[q]
            if r and r.mine and shown < PREP_LINES then
                shown = shown + 1
                lines[#lines + 1] = questLine(goal, q, r, level)
            end
        end
    end
    if goal.d then lootLines(goal, lines) end
    if goal.line then professionLines(goal, lines) end
    local note = UI.Text(goal.note)
    if note then lines[#lines + 1] = { note, GOLD[1], GOLD[2], GOLD[3] } end
    if goal.src then lines[#lines + 1] = { format(L.UI_NAR_SOURCE_FMT, goal.src), GREY[1], GREY[2], GREY[3] } end
    if goal.v == false then lines[#lines + 1] = { L.UI_NAR_UNVERIFIED, GREY[1], GREY[2], GREY[3] } end
    UI.ShowTooltip(row, N:Title(goal), lines)
end

-- A per-goal check box ("done": did it myself, "skip": not interested): writes the marks of the goal.
local function markCheck(page, row, value, label, tooltip, x)
    local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    cb:SetSize(20, 20)
    cb:SetPoint("CENTER", row, "RIGHT", x, 0)
    cb:SetScript("OnClick", function(self)
        ns.Narrative:Mark(row.goal, self:GetChecked() and value or nil)
        AN.refresh(page)
    end)
    cb:SetScript("OnEnter", function(self) UI.ShowTooltip(self, label, { tooltip }) end)
    cb:SetScript("OnLeave", UI.HideTooltip)
    return cb
end

-- One pooled list row: a zone header (zone text) or a goal (mark, title, levels, count, tags, check boxes).
local function buildRow(page, i)
    local row = CreateFrame("Button", nil, page.list)
    row:SetSize(LIST_WIDTH, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", page.list, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.zone = text(row, "GameFontNormal", LIST_WIDTH - 4)
    row.zone:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.mark = text(row, "GameFontNormalSmall", MARK_W)
    row.mark:SetPoint("LEFT", row, "LEFT", 0, 0)
    local right = 2 * COL_W + 4
    row.tag = text(row, "GameFontNormalSmall", TAG_W)
    row.tag:SetPoint("RIGHT", row, "RIGHT", -right, 0)
    row.tag:SetTextColor(0.4, 0.8, 1)
    row.count = text(row, "GameFontHighlightSmall", COUNT_W)
    row.count:SetPoint("RIGHT", row, "RIGHT", -(right + TAG_W + 4), 0)
    row.level = text(row, "GameFontHighlightSmall", LEVEL_W)
    row.level:SetPoint("RIGHT", row, "RIGHT", -(right + TAG_W + COUNT_W + 8), 0)
    row.name = text(row, "GameFontHighlight", LIST_WIDTH - MARK_W - 2 - LEVEL_W - COUNT_W - TAG_W - right - 16)
    row.name:SetPoint("LEFT", row, "LEFT", MARK_W + 2, 0)
    row.done = markCheck(page, row, "done", L.UI_NAR_COL_DONE, L.UI_NAR_DONE_TT, -(COL_W + COL_W / 2))
    row.skip = markCheck(page, row, "skip", L.UI_NAR_COL_SKIP, L.UI_NAR_SKIP_TT, -COL_W / 2)
    row:SetScript("OnClick", function(self)
        if self.goal then toggleLead(page, ns.Narrative:Best(self.goal)) end
    end)
    row:SetScript("OnEnter", goalTooltip)
    row:SetScript("OnLeave", UI.HideTooltip)
    return row
end

local function maxOffset(page)
    return max(0, #page.results - ROWS)
end

local function setOffset(page, offset)
    page.offset = max(0, min(maxOffset(page), floor(offset + 0.5)))
    AN.renderList(page)
end

-- The list frame with its pooled rows, the slider, the column captions and the "no goals" text.
local function buildList(page, body)
    local list = CreateFrame("Frame", nil, body)
    list:SetPoint("TOPLEFT", body, "TOPLEFT", 0, LIST_TOP)
    list:SetSize(LIST_WIDTH, ROWS * ROW_HEIGHT)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta) setOffset(page, page.offset - delta * 3) end)
    local bg = list:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(list)
    bg:SetColorTexture(0, 0, 0, 0.25)
    page.list, page.rows = list, {}
    for i = 1, ROWS do page.rows[i] = buildRow(page, i) end

    for _, col in ipairs({ { L.UI_NAR_COL_DONE, -COL_W }, { L.UI_NAR_COL_SKIP, 0 } }) do
        local cap = body:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        cap:SetWidth(COL_W)
        cap:SetJustifyH("CENTER")
        cap:SetPoint("BOTTOMRIGHT", list, "TOPRIGHT", col[2], 4)
        cap:SetText(col[1])
    end

    local slider = CreateFrame("Slider", nil, body)
    slider:SetPoint("TOPLEFT", list, "TOPRIGHT", 4, 0)
    slider:SetSize(SLIDER_WIDTH, ROWS * ROW_HEIGHT)
    slider:SetOrientation("VERTICAL")
    slider:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider:SetMinMaxValues(0, 0)
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints(slider)
    track:SetColorTexture(0, 0, 0, 0.4)
    slider:SetScript("OnValueChanged", function(_, value, userInput)
        if userInput then setOffset(page, value) end
    end)
    page.slider = slider

    local empty = list:CreateFontString(nil, "OVERLAY", "GameFontDisable") -- above the list's background
    empty:SetPoint("TOPLEFT", list, "TOPLEFT", 6, -6)
    empty:SetText(L.UI_NAR_EMPTY)
    page.empty = empty
end

-- Show either the zone header or the goal widgets of a pooled row.
local function setRowKind(row, isGoal)
    row.zone:SetShown(not isGoal)
    for _, w in ipairs({ row.mark, row.name, row.level, row.count, row.tag, row.done, row.skip }) do
        w:SetShown(isGoal)
    end
end

-- Fill a goal row: state mark and color, title, level band (a learned profession: rank/max, "+" when the next
-- rank can be trained now), count (or "passed by" / "from level N" / "skill N"), tags (* new in Forever,
-- ? not checked in game) and the check boxes of its mark.
local function renderGoal(row, goal, gs)
    local N = ns.Narrative
    local look = STATE_LOOK[gs.state] or STATE_LOOK.open
    local c = look[2]
    row.mark:SetText(look[1])
    for _, fs in ipairs({ row.mark, row.name, row.level, row.count }) do fs:SetTextColor(c[1], c[2], c[3]) end
    row.name:SetText(N:Title(goal))
    local rank, maxRank
    if goal.line then rank, maxRank = N:Skill(goal.line) end
    if rank then
        local _, _, can = N:NextRank(goal)
        row.level:SetText(format(can and L.UI_NAR_RANK_UP_FMT or L.UI_NAR_RANK_FMT, rank, maxRank))
    else
        row.level:SetText(levelsText(goal.lo, goal.hi))
    end
    local count
    if gs.state == "missed" and gs.done == 0 then
        count = L.UI_NAR_PASSED
    elseif gs.state == "later" and gs.skill then -- skill-locked
        count = format(L.UI_NAR_SKILL_FMT, gs.skill)
    elseif gs.state == "later" and gs.done == 0 and gs.later then -- level-locked (not only behind a chain)
        count = format(L.UI_NAR_FROM_FMT, gs.later)
    else
        count = countText(gs)
        if gs.missed > 0 and gs.done > 0 then count = count .. " " .. format(L.UI_NAR_MISSED_FMT, gs.missed) end
    end
    row.count:SetText(count)
    row.tag:SetText((goal.new and "*" or "") .. (goal.v == false and "?" or ""))
    local mark = N:GoalMark(goal)
    row.done:SetChecked(mark == "done")
    row.skip:SetChecked(mark == "skip")
end

--- Fill the pooled rows from page.results (Narrative:List rows) starting at page.offset.
function AN.renderList(page)
    local K = ns.Knowledge
    local results = page.results
    page.slider:SetMinMaxValues(0, maxOffset(page))
    page.slider:SetValue(page.offset)
    page.slider:SetShown(#results > ROWS)
    page.empty:SetShown(#results == 0)
    for i, row in ipairs(page.rows) do
        local item = results[page.offset + i]
        row.goal, row.gs = nil, nil
        if not item then
            row:Hide()
        elseif item.kind == "zone" then
            setRowKind(row, false)
            local s = item.sum or { done = 0, open = 0, lo = 0, hi = 0 }
            row.zone:SetText(format(L.UI_NAR_ZONE_FMT, K:ZoneName(item.z), levelsText(s.lo, s.hi), s.done, s.done + s.open))
            row:Show()
        else
            setRowKind(row, true)
            row.goal, row.gs = item.goal, item.gs
            renderGoal(row, item.goal, item.gs)
            row:Show()
        end
    end
    -- an open goal tooltip follows its row (item names arrive later; the list may have moved under the mouse)
    for _, row in ipairs(page.rows) do
        if row.goal and GameTooltip and GameTooltip:IsOwned(row) then goalTooltip(row) end
    end
end

---------------------------------------------------------------------------
-- view
---------------------------------------------------------------------------

--- Build the view into its frame (once).
function AN.build(page)
    page.offset, page.results = 0, {}
    local body = CreateFrame("Frame", nil, page)
    body:SetAllPoints(page)
    page.body = body
    buildWhere(page, body)
    buildAspects(page, body)
    buildFilters(page, body)
    buildList(page, body)

    local missing = page:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    missing:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    missing:SetWidth(PAGE_WIDTH)
    missing:SetJustifyH("LEFT")
    missing:SetText(L.UI_KB_NOT_INSTALLED)
    page.missing = missing
end

--- Re-read ns.Narrative into the view (loads the knowledge base on first use).
function AN.refresh(page)
    local N = ns.Narrative
    local ok = N:Load()
    page.body:SetShown(ok)
    page.missing:SetShown(not ok)
    if not ok then return end
    local o = options()
    page.checks.hideDone:SetChecked(o.hideDone == true)
    page.checks.onlyNew:SetChecked(o.onlyNew == true)
    renderWhere(page, N:Where())
    renderAspects(page, N:Get(), o.aspect)
    page.results = N:List(o.aspect, { hideDone = o.hideDone == true, onlyNew = o.onlyNew == true })
    page.offset = min(page.offset, maxOffset(page))
    AN.renderList(page)
end
