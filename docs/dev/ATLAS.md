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
  now" suggestion. It has no step route. The aspects are story, dungeon, class and "new in Forever".
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
  | ALONG | 3 | detours at most (the step window shows 2) |
  | TICK | 10 s | "where now" re-check |
  | DEBOUNCE | 0.5 s | recompute coalescing |
* **Later stages.** They only add keys.
  * **Stage 2: professions.**
    * Compat.SkillRank, after an in-game check.
    * Curated `sk` gates, for example the Camping 101 profession quests.
    * A "Профессии" aspect from the reqSkill quests.
    * Maybe widen the snapshot for the index-only class chains.
  * **Stage 3: items and finds.**
    * Curated notes on dungeon goals, such as the camping blueprints.
    * Item-in-bags suggestions.
    * Opt-in automation for the followed goal, only if asked.
* **Open; in-game checks are in docs/routes/confirm-in-game.md.** None of this has been played yet. Expect to
  tune:
  * the constants above;
  * the large story goals: Stranglethorn 19 quests, Tanaris 18, Barrens 15. Curated `titles` / `exclude` can
    fix them;
  * the derived bands of 11 dungeons.

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
