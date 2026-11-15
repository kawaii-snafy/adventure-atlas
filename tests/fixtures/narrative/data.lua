-- tests/fixtures/narrative/data.lua -- a small knowledge base with narrative goals (the AdventureAtlas.AddKnowledge
-- shape, tools/gen_knowledge_data.lua; goals: Core/Knowledge.lua header) for tests/spec/core_narrative_spec.lua and
-- the atlas specs. Quest ids are fake (10xx); places use the synthetic maps of the WoW mock (tests/mocks/wow/world.lua:
-- a zone is 1000 x 1000 yards, Durotar lies east of the Barrens, Orgrimmar inside Durotar, Tirisfal on the other
-- continent). The player of the specs: an Orc warrior, level 12, at the Barrens 50, 50.
--
-- Roles: s1001 a Barrens chain (clique slot, breadcrumb in opt), e1011 errands of one giver (1012 leads in to the
-- dungeon), s1023 a Tauren-only chain, s1051 a chain on the other continent, s1061 a low-level chain (1061 is
-- gray at 12, 1062 needs it), s1071 non-clique exclusives (1072 excludes 1071 and 1073; 1074 needs 1072),
-- c1021 a warrior chain in Orgrimmar, d718 a dungeon (1032's giver is inside), n:test a curated novelty with
-- the after / cnt / hint gates, n:finds the finds goal (no quests; a crate to turn in, `use`), p182 Herbalism
-- (1081 at skill 1 with a level above the gate, 1082 at skill 50, 1083 Camping 101 lost once spell 9001 is known;
-- a trainer 40 yd away, a blueprint from Wailing Caverns, two leveling brackets in the Barrens). Items: 2001
-- starts 1051, 2002 starts 1092 (in no goal: owned by n:finds). The default Orc (no skills, empty bags) sees
-- none of the profession / finds content.
return {
    faction = "Horde",
    zones = {
        [1] = { map = 1413, en = "The Barrens" },
        [2] = { map = 1411, en = "Durotar" },
        [3] = { map = 1420, en = "Tirisfal Glades" },
        [4] = { class = "WARRIOR" },
        [5] = { area = 718, en = "Wailing Caverns" },
    },
    npcs = {
        [101] = { "Oasis Keeper", 1413, 50, 52 },     -- 20 yd from the player
        [102] = { "Oasis Scout", 1413, 50, 80 },      -- 300 yd
        [103] = { "Errand Giver", 1413, 50, 70 },     -- 200 yd
        [104] = { "Durotar Grunt", 1411, 50, 50 },    -- 1000 yd
        [105] = { "Warrior Trainer", 1454, 50, 50 },  -- Orgrimmar, about 1030 yd
        [106] = { "Tirisfal Deathguard", 1420, 50, 50 }, -- other continent
        [107] = { "Crossroads Druid", 1413, 52, 30 }, -- about 200 yd
        [108] = { "Bag Maker", 1411, 99, 99 },        -- about 1570 yd
        [109] = { "Old Hermit", 1413, 10, 90 },       -- about 570 yd
        [110] = { "Hidden Hermit" },                  -- no spawn known
        [111] = { "Herb Trainer", 1413, 50, 54 },     -- 40 yd
        [112] = { "Crate Clerk", 1413, 60, 50 },      -- 100 yd
    },
    objects = {},
    items = {
        [2001] = "Tirisfal Token", [2002] = "Loose Label", [2003] = "Blueprint: Test Rack",
        [2004] = "Sealed Test Crate", [2447] = "Peacebloom", [785] = "Mageroyal",
    },
    quests = {
        [1001] = { n = "Oasis One", l = 12, r = 10, z = 1, s = { n = { 101 } }, e = { n = { 101 } } },
        [1002] = { n = "Oasis Two", l = 13, r = 10, z = 1, s = { n = { 101 } }, e = { n = { 102 } }, pa = { 1001 } },
        [1003] = { n = "Oasis Choice A", l = 14, r = 10, z = 1, s = { n = { 102 } }, e = { n = { 102 } }, py = { 1002 } },
        [1004] = { n = "Oasis Choice B", l = 14, r = 10, z = 1, s = { n = { 102 } }, e = { n = { 102 } }, py = { 1002 } },
        [1005] = { n = "Word of the Oases", l = 11, r = 10, z = 1, s = { n = { 104 } }, e = { n = { 101 } } },
        [1011] = { n = "Errand One", l = 12, r = 10, z = 1, s = { n = { 103 } }, e = { n = { 103 } } },
        [1012] = { n = "Errand Two", l = 13, r = 10, z = 1, s = { n = { 103 } }, e = { n = { 103 } } },
        [1021] = { n = "Warrior Call", l = 10, r = 10, z = 4, cl = 1, s = { n = { 105 } }, e = { n = { 105 } } },
        [1022] = { n = "Warrior Trial", l = 12, r = 10, z = 4, cl = 1, s = { n = { 105 } }, e = { n = { 104 } },
                   pa = { 1021 } },
        [1023] = { n = "Tauren Rite", l = 12, r = 10, z = 1, ra = 32, s = { n = { 101 } }, e = { n = { 101 } } },
        [1024] = { n = "Tauren Rite Two", l = 13, r = 10, z = 1, s = { n = { 101 } }, e = { n = { 101 } }, pa = { 1023 } },
        [1031] = { n = "Fang Leaders", l = 17, r = 15, z = 5, s = { n = { 107 } }, e = { n = { 107 } }, pa = { 1012 } },
        [1032] = { n = "Deep Hermit", l = 18, r = 15, z = 5, s = { n = { 110 } }, e = { n = { 110 } } },
        [1041] = { n = "Bag One", l = 12, r = 10, z = 2, new = true, s = { n = { 108 } }, e = { n = { 108 } } },
        [1042] = { n = "Bag Two", l = 12, r = 10, z = 1, new = true, s = { n = { 101 } }, e = { n = { 101 } } },
        [1043] = { n = "Bag Reward", l = 12, r = 10, z = 1, new = true, s = { n = { 101 } }, e = { n = { 101 } } },
        [1051] = { n = "Tirisfal Errand", l = 12, r = 10, z = 3, s = { n = { 106 }, i = { 2001 } }, e = { n = { 106 } } },
        [1061] = { n = "Old Request", l = 5, r = 3, z = 1, s = { n = { 109 } }, e = { n = { 109 } } },
        [1062] = { n = "Old Request Two", l = 14, r = 10, z = 1, s = { n = { 109 } }, e = { n = { 109 } }, pa = { 1061 } },
        [1071] = { n = "Shade Left", l = 12, r = 10, z = 2, s = { n = { 104 } }, e = { n = { 104 } } },
        [1072] = { n = "Shade Middle", l = 12, r = 10, z = 2, s = { n = { 104 } }, e = { n = { 104 } } },
        [1073] = { n = "Shade Right", l = 12, r = 10, z = 2, s = { n = { 104 } }, e = { n = { 104 } } },
        [1074] = { n = "Shade Beyond", l = 13, r = 10, z = 2, s = { n = { 104 } }, e = { n = { 104 } }, pa = { 1072 } },
        [1081] = { n = "Root Samples", l = 16, r = 9, z = 1, sk = { 182, 1 }, s = { n = { 111 } }, e = { n = { 111 } } },
        [1082] = { n = "Rare Roots", l = 14, r = 10, z = 1, sk = { 182, 50 }, s = { n = { 111 } }, e = { n = { 111 } } },
        [1083] = { n = "Camping 101: Herbalism", l = 6, r = 4, z = 1, new = true, sk = { 182, 1 }, sp = 9001,
                   s = { n = { 111 } }, e = { n = { 111 } } },
        [1092] = { n = "Loose Label", l = 60, r = 10, z = 1, s = { i = { 2002 } }, e = { n = { 112 } } },
    },
    goals = { -- order: aspect, lo, id (as generated)
        { id = "s1061", a = "story", z = 1, lo = 5, hi = 14, q = { 1061, 1062 } },
        { id = "e1011", a = "story", z = 1, lo = 12, hi = 13, q = { 1011, 1012 } },
        { id = "s1001", a = "story", z = 1, lo = 12, hi = 14, q = { 1001, 1002, { 1003, 1004 } }, opt = { 1005 } },
        { id = "s1023", a = "story", z = 1, lo = 12, hi = 13, q = { 1023, 1024 } },
        { id = "s1051", a = "story", z = 3, lo = 12, hi = 12, q = { 1051 } },
        { id = "s1071", a = "story", z = 2, lo = 12, hi = 13, q = { 1071, 1072, 1073, 1074 },
          ex = { [1071] = { 1072 }, [1072] = { 1071, 1073 }, [1073] = { 1072 } } },
        { id = "d718", a = "dungeon", lo = 15, hi = 24, q = { 1031, 1032 }, d = 718, en = "Wailing Caverns",
          at = { { 1413, 46, 36.5 } }, lv = "db", prep = { 1012 } },
        { id = "c1021", a = "class", z = 4, lo = 10, hi = 12, q = { 1021, 1022 } },
        { id = "n:test", a = "novelty", lo = 12, hi = 12, q = { 1041, 1042, 1043 },
          name = { en = "Cozy test bag", ru = "Тестовый спальник" },
          note = { en = "A bag to rest anywhere.", ru = "Мешок, чтобы отдыхать где угодно." },
          src = "https://example.invalid/test-bag", v = false,
          after = { [1042] = 1041 }, cnt = { [1043] = 2 }, hint = { [1041] = { 1413, 12 } } },
        { id = "n:finds", a = "novelty", lo = 1, hi = 60, q = {}, name = { en = "Finds", ru = "Находки" },
          src = "https://example.invalid/finds", v = false,
          use = { { i = { 2004 }, n = { 112 }, t = { en = "turn it in", ru = "сдай" } } } },
        { id = "p182", a = "profession", line = 182, lo = 6, hi = 16, q = { 1083, 1081, 1082 },
          name = { en = "Herbalism", ru = "Травничество" }, note = { en = "Gather herbs.", ru = "Собирай травы." },
          src = "https://example.invalid/herbalism", v = false,
          train = { { n = { 111 } } }, blueprints = { { i = 2003, need = 40, d = 718, n = 110 } },
          brackets = { { lo = 1, hi = 50, i = { 2447 }, m = { 1413 } }, { lo = 50, hi = 70, i = { 785 }, m = { 1413 } } } },
    },
}
