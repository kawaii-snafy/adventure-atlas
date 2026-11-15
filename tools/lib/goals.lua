-- tools/lib/goals.lua -- narrative goals of the knowledge base (Lua 5.1, pure).
--
--   local Goals = require("lib.goals")
--   local curated = Goals.LoadCurated("tools/data/narrative.lua")  -- error() when it does not load
--   local goals, notes, excluded = Goals.Build(db, fileIds, zoneOf, curated)  -- error() on a hard error
--   local lines = Goals.Lines(goals)                                -- the `goals = { ... }` text
--
-- Groups the quests of the knowledge base (tools/gen_knowledge_data.lua) into goals of four aspects:
-- story, dungeon, class and novelty (curated in tools/data/narrative.lua). Every Horde record of the
-- file gets exactly one disposition: a counted slot of a goal, an optional quest of a goal (`opt`), or
-- excluded with a reason (index-only, repeatable, endgame, ...; listed in the notes). The goal format
-- is documented in the header of tools/gen_knowledge_data.lua. Inputs:
--   db      = tools/data/forever_db.lua with the overrides applied (tools/lib/fbdb.lua)
--   fileIds = { [questID] = true }  every quest of the file: full records and index-only entries
--   zoneOf  = { [questID] = k }     zones[] key of each quest of the file (the file's zone numbering)
--   curated = the table of tools/data/narrative.lua
-- The output is deterministic (no pairs() order leaks into it).

local DB = require("lib.fbdb")

local Goals = {}

local format, floor, sort, concat = string.format, math.floor, table.sort, table.concat

local ASPECTS = { "story", "dungeon", "class", "novelty" }
local ASPECT_RANK = { story = 1, dungeon = 2, class = 3, novelty = 4 }
-- quest sorts (zone < 0) of seasonal events, the legendaries and the reputation / war-effort sorts
local EVENT_SORTS = {
    [-22] = true, [-284] = true, [-344] = true, [-364] = true, [-365] = true, [-366] = true, [-367] = true,
    [-368] = true, [-369] = true,
}
-- quest sorts of the professions (stage 1 leaves them out; reqSkill quests too)
local PROFESSION_SORTS = {
    [-24] = true, [-101] = true, [-121] = true, [-182] = true, [-201] = true, [-264] = true, [-304] = true,
    [-324] = true,
}
local ENDGAME_REQ = 58      -- reqLevel from which a quest is endgame
local BREADCRUMB_HOPS = 10  -- a breadcrumb may lead to another breadcrumb, at most this many times

-- keys a curated entry may carry (anything else is a shape error)
local TOP_KEYS = { dungeons = true, goals = true, titles = true, exclude = true, opt = true }
local DUNGEON_KEYS = { xp = true, lo = true, hi = true, areas = true, after = true, add = true, src = true, v = true }
local GOAL_KEYS = {
    key = true, name = true, q = true, opt = true, note = true, after = true, cnt = true, hint = true,
    startObj = true, src = true, v = true,
}

--- Sorted keys of a table.
local function sortedKeys(t)
    local out = {}
    for k in pairs(t) do out[#out + 1] = k end
    sort(out)
    return out
end

local function isId(v)
    return type(v) == "number" and v > 0 and floor(v) == v
end

local function luaString(s)
    return (format("%q", s):gsub("\\\n", "\\n"))
end

--- Load the curated file (one `return { ... }`, run in an empty environment like tools/overrides).
function Goals.LoadCurated(path)
    local chunk, err = loadfile(path)
    if not chunk then error("cannot load " .. tostring(path) .. ": " .. tostring(err), 0) end
    setfenv(chunk, {})
    local ok, data = pcall(chunk)
    if not ok then error(tostring(path) .. ": " .. tostring(data), 0) end
    if type(data) ~= "table" then error(tostring(path) .. ": must return a table", 0) end
    return data
end

--- Shape check of the curated table. Appends messages to errs.
local function checkShape(cur, errs)
    local function bad(fmt, ...) errs[#errs + 1] = "narrative.lua: " .. format(fmt, ...) end
    local function idList(v, what)
        if type(v) ~= "table" then bad("%s: not a list", what) return end
        for i, id in ipairs(v) do
            if not isId(id) then bad("%s[%d]: not a quest id", what, i) end
        end
    end
    local function idMap(v, what, valueOk)
        if type(v) ~= "table" then bad("%s: not a table", what) return end
        for k, val in pairs(v) do
            if not isId(k) or not valueOk(val) then bad("%s[%s]: bad entry", what, tostring(k)) end
        end
    end
    local function text(v) return type(v) == "table" and type(v.en) == "string" and type(v.ru) == "string" end
    local function provenance(e, what)
        if type(e.src) ~= "string" or e.src == "" then bad("%s: src missing", what) end
        if type(e.v) ~= "boolean" then bad("%s: v (verified in game) missing", what) end
    end
    for k in pairs(cur) do
        if not TOP_KEYS[k] then bad("unknown key %s", tostring(k)) end
    end
    for area, d in pairs(cur.dungeons or {}) do
        local what = "dungeons[" .. tostring(area) .. "]"
        if not isId(area) or type(d) ~= "table" then bad("%s: bad entry", what) else
            for k in pairs(d) do
                if not DUNGEON_KEYS[k] then bad("%s: unknown key %s", what, tostring(k)) end
            end
            if d.xp ~= nil and type(d.xp) ~= "string" then bad("%s: xp is not a slug", what) end
            if (d.lo == nil) ~= (d.hi == nil) or (d.lo ~= nil and not (isId(d.lo) and isId(d.hi))) then
                bad("%s: lo / hi must be given together as levels", what)
            end
            if d.areas ~= nil then idList(d.areas, what .. ".areas") end
            if d.add ~= nil then idList(d.add, what .. ".add") end
            if d.after ~= nil then idMap(d.after, what .. ".after", isId) end
            if d.lo or d.after or d.add or d.src ~= nil or d.v ~= nil then provenance(d, what) end
        end
    end
    local keys = {}
    for i, g in ipairs(cur.goals or {}) do
        local what = "goals[" .. i .. "]"
        if type(g) ~= "table" then bad("%s: not a table", what) else
            for k in pairs(g) do
                if not GOAL_KEYS[k] then bad("%s: unknown key %s", what, tostring(k)) end
            end
            if type(g.key) ~= "string" or g.key == "" then bad("%s: key missing", what)
            elseif keys[g.key] then bad("%s: key %s twice", what, g.key) end
            keys[g.key or i] = true
            if not text(g.name) then bad("%s: name = { en, ru } missing", what) end
            if g.note ~= nil and not text(g.note) then bad("%s: note is not { en, ru }", what) end
            if type(g.q) ~= "table" or #g.q == 0 then bad("%s: q missing", what) else
                for j, slot in ipairs(g.q) do
                    if type(slot) == "table" then idList(slot, format("%s.q[%d]", what, j))
                    elseif not isId(slot) then bad("%s.q[%d]: not a quest id", what, j) end
                end
            end
            if g.opt ~= nil then idList(g.opt, what .. ".opt") end
            if g.after ~= nil then idMap(g.after, what .. ".after", isId) end
            if g.cnt ~= nil then idMap(g.cnt, what .. ".cnt", isId) end
            if g.hint ~= nil then
                idMap(g.hint, what .. ".hint", function(h) return type(h) == "table" and isId(h[1]) and isId(h[2]) end)
            end
            if g.startObj ~= nil and g.startObj ~= true then bad("%s: startObj must be true or absent", what) end
            provenance(g, what)
        end
    end
    for id, t in pairs(cur.titles or {}) do
        if type(id) ~= "string" or not text(t) then bad("titles[%s]: bad entry", tostring(id)) end
    end
    for _, name in ipairs({ "exclude", "opt" }) do
        if cur[name] ~= nil then
            idMap(cur[name], name, function(r) return type(r) == "string" and r ~= "" end)
        end
    end
end

--- Kahn topological order of slots over pa / py / next (ties: effective level, then id).
-- slots = { slot, ... } (number or clique array); returns the ordered list, or nil when there is a cycle.
local function topoOrder(slots, slotOf, preds, effOf)
    local key, indeg, succ = {}, {}, {}
    for i, s in ipairs(slots) do
        local members = type(s) == "table" and s or { s }
        local eff, id = math.huge, math.huge
        for _, m in ipairs(members) do
            eff = math.min(eff, effOf(m))
            id = math.min(id, m)
        end
        key[i] = { eff = eff, id = id }
        indeg[i] = 0
        succ[i] = {}
    end
    local index = {}
    for i, s in ipairs(slots) do index[s] = i end
    for i, s in ipairs(slots) do
        local seen = {}
        for _, m in ipairs(type(s) == "table" and s or { s }) do
            for _, p in ipairs(preds[m] or {}) do
                local j = slotOf[p] and index[slotOf[p]]
                if j and j ~= i and not seen[j] then
                    seen[j] = true
                    indeg[i] = indeg[i] + 1
                    succ[j][#succ[j] + 1] = i
                end
            end
        end
    end
    local ready, out = {}, {}
    for i in ipairs(slots) do
        if indeg[i] == 0 then ready[#ready + 1] = i end
    end
    while #ready > 0 do
        local best = 1
        for r = 2, #ready do
            local a, b = key[ready[r]], key[ready[best]]
            if a.eff < b.eff or (a.eff == b.eff and a.id < b.id) then best = r end
        end
        local i = table.remove(ready, best)
        out[#out + 1] = slots[i]
        for _, j in ipairs(succ[i]) do
            indeg[j] = indeg[j] - 1
            if indeg[j] == 0 then ready[#ready + 1] = j end
        end
    end
    if #out < #slots then return nil end
    return out
end

--- Build the goals. @return goals (array; format in the header of tools/gen_knowledge_data.lua), notes (lines
-- for stderr), excluded ({ [questID] = reason } of the quests in no goal); error() on hard errors.
function Goals.Build(db, fileIds, zoneOf, curated)
    local errs = {}
    local function fail(fmt, ...) errs[#errs + 1] = format(fmt, ...) end
    checkShape(curated, errs)
    if #errs > 0 then error(concat(errs, "\n"), 0) end

    local classOfSort = {}
    for class, s in pairs(db.enums.classSorts) do classOfSort[s] = class end
    local REPEATABLE = db.enums.specialFlags.REPEATABLE
    local function full(id) return fileIds[id] and db.quests[id] or nil end
    local function eff(id)
        local q = db.quests[id]
        return (q.level or 0) > 0 and q.level or math.max(q.reqLevel or 1, 1)
    end
    local fullIds = {}
    for _, id in ipairs(sortedKeys(fileIds)) do
        if db.quests[id] then fullIds[#fullIds + 1] = id end
    end

    -- symmetric exclusive partners within the file; predecessors over pa / py / next
    local partners, preds = {}, {}
    local function addPartner(a, b)
        partners[a] = partners[a] or {}
        partners[a][b] = true
    end
    local function addPred(b, a)
        if a ~= b and fileIds[a] and fileIds[b] then
            preds[b] = preds[b] or {}
            preds[b][#preds[b] + 1] = a
        end
    end
    for _, id in ipairs(fullIds) do
        local q = db.quests[id]
        for _, b in ipairs(q.exclusive or {}) do
            if fileIds[b] and b ~= id then
                addPartner(id, b)
                addPartner(b, id)
            end
        end
        for _, p in ipairs(q.preGroup or {}) do addPred(id, p) end
        for _, p in ipairs(q.preSingle or {}) do addPred(id, p) end
        if q.next then addPred(q.next, id) end
    end

    -- usable starters / enders, as in the file: non-Alliance NPCs, known objects and items
    local function npcs(list)
        local out = {}
        for _, n in ipairs(list or {}) do
            if db.npcs[n] and db.npcs[n].faction ~= "A" then out[#out + 1] = n end
        end
        sort(out)
        return out
    end
    local function firstStarter(id)
        local s = db.quests[id].start or {}
        local n = npcs(s.npcs)[1]
        if n then return "n" .. n end
        local best
        for _, o in ipairs(s.objects or {}) do
            if db.objects[o] and (not best or o < best) then best = o end
        end
        if best then return "o" .. best end
        for _, i in ipairs(s.items or {}) do
            if db.items[i] and (not best or i < best) then best = i end
        end
        return best and ("i" .. best) or nil
    end

    -- curated claims: every id at most once, every id a full record of the file
    local claimed = {}
    local function claim(id, where)
        if not full(id) then fail("curated %s: quest %d is not a full record of the file", where, id)
        elseif claimed[id] then fail("curated %s: quest %d already claimed by %s", where, id, claimed[id])
        else claimed[id] = where end
    end
    local curatedGoal = {}   -- quest id -> index in curated.goals
    for i, g in ipairs(curated.goals or {}) do
        for _, slot in ipairs(g.q) do
            for _, id in ipairs(type(slot) == "table" and slot or { slot }) do
                claim(id, "goal " .. g.key)
                curatedGoal[id] = i
            end
        end
        for _, id in ipairs(g.opt or {}) do
            claim(id, "goal " .. g.key .. " opt")
            curatedGoal[id] = i
        end
    end
    local forcedDungeon = {} -- quest id -> dungeon area (curated `add`)
    local dungeonOf = {}     -- AreaTable id (dungeon or sub-area) -> whitelisted dungeon area
    for _, area in ipairs(sortedKeys(curated.dungeons or {})) do
        local d = curated.dungeons[area]
        dungeonOf[area] = area
        for _, sub in ipairs(d.areas or {}) do dungeonOf[sub] = area end
        for _, id in ipairs(d.add or {}) do
            claim(id, "dungeon " .. area)
            forcedDungeon[id] = area
        end
        local info = db.dungeons[area]
        if not info then fail("dungeon %d: not in db.dungeons", area)
        elseif not info.entrances or #info.entrances == 0 then fail("dungeon %d (%s): no entrances", area, info.name) end
        if d.xp and not (db.xp.dungeons[d.xp] and db.xp.dungeons[d.xp].levels) then
            fail("dungeon %d: unknown xp slug %s", area, d.xp)
        end
    end
    for _, name in ipairs({ "exclude", "opt" }) do
        for _, id in ipairs(sortedKeys(curated[name] or {})) do claim(id, name) end
    end
    if #errs > 0 then error(concat(errs, "\n"), 0) end

    -- 1. disposition: aspect (+ dungeon area) or an exclusion reason; the first matching rule wins
    local aspect, dungeonArea, excluded = {}, {}, {}
    local function areasOf(q)
        local out = {}
        if (q.zone or 0) > 0 then out[#out + 1] = q.zone end
        local z = q.uiMap and db.zones[q.uiMap]
        if z and z.dungeon and z.areaId then out[#out + 1] = z.areaId end
        return out
    end
    local function dispose(id)
        local q = db.quests[id]
        if not q then return nil, "index" end
        if curated.exclude and curated.exclude[id] then return nil, "curated" end
        if curatedGoal[id] then return "novelty" end
        if forcedDungeon[id] then return "dungeon", forcedDungeon[id] end
        local zone, name = q.zone or 0, q.name or ""
        if DB.HasBit(q.special, REPEATABLE) then return nil, "repeatable" end
        if EVENT_SORTS[zone] then return nil, "event" end
        if q.reqSkill or PROFESSION_SORTS[zone] then return nil, "profession" end
        if name:sub(1, 1) == "<" or name:find("REUSE", 1, true) then return nil, "placeholder" end
        if (q.reqLevel or 0) >= ENDGAME_REQ then return nil, "endgame" end
        if (q.level or 0) >= 60 and (q.reqLevel or 0) <= 10 then return nil, "anylevel" end
        if q.maxLevel or q.disabledBy or q.untilCompleted then return nil, "limited" end
        if (q.classes or 0) ~= 0 or classOfSort[zone] then return "class" end
        local areas = areasOf(q)
        for _, a in ipairs(areas) do
            if db.dungeons[a] and not dungeonOf[a] then return nil, "instance" end
        end
        for _, a in ipairs(areas) do
            if dungeonOf[a] then return "dungeon", dungeonOf[a] end
        end
        return "story"
    end
    for _, id in ipairs(sortedKeys(fileIds)) do
        local a, extra = dispose(id)
        if a then
            aspect[id] = a
            dungeonArea[id] = a == "dungeon" and extra or nil
        else
            excluded[id] = extra
        end
    end

    -- breadcrumbs leave the grouping: they become optional quests of the goal that owns their target
    local breadcrumbs = {}
    for _, id in ipairs(fullIds) do
        local a = aspect[id]
        if a and a ~= "novelty" and db.quests[id].breadcrumbFor then
            breadcrumbs[#breadcrumbs + 1] = id
            aspect[id] = nil
        end
    end

    -- 2. raw goals: { a, kind, members = { id, ... }, area = dungeon area }
    local raw = {}
    local byArea = {}
    for _, id in ipairs(fullIds) do
        if aspect[id] == "dungeon" then
            local area = dungeonArea[id]
            if not byArea[area] then
                byArea[area] = { a = "dungeon", members = {}, area = area }
                raw[#raw + 1] = byArea[area]
            end
            local m = byArea[area].members
            m[#m + 1] = id
        end
    end
    -- story and class: components over pa / py / next and exclusive links within the aspect
    for _, a in ipairs({ "story", "class" }) do
        local adj = {}
        local function link(x, y)
            if aspect[x] == a and aspect[y] == a and x ~= y then
                adj[x] = adj[x] or {}
                adj[y] = adj[y] or {}
                adj[x][y] = true
                adj[y][x] = true
            end
        end
        for _, id in ipairs(fullIds) do
            for _, p in ipairs(preds[id] or {}) do link(p, id) end
            for b in pairs(partners[id] or {}) do link(id, b) end
        end
        local comps, compOf = {}, {}
        for _, id in ipairs(fullIds) do
            if aspect[id] == a and not compOf[id] then
                local c = { id }
                compOf[id] = #comps + 1
                local i = 1
                while i <= #c do
                    for _, n in ipairs(sortedKeys(adj[c[i]] or {})) do
                        if not compOf[n] then
                            compOf[n] = #comps + 1
                            c[#c + 1] = n
                        end
                    end
                    i = i + 1
                end
                comps[#comps + 1] = c
            end
        end
        -- a singleton joins the first multi-quest component of its zone that shares a start or end NPC
        local function npcKeys(id)
            local q, out = db.quests[id], {}
            for _, n in ipairs(npcs(q.start and q.start.npcs)) do out[#out + 1] = n .. "@" .. zoneOf[id] end
            for _, n in ipairs(npcs(q.finish and q.finish.npcs)) do out[#out + 1] = n .. "@" .. zoneOf[id] end
            return out
        end
        local compOfNpc = {}
        for ci, c in ipairs(comps) do
            if #c > 1 then
                for _, id in ipairs(c) do
                    for _, k in ipairs(npcKeys(id)) do
                        if not compOfNpc[k] then compOfNpc[k] = ci end
                    end
                end
            end
        end
        local chains, errands, errandKeys = {}, {}, {}
        for ci, c in ipairs(comps) do
            if #c > 1 then chains[ci] = { a = a, kind = "chain", members = c } end
        end
        for _, c in ipairs(comps) do
            if #c == 1 then
                local id, target = c[1], nil
                for _, k in ipairs(npcKeys(id)) do
                    local ci = compOfNpc[k]
                    if ci and (not target or ci < target) then target = ci end
                end
                if target then
                    local m = chains[target].members
                    m[#m + 1] = id
                else
                    local key = zoneOf[id] .. "#" .. (firstStarter(id) or "-")
                    if not errands[key] then
                        errands[key] = { a = a, kind = "errands", members = {} }
                        errandKeys[#errandKeys + 1] = key
                    end
                    local m = errands[key].members
                    m[#m + 1] = id
                end
            end
        end
        for ci = 1, #comps do
            if chains[ci] then raw[#raw + 1] = chains[ci] end
        end
        for _, key in ipairs(errandKeys) do raw[#raw + 1] = errands[key] end
    end

    -- 3. optional members (curated opt, no starter left); counted members form the slots
    local optReason, optCount = {}, { breadcrumb = 0, nostarter = 0, curated = 0 }
    local function hasStarter(id)
        local s = db.quests[id].start or {}
        if #npcs(s.npcs) > 0 then return true end
        for _, o in ipairs(s.objects or {}) do if db.objects[o] then return true end end
        for _, i in ipairs(s.items or {}) do if db.items[i] then return true end end
        return false
    end
    for _, g in ipairs(raw) do
        g.counted, g.opt = {}, {}
        for _, id in ipairs(g.members) do
            local why = (curated.opt and curated.opt[id] and "curated") or (not hasStarter(id) and "nostarter")
            if why then
                optReason[id] = why
                g.opt[#g.opt + 1] = id
            else
                g.counted[#g.counted + 1] = id
            end
        end
    end
    -- curated novelty goals
    for i, c in ipairs(curated.goals or {}) do
        local g = { a = "novelty", curated = c, order = i, counted = {}, opt = {} }
        for _, slot in ipairs(c.q) do
            for _, id in ipairs(type(slot) == "table" and slot or { slot }) do g.counted[#g.counted + 1] = id end
        end
        for _, id in ipairs(c.opt or {}) do
            g.opt[#g.opt + 1] = id
            optReason[id] = "curated"
        end
        raw[#raw + 1] = g
    end
    -- a goal without a counted quest is dropped: its optional quests leave every bar
    local goalOf, kept = {}, {}
    for _, g in ipairs(raw) do
        if #g.counted == 0 then
            for _, id in ipairs(g.opt) do
                excluded[id] = "optonly"
                optReason[id] = nil
            end
        else
            kept[#kept + 1] = g
            for _, list in ipairs({ g.counted, g.opt }) do
                for _, id in ipairs(list) do
                    if goalOf[id] then fail("quest %d is in two goals", id) end
                    goalOf[id] = g
                end
            end
        end
    end
    raw = kept
    for _, id in ipairs(breadcrumbs) do
        local target, hops = db.quests[id].breadcrumbFor, 0
        while target and not goalOf[target] and hops < BREADCRUMB_HOPS and full(target) do
            target = db.quests[target].breadcrumbFor
            hops = hops + 1
        end
        local g = target and goalOf[target]
        if g then
            g.opt[#g.opt + 1] = id
            goalOf[id] = g
            optReason[id] = (curated.opt and curated.opt[id]) and "curated" or "breadcrumb"
        else
            excluded[id] = "breadcrumb"
        end
    end
    for _, why in pairs(optReason) do optCount[why] = optCount[why] + 1 end

    -- 4. slots, order, level band, ids
    local goals = {}
    local function isClique(list)
        for i = 1, #list do
            for j = i + 1, #list do
                if not (partners[list[i]] and partners[list[i]][list[j]]) then return false end
            end
        end
        return true
    end
    local slotOf = {}
    for _, g in ipairs(raw) do
        local inGoal = {}
        for _, id in ipairs(g.counted) do inGoal[id] = true end
        local slots = {}
        if g.curated then
            for _, slot in ipairs(g.curated.q) do
                if type(slot) == "table" then
                    local s = {}
                    for i, id in ipairs(slot) do s[i] = id end
                    sort(s)
                    if not isClique(s) then
                        fail("goal n:%s: slot { %s } is not an exclusive clique", g.curated.key, concat(s, ", "))
                    end
                    slots[#slots + 1] = s
                else
                    slots[#slots + 1] = slot
                end
            end
        else
            local done = {}
            for _, id in ipairs(g.counted) do
                if not done[id] then
                    -- the exclusive component of id within the file
                    local comp, i = { id }, 1
                    local seen = { [id] = true }
                    while i <= #comp do
                        for _, b in ipairs(sortedKeys(partners[comp[i]] or {})) do
                            if not seen[b] then
                                seen[b] = true
                                comp[#comp + 1] = b
                            end
                        end
                        i = i + 1
                    end
                    sort(comp)
                    local whole = #comp > 1
                    for _, m in ipairs(comp) do
                        if not inGoal[m] then whole = false end
                    end
                    if whole and isClique(comp) then
                        slots[#slots + 1] = comp
                        for _, m in ipairs(comp) do done[m] = true end
                    else
                        slots[#slots + 1] = id
                        done[id] = true
                    end
                end
            end
        end
        local ex
        for _, s in ipairs(slots) do
            if type(s) == "number" and partners[s] then
                ex = ex or {}
                ex[s] = sortedKeys(partners[s])
            end
            for _, m in ipairs(type(s) == "table" and s or { s }) do
                if slotOf[m] then fail("quest %d is in two slots", m) end
                slotOf[m] = s
            end
        end
        local lo, hi = math.huge, 0
        for _, id in ipairs(g.counted) do
            lo = math.min(lo, eff(id))
            hi = math.max(hi, eff(id))
        end
        local first = math.huge
        for _, id in ipairs(g.counted) do first = math.min(first, id) end
        local goal = { a = g.a, lo = lo, hi = hi, ex = ex, order = g.order }
        sort(g.opt)
        goal.opt = #g.opt > 0 and g.opt or nil
        if g.curated then
            local c = g.curated
            goal.id = "n:" .. c.key
            goal.q = slots
            goal.name, goal.note, goal.src, goal.v = c.name, c.note, c.src, c.v
            goal.after, goal.cnt, goal.hint, goal.startObj = c.after, c.cnt, c.hint, c.startObj
        else
            g.slots = slots
            goal.raw = g
            if g.a == "dungeon" then
                goal.id = "d" .. g.area
            else
                local letter = g.a == "story" and (g.kind == "chain" and "s" or "e") or (g.kind == "chain" and "c" or "k")
                goal.id = letter .. first
                -- home zone: the zone of most counted quests (tie: the zone of the lowest-level quest)
                local byLevel = {}
                for i, id in ipairs(g.counted) do byLevel[i] = id end
                sort(byLevel, function(x, y)
                    if eff(x) ~= eff(y) then return eff(x) < eff(y) end
                    return x < y
                end)
                local count, best = {}, nil
                for _, id in ipairs(byLevel) do
                    local z = zoneOf[id]
                    count[z] = (count[z] or 0) + 1
                end
                for _, id in ipairs(byLevel) do
                    local z = zoneOf[id]
                    if not best or count[z] > count[best] then best = z end
                end
                goal.z = best
            end
        end
        goals[#goals + 1] = goal
    end
    -- topological order (generated goals; curated goals keep their order)
    for _, goal in ipairs(goals) do
        if goal.raw then
            local order = topoOrder(goal.raw.slots, slotOf, preds, eff)
            if not order then fail("goal %s: cycle in pa / py / next", goal.id) end
            goal.q = order or goal.raw.slots
        end
    end

    -- 5. dungeon goals: entrances, level band, preparation chains
    local derived = {}
    for _, goal in ipairs(goals) do
        local g = goal.raw
        if g and g.a == "dungeon" then
            local area, d, info = g.area, curated.dungeons[g.area], db.dungeons[g.area]
            goal.d, goal.en = area, info.name
            goal.at = {}
            for i, e in ipairs(info.entrances) do goal.at[i] = { e[1], e[2], e[3] } end
            if d.xp then
                local lv = db.xp.dungeons[d.xp].levels
                goal.lo, goal.hi, goal.lv = lv[1], lv[2], "db"
            elseif d.lo then
                goal.lo, goal.hi, goal.lv = d.lo, d.hi, "src"
            else
                local lo = math.huge
                for _, id in ipairs(g.counted) do lo = math.min(lo, math.max(db.quests[id].reqLevel or 1, 1)) end
                goal.lo, goal.lv = lo, "derived"
                derived[#derived + 1] = format("dungeon %s %s: derived band %d-%d", goal.id, info.name, goal.lo, goal.hi)
            end
            goal.after = d.after
            goal.src, goal.v = d.src, d.v
            -- ancestors over pa / py / next outside the goal that another goal owns
            local seen, prep, stack = {}, {}, {}
            for _, id in ipairs(g.counted) do stack[#stack + 1] = id end
            while #stack > 0 do
                local x = table.remove(stack)
                for _, p in ipairs(preds[x] or {}) do
                    if not seen[p] and goalOf[p] ~= g then
                        seen[p] = true
                        if goalOf[p] then prep[#prep + 1] = p end
                        stack[#stack + 1] = p
                    end
                end
            end
            sort(prep, function(x, y)
                if eff(x) ~= eff(y) then return eff(x) < eff(y) end
                return x < y
            end)
            goal.prep = #prep > 0 and prep or nil
        end
    end

    -- 6. checks of the result
    local titles = curated.titles or {}
    local byId = {}
    for _, goal in ipairs(goals) do
        if byId[goal.id] then fail("goal id %s twice", goal.id) end
        byId[goal.id] = goal
        if goal.lo > goal.hi then fail("goal %s: lo %d > hi %d", goal.id, goal.lo, goal.hi) end
        if titles[goal.id] then goal.name = titles[goal.id] end
        local member = {}
        for _, s in ipairs(goal.q) do
            for _, m in ipairs(type(s) == "table" and s or { s }) do member[m] = true end
        end
        for _, field in ipairs({ "after", "cnt", "hint" }) do
            for _, k in ipairs(sortedKeys(goal[field] or {})) do
                if not member[k] or (field == "after" and not member[goal.after[k]]) then
                    fail("goal %s: %s[%d] names a quest outside the goal's slots", goal.id, field, k)
                end
            end
        end
        if goal.a == "novelty" and not (goal.src and goal.v ~= nil) then fail("goal %s: src / v missing", goal.id) end
    end
    for _, id in ipairs(sortedKeys(titles)) do
        if not byId[id] then fail("titles[%s]: no such goal", id) end
    end
    for _, id in ipairs(sortedKeys(fileIds)) do
        if (goalOf[id] ~= nil) == (excluded[id] ~= nil) then fail("quest %d: not exactly one disposition", id) end
    end
    if #errs > 0 then error(concat(errs, "\n"), 0) end

    sort(goals, function(x, y)
        local rx, ry = ASPECT_RANK[x.a], ASPECT_RANK[y.a]
        if rx ~= ry then return rx < ry end
        if x.order or y.order then return (x.order or 0) < (y.order or 0) end
        if x.lo ~= y.lo then return x.lo < y.lo end
        return x.id < y.id
    end)
    for _, goal in ipairs(goals) do
        goal.raw, goal.order = nil, nil
    end

    -- notes
    local notes = {}
    local perAspect, quests = {}, {}
    for _, goal in ipairs(goals) do
        perAspect[goal.a] = (perAspect[goal.a] or 0) + 1
    end
    for id, g in pairs(goalOf) do
        local k = g.a .. (slotOf[id] and "" or " opt")
        quests[k] = (quests[k] or 0) + 1
    end
    local parts = {}
    for _, a in ipairs(ASPECTS) do
        parts[#parts + 1] = format("%s %d (%d quests + %d opt)", a, perAspect[a] or 0, quests[a] or 0, quests[a .. " opt"] or 0)
    end
    notes[#notes + 1] = format("goals: %d: %s", #goals, concat(parts, ", "))
    local reasons = {}
    for _, why in pairs(excluded) do reasons[why] = (reasons[why] or 0) + 1 end
    parts = {}
    for _, why in ipairs(sortedKeys(reasons)) do parts[#parts + 1] = why .. " " .. reasons[why] end
    notes[#notes + 1] = "excluded: " .. concat(parts, ", ")
    parts = {}
    for _, why in ipairs(sortedKeys(optCount)) do parts[#parts + 1] = why .. " " .. optCount[why] end
    notes[#notes + 1] = "opt: " .. concat(parts, ", ")
    for _, line in ipairs(derived) do notes[#notes + 1] = line end
    -- index-only class quests per class: the class aspect cannot see them (no NPCs, no chains)
    local gap = {}
    for _, id in ipairs(sortedKeys(fileIds)) do
        if not db.quests[id] then
            local b = db.questIndex[id]
            local mask, zone = b[5] or 0, b[6] or 0
            for class, bit in pairs(db.enums.classes) do
                if DB.HasBit(mask, bit) or classOfSort[zone] == class then
                    gap[class] = (gap[class] or 0) + 1
                end
            end
        end
    end
    parts = {}
    for _, class in ipairs(sortedKeys(gap)) do parts[#parts + 1] = class .. " " .. gap[class] end
    notes[#notes + 1] = "index-only class quests (not in the class aspect): " .. concat(parts, ", ")
    return goals, notes, excluded
end

--- The `goals = { ... }` block of the file, one goal per line (key order fixed). @return array of lines
function Goals.Lines(goals)
    local function list(t)
        local out = {}
        for i, v in ipairs(t) do
            out[i] = type(v) == "table" and list(v) or tostring(v)
        end
        return "{ " .. concat(out, ", ") .. " }"
    end
    local function map(t, value)
        local out = {}
        for _, k in ipairs(sortedKeys(t)) do out[#out + 1] = format("[%d] = %s", k, value(t[k])) end
        return "{ " .. concat(out, ", ") .. " }"
    end
    local function text(t) return format("{ en = %s, ru = %s }", luaString(t.en), luaString(t.ru)) end
    local lines = { "    goals = {" }
    for _, g in ipairs(goals) do
        local f = { "id = " .. luaString(g.id), "a = " .. luaString(g.a) }
        if g.z then f[#f + 1] = "z = " .. g.z end
        f[#f + 1] = "lo = " .. g.lo
        f[#f + 1] = "hi = " .. g.hi
        f[#f + 1] = "q = " .. list(g.q)
        if g.opt then f[#f + 1] = "opt = " .. list(g.opt) end
        if g.ex then f[#f + 1] = "ex = " .. map(g.ex, list) end
        if g.d then
            f[#f + 1] = "d = " .. g.d
            f[#f + 1] = "en = " .. luaString(g.en)
            f[#f + 1] = "at = " .. list(g.at)
            f[#f + 1] = "lv = " .. luaString(g.lv)
        end
        if g.prep then f[#f + 1] = "prep = " .. list(g.prep) end
        if g.name then f[#f + 1] = "name = " .. text(g.name) end
        if g.note then f[#f + 1] = "note = " .. text(g.note) end
        if g.src then f[#f + 1] = "src = " .. luaString(g.src) end
        if g.v ~= nil then f[#f + 1] = "v = " .. tostring(g.v) end
        if g.after then f[#f + 1] = "after = " .. map(g.after, tostring) end
        if g.cnt then f[#f + 1] = "cnt = " .. map(g.cnt, tostring) end
        if g.hint then f[#f + 1] = "hint = " .. map(g.hint, list) end
        if g.startObj then f[#f + 1] = "startObj = true" end
        lines[#lines + 1] = "        { " .. concat(f, ", ") .. " },"
    end
    lines[#lines + 1] = "    },"
    return lines
end

return Goals
