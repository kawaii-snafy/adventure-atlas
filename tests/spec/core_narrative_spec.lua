-- Narrative mode (Core/Narrative.lua): the evaluation of the goals (bars, slots, marks), "where now" (buckets,
-- priorities, gates, the prerequisite walk), the mode switch against the route engine and the automation, and
-- follow (the arrow moves on with the suggestion). Goals: tests/fixtures/narrative/data.lua (its header lists
-- the role of each goal); the player is an Orc warrior, level 12, at the Barrens 50, 50.

local H = require("fixtures.core.helpers")

local FIXTURE = "tests/fixtures/narrative/data.lua"
local ORC = { race = "Orc", class = "WARRIOR", level = 12, mapID = 1413, x = 50, y = 50 }

local m, ns

local function N() return ns.Narrative end

-- Every fixture quest with one objective, so a quest in the log is incomplete until CompleteObjectives; the
-- fixture items with their names.
local function defineQuests(mm)
    local data = dofile(FIXTURE)
    for id, q in pairs(data.quests) do
        mm:DefineQuest(id, { title = q.n, level = q.l, reqLevel = q.r, objectives = { { text = "done", required = 1 } } })
    end
    for id, name in pairs(data.items) do mm:DefineItem(id, { name = name }) end
end

-- The Orc warrior in narrative mode with the fixture goals (a fresh copy: tests may edit the records);
-- skills = { [line] = { rank, maxRank } }.
local function boot(player, skills)
    local p = {}
    for k, v in pairs(ORC) do p[k] = v end
    for k, v in pairs(player or {}) do p[k] = v end
    m, ns = H.boot({ fixture = false, quests = false, player = p, setup = defineQuests, mock = { skills = skills } })
    ns.Knowledge:Add(dofile(FIXTURE))
    N():SetMode("narrative")
    H.settle(m)
end

local function goal(id) return N().byId[id] end
local function best(id) return N():Best(goal(id)) end
local function where() return N():Where() end

-- Evaluate the fixture goals for a state: opts = { level, range, done = { ids }, log, marks, race, class,
-- skill = { [line] = { rank, maxRank } }, known = { spellIDs } }.
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
        skill = function(line)
            local s = (opts.skill or {})[line]
            if s then return s[1], s[2] end
        end,
        known = function(id)
            for _, k in ipairs(opts.known or {}) do
                if k == id then return true end
            end
            return false
        end,
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

    it("names the level to wait for when nothing can be done, also next to a hint as the main suggestion", function()
        boot({ level = 1 })
        assert.is_nil(where().main)
        assert.equal(3, where().wait)
        m:AddItem(2004)
        H.settle(m)
        assert.same({ "use", true, 3 }, { where().main.kind, where().main.side, where().wait })
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

describe("narrative professions", function()
    after_each(function() m:AssertClean() end)

    local HERB = { [182] = { 1, 75 } }

    it("counts a profession's quests only once it is learned", function()
        boot()
        local res = eval()
        assert.equal("none", res.goal.p182.state)
        assert.same({ done = 0, open = 0, missed = 0 }, res.aspect.profession)
        assert.same({ 0, 3 }, { eval({ skill = HERB }).aspect.profession.done, eval({ skill = HERB }).aspect.profession.open })
    end)

    it("locks a quest behind its skill rank: open but not available, the goal waits for the skill", function()
        boot()
        local skill = { [182] = { 30, 75 } }
        local res = eval({ skill = skill })
        assert.same({ false, 50 }, { res.q[1082].avail, res.q[1082].need })
        assert.same({ "open", 50 }, { res.goal.p182.slot[3], res.goal.p182.skill })
        local gs = eval({ skill = skill, done = { 1081, 1083 } }).goal.p182
        assert.same({ "later", 50 }, { gs.state, gs.skill })
    end)

    it("never grays a profession quest", function()
        boot()
        assert.is_true(ns.Compat.IsLevelGray(6, 12, ns.Compat.FallbackTrivialRange(12)))
        assert.is_false(eval({ skill = HERB }).q[1083].gray)
    end)

    it("loses Camping 101 once its camp spell is known: the total drops by one", function()
        boot()
        local res = eval({ skill = HERB, known = { 9001 } })
        assert.is_true(res.q[1083].lost)
        assert.same({ "out", 2 }, { res.goal.p182.slot[1], res.goal.p182.open })
    end)

    it("gates a profession quest by its required level only", function()
        boot({ level = 9 }, HERB)
        assert.is_true(N():Get().q[1081].avail)
        assert.equal("take", N().candOf["1081"].kind)
    end)
end)

describe("narrative hints", function()
    after_each(function() m:AssertClean() end)

    it("suggests training the next rank near the trainer from its skill and level", function()
        boot(nil, { [182] = { 50, 75 } })
        local c = N().candOf.t182
        assert.same({ "train", true, 1413, "Herb Trainer", 1 }, { c.kind, c.side, c.map, c.place, c.bucket })
        for _, case in ipairs({ { 12, { 40, 75 } }, { 12, { 140, 150 } }, { 9, { 50, 75 } } }) do
            boot({ level = case[1] }, { [182] = case[2] })
            assert.is_nil(N().candOf.t182)
        end
        goal("p182").sec = true -- a secondary keeps the level gate (Fishing) ...
        changed()
        assert.is_nil(N().candOf.t182)
        goal("p182").nolv = true -- ... unless its rank-ups need no level (Cooking, First Aid)
        changed()
        assert.equal("train", N().candOf.t182.kind)
    end)

    it("never makes a side candidate main while another is left", function()
        boot(nil, { [182] = { 50, 75 } })
        assert.equal("s1001", where().main.goal.id) -- the train (prio 3) waits behind a take (prio 4)
        for _, g in ipairs(N().goals) do
            if g.a ~= "profession" then N():Mark(g, "skip") end
        end
        H.settle(m)
        assert.same({ "p182", "train" }, { where().main.goal.id, where().main.kind })
    end)

    it("prefers a non-side detour of an aspect to a side one", function()
        boot()
        ns.Knowledge.data.npcs[108] = { "Bag Maker", 1413, 50, 60 } -- n:test's 1041 in bucket 1, prio 4
        m:AddItem(2002) -- n:finds: start 1092 in bucket 1, prio 2
        H.settle(m)
        assert.equal("start", best("n:finds").kind)
        local novelty
        for _, c in ipairs(where().along) do
            if c.goal.a == "novelty" then novelty = c end
        end
        assert.same({ "n:test", 1041 }, { novelty.goal.id, novelty.q })
    end)

    it("names the gathering of this zone while it still gives skill", function()
        boot(nil, { [182] = { 60, 75 } })
        local c = N().candOf.g182
        assert.same({ "gather", 2, nil, 50, 60 }, { c.kind, c.bucket, c.map, c.e.lo, c.rank })
        m:SetSkill(182, 160, 225)
        H.settle(m)
        assert.is_nil(N().candOf.g182)
    end)

    it("suggests starting a quest from an item in the bags, in a goal or among the finds", function()
        boot()
        m:AddItem(2001)
        H.settle(m)
        local main = where().main
        assert.same({ "start", 1051, 1, false }, { main.kind, main.q, main.bucket, main.side })
        assert.is_false(N():Lead(main, true))
        m:AddItem(2002)
        H.settle(m)
        local c = best("n:finds")
        assert.same({ "start", 1092, true }, { c.kind, c.q, c.side })
    end)

    it("keeps the goal's take gate for a quest started from an item: never a gray one", function()
        boot({ level = 30 })
        m:AddItem(2001)
        H.settle(m)
        assert.is_true(N():Get().q[1051].gray)
        assert.is_nil(N().candOf["1051"])
    end)

    it("suggests a curated use for an item in the bags", function()
        boot()
        assert.is_nil(N().candOf.u2004)
        m:AddItem(2004)
        H.settle(m)
        local c = N().candOf.u2004
        assert.same({ "use", 112, "Crate Clerk" }, { c.kind, c.goal.use[1].n[1], c.place })
        assert.is_true(c.bucket <= 2)
        m:MoveTo(1420, 50, 50) -- the clerk on another continent: text only, no detour, no arrow
        H.settle(m)
        c = N().candOf.u2004
        assert.same({ 4, true }, { c.bucket, c.far })
        assert.is_false(N():Lead(c, true))
        for _, a in ipairs(where().along) do assert.not_equal(c, a) end
    end)

    it("mutes the train and gather hints of a profession marked 'not interested'", function()
        boot(nil, { [182] = { 60, 75 } })
        assert.is_truthy(N().candOf.t182 and N().candOf.g182)
        N():Mark(goal("p182"), "skip")
        H.settle(m)
        assert.is_nil(N().candOf.t182)
        assert.is_nil(N().candOf.g182)
    end)

    it("describes each hint, flagging the unverified ones", function()
        boot(nil, { [182] = { 60, 75 } })
        m:AddItem(2001)
        m:AddItem(2004)
        H.settle(m)
        local cand = N().candOf
        assert.equal("Start \"Tirisfal Errand\": Tirisfal Token is in your bags", N():Describe(cand["1051"]))
        assert.equal("Train Herbalism up to 150 -- Herb Trainer, 40 yd (not checked in game)",
            N():Describe(cand.t182))
        assert.equal("Herbalism 60: here -- Mageroyal (not checked in game)", N():Describe(cand.g182))
        assert.equal("Sealed Test Crate: turn it in -- Crate Clerk, 100 yd (not checked in game)",
            N():Describe(cand.u2004))
    end)
end)

describe("narrative profession and bag events", function()
    after_each(function() m:AssertClean() end)

    it("re-evaluates when a profession rank changes, not on an unchanged SKILL_LINES_CHANGED", function()
        boot()
        assert.equal("none", N():Get().goal.p182.state)
        m:SetSkill(182, 50, 75)
        H.settle(m)
        local res = N():Get()
        assert.equal("open", res.goal.p182.state)
        m:Fire("SKILL_LINES_CHANGED")
        H.settle(m)
        assert.equal(res, N():Get())
    end)

    it("re-checks only where now when a watched item comes or goes, and tells the UI only then", function()
        boot({ level = 1 }) -- nothing to suggest: the crate becomes the main suggestion
        local res = N():Get()
        local fired = H.record(ns, "NARRATIVE_UPDATED")
        m:AddItem(9999) -- loot nobody watches: nothing to re-check
        H.settle(m)
        assert.equal(0, #fired)
        assert.is_nil(best("n:finds"))
        m:AddItem(2004)
        H.settle(m)
        assert.equal("use", where().main.kind)
        assert.equal(1, #fired)
        assert.equal(res, N():Get())
    end)

    it("follows a hint by its ref", function()
        boot(nil, { [182] = { 50, 75 } })
        local c = N().candOf.t182
        assert.is_true(N():Lead(c, true))
        assert.equal("nar:t182", ns.Waypoint:GetCustom().ref)
        assert.is_true(N():IsLeading(c))
        changed()
        assert.equal("nar:t182", ns.Waypoint:GetCustom().ref) -- sticky while still a candidate
    end)
end)

describe("Compat professions", function()
    after_each(function() m:AssertClean() end)

    it("reads a skill rank from C_SkillInfo, an unlearned line as nil", function()
        boot(nil, { [182] = { 60, 75 }, [186] = { 0, 75 } })
        assert.same({ 60, 75 }, { ns.Compat.SkillRank(182) })
        assert.is_nil(ns.Compat.SkillRank(186))
        assert.is_nil(ns.Compat.SkillRank(393))
    end)

    it("falls back to GetProfessions / GetProfessionInfo", function()
        boot(nil, { [182] = { 60, 75 } })
        m:ProvideNS("C_SkillInfo", { GetSkillLineInfoByID = function() return nil end })
        assert.same({ 60, 75 }, { ns.Compat.SkillRank(182) })
        assert.is_nil(ns.Compat.SkillRank(186))
    end)

    it("knows a spell from the spell book", function()
        boot()
        assert.is_false(ns.Compat.IsSpellKnown(9001))
        m:LearnSpell(9001)
        assert.is_true(ns.Compat.IsSpellKnown(9001))
    end)
end)
