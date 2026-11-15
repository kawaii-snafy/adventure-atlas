-- The narrative goals of the knowledge base: tools/lib/goals.lua (Goals.Build on the real snapshot with the
-- overrides, the curated input tools/data/narrative.lua). The quest ids of the file and their zone keys come
-- from the generated addons/AdventureAtlas_Knowledge/Quests.lua (`make knowledge-check` keeps it current).

local DB = require("lib.fbdb")
local Goals = require("lib.goals")

local KB_FILE = "addons/AdventureAtlas_Knowledge/Quests.lua"

-- the AddKnowledge table of the generated file
local function knowledge()
    local chunk = assert(loadfile(KB_FILE))
    local data
    setfenv(chunk, { AdventureAtlas = { AddKnowledge = function(d) data = d end } })
    chunk()
    return data
end

-- every quest of a slot list (cliques flattened)
local function members(slots)
    local out = {}
    for _, s in ipairs(slots) do
        if type(s) == "table" then
            for _, m in ipairs(s) do out[#out + 1] = m end
        else
            out[#out + 1] = s
        end
    end
    return out
end

local function set(list)
    local out = {}
    for _, v in ipairs(list or {}) do out[v] = true end
    return out
end

describe("narrative goals (tools/lib/goals.lua)", function()
    local db, fileIds, zoneOf, curated, goals, excluded, byId, goalOf

    setup(function()
        db = DB.Load("tools/data/forever_db.lua")
        local rep = DB.ApplyOverrides(db, DB.OverridesDir("."))
        assert.are.equal(0, #rep.errors)
        fileIds, zoneOf = {}, {}
        for id, q in pairs(knowledge().quests) do
            fileIds[id] = true
            zoneOf[id] = q.z
        end
        curated = Goals.LoadCurated("tools/data/narrative.lua")
        local _
        goals, _, excluded = Goals.Build(db, fileIds, zoneOf, curated)
        byId, goalOf = {}, {}
        for _, g in ipairs(goals) do
            byId[g.id] = g
            for _, id in ipairs(members(g.q)) do goalOf[id] = g end
            for _, id in ipairs(g.opt or {}) do goalOf[id] = g end
        end
    end)

    it("gives every quest of the file exactly one disposition: a slot, an opt or an exclusion reason", function()
        local seen = {}
        for _, g in ipairs(goals) do
            for _, id in ipairs(members(g.q)) do
                assert.is_nil(seen[id], "twice: " .. id)
                seen[id] = g.id
            end
            for _, id in ipairs(g.opt or {}) do
                assert.is_nil(seen[id], "twice: " .. id)
                seen[id] = g.id
            end
        end
        for id in pairs(fileIds) do
            assert.is_true((seen[id] ~= nil) ~= (excluded[id] ~= nil), "quest " .. id)
        end
    end)

    it("makes camping one Great Outdoors slot and one Cooking slot, The Adventurer optional", function()
        local g = byId["n:camping"]
        assert.are.same({ { 96101, 96604, 96605, 96607 }, { 96646, 96655, 96658, 96661 } }, g.q)
        assert.are.same({ 96638, 96652, 96656, 96659 }, g.opt)
        assert.are.equal("novelty", g.a)
    end)

    it("keeps the sleeping bag in curated order with its soft order, Rekindle optional, unverified", function()
        local g = byId["n:sleeping-bag"]
        assert.are.same({ 79007, 79192, 79980, 79974, 79975, 79976 }, g.q)
        assert.are.same({ [79192] = 79007, [79980] = 79192, [79974] = 79980, [79975] = 79974, [79976] = 79975 },
            g.after)
        assert.are.same({ 80001 }, g.opt)
        assert.is_false(g.v)
        assert.is_string(g.src)
    end)

    it("builds Wailing Caverns from the db band and entrance, its lead-in chain as prep", function()
        local g = byId.d718
        assert.are.equal(15, g.lo)
        assert.are.equal(24, g.hi)
        assert.are.equal("db", g.lv)
        assert.are.same({ 1413, 46, 36.5 }, g.at[1])
        local prep = set(g.prep)
        for _, id in ipairs({ 886, 870, 877, 880 }) do assert.is_true(prep[id], "prep " .. id) end
        -- 1489 / 1490 are filed under the dungeon area: counted in the dungeon goal itself
        local q = set(members(g.q))
        assert.is_true(q[914] and q[1489] and q[1490])
        assert.are.equal("story", goalOf[886].a)
    end)

    it("files quests of entrance sub-areas under their dungeon; Sparklematic is two clique slots", function()
        assert.are.equal("d491", goalOf[1144].id)
        assert.are.equal("d1337", goalOf[2418].id)
        assert.are.equal("d1584", goalOf[3906].id)
        local cliques = {}
        for _, s in ipairs(byId.d721.q) do
            if type(s) == "table" then cliques[#cliques + 1] = s end
        end
        assert.are.same({ { 2951, 4601, 4602 }, { 2952, 4605, 4606 } }, cliques)
    end)

    it("keeps non-clique exclusives as single slots with ex; every table slot is a clique", function()
        local g = goalOf[411]
        assert.are.same({ 410, 431 }, g.ex[411])
        local function exclusive(a, b)
            return set(db.quests[a].exclusive)[b] or set(db.quests[b].exclusive)[a]
        end
        for _, goal in ipairs(goals) do
            for _, s in ipairs(goal.q) do
                if type(s) == "table" then
                    for i = 1, #s do
                        for j = i + 1, #s do
                            assert.is_truthy(exclusive(s[i], s[j]), goal.id .. ": " .. s[i] .. " / " .. s[j])
                        end
                    end
                end
            end
        end
    end)

    it("leaves repeatable, endgame, any-level, profession and index-only quests out; breadcrumbs only opt", function()
        local REPEATABLE = db.enums.specialFlags.REPEATABLE
        for id, g in pairs(goalOf) do
            local q = db.quests[id]
            assert.is_table(q, "index-only " .. id)
            if g.a ~= "novelty" then
                assert.is_false(DB.HasBit(q.special, REPEATABLE), "repeatable " .. id)
                assert.is_true(q.reqLevel < 58, "endgame " .. id)
                assert.is_false(q.level >= 60 and q.reqLevel <= 10, "any level " .. id)
                assert.is_nil(q.reqSkill, "profession " .. id)
            end
        end
        for _, goal in ipairs(goals) do
            for _, id in ipairs(members(goal.q)) do
                assert.is_nil(db.quests[id].breadcrumbFor, "breadcrumb in a slot: " .. id)
            end
        end
    end)

    it("puts every dungeon quest of docs/routes/shared-path.md section 7 in a dungeon goal", function()
        local ids = { 92421, 95216, 95204, 97288, 1098, 1014, 1013, 6563, 6921, 6922, 6564, 6561, 1144, 6626, 1048,
            2418, 2768, 3042, 2865, 4134, 3906, 4081, 1445, 5251, 5212, 5243, 5214, 5282 }
        for _, id in ipairs(ids) do
            assert.are.equal("dungeon", goalOf[id] and goalOf[id].a, "quest " .. id)
        end
    end)

    it("stops on a curated id that is not a full record of the file", function()
        local bad = Goals.LoadCurated("tools/data/narrative.lua")
        bad.opt[999999] = "no such quest"
        local ok, err = pcall(Goals.Build, db, fileIds, zoneOf, bad)
        assert.is_false(ok)
        assert.matches("quest 999999 is not a full record", err, 1, true)
    end)

    it("is deterministic: two builds serialize identically", function()
        local again = Goals.Build(db, fileIds, zoneOf, Goals.LoadCurated("tools/data/narrative.lua"))
        assert.are.same(Goals.Lines(goals), Goals.Lines(again))
    end)
end)
