# BLACKOUT — Design Document

> **Logline:** The power is dead and the magnetic front door won't release.
> Three fuses are scattered through the rooms of an abandoned building.
> Find them, slot them in the breaker box, get out. You are not alone —
> and the thing in here hunts by **light**.

**Genre:** First-person stealth-survival horror
**Tone:** Visceral / disturbing (implied dread + committed visual horror)
**Length:** ~10–12 minutes, single floor, complete arc
**Engine:** Godot 4.6 (3D)

---

## 1. The Spine — light as polarity

Every great horror game has one mechanic with a **polarity**: a single action
that is simultaneously your greatest tool and your greatest danger.

> **Your flashlight lets you see. It also calls to Him.**

| Flashlight | You can… | But… |
|------------|----------|------|
| **ON** | See the room, find fuses, read notes | His detection range ×3; he drifts toward your position |
| **OFF** | Sneak past him, hide, break line of sight | Nearly blind — only ambient fog-glow, you stumble |

Every second is a decision: *do I want to see, or do I want to live?*
Sprinting adds **noise** that also draws him, flashlight or not. So the
player carries two dials — **light** and **noise** — and must keep at least
one low to survive. This is the whole game.

---

## 2. Core loop

```
EXPLORE (light off, slow, listening) → FIND a fuse (light on briefly)
  → He notices → HIDE or FLEE (light off, break LOS)
    → Lose him → repeat for 3 fuses
      → SLOT fuses at breaker → door unlocks → final gauntlet → ESCAPE
```

---

## 3. Player mechanics

- **Move:** WASD walk (4.0), **Shift** sprint (6.5) — sprint drains **stamina** and generates noise.
- **Look:** mouse-look, captured pointer. (`ui_cancel` frees mouse.)
- **Flashlight:** **F** toggles the headlamp. Warm cone, limited range, hard edge.
- **Interact:** **E** when a prompt is in range — pick up fuse, insert fuse, read note, open door.
- **Crouch:** **Ctrl** — slower, quieter, can fit behind cover / under things. Required for hiding.
- **Stamina:** sprint bar (~4s sprint, regen when walking). Running out mid-chase = panic.
- **No weapons. No fighting.** You avoid, you hide, you run.

### Inputs (to register)
`move_*`, `sprint`, `flashlight`, `interact`, `crouch` (existing: `move_*`, `sprint`, `flashlight`).

---

## 4. The Monster — "Him"

### Visual design
Built from primitives, deliberately **under-seen**:
- **~2.4m tall**, emaciated, limbs slightly too long, posture hunched-forward.
- **Wet-pale skin material** — subsurface pinkish-grey, high specular wetness, catches light wrong.
- **Head:** mostly shadowed; one faint glint where an eye should be. No clear face. The imagination fills worse.
- **Movement:** lurching, uneven cadence — one foot drags. Audio does more than the model.

### Behavior — state machine (reuses existing `monster.gd`)

| State | Trigger | Behavior |
|-------|---------|----------|
| **DORMANT** | Start of game, until Fuse 2 | Off-stage. Building is just creepy. |
| **PATROL** | After first sighting | Walks slow waypoints between rooms. |
| **INVESTIGATE** | Hears noise / sees light flash | Moves to last-suspected position. |
| **HUNT** | Has line-of-sight to player (and light/noise warrants it) | Sprints at player. |
| **SEARCH** | Lost sight of player | Goes to last-seen, looks around ~6s, then PATROL. |
| **ATTACK** | Touches player | Triggers **death sequence**. |

### Detection model (the rewire)
```
threat = 0
if player.flashlight_on: threat += detection_range_flashlight  (≈14m, LOS required)
if player.sprinting:     threat += detection_range_noise        (≈8m, through walls, muffled)
if player.crouched:      threat × 0.4
if player in HIDE_VOLUME (closet/behind cover) and still and dark: threat = 0

if threat > 0 and has_LOS → HUNT (sprint)
elif threat > 0           → INVESTIGATE (walk to position)
else                      → PATROL / SEARCH
```
This is the heart of the game feel. LOS uses a RayCast3D from his eyes to
the player, blocked by walls. Noise is range-only (he "hears" through walls
but muffled — represented by the smaller range).

### The tell (fair warning before he appears)
1. Lights in the area **flicker hard** (scripted via existing `flicker_light.gd`).
2. Ambient drone **drops to silence** (the dread gap).
3. Then his footsteps. Then him.
Predictable enough to be fair, unpredictable enough to scare.

---

## 5. Level structure — one floor, three acts

**Roughly 6–8 rooms + connecting corridors**, built from the kenney modular
set (corridors, rooms, gates, doors) + domestic furniture. Single floor.
Central **lobby hub** with the locked front door + breaker box.

| # | Space | Purpose | Threat |
|---|-------|---------|--------|
| **Hub** | Lobby — front door (locked), breaker box, reception desk | Anchor / objective beacon | None (safe room) |
| 1 | **Reception office** | Fuse 1 + intro note. Easy. Teaches pickup. | None |
| 2 | **Corridor stretch** | Transition, first atmosphere | Ambient dread |
| 3 | **Break room** | Fuse 2. On pickup → **first sighting** (he crosses far end, doesn't engage). | Revealed |
| 4 | **The Wrong Room** | Visceral set-piece (see §8). No fuse — story. | Peak ambient |
| 5 | **Storage / basement stairs** | Fuse 3, deepest. Pickup → **full HUNT begins**. | High |
| 6 | **Closet + side rooms** | Hiding spots, notes, a spare battery | — |
| **Exit** | Back to lobby, slot fuses, door opens, **berserk gauntlet**, escape | Resolution | Peak |

### Tension curve
```
lo ─────╮              ╭──╮              ╭──── HIGH (gauntlet)
        ╰──Fuse1────Fuse2──╯  explore    ╰──Fuse3──breaker──door
                                         (search/hide cycles between)
```
Deliberate **tension/release**. The quiet moments between fuses matter — they
reset the player's nerves so the next spike hits harder.

---

## 6. Art direction — visceral

**Palette:** desaturated, sickly green-grey base (already in
`world_environment_setup.gd`); accents of **sick amber** (flashlight, old
bulbs) and **deep arterial red** (blood, the death screen).

**Materials to author:**
- **Walls/floor:** stained, slightly wet specular, grime in corners.
- **Blood:** decals — pools, drag-trails, handprints on walls. Procedural noise textures. Wet specular.
- **The Wrong Room:** a space clearly aftermath of something — overturned furniture, a chair facing the corner, smears. Disturbing via arrangement, not gore dumps.

**Lighting design (per room):** each room has **one motivated light source**
(a bare bulb, a cracked window glow, the player's flashlight). Mostly dark.
Flicker lights at threshold moments. Color: cold blue ambient + sick amber
practicals. No flat fills.

**The monster** (see §4) — revealed in **strobe glimpses**, never held in
clear frame. Your own flashlight catching him mid-room is the worst image
in the game.

---

## 7. Audio direction — the soul of the horror

Horror is 70% sound. Three layers, always running:

### A. Ambient bed (continuous)
- **Low drone** (~40–60Hz), loops forever, barely conscious. Rises a tone in act 2.
- **Room tone** per area (different airy character: tiled bathroom echo, carpeted office hush, basement hum).
- Distant **house creaks / drips** randomized every 8–20s.

### B. Threat stack (scales with proximity — the fear meter)
Layered in as he nears (driven by the same `threat` value as the shader):
1. **Heartbeat** (~50→90bpm) — kicks in at medium range.
2. **Wet breathing** — his, close.
3. **Footsteps** — his, wet/dragging, positional (use AudioStreamPlayer3D).
4. **High tonal whine** — at point-blank, the "he's right there" sting.

### C. One-shot SFX
- Player footsteps (walk/sprint, surface-aware if feasible).
- Fuse pickup (metal click + hum), fuse insert (heavy clack + power-up whine).
- Flashlight click, door handle, note paper rustle.
- **Death sting** — a wet, truncated crunch + hiss, hard cut.
- **Win sound** — door release clunk + outside ambience bleed (rain/street).

> **Test target:** play with the monitor off. It should be scary by sound alone.

---

## 8. Scripted Scares — the paranoia engine

Horror lives in the **quiet moments between the monster**. Scripted scares
are the second threat layer: they make the *building itself* feel hostile,
so the player is never safe even when He is nowhere near. A head at a
window when you've let your guard down is often scarier than the chase.

### Design principles (do not violate)

1. **Scarcity is the rule.** A scare every 10 seconds is comedy. Minimum
   **45s global cooldown** between any two scripted scares. The first scare
   is delayed ~90s — earn the silence first.
2. **Most scares are fake.** ~60% are NOT the monster — a coat on a chair, a
   reflection, a shadow. These train paranoia so the real reveals land
   harder. The player must never be sure what's a threat.
3. **Never punish a scare (except once).** Scripted scares do not kill.
   Death comes only from the real monster. The single exception is the Twist
   (§8.7) — that's the one moment we lie to the player.
4. **One-shot by default.** A scare that repeats loses its weight. Most fire
   once, ever. A few repeat with heavy randomness and long cooldowns.
5. **Audio is 80% of the scare.** Every scare has a dedicated sting — a
   fingernail on glass, a breath, a knock. The visual is the punctuation on
   the sound, not the other way around.

### The scare system (data-driven, no per-scare code)

A `ScareEvent` node placed in the editor like a pickup. Configured in the
inspector, fired by the engine. No new script per scare. A global
`ScareDirector` autoload enforces cooldown, scarcity, and ordering.

| Field | Values |
|-------|--------|
| `trigger` | `ZONE_ENTER` · `ZONE_LOITER` (stand Xs in zone) · `GAZE_HOLD` (look at target Ys) · `INTERACT` · `ON_MONSTER_STATE` |
| `reveal` | `SHOW_NODE` (unhide a model for duration) · `PLAY_SOUND` · `STROBE_LIGHTS` · `SPAWN_DECAL` · `MOVE_PROP` · `MIRROR_DUP` |
| `duration` | reveal length (0.3–1.2s typical — shorter is scarier) |
| `one_shot` | bool (default true) |
| `sound` | AudioStream — the sting |
| `requires` | optional game-state gate (e.g. "after fuse 2") |

### The scare library — 8 specific beats for BLACKOUT

Distributed across the level (mapped to §5 rooms), ordered by intended
first encounter:

**1. The Lobby Window** *(Act 1, fakeout, ZONE_LOITER 4s)*
Stand at the reception desk too long → a pale face presses against the
frosted front window for 0.8s, breath fogging the glass, then gone. It is
**not** Him. *Trains: windows are watched. First scare of the game.*

**2. The Bathroom Mirror** *(Act 2, fakeout, GAZE_HOLD 2s)*
Look in the mirror → your reflection. Look away, look back → a second
figure behind your shoulder for 0.5s → gone. Always empty on the third
look. *Pure unease; classic for a reason.*

**3. The Hallway Window** *(Act 2, real-feeling reveal, ZONE_ENTER on
backtrack)*
Long corridor with a window to outside. Walk past the first time →
nothing. Backtrack past it → a head is at the window, tracking your
movement, gone the instant you face it directly. One-shot. *Rewards
exploration with dread.*

**4. The Closet Drop** *(Act 2, visceral, INTERACT)*
Open a closet to hide → a slumped body tumbles out. One-shot. *Teaches:
opening things is risky. Sets up the hide mechanic with consequence.*

**5. The Corner Chair** *(Act 2, ambient, GAZE_HOLD 3s, repeating)*
In the Wrong Room. Stare at the chair facing the corner >3s → on
look-away-look-back, it has turned slightly more toward you. Never a
person. *Lingering wrongness with no release.*

**6. The Strobed Silhouette** *(Act 2→3 bridge, real, ON_MONSTER_STATE)*
Approaching the Fuse 3 area → lights strobe → for one flash He stands at
the far end of the corridor → next flash, empty → then the real hunt
begins. *Bridges scripted scare into live gameplay seamlessly.*

**7. THE TWIST — The Interior Window** *(Act 3, REAL THREAT, ZONE_LOITER)*
Back in a familiar room after Fuse 3. A window scare fires (head at
window) — but this is an **interior** window, and it is Him, and He is
**inside the room with you**. He drops from the frame and becomes a live
hunt. *Subverts the "scares don't hurt you" rule we trained for 8 minutes.
The cruelest, most effective beat in the game.*

**8. The Final Door** *(Exit, ambiguous, ZONE_ENTER)*
Reaching the exit handle → His face fills the door's window for one frame
→ the door opens, He is gone. Step out into cold rain. *Did he let you
go? Ends on a question, not a victory.*

### Scare audio stings (authored in Phase 5)

| Scare | Sting |
|-------|-------|
| Lobby window | breath-on-glass + faint fingernail tap |
| Mirror | wet inhale, panned just behind the ear |
| Hallway window | low double-knock on glass |
| Closet drop | body thud + fabric rustle |
| Corner chair | nothing — silence is the sting |
| Strobed silhouette | the drone-drops-to-silence tell (§4) |
| **Twist** | His **only** vocalization — layered, wrong, too human |
| Final door | door-handle click + one wet exhale |

### Scarcity budget (enforced by ScareDirector)

- ~8 scripted scares total across a 10–12 min run (≈ one per 80–90s avg).
- Global cooldown: **min 45s** between any two scares.
- Max 2 scares per room-visit.
- First scare (Lobby Window) cannot fire before t=90s.
- The Twist has **no cooldown rule** — it breaks the pattern intentionally.

---

## 9. Visceral moments (the committed-disturbing beats)

The tone is visceral — these are the moments that earn it, used **sparingly**
so they keep their weight:

1. **The Wrong Room** (Fuse 2→3 transition). A room with no fuse. Door ajar. Inside: overturned chair, long drag-mark leading to a corner, a pile of clothes, **handprints on the inside of the window**. A single bare bulb. He is never in here. It's worse that he isn't.
2. **The first sighting.** Picking up Fuse 2 → lights strobe → across the far corridor, lit for 0.4s, **He walks past**. Doesn't look at you. Vanishes. The drone cuts to silence for 3 full seconds.
3. **Flashlight catch.** Mid-game, you round a corner with the light on — He is **right there**, 2m away, frozen. One frame of his face in the cone. He lunges. (If you have stamina and react, you escape; if not, you die.)
4. **The death sequence.** First-person: his hand enters frame from above, camera wrenches to the floor, a wet crunch + your character's cut-off breath, **hard cut to black**. Beat. Then white text: *"He found you."* → `[R] Retry`.
5. **The berserk gauntlet.** Slotting the 3rd fuse → every light strobes red, he screams (first and only vocalization — wrong, layered), sprints from the deep room. You run for the lobby door. The longest 12 seconds of the game.
6. **The escape.** Door opens → cold blue exterior light spills in → you step out → cut to title with a quiet rain bed. No score, no congratulations. Just out.

---

## 10. UI / Game flow

- **Title screen:** `BLACKOUT` — single key prompt. Black screen, one floor-creak. No menu chrome.
- **Intro card** (3s, fades): *"3 fuses. Breaker box. The door will open. Don't use the light unless you have to."*
- **HUD (diegetic-minimal):**
  - Bottom-left: `FUSES 0/3`.
  - Center-bottom (contextual): `[E] PICK UP FUSE` / `[E] INSERT FUSE` / `[E] READ`.
  - Bottom-right: stamina bar (only when draining).
  - **No minimap, no health bar, no objective log.** Scarcity of info is horror.
- **Subtitles** (toggle): for sound tells (*"...wet footsteps, close"*), accessibility.
- **Death:** the sequence (§9.4) → retry. No loading screen — instant.
- **Win:** the escape (§9.6) → title.
- **Pause (Esc):** Resume / Restart / Quit. Freezes time + audio.

---

## 11. Scope & build phases

Each phase is independently testable. Stop-and-test between each.

| Phase | Delivers | Test gate |
|-------|----------|-----------|
| **0. Lock + scaffold** | This doc, new `blackout.tscn`, input actions, MCP online | Scene boots |
| **1. Shell + objective loop** | Floor layout, 3 fuses, breaker, door, basic HUD, win-on-collect | Can walk the full loop and "win" with no threat |
| **2. Monster + stealth** | Light/noise detection, state machine, hide volumes, stamina, catch=death | He hunts, you can hide/lose him, he kills you |
| **3. Atmosphere + visceral dressing** | Per-room lighting, materials, blood decals, Wrong Room, monster model | Walking the level feels Dread |
| **4. Scripted scare system** | `ScareEvent` node + `ScareDirector`, all 8 scares placed, scarcity enforced, Twist transitions to live hunt | Scares fire on triggers; monitor-off test startles |
| **5. Audio layer** | Drone, room tone, threat stack, all SFX, positional footsteps, scare stings | Scary with monitor off |
| **6. Flow + UI polish** | Title, intro, death seq, win, pause, subtitles | Full end-to-end playthrough |
| **7. Juice + tuning** | Shader tune, screen shake, visceral death, speed/detection tuning, scare timing, level balance | 3 real playtests, adjusted to fair-but-terrifying |

---

## 12. Tuning targets (starting values, revise in Phase 7)

- Player walk 4.0, sprint 6.5, sprint duration 4.0s, regen 1.5s to full.
- Monster walk 2.0, run 5.2 (slower than player sprint — you *can* escape, barely).
- Detection: flashlight LOS 14m, noise 8m, crouch ×0.4.
- Lose-LOS grace: 1.2s (so flickering past a pillar doesn't drop him instantly).
- Search duration: 6s at last-seen before returning to patrol.
- Fuse 2 → first sighting at 1.5s after pickup. Fuse 3 → hunt begins at 1.0s.

---

## 13. What this is NOT (scope guard)

- Not multiple floors. Not multiple monster types. Not weapons. Not puzzles
  beyond "find + insert." Not a story with NPCs. Not procedural.
- **One floor. One monster. One objective. Done with craft.**
