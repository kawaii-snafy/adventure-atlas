-- tools/data/narrative.lua -- curated input of the narrative goals (maintained by hand).
--
-- Read by tools/lib/goals.lua (Goals.LoadCurated: local constants, then one `return { ... }`, run in an EMPTY
-- environment) when tools/gen_knowledge_data.lua builds the `goals` of addons/AdventureAtlas_Knowledge/Quests.lua.
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
--       note = { en, ru },                  -- keys, attunements (needs src, v)
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
--       use = { { i = { itemID }, n = { npcID } | nil, t = { en, ru } } } | nil, -- an item of i in the bags:
--                                           -- "<item>: t -- nearest of n"; with use, q may be {} (no bar)
--       src = "...", v = false,
--   } },
--   professions = { [skillLineID] = {       -- one entry per skill line the profession goals "p<line>" need
--       name = { en, ru }, note = { en, ru } | nil,
--       sec = true | nil,                   -- secondary (First Aid, Cooking, Fishing): at most 2 train tiers
--       nolv = true | nil,                  -- rank-ups need no character level (Cooking, First Aid)
--       train = { { n = { npcIDs } }, { n = { npcIDs }, i = itemID } },  -- by tier; i: a book the NPCs sell
--       blueprints = { { i = itemID, need = skill, d = areaID, n = npcID | nil } },
--       brackets = { { lo, hi, i = { itemIDs } | nil, m = { uiMapIDs } | nil } }, -- ordered by lo
--       src = "...", v = false,
--   } },
--   titles = { [goal id] = { en, ru } },    -- title overrides, only for titles that read badly in game
--   exclude = { [questID] = "reason" },     -- left out of every goal
--   opt = { [questID] = "reason" },         -- optional in the goal it falls into
-- The generator checks the profession and use records against the snapshot (tools/lib/goals.lua): every
-- NPC known and not Alliance; trainers flagged trainer, book sellers vendor; a rank word in a trainer's
-- subtitle matches the tier (Expert = 1, Artisan = 2, Master = 3); blueprint dungeons in db.dungeons, bracket maps in db.zones, use NPCs with a spawn. Item ids were checked
-- at https://forever.warcraftdb.com/api/data/node/item/<id> (crafted items through the recipe spell's
-- created item). The goal fields are documented in the header of tools/gen_knowledge_data.lua; the fields
-- stages 2 and 3 added (the same block is in tools/gen_knowledge_data.lua and Core/Knowledge.lua):
--   a = "story" | "dungeon" | "class" | "novelty" | "profession"
--   id: "p<skillLineID>" = profession goal (generated); "n:finds" = the finds container (curated key "finds", reserved)
--   line = 182,                      -- profession goals: skill line id (db.enums.professions)
--   sec = true,                      -- profession goals: secondary (First Aid, Cooking, Fishing): no tier 3 (a quest)
--   nolv = true,                     -- profession goals: rank-ups need no character level (Cooking, First Aid)
--   train = { { n = { npcIDs } }, { n = { npcIDs }, i = itemID }, { n = { npcIDs } } },
--                                    -- profession goals, indexed by tier (Narrative TIERS: 1 = 75->150, 2 = 150->225,
--                                    --   3 = 225->300): trainers, or with i a book the NPCs sell; a tier may be absent
--                                    --   (nil hole not allowed: tiers are a prefix, 1..#train)
--   blueprints = { { i = itemID, need = 140, d = areaID, n = npcID | nil } },
--                                    -- profession goals: camp blueprint, skill to learn it, dungeon, boss (when in the DB)
--   brackets = { { lo = 50, hi = 70, i = { itemIDs } | nil, m = { uiMapIDs } | nil } },
--                                    -- profession goals, ordered by lo: at skill lo..hi-1 gather / make i, found in m
--                                    --   (at least one of i, m)
--   use = { { i = { itemIDs }, n = { npcIDs } | nil, t = { en = "", ru = "" } } },
--                                    -- curated goals: an item of i in the bags -> "<item>: t -- nearest of n"
--   note = { en, ru }                -- also on dungeon goals now (curated)
--   q = { }                          -- empty only for a goal with `use` (n:finds): never listed (state "none"), no bar;
--                                    --   lo = 1, hi = 60

-- uiMapIDs of the brackets (db.zones)
local DUROTAR, MULGORE, TIRISFAL, ZEPHRAS = 1411, 1412, 1420, 2521
local ORGRIMMAR, THUNDER_BLUFF, UNDERCITY = 1454, 1456, 1458
local BARRENS, STONETALON, ASHENVALE, SILVERPINE, HILLSBRAD = 1413, 1442, 1440, 1421, 1424
local NEEDLES, DESOLACE, DUSTWALLOW, STV, ARATHI, ALTERAC = 1441, 1443, 1445, 1434, 1417, 1416
local WETLANDS, DUSKWOOD, SWAMP, BADLANDS, TANARIS, FERALAS = 1437, 1431, 1435, 1418, 1446, 1444
local HINTERLANDS, SEARING_GORGE, BLASTED_LANDS, FELWOOD, AZSHARA = 1425, 1427, 1419, 1448, 1447
local UNGORO, WINTERSPRING, SILITHUS, WPL, EPL, BURNING_STEPPES = 1449, 1452, 1451, 1422, 1423, 1428
-- sources shared by the crafting / gathering entries
local TRAINERS = "https://www.warcrafttavern.com/forever/guides/profession-trainers/; forever_db npc subName"
local CAMPING = "https://www.wow-professions.com/forever/camping-guide;"
    .. " https://www.warcrafttavern.com/forever/guides/camping-objects-buffs/"
local function crafting(slug)
    return TRAINERS .. "; https://www.wow-professions.com/forever/" .. slug .. "-leveling-guide; " .. CAMPING
end
local function gathering(slug, extra)
    return TRAINERS .. "; https://wow.gg/professions/forever/" .. slug .. "; " .. CAMPING .. (extra or "")
end
-- the camp line of every profession but Cooking (wow-professions camping guide, warcrafttavern camping), with the
-- skill of the profession's blueprint
local function campEn(need)
    return "Skill 20: camp item from the trainer or Camping 101; " .. need .. ": a blueprint (below)."
end
local function campRu(need)
    return "Навык 20: предмет лагеря у учителя или в Camping 101; " .. need .. ": чертёж (ниже)."
end
local CAMP_EN, CAMP_RU = campEn(140), campRu(140)

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
        [16544] = {
            lo = 28, hi = 33,
            note = {
                en = "The Dalaran Sewer Key comes with Heart of Disruption (Image of Archmage Modera, Alterac"
                    .. " Mountains): it is your way into the city.",
                ru = "Dalaran Sewer Key выдают с заданием Heart of Disruption (Image of Archmage Modera,"
                    .. " Альтеракские горы): это вход в город.",
            },
            src = "https://warcraft.wiki.gg/wiki/Forever; https://warcraft.wiki.gg/wiki/Heart_of_Disruption"
                .. " (item 277507, quest 96984)",
            v = false,
        },
        [796] = {                         -- Scarlet Monastery
            note = {
                en = "The Scarlet Key from the chest behind Arcanist Doan (Library) opens the Armory and the"
                    .. " Cathedral; a party member who has it can open them for you.",
                ru = "The Scarlet Key из сундука за Arcanist Doan (Библиотека) открывает Оружейную и Собор;"
                    .. " открыть может и спутник с ключом.",
            },
            src = "https://www.warcrafttavern.com/forever/guides/scarlet-monastery/ (item 7146)", v = false,
        },
        [722] = {},                       -- Razorfen Downs
        [1337] = { areas = { 1517 } },    -- Uldaman
        [1176] = {                        -- Zul'Farrak
            areas = { 978 },
            note = {
                en = "Gahz'rilla needs the Mallet of Zul'Farrak: the Sacred Mallet from Qiaga the Keeper (Altar of"
                    .. " Zul, the Hinterlands), used at the altar of Jintha'Alor. Killing him (Gahz'rilla quest)"
                    .. " gives Carrot on a Stick.",
                ru = "Для Gahz'rilla нужен Mallet of Zul'Farrak: Sacred Mallet с Qiaga the Keeper (Altar of Zul,"
                    .. " Внутренние земли) освящают на алтаре Jintha'Alor. За его убийство (задание Gahz'rilla) —"
                    .. " Carrot on a Stick.",
            },
            src = "https://warcraft.wiki.gg/wiki/Mallet_of_Zul%27Farrak (item 9240); WDB quest 2770 (item 11122)",
            v = false,
        },
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
        {
            -- slotless (q = {}): no bar, only hints in "where now"; a quest item in the bags needs no data here
            -- (the start rule of Core/Narrative.lua covers every quest that starts from an item, e.g. 98248)
            key = "finds",
            name = { en = "Finds", ru = "Находки" },
            q = {},
            use = {
                {   -- filled crates: forever_db quests 91899-91905 ask for them (248767, 248772: forever.warcraftdb.com
                    -- quests 91901 / 91906)
                    i = { 248765, 248766, 248767, 248770, 248771, 248772 }, n = { 256386 },
                    t = { en = "turn it in", ru = "сдай" },
                },
                {   -- crates still to fill (forever.warcraftdb.com item names "Waylaid Crate: ...")
                    i = {
                        248549, 248682, 248683, 248684, 248685, 248686, 248687, 248688, 248689, 248690, 248691, 248692,
                        248693, 248694, 248695, 248696, 248697, 248698, 248699, 248702, 248703, 248704, 248705, 248706,
                        248707, 248708, 248709, 248710, 248711, 248712, 248713
                    },
                    n = { 256386 },
                    t = {
                        en = "fill it (see its tooltip), then turn it in",
                        ru = "наполни (см. подсказку предмета) и сдай",
                    },
                },
            },
            note = {
                en = "Waylaid Crates drop in the open world (or come from the Auction House): fill one with the"
                    .. " materials it asks for and bring the sealed crate to Dokimi (Durotar Supply and Logistics,"
                    .. " the Crossroads) for Merchant's Favor, the camp vendors' currency.",
                ru = "Waylaid Crate падают в мире (или есть на аукционе): наполни ящик нужными материалами и"
                    .. " отнеси запечатанный Dokimi (Durotar Supply and Logistics, Перекресток) — за Merchant's"
                    .. " Favor, валюту торговцев лагеря.",
            },
            src = "forever_db quests 91899-91905 objectives, npc 256386;"
                .. " https://forever.warcraftdb.com/api/data/node/quest/91901, /91906 (items 248767, 248772);"
                .. " https://www.wow-professions.com/forever/merchants-favor-durotar-supply-azeroth-commerce;"
                .. " https://www.method.gg/wow-forever/how-to-get-waylaid-crates-and-merchants-favor-in-wow-forever",
            v = false,
        },
    },
    -- One entry per skill line (the goal "p<line>" takes its quests from the snapshot). train tiers: 1 = 75 -> 150,
    -- 2 = 150 -> 225, 3 = 225 -> 300 (Core/Narrative.lua TIERS); the gathering trainers teach every rank
    -- (wow.gg "Up to Skill 300", warcrafttavern profession-trainers "Artisan"; the 75-cap trainers of the starting
    -- areas are new NPCs outside the data), so tiers 2 / 3 repeat tier 1. Blueprints: the tier-2 camp blueprint
    -- and the boss that drops it (wow-professions camping guide, warcrafttavern camping objects); the skill is
    -- the one of the recipe spell at https://forever.warcraftdb.com/api/data/node/spell/<id>. Brackets: one row per leveling step of the cited guide (crafting: the made items, merged where a
    -- guide has more than ~15 steps; gathering: the herb / ore and the Horde-reachable zones the guide names).
    professions = {
        [171] = {
            name = { en = "Alchemy", ru = "Алхимия" },
            note = { en = CAMP_EN, ru = CAMP_RU },
            train = { { n = { 3347, 3009, 4609, 2391 } }, { n = { 4611 } }, { n = { 1386 } } },
            blueprints = { { i = 273085, need = 140, d = 16611, n = 250657 } },  -- Fermenter, Rath'mael
            brackets = {
                { lo = 1, hi = 10, i = { 247755 } }, { lo = 10, hi = 55, i = { 5997 } },
                { lo = 55, hi = 65, i = { 2455 } }, { lo = 65, hi = 90, i = { 2458 } },
                { lo = 90, hi = 120, i = { 3383 } }, { lo = 120, hi = 130, i = { 3385 } },
                { lo = 130, hi = 150, i = { 6371, 3385 } }, { lo = 150, hi = 165, i = { 6373, 3385 } },
                { lo = 165, hi = 195, i = { 3827 } }, { lo = 195, hi = 235, i = { 6052 } },
                { lo = 235, hi = 250, i = { 9179 } }, { lo = 250, hi = 260, i = { 13423 } },
                { lo = 260, hi = 265, i = { 9179 } }, { lo = 265, hi = 300, i = { 13445, 13443 } },
            },
            src = crafting("alchemy"), v = false,
        },
        [164] = {
            name = { en = "Blacksmithing", ru = "Кузнечное дело" },
            note = { en = CAMP_EN, ru = CAMP_RU },
            train = { { n = { 1383, 2998, 4596, 3478 } }, { n = { 3355 } }, { n = { 2836 } } },
            blueprints = { { i = 273086, need = 140, d = 1581, n = 1763 } },   -- Anvil, Gilnid
            brackets = {
                { lo = 1, hi = 25, i = { 2862 } }, { lo = 25, hi = 50, i = { 3470 } },
                { lo = 50, hi = 75, i = { 3478 } }, { lo = 75, hi = 100, i = { 6338, 2857, 2868 } },
                { lo = 100, hi = 125, i = { 3486, 2868 } }, { lo = 125, hi = 150, i = { 2850, 7956, 2868 } },
                { lo = 150, hi = 175, i = { 3835 } }, { lo = 175, hi = 195, i = { 7966, 6040 } },
                { lo = 195, hi = 215, i = { 7920, 7941 } }, { lo = 215, hi = 225, i = { 7930, 7969 } },
                { lo = 225, hi = 240, i = { 12404, 7933, 7969 } }, { lo = 240, hi = 270, i = { 12424, 12425 } },
                { lo = 270, hi = 300, i = { 12426, 12429 } },
            },
            src = crafting("blacksmithing"), v = false,
        },
        [333] = {
            name = { en = "Enchanting", ru = "Наложение чар" },
            note = {
                en = CAMP_EN .. " Most steps are enchants (no item): the brackets list only the rods and oils.",
                ru = CAMP_RU .. " Почти все шаги — чары (без предмета): в шагах только жезлы и масла.",
            },
            -- tier 3: Annora is inside Uldaman (no spawn in the snapshot: shown by name)
            train = { { n = { 3345, 3011, 4616 } }, { n = { 11074 } }, { n = { 11073 } } },
            blueprints = { { i = 273103, need = 140, d = 16544, n = 246020 } }, -- Arcane Salvager, Shade of the Archmage
            brackets = {
                { lo = 1, hi = 2, i = { 6218 } }, { lo = 109, hi = 110, i = { 6339 } },
                { lo = 150, hi = 151, i = { 11130 } }, { lo = 151, hi = 165, i = { 20745 } },
                { lo = 200, hi = 201, i = { 11145 } }, { lo = 201, hi = 220, i = { 20746 } },
                { lo = 250, hi = 265, i = { 20747 } }, { lo = 299, hi = 300, i = { 16207 } },
            },
            src = crafting("enchanting"), v = false,
        },
        [202] = {
            name = { en = "Engineering", ru = "Инженерное дело" },
            note = { en = CAMP_EN, ru = CAMP_RU },
            train = { { n = { 3412, 11031 } }, { n = { 11017 } }, { n = { 8736 } } },
            blueprints = { { i = 273092, need = 140, d = 1581, n = 643 } },    -- Repair Bot, Sneed
            brackets = {
                { lo = 1, hi = 30, i = { 4357 } }, { lo = 30, hi = 51, i = { 4359, 6219 } },
                { lo = 51, hi = 75, i = { 4360 } }, { lo = 75, hi = 100, i = { 4364, 4365 } },
                { lo = 100, hi = 125, i = { 4404, 4368, 4371 } }, { lo = 125, hi = 150, i = { 4406, 4377, 4375 } },
                { lo = 150, hi = 175, i = { 4382, 4384 } }, { lo = 175, hi = 200, i = { 10505, 10498, 10559 } },
                { lo = 200, hi = 215, i = { 10560 } }, { lo = 215, hi = 238, i = { 10561 } },
                { lo = 238, hi = 250, i = { 10562 } }, { lo = 250, hi = 260, i = { 15992 } },
                { lo = 260, hi = 285, i = { 15994 } }, { lo = 285, hi = 300, i = { 16000 } },
            },
            src = crafting("engineering"), v = false,
        },
        [165] = {
            name = { en = "Leatherworking", ru = "Кожевничество" },
            note = { en = campEn(125), ru = campRu(125) },
            train = { { n = { 3365, 11084, 4588, 3703, 1385, 8153 } }, { n = { 3007 } }, { n = { 11098 } } },
            -- Tanning Rack: spell 1263031 "Leatherworking (125)" (wow-professions 125; warcrafttavern says 140)
            blueprints = { { i = 273096, need = 125, d = 209, n = 3886 } },    -- Razorclaw the Butcher
            brackets = {
                { lo = 1, hi = 30, i = { 2318 } }, { lo = 30, hi = 55, i = { 4231 } },
                { lo = 55, hi = 75, i = { 4239 } }, { lo = 75, hi = 90, i = { 2319, 4233 } },
                { lo = 90, hi = 100, i = { 4246 } }, { lo = 100, hi = 115, i = { 7282 } },
                { lo = 115, hi = 125, i = { 4249 } }, { lo = 125, hi = 143, i = { 4234, 4236 } },
                { lo = 143, hi = 155, i = { 4247 } }, { lo = 155, hi = 170, i = { 5964 } },
                { lo = 170, hi = 185, i = { 5966 } }, { lo = 185, hi = 195, i = { 5739 } },
                { lo = 195, hi = 205, i = { 8176 } }, { lo = 205, hi = 235, i = { 8193 } },
                { lo = 235, hi = 265, i = { 15083, 252467 } }, { lo = 265, hi = 300, i = { 15094, 252482 } },
            },
            src = crafting("leatherworking"), v = false,
        },
        [197] = {
            name = { en = "Tailoring", ru = "Портняжное дело" },
            note = { en = CAMP_EN, ru = CAMP_RU },
            train = { { n = { 3363, 3004, 11049, 3704 } }, { n = { 4576 } }, { n = { 2399 } } },
            -- Spinning Wheel drops from the Unstable Sentinel (npc 246017, not in the snapshot)
            blueprints = { { i = 273099, need = 140, d = 16544 } },
            brackets = {
                { lo = 1, hi = 30, i = { 2996 } }, { lo = 30, hi = 55, i = { 7026 } },
                { lo = 55, hi = 80, i = { 2997 } }, { lo = 80, hi = 100, i = { 2584, 4314 } },
                { lo = 100, hi = 120, i = { 4305 } }, { lo = 120, hi = 140, i = { 4318 } },
                { lo = 140, hi = 150, i = { 4339 } }, { lo = 150, hi = 170, i = { 7058 } },
                { lo = 170, hi = 190, i = { 7062 } }, { lo = 190, hi = 205, i = { 9999, 10027 } },
                { lo = 205, hi = 225, i = { 14048, 10050, 13856 } }, { lo = 225, hi = 240, i = { 13856 } },
                { lo = 240, hi = 250, i = { 13863 } }, { lo = 250, hi = 280, i = { 254123 } },
                { lo = 280, hi = 300, i = { 13867, 14130 } },
            },
            src = crafting("tailoring"), v = false,
        },
        [182] = {
            name = { en = "Herbalism", ru = "Травничество" },
            note = {
                en = "Forever adds new herbs and herb seeds. " .. CAMP_EN,
                ru = "В Forever есть новые травы и семена. " .. CAMP_RU,
            },
            train = {
                { n = { 3404, 3013, 4614, 8146, 2390, 3185, 2856 } },
                { n = { 3404, 3013, 4614, 8146, 2390, 3185, 2856 } },
                { n = { 3404, 3013, 4614, 8146, 2390, 3185, 2856 } },
            },
            blueprints = { { i = 273106, need = 140, d = 16732, n = 260325 } }, -- Greenhouse, Shadetooth
            brackets = {
                { lo = 1, hi = 15, i = { 2447, 765 }, m = { BARRENS, DUROTAR, MULGORE, TIRISFAL } },
                { lo = 15, hi = 50, i = { 2449 }, m = { BARRENS, DUROTAR, TIRISFAL } },
                { lo = 50, hi = 70, i = { 785 }, m = { BARRENS, ASHENVALE } },
                { lo = 70, hi = 85, i = { 2450 }, m = { BARRENS, DUSKWOOD, ASHENVALE } },
                { lo = 85, hi = 100, i = { 3820 }, m = { STV, WETLANDS, ASHENVALE } },
                { lo = 100, hi = 115, i = { 2453 }, m = { STONETALON, BARRENS, HILLSBRAD, WETLANDS } },
                { lo = 115, hi = 120, i = { 3355 }, m = { ARATHI, STONETALON, STV, WETLANDS } },
                { lo = 120, hi = 125, i = { 3369 }, m = { DUSKWOOD, DESOLACE, WETLANDS, ARATHI } },
                { lo = 125, hi = 150, i = { 3356 }, m = { STV, WETLANDS, ASHENVALE, HILLSBRAD } },
                { lo = 150, hi = 160, i = { 3357 }, m = { STV, WETLANDS, ARATHI, ALTERAC } },
                { lo = 160, hi = 170, i = { 3818 }, m = { ARATHI, SWAMP, ALTERAC, STV } },
                { lo = 170, hi = 185, i = { 3821 }, m = { STV, ARATHI, SWAMP, ALTERAC } },
                { lo = 185, hi = 195, i = { 3358 }, m = { STV, ARATHI, SWAMP, ALTERAC } },
                { lo = 195, hi = 205, i = { 3819 }, m = { ALTERAC } },
                { lo = 205, hi = 210, i = { 4625 }, m = { TANARIS, SEARING_GORGE, BADLANDS } },
                { lo = 210, hi = 220, i = { 8831 }, m = { AZSHARA, HINTERLANDS, TANARIS, FERALAS } },
                { lo = 220, hi = 230, i = { 8836 }, m = { WPL, EPL, FELWOOD } },
                { lo = 230, hi = 235, i = { 8838 }, m = { AZSHARA, HINTERLANDS, FERALAS, EPL } },
                { lo = 235, hi = 245, i = { 8839 }, m = { SWAMP, UNGORO } },
                { lo = 245, hi = 250, i = { 8845 }, m = { HINTERLANDS, DESOLACE } },
                { lo = 250, hi = 260, i = { 8846 }, m = { FELWOOD, DESOLACE } },
                { lo = 260, hi = 270, i = { 13464 }, m = { UNGORO, AZSHARA, EPL, FELWOOD } },
                { lo = 270, hi = 280, i = { 13463 }, m = { AZSHARA, EPL, UNGORO, FELWOOD } },
                { lo = 280, hi = 285, i = { 13465 }, m = { WINTERSPRING, UNGORO, AZSHARA, BURNING_STEPPES } },
                { lo = 285, hi = 290, i = { 13466 }, m = { EPL, WPL } },
                { lo = 290, hi = 300, i = { 13467 }, m = { WINTERSPRING } },
            },
            src = gathering("herbalism", "; https://www.warcrafttavern.com/forever/guides/herbalism/"), v = false,
        },
        [186] = {
            name = { en = "Mining", ru = "Горное дело" },
            note = {
                en = "Only the first successful mine of a vein gives a skill point; Forever adds new ores. " .. CAMP_EN,
                ru = "Очко навыка даёт только первая удачная добыча из жилы; в Forever есть новые руды. " .. CAMP_RU,
            },
            train = {
                { n = { 3357, 3001, 4598, 3175, 3555, 8128 } },
                { n = { 3357, 3001, 4598, 3175, 3555, 8128 } },
                { n = { 3357, 3001, 4598, 3175, 3555, 8128 } },
            },
            blueprints = { { i = 273097, need = 140, d = 16732, n = 260326 } }, -- Rock Garden, Relic Guardian
            brackets = {
                { lo = 1, hi = 65, i = { 2770 }, m = { DUROTAR, DUSKWOOD, SILVERPINE } },
                { lo = 65, hi = 75, i = { 2771 }, m = { WETLANDS, DUSKWOOD, SILVERPINE } },
                { lo = 75, hi = 125, i = { 2775 }, m = { ARATHI, ALTERAC, STV, WETLANDS } },
                { lo = 125, hi = 155, i = { 2772 }, m = { ARATHI, ALTERAC, STV, DUSKWOOD } },
                { lo = 155, hi = 175, i = { 2776 }, m = { ARATHI, ALTERAC, STV, DUSKWOOD } },
                { lo = 175, hi = 230, i = { 3858 }, m = { BADLANDS, HINTERLANDS, ALTERAC, SEARING_GORGE } },
                { lo = 230, hi = 245, i = { 7911, 11370 }, m = { BADLANDS, HINTERLANDS, ALTERAC, SEARING_GORGE } },
                { lo = 245, hi = 275, i = { 10620 }, m = { WINTERSPRING, SWAMP, BLASTED_LANDS } },
                { lo = 275, hi = 300, i = { 10620 }, m = { WINTERSPRING, AZSHARA } },
            },
            src = gathering("mining", "; https://www.warcrafttavern.com/forever/guides/mining/"), v = false,
        },
        [393] = {
            name = { en = "Skinning", ru = "Снятие шкур" },
            note = { en = CAMP_EN, ru = CAMP_RU },
            train = {
                { n = { 7088, 7089, 7087, 6387, 12030, 8144, 6290, 6289 } },
                { n = { 7088, 7089, 7087, 6387, 12030, 8144, 6290, 6289 } },
                { n = { 7088, 7089, 7087, 6387, 12030, 8144, 6290, 6289 } },
            },
            blueprints = { { i = 273098, need = 140, d = 718, n = 3671 } },    -- Field Guide, Lady Anacondra
            -- beasts by level (skill = (level - 10) x 10 at 11-20, level x 5 from 21): zones only
            brackets = {
                { lo = 1, hi = 10, m = { MULGORE, DUROTAR } },
                { lo = 10, hi = 105, m = { BARRENS, SILVERPINE } },
                { lo = 105, hi = 155, m = { WETLANDS, ASHENVALE, HILLSBRAD, NEEDLES } },
                { lo = 155, hi = 205, m = { DUSTWALLOW, DESOLACE, STV, BADLANDS } },
                { lo = 205, hi = 255, m = { TANARIS, FERALAS, HINTERLANDS, FELWOOD } },
                { lo = 255, hi = 300, m = { WINTERSPRING, AZSHARA, SILITHUS, EPL } },
            },
            src = gathering("skinning"), v = false,
        },
        [185] = {
            name = { en = "Cooking", ru = "Кулинария" },
            note = {
                en = "The campfire is an item: the Basic Campfire Kit comes with Cooking; bigger fires need a blueprint"
                    .. " (below).",
                ru = "Костёр — предмет: простой набор для костра дают вместе с кулинарией; для больших — чертёж"
                    .. " (ниже).",
            },
            sec = true,
            nolv = true,                      -- the cited guide: Journeyman Cooking needs Cooking 50 only
            train = {
                { n = { 3399, 3026, 4552, 265944, 3067, 8306, 1382, 256655 } },
                { n = { 12033 }, i = 16072 },                                  -- Expert Cookbook from Wulan
            },
            blueprints = {
                { i = 273087, need = 90, d = 718, n = 3673 },                  -- Journeyman Campfire, Lord Serpentis
                { i = 273102, need = 140, d = 1581, n = 645 },                 -- Cookie's Feast, Cookie
            },
            brackets = {
                { lo = 1, hi = 50, i = { 6290, 787, 2679 } }, { lo = 50, hi = 100, i = { 4592, 5095, 5477 } },
                { lo = 100, hi = 130, i = { 4593 } }, { lo = 130, hi = 175, i = { 5527, 3665, 3727 } },
                { lo = 175, hi = 225, i = { 12210, 8364, 3729 } }, { lo = 225, hi = 300, i = { 6887, 13930, 13932 } },
            },
            src = crafting("cooking"), v = false,
        },
        [356] = {
            name = { en = "Fishing", ru = "Рыбная ловля" },
            note = { en = CAMP_EN, ru = CAMP_RU },
            sec = true,
            -- no nolv: Journeyman Fishing needs level 10, the Expert book level 20 (wow-professions fishing
            -- guide; forever.warcraftdb.com item 16083 required_level 20)
            train = {
                { n = { 3332, 3028, 4573, 5941, 5938, 5690, 12032, 12961 } },
                { n = { 2626 }, i = 16083 },                                   -- Expert Fishing - The Bass and You
            },
            -- Fishing Rack drops from Gelihast (npc 6243, not in the snapshot)
            blueprints = { { i = 273141, need = 140, d = 719 } },
            brackets = {
                { lo = 1, hi = 75, m = { DUROTAR, MULGORE, TIRISFAL, ZEPHRAS } },
                { lo = 75, hi = 150, m = { ORGRIMMAR, UNDERCITY, THUNDER_BLUFF, BARRENS, SILVERPINE } },
                { lo = 150, hi = 225, m = { DUSTWALLOW, ALTERAC, ARATHI, DESOLACE, STV, SWAMP, NEEDLES } },
                { lo = 225, hi = 300, m = { FELWOOD, FERALAS, HINTERLANDS, TANARIS, UNGORO, WPL } },
            },
            src = crafting("fishing"), v = false,
        },
        [129] = {
            name = { en = "First Aid", ru = "Первая помощь" },
            note = {
                en = "In Forever First Aid also makes the healing potions. " .. CAMP_EN,
                ru = "В Forever первая помощь делает и лечебные зелья. " .. CAMP_RU,
            },
            sec = true,
            nolv = true,                      -- the cited guide: the book has no level requirement
            train = {
                { n = { 3373, 2798, 4591, 5943, 5939, 5759 } },
                { n = { 13476 }, i = 16084 },                                  -- Expert First Aid - Under Wraps
            },
            -- Toxin Study drops from Commander Springvale (npc 4278, not in the snapshot)
            blueprints = { { i = 273105, need = 140, d = 209 } },
            brackets = {
                { lo = 1, hi = 40, i = { 1251, 118 } }, { lo = 40, hi = 75, i = { 2581, 118 } },
                { lo = 75, hi = 80, i = { 2581 } }, { lo = 80, hi = 115, i = { 3530 } },
                { lo = 115, hi = 150, i = { 3531 } }, { lo = 150, hi = 180, i = { 6450 } },
                { lo = 180, hi = 210, i = { 6451 } }, { lo = 210, hi = 240, i = { 8544 } },
                { lo = 240, hi = 260, i = { 8545 } }, { lo = 260, hi = 275, i = { 14529 } },
                { lo = 275, hi = 300, i = { 13446 } },
            },
            src = crafting("first-aid") .. "; https://www.warcrafttavern.com/forever/guides/first-aid/", v = false,
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
        -- weaponsmith masters: one of the three, choosing one closes the others (forever.warcraftdb.com quest 5305
        -- text); the snapshot does not link them
        [5305] = "hammersmith: one of 5305 / 5306 / 5307 (weaponsmiths only)",
        [5306] = "axesmith: one of 5305 / 5306 / 5307 (weaponsmiths only)",
        [5307] = "swordsmith: one of 5305 / 5306 / 5307 (weaponsmiths only)",
    },
}
