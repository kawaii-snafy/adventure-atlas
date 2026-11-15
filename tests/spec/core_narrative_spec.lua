-- Narrative mode (Core/Narrative.lua): the evaluation of the goals (bars, slots, marks), "where now" (buckets,
-- priorities, gates, the prerequisite walk), the mode switch against the route engine and the automation, and
-- follow (the arrow moves on with the suggestion). Goals: tests/fixtures/narrative/data.lua (its header lists
-- the role of each goal); the player is an Orc warrior, level 12, at the Barrens 50, 50.

local H = require("fixtures.core.helpers")

local FIXTURE = "tests/fixtures/narrative/data.lua"
local ORC = { race = "Orc", class = "WARRIOR", level = 12, mapID = 1413, x = 50, y = 50 }

local m, ns

local function N() return ns.Narrative end

-- Every fixture quest with one objective, so a quest in the log is incomplete until CompleteObjectives.
local function defineQuests(mm)
    for id, q in pairs(dofile(FIXTURE).quests) do
        mm:DefineQuest(id, { title = q.n, level = q.l, reqLevel = q.r, objectives = { { text = "done", required = 1 } } })
    end
end

-- The Orc warrior in narrative mode with the fixture goals (a fresh copy: tests may edit the records).
local function boot(player)
    local p = {}
    for k, v in pairs(ORC) do p[k] = v end
    for k, v in pairs(player or {}) do p[k] = v end
    m, ns = H.boot({ fixture = false, quests = false, player = p, setup = defineQuests })
    ns.Knowledge:Add(dofile(FIXTURE))
    N():SetMode("narrative")
    H.settle(m)
end

local function goal(id) return N().byId[id] end
local function best(id) return N():Best(goal(id)) end
local function where() return N():Where() end

-- Evaluate the fixture goals for a state: opts = { level, range, done = { ids }, log, marks, race, class }.
local function eval(opts)
    opts = opts or {}
    local data = ns.Knowledge.data
    local facts = { race = opts.race or "Orc", class = opts.class or "WARRIOR", faction = "Horde" }
    local done = {}
    for _, q in ipairs(opts.done or {}) do done[q] = true end
    local level = opts.level or 12
    return N().Evaluate(N().goals, data.quests, {
        level = level, range = opts.range or ns.Compat.FallbackTrivialRange(level),
        isFor = function(rec) return ns.Knowledge:IsFor(rec, facts) end,
        done = function(q) return done[q] == true end,
        log = opts.log or {}, marks = opts.marks or {},
    })
end

-- Re-evaluate now (the module coalesces changes for DEBOUNCE seconds).
local function changed()
    N():Invalidate()
    H.settle(m)
end

local function inLog(q, complete)
    m:AddQuestToLog(q)
    if complete then m:CompleteObjectives(q) end
end

describe("narrative evaluation", function()
    before_each(function() boot() end)
    after_each(function() m:AssertClean() end)

    it("counts an exclusive clique as one slot", function()
        assert.same({ 0, 3 }, { eval().goal.s1001.done, eval().goal.s1001.open })
        local gs = eval({ done = { 1001, 1002, 1003 } }).goal.s1001
        assert.same({ 3, 0, "done" }, { gs.done, gs.open, gs.state })
    end)

    it("loses a non-clique exclusive and what needs it once a partner is done; 100% stays reachable", function()
        local res = eval({ done = { 1071 } })
        assert.is_true(res.q[1072].lost)
        assert.is_true(res.q[1074].lost)
        assert.is_false(res.q[1073].lost)
        assert.same({ "done", "out", "open", "out" }, res.goal.s1071.slot)
        local gs = eval({ done = { 1071, 1073 } }).goal.s1071
        assert.same({ 2, 0, "done" }, { gs.done, gs.open, gs.state })
    end)

    it("counts an optional quest only once it is done", function()
        assert.same({ 0, 3 }, { eval().goal.s1001.done, eval().goal.s1001.open })
        local gs = eval({ done = { 1005 } }).goal.s1001
        assert.same({ 1, 3 }, { gs.done, gs.open })
    end)

    it("leaves a chain behind a race-locked quest out of the bars", function()
        local res = eval()
        assert.is_true(res.q[1024].lost)
        assert.equal("none", res.goal.s1023.state)
        assert.equal(2, eval({ race = "Tauren" }).goal.s1023.open)
    end)

    it("counts untouched gray quests as missed, in the headline only for started goals", function()
        local res = eval({ level = 30, done = { 1001 } })
        assert.same({ 1, 0, 2, "missed" }, { res.goal.s1001.done, res.goal.s1001.open, res.goal.s1001.missed,
            res.goal.s1001.state })
        assert.equal("missed", res.goal.e1011.state) -- passed by: missed, nothing done
        assert.same({ done = 1, open = 0, missed = 2 }, res.aspect.story)
    end)

    it("applies a mark on any member of a slot", function()
        local gs = eval({ marks = { [1004] = "skip", [1002] = "done" } }).goal.s1001
        assert.same({ "open", "done", "skip" }, gs.slot)
        assert.same({ 1, 1, 1 }, { gs.done, gs.open, gs.skip })
    end)

    it("marks the unfinished slots of a goal done / skipped and clears them", function()
        m:SetCompletedQuests({ 1001 })
        local g = goal("s1001")
        N():Mark(g, "skip")
        assert.same({ [1002] = "skip", [1003] = "skip" }, ns.cdb.marks)
        assert.equal("skip", N():GoalMark(g))
        local gs = N():Get().goal.s1001
        assert.same({ 1, 0, 2, "done" }, { gs.done, gs.open, gs.skip, gs.state })
        N():Mark(g, "done")
        assert.equal("done", N():GoalMark(g))
        assert.same({ 3, 0 }, { N():Get().goal.s1001.done, N():Get().goal.s1001.open })
        N():Mark(g, nil)
        assert.same({}, ns.cdb.marks)
        assert.is_nil(N():GoalMark(g))
    end)

    it("keeps a lost or other-race slot out of the bars whatever its marks", function()
        assert.equal("out", eval({ done = { 1071 }, marks = { [1072] = "done" } }).goal.s1071.slot[2])
        m:SetCompletedQuests({ 1071 })
        changed()
        N():Mark(goal("s1071"), "done")
        assert.same({ [1073] = "done" }, ns.cdb.marks)
        local gs = N():Get().goal.s1071
        assert.same({ "done", "out", "done", "out" }, gs.slot)
        assert.same({ 2, 0 }, { gs.done, gs.open })
    end)

    it("lists by the filters: hide done / skipped goals, only goals new in Forever", function()
        local function ids(aspect, opts)
            local out = {}
            for _, row in ipairs(N():List(aspect, opts)) do
                if row.kind == "goal" then out[#out + 1] = row.goal.id end
            end
            return out
        end
        m:SetCompletedQuests({ 1011, 1012 })
        N():Mark(goal("s1051"), "skip")
        changed()
        assert.same({ "s1061", "s1001", "s1071" }, ids("story", { hideDone = true }))
        assert.same({}, ids("story", { onlyNew = true }))
        assert.same({ "n:test" }, ids("novelty", { onlyNew = true }))
    end)
end)

describe("narrative where now", function()
    after_each(function() m:AssertClean() end)

    it("suggests another continent only when nothing is on this one, as text", function()
        boot({ mapID = 1420, x = 50, y = 50 })
        assert.equal(1051, where().main.q)
        m:SetCompletedQuests({ 1051 })
        changed()
        local main = where().main
        assert.equal(4, main.bucket)
        assert.is_false(N():Lead(main, true))
        assert.is_truthy(N():Describe(main):find("another continent", 1, true))
    end)

    it("puts the nearer bucket before a higher priority", function()
        boot()
        m:SetCompletedQuests({ 1021 })
        inLog(1022, true)
        changed()
        assert.same({ "turnin", 2 }, { best("c1021").kind, best("c1021").bucket })
        assert.same({ 1001, "take", 1 }, { where().main.q, where().main.kind, where().main.bucket })
    end)

    it("puts a turn-in first within its bucket", function()
        boot()
        inLog(1011, true)
        changed()
        assert.same({ 1011, "turnin", 1 }, { where().main.q, where().main.kind, where().main.prio })
    end)

    it("puts a chain before a fresh errand", function()
        boot()
        m:SetCompletedQuests({ 1001 })
        changed()
        assert.same({ 1002, "chain" }, { where().main.q, where().main.reason })
        assert.equal(4, best("e1011").prio)
    end)

    it("leads into a dungeon only in its band with a quest in the log, or to a giver inside", function()
        boot({ level = 14 })
        m:SetCompletedQuests({ 1032 })
        inLog(1031)
        changed()
        assert.is_nil(best("d718"))
        m:SetLevel(16)
        changed()
        local c = best("d718")
        assert.same({ "enter", 1413, 46, 36.5 }, { c.kind, c.map, c.x, c.y })
        boot({ level = 16 })
        m:SetCompletedQuests({ 1012, 1031 })
        changed()
        assert.same({ "enter", 1032 }, { best("d718").kind, best("d718").q })
    end)

    it("walks to an optional prerequisite of an open slot", function()
        boot()
        m:SetCompletedQuests({ 1001 })
        ns.Knowledge:Get(1002).pa = { 1001, 1005 }
        changed()
        assert.same({ 1005, "take", "chain" }, { best("s1001").q, best("s1001").kind, best("s1001").reason })
    end)

    it("walks to a gray prerequisite of an open slot", function()
        boot()
        assert.is_true(N():Get().q[1061].gray)
        assert.same({ 1061, "take", "chain" }, { best("s1061").q, best("s1061").kind, best("s1061").reason })
    end)

    it("lets the soft order through once the predecessor's slot is no longer open (here: gray)", function()
        boot()
        ns.Knowledge:Get(1041).l = 5
        changed()
        assert.equal("missed", N():Get().goal["n:test"].slot[1])
        assert.equal(1042, best("n:test").q)
    end)

    it("counts only the done slots without a threshold of their own toward `cnt`", function()
        boot()
        local g = goal("n:test")
        g.after, g.cnt = nil, { [1042] = 1, [1043] = 2 }
        m:SetCompletedQuests({ 1041 })
        changed()
        assert.equal(1042, best("n:test").q)
        m:SetCompletedQuests({ 1041, 1042 })
        changed()
        assert.is_nil(best("n:test")) -- one book (1041) done: 1043 needs two
    end)

    it("falls back to the NPC giver of a startObj goal when no start object has a place", function()
        boot()
        goal("n:test").startObj = true
        changed()
        assert.same({ 1041, 1411 }, { best("n:test").q, best("n:test").map })
    end)

    it("gates suggestions by `after` and `cnt`", function()
        boot()
        assert.equal(1041, best("n:test").q)
        m:SetCompletedQuests({ 1041 })
        changed()
        assert.equal(1042, best("n:test").q)
        m:SetCompletedQuests({ 1041, 1042 })
        changed()
        assert.equal(1043, best("n:test").q)
    end)

    it("promotes a hinted quest on the hint map from the hint level", function()
        boot({ level = 11 })
        assert.same({ 3, nil }, { best("n:test").bucket, best("n:test").reason })
        m:SetLevel(12)
        changed()
        assert.same({ 2, "hint" }, { best("n:test").bucket, best("n:test").reason })
        ns.Knowledge.data.npcs[108] = { "Bag Maker", 1420, 50, 50 } -- another continent: no promotion
        changed()
        assert.same({ 4, nil }, { best("n:test").bucket, best("n:test").reason })
    end)

    it("breaks ties by quests about to turn gray", function()
        boot()
        local K = ns.Knowledge
        K:Get(1011).l = 7          -- gray at 13
        K:Get(1001).l, K:Get(1001).r = 0, 5 -- no level: never gray, lower effective level
        changed()
        assert.same({ 1011, true }, { where().main.q, where().main.graySoon })
    end)

    it("adds the best detour of each other aspect within NEAR2 yards", function()
        boot()
        local w = where()
        assert.equal("s1001", w.main.goal.id)
        assert.same({ "c1021", "n:test" }, { w.along[1].goal.id, w.along[2].goal.id })
        assert.equal(2, #w.along)
        m:SetLevel(11)
        changed()
        assert.same({ "c1021" }, { where().along[1].goal.id, where().along[2] })
    end)

    it("shows a quest once: a detour never repeats the main suggestion", function()
        boot({ level = 16 })
        m:SetCompletedQuests({ 1032 })
        changed()
        local w = where()
        assert.same({ "d718", 1012 }, { w.main.goal.id, w.main.q }) -- the walk from 1031
        assert.same({ "s1001", 1001 }, { w.along[1].goal.id, w.along[1].q }) -- not e1011's own 1012
    end)

    it("calls a target another continent only when the player's continent is known", function()
        boot()
        m:EnterInstance("Wailing Caverns", "party")
        changed()
        local main = where().main
        assert.same({ 4, false }, { main.bucket, main.far })
        assert.is_nil(N():Describe(main):find("another continent", 1, true))
    end)

    it("names the level to wait for when nothing can be done", function()
        boot({ level = 1 })
        assert.is_nil(where().main)
        assert.equal(3, where().wait)
    end)

    it("waits for the level a quest can be suggested at, not only its required level", function()
        boot({ level = 1 })
        ns.Knowledge:Get(1061).l = 9 -- required 3, suggested from 9 - RED
        changed()
        assert.equal(6, where().wait)
    end)

    it("counts the goal quests in the log and the ones ready", function()
        boot()
        inLog(1011, true)
        inLog(1001)
        changed()
        assert.same({ 2, 1 }, { where().inLog, where().ready })
    end)
end)

describe("narrative mode", function()
    after_each(function() m:AssertClean() end)

    -- the test route's Scourge paladin with the fixture goals
    local function bootRoute()
        m, ns = H.boot()
        ns.Knowledge:Add(dofile(FIXTURE))
    end

    it("has no route, no route chat line and no automation", function()
        bootRoute()
        local mark = #m.chat + 1
        assert.is_true(N():SetMode("narrative"))
        H.settle(m)
        assert.is_nil(ns.Engine:GetRoute())
        assert.equal("narrative", N():GetMode())
        assert.is_false(H.chatHas(m, ns.L.MSG_NO_ROUTE, mark))
        assert.is_true(H.chatHas(m, ns.L.MSG_MODE_NARRATIVE, mark))
        local actions = #m.actions
        m:OpenQuestDetail(363, { npcID = 1568 })
        H.waitAuto(m, ns)
        m:CloseInteraction()
        assert.same({}, H.actionsSince(m, actions, "AcceptQuest"))
    end)

    it("resumes the route where it was when switched back", function()
        bootRoute()
        H.playTo(m, ns, "tr-turnin-364")
        local hint, step = ns.cdb.cursorHint, H.cur(ns)
        N():SetMode("narrative")
        H.settle(m)
        N():SetMode("speedrun")
        H.settle(m)
        assert.equal(H.ROUTE_ID, ns.Engine:GetRoute().id)
        assert.equal(hint, ns.cdb.cursorHint)
        assert.equal(step, H.cur(ns))
    end)

    it("rejects an unknown mode", function()
        bootRoute()
        assert.is_false(N():SetMode("zen"))
        assert.equal("speedrun", N():GetMode())
        assert.is_true(H.chatHas(m, "zen"))
    end)

    it("keeps the mode and the marks over a reload and cleans invalid saved values", function()
        bootRoute()
        N():SetMode("narrative")
        ns.cdb.marks = { [1001] = "skip", [1002] = "done", x = "done", [5] = "maybe" }
        m, ns = H.reload(m)
        assert.equal("narrative", ns.cdb.mode)
        assert.same({ [1001] = "skip", [1002] = "done" }, ns.cdb.marks)
        assert.is_nil(ns.Engine:GetRoute())
        ns.cdb.mode, ns.cdb.marks = "zen", "none"
        m, ns = H.reload(m)
        assert.equal("speedrun", ns.cdb.mode)
        assert.same({}, ns.cdb.marks)
        assert.equal(H.ROUTE_ID, ns.Engine:GetRoute().id)
    end)
end)

describe("narrative follow", function()
    before_each(function() boot() end)
    after_each(function() m:AssertClean() end)

    local function ref() return (ns.Waypoint:GetCustom() or {}).ref end

    it("leads the arrow with the ref nar:<quest>", function()
        local main = where().main
        assert.is_true(N():Lead(main, true))
        assert.equal("nar:1001", ref())
        assert.is_true(N():IsLeading(main))
        assert.is_true(N():IsFollowing())
        N():Stop()
        assert.is_nil(ns.Waypoint:GetCustom())
        assert.is_false(N():IsFollowing())
    end)

    it("labels the arrow without the distance (the arrow shows it live)", function()
        local main = where().main
        N():Lead(main, true)
        assert.equal(N():Describe(main, true), ns.Waypoint:GetCustom().label)
        assert.is_nil(ns.Waypoint:GetCustom().label:find("yd", 1, true))
    end)

    it("tells the UI on a tick only when the suggestion changed", function()
        local fired = H.record(ns, "NARRATIVE_UPDATED")
        m:Advance(11)
        assert.equal(0, #fired)
        m:MoveTo(1413, 50, 60)
        m:Advance(10)
        assert.equal(1, #fired)
    end)

    it("moves the target on after a turn-in", function()
        N():Lead(where().main, true)
        inLog(1001, true)
        H.settle(m)
        assert.equal("nar:1001", ref()) -- now the turn-in of the same quest
        m:TurnInQuest(1001)
        H.settle(m)
        assert.equal("nar:1002", ref())
    end)

    it("does not lead back to the place just reached", function()
        N():Lead(where().main, true)
        m:MoveTo(1413, 50, 52)
        H.settle(m)
        assert.is_nil(ns.Waypoint:GetCustom())
        m:Advance(11) -- the "where now" ticker
        assert.is_nil(ns.Waypoint:GetCustom())
        assert.is_true(N():IsFollowing())
    end)

    it("keeps the followed quest while it is still a candidate", function()
        N():Lead(best("s1071"), true)
        changed()
        assert.equal(1001, where().main.q)
        assert.equal("nar:1071", ref())
    end)

    it("stops following when the knowledge base leads elsewhere", function()
        N():Lead(where().main, true)
        ns.Waypoint:SetCustom(1413, 10, 10, "Errand One", 1011)
        assert.is_false(N():IsFollowing())
        changed()
        assert.equal(1011, ref())
    end)
end)
