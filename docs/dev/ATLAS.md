# Adventure Atlas: product vision (recorded 2026-11-10)

The owner's goal for the addon, stated while the race + class guides were being planned. This file records the
decisions so that the guide work (docs/dev/PLAN.md) does not close doors; the atlas itself is the **next stage,
after the 28 guides**.

## What the addon becomes

An "adventure atlas" for players of World of Warcraft: Forever: everything useful in one place, for players
who do not live in the game and would otherwise miss much of it (the game is large and explains itself poorly).

Two big blocks:

1. **Knowledge base** — a growing collection of what there is in the game and how it works. Sections named so
   far: dungeons and raids; classes; world and services; what is new in Forever. It must be easy to add entries
   over time ("пополняемая").
2. **The adventure** — an algorithm of character development, a flow: leveling, gearing, professions, skills
   and so on. A helper that leads the player through the adventure and **always tells where to go right now**.
   The 28 leveling guides (race + class, 1-60) are the first track of this block.

## Look

Inspired by the retail Adventure Guide (Encounter Journal): one window with tabs. The **first tab is "what is
relevant for you now"** (suggestions for this character), the others are Dungeons, Raids and so on. Plus a
**minimap button** that opens the window, "like every addon has". The compact step window and the arrow of the
leveling guide stay.

## Order (decided)

1. The 28 race + class guides, levels 1-60 (docs/dev/PLAN.md). Done.
2. Then the atlas: the window, the knowledge base sections, the adventure flow beyond leveling. Started
   2026-11-14.

## Atlas stage: decisions of 2026-11-14

* **Name.** The addon is renamed from FastesBoooy to **Adventure Atlas** (core 0.5.0): folders `AdventureAtlas` and
  `AdventureAtlas_Guides`, global API table `AdventureAtlas`, SavedVariables `AdventureAtlasDB` /
  `AdventureAtlasCharDB`, slash commands `/aa` and `/atlas`. SavedVariables of FastesBoooy are not migrated (the
  engine recovers the route position from the game state; settings return to defaults). The core warns once per
  session about loaded folders of the old name. The repository is `adventure-atlas`.
* **History.** `docs/dev/PLAN.md`, `docs/dev/handover/` and `docs/dev/research/` are records of the guide stage and
  keep the old name and the paths of that time (`addons/FastesBoooy/...` is `addons/AdventureAtlas/...` now).
* **Window.** Opened by a minimap button (own code, no LibDBIcon). Two tabs for now:
  1. **"Твоё приключение"** (your adventure): the character's development path; for now leveling 1-60 plus the
     useful finds of the Forever community for fast leveling. Two modes: **calm** (play and level along the story)
     and **speedrun** (the existing race + class routes). Proposed for the calm mode: a zone and story-chain guide
     built from the DB chains (where to go at this level, which story chains are there, how far the character got),
     not a second set of hand-written step routes. Decided on 2026-11-15 as the narrative mode (below).
  2. **"База знаний"** (knowledge base): for now a quest list with search and filters (level, zone, class/race,
     done or not, "new in Forever"), with a quest card (start/end NPC, places, chain) and "lead me with the arrow".
* **Data.** Knowledge base quests are generated from `tools/data/forever_db.lua` into a load-on-demand data addon
  (proposed name `AdventureAtlas_Knowledge`). The DB snapshot is Horde-focused (few Alliance-only quests): the
  knowledge base is Horde-only for now. Community finds are sourced data entries (what, where, from which level,
  why useful, source); nothing unverified is shown as fact.
* **Order.** Rename -> window + minimap button -> knowledge base -> your adventure (speedrun overview, calm mode,
  finds).

## Narrative mode: decisions of 2026-11-15

The "calm" mode of 2026-11-14 is built as the **narrative mode** (stage 1). The owner's goal for it is maximum
content and missing nothing: the story, dungeons with their quests and lead-in chains, the Forever novelties
(camping, the sleeping bag, the Undercity library). The narrative flow must not break. Code: Core/Narrative.lua
and UI/AtlasNarrative.lua. Player-facing description: README.md, "Режим повествования". Data flow:
docs/ARCHITECTURE.md.

* **Goals, not steps.** The mode shows flexible goals with a progress bar per aspect, check boxes and a "where
  now" suggestion. It has no step route. The aspects are story, dungeon, class and "new in Forever" (stage 2
  adds professions, below).
  * Story goals are the chains of a zone, plus the errands of one giver ("<giver>: поручения").
  * Dungeon goals are a curated whitelist of the Horde leveling 5-mans with their quests. A dungeon's lead-in
    chains stay counted in their zone's story and are listed as "Подготовка" of the dungeon.
  * Class goals are the class quests of the character's class.
  * Novelty goals are curated.
* **Data.** The goals are a `goals` key in the existing AdventureAtlas_Knowledge/Quests.lua, so there is no new
  API, std or TOC line, and the quest records stay unchanged. tools/gen_knowledge_data.lua builds them with
  tools/lib/goals.lua from the snapshot and the curated tools/data/narrative.lua. The rules are in tools/README.md
  §11; `make knowledge-check` guards the file.
  * The first build has 530 goals: story 420, dungeon 20, class 87, novelty 3.
  * The 527 index-only quests of the snapshot (no NPCs, no chains) are left out. The bars therefore mean "of the
    content the snapshot knows".
* **Mode.** The mode is saved per character in `cdb.mode` and defaults to "speedrun". It is switched with two
  buttons on the "Твоё приключение" tab or with `/aa mode`. In narrative mode the engine has no route (gate in
  Engine:SelectRoute), so no route state is written and the automation rests. Switching back resumes the route
  where it was.
* **Evaluation (pure, Narrative.Evaluate).**
  * A slot is one quest, or an exclusive clique (any member done = done).
  * A non-clique exclusive member is its own slot, with partners in `goal.ex`; it is lost once a partner is done.
  * Lost propagates down pa/py chains.
  * Slot status, first match: done (turned in), out (not for this character, or lost), done (marked "done"),
    skip (marked), missed (every live member gray by level and none in the log), open.
  * Optional quests (breadcrumbs, no known giver, curated doubtful ones) count only once done.
  * Bar = done / (done + open). With the marks unchanged, turn-ins never lower the bar at a fixed level, and
    100% is reachable for all 28 race/class profiles. tests/spec/narrative_data_spec.lua proves both on the real
    data. Picking up a gray quest is the one exception: the quest is no longer untouched, so it joins the bar as
    open (spec rule "none in the log"), and abandoning it takes it out again.
  * A mark never counts a slot that is out: out is checked before the marks, and the check boxes mark only
    slots that are open, missed or already marked.
  * Gray is computed from levels (Compat.IsLevelGray), not from C_QuestLog.IsQuestTrivial, whose answer
    changes as quests get cached.
* **Where now (Narrative:Where).** Candidates are turn-ins, takes and dungeon entrances.
  * A take needs: available, gates met (curated `after` / `cnt`), level up to L + RED, not gray. A dungeon take
    also needs the player inside the dungeon's band.
    * `after` waits while the predecessor's slot is open. A done, marked, gray (missed) or out predecessor lets
      the next step through, so one gray step does not hide the rest of the sleeping bag chain.
    * `cnt` counts the done slots without a threshold of their own: the library books, not the rewards.
    * `startObj` navigates to start objects. A quest with no positioned start object (the library rewards at
      Owen Thadd) falls back to its NPCs.
  * A locked open slot is reached through a prerequisite walk. The walk may suggest a gray prerequisite, or an
    optional one (a breadcrumb that is the only way to a counted quest, e.g. 6562 before 6564 in BFD).
  * With no candidate, "wait" is the lowest level at which one appears: the required level, the quest level
    - RED, and a dungeon's lo.
  * The sort key, in order: distance bucket (NEAR1, NEAR2, same continent, other continent or no place), then
    priority (turn-in, chain, dungeon / lead-in, rest), then "about to go gray", then level, distance, id.
  * A curated `hint` promotes a quest to bucket 2, on the player's continent only.
  * "Along the way" shows the best candidate of each other aspect within NEAR2, never a quest already shown.
  * "Another continent" is said only when both continents are known. Inside an instance the player has no
    position, so targets are text without it.
  * The arrow label is the short line (what and where); the arrow shows the live distance. The 10 s ticker
    fires NARRATIVE_UPDATED only when the shown result (rows, rounded yards, wait) changed.
  * Follow ("Вести") is sticky while the target is still a candidate. It does not lead back to a target just
    reached. A "Lead me" from the knowledge base stops it.
* **Defaults chosen by the owner.**
  * **Gray.** Untouched gray quests leave the bars, so 100% stays reachable without going back for gray
    quests. The gray quests of the goals the player started count as "пропущено: N" next to the bar (N =
    quests, not goals). An untouched goal that went gray is listed as "прошли мимо" (passed by).
  * **Automation.** It is off in narrative mode: there is no route to say which quests to take.
* **Constants to tune after playing.** They are at the top of Core/Narrative.lua:

  | Constant | Value | Meaning |
  |---|---|---|
  | RED | 3 | take quests up to level L + 3 |
  | NEAR1 | 400 yd | bucket 1 |
  | NEAR2 | 1500 yd | bucket 2 and "along the way" |
  | PREP_LEAD | 2 | lead-in quests count from dungeon lo - 2 |
  | WALK | 5 | prerequisite walk depth |
  | ALONG | 4 | detours at most (the step window shows 2; was 3 in stage 1) |
  | GRAY_GAP | 100 | gather hint: a bracket gives skill until its lo + 100 (stage 2) |
  | TIERS | 75/150/225 | profession rank-ups: cap, next rank, skill and level needed (stage 2, below) |
  | TICK | 10 s | "where now" re-check |
  | DEBOUNCE | 0.5 s | recompute coalescing |
* **Later stages.** They only add keys. Done in core 0.6.0 (next section), except two items:
  * **Stage 2: professions.** Done: Compat.SkillRank (still to be checked in game), `sk` from the snapshot (no
    curated gates were needed), the "Профессии" aspect. Not done: widening the snapshot for the index-only class
    chains. Index records have no NPCs and no chains, so the DB data cannot build them.
  * **Stage 3: items and finds.** Done: curated dungeon notes, the blueprints, item-in-bags suggestions. Not done:
    opt-in automation for the followed goal. It was "only if asked"; it is raised with the owner.
* **Open; in-game checks are in docs/routes/confirm-in-game.md.** None of this has been played yet. Expect to
  tune:
  * the constants above;
  * the large story goals: Stranglethorn 19 quests, Tanaris 18, Barrens 15. Curated `titles` / `exclude` can
    fix them;
  * the derived bands of 11 dungeons.

## Narrative stages 2 and 3: decisions of 2026-11-15

The owner asked for profession leveling advice ("советы по прокачке профессий") and for useful items to collect
("сбор всяких айтемов"), under the stage-1 principle: maximum content, miss nothing, never break the narrative
flow. Both are in core 0.6.0. Code: Core/Narrative.lua, Core/Compat.lua, UI/AtlasNarrative.lua; data rules:
tools/README.md §11; player-facing: README.md, "Режим повествования".

* **New concepts (the only ones).**
  1. Quest records carry two snapshot fields: `sk = { skill line, rank }` (db reqSkill) and `sp = spell` (a
     negative db reqSpell: the quest is gone once the spell is known). `sp` marks exactly the 44 Camping 101
     <profession> quests; the spell is the camp item.
  2. A fifth aspect, **profession**: one generated goal per skill line (`p<line>`, `line`), built from that line's
     quests (stage 1 left them out). Curated per line (tools/data/narrative.lua `professions`): name, note,
     `train` (rank-up places by tier), `blueprints` (camp blueprints: skill, dungeon, boss), `brackets` (what to
     gather or make at which skill, and where), source, `v = false`. A line the character lacks has its quests
     "out": no bar share, no row, no hints. Build: 12 profession goals (543 goals in all).
  3. **Hints** in "where now", never counted: `train` (at the rank cap, near a trainer or book seller), `gather`
     (the player stands in a zone that suits the skill), `start` (an item in the bags starts a quest; generic, no
     data), `use` (a curated item is in the bags: Waylaid Crates -> Dokimi). Candidates get a string `ref`.
  4. **Side candidates**: everything of a profession goal (except turn-ins) and of the slotless container goal
     `n:finds` (`q = {}`, `use` records). A side candidate is never the main suggestion while a non-side one
     exists, and loses ties to non-side ones in the same bucket: the sort key is bucket, then side, then the
     stage-1 key. Side candidates surface as "Попутно" detours; ALONG goes from 3 to 4 (the atlas has 4 detour
     rows, the step window still 2; the window is 40 px taller). When a side candidate is main, "wait" is still
     computed and shown next to it (the narrative answer is not hidden behind a hint). A `use` hint is near
     (bucket <= 2) only when its turn-in NPC is on this continent; on another continent it stays text-only and
     cannot be led to, like every other candidate there. The bags are re-read on BAG_UPDATE_DELAYED, and "where
     now" is re-checked only when a watched item (start or `use` item) came or went.
  5. Curated `note` on dungeon goals (Scarlet Key, Dalaran Sewer Key, the Zul'Farrak mallet) and the dungeon
     tooltip lists the blueprints that drop there for the character's professions.
* **No "Полезное" bar.** Items in the bags are not monotone (sold, used); learned blueprints cannot be detected
  (IsPlayerSpell is not in the API dump, IsSpellKnown for recipes is unconfirmed); quest items (bags, keys,
  library rewards) are already counted through their quests. So the stage-1 guarantee holds: bars only rise on
  turn-ins and reach 100%. Two documented exceptions change the total: learning a profession adds its quests,
  and the camp spell becoming known removes the Camping 101 slot.
* **Profession quests.** Their level gate is the required level only (no "level + RED" check), and they are never
  gray: a skill quest waits for the skill, not for the level. A quest whose rank is not reached yet shows
  "навык N" ("later" state). tests/spec/narrative_data_spec.lua plays every profession goal to 100% with all
  skills at 300.
* **Camping 101** has no curated `sk` override: the DB take gate is skill 1, and Wowhead says the objective is to
  raise the skill to 20; the quest is taken at 1 and completes in the log, which the turn-in logic handles.
  `sp` relies on Compat.IsSpellKnown (C_SpellBook.IsSpellKnown or IsSpellKnownOrInSpellBook). Plan B if the
  in-game check fails: Camping 101 <profession> becomes curated `opt`; the "сам" box is the immediate way out.
* **TIERS** (Core/Narrative.lua; warcrafttavern profession-trainers rank table, not checked in game): at max rank
  75 / 150 / 225 the next rank (150 / 225 / 300) needs skill 50 / 125 / 200 and character level 10 / 20 / 35.
  Secondaries (First Aid, Cooking, Fishing; `sec`) have two trained tiers (tier 2 from a book); their last rank is
  the quest. Cooking and First Aid have no level gate (curated `nolv`: their cited guides name only the skill);
  Fishing keeps it (wow-professions: Journeyman Fishing level 10, the Expert book level 20, as warcraftdb's
  required_level of item 16083). The gathering trainers of the data teach every rank (wow.gg "Up to Skill 300",
  warcrafttavern "Artisan", Mishiki / Krunn / Yonn Deepcut / Rand Rhobart included; the 75-cap trainers of the
  starting areas are new NPCs outside the data), so tiers 2 and 3 repeat tier 1. The generator checks the
  subtitle rank word against the tier.
* **GRAY_GAP = 100.** The gather hint picks the highest bracket with lo <= skill < lo + 100 whose zones contain
  the player's map, and only below the rank cap (no skill is gained at the cap). The 100 is the Classic "gray at
  the requirement + 100" rule, not checked in game.
* **Blueprint skill.** The skill to learn a blueprint is the one of its recipe spell at forever.warcraftdb.com
  (`api/data/node/spell/<id>`): 140 for all but Tanning Rack 125 (warcrafttavern says 140) and Journeyman
  Campfire 90.
* **Start rule.** A quest-starting item in the bags is suggested (bucket 1). A quest of a goal keeps the goal's
  take gate (goal neither skipped nor done, its slot open, not gray, the dungeon band, `after` / `cnt`, level +
  RED); a quest outside every goal belongs to `n:finds`, is side, and is gated only by its required level:
  those are the generator-excluded "anylevel" Forever quests (98248 Shipping Label is level 60, required 10),
  whose quest level means nothing.
* **Muting.** "не надо" on a profession goal also mutes its train and gather hints (mute = the goal mark is
  "skip"). A profession with no unfinished slot cannot be muted; its hints are proximity-gated. No second marks
  store.
* **Specialisations.** Engineering (gnomish / goblin) is closed by the DB `ex`; the Blacksmithing armorsmith /
  weaponsmith and Leatherworking quests are cliques; the weaponsmith masters 5305 / 5306 / 5307 are curated `opt`
  (choosing one closes the others, not linked in the DB).
* **Left out, with reasons.**
  * The Barrens rare set: low confidence in the sources.
  * The Scarlet Banner: cosmetic.
  * Bags: already counted as quests.
  * Craftsman's Writs beyond the start rule.
  * Tier-300 blueprints: endgame.
  * Riding: no Forever source for the trainer or the cost.
  * A hint for players with no profession: YAGNI.
  * Widening the snapshot for the index-only class chains: index records have no NPCs or chains.
  * Automation for the followed goal: it was "only if asked"; raised with the owner.

## Status

* 2026-11-14: knowledge base, first version. tools/gen_knowledge_data.lua writes the Horde-available quests of the
  snapshot with the DB overrides applied (3358: 2831 full records + the out-of-scope index, which has no NPCs or
  chains; zone, levels, race / class masks, start / end NPCs with positions, chain, XP, "new") into the
  load-on-demand addon AdventureAtlas_Knowledge (TOC `## X-AdventureAtlas-Module: data`: the route tools skip it).
  Core/Knowledge.lua loads and searches it; UI/AtlasKnowledge.lua is the tab (search by name or zone, level range,
  "for my character", "hide done", "only new", quest card, "lead me" = Waypoint:SetCustom). Open: quest titles in
  Russian only when the client has cached them (searching in Russian finds only those); NPC names are enUS;
  quest sorts -1 and 0 have no category name ("Other"); the area of the Craftsman's Writs (16941) is our label;
  class follow-ups that differ by class (byClass in the snapshot) are not shown; "Lead me" is off for targets on
  another continent.
* 2026-11-14, core 0.5.0: renamed. The window (UI/Atlas.lua, BasicFrameTemplateWithInset, own tab buttons) and the
  minimap button (UI/MinimapButton.lua) exist. "Your adventure" shows the active route, its progress and its
  chapters (Engine:GetChapters: segment runs, steps that are not background goals); "Knowledge base" is a
  placeholder. Escape closes the window (`UISpecialFrames`: missing from the generated API dump, confirmed in game
  and listed in tools/data/forever_api_confirmed.lua).

* 2026-11-15: narrative mode, stage 1 (decisions above).
  * Goals in the knowledge base data.
  * Core/Narrative.lua.
  * Mode buttons, the narrative view of "Твоё приключение" (UI/AtlasNarrative.lua), the step window card and
    `/aa mode`.
  * Not checked in game yet.

* 2026-11-15, core 0.6.0: narrative stages 2 and 3 (decisions above).
  * Professions aspect (12 goals), profession tooltips (skill, next rank, leveling brackets, blueprints), the
    hints train / gather / start / use, the finds goal, dungeon notes, 4 detour rows.
  * Compat.SkillRank and Compat.IsSpellKnown; the in-game checks are listed in docs/routes/confirm-in-game.md.
  * Not checked in game yet.

## What this meant for the guide work

* Packaging stays: `AdventureAtlas` (core) + `AdventureAtlas_Guides` (data). Atlas data will be further data files or
  one more data addon; the window lives in the core. Nothing in the guide phases should assume that routes are
  the only kind of content a data module registers.
* Class files (`Classes/<Class>.lua`), race files and the hand-over notes are also the raw material of the
  "Classes" and "World and services" sections: keep facts structured and sourced (trainer ids and places, class
  quest chains and what they reward, riding, weapon masters, transports), and record facts that do not fit a
  route step in `docs/dev/handover/*.md` instead of dropping them.
* Optional content the leveling path skips (dungeon quest blocks, profession quests, elite chains) is material
  for the adventure flow: note it in the hand-over rather than deleting knowledge about it.
* User-visible names carry no faction ("Орк-воин 1-60"); the same rule will hold for atlas sections.
* Everything the atlas shows must come from data that is true for Forever (DB snapshot, in-game recordings,
  cited sources). Unknown or unverified facts are marked as such, as in the guides.

## Open (to design when the atlas stage starts)

* The "relevant for you" tab: which signals (level, class, professions, quest log, gear) and which suggestions.
* Data sources for bosses, loot and professions (the DB snapshot has quests, NPCs, zones and items referenced by
  quests; not loot tables or recipes).
* How the knowledge base is replenished (data files in the repository; maybe an in-game notes layer).
