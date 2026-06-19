# One More Room — Game Design Document

> A push-your-luck dive into a collapsing ruin. Every step deeper is richer — and
> closer to never coming back. The only question the game ever asks you: **bank it, or push?**

**Status:** design complete, not yet built.
**Type:** single-player, turn-based, push-your-luck (card/decision game).
**Renderer:** 2D (this is a UI/card game — do **not** use Forward+/3D here).
**Target:** a small, complete, *fun* core loop first; layer depth afterward.

This doc is written to be handed to a build agent with no prior context. It is
self-contained: read it top to bottom and you can build the MVP.

---

## 1. The pitch

You lead an expedition into a ruin that crumbles a little more with every room you
enter. You flip rooms one at a time; treasure piles up but stays **unbanked**. The
deeper you go the richer the rooms — but each new hazard you see tightens the noose.
The second time the *same* hazard appears, the ruin collapses and you flee with
**nothing you hadn't banked**. At any moment you may **bank** your haul and walk out
safe, ending the expedition.

The entire game is the tension between greed (PUSH) and safety (BANK), and the skill
is reading the odds and spending your mitigation tools at the right moment.

---

## 2. Design pillars (why this is fun, not frustrating)

These are the *reasons* behind every rule below. Preserve them when making changes.

1. **Self-inflicted risk.** The player always chooses to be in danger (they pressed
   PUSH). Never bust a player on a decision they didn't opt into. This is the single
   most important rule — it's the difference between thrilling and infuriating.
2. **Input randomness, not output randomness.** Randomize *what the ruin contains*
   (the deck), then let the player plan around it. Never randomize the outcome of a
   choice already committed (no "your bank failed" coin-flips).
3. **Legible odds.** The bust probability is shown live as a **danger %**. Players
   should always be able to feel the risk climbing. Hidden math kills the tension.
4. **Tools to bend luck.** Relics let players hedge, peek, and cancel danger. The
   strategy lives in *when* you spend them.
5. **Comeback variance.** The deepest rooms hold jackpot loot, so a player who's
   behind has a valid (if reckless) line. Games stay live to the final flip.

---

## 3. Core loop

```
START EXPEDITION
   │
   ├──> Reveal nothing yet. unbanked = 0. seen_hazards = {}.
   │
   ▼
PLAYER CHOICE  ──────────────────────────────┐
   │                                          │
   │  PUSH                              BANK   │
   ▼                                          ▼
FLIP TOP CARD                          vault += unbanked
   │                                   unbanked = 0
   ├─ Treasure → unbanked += value     EXPEDITION ENDS (safe)
   │             back to CHOICE
   │
   ├─ Hazard(type)
   │     ├─ type NOT in seen_hazards → seen_hazards.add(type); back to CHOICE
   │     └─ type IN seen_hazards     → BUST: unbanked = 0; EXPEDITION ENDS (collapse)
   │
   └─ Special → resolve effect (relic / shrine / fork); back to CHOICE
```

A **run** = several expeditions in a row (default 3). Between expeditions the player
keeps their **vault** total and (later) spends it in a meta-shop. The run's score is
the final vault.

---

## 4. Rules in detail

- **Deck.** Each expedition draws from a freshly shuffled depth deck (~30 cards). The
  deck is *not* fully revealed; the player flips the top card on each PUSH.
- **Unbanked vs. vault.** Treasure goes to `unbanked`. Only **BANK** moves `unbanked`
  → `vault`. A **bust** zeroes `unbanked` (vault is always safe).
- **Hazard bust rule.** There are 5 hazard *types*. The first sighting of a type is
  harmless (a scare). The **second** sighting of *any one type* ends the expedition
  with a bust.
- **Deeper = richer.** Treasure values are drawn so that cards deeper in the deck pay
  more (see gold curve, §6). This makes pushing genuinely tempting even as danger
  rises.
- **Bank is always available** before a flip, and always safe.
- **Specials** never bust. They give relics or one-time effects.

### Bust probability (show this to the player)

```
danger_next_flip = distinct_hazards_seen / cards_remaining_in_deck
```

Display it as a percentage. Example: 3 hazard types seen, 12 cards left → 25% chance
the next flip busts. This is an estimate (it ignores that some remaining cards are
treasure of unknown count to the player, which is fine — it's the *felt* risk and it's
honest enough). Round to nearest whole percent.

---

## 5. The mitigation layer (where strategy lives)

Relics are brought in via a pre-run **loadout** (pick N) and/or found as Specials mid-run.

| Relic | Effect | The decision it creates |
|---|---|---|
| 🔦 **Lantern** | Peek the top card before you choose PUSH/BANK | Use the info now, or save it for a tighter spot |
| 🧪 **Antidote** | Remove one already-seen hazard type from `seen_hazards` | When to spend your "get out of jail free" |
| 🪢 **Rope** | Bank **half** of `unbanked` but keep diving | Hedge instead of all-or-nothing |
| 🍀 **Charm** | Turn the next hazard you flip into treasure (one-shot) | Gamble on top of the gamble |

Each relic is **one-use per expedition** unless stated otherwise. The loadout choice
(which relics, how many charges) is the pre-run strategy; *when* to fire them is the
in-run strategy.

---

## 6. Tunable data (starting values)

These are starting points for a build agent to drop into code as constants/resources.
Tune by playtest; the danger formula and the "second-hazard-busts" rule are the only
sacred parts.

### Deck composition (~30 cards per expedition)

| Card | Count | Notes |
|---|---|---|
| Treasure | 18 | gold value from the curve below, scaled by draw depth |
| Hazard — Gas ☠️ | 3 | hazard type A |
| Hazard — Cave-in 🪨 | 3 | hazard type B |
| Hazard — Spiders 🕷️ | 3 | hazard type C |
| Hazard — Flood 🌊 | 3 | hazard type D |
| Hazard — Curse 💀 | 3 | hazard type E |
| Special — relic/shrine | 2 | never busts |

> Note: with 3 of each hazard type, two-of-a-kind is *likely* in a deep dive — that's
> intended. The bust comes from the **second** sighting, so the danger ramps fast once
> you've seen several distinct types. Designers can lower hazard counts to 2 each for a
> punchier, shorter deck.

### Gold curve (deeper = richer)

Treasure value scales with how deep the card is drawn (`depth` = number of rooms
entered so far, starting at 1):

```
gold_value = base_gold * (1 + 0.18 * depth) ± small_jitter
base_gold  = 10
```

So room 1 treasure ≈ 12, room 10 ≈ 28, room 20 ≈ 46. Add ±15% jitter for texture.
Tune the 0.18 multiplier to push the greed/safety break-even deeper or shallower.

### Run / scoring

- Default run = **3 expeditions**; score = final `vault`.
- Optional **Endless** mode: one expedition deck reshuffles forever; score = highest
  vault reached before a bust ends the run.

---

## 7. UI layout (the whole screen)

A single screen. No camera, no world — just clear, juicy UI.

```
┌──────────────────────────────────────────────────────────────┐
│  Expedition 2 / 3                         VAULT:  340 g        │  ← run header
├──────────────────────────────────────────────────────────────┤
│                                                                │
│   Revealed rooms (left → right, scrolls):                      │
│   [💰12] [💰15] [☠️Gas] [💰19] [🕷️Spiders] [💰24] [ ? ]        │  ← room track
│                                                                │
├──────────────────────────────────────────────────────────────┤
│   UNBANKED:  86 g            DANGER (next flip):  29% ▲        │  ← live state
│   Seen hazards:  ☠️ 🕷️                                          │
├──────────────────────────────────────────────────────────────┤
│   Relics:  [🔦 Lantern]  [🪢 Rope]                              │  ← clickable relics
├──────────────────────────────────────────────────────────────┤
│            [   PUSH (one more room)   ]   [   BANK   ]          │  ← the two buttons
└──────────────────────────────────────────────────────────────┘
```

**Must communicate at a glance:** unbanked vs. vault (different colors), the danger %
(turns red as it climbs), which hazard types have been seen, and the two choices.

**Juice that makes it feel good (cheap, high-impact):**
- Treasure flip → coin count-up sound + number pop on UNBANKED.
- Hazard *first* sighting → tension sting, hazard icon slots into "Seen".
- Hazard *second* sighting (BUST) → screen shake, rumble, room track collapses,
  UNBANKED smashes to 0.
- BANK → satisfying "cha-ching", vault count-up, calm exit transition.
- DANGER % ticking up should be visible and a little stressful.

---

## 8. Suggested Godot implementation (for the build agent)

Follow the playground conventions in the repo `README.md`:
- Put everything under `prototypes/one-more-room/`.
- 2D project settings; **do not** switch the renderer to Forward+ for this — it's a 2D
  UI game. (The horror prototype needs Forward+; this one does not. If both must
  coexist, leave the project on Forward+ — 2D renders fine on it — just don't rely on
  3D-only features here.)
- When ready to make it the default Play target, point `run/main_scene` at this
  scene. Otherwise run it with Play Scene (F6).

### Scene tree (one main scene)

```
OneMoreRoom (Node2D or Control)
├── GameController        (script: game.gd)  — owns all state & rules
├── UI (CanvasLayer)
│   ├── RunHeader         (expedition X/N, vault label)
│   ├── RoomTrack         (HBoxContainer in a ScrollContainer; room cards added here)
│   ├── StatePanel        (unbanked label, danger % label, seen-hazards row)
│   ├── RelicBar          (HBoxContainer of relic buttons)
│   └── ButtonBar         (PushButton "PUSH", PushButton "BANK")
├── DeckModel             (script: deck.gd) — build/shuffle/draw the depth deck
└── AudioStreamPlayers / particles for juice
```

### Scripts

- **`game.gd`** — the state machine and rules. Holds `vault`, `unbanked`,
  `seen_hazards: Dictionary`, `expedition_index`. Methods: `on_push()`, `on_bank()`,
  `resolve_card(card)`, `compute_danger()`, `bust()`, `end_expedition(safe: bool)`,
  `start_run()`. This is the source of truth; UI only reflects it.
- **`deck.gd`** — builds the deck from §6 tables, shuffles, draws. A card is a small
  Dictionary or a custom `Resource`: `{kind: "treasure"|"hazard"|"special", value,
  hazard_type, special_id}`.
- **`relics.gd`** (or part of game.gd) — relic definitions + effects from §5.
- Keep all state in `game.gd`; have the UI subscribe via signals
  (`treasure_gained`, `hazard_seen`, `busted`, `banked`, `danger_changed`) so the
  juice is just signal handlers.

### Deterministic-enough randomness

Use Godot's RNG. For reproducible playtests/bug reports, expose a seed field (a
`RandomNumberGenerator` with a settable `seed`). Reshuffle per expedition.

### MCP test loop

Use the `godot-mcp-headless` skill in `.claude/skills/`. Verify the full flow headless:
`run_scene` → `send_input`/click PUSH a few times → `take_screenshot` → confirm
unbanked rises and danger % climbs → force a bust (push until second hazard) →
confirm unbanked zeroes → `get_errors` should be clean → `stop_scene`.

---

## 9. MVP scope (build this first — small and complete)

Ship a *fun, complete loop* before adding any depth. The MVP is "done" when a player
can feel the bank-or-push tension and lose/win a run.

**In scope:**
1. One depth deck (§6 tables), shuffle + draw.
2. The full PUSH / BANK / bust state machine (§3, §4).
3. UI: room track, unbanked, vault, **live danger %**, seen-hazards row, the two buttons.
4. Bust sequence (collapse + zero unbanked) and bank sequence (cash in + exit).
5. **One** working relic — 🔦 **Lantern** (peek top card) — to prove the mitigation
   hook end to end.
6. Run = 3 expeditions; show final vault score + a restart button.
7. Minimum juice: coin sound on treasure, sting + screen shake on bust, cha-ching on bank.

**Explicitly OUT of MVP (stretch goals, §10):** meta-shop, the other 3 relics,
multi-crew, art polish, settings, save files.

**Definition of done:** a fresh player can complete a 3-expedition run, the danger %
visibly drives their decisions, a bust feels bad (in a good way), banking feels great,
and `get_errors` is clean in a headless MCP run.

---

## 10. Stretch goals (after MVP feels good)

In rough priority order:

1. **The other 3 relics** (Antidote, Rope, Charm) + a pre-run loadout screen.
2. **Meta-shop between expeditions** — spend vault on deck manipulation: remove a
   hazard type, salt in extra treasure, buy relic charges. This is the long-game
   mastery curve.
3. **More hazard flavor** — hazard-specific events instead of pure bust (e.g. flood
   makes the next 2 rooms pay double but doubles their danger).
4. **Multi-crew "split your bets"** — commit multiple explorers; send some back to
   bank early while others push deeper. Reintroduces the multiplayer-style tension
   solo.
5. **Endless / daily-seed mode** with a high-score table.
6. **Art & theme pass** — currently icons + numbers; could become a real ruin crawl.

---

## 11. Open tuning questions (decide by playtest)

- Is 5 hazard types × 3 the right tension, or 5 × 2 for a punchier deck?
- Is the gold-curve multiplier (0.18) making the deep dive tempting enough?
- Should DANGER % factor in that remaining treasure cards can't bust (more accurate),
  or stay as the simple `seen/remaining` (more legible)? Start simple.
- 3 expeditions per run, or endless-only? Start with 3 for a clear arc.

---

*Design owner's note for the build agent: the rules in §3–4 and the design pillars in
§2 are the load-bearing parts — keep them intact. Everything in §6 is dials to turn.
Build the §9 MVP, get it fun, then climb §10.*
