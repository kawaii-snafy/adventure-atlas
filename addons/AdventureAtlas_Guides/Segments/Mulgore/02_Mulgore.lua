-- AdventureAtlas_Guides / Segments / Mulgore / 02_Mulgore.lua
-- Segment "mul-02-mulgore": Mulgore (uiMap 1412) and Thunder Bluff (1456), levels 6-12, Tauren. Class-neutral:
-- every Tauren class walks it; what exists because of a class is a shared insert of Classes/<Class>.lua on the
-- anchors below.
--
-- Hub plan (Forever DB). Bloodhoof Village is visited seven times: the Thunderhorn chain of Mull Thunderhorn
-- (748 > 754 > 756 > 758 > 759 > 760) returns to him after every step, so each loop ends at his tent.
--   camp  : Kaga Wildhoof south of the village: 96659 > 96605 (campfire) > 96661 (Pyall).
--   BH1   : 1656 + bind, 743, 763 > 767 + 745 + 746, 99079, 748, 99108 (duel on the spot), 761, 767 > 771, 96130,
--           99411 (north end), then Maur 766 and Pyall 96661 on the way out west.
--   west  : Chakuyak 96130, Palemane camp 745, Perith Stormhoof's escort 98430 (turned in at Cairne); the wolves,
--           plainstriders and swoops of 748, 761 and 766 (heart, scale, gizzard) and the Tender Strider Meat of
--           99411 are killed on the way and finished at mul02-west on the way back.
--   BH2   : 99411 (Kyle in the village), 96130, 745, 748 > 754, 761.
--   SE    : the Ambercorns of 771 on the way, Winterhoof Water Well 754 + the well stones of 771, Windfury harpies
--           743, Malah Longwind 99079 > 99081, Morin Cloudstalker 749.
--   BH3   : 99081 > 99101 > 99080, 743, 771 > 772, 754 > 756.
--   centre: 756 claws and the 766 femur north of the village, the caravan crate 749 > 751 on the way south-east,
--           Morin 751 > 764 + 765, Venture Co. mine 764, 765 (Fizsprocket drops the plans that start 98424), the
--           three documents of 98424, Galak centaurs + Herak 99080, Morin; gate mul02-lvl-10.
--   BH4   : 99080 > 99082, 766, 756 > 758.
--   west 2: the dig site forge 746, Seer Wiserunner 772 > 773, Thunderhorn Water Well 758 on the way back.
--   BH5   : 746, 758 > 759, 861 (level 10).
--   north : Red Rocks: 833 and the Ancestral Spirit 773 > 775; 759 alpha teeth and 861 prowler claws on the way,
--           finished west of Red Rocks; hearth.
--   BH6   : 759 > 760.
--   TB    : Cairne 775, 98430, 99082 > 776; flight point. Down again: Wildmane Water Well 760, Arra'chea 776.
--   BH7   : 760 > 98435 (on the way out: the road from Thunder Bluff to the Barrens passes the village).
-- Carried into mul-03 (turned in during the flight chain's visit of Thunder Bluff): 776, 98435, 861.
-- Skipped: 98427 (level-12 elite key and a second trip to Morin), 744 (Thunder Bluff harpies, the first fall-back
--   of docs/dev/PLAN.md B.2: not needed, h13-lvl-12 needs 0 kills), 770 (rare drop), 768 / 769 (professions),
--   97485 (an item without a source), the 76156 chain (E.10), 9264 (event), 5844 (gift voucher).
-- Level gates (class-neutral, docs/dev/PLAN.md B.8), 0 kills each for the base profile: mul02-lvl-6 before the
--   first village visit (746 needs 6, training at 6), mul02-lvl-10 before the fourth (861 needs 10, training at 10).
-- Hearthstone: bound in Bloodhoof Village on the first visit; used once, from Red Rocks back to the village.
-- No background (`bg`) steps: mobs met on the way are named in the note of the step where they start ("По пути:"),
-- and a regular step finishes them (mul02-west, mul02-claws, mul02-north).
--
-- Anchors for the class files (docs/dev/PLAN.md C.2; level = validator level of the base profile before the step,
-- read with --levels; the measured list is in docs/dev/handover/p1-mulgore.md). The trainers of Bloodhoof stand
-- next to Mull Thunderhorn (druid Gennia Runetotem, shaman Narm Skychaser, warrior Krang Stonehoof) and at the
-- north end (hunter Yaw Sharpmane):
--   mul02-bh-1 .. mul02-bh-6  the step of each village visit next to the trainers (Harken / Mull)
--   mul02-tb      Cairne in Thunder Bluff (first quest step of the city): city trainers, weapon master
--   mul02-end     the last step: Mull Thunderhorn on the way out (BH7)
-- After the anchor step (where `after` inserts run) the even level is reached at every trainer visit: mul01-ravine 4,
-- mul01-leave 6, mul02-bh-2 8, mul02-bh-4 10 (gate), so no trainer-hub gate is needed in the start zone.
-- Every step has an explicit id (prefix "mul02-"). No `reward` here (class reward tables of the class files).
-- Coordinates: Forever DB snapshot (tools/data/forever_db.lua): NPC / object spawns, quest triggers and centroids
-- of the objective mob spawns near the path. The Thunder Bluff lift is the point the shared path uses.
if not AdventureAtlas.AddLibraryInsert then return end
AdventureAtlas.AddLibrarySegment({
    id = "mul-02-mulgore",
    title = {
        ru = "6-12 Мулгор: деревня Кровавого Копыта и Громовой Утёс",
        en = "6-12 Mulgore: Bloodhoof Village and Thunder Bluff",
    },
    zone = "Mulgore",
    levels = { 6, 12 },
    steps = {
        ------------------------------------------------------------------
        -- Kaga Wildhoof's camp, south of the village (level 6)
        ------------------------------------------------------------------
        { id = "mul02-kaga", turnin = 96659, accept = 96605, npc = 265810, at = { 1412, 46.20, 67.30 },
          note = {
              ru = "По дороге на север: лагерь Kaga Wildhoof к югу от деревни Кровавого Копыта.",
              en = "North along the road: Kaga Wildhoof's camp south of Bloodhoof Village.",
          } },
        -- CONFIRM: the campfire objective of 96605 works as in Tirisfal (sit at the camp's fire).
        { id = "mul02-campfire", complete = 96605, object = 460003, at = { 1412, 46.20, 67.30 },
          note = {
              ru = "Сядьте у костра (/sit) и ждите около минуты, пока не появится бафф отдыха.",
              en = "Sit at the campfire (/sit) and wait about a minute for the rest buff.",
          } },
        { id = "mul02-kaga-2", turnin = 96605, accept = 96661, npc = 265810, at = { 1412, 46.20, 67.30 },
          note = {
              ru = "Kaga Wildhoof: следующее задание сдаётся у Pyall Silentstride в деревне.",
              en = "Kaga Wildhoof: the next quest is turned in to Pyall Silentstride in the village.",
          } },

        -- Requirement and trainer-hub gate: 746 (Baine) needs level 6, and every class trains at 6 in the village.
        -- The base profile is at 6.32 here (0 kills), but about 1,100 XP of the way are the estimated XP of the
        -- two camp quests (96659, 96605): the gate is the guarantee. `at`: Prairie Wolves (5-6) and Adult
        -- Plainstriders (6-8) around the camp.
        { id = "mul02-lvl-6", level = 6, at = { 1412, 48.3, 68.5 },
          note = {
              ru = "6-й уровень перед деревней: он нужен для задания Baine Bloodhoof, и у тренеров новые умения. "
                  .. "Не хватает - степные волки и долгоноги вокруг лагеря.",
              en = "Level 6 before the village: Baine Bloodhoof's quest needs it, and the trainers have new ranks. "
                  .. "Short: the Prairie Wolves and plainstriders around the camp.",
          } },

        ------------------------------------------------------------------
        -- Bloodhoof Village, visit 1 (level 6-7)
        ------------------------------------------------------------------
        { id = "mul02-inn", turnin = 1656, sethearth = "Bloodhoof Village", npc = 6747, at = { 1412, 45.93, 64.16 },
          note = {
              ru = "Трактирщик Kauth: сдайте письмо и сделайте таверну домом.",
              en = "Innkeeper Kauth: hand in the letter and make this inn your home.",
          } },
        { id = "mul02-ruul", accept = 743, npc = 2985, at = { 1412, 46.50, 64.90 } },
        { id = "mul02-baine-1", turnin = 763, accept = { 767, 745, 746 }, npc = 2993, at = { 1412, 46.70, 63.40 },
          note = {
              ru = "Baine Bloodhoof в центре деревни.",
              en = "Baine Bloodhoof in the middle of the village.",
          } },
        { id = "mul02-wildrunner", accept = 99079, npc = 3222, at = { 1412, 46.70, 63.80 } },
        { id = "mul02-mull-1", accept = 748, npc = 2948, at = { 1412, 47.50, 63.60 },
          note = {
              ru = "Mull Thunderhorn: его цепочка будет возвращать вас в деревню после каждого шага.",
              en = "Mull Thunderhorn: his chain brings you back to the village after every step.",
          } },
        { id = "mul02-krang", accept = 99108, complete = 99108, turnin = 99108, npc = 3063, at = { 1412, 48.40, 63.70 },
          note = {
              ru = "Krang Stonehoof: возьмите задание, победите Novice Warrior рядом с ним и сразу сдайте.",
              en = "Krang Stonehoof: take the quest, beat a Novice Warrior next to him and hand it in right away.",
          } },
        -- Anchor: training at 6 (the trainers stand around Mull Thunderhorn).
        { id = "mul02-bh-1", accept = 761, npc = 2947, at = { 1412, 47.70, 62.70 },
          note = {
              ru = "Harken Windtotem. Тренеры классов стоят вокруг Mull Thunderhorn.",
              en = "Harken Windtotem. The class trainers stand around Mull Thunderhorn.",
          } },
        { id = "mul02-zarlman", turnin = 767, accept = 771, npc = 3054, at = { 1412, 46.90, 61.20 },
          note = {
              ru = "Zarlman Two-Moons. Янтарные жёлуди (Ambercorn) лежат под деревьями по всему Мулгору: увидите - "
                  .. "подберите 2; камни - у колодца Winterhoof.",
              en = "Zarlman Two-Moons. Ambercorns lie under the trees all over Mulgore: pick 2 when you see them; the "
                  .. "stones are at the Winterhoof well.",
          } },
        { id = "mul02-yaw", accept = 96130, npc = 3065, at = { 1412, 46.90, 59.60 } },
        { id = "mul02-ahab", accept = 99411, npc = 277182, at = { 1412, 47.28, 57.63 },
          note = {
              ru = "Ahab Wheathoof у северного края деревни.",
              en = "Ahab Wheathoof at the north end of the village.",
          } },
        -- Maur and Pyall lie on the way from the north end to the west loop.
        { id = "mul02-maur", accept = 766, npc = 3055, at = { 1412, 46.20, 60.80 },
          note = {
              ru = "Maur Raincaller, по пути к западному краю деревни.",
              en = "Maur Raincaller, on the way to the west edge of the village.",
          } },
        { id = "mul02-pyall", complete = 96661, turnin = 96661, npc = 3067, at = { 1412, 44.90, 61.70 },
          note = {
              ru = "Pyall Silentstride у западного края деревни, по пути на запад.",
              en = "Pyall Silentstride at the west edge of the village, on the way west.",
          } },

        ------------------------------------------------------------------
        -- West: Palemane, Chakuyak, Perith Stormhoof (level 7-8)
        ------------------------------------------------------------------
        { id = "mul02-chakuyak", complete = 96130, at = { 1412, 39.50, 66.20 },
          note = {
              ru = "На запад: Chakuyak (редкий волк) бродит у 39.5, 66. По пути: бейте степных волков (6 лап и "
                  .. "сердце), взрослых долгоногов (4 когтя, чешуя и Tender Strider Meat для Kyle) и стервятников "
                  .. "(8 перьев и зоб), доберёте на обратном пути.",
              en = "West: Chakuyak (a lone wolf) roams around 39.5, 66. On the way: kill Prairie Wolves (6 paws and "
                  .. "a heart), Adult Plainstriders (4 talons, a scale and the Tender Strider Meat for Kyle) and Wiry "
                  .. "Swoops (8 quills and a gizzard); finish them on the way back.",
          } },
        { id = "mul02-palemane", complete = 745, at = { 1412, 34.2, 64.3 },
          note = {
              ru = "Лагерь Palemane на западе: 10 Tanner, 8 Skinner, 5 Poacher.",
              en = "The Palemane camp in the west: 10 Tanners, 8 Skinners, 5 Poachers.",
          } },
        { id = "mul02-perith", accept = 98430, npc = 272203, at = { 1412, 33.10, 66.00 },
          note = {
              ru = "Perith Stormhoof у лагеря: проводите его.",
              en = "Perith Stormhoof by the camp: escort him.",
          } },
        { id = "mul02-escort", complete = 98430, at = { 1412, 37.19, 64.62 },
          note = {
              ru = "Сопровождение короткое, на восток до 37.2, 64.6. Сдаётся у Cairne в Громовом Утёсе.",
              en = "A short escort east to 37.2, 64.6. It is turned in to Cairne in Thunder Bluff.",
          } },
        -- CONFIRM: Tender Strider Meat (287505, needed by 99411) drops from Adult Plainstriders (DB: 2956, 2957, 3068).
        { id = "mul02-west", complete = { 748, 761, [766] = { 1, 3, 4 } }, collect = { [287505] = 1 },
          at = { 1412, 40.6, 64.4 },
          note = {
              ru = "Перед деревней добейте волков, долгоногов и стервятников: 6 лап, 4 когтя, 8 перьев; для Maur "
                  .. "Raincaller - сердце волка, чешуя долгонога, зоб стервятника; для Kyle - Tender Strider Meat с "
                  .. "долгонога.",
              en = "Before the village finish the wolves, plainstriders and swoops: 6 paws, 4 talons, 8 quills; for "
                  .. "Maur Raincaller a wolf heart, a plainstrider scale, a swoop gizzard; for Kyle the Tender Strider "
                  .. "Meat from a plainstrider.",
          } },

        ------------------------------------------------------------------
        -- Bloodhoof Village, visit 2 (level 8)
        ------------------------------------------------------------------
        -- CONFIRM: Kyle the Frenzied at 46.3, 62.3 (DB) takes the Tender Strider Meat of mul02-west.
        { id = "mul02-kyle", complete = 99411, use = 287505, at = { 1412, 46.28, 62.34 },
          ok = "travel-revisit", -- the first village visit passes Kyle, but the meat comes from mul02-west
          note = {
              ru = "Kyle the Frenzied бегает по деревне: используйте на нём Tender Strider Meat.",
              en = "Kyle the Frenzied runs around the village: use the Tender Strider Meat on him.",
          } },
        { id = "mul02-yaw-2", turnin = 96130, npc = 3065, at = { 1412, 46.90, 59.60 } },
        { id = "mul02-ahab-2", turnin = 99411, npc = 277182, at = { 1412, 47.28, 57.63 } },
        { id = "mul02-baine-2", turnin = 745, npc = 2993, at = { 1412, 46.70, 63.40 } },
        { id = "mul02-mull-2", turnin = 748, accept = 754, npc = 2948, at = { 1412, 47.50, 63.60 },
          note = {
              ru = "Mull Thunderhorn даёт тотем очищения для колодца Winterhoof.",
              en = "Mull Thunderhorn gives you the cleansing totem for the Winterhoof well.",
          } },
        -- Anchor: training at 8.
        { id = "mul02-bh-2", turnin = 761, npc = 2947, at = { 1412, 47.70, 62.70 } },

        ------------------------------------------------------------------
        -- South-east: Winterhoof Water Well, harpies, Malah Longwind (level 8-9)
        ------------------------------------------------------------------
        -- The Ambercorns of 771 have no step of their own: they lie all over Mulgore (the walk to Chakuyak passes
        -- enough of them), so a step for them alone would be done early, become the forward anchor and skip the
        -- Tender Strider Meat (collect) of mul02-west. mul02-wellstones finishes all of 771 (the Well Stones are only
        -- at the wells).
        { id = "mul02-winterhoof", complete = 754, use = 5411, at = { 1412, 51.76, 68.43 },
          note = {
              ru = "На юго-восток к колодцу Winterhoof: используйте тотем у колодца. По пути, если ещё нет, подберите 2 "
                  .. "янтарных жёлудя (Ambercorn) под деревьями - у 50.4, 64.2 и 50.1, 66.1 (ещё один у 49.0, 68.7).",
              en = "South-east to the Winterhoof Water Well: use the totem at the well. On the way, if you do not have "
                  .. "them yet, pick 2 Ambercorns under the trees - at 50.4, 64.2 and 50.1, 66.1 (one more at 49.0, 68.7).",
          } },
        { id = "mul02-wellstones", complete = 771, object = { 2910, 2912 }, at = { 1412, 51.80, 68.60 },
          note = {
              ru = "Там же 2 камня колодца (Well Stone). Жёлудей не хватает - деревья у 49.0, 68.7 и 50.1, 66.1.",
              en = "Two Well Stones at the same well. Ambercorns missing: the trees at 49.0, 68.7 and 50.1, 66.1.",
          } },
        { id = "mul02-harpies", complete = 743, at = { 1412, 62.0, 71.8 },
          note = {
              ru = "Гарпии Windfury на юго-востоке: 8 когтей.",
              en = "The Windfury harpies in the south-east: 8 talons.",
          } },
        { id = "mul02-malah", turnin = 99079, accept = 99081, npc = 275789, at = { 1412, 57.60, 63.20 },
          note = {
              ru = "Malah Longwind к северу от гарпий.",
              en = "Malah Longwind north of the harpies.",
          } },
        { id = "mul02-morin", accept = 749, npc = 2988, at = { 1412, 54.80, 64.30 },
          note = {
              ru = "Morin Cloudstalker ходит по восточной дороге: ищите его у 54.8, 64.3.",
              en = "Morin Cloudstalker walks the east road: look for him around 54.8, 64.3.",
          } },

        ------------------------------------------------------------------
        -- Bloodhoof Village, visit 3 (level 9)
        ------------------------------------------------------------------
        { id = "mul02-ruul-2", turnin = 743, npc = 2985, at = { 1412, 46.50, 64.90 } },
        { id = "mul02-wildrunner-2", turnin = 99081, accept = 99101, npc = 3222, at = { 1412, 46.70, 63.80 } },
        { id = "mul02-baine-3", turnin = 99101, accept = 99080, npc = 2993, at = { 1412, 46.70, 63.40 } },
        -- Anchor: Bloodhoof trainers (visit 3).
        { id = "mul02-bh-3", turnin = 754, accept = 756, npc = 2948, at = { 1412, 47.50, 63.60 } },
        { id = "mul02-zarlman-2", turnin = 771, accept = 772, npc = 3054, at = { 1412, 46.90, 61.20 } },

        ------------------------------------------------------------------
        -- Centre and east: claws, the caravan, the Venture Co. mine, the Galak centaurs (level 9-10)
        ------------------------------------------------------------------
        { id = "mul02-claws", complete = { 756, 766 }, at = { 1412, 49.2, 50.5 },
          note = {
              ru = "На север: степные охотники (Prairie Stalker) и равнинные пумы (Flatland Cougar) - 6 и 6 "
                  .. "когтей, с пумы ещё бедренная кость для Maur.",
              en = "North: Prairie Stalkers and Flatland Cougars - 6 and 6 claws; one cougar femur for Maur.",
          } },
        { id = "mul02-crate", turnin = 749, accept = 751, object = 2908, at = { 1412, 51.90, 53.40 },
          note = {
              ru = "На юго-восток к разграбленному каравану: запечатанный ящик у повозки.",
              en = "South-east to the ravaged caravan: the Sealed Supply Crate by the wagon.",
          } },
        { id = "mul02-morin-2", turnin = 751, accept = { 764, 765 }, npc = 2988, at = { 1412, 54.80, 64.30 },
          note = {
              ru = "Ящик - обратно к Morin Cloudstalker на восточную дорогу: он даёт задания на рудник Venture Co.",
              en = "Take the crate back to Morin Cloudstalker on the east road: he gives the Venture Co. mine quests.",
          } },
        { id = "mul02-venture", complete = 764, at = { 1412, 58.4, 47.5 },
          note = {
              ru = "Рудник Venture Co. на северо-востоке: 14 рабочих и 6 надсмотрщиков.",
              en = "The Venture Co. mine in the north-east: 14 Workers and 6 Supervisors.",
          } },
        { id = "mul02-fizsprocket", complete = 765, at = { 1412, 61.20, 49.30 },
          note = {
              ru = "Supervisor Fizsprocket в глубине рудника: его планшет.",
              en = "Supervisor Fizsprocket deep in the mine: his clipboard.",
          } },
        { id = "mul02-plans", accept = 98424, use = 281031, at = { 1412, 61.20, 49.30 },
          note = {
              ru = "С него же падают Mulgore Expansion Plans: начните задание из сумки.",
              en = "He also drops the Mulgore Expansion Plans: start the quest from your bags.",
          } },
        { id = "mul02-notes", complete = { [98424] = { 2 } }, object = 673496, at = { 1412, 61.67, 47.31 },
          note = {
              ru = "Записка на земле рядом, у 61.7, 47.3.",
              en = "A document on the ground close by, at 61.7, 47.3.",
          } },
        { id = "mul02-notes-2", complete = 98424, object = { 673494, 673497 }, at = { 1412, 58.80, 46.90 },
          note = {
              ru = "Ещё две на выходе из рудника: у 59.0, 46.4 и 58.6, 47.3.",
              en = "Two more on the way out of the mine: at 59.0, 46.4 and 58.6, 47.3.",
          } },
        { id = "mul02-galak", complete = 99080, at = { 1412, 63.80, 62.60 },
          note = {
              ru = "На юг к лагерю кентавров Galak: 6 Centaur, 4 Outrunner; Herak the Pillager бродит у 60.3, 60.5.",
              en = "South to the Galak camp: 6 Centaurs, 4 Outrunners; Herak the Pillager roams around 60.3, 60.5.",
          } },
        { id = "mul02-morin-3", turnin = { 764, 765, 98424 }, npc = 2988, at = { 1412, 54.80, 64.30 },
          note = {
              ru = "Morin Cloudstalker на восточной дороге. Его следующее задание (элитный Clearcutter) пропускаем.",
              en = "Morin Cloudstalker on the east road. Skip his next quest (the elite Clearcutter).",
          } },

        -- Requirement and trainer-hub gate: 861 (Skorn, visit 5) needs level 10, and every class trains at 10 in
        -- the village. The base profile is at 10.05 here (0 kills), but a third of the XP of the way is the
        -- estimated XP of Forever-new quests: the gate is the guarantee. `at`: Prairie Stalkers (7-8) and
        -- Prairie Wolf Alphas (9-10) along the road between the Galak camp and Morin.
        { id = "mul02-lvl-10", level = 10, at = { 1412, 57.0, 62.8 },
          note = {
              ru = "10-й уровень перед деревней: он нужен для задания Skorn Whitecloud, и у тренеров новые умения. "
                  .. "Не хватает - степные охотники и вожаки волков у дороги.",
              en = "Level 10 before the village: Skorn Whitecloud's quest needs it, and the trainers have new "
                  .. "ranks. Short: the Prairie Stalkers and Prairie Wolf Alphas along the road.",
          } },

        ------------------------------------------------------------------
        -- Bloodhoof Village, visit 4 (level 10)
        ------------------------------------------------------------------
        { id = "mul02-baine-4", turnin = 99080, accept = 99082, npc = 2993, at = { 1412, 46.70, 63.40 } },
        -- Anchor: training at 10, level-10 class quests.
        { id = "mul02-bh-4", turnin = 756, accept = 758, npc = 2948, at = { 1412, 47.50, 63.60 } },
        { id = "mul02-maur-2", turnin = 766, npc = 3055, at = { 1412, 46.20, 60.80 } },

        ------------------------------------------------------------------
        -- West and north-west: the dig site, Seer Wiserunner, Thunderhorn Water Well (level 10)
        ------------------------------------------------------------------
        { id = "mul02-forge", complete = 746, object = 17190, at = { 1412, 33.10, 54.80 },
          note = {
              ru = "На запад к раскопкам дворфов: 5 сломанных инструментов из кузни.",
              en = "West to the dwarven dig site: 5 Broken Tools from the forge.",
          } },
        { id = "mul02-wiserunner", turnin = 772, accept = 773, npc = 2984, at = { 1412, 34.30, 43.30 },
          note = {
              ru = "Seer Wiserunner к северу, у подножия Громового Утёса.",
              en = "Seer Wiserunner to the north, at the foot of Thunder Bluff.",
          } },
        { id = "mul02-thunderhorn", complete = 758, at = { 1412, 44.20, 51.10 },
          note = {
              ru = "На обратном пути в деревню - колодец Thunderhorn: используйте тотем у колодца.",
              en = "On the way back to the village, the Thunderhorn Water Well: use the totem at the well.",
          } },

        ------------------------------------------------------------------
        -- Bloodhoof Village, visit 5 (level 10)
        ------------------------------------------------------------------
        { id = "mul02-baine-5", turnin = 746, npc = 2993, at = { 1412, 46.70, 63.40 } },
        { id = "mul02-mull-5", turnin = 758, accept = 759, npc = 2948, at = { 1412, 47.50, 63.60 } },
        -- Anchor: Bloodhoof trainers (visit 5).
        { id = "mul02-bh-5", accept = 861, npc = 3052, at = { 1412, 46.00, 63.40 },
          note = {
              ru = "Skorn Whitecloud (нужен 10-й уровень): когти равнинных бродяг, сдаются в Громовом Утёсе.",
              en = "Skorn Whitecloud (needs level 10): Flatland Prowler claws, turned in at Thunder Bluff.",
          } },

        ------------------------------------------------------------------
        -- North: alphas, prowlers, Red Rocks (level 10-11)
        ------------------------------------------------------------------
        { id = "mul02-raintotem", accept = 833, npc = 3233, at = { 1412, 57.00, 34.50 },
          note = {
              ru = "На север к Lorekeeper Raintotem у подножия Красных Скал. По пути: бейте вожаков степных волков "
                  .. "(8 клыков) и равнинных бродяг (4 когтя), доберёте после Красных Скал, к западу от них.",
              en = "North to Lorekeeper Raintotem at the foot of Red Rocks. On the way: kill Prairie Wolf Alphas "
                  .. "(8 teeth) and Flatland Prowlers (4 claws); finish them after Red Rocks, west of them.",
          } },
        { id = "mul02-interlopers", complete = 833, at = { 1412, 58.20, 31.20 },
          note = {
              ru = "8 Bristleback Interloper на Красных Скалах.",
              en = "8 Bristleback Interlopers on Red Rocks.",
          } },
        { id = "mul02-spirit", turnin = 773, accept = 775, npc = 2994, at = { 1412, 58.30, 30.70 },
          note = {
              ru = "Ancestral Spirit на вершине Красных Скал.",
              en = "The Ancestral Spirit on top of Red Rocks.",
          } },
        { id = "mul02-raintotem-2", turnin = 833, npc = 3233, at = { 1412, 57.00, 34.50 } },
        { id = "mul02-north", complete = { 759, 861 }, at = { 1412, 52.0, 34.0 },
          note = {
              ru = "Добейте вожаков волков и равнинных бродяг к западу от Красных Скал: 8 клыков и 4 когтя.",
              en = "Finish the Prairie Wolf Alphas and Flatland Prowlers west of Red Rocks: 8 teeth and 4 claws.",
          } },
        { id = "mul02-hearth", hearth = "Bloodhoof Village", at = { 1412, 45.93, 64.16 },
          note = {
              ru = "Камень возвращения - в деревню Кровавого Копыта.",
              en = "Hearth to Bloodhoof Village.",
          } },

        ------------------------------------------------------------------
        -- Bloodhoof Village, visit 6 (level 11)
        ------------------------------------------------------------------
        -- Anchor: Bloodhoof trainers (visit 6).
        { id = "mul02-bh-6", turnin = 759, accept = 760, npc = 2948, at = { 1412, 47.50, 63.60 } },

        ------------------------------------------------------------------
        -- Thunder Bluff, first visit (level 11)
        ------------------------------------------------------------------
        { id = "mul02-tb-lift", go = true, radius = 20, at = { 1456, 31.78, 65.92 },
          note = {
              ru = "На северо-запад по равнине к Громовому Утёсу и наверх на лифте.",
              en = "North-west across the plain to Thunder Bluff and up the lift.",
          } },
        -- Anchor: Thunder Bluff trainers, weapon master.
        { id = "mul02-tb", turnin = { 775, 98430, 99082 }, accept = 776, npc = 3057, at = { 1456, 60.30, 51.70 },
          note = {
              ru = "Cairne Bloodhoof на центральной вершине: сдайте три задания и возьмите охоту на Arra'chea.",
              en = "Cairne Bloodhoof on the central mesa: hand in three quests and take the hunt for Arra'chea.",
          } },
        { id = "mul02-fp-tb", fp = "Thunder Bluff", npc = 2995, at = { 1456, 47.00, 49.83 },
          note = {
              ru = "Tal у башни ветрокрылов: откройте карту полётов (точка изучится). Сюда вы ещё прилетите из "
                  .. "Перекрёстка.",
              en = "Tal at the wind rider tower: open the flight map (learns the point). You fly back here from the "
                  .. "Crossroads.",
          } },

        ------------------------------------------------------------------
        -- North: Wildmane Water Well, Arra'chea (level 11-12)
        ------------------------------------------------------------------
        { id = "mul02-wildmane", complete = 760, at = { 1412, 42.70, 25.00 },
          note = {
              ru = "Вниз на лифте и на север к колодцу Wildmane: используйте тотем.",
              en = "Down the lift and north to the Wildmane Water Well: use the totem.",
          } },
        -- CONFIRM: Arra'chea's DB spawn (51.2, 24.8) and that 776 is offered right after 775 in Forever.
        { id = "mul02-arrachea", complete = 776, at = { 1412, 51.20, 24.80 },
          note = {
              ru = "Arra'chea (11-й уровень, большой кодо) бродит к востоку от колодца, у 51, 25: его рог.",
              en = "Arra'chea (level 11, a big kodo) roams east of the well, around 51, 25: its horn.",
          } },

        ------------------------------------------------------------------
        -- Bloodhoof Village, visit 7, on the way out (level 12)
        ------------------------------------------------------------------
        { id = "mul02-end", turnin = 760, accept = 98435, npc = 2948, at = { 1412, 47.50, 63.60 },
          note = {
              ru = "На юг в деревню: сдайте колодец Mull Thunderhorn. Его донесение (и рог Arra'chea) сдаются в "
                  .. "Громовом Утёсе, куда вы прилетите из Перекрёстка.",
              en = "South to the village: hand the well in to Mull Thunderhorn. His report (and the horn of "
                  .. "Arra'chea) go to Thunder Bluff, where you fly in from the Crossroads.",
          } },
    },
})
