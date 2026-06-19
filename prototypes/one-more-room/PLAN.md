# Implementation Plan: One More Room (MVP)

> Built from `DESIGN.md` §9 MVP scope. Goal: a **fun, complete push-your-luck loop**
> that can be played and verified headlessly via MCP, with a written fun report.
> Everything in §10 (stretch) is explicitly deferred.

**Art direction (decided):** custom SVG icons rendered to PNG via the
`godot_generate_2d_asset` MCP tool — cohesive style, no Godot-4 emoji-font issues.

---

## Overview

A single-screen 2D Control UI game. `game.gd` owns all state and emits signals; the
UI is a passive subscriber. One deck (~30 cards), 5 hazard types, second-sighting-of-a-
type busts, live danger %, one relic (Lantern) for MVP, 3 expeditions per run.

## Architecture Decisions

| Decision | Rationale |
|---|---|
| `Control`-based UI scene (not `Node2D`) | Pure UI game per §7; anchors/containers give free layout |
| `game.gd` = single source of truth; UI subscribes via signals | Matches §8; makes headless rule-testing trivial |
| Cards = `Dictionary` (`{kind, value, hazard_type, special_id}`) | Simplest; no Resource boilerplate for MVP |
| `RandomNumberGenerator` with settable `seed` | Reproducible playtests/bug reports (§8) |
| Custom SVG→PNG icons via `godot_generate_2d_asset` | Decided above; cohesive, MCP-native |
| Sounds: Kenney UI Audio CC0 (download) + synthesized fallback | Free, Godot-proven; fallback if no net |
| Fonts: Google Font OFL (Cinzel for titles, Inter for body) | Free, themed, tabular figures for counting numbers |
| **Keep renderer on Forward+** (don't touch) | §8: 2D renders fine on it; horror proto needs it |
| Switch `run/main_scene` → this prototype while building | Faster Play-button iteration; reversible |

---

## Dependency Graph

```
Assets (icons/sounds/fonts) ──┐
                              ├──> Project scaffold (scene + folder)
Deck (deck.gd) ──────────────────────┐
                                      ├──> Game logic (game.gd) ──┐
                                      │                           ├──> UI wiring
                                      │                           │
                                      └──> Headless rule tests ───┘    │
                                                                       ▼
                                                                Minimal UI playable
                                                                       │
                                              ┌────────────────────────┤
                                              ▼                        ▼
                                        Full UI panels              Lantern relic
                                              └───────────┬────────────┘
                                                          ▼
                                                       Juice pass
                                                          │
                                                          ▼
                                                  Run structure + endgame
                                                          │
                                                          ▼
                                              MCP test loop + FUN_REPORT
```

Build **bottom-up**, but each phase ends in a playable/verifiable state (vertical slices).

---

## Phases & Tasks

### Phase 0 — Assets & Foundation (parallelizable)

#### Task 0.1: Generate icon set (SVG → PNG)
**Description:** Use `godot_generate_2d_asset` to create a cohesive icon set.
**Acceptance:**
- [ ] Treasure icon (coin) — 1 file
- [ ] 5 hazard icons: Gas, Cave-in, Spiders, Flood, Curse
- [ ] 4 relic icons (generate all 4 now even though MVP uses 1): Lantern, Antidote, Rope, Charm
- [ ] Special/shrine icon, unknown-card-back icon
- [ ] All saved to `res://prototypes/one-more-room/assets/icons/`
**Verification:** `list_dir` shows 12 PNGs; open one to confirm dimensions ~128×128.
**Dependencies:** None. **Scope:** S (0 code files, ~12 asset generations).

#### Task 0.2: Source sound effects (free CC0)
**Description:** Download Kenney UI Audio pack (CC0); pick coin, click, negative-sting, rumble-ish, cha-ching-ish. If no network, synthesize via `AudioStreamGenerator` in code as fallback.
**Acceptance:**
- [ ] `coin.wav` (treasure flip)
- [ ] `click.wav` (button)
- [ ] `sting.wav` (hazard first sighting)
- [ ] `rumble.wav` (bust)
- [ ] `chaching.wav` (bank)
- [ ] All in `res://prototypes/one-more-room/assets/sounds/`
**Verification:** `get_resource_info` on each confirms loadable AudioStream + length > 0.
**Dependencies:** None. **Scope:** S.

#### Task 0.3: Fonts & theme
**Description:** Download Cinzel (titles) + Inter (body) OFL from Google Fonts. Create a `Theme` resource with font sizes, colors (gold for treasure, red for danger, cool blue for vault).
**Acceptance:**
- [ ] `cinzel.ttf`, `inter.ttf` in `assets/fonts/`
- [ ] `theme.tres` with font assignments + color palette
**Verification:** `get_resource_info` on fonts; assign theme to root in scaffold scene.
**Dependencies:** None. **Scope:** S.

#### Task 0.4: Project scaffold
**Description:** Create main scene skeleton (`one_more_room.tscn`, root `Control`) + empty `game.gd`/`deck.gd` stubs. Set `run/main_scene` to this scene.
**Acceptance:**
- [ ] Scene opens in editor without error
- [ ] `run/main_scene` → `res://prototypes/one-more-room/one_more_room.tscn`
- [ ] `get_errors` clean
**Verification:** `run_scene` boots to an empty (but error-free) screen.
**Dependencies:** 0.3 (theme to attach). **Scope:** S.

### ✅ Checkpoint A — Foundation ready
- [ ] All icons/sounds/fonts present and loadable
- [ ] Scene boots clean headlessly

---

### Phase 1 — Core Game Logic (headless-testable, no UI)

#### Task 1.1: `deck.gd`
**Description:** Build deck from §6 tables (18 treasure, 5×3 hazards, 2 specials = 35 — trim to ~30 per design note if needed). Shuffle (Fisher-Yates). `draw()` pops top. Card = Dictionary.
**Acceptance:**
- [ ] `build_deck()` returns 30-card array matching §6 composition
- [ ] `shuffle(seed)` reproducible for same seed
- [ ] `draw()` returns a card Dict with correct keys
**Verification:** `validate_script` clean; headless MCP script prints counts.
**Dependencies:** 0.4. **Scope:** S (1 file).

#### Task 1.2: `game.gd` state machine
**Description:** Holds `vault`, `unbanked`, `seen_hazards: Dictionary`, `expedition_index`, `deck`. Methods: `start_run()`, `start_expedition()`, `on_push()`, `on_bank()`, `resolve_card()`, `compute_danger()`, `bust()`, `end_expedition(safe)`. Signals: `treasure_gained`, `hazard_seen`, `busted`, `banked`, `danger_changed`, `expedition_started`, `run_ended`. Gold curve `10*(1+0.18*depth)±15%`.
**Acceptance:**
- [ ] Second sighting of a hazard type → `busted` signal + `unbanked=0` + expedition ends
- [ ] First sighting → `hazard_seen` + stays in expedition
- [ ] `compute_danger()` = `distinct_seen / cards_remaining`, rounded %
- [ ] `on_bank()` → `vault += unbanked`, `unbanked=0`, expedition ends safe
- [ ] Gold curve scales with depth as specified
**Verification:** Headless test harness: fixed seed, force a known deck order, assert each rule. `get_errors` clean.
**Dependencies:** 1.1. **Scope:** M (1 file, but the load-bearing one).

#### Task 1.3: Headless rule verification
**Description:** Write a tiny test script (or MCP-driven `run_scene` + `query_runtime_node`) that plays a fixed-seed expedition and asserts: bust rule, danger formula, gold curve, bank safety.
**Acceptance:**
- [ ] All §3/§4 rules verified against fixed seed
- [ ] Results captured in `TEST_LOG.md`
**Verification:** Test passes; `get_errors` clean.
**Dependencies:** 1.2. **Scope:** S.

### ✅ Checkpoint B — Rules proven correct before any UI
- [ ] Bust/bank/danger/gold all behave per spec
- [ ] Reproducible with seed

---

### Phase 2 — Minimal UI (end-to-end playable)

#### Task 2.1: Build scene tree per §7
**Description:** Create the node structure from §8 (GameController, UI CanvasLayer with RunHeader/RoomTrack/StatePanel/RelicBar/ButtonBar, DeckModel). Use Containers for layout.
**Acceptance:**
- [ ] Tree matches §8 structure
- [ ] Layout non-overlapping at 1152×648
**Verification:** `scene_tree_dump` matches; screenshot shows clean layout.
**Dependencies:** 1.2, 0.4. **Scope:** M (scene + 1 script edit).

#### Task 2.2: Wire UI to signals
**Description:** Connect `game.gd` signals to UI updaters. Room cards spawn into RoomTrack HBoxContainer.
**Acceptance:**
- [ ] PUSH reveals a card → new room card appears
- [ ] Treasure → unbanked label updates
- [ ] Hazard → seen-hazards updates
**Verification:** Play 5 pushes via MCP `send_input`, `take_screenshot` shows progression.
**Dependencies:** 2.1. **Scope:** S.

#### Task 2.3: PUSH/BANK buttons functional
**Description:** Buttons call `on_push()`/`on_bank()`. Disabled states during resolution.
**Acceptance:**
- [ ] Click PUSH → card flips
- [ ] Click BANK → expedition ends, vault increases
**Verification:** Full single-expedition playable by clicking.
**Dependencies:** 2.2. **Scope:** S.

### ✅ Checkpoint C — A full expedition is playable by clicking

---

### Phase 3 — Full MVP UI Panels

#### Task 3.1: Live danger % (with color shift)
**Acceptance:** Danger % updates every flip; turns yellow >25%, red >50%. `danger_changed` drives it.
#### Task 3.2: Seen-hazards row
**Acceptance:** Hazard icons appear in a row as first-sighted; styling distinct from room track.
#### Task 3.3: Unbanked vs vault styling
**Acceptance:** Unbanked gold/warm; vault cool/blue; both clearly different (§7).
#### Task 3.4: Run header
**Acceptance:** Shows "Expedition X / 3" and live vault total.

**All Phase 3 deps:** 2.3. **Scope:** M total (UI edits only).

### ✅ Checkpoint D — Screen matches §7 layout and communicates state at a glance

---

### Phase 4 — Lantern Relic (the mitigation hook)

#### Task 4.1: `relics.gd` + Lantern effect
**Acceptance:** Lantern definition present; `use_lantern()` returns top card without drawing; one-use per expedition.
#### Task 4.2: Relic UI + peek overlay
**Acceptance:** Lantern button in RelicBar; clicking shows next card in an overlay; consumed after use.
#### Task 4.3: Verify peek changes decisions
**Acceptance:** Headless test: with known top card, player can BANK safely.

**Deps:** 3.x. **Scope:** M (1 new script + UI).

### ✅ Checkpoint E — Strategy exists (peek → informed bank)

---

### Phase 5 — Juice (this is what makes it *fun*)

#### Task 5.1: Treasure coin count-up
Tween unbanked number upward + `coin.wav`.
#### Task 5.2: Bust sequence
Screen shake (tween offset), `rumble.wav`, unbanked smashes to 0, room track collapse animation.
#### Task 5.3: Bank sequence
`chaching.wav`, vault count-up, calm fade transition.
#### Task 5.4: Danger % stress pulse
Subtle pulse/tween as danger climbs; intensifies past 50%.

**Deps:** Phase 3 + 0.2 sounds. **Scope:** M (tweens in UI scripts).

### ✅ Checkpoint F — Bust feels bad (good), bank feels great

---

### Phase 6 — Run Structure & Endgame

#### Task 6.1: 3-expedition run flow
Between expeditions: brief transition, fresh shuffled deck, unbanked resets, vault persists.
#### Task 6.2: Final score screen + restart
After expedition 3: show final vault, "Play Again" button → `start_run()`.

**Deps:** Phase 5. **Scope:** M.

### ✅ Checkpoint G — A complete run is playable start → score → restart

---

### Phase 7 — MCP Testing & Fun Report

#### Task 7.1: Full headless MCP test loop
**Description:** Per design §8 — `run_scene` (wait_for_runtime) → `send_input` PUSH ×N → `take_screenshot` at key moments → force bust → verify unbanked=0 → `get_errors` clean → `stop_scene`. Run a full 3-expedition game automated.
**Acceptance:**
- [ ] Automated play completes a run
- [ ] Screenshots captured at: first treasure, danger climbing, bust, bank, final score
- [ ] Zero errors throughout
**Verification:** Screenshots + `get_errors` clean at every step.

#### Task 7.2: Balance playtest & tuning
**Description:** Play multiple seeded runs. Check: does danger climb at a fun rate? Is deep diving tempting? Is banking satisfying? Adjust §6 dials (hazard counts, 0.18 multiplier) if needed. Log changes.
**Acceptance:**
- [ ] At least 3 full runs played
- [ ] Any tuning changes documented with before/after rationale

#### Task 7.3: Write `FUN_REPORT.md`
**Description:** Report back to the user: Is it fun? Where's the tension? What clicks? What's missing for the next pass? Concrete tuning suggestions for §11 open questions.
**Acceptance:**
- [ ] Answers "is it fun?" honestly
- [ ] References §11 open tuning questions with playtest-informed answers
- [ ] Lists top 3 things to add next (from §10)

**Deps:** Phase 6. **Scope:** S (docs).

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Godot editor disconnects mid-test (we hit this earlier) | Med | tmux session `godot`; `get_godot_status` before each test; reconnect + re-run |
| No network → can't download Kenney sounds/fonts | Med | Synthesize beeps via `AudioStreamGenerator`; use Godot default font as font fallback |
| Danger curve not fun on first pass | High | Phase 7.2 explicitly budgets for tuning §6 dials |
| Scope creep into other relics / meta-shop | Med | Strict §9 MVP; log every stretch idea in FUN_REPORT instead of building it |
| Color emoji rendering (if any slips in) | Low | Eliminated by SVG-icon decision |
| UI breaks at non-1152×648 sizes | Low | Use Containers + anchors; test at default size for MVP |
| Headless audio errors (ALSA dummy) | Low | Benign, ignore (seen in horror proto) |

## Open Questions (resolve during build)

1. **Sound source:** Try Kenney UI Audio CC0 download first; synthesize fallback. (No human input needed unless both fail.)
2. **Exact fonts:** Plan on Cinzel + Inter; if download fails, use Godot default + bold weighting.
3. **Hazard count 3 vs 2 per type (§11):** Start at 3 per §6 default; revisit in Phase 7.2.
4. **Danger % formula (§11):** Start with simple `seen/remaining` per design default.
5. **Switch `run/main_scene` now?** Yes (reversible) — speeds iteration.

## Verification (the plan is done when)

- [ ] Every task above has acceptance criteria ✓ (intrinsic)
- [ ] Full 3-expedition run playable headlessly via MCP
- [ ] Bust/bank/treasure/danger all behave per §3–§4
- [ ] Lantern peek works end-to-end
- [ ] Juice present (shake, count-ups, sounds)
- [ ] `get_errors` clean across a full automated run
- [ ] `FUN_REPORT.md` written and answers "is it fun?"
