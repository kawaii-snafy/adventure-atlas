-- The narrative goals of the real knowledge base (addons/AdventureAtlas_Knowledge/Quests.lua, goals built by
-- tools/lib/goals.lua): every goal loads, and the bars are honest for every race / class of the guides --
-- playing every quest that can be taken, in order, never lowers a bar and ends with nothing open (100% is
-- reachable), without gray quests and with them (level 60). The profession goals are played with every skill line
-- at 300/300, so their quests count and none waits for a skill rank.

local H = require("fixtures.core.helpers")

local KB_TOC = "addons/AdventureAtlas_Knowledge/AdventureAtlas_Knowledge.toc"

-- the race / class pairs of the routes (addons/AdventureAtlas_Guides/Route.lua, RACES)
local PROFILES = {
    Orc = { "HUNTER", "MAGE", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" },
    Troll = { "HUNTER", "MAGE", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" },
    Tauren = { "DRUID", "HUNTER", "SHAMAN", "WARRIOR" },
    Scourge = { "MAGE", "PALADIN", "PRIEST", "ROGUE", "WARLOCK", "WARRIOR" },
    Skyborne = { "DRUID", "HUNTER", "ROGUE", "SHAMAN", "WARRIOR" },
}

local m, ns

-- Evaluate at level 60, then complete every quest that can be taken (id order; not a second quest of an
-- exclusive group in the same pass) until none is left. @return nil, or what went wrong
local function playThrough(goals, quests, facts, range)
    local done, prev, mine = {}, {}, {}
    local st = {
        level = 60, range = range, log = {}, marks = {},
        isFor = function(rec)
            if mine[rec] == nil then mine[rec] = ns.Knowledge:IsFor(rec, facts) end
            return mine[rec]
        end,
        done = function(q) return done[q] == true end,
        skill = function() return 300, 300 end,
    }
    -- exclusive partners: clique members and the listed non-clique partners
    local partners = {}
    local function link(a, b)
        partners[a] = partners[a] or {}
        partners[a][#partners[a] + 1] = b
    end
    for _, g in ipairs(goals) do
        for _, slot in ipairs(g.q) do
            if type(slot) == "table" then
                for _, a in ipairs(slot) do
                    for _, b in ipairs(slot) do
                        if a ~= b then link(a, b) end
                    end
                end
            end
        end
        for q, list in pairs(g.ex or {}) do
            for _, b in ipairs(list) do link(q, b) end
        end
    end
    for _ = 1, 200 do
        local res = ns.Narrative.Evaluate(goals, quests, st)
        for a, agg in pairs(res.aspect) do
            local total = agg.done + agg.open
            local pct = total > 0 and agg.done / total or 1
            if pct < (prev[a] or 0) then return ("%s bar fell from %.4f to %.4f"):format(a, prev[a], pct) end
            prev[a] = pct
        end
        local ids = {}
        for q, r in pairs(res.q) do
            if r.avail then ids[#ids + 1] = q end
        end
        if #ids == 0 then
            local stuck = {}
            for _, g in ipairs(goals) do
                local gs = res.goal[g.id]
                for i, status in ipairs(gs.slot) do
                    if status == "open" then
                        local slot = g.q[i]
                        stuck[#stuck + 1] = g.id .. ":" .. tostring(type(slot) == "table" and slot[1] or slot)
                    end
                end
            end
            if #stuck > 0 then
                table.sort(stuck)
                return ("%d slot(s) stay open: %s"):format(#stuck, table.concat(stuck, " ", 1, math.min(#stuck, 15)))
            end
            return nil
        end
        table.sort(ids)
        local now = {}
        for _, q in ipairs(ids) do
            local blocked = false
            for _, p in ipairs(partners[q] or {}) do
                if now[p] then blocked = true end
            end
            if not blocked then
                done[q], now[q] = true, true
            end
        end
    end
    return "no end after 200 passes"
end

describe("narrative goals of the knowledge base", function()
    setup(function()
        m, ns = H.boot({ fixture = false, setup = function(mm) H.Mock.loadAddon(mm, KB_TOC, nil, { deferred = true }) end })
        assert(ns.Narrative:Load())
    end)
    teardown(function() m:AssertClean() end)

    it("loads every goal", function()
        assert.is_table(ns.Knowledge.data.goals)
        assert.equal(#ns.Knowledge.data.goals, #ns.Narrative.goals)
        assert.is_true(#ns.Narrative.goals > 0)
    end)

    it("carries the profession fields of the snapshot", function()
        local quests = ns.Knowledge.data.quests
        assert.same({ 165, 10 }, quests[769].sk)
        assert.equal(1229432, quests[97906].sp)
        local n = 0
        for _, g in ipairs(ns.Narrative.goals) do
            if g.a == "profession" then
                n = n + 1
                assert.is_number(g.line, g.id)
                assert.equal("p" .. g.line, g.id)
                assert.is_string(g.name.en, g.id)
                assert.is_string(g.name.ru, g.id)
            end
        end
        assert.equal(12, n)
    end)

    it("keeps the bars rising to 100% for every race / class of the guides", function()
        local goals, quests = ns.Narrative.goals, ns.Knowledge.data.quests
        local failures = {}
        for race, classes in pairs(PROFILES) do
            for _, class in ipairs(classes) do
                local facts = { race = race, class = class, faction = "Horde" }
                for _, range in ipairs({ 99, ns.Compat.FallbackTrivialRange(60) }) do
                    local err = playThrough(goals, quests, facts, range)
                    if err then failures[#failures + 1] = ("%s %s (range %d): %s"):format(race, class, range, err) end
                end
            end
        end
        table.sort(failures)
        assert.same({}, failures)
    end)
end)
