-- tools/data/narrative.lua -- curated input of the narrative goals (maintained by hand).
--
-- Read by tools/lib/goals.lua (Goals.LoadCurated: one `return { ... }`, run in an EMPTY environment)
-- when tools/gen_knowledge_data.lua builds the `goals` of addons/AdventureAtlas_Knowledge/Quests.lua.
-- Every id must be a full record of that file and may be claimed once; the generator stops with an
-- error otherwise. Entries that state more than the snapshot does carry `src` (link or
-- "in game YYYY-MM-DD") and `v` (true only when checked in the Forever client).
--
--   dungeons = { [AreaTable id] = {         -- whitelist of Horde leveling 5-man instances
--       xp = "slug",                        -- level band from db.xp.dungeons[slug].levels (lv "db")
--       lo = 28, hi = 33,                   -- else a sourced band (lv "src"; needs src, v)
--                                           -- neither: min reqLevel .. max level of its quests ("derived")
--       areas = { AreaTable id, ... },      -- sub-areas whose quests belong to the dungeon
--       add = { questID, ... },             -- quests of the dungeon outside its areas (needs src, v)
--       after = { [questID] = questID },    -- soft order: suggest the key after the value (needs src, v)
--       src = "...", v = false,
--   } },
--   goals = { {                             -- novelty goals, in display order
--       key = "camping",                    -- goal id "n:<key>"
--       name = { en, ru }, note = { en, ru } | nil,
--       q = { questID | { questID, ... } }, -- counted slots in this order; a table = an exclusive clique
--       opt = { questID } | nil,            -- counted only once done; suggested only by the prerequisite walk
--       after = { [questID] = questID } | nil, -- suggest the key once the value's slot is no longer open
--       cnt = { [questID] = N } | nil,      -- suggest the key once N slots without a cnt key are done
--       hint = { [questID] = { uiMapID, level } } | nil, startObj = true | nil,
--       src = "...", v = false,
--   } },
--   titles = { [goal id] = { en, ru } },    -- title overrides, only for titles that read badly in game
--   exclude = { [questID] = "reason" },     -- left out of every goal
--   opt = { [questID] = "reason" },         -- optional in the goal it falls into
-- The goal fields are documented in the header of tools/gen_knowledge_data.lua.

return {
    dungeons = {
        [2437] = { xp = "ragefire-chasm" },
        [718] = { xp = "wailing-caverns" },
        [16611] = {
            xp = "ruins-of-lordaeron",
            -- 97288 starts from an item dropped in the ruins; 97289 / 97291 / 97292 from Faranell and 97290
            -- from npc 271613, all in Undercity. Only 97290 has quest zone 1497 (the rest 16611), hence `add`
            add = { 97290 },
            after = { [97289] = 97288, [97290] = 97289, [97291] = 97290, [97292] = 97291 },
            src = "https://www.wowhead.com/forever/quest=97288 (order)", v = false,
        },
        [719] = { xp = "blackfathom-deeps" },
        [209] = { xp = "shadowfang-keep" },
        [491] = { xp = "razorfen-kraul", areas = { 1717 } },
        [721] = { xp = "gnomeregan", areas = { 133 } },
        [16732] = { xp = "excavation-site" },
        [16544] = { lo = 28, hi = 33, src = "https://warcraft.wiki.gg/wiki/Forever", v = false },
        [796] = {},                       -- Scarlet Monastery
        [722] = {},                       -- Razorfen Downs
        [1337] = { areas = { 1517 } },    -- Uldaman
        [1176] = { areas = { 978 } },     -- Zul'Farrak
        [2100] = {},                      -- Maraudon
        [1477] = { areas = { 1417 } },    -- The Temple of Atal'Hakkar (quests under the Sunken Temple area)
        [1584] = { areas = { 25 } },      -- Blackrock Depths (Blackrock Mountain: only 3906 is not endgame)
        [1583] = {},                      -- Blackrock Spire
        [2557] = {},                      -- Dire Maul
        [2017] = {},                      -- Stratholme
        [2057] = {},                      -- Scholomance
    },
    goals = {
        {
            key = "camping",
            name = { en = "Camping", ru = "Походная жизнь" },
            q = { { 96101, 96604, 96605, 96607 }, { 96646, 96655, 96658, 96661 } },
            opt = { 96638, 96652, 96656, 96659 },
            note = {
                en = "Sit by a campfire for a rest bonus; Camping 101 unlocks the campfire kit.",
                ru = "Сядь у костра — бонус к отдыху; Camping 101 открывает походный набор.",
            },
            src = "forever_db sort -666; https://www.wowhead.com/forever/quest=96604", v = false,
        },
        {
            key = "sleeping-bag",
            name = { en = "Cozy Sleeping Bag", ru = "Уютный спальный мешок" },
            q = { 79007, 79192, 79980, 79974, 79975, 79976 },
            opt = { 80001 },
            after = { [79192] = 79007, [79980] = 79192, [79974] = 79980, [79975] = 79974, [79976] = 79975 },
            hint = { [79007] = { 1434, 30 }, [79974] = { 1437, 28 }, [79975] = { 1437, 28 } },
            note = {
                en = "A portable resting spot: bonus XP and rest anywhere. Every step starts at an object:"
                    .. " the Barrens, Westfall, Stonetalon, Loch Modan, Arathi.",
                ru = "Переносное место отдыха: +опыт, отдых где угодно. Каждый шаг начинается у предмета:"
                    .. " Степи, Западный Край, Когтистые горы, Лок Модан, Арати.",
            },
            src = "https://www.wowhead.com/forever/quest=79976;"
                .. " https://www.warcrafttavern.com/forever/guides/cozy-sleeping-bag/",
            v = false,
        },
        {
            key = "library",
            name = { en = "Undercity library", ru = "Библиотека Подгорода" },
            startObj = true,
            q = { 78124, 78127, 78142, 78143, 78145, 78146, 78147, 78148, 78149, 79091, 79092, 79093, 79094, 79095,
                79096, 79097, 79535, 79947, 79948, 79949, 79950, 79951, 79952, 79953, 81947, 81949, 81951, 81952,
                81953, 81954, 81955, 81956, 84395, 84396, 84397, 84398, 84399, 84400, 84401, 84402,
                78150, 79536, 82208 },
            cnt = { [78150] = 10, [79536] = 20, [82208] = 25 },
            note = {
                en = "Books lie all over the world: pick them up and bring them to the Undercity library."
                    .. " 10, 20 and 25 books earn the Friend of the Library rewards.",
                ru = "Книги лежат по всему миру: подбери и отнеси в библиотеку Подгорода."
                    .. " За 10, 20 и 25 книг — награды «Друг библиотеки».",
            },
            src = "https://www.warcrafttavern.com/forever/guides/library-books/", v = false,
        },
    },
    titles = {},
    exclude = {
        [96339] = "Legacy Reward (account cosmetic)",
        [96383] = "Legacy Reward (account cosmetic)",
        [95819] = "Sign Me Up! (crates system)",
        [76156] = "Stalk With The Earthmother: judged unreleased (Mulgore/02 header)",
        [76160] = "Stalk With The Earthmother: judged unreleased (Mulgore/02 header)",
        [76240] = "Stalk With The Earthmother: judged unreleased (Mulgore/02 header)",
    },
    opt = {
        [78132] = "SoD carry-over, unconfirmed in Forever",
        [78133] = "SoD carry-over, unconfirmed in Forever",
        [78134] = "SoD carry-over, unconfirmed in Forever",
        [79229] = "SoD carry-over, unconfirmed in Forever",
    },
}
