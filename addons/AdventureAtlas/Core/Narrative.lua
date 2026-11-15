-- AdventureAtlas / Core / Narrative.lua
--
-- Narrative mode: instead of a speed-leveling route, flexible goals (story chains and errands, dungeons with
-- their quests, class quests, Forever novelties) with progress bars per aspect, the player's check boxes and a
-- "where now" suggestion. The goals come with the knowledge base data (Core/Knowledge.lua, data.goals); all
-- progress is derived from the game state (through Compat), so switching modes is always safe. In narrative
-- mode the engine has no route (Engine:SelectRoute): no route state is written and the automation rests.
--
-- Saved per character: cdb.mode = "speedrun" | "narrative" (Narrative:SetMode fires MODE_CHANGED) and
-- cdb.marks[questID] = "done" | "skip" (goal check boxes; keyed by quest id, so a regeneration that regroups
-- the goals keeps them). Follow (the arrow moves on with the suggestion) is session state only.
--
-- Shapes (the atlas and the step frame code against them):
--   res = Narrative:Get() = Narrative.Evaluate(...) = {
--       goal   = { [goal.id] = gs },
--       aspect = { [aspect] = { done, open, missed } },  -- bar = done / (done + open); missed counts only the
--                                                        --   goals the player has started (done > 0 or active > 0)
--       zone   = { story = { [z] = { done, open, lo, hi } }, class = { ... } },  -- goals with a zone, state ~= "none"
--       q      = { [questID] = { mine (for this character), done, lost (can no longer be done), avail (can be
--                  taken now), gray (by level), inLog, complete } },  -- every quest the evaluation looked at
--   }
--   gs = { done (counted slots done + optional quests done), open, missed, skip, active (open slots with a quest
--          in the log), later (the lowest level above the player's at which a quest of an open slot can be
--          suggested: its required level, its level - RED, a dungeon's lo; or nil),
--          slot = { [i] = status of goal.q[i]: "done" | "skip" | "out" | "missed" | "open" },
--          state = "none" (nothing for this character: hidden) | "skip" | "done" | "active" | "open" (something
--                  can be taken now) | "later" | "missed" (shown as "passed by" when done == 0) }
--   candidate = { goal, q (questID), kind = "turnin" | "take" | "enter",
--          map, x, y (uiMapID + percent; nil = no known place), place (NPC / object name; nil at an entrance),
--          yards (nil = another continent / unknown), bucket (1: <= NEAR1 yd, 2: <= NEAR2 yd, 3: same continent,
--          4: another continent or no place: text only), far (known to be on another continent; false when the
--          player's position is unknown, e.g. inside an instance), prio (1 turn-in, 2 chain, 3 dungeon / lead-in, 4 other),
--          reason = nil | "chain" | "prep" | "hint", dungeon (the dungeon goal a lead-in quest leads to, or nil),
--          graySoon (bool), eff (quest level) }
--   Narrative:Where() = { main = candidate | nil, along = { candidate, ... } (the best of each other aspect
--          within NEAR2 yards; no quest twice), wait = level | nil (no candidate: the next level with something
--          to take), inLog, ready (goal quests in the log, of them complete) }
-- Load adds a run-time field to the goal records: goal.new = true when a quest of the goal is new in Forever.

local _, ns = ...
-- luacheck: ignore 212/self

local type, pairs, ipairs, tostring = type, pairs, ipairs, tostring
local min, max, floor = math.min, math.max, math.floor
local sort, concat, format = table.sort, table.concat, string.format

local L = ns.L

local Narrative = {
    goals = nil,      -- validated data.goals (Load)
    byId = nil,       -- [goal.id] = goal
    prepOf = nil,     -- [questID] = { dungeon goals the quest leads to (goal.prep) }
    goalOf = nil,     -- [questID] = goal (counted or optional quest of it)
    res = nil, state = nil, where = nil,
    dirty = true, whereDirty = true, pending = false, ticker = nil,
    bestOf = {},      -- last Where: [goal.id] = best candidate of the goal
    candOf = {},      -- last Where: [questID] = best candidate of the quest
    following = false, followQ = nil, -- follow: the arrow moves on with the suggestion; quest led to
    activeRef = nil,  -- ref of the waypoint we set last
    reached = nil,    -- ref of the waypoint the player arrived at (no re-lead to it)
    selfSet = false,  -- we are changing the waypoint ourselves
}
ns.Narrative = Narrative

Narrative.ASPECTS = { "story", "dungeon", "class", "novelty" }

local RED = 3          -- take quests up to level L + RED
local NEAR1 = 400      -- yards: bucket 1
local NEAR2 = 1500     -- yards: bucket 2 (and "along the way")
local PREP_LEAD = 2    -- lead-in quests of a dungeon count as such from its lo - PREP_LEAD
local WALK = 5         -- prerequisite walk: links followed at most
local ALONG = 3        -- "along the way" suggestions at most
local TICK = 10        -- seconds: "where now" re-checked while narrative mode is on
local DEBOUNCE = 0.5   -- seconds: changes coalesced into one recompute
local MAX_DEPTH = 64   -- recursion guard of the chain evaluation

local REF = "nar:"
local EMPTY = {}
local ASPECT = {}
for _, a in ipairs(Narrative.ASPECTS) do ASPECT[a] = true end

-- Members of a counted slot (a quest id, or an exclusive clique) as an array.
local function members(slot)
    if type(slot) == "table" then return slot end
    return { slot }
end

-- Is quest q in the list (nil = empty)?
local function contains(list, q)
    for _, v in ipairs(list or EMPTY) do
        if v == q then return true end
    end
    return false
end

-- Effective level of a quest record: its level, else (none / scaling) its required level.
local function eff(rec)
    if not rec then return 0 end
    if (rec.l or 0) > 0 then return rec.l end
    return rec.r or 1
end

-- Is the waypoint ref one of ours?
local function isOurs(ref)
    return type(ref) == "string" and ref:sub(1, #REF) == REF
end

---------------------------------------------------------------------------
-- evaluation (pure)
---------------------------------------------------------------------------

-- Status of one counted slot (rules in order: done (turned in), out, done (marked), skip (marked), missed,
-- open). Out comes before the marks: a mark never brings a slot this character cannot do into the bars.
local function slotStatus(list, info, marks)
    local live, grayOnly = false, true
    for _, m in ipairs(list) do
        local r = info(m)
        if r.done then return "done" end
        if r.mine and not r.lost then
            live = true
            if not r.gray or r.inLog then grayOnly = false end
        end
    end
    if not live then return "out" end
    local skip = false
    for _, m in ipairs(list) do
        if marks[m] == "done" then return "done" end
        if marks[m] == "skip" then skip = true end
    end
    if skip then return "skip" end
    if grayOnly then return "missed" end
    return "open"
end

--- Evaluate the goals against a game state; pure (no game calls, no module state), so specs and the
-- offline play-through call it directly. quests = the knowledge data's quests;
-- st = { level, range (Compat.TrivialRange), isFor = fn(rec) -> bool, done = fn(questID) -> bool,
--        log = { [questID] = complete }, marks = { [questID] = "done" | "skip" } }. @return res (header)
function Narrative.Evaluate(goals, quests, st)
    local level, range = st.level, st.range
    local log, marks, done = st.log or EMPTY, st.marks or EMPTY, st.done
    local isLevelGray = ns.Compat.IsLevelGray

    -- exclusive partners: the listed ones of non-clique quests and the other members of a clique (a quest
    -- whose partner is done can no longer be done, nor can what needs it)
    local exOf = {}
    local function addEx(a, b)
        local t = exOf[a]
        if not t then t = {}; exOf[a] = t end
        t[#t + 1] = b
    end
    for _, g in ipairs(goals) do
        for _, slot in ipairs(g.q) do
            if type(slot) == "table" then
                for _, a in ipairs(slot) do
                    for _, b in ipairs(slot) do
                        if a ~= b then addEx(a, b) end
                    end
                end
            end
        end
        for q, list in pairs(g.ex or EMPTY) do
            for _, b in ipairs(list) do addEx(q, b) end
        end
    end

    local Q = {}
    local function info(id, depth)
        local r = Q[id]
        if r then return r end
        local c = log[id]
        r = { done = done(id) and true or false, inLog = c ~= nil, complete = c == true,
              mine = false, lost = false, avail = false, gray = false }
        Q[id] = r -- before the recursion: a cycle sees "not lost"
        local rec = quests[id]
        if not rec then
            r.lost = not r.done
            return r
        end
        r.mine = st.isFor(rec) and true or false
        r.gray = isLevelGray(rec.l or 0, level, range)
        depth = depth or 0
        if depth > MAX_DEPTH then return r end
        local lost, paDone, pyDone, pyLive = false, true, rec.py == nil or #rec.py == 0, false
        for _, p in ipairs(exOf[id] or EMPTY) do
            if done(p) then lost = true end
        end
        for _, p in ipairs(rec.pa or EMPTY) do
            local pi = info(p, depth + 1)
            if not pi.done then
                paDone = false
                if not pi.mine or pi.lost then lost = true end
            end
        end
        for _, p in ipairs(rec.py or EMPTY) do
            local pi = info(p, depth + 1)
            if pi.done then pyDone = true end
            if pi.done or (pi.mine and not pi.lost) then pyLive = true end
        end
        if not pyDone and not pyLive then lost = true end
        r.lost = lost and not r.done
        r.avail = r.mine and not r.lost and not r.done and not r.inLog and (rec.r or 1) <= level
            and paDone and pyDone
        return r
    end

    local res = { goal = {}, aspect = {}, zone = { story = {}, class = {} }, q = Q }
    for _, a in ipairs(Narrative.ASPECTS) do res.aspect[a] = { done = 0, open = 0, missed = 0 } end
    for _, g in ipairs(goals) do
        local gs = { done = 0, open = 0, missed = 0, skip = 0, active = 0, slot = {} }
        local canTake = false
        for i, slot in ipairs(g.q) do
            local list = members(slot)
            local status = slotStatus(list, info, marks)
            gs.slot[i] = status
            if status ~= "out" then gs[status] = gs[status] + 1 end
            if status == "open" then
                local active = false
                for _, m in ipairs(list) do
                    local r = info(m)
                    if r.mine and not r.lost then
                        if r.inLog then active = true end
                        if r.avail then canTake = true end
                        local rec = quests[m]
                        local need = max(rec.r or 1, eff(rec) - RED)
                        if g.a == "dungeon" then need = max(need, g.lo) end
                        if need > level and (gs.later == nil or need < gs.later) then gs.later = need end
                    end
                end
                if active then gs.active = gs.active + 1 end
            end
        end
        for _, q in ipairs(g.opt or EMPTY) do
            if info(q).done then gs.done = gs.done + 1 end
        end
        if gs.done + gs.open + gs.missed + gs.skip == 0 then gs.state = "none"
        elseif gs.open == 0 and gs.missed == 0 then gs.state = gs.done > 0 and "done" or "skip"
        elseif gs.active > 0 then gs.state = "active"
        elseif canTake then gs.state = "open"
        elseif gs.open > 0 then gs.state = "later"
        else gs.state = "missed" end
        res.goal[g.id] = gs

        local agg = res.aspect[g.a]
        if agg then
            agg.done, agg.open = agg.done + gs.done, agg.open + gs.open
            if gs.done > 0 or gs.active > 0 then agg.missed = agg.missed + gs.missed end
        end
        local zones = res.zone[g.a]
        if zones and g.z and gs.state ~= "none" then
            local s = zones[g.z]
            if not s then
                s = { done = 0, open = 0, lo = g.lo, hi = g.hi }
                zones[g.z] = s
            end
            s.done, s.open = s.done + gs.done, s.open + gs.open
            s.lo, s.hi = min(s.lo, g.lo), max(s.hi, g.hi)
        end
    end
    return res
end

---------------------------------------------------------------------------
-- game state, data
---------------------------------------------------------------------------

local isForCache = {} -- [quest record] = Knowledge:IsFor (race / class / faction do not change in a session)

-- The game state Evaluate needs, read through Compat.
local function gameState()
    local C = ns.Compat
    local facts = C.PlayerFacts()
    local log = {}
    for _, e in ipairs(C.GetQuestLogQuests()) do log[e.questID] = e.isComplete end
    local known = facts.race ~= nil and facts.class ~= nil
    return {
        level = facts.level, range = C.TrivialRange(facts.level), log = log, marks = ns.cdb.marks,
        done = C.IsQuestTurnedIn,
        isFor = function(rec)
            local v = isForCache[rec]
            if v == nil then
                v = ns.Knowledge:IsFor(rec, facts)
                if known then isForCache[rec] = v end
            end
            return v
        end,
    }
end

--- Mode of this character: "speedrun" | "narrative".
function Narrative:GetMode()
    return ns.IsNarrative() and "narrative" or "speedrun"
end

--- Load the knowledge base and index its goals (once; malformed goals are dropped with one chat line).
-- @return true, or false + the reason of Knowledge:Load
function Narrative:Load()
    if self.goals then return true end
    local ok, reason = ns.Knowledge:Load()
    if not ok then return false, reason end
    local data = ns.Knowledge.data
    local goals, byId, prepOf, goalOf = {}, {}, {}, {}
    local bad, first = 0, nil
    for i, g in ipairs(type(data.goals) == "table" and data.goals or EMPTY) do
        if type(g) == "table" and type(g.id) == "string" and not byId[g.id] and ASPECT[g.a]
            and type(g.q) == "table" and type(g.lo) == "number" and type(g.hi) == "number" then
            goals[#goals + 1] = g
            byId[g.id] = g
        else
            bad = bad + 1
            first = first or (type(g) == "table" and tostring(g.id)) or ("#" .. i)
        end
    end
    for _, g in ipairs(goals) do
        local new = false
        local function own(q)
            if not goalOf[q] then goalOf[q] = g end
            local rec = data.quests[q]
            if rec and rec.new then new = true end
        end
        for _, slot in ipairs(g.q) do
            for _, q in ipairs(members(slot)) do own(q) end
        end
        for _, q in ipairs(g.opt or EMPTY) do own(q) end
        g.new = new or nil
        if g.a == "dungeon" then
            for _, q in ipairs(g.prep or EMPTY) do
                local t = prepOf[q] or {}
                t[#t + 1] = g
                prepOf[q] = t
            end
        end
    end
    if bad > 0 then ns.Print(L.MSG_NAR_BAD_GOALS_FMT, bad, first) end
    self.goals, self.byId, self.prepOf, self.goalOf = goals, byId, prepOf, goalOf
    self.dirty, self.whereDirty = true, true
    return true
end

--- The evaluation of the goals (cached; recomputed after Invalidate). nil before Load.
function Narrative:Get()
    if not self.goals then return nil end
    if self.dirty or not self.res then
        self.dirty = false
        self.state = gameState()
        self.res = Narrative.Evaluate(self.goals, ns.Knowledge.data.quests, self.state)
        self.whereDirty = true
    end
    return self.res
end

---------------------------------------------------------------------------
-- where now
---------------------------------------------------------------------------

-- All candidates of the evaluation, sorted (bucket, prio, graySoon, level, yards, quest id).
local function candidates(self, res, st)
    local K, C = ns.Knowledge, ns.Compat
    local quests = K.data.quests
    local level, range = st.level, st.range
    local here = C.GetPlayerMapPosition()
    local cont = C.PlayerWorldPos() -- nil inside an instance: then no target is called "another continent"
    local dist = {}

    local function yardsTo(map, x, y)
        local key = map .. ":" .. x .. ":" .. y
        local d = dist[key]
        if d == nil then
            d = C.DistanceTo(map, x, y) or false
            dist[key] = d
        end
        return d or nil
    end
    local function closer(best, yards)
        return not best or (yards ~= nil and (best.yards == nil or yards < best.yards))
    end
    -- the nearest positioned NPC / object of a list (kind "n" / "o")
    local function nearest(best, kind, ids)
        for _, id in ipairs(ids or EMPTY) do
            local name, map, x, y = K:Entity(kind, id)
            if map then
                local yards = yardsTo(map, x, y)
                if closer(best, yards) then best = { place = name, map = map, x = x, y = y, yards = yards } end
            end
        end
        return best
    end
    -- the nearest starter (goal.startObj: objects, NPCs only when no start object has a place)
    local function starter(g, rec)
        local s = rec.s or EMPTY
        local at = nearest(nil, "o", s.o)
        if not at or not g.startObj then at = nearest(at, "n", s.n) end
        return at
    end
    local function ender(rec)
        local e = rec.e or EMPTY
        return nearest(nearest(nil, "n", e.n), "o", e.o)
    end
    local function entrance(g)
        local best
        for _, e in ipairs(g.at or EMPTY) do
            local yards = yardsTo(e[1], e[2], e[3])
            if closer(best, yards) then best = { map = e[1], x = e[2], y = e[3], yards = yards } end
        end
        return best
    end

    local list = {}
    local function add(g, q, kind, at, prio, reason)
        local c = { goal = g, q = q, kind = kind, prio = prio, reason = reason, bucket = 4 }
        if at then c.map, c.x, c.y, c.yards, c.place = at.map, at.x, at.y, at.yards, at.place end
        if c.map and c.yards then
            c.bucket = (c.yards <= NEAR1 and 1) or (c.yards <= NEAR2 and 2) or 3
        elseif c.map then
            local tc = C.WorldPosFromMap(c.map, c.x, c.y)
            c.far = tc ~= nil and cont ~= nil and tc ~= cont
        end
        local h = g.hint and g.hint[q]
        if h and c.yards and here == h[1] and level >= h[2] then -- this continent only
            c.bucket, c.reason = min(c.bucket, 2), "hint"
        end
        local rec = quests[q]
        c.eff = eff(rec)
        c.graySoon = rec ~= nil and C.IsLevelGray(rec.l or 0, level + 1, range) -- gray at the next level
        for _, d in ipairs(self.prepOf[q] or EMPTY) do
            if level >= d.lo - PREP_LEAD and level <= d.hi then
                c.dungeon = d
                if c.prio > 3 then c.prio, c.reason = 3, c.reason or "prep" end
                break
            end
        end
        list[#list + 1] = c
    end

    local function anyDone(ids)
        for _, p in ipairs(ids or EMPTY) do
            local r = res.q[p]
            if r and r.done then return true end
        end
        return false
    end
    -- the soft order of goal g waits while the slot of its predecessor p is open (done, marked, gray or out
    -- slots let the next step through); a predecessor outside the slots has to be done
    local function waiting(g, gs, p)
        for i, slot in ipairs(g.q) do
            if contains(members(slot), p) then return gs.slot[i] == "open" end
        end
        return not (res.q[p] or EMPTY).done
    end
    -- prerequisite walk: the first prerequisite on the way to quest `id` that can be taken now
    local function walk(id)
        local cur = id
        for _ = 1, WALK do
            local rec = quests[cur]
            local nextId
            for _, p in ipairs(rec.pa or EMPTY) do
                local r = res.q[p]
                if r and not r.done and r.mine and not r.lost then nextId = p; break end
            end
            if not nextId and rec.py and #rec.py > 0 and not anyDone(rec.py) then
                local low
                for _, p in ipairs(rec.py) do
                    local r = res.q[p]
                    if r and r.mine and not r.lost and quests[p] and (not low or eff(quests[p]) < low) then
                        nextId, low = p, eff(quests[p])
                    end
                end
            end
            if not nextId then return nil end
            local r = res.q[nextId]
            if r.avail then return nextId end
            if r.inLog or r.done or not quests[nextId] then return nil end
            cur = nextId
        end
        return nil
    end

    for _, g in ipairs(self.goals) do
        local gs = res.goal[g.id]
        if gs.state ~= "none" and gs.state ~= "skip" and gs.state ~= "done" then
            local dungeon = g.a == "dungeon"
            local band = not dungeon or (level >= g.lo and level <= g.hi)
            local started = gs.done > 0 or gs.active > 0
            -- cnt counts the done slots that carry no threshold themselves (the books, not the rewards)
            local doneSlots, entered = 0, false
            for i, slot in ipairs(g.q) do
                if gs.slot[i] == "done" and not (g.cnt and g.cnt[members(slot)[1]]) then
                    doneSlots = doneSlots + 1
                end
            end
            for i, slot in ipairs(g.q) do
                if gs.slot[i] == "open" then
                    for _, m in ipairs(members(slot)) do
                        local r, rec = res.q[m], quests[m]
                        local gated = (g.after and g.after[m] and waiting(g, gs, g.after[m]))
                            or (g.cnt and g.cnt[m] and doneSlots < g.cnt[m])
                        if rec and r.mine and not r.lost then
                            if r.inLog then
                                if r.complete then
                                    add(g, m, "turnin", ender(rec), 1)
                                elseif dungeon and band and not entered then
                                    entered = true
                                    add(g, m, "enter", entrance(g), 3)
                                end
                            elseif band and not gated and eff(rec) <= level + RED then
                                if r.avail and not r.gray then
                                    local at = starter(g, rec)
                                    if not at and dungeon then
                                        add(g, m, "enter", entrance(g), 3) -- the giver is inside
                                    elseif started or anyDone(rec.pa) or anyDone(rec.py) then
                                        add(g, m, "take", at, 2, "chain")
                                    else
                                        add(g, m, "take", at, dungeon and 3 or 4)
                                    end
                                elseif not r.avail and not r.done and (rec.r or 1) <= level then
                                    -- a counted quest of this goal that can be taken is suggested for itself
                                    -- (gray ones are not, nor are optional ones: the walk leads to them)
                                    local p = walk(m)
                                    if p and (self.goalOf[p] ~= g or res.q[p].gray or contains(g.opt, p)) then
                                        add(g, p, "take", starter(g, quests[p]), 2, "chain")
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        for _, q in ipairs(g.opt or EMPTY) do
            local r = res.q[q]
            if r and r.inLog and r.complete and quests[q] then add(g, q, "turnin", ender(quests[q]), 1) end
        end
    end

    sort(list, function(a, b)
        if a.bucket ~= b.bucket then return a.bucket < b.bucket end
        if a.prio ~= b.prio then return a.prio < b.prio end
        if a.graySoon ~= b.graySoon then return a.graySoon end
        if a.eff ~= b.eff then return a.eff < b.eff end
        if a.yards ~= b.yards then
            if a.yards == nil or b.yards == nil then return b.yards == nil end
            return a.yards < b.yards
        end
        if a.q ~= b.q then return a.q < b.q end
        return a.goal.id < b.goal.id
    end)
    return list
end

-- Leave the waypoint to us for the duration of fn (our own WAYPOINT_CUSTOM is no player action).
local function setWaypoint(self, fn, ...)
    self.selfSet = true
    ns.SafeCall(fn, ns.Waypoint, ...)
    self.selfSet = false
end

-- Can the arrow lead to the candidate (a known place on this continent)?
local function leadable(c)
    return c ~= nil and c.map ~= nil and c.bucket < 4
end

-- Follow: keep the followed quest while it is still a candidate (sticky), else move on to the main
-- suggestion; never back to the place the player has just reached.
local function applyFollow(self)
    if not self.following then return end
    local c = self.followQ and self.candOf[self.followQ]
    if not leadable(c) then
        c = self.where.main
        if not (leadable(c) and c.bucket <= 3) then c = nil end
    end
    local cur = ns.Waypoint:GetCustom()
    if not c then
        if cur and isOurs(cur.ref) then
            setWaypoint(self, ns.Waypoint.ClearCustom)
            self.activeRef = nil
        end
        return
    end
    if REF .. c.q == self.reached then return end
    local at = cur and cur.ref == REF .. c.q and cur.at
    if not (at and at.map == c.map and at.x == c.x and at.y == c.y) then self:Lead(c, true) end
end

--- "Where now": the main suggestion, the detours of the other aspects, the level to wait for and the
-- quest log counts (cached; shape in the header). nil before Load.
function Narrative:Where()
    local res = self:Get()
    if not res then return nil end
    if self.whereDirty or not self.where then
        self.whereDirty = false
        local bestOf, candOf, best = {}, {}, {}
        for _, c in ipairs(candidates(self, res, self.state)) do
            if not bestOf[c.goal.id] then
                bestOf[c.goal.id] = c
                best[#best + 1] = c
            end
            if not candOf[c.q] then candOf[c.q] = c end
        end
        local main, along, wait = best[1], {}, nil
        if main then
            local shown = { [main.q] = true } -- a quest is shown once (a prerequisite walk can offer it twice)
            for _, a in ipairs(Narrative.ASPECTS) do
                if a ~= main.goal.a and #along < ALONG then
                    for _, c in ipairs(best) do
                        if c.goal.a == a and not shown[c.q] then
                            shown[c.q] = true
                            if c.bucket <= 2 then along[#along + 1] = c end
                            break
                        end
                    end
                end
            end
        else
            for _, g in ipairs(self.goals) do
                local gs = res.goal[g.id]
                if gs.later and gs.state ~= "none" and gs.state ~= "skip" and (wait == nil or gs.later < wait) then
                    wait = gs.later
                end
            end
        end
        local inLog, ready = 0, 0
        for q, complete in pairs(self.state.log) do
            if self.goalOf[q] then
                inLog = inLog + 1
                if complete then ready = ready + 1 end
            end
        end
        self.bestOf, self.candOf = bestOf, candOf
        self.where = { main = main, along = along, wait = wait, inLog = inLog, ready = ready }
        applyFollow(self)
    end
    return self.where
end

--- Best candidate of one goal (all buckets), or nil.
function Narrative:Best(goal)
    if not self:Where() then return nil end
    return self.bestOf[goal.id]
end

--- Rows of one aspect for the atlas list: { kind = "zone", z, sum = res.zone[aspect][z] } headers (story /
-- class: the player's zone first, then by the lowest goal level) followed by their { kind = "goal", goal, gs }
-- rows (data order). opts = { hideDone (hide done, skipped and missed goals), onlyNew (goals with a quest new
-- in Forever) }. Goals with nothing for this character are never listed.
function Narrative:List(aspect, opts)
    local rows = {}
    local res = self:Get()
    if not res then return rows end
    opts = opts or EMPTY
    local groups, order = {}, {}
    for _, g in ipairs(self.goals) do
        local gs = res.goal[g.id]
        local state = gs.state
        if g.a == aspect and state ~= "none"
            and not (opts.hideDone and (state == "done" or state == "skip" or state == "missed"))
            and not (opts.onlyNew and not g.new) then
            local key = g.z or false
            local grp = groups[key]
            if not grp then
                grp = { z = g.z, lo = g.lo, goals = {} }
                groups[key] = grp
                order[#order + 1] = grp
            end
            grp.goals[#grp.goals + 1] = g
            grp.lo = min(grp.lo, g.lo)
        end
    end
    local here = ns.Compat.GetPlayerMapPosition()
    local zones = ns.Knowledge.data.zones or EMPTY
    local function isHere(grp)
        local z = grp.z and zones[grp.z]
        return z ~= nil and z.map ~= nil and z.map == here
    end
    sort(order, function(a, b)
        local ha, hb = isHere(a), isHere(b)
        if ha ~= hb then return ha end
        if a.lo ~= b.lo then return a.lo < b.lo end
        return (a.z or 0) < (b.z or 0)
    end)
    for _, grp in ipairs(order) do
        if grp.z then rows[#rows + 1] = { kind = "zone", z = grp.z, sum = (res.zone[aspect] or EMPTY)[grp.z] } end
        for _, g in ipairs(grp.goals) do rows[#rows + 1] = { kind = "goal", goal = g, gs = res.goal[g.id] } end
    end
    return rows
end

---------------------------------------------------------------------------
-- check boxes
---------------------------------------------------------------------------

-- Counted slots of a goal the check boxes mark: no quest of them turned in, and not out (lost or not for this
-- character).
local function unfinished(self, goal)
    local gs = self:Get().goal[goal.id]
    local out = {}
    for i, slot in ipairs(goal.q) do
        local list, skip = members(slot), gs.slot[i] == "out"
        for _, m in ipairs(list) do
            if ns.Compat.IsQuestTurnedIn(m) then skip = true; break end
        end
        if not skip then out[#out + 1] = list end
    end
    return out
end

--- Check box state of a goal: "done" | "skip" when every unfinished counted slot carries that mark, else nil.
function Narrative:GoalMark(goal)
    local marks = ns.cdb.marks
    local slots = unfinished(self, goal)
    if #slots == 0 then return nil end
    for _, value in ipairs({ "done", "skip" }) do
        local all = true
        for _, list in ipairs(slots) do
            local has = false
            for _, m in ipairs(list) do
                if marks[m] == value then has = true; break end
            end
            if not has then all = false; break end
        end
        if all then return value end
    end
    return nil
end

--- Mark a goal "done" (did it myself) / "skip" (not interested) / nil (clear): every unfinished counted
-- slot loses the marks of its quests and gets the value on its first quest.
function Narrative:Mark(goal, value)
    if value ~= "done" and value ~= "skip" then value = nil end
    local marks = ns.cdb.marks
    for _, list in ipairs(unfinished(self, goal)) do
        for _, m in ipairs(list) do marks[m] = nil end
        if value then marks[list[1]] = value end
    end
    self:Invalidate()
end

---------------------------------------------------------------------------
-- texts
---------------------------------------------------------------------------

-- Name of whoever starts a quest (the first NPC, else object, else item), or nil.
local function giverName(q)
    local K = ns.Knowledge
    local s = (K:Get(q) or EMPTY).s or EMPTY
    if s.n and s.n[1] then return (K:Entity("n", s.n[1])) end
    if s.o and s.o[1] then return (K:Entity("o", s.o[1])) end
    if s.i and s.i[1] then return K:ItemName(s.i[1]) end
    return nil
end

--- Localized title of a goal: its curated name, the dungeon's name, "<giver>: errands" for errand goals,
-- else the title of its first quest.
function Narrative:Title(goal)
    local name = goal.name
    if type(name) == "table" then
        local t = (ns.locale == "ruRU" and name.ru) or name.en
        if t then return t end
    end
    if goal.d then return ns.Compat.AreaName(goal.d) or goal.en or tostring(goal.d) end
    local first = goal.q[1]
    if type(first) == "table" then first = first[1] end
    if not first then return goal.id end
    local kind = goal.id:sub(1, 1)
    if kind == "e" or kind == "k" then
        local giver = giverName(first)
        if giver then return format(L.NAR_ERRANDS_FMT, giver) end
    end
    return ns.Knowledge:Title(first)
end

--- One localized line for a candidate: what to do, where, how far, and why it comes first (short: what and
-- where only, the waypoint label: the arrow shows the live distance).
function Narrative:Describe(cand, short)
    local place
    if not cand.map then
        place = L.NAR_NO_PLACE
    else
        local zone = ns.Compat.GetMapName(cand.map) or ""
        place = cand.place and format(L.NAR_PLACE_FMT, cand.place, zone) or zone
        if cand.far then place = format(L.NAR_FAR_FMT, place) end
    end
    local text
    if cand.kind == "enter" then
        text = format(L.NAR_ENTER_FMT, self:Title(cand.goal), place)
    else
        text = format(cand.kind == "turnin" and L.NAR_TURNIN_FMT or L.NAR_TAKE_FMT, ns.Knowledge:Title(cand.q), place)
    end
    if short then return text end
    if cand.yards then text = text .. " " .. format(L.NAR_YARDS_FMT, floor(cand.yards + 0.5)) end
    local why
    if cand.reason == "hint" then why = L.NAR_WHY_HINT
    elseif cand.dungeon then why = format(L.NAR_WHY_PREP_FMT, self:Title(cand.dungeon))
    elseif cand.reason == "chain" then why = L.NAR_WHY_CHAIN
    elseif cand.graySoon then why = L.NAR_WHY_GRAYSOON end
    if why then text = text .. " · " .. why end
    return text
end

---------------------------------------------------------------------------
-- arrow
---------------------------------------------------------------------------

--- Lead the arrow to a candidate (follow = move on with the suggestion afterwards).
-- @return false when the place is unknown or on another continent
function Narrative:Lead(cand, follow)
    if not leadable(cand) then return false end
    self.following, self.followQ = follow and true or false, cand.q
    self.activeRef = REF .. cand.q
    setWaypoint(self, ns.Waypoint.SetCustom, cand.map, cand.x, cand.y, self:Describe(cand, true), self.activeRef)
    return true
end

--- Stop following and remove our waypoint (a target of the knowledge base stays).
function Narrative:Stop()
    self.following, self.followQ = false, nil
    local cur = ns.Waypoint:GetCustom()
    if cur and isOurs(cur.ref) then
        setWaypoint(self, ns.Waypoint.ClearCustom)
        self.activeRef = nil
    end
end

--- Does the arrow lead to this candidate?
function Narrative:IsLeading(cand)
    local cur = ns.Waypoint:GetCustom()
    return cur ~= nil and cand ~= nil and cur.ref == REF .. cand.q
end

--- Does the arrow move on with the suggestion?
function Narrative:IsFollowing()
    return self.following
end

---------------------------------------------------------------------------
-- mode, recompute, events
---------------------------------------------------------------------------

-- Recompute "where now" (the evaluation too when dirty) and tell the UI.
local function update()
    local self = Narrative
    if not (ns.IsNarrative() and self.goals) then return end
    self:Where()
    ns:Fire("NARRATIVE_UPDATED")
end

-- What the UI shows of a "where now" result: per row goal, quest, kind, place and rounded yards; the wait level
-- and the log counts.
local function signature(w)
    local t = { tostring(w.wait), w.inLog, w.ready }
    local rows = { w.main } -- no main: no detours either
    for _, c in ipairs(w.along) do rows[#rows + 1] = c end
    for _, c in ipairs(rows) do
        t[#t + 1] = format("%s:%d:%s:%s:%s", c.goal.id, c.q, c.kind, tostring(c.map),
            c.yards and floor(c.yards + 0.5) or "-")
    end
    return concat(t, "|")
end

-- The ticker: re-check "where now", tell the UI only when what it shows changed (standing still costs nothing
-- in the atlas).
local function tick()
    local self = Narrative
    if not (ns.IsNarrative() and self.goals) then return end
    local before = self.where and signature(self.where)
    self.whereDirty = true
    if signature(self:Where()) ~= before then ns:Fire("NARRATIVE_UPDATED") end
end

-- One update DEBOUNCE seconds after the first of a burst of changes.
local function schedule()
    if Narrative.pending then return end
    if C_Timer and C_Timer.After then
        Narrative.pending = true
        C_Timer.After(DEBOUNCE, function()
            Narrative.pending = false
            update()
        end)
    else
        update()
    end
end

--- The game state changed: recompute (coalesced) and fire NARRATIVE_UPDATED.
function Narrative:Invalidate()
    self.dirty, self.whereDirty = true, true
    schedule()
end

-- Narrative mode on: load the goals, re-check "where now" every TICK seconds.
local function activate()
    local self = Narrative
    if not self:Load() then return end -- the atlas shows why
    if not self.ticker and C_Timer and C_Timer.NewTicker then
        self.ticker = C_Timer.NewTicker(TICK, tick)
    end
    self:Invalidate()
end

local function deactivate()
    if Narrative.ticker then
        Narrative.ticker:Cancel()
        Narrative.ticker = nil
    end
end

--- Switch this character's mode ("speedrun" | "narrative"); the engine drops / restores the route on
-- MODE_CHANGED. @return false for an unknown mode
function Narrative:SetMode(mode)
    if mode ~= "speedrun" and mode ~= "narrative" then
        ns.Print(L.MSG_MODE_UNKNOWN_FMT, tostring(mode))
        return false
    end
    if ns.cdb.mode == mode then return true end
    ns.cdb.mode = mode
    self:Stop()
    ns:Fire("MODE_CHANGED", mode)
    if mode == "narrative" then
        ns.Print(L.MSG_MODE_NARRATIVE)
        activate()
    else
        deactivate()
    end
    return true
end

local function onLogin()
    if ns.IsNarrative() then activate() end
end
ns:On("PLAYER_LOGIN", onLogin)
ns:Listen("DB_READY", function()
    if IsLoggedIn and IsLoggedIn() then onLogin() end
end)

-- quest log / level changes: re-evaluate; an accepted or turned-in quest lets the arrow return anywhere
local function onQuestChange(event)
    if not ns.IsNarrative() then return end
    if event == "QUEST_ACCEPTED" or event == "QUEST_TURNED_IN" then Narrative.reached = nil end
    Narrative:Invalidate()
end
for _, event in ipairs({ "QUEST_TURNED_IN", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_LOG_UPDATE", "PLAYER_LEVEL_UP" }) do
    ns:On(event, onQuestChange)
end

-- moving changes only "where now"
local function onMove()
    if not ns.IsNarrative() then return end
    Narrative.whereDirty = true
    schedule()
end
ns:On("ZONE_CHANGED_NEW_AREA", onMove)
ns:On("ZONE_CHANGED", onMove)

-- the player reached our waypoint (cleared by the arrival) or chose another target (knowledge base)
ns:Listen("WAYPOINT_CUSTOM", function(_, custom)
    local self = Narrative
    if self.selfSet then return end
    if custom == nil then
        if self.activeRef then self.reached, self.activeRef = self.activeRef, nil end
    elseif not isOurs(custom.ref) then
        self.following, self.followQ, self.activeRef = false, nil, nil
    end
end)
