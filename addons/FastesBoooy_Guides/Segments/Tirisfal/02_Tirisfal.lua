-- FastesBoooy_Guides / Segments / Tirisfal / 02_Tirisfal.lua
--
-- Segment ud-02-tirisfal: Deathknell exit road -> Brill hub -> rest of Tirisfal Glades ->
-- Bandarion Keep -> Brill -> Undercity -> the road to Silverpine Forest, levels 6-13.
-- Class-neutral: every Undead class walks these steps. What exists because of a class (class quests,
-- training, class gear) is a shared insert of Classes/<Class>.lua on the anchors below.
-- Coordinates: Forever uiMap 1420 (Tirisfal Glades) / 1458 (Undercity), map percent, from
-- tools/data/forever_db.lua (NPC/object spawns; centroids of the objective mob/object spawns
-- for complete steps).
--
-- Hub plan (Forever DB). Every goal is a step of its own, in the order of play; where the mobs of a goal are
-- passed earlier, the notes say "on the way" and a later step at the last pass finishes it.
--   road  : 365 Simmer, 5481 Gordo (gloom weed on the walk to Brill).
--   Brill1: 86784, 96656 > 96607 > 96658 (camping), 383 > 427/99141/99134 (the motivator on the Deathguards
--           around Zygand), 367, Dillinger: 404 + his report, 8 + hearth; Kristof's report + 97558 at the Rear
--           Guard camp.
--   west  : 404 claws (Rotting Dead west of Brill), Gordo's report, 365 pumpkins, 97558 murloc skins, 427 Scarlet
--           Warriors, 99144 escort, 367 + 97558 hides and membranes (darkhounds and duskbats north-east of the
--           farm); hearth back.
--   Brill2: 367/365 > 368/407, 427/99141/99134 > 370, 398, 99144, 374, 358, 407, 354/362/375 (inn),
--           404 > 426, 5481 > 5482.
--   north : 5482 doom weed and 358 gnolls (same fields), 398 Maggot Eye, 368 coast murlocs, Agamand Mills
--           east > north > west > south (354, 362, 426, 361), 375 pelts on the way back.
--   Brill3: 5482 > 99142, 426, 368 > 369, 398, 361, 354/362 > 355, 375, 358/355 > 359.
--   south : 370 Captain Perrine, 374 rings. Brill4: 370 > 371, level 10, 96895.
--   east  : 97558, 359 > 360/356, 96895 > 96897/96898 > 96899, 356 + 99142 (Balnir), 371 + 374,
--           369 spiders, 374 finished, 356. Brill5: 369 > 492/445, 95314, 371, 374, 360, 492, 99142.
--   BK    : 96899 > 96896 > 98545; 99152, 99153, 95314 (Shadowvale: bottles, crystal, bones on the way
--           back); level 12.
--   UC    : hearth to Brill, 95314, Undercity: 98545 Glix, flight path; out to the Silverpine road.
-- Skipped: 405/357/366 (Undercity <-> Gunther back-and-forth), 408 (needs a second Agamand trip),
--   372 (far north-east), 99156 Riptear and 95328 Whispering Horror (elites), other Camping 101 quests.
-- Carried into the next segment: 445 (Delivery to Silverpine Forest, turned in at the Sepulcher).
-- Hearthstone: set in Brill on the first visit; used after the west loop and from Bandarion Keep.
--
-- Hand-over to h-13-silverpine (docs/dev/PLAN.md B.2): on the Silverpine road, level 12 or more (the gate
-- ud02-lvl-12), 445 in the log, 96895 > 96897 / 96898 done, hearthstone bound in Brill, flight point Undercity.
--
-- Anchors for class files (docs/dev/PLAN.md C.2; level of the base profile before the step, normal run / worst
-- case where it differs). The trainers of five classes (warrior, rogue, priest, mage, warlock) stand in the
-- Brill inn, so the Brill anchors are the steps in the inn:
--   ud02-sethearth        6.37 / 6.30  bind in the inn (level 6: gate ud02-lvl-6): training at 6
--   ud02-brill-8          8.17 / 8.13  the level-8 visit, in the inn (Coleman, Gretchen): training at 8. Two generic
--                               steps of the visit follow on the way out of Brill (Dillinger, Holland); neither
--                               is at a trainer
--   ud02-level-10        10.15 / 10.07  generic gate in Brill, between Zygand and Terrence: training at 10,
--                               level-10 class quests
--   ud02-keep            11.67 / 11.60  first generic step at Bandarion Keep (Leonid, upstairs)
--   ud02-lvl-12          11.98 / 11.92  generic gate at the keep, before the hearth
--   ud02-hearth-2        12.00 / 12.01  back in the Brill inn: training at 12. ud02-carolai-2 (100 yd west of
--                               the inn) is the last generic quest step of this visit
--   ud02-fp-uc           12.09  Undercity, Trade Quarter, after the generic quest step of the city:
--                               trainers, weapon master, class quests
--   ud02-silverpine-road 12.09  last step
-- The paladin trainer Shari Stilwell stands outside the inn, next to the stables: 99144 (a quest for everyone)
-- is turned in to her at ud02-shari-99144, and 99152 is a quest of Hilda the Breaker, a paladin trainer at the
-- keep. The training inserts of the paladin file therefore follow these steps (and ud02-dillinger-report,
-- ud02-carolai-2: the steps next to Shari), not the inn anchors.
--
-- Level gates (docs/dev/PLAN.md B.8), all plain and class-neutral (kills of the base profile, normal / worst):
--   ud02-lvl-6     0 / 0  367 and 97558 need level 6; every class trains at 6 in Brill.
--   ud02-level-10  0 / 0  96895 needs level 10; every class trains at 10 in Brill.
--   ud02-lvl-12    2 / 8  trainer-hub gate before the hearth to Brill: the trainers in Brill and in the
--                         Undercity have new ranks at 12, and the first Silverpine quests need 12 (421, gate
--                         h13-lvl-12: 0 kills after this one).
if not FastesBoooy.AddLibraryInsert then return end
local _, ns = ...
FastesBoooy.AddLibrarySegment({
    id = "ud-02-tirisfal",
    title = { ru = "6-13 Тирисфальские леса", en = "6-13 Tirisfal Glades" },
    zone = "Tirisfal Glades",
    levels = { 6, 13 },
    steps = {
        ------------------------------------------------------------------
        -- Road to Brill (level 6)
        ------------------------------------------------------------------
        { id = "ud02-365", accept = 365, npc = 1519, at = { 1420, 40.91, 54.17 },
          note = { ru = "Стражник смерти Симмер на дороге в Брилл.",
                   en = "Deathguard Simmer on the road to Brill." } },
        { id = "ud02-gordo", accept = 5481, npc = 10666, at = { 1420, 43.06, 54.69 },
          note = { ru = "Гордо ходит по дороге между Мертвым Звоном и Бриллом — ищите его рядом.",
                   en = "Gordo walks the road between Deathknell and Brill - look for him nearby." } },
        -- 5481: the weed grows on both sides of the road all the way to Brill; the walk to Brill is the pass.
        { id = "ud02-gloom-weed-bg", complete = 5481, at = { 1420, 50.3, 53.7 },
          note = { ru = "По дороге на восток к Бриллу соберите 3 Мрачной травы: кусты растут по обе стороны дороги.",
                   en = "On the road east to Brill, pick 3 Gloom Weed: the plants grow on both sides of the "
                       .. "road." } },
        { id = "ud02-brill-gate", accept = 86784, npc = 1742, at = { 1420, 58.35, 51.42 },
          note = { ru = "Вход в Брилл: стражник смерти Бартоломью.",
                   en = "Brill entrance: Deathguard Bartholomew." } },
        { id = "ud02-branches", complete = 86784, at = { 1420, 56.9, 52.0 },
          note = { ru = "6 Сухих веток на земле у входа в Брилл.",
                   en = "6 Dry Branches on the ground around the Brill entrance." } },
        { id = "ud02-eleanor", turnin = { 86784, 96656 }, accept = 96607, npc = 265812, at = { 1420, 57.28, 55.49 },
          note = { ru = "Элинор Шеклтон в лагере к югу от дороги.",
                   en = "Eleanor Shackleton at the camp south of the road." } },
        { id = "ud02-campfire", complete = 96607, object = 460003, at = { 1420, 57.17, 55.55 },
          note = { ru = "Сядьте у костра (/sit) и ждите около минуты, пока не появится бафф отдыха.",
                   en = "Sit at the campfire (/sit) and wait about a minute for the rest buff." } },
        { id = "ud02-eleanor-2", turnin = 96607, accept = 96658, npc = 265812, at = { 1420, 57.28, 55.49 },
          note = { ru = "Элинор Шеклтон: следующее задание сдаётся у таверны Брилла.",
                   en = "Eleanor Shackleton: her next quest is turned in by the Brill inn." } },
        -- Requirement and trainer-hub gate: 367 (Johaan) and 97558 (Rear Guard camp) need level 6, and every
        -- class trains at 6 in Brill. The base profile is at 6.28 here (6.20 in the worst case, 0 kills), but
        -- about 1,700 XP of the way to it are the estimated XP of the three camp quests (86784, 96656, 96607):
        -- the gate is the guarantee. `at`: the Rotting Dead (5-6) and Ravaged Corpses (6-7) 120 yd west of the
        -- camp. They drop the claws of 404 only with the quest in the log, and Dillinger hands it out after this
        -- gate (ud02-dillinger-report): a grind here cannot finish ud02-putrid-claws early and make it the forward
        -- anchor that would count the training of the first Brill visit as done (validator: skip-ahead).
        { id = "ud02-lvl-6", level = 6, at = { 1420, 54.6, 55.6 },
          note = { ru = "6-й уровень перед Бриллом: он нужен для задания аптекаря Йохана, и у тренеров в Брилле "
                       .. "новые умения. Не хватает — гниющие мертвецы и растерзанные трупы к западу от лагеря.",
                   en = "Level 6 before Brill: Apothecary Johaan's quest needs it, and the trainers in Brill have "
                       .. "new ranks. Short: the Rotting Dead and Ravaged Corpses west of the camp." } },

        ------------------------------------------------------------------
        -- Brill, first visit (level 6)
        ------------------------------------------------------------------
        { id = "ud02-zygand-1", turnin = 383, accept = { 427, 99141, 99134 }, npc = 1515,
          at = { 1420, 60.59, 51.76 },
          note = { ru = "Палач Зиганд в центре Брилла.", en = "Executor Zygand in the middle of Brill." } },
        -- 99134: seven Deathguards stand within 60 yd of Zygand (by him, at the stables and by the inn).
        { id = "ud02-motivator-bg", complete = 99134, use = 286176, at = { 1420, 60.9, 52.3 },
          note = { ru = "Сразу здесь: используйте Мотиватор палача (кнопка предмета) на 5 стражниках смерти — они "
                       .. "стоят рядом с Зигандом, у конюшни и у таверны.",
                   en = "Right here: use the Executor's Motivator (item button) on 5 Deathguards - they stand next "
                       .. "to Zygand, at the stables and by the inn." } },
        { id = "ud02-johaan-1", accept = 367, npc = 1518, at = { 1420, 59.45, 52.40 },
          note = { ru = "Аптекарь Йохан (нужен 6-й уровень).", en = "Apothecary Johaan (needs level 6)." } },
        { id = "ud02-dillinger-report", complete = { [99141] = { 1 } }, accept = 404, npc = 1496,
          at = { 1420, 58.2, 51.45 },
          note = { ru = "Диллинджер у входа: возьмите его задание (гнилые когти — на западном круге) и попросите "
                       .. "отчёт для палача Зиганда (вариант диалога).",
                   en = "Dillinger at the entrance: take his quest (the Putrid Claws come on the west loop) and ask "
                       .. "for the report for Executor Zygand (gossip option)." } },
        { id = "ud02-sethearth", turnin = 8, sethearth = "Brill", npc = 5688, at = { 1420, 61.72, 52.05 },
          note = { ru = "Трактирщица Рене: сдайте письмо и сделайте таверну домом. В этой таверне стоят тренеры "
                       .. "большинства классов.",
                   en = "Innkeeper Renee: turn in the letter and make this inn your home. The trainers of most "
                       .. "classes stand in this inn." } },
        { id = "ud02-pickman", complete = 96658, turnin = 96658, npc = 265944, at = { 1420, 61.75, 51.44 },
          note = { ru = "Уильям Пикман у таверны: выучите кулинарию и сдайте задание.",
                   en = "William Pickman by the inn: learn Cooking and turn in." } },

        ------------------------------------------------------------------
        -- Rear Guard camp (Kristof, Shelene)
        ------------------------------------------------------------------
        { id = "ud02-rear-guard-1", complete = { [99141] = { 2 } }, accept = 97558, npc = { 251001, 3549 },
          at = { 1420, 65.34, 60.16 },
          note = { ru = "Лагерь к юго-востоку от Брилла: отчёт у Кристофа (вариант диалога), "
                       .. "задание у Шелены Робарт (шкуры собираются на западном круге).",
                   en = "Camp south-east of Brill: report from Deathguard Kristof (gossip option), "
                       .. "quest from Shelene Rhobart (the hides are collected on the west loop)." } },

        ------------------------------------------------------------------
        -- West loop: fields west of Brill, Solliden Farmstead (level 6-8)
        ------------------------------------------------------------------
        -- The darkhounds and duskbats of 367 and 97558 (objectives 1, 2) live all along this loop; the step that
        -- finishes them is ud02-darkhounds, the last field step before the hearth. 97558 objective 3 (murloc
        -- skins) is ud02-murloc-skins.
        -- 404: the Rotting Dead and Ravaged Corpses stand on the way from the Rear Guard camp west to Gordo. The
        -- `at` of the gate ud02-lvl-6 lies 70 yd from here, but the gate is met at the camp already (6.13 / 6.05
        -- before ud02-campfire), so the player does not walk there, and 404 is taken after the gate on purpose
        -- (see there): this is the first pass (travel-revisit).
        { id = "ud02-putrid-claws", complete = 404, at = { 1420, 53.3, 57.0 }, ok = "travel-revisit",
          note = { ru = "Гниющие мертвецы и растерзанные трупы на пути на запад: 7 гнилых когтей.",
                   en = "Rotting Dead and Ravaged Corpses on the way west: 7 Putrid Claws." } },
        { id = "ud02-gordo-report", complete = { [99141] = { 3 } }, npc = 10666, at = { 1420, 43.06, 54.69 },
          note = { ru = "Гордо на дороге на запад: отчёт для Зиганда (вариант диалога). По пути: гончие и ночные "
                       .. "мыши — кровь гончих (5) для Йохана, шкуры гончих (6) и перепонки ночных мышей (8) для "
                       .. "Шелены; доберёте к северо-востоку от фермы Соллиден.",
                   en = "Gordo on the road west: the report for Zygand (gossip option). On the way: darkhounds and "
                       .. "duskbats - Darkhound Blood (5) for Johaan, Darkhound Hides (6) and Duskbat Wing Membranes "
                       .. "(8) for Shelene; you finish them north-east of Solliden Farmstead." } },
        { id = "ud02-pumpkins", complete = 365, at = { 1420, 36.4, 50.4 },
          note = { ru = "Тыквы (10) на полях фермы Соллиден. По пути: алые воины (10) — доберёте у башни.",
                   en = "10 Tirisfal Pumpkins in the Solliden Farmstead fields. On the way: the Scarlet Warriors "
                       .. "(10) - you finish them by the tower." } },
        { id = "ud02-murloc-skins", complete = { [97558] = { 3 } }, at = { 1420, 32.7, 43.2 },
          note = { ru = "Мурлоки Гиблого Плавника на берегу озера к северу от фермы: 3 шкуры.",
                   en = "Vile Fin murlocs on the lake shore north of the farm: 3 skins." } },
        { id = "ud02-scarlet-warriors", complete = 427, at = { 1420, 32.2, 47.3 },
          note = { ru = "Добейте алых воинов у башни. Каннибализм на их трупах восстанавливает здоровье без простоя.",
                   en = "Finish the Scarlet Warriors by the tower. Cannibalize on their corpses restores your "
                       .. "health without downtime." } },
        { id = "ud02-bareth", accept = 99144, npc = 275954, at = { 1420, 31.96, 46.34 },
          note = { ru = "Барет Рассветный Камень на вершине башни Алого ордена. Наверху легко сагрить "
                       .. "трёх воинов сразу.",
                   en = "Bareth Dawnstone at the top of the Scarlet tower. It is easy to pull three "
                       .. "warriors at once up there." } },
        { id = "ud02-escort", complete = 99144, at = { 1420, 39.1, 48.8 },
          note = { ru = "Сопровождение: идите с Баретом на восток с фермы и защищайте его. "
                       .. "Задание сдаётся в Брилле.",
                   en = "Escort: follow Bareth east out of the farmstead and protect him. "
                       .. "The quest is turned in at Brill." } },
        { id = "ud02-darkhounds", complete = { 367, [97558] = { 1, 2 } }, at = { 1420, 41.0, 42.6 },
          note = { ru = "Гончие и большие ночные мыши к северо-востоку от фермы: доберите кровь гончих (5), шкуры "
                       .. "гончих (6) и перепонки ночных мышей (8).",
                   en = "Darkhounds and Greater Duskbats north-east of the farm: finish the Darkhound Blood (5), "
                       .. "Darkhound Hides (6) and Duskbat Wing Membranes (8)." } },
        { id = "ud02-hearth-1", hearth = "Brill", at = { 1420, 61.72, 52.05 },
          note = { ru = "Камень возвращения в Брилл.", en = "Hearth to Brill." } },

        ------------------------------------------------------------------
        -- Brill, second visit (level 8)
        ------------------------------------------------------------------
        { id = "ud02-johaan-2", turnin = { 367, 365 }, accept = { 368, 407 }, npc = 1518, at = { 1420, 59.45, 52.40 },
          note = { ru = "Аптекарь Йохан.", en = "Apothecary Johaan." } },
        { id = "ud02-zygand-2", turnin = { 427, 99141, 99134 }, accept = 370, npc = 1515, at = { 1420, 60.59, 51.76 },
          note = { ru = "Палач Зиганд.", en = "Executor Zygand." } },
        { id = "ud02-wanted", accept = 398, object = 711, at = { 1420, 60.74, 51.50 },
          note = { ru = "Плакат «Разыскивается» рядом с Зигандом: Глаз Личинки.",
                   en = "The Wanted poster next to Zygand: Maggot Eye." } },
        { id = "ud02-shari-99144", turnin = 99144, npc = 246152, at = { 1420, 60.22, 52.66 },
          note = { ru = "Шари Стилвелл у конюшни: сдайте сопровождение Барета.",
                   en = "Shari Stilwell by the stables: turn in the escort of Bareth." } },
        { id = "ud02-burgess", accept = 374, npc = 1652, at = { 1420, 60.93, 52.01 },
          note = { ru = "Стражник смерти Берджесс.", en = "Deathguard Burgess." } },
        { id = "ud02-thread", collect = { [2320] = 1 }, npc = 2118, at = { 1420, 61.03, 52.37 },
          note = { ru = "Купите Грубую нить у Эбигейл Шил (для 375).",
                   en = "Buy Coarse Thread from Abigail Shiel (for 375)." } },
        { id = "ud02-sevren-1", accept = 358, npc = 1499, at = { 1420, 61.26, 50.84 },
          note = { ru = "Мировой судья Севрен.", en = "Magistrate Sevren." } },
        { id = "ud02-zealot", turnin = 407, npc = 1931, at = { 1420, 61.97, 51.29 },
          note = { ru = "Пленный алый фанатик за таверной.", en = "Captured Scarlet Zealot behind the inn." } },
        { id = "ud02-brill-8", accept = { 354, 362, 375 }, npc = { 1500, 1521 }, at = { 1420, 61.8, 52.5 },
          note = { ru = "Коулман Фартинг и Гретхен Дедмар в таверне (нужен 7-й уровень). Здесь же стоят "
                       .. "тренеры большинства классов.",
                   en = "Coleman Farthing and Gretchen Dedmar in the inn (need level 7). The trainers "
                       .. "of most classes stand here." } },
        { id = "ud02-dillinger-2", turnin = 404, accept = 426, npc = 1496, at = { 1420, 58.2, 51.45 },
          note = { ru = "Диллинджер у входа в Брилл.", en = "Dillinger at the Brill entrance." } },
        { id = "ud02-holland-2", turnin = 5481, accept = 5482, npc = 10665, at = { 1420, 57.44, 48.85 },
          note = { ru = "Младший аптекарь Холланд на северо-западной окраине Брилла.",
                   en = "Junior Apothecary Holland on the north-west edge of Brill." } },

        ------------------------------------------------------------------
        -- North loop: gnolls, Garren's Haunt, coast, Agamand Mills (level 8-10)
        ------------------------------------------------------------------
        -- The Doom Weed grows among the gnolls: both in the fields north of Brill, before Garren's Haunt. The
        -- Duskbat Pelts of 375 are finished by ud02-pelts on the way back from Agamand Mills.
        { id = "ud02-doom-weed", complete = 5482, at = { 1420, 57.1, 39.5 },
          note = { ru = "Роковая трава (10) на полях к северу от Брилла. По пути: гноллы Гнилошкуры для Севрена "
                       .. "(доберёте шагом ниже) и большие ночные мыши — шкуры (5) для Гретхен, доберёте по дороге "
                       .. "назад в Брилл.",
                   en = "Doom Weed (10) in the fields north of Brill. On the way: the Rot Hide gnolls for Sevren "
                       .. "(you finish them in the next step) and Greater Duskbats - Duskbat Pelts (5) for "
                       .. "Gretchen, finished on the way back to Brill." } },
        { id = "ud02-gnolls", complete = 358, at = { 1420, 57.6, 38.0 },
          note = { ru = "Добейте гноллов Гнилошкуров в тех же полях: 8 грабителей могил, 5 дворняг (они ближе "
                       .. "к Гарренской Тени) и 8 бальзамирующих жидкостей.",
                   en = "Finish the Rot Hide gnolls in the same fields: 8 Graverobbers, 5 Mongrels (closer to "
                       .. "Garren's Haunt) and 8 Embalming Ichor." } },
        { id = "ud02-maggot-eye", complete = 398, npc = 1753, at = { 1420, 58.66, 30.77 },
          note = { ru = "Глаз Личинки (11 ур.) в Гарренской Тени. Подтяните его по одному и приберегите "
                       .. "защитное умение на случай беды.",
                   en = "Maggot Eye (level 11) at Garren's Haunt. Pull him alone and keep a defensive cooldown "
                       .. "for emergencies." } },
        { id = "ud02-coast-murlocs", complete = 368, at = { 1420, 60.3, 27.9 },
          note = { ru = "Мурлоки Гиблого Плавника на северном берегу: 5 чешуек.",
                   en = "Vile Fin murlocs on the north coast: 5 scales." } },
        -- Agamand Mills in one sweep from the coast: east (Nissa), north (Gregor), west (Thurman), then the
        -- southern mills (Devlin), where the skeletons of 426 are finished on the way out to Brill.
        { id = "ud02-nissa", complete = { [354] = { 2 } }, npc = 1655, at = { 1420, 49.74, 36.34 },
          note = { ru = "С берега на юго-запад в Мельницы Агамандов: Нисса Агаманд (10) в восточной части деревни. "
                       .. "По пути: скелеты — 5 зазубренных рёбер и 3 почерневших черепа для Диллинджера, доберёте "
                       .. "у южных мельниц. С них может выпасть Письмо Иветте — сохраните его.",
                   en = "From the coast south-west into Agamand Mills: Nissa Agamand (10) in the east of the "
                       .. "village. On the way: the skeletons - 5 Notched Ribs and 3 Blackened Skulls for "
                       .. "Dillinger, finished by the southern mills. They may drop A Letter to Yvette: keep it." } },
        { id = "ud02-gregor", complete = { [354] = { 1 } }, npc = 1654, at = { 1420, 45.79, 29.39 },
          note = { ru = "Грегор Агаманд (10) на севере деревни.", en = "Gregor Agamand (10) in the north of the village." } },
        { id = "ud02-thurman", complete = { [354] = { 3 } }, npc = 1656, at = { 1420, 42.84, 32.54 },
          note = { ru = "Турман Агаманд (10) на западе.", en = "Thurman Agamand (10) in the west." } },
        { id = "ud02-devlin", complete = 362, npc = 1657, at = { 1420, 47.23, 40.02 },
          note = { ru = "Девлин Агаманд (9) у южных мельниц.", en = "Devlin Agamand (9) by the southern mills." } },
        { id = "ud02-agamand-bones", complete = 426, at = { 1420, 47.6, 40.5 },
          note = { ru = "Добейте рёбра и черепа у южных мельниц, затем идите обратно в Брилл.",
                   en = "Finish the ribs and skulls by the southern mills, then head back to Brill." } },
        { id = "ud02-pelts", complete = 375, at = { 1420, 48.2, 47.1 },
          note = { ru = "Доберите шкуры ночных мышей по дороге в Брилл.", en = "Finish the Duskbat Pelts on the way to Brill." } },

        ------------------------------------------------------------------
        -- Brill, third visit (level 9-10)
        ------------------------------------------------------------------
        { id = "ud02-holland-3", turnin = 5482, accept = 99142, npc = 10665, at = { 1420, 57.44, 48.85 },
          note = { ru = "Младший аптекарь Холланд.", en = "Junior Apothecary Holland." } },
        { id = "ud02-dillinger-3", turnin = 426, npc = 1496, at = { 1420, 58.2, 51.45 },
          note = { ru = "Диллинджер. Из наград берите доспехи, которые носит ваш класс.",
                   en = "Dillinger. Rewards: pick the armour your class can wear." } },
        { id = "ud02-johaan-3", turnin = 368, accept = 369, npc = 1518, at = { 1420, 59.45, 52.40 },
          note = { ru = "Аптекарь Йохан.", en = "Apothecary Johaan." } },
        { id = "ud02-zygand-3", turnin = 398, npc = 1515, at = { 1420, 60.59, 51.76 },
          note = { ru = "Палач Зиганд. Из наград берите доспехи, которые носит ваш класс.",
                   en = "Executor Zygand. Rewards: pick the armour your class can wear." } },
        { id = "ud02-letter", accept = 361, use = 2839, optional = true, at = { 1420, 61.58, 52.60 },
          note = { ru = "Если со скелетов Мельниц Агамандов выпало Письмо Иветте — используйте его. "
                       .. "Нет письма — пропустите этот и следующий шаг.",
                   en = "If A Letter to Yvette dropped from the Agamand Mills skeletons, use it. "
                       .. "No letter: skip this and the next step." } },
        { id = "ud02-yvette", turnin = 361, npc = 1560, optional = true, at = { 1420, 61.58, 52.60 },
          note = { ru = "Иветта Фартинг в таверне.", en = "Yvette Farthing in the inn." } },
        { id = "ud02-coleman", turnin = { 354, 362 }, accept = 355, npc = 1500, at = { 1420, 61.72, 52.29 },
          note = { ru = "Коулман Фартинг в таверне.", en = "Coleman Farthing in the inn." } },
        { id = "ud02-gretchen", turnin = 375, npc = 1521, at = { 1420, 61.89, 52.73 },
          note = { ru = "Гретхен Дедмар в таверне.", en = "Gretchen Dedmar in the inn." } },
        { id = "ud02-sevren-3", turnin = { 358, 355 }, accept = 359, npc = 1499, at = { 1420, 61.26, 50.84 },
          note = { ru = "Мировой судья Севрен. Из наград за 358 берите доспехи, которые носит ваш класс.",
                   en = "Magistrate Sevren. 358 rewards: pick the armour your class can wear." } },

        ------------------------------------------------------------------
        -- South: Captain Perrine's camp, then Brill fourth visit (level 10)
        ------------------------------------------------------------------
        { id = "ud02-perrine", complete = 370, at = { 1420, 51.6, 68.0 },
          note = { ru = "Лагерь Алого ордена к юго-западу от Подгорода: капитан Перрин, 3 фанатика и "
                       .. "3 миссионера. Собирайте с них Алые кольца с печатью (374).",
                   en = "Scarlet camp south-west of the Undercity: Captain Perrine, 3 Zealots and "
                       .. "3 Missionaries. Loot their Scarlet Insignia Rings (374)." } },
        { id = "ud02-zygand-4", turnin = 370, accept = 371, npc = 1515, at = { 1420, 60.59, 51.76 },
          note = { ru = "Вернитесь к Зиганду в Брилл.", en = "Back to Zygand in Brill." } },
        -- Requirement and trainer-hub gate: 96895 (the next step) needs level 10, and every class trains at 10.
        -- `at`: the Vampiric Duskbats (8-9) just east of Brill, the nearest mobs that still give full XP.
        { id = "ud02-level-10", level = 10, at = { 1420, 64.6, 52.1 },
          note = { ru = "10-й уровень: он нужен для задания стражника смерти Терренса, и у тренеров в Брилле новые "
                       .. "умения. Не хватает — вампирические ночные мыши сразу к востоку от Брилла.",
                   en = "Level 10: Deathguard Terrence's quest needs it, and the trainers in Brill have new ranks. "
                       .. "Short: the Vampiric Duskbats just east of Brill." } },
        { id = "ud02-terrence", accept = 96895, npc = 1738, at = { 1420, 61.50, 53.50 },
          note = { ru = "Стражник смерти Терренс на южной окраине (нужен 10-й уровень).",
                   en = "Deathguard Terrence at the south edge of Brill (needs level 10)." } },

        ------------------------------------------------------------------
        -- East loop: Rear Guard, Argent emissary, Balnir Farmstead, Venomweb Vale (level 10-12)
        ------------------------------------------------------------------
        -- 374: the rings drop from every Scarlet mob: Perrine's camp (named in ud02-perrine), Vachon's camp, and
        -- the friars north of the spiders, where ud02-rings finishes them.
        { id = "ud02-rear-guard-2", turnin = { 97558, 359 }, accept = { 360, 356 }, npc = { 3549, 1495 },
          at = { 1420, 65.46, 60.18 },
          note = { ru = "Шелена Робарт и Линнея.", en = "Shelene Rhobart and Linnea." } },
        { id = "ud02-hadric", turnin = 96895, accept = { 96897, 96898 }, npc = 267009, at = { 1420, 65.93, 61.13 },
          note = { ru = "Хадрик Харлсон из Серебряного Рассвета рядом с лагерем.",
                   en = "Hadric Harlson of the Argent Dawn next to the camp." } },
        { id = "ud02-cult-camp", complete = { 96897, 96898 }, at = { 1420, 67.5, 63.2 },
          note = { ru = "Тёмные неофиты и силовики (по 8) к юго-востоку. Осколки кристаллов падают с них "
                       .. "и лежат на земле (12). Силовики бьют сильно — по одному.",
                   en = "Dark Neophytes and Dark Enforcers (8 each) to the south-east. Crystal fragments "
                       .. "drop from them and lie on the ground (12). Enforcers hit hard: one at a time." } },
        { id = "ud02-hadric-2", turnin = { 96897, 96898 }, accept = 96899, npc = 267009, at = { 1420, 65.93, 61.13 },
          note = { ru = "Хадрик Харлсон: следующее задание ведёт в крепость Бандарион.",
                   en = "Hadric Harlson: his next quest leads to Bandarion Keep." } },
        { id = "ud02-balnir", complete = { 356, 99142 }, at = { 1420, 76.4, 60.6 },
          note = { ru = "Ферма Бальнира: кровоточащие ужасы и блуждающие духи (по 8), Могильная трава (5).",
                   en = "Balnir Farmstead: Bleeding Horrors and Wandering Spirits (8 each), 5 Tomb Weed." } },
        { id = "ud02-vachon", complete = 371, at = { 1420, 79.2, 56.1 },
          note = { ru = "Лагерь Алого ордена к северо-востоку от фермы: капитан Вашон (11) и 5 монахов. Собирайте с "
                       .. "них Алые кольца с печатью (374).",
                   en = "Scarlet camp north-east of the farm: Captain Vachon (11) and 5 Scarlet Friars. Loot their "
                       .. "Scarlet Insignia Rings (374)." } },
        { id = "ud02-venomweb", complete = 369, at = { 1420, 86.6, 52.0 },
          note = { ru = "Долина Ядовитой Паутины: 4 яда свирепых пауков.",
                   en = "Venomweb Vale: 4 Vicious Night Web Spider Venoms." } },
        { id = "ud02-rings", complete = 374, at = { 1420, 86.9, 43.2 },
          note = { ru = "Доберите Алые кольца с печатью (10): монахи и фанатики к северу от пауков.",
                   en = "Finish the Scarlet Insignia Rings (10): the Friars and Zealots just north of the "
                       .. "spiders." } },
        { id = "ud02-linnea", turnin = 356, npc = 1495, at = { 1420, 65.49, 60.25 },
          note = { ru = "Линнея (продолжение про Рваноклыка — элитное, пропустите).",
                   en = "Linnea (skip the Riptear follow-up: elite)." } },

        ------------------------------------------------------------------
        -- Brill, fifth visit (level 11-12)
        ------------------------------------------------------------------
        { id = "ud02-johaan-5", -- 445 is carried: Renferrel at the Sepulcher (h-13-silverpine)
          turnin = 369, accept = { 492, 445 }, npc = 1518, at = { 1420, 59.45, 52.40 },
          note = { ru = "445 ведёт в Серебряный бор — держите его.", en = "445 leads to Silverpine Forest: keep it." } },
        { id = "ud02-carolai", accept = 95314, npc = 2132, at = { 1420, 59.43, 52.19 },
          note = { ru = "Каролай Аниз рядом с Йоханом: задание для Тенистой долины.",
                   en = "Carolai Anise next to Johaan: a quest for Shadowvale." } },
        { id = "ud02-zygand-5", turnin = 371, npc = 1515, at = { 1420, 60.59, 51.76 },
          note = { ru = "Палач Зиганд.", en = "Executor Zygand." } },
        { id = "ud02-burgess-5", turnin = 374, npc = 1652, at = { 1420, 60.93, 52.01 },
          note = { ru = "Стражник смерти Берджесс. Из наград берите доспехи, которые носит ваш класс.",
                   en = "Deathguard Burgess. Rewards: pick the armour your class can wear." } },
        { id = "ud02-sevren-5", turnin = 360, npc = 1499, at = { 1420, 61.26, 50.84 },
          note = { ru = "Мировой судья Севрен.", en = "Magistrate Sevren." } },
        { id = "ud02-mountaineer", turnin = 492, npc = 2211, at = { 1420, 61.94, 51.40 },
          note = { ru = "Пленный горец за таверной.", en = "Captured Mountaineer behind the inn." } },
        { id = "ud02-holland-5", turnin = 99142, npc = 10665, at = { 1420, 57.44, 48.85 },
          note = { ru = "Младший аптекарь Холланд, по пути на запад.",
                   en = "Junior Apothecary Holland, on the way west." } },

        ------------------------------------------------------------------
        -- Bandarion Keep (level 11-12)
        ------------------------------------------------------------------
        { id = "ud02-go-simmer", go = true, at = { 1420, 40.8, 54.4 },
          note = { ru = "На запад по дороге мимо Симмера.", en = "West along the road past Simmer." } },
        { id = "ud02-go-solliden", go = true, at = { 1420, 28.8, 46.5 },
          note = { ru = "Через ферму Соллиден к крепости Бандарион.", en = "Through Solliden Farmstead toward Bandarion Keep." } },
        { id = "ud02-keep", turnin = 96899, accept = 96896, npc = 267008, at = { 1420, 22.03, 44.73 },
          note = { ru = "Леонид Варфоломей наверху в крепости Бандарион.",
                   en = "Leonid Barthalomew upstairs in Bandarion Keep." } },
        { id = "ud02-leonid-talk", complete = 96896, at = { 1420, 22.03, 44.73 },
          note = { ru = "Послушайте разговор Даниты и Леонида.", en = "Listen to the conversation between Danitha and Leonid." } },
        { id = "ud02-leonid-letter", turnin = 96896, accept = 98545, npc = 267008, at = { 1420, 22.03, 44.73 },
          note = { ru = "Письмо Леонида — для Подгорода.", en = "Leonid's Letter is for the Undercity." } },
        { id = "ud02-hilda", accept = 99152, npc = 246389, at = { 1420, 21.96, 47.25 },
          note = { ru = "Хильда Сокрушительница у южной стены крепости.",
                   en = "Hilda the Breaker by the south wall of the keep." } },
        { id = "ud02-ephram", accept = 99153, npc = 259190, at = { 1420, 20.17, 46.49 },
          note = { ru = "Эфрам Барбаро к юго-западу от крепости, по пути в Тенистую долину.",
                   en = "Ephram Barbaro south-west of the keep, on the way to Shadowvale." } },

        ------------------------------------------------------------------
        -- Shadowvale (level 12)
        ------------------------------------------------------------------
        -- One pass: the bottles (objects) in the middle of the vale on the way in, the crystal at the south end,
        -- the bones (Lurchers and Mystics, all over the middle) finished on the way back. A class file puts a goal
        -- at the entrance of the vale after ud02-ephram, its object goals of the middle after ud02-elixir-bg and
        -- the kills it finishes on the way back after ud02-shadowvale. ud02-elixir-bg keeps its old id: the
        -- paladin file and the layout spec anchor on it.
        { id = "ud02-elixir-bg", complete = 95314, at = { 1420, 10.2, 66.2 },
          note = { ru = "Соберите 8 бутылок шепчущего эликсира — на земле и на стенах в середине Тенистой долины. "
                       .. "По пути: бродяги и мистики Тенистой долины — слабо светящиеся кости (6) для Хильды, "
                       .. "доберёте на обратном пути.",
                   en = "Collect 8 Bottles of Whispering Elixir - on the ground and on the walls in the middle of "
                       .. "Shadowvale. On the way: Shadowvale Lurchers and Mystics - Faintly Glowing Bones (6) for "
                       .. "Hilda, finished on the way back." } },
        { id = "ud02-crystal", complete = 99153, object = 694895, at = { 1420, 9.74, 69.43 },
          note = { ru = "Светящийся осколок кристалла лежит внизу, на юге Тенистой долины. Шепчущие ужасы — "
                       .. "элита, обходите.",
                   en = "The Glowing Crystal Fragment lies down below in the south of Shadowvale. Whispering "
                       .. "Horrors are elite: avoid them." } },
        { id = "ud02-shadowvale", complete = 99152, at = { 1420, 11.5, 65.5 },
          note = { ru = "На обратном пути через середину долины добейте бродяг и мистиков: слабо светящиеся кости (6). "
                       .. "Потом — в крепость.",
                   en = "On the way back through the middle of the vale, finish the Lurchers and Mystics: Faintly "
                       .. "Glowing Bones (6). Then back to the keep." } },
        { id = "ud02-ephram-2", turnin = 99153, npc = 259190, at = { 1420, 20.17, 46.49 },
          note = { ru = "Эфрам Барбаро.", en = "Ephram Barbaro." } },
        { id = "ud02-hilda-2", turnin = 99152, npc = 246389, at = { 1420, 21.96, 47.25 },
          note = { ru = "Хильда Сокрушительница.", en = "Hilda the Breaker." } },
        -- Trainer-hub gate (docs/dev/PLAN.md B.8): level 12 before the hearth to Brill. The turn-ins behind it
        -- (95314, 98545) have estimated XP and are not counted. `at`: the Vile Fin murlocs (9-11) on the lake
        -- shore next to the keep; the Shadowvale mobs (10-12) are 450 yd back.
        { id = "ud02-lvl-12", level = 12, at = { 1420, 23.2, 48.2 },
          note = { ru = "12-й уровень перед возвращением: новые умения у тренеров в Брилле и Подгороде, и он нужен "
                       .. "в начале Серебряного бора. Не хватает — мурлоки Гиблого Плавника на берегу озера у "
                       .. "крепости.",
                   en = "Level 12 before you go back: new ranks at the trainers in Brill and the Undercity, and the "
                       .. "start of Silverpine needs it. Short: the Vile Fin murlocs on the lake shore by the keep." } },

        ------------------------------------------------------------------
        -- Brill and the Undercity (level 12), out to the Silverpine road
        ------------------------------------------------------------------
        { id = "ud02-hearth-2", hearth = "Brill", at = { 1420, 61.72, 52.05 },
          note = { ru = "Камень возвращения в Брилл.", en = "Hearth to Brill." } },
        { id = "ud02-carolai-2", turnin = 95314, npc = 2132, at = { 1420, 59.43, 52.19 },
          note = { ru = "Каролай Аниз рядом с аптекарем Йоханом.", en = "Carolai Anise next to Apothecary Johaan." } },
        { id = "ud02-go-uc", go = true, at = { 1420, 61.92, 64.85 },
          note = { ru = "Вход в Подгород через Руины Лордерона к югу от Брилла, лифт вниз.",
                   en = "Undercity entrance through the Ruins of Lordaeron south of Brill, take the lift down." } },
        { id = "ud02-glix", turnin = 98545, npc = 272526, at = { 1458, 70.03, 47.31 },
          note = { ru = "Гликс Ксиззикс в Торговом квартале.", en = "Glix Xizzix in the Trade Quarter." } },
        { id = "ud02-fp-uc", fp = "Undercity", npc = 4551, at = { 1458, 63.25, 48.56 },
          note = { ru = "Майкл Гаррет — точка полёта Подгорода. В городе есть тренеры всех классов и мастер оружия.",
                   en = "Michael Garrett: Undercity flight path. The city has trainers of every class and a weapon "
                       .. "master." } },
        { id = "ud02-uc-exit", go = true, at = { 1420, 61.92, 64.85 },
          note = { ru = "Выйдите из Подгорода на лифте к Руинам Лордерона.",
                   en = "Leave the Undercity by the lift up to the Ruins of Lordaeron." } },
        { id = "ud02-silverpine-road", go = true, at = { 1420, 53.2, 75.8 },
          note = { ru = "На юго-запад к дороге в Серебряный бор, восточнее лагеря Алого ордена.",
                   en = "South-west to the Silverpine Forest road, east of the Scarlet camp." } },
    },
})

-- Start-zone announcement (read by Route.lua): the segments every Undead route starts with. The two segments
-- are class-neutral, so every class of the race gets its route.
ns.startZones = ns.startZones or {}
ns.startZones.Tirisfal = { "ud-01-deathknell", "ud-02-tirisfal" }
