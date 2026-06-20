# BLACKOUT — Asset Manifest

Derived from `DESIGN.md`. Every asset the game needs, with specs.
This is the source of truth for sourcing. Tick `[x]` as acquired.

> **License rule:** prefer **CC0** (no attribution, no restrictions). Accept
> **CC-BY** (attribution required — logged in `ATTRIBUTION.md`). Never use
> non-commercial or no-derivs assets (we're shipping a release).

---

## A. 3D MODELS

### A1. THE MONSTER ("Him") — HIGHEST PRIORITY
The single hardest, most important asset. Design spec (§4):
- ~2.4m tall, emaciated, limbs slightly too long, hunched posture
- Wet-pale skin (pinkish-grey, subsurface, high specular wetness)
- Head mostly shadowed, one faint eye-glint, no clear face
- **Must be rigged + animatable** (walk-lurch, idle, lunge, attack)
- Format: `.glb` (Godot-native), with armature

**Options (pick one in sourcing):**
- (a) Free rigged creature model (Quaternius Ultimate Zombies, KayKit, Mixamo)
- (b) Build from primitives + custom skin shader (full art control, ~1 day)
- (c) Paid pack ($5–20)

### A2. Objective props — REQUIRED for core loop
- [ ] **Breaker/fuse box** — wall-mounted, opens to slot fuses. ~1m tall.
- [ ] **Fuse ×3** — pickup-able cylinders, ~15cm. Glowing filament inside (emissive).
- [ ] **Front door (magnetic, locked)** — heavy, with a window (for Final Door scare). Have `door-brown-window` — may reuse or upgrade.

### A3. Scare-specific props — REQUIRED for scripted scares
- [ ] **Closet/wardrobe** — openable, hideable, for Closet Drop scare + hiding. Tall, ~2m.
- [ ] **Body / slumped figure** — for Closet Drop. Can be low-detail.
- [ ] **Chair** — simple wooden chair, for Corner Chair scare (we have no chair).
- [ ] **Bare bulb / ceiling light fixture** — for flicker lights (we have the flicker script, no fixture model).

### A4. Dressing props — for atmosphere & The Wrong Room
- [ ] **Note/paper** — pickup-able, readable. Simple plane.
- [ ] **Reception desk** — have `desk.glb`, may suffice. Verify.
- [ ] **Shelves/storage** — for basement storage room.
- [ ] **Cardboard boxes / crates** — cover for hiding, basement clutter.

### A5. Architecture (mostly HAVE — verify coverage)
- ✅ Corridors (straight, corner, end, intersection, junction, wide variants)
- ✅ Rooms (small, large, wide, corner + variations)
- ✅ Gates & doors (incl. door-with-window)
- ✅ Stairs, walls, floors, templates
- [ ] Verify window frames with glass (for window scares) — have `window-brown-tall`, may need interior window variant

---

## B. TEXTURES / DECALS / MATERIALS

### B1. Blood (visceral tone — §6)
- [ ] Blood pool (floor decal) — dark, wet, specular. ~512×512 + alpha.
- [ ] Blood smear / drag-mark (floor decal) — long streak.
- [ ] Handprints (wall decal) — esp. "inside of window" variant.
- [ ] Blood splatter (wall decal) — small, varied.

### B2. Surface materials
- [ ] Stained concrete floor (wet specular variant)
- [ ] Grime/wall stain overlay
- [ ] Rust (for gates, breaker box)
- [ ] Wet-pale skin material (for monster) — likely a shader, not a texture

### B3. Optional but high-impact
- [ ] Tile pattern (bathroom)
- [ ] Wood floor (reception office)
- [ ] Wallpaper (residential rooms)
- [ ] Mold/water damage (corners)

---

## C. AUDIO — the soul of horror (§7) — 70% of the fear

> Format: `.wav` (16/24-bit) for SFX, `.ogg` for music/loops.
> Godot imports both. Prefer `.wav` for one-shots (no decode latency on scares).

### C1. Ambient bed (continuous, looped)
- [ ] **Low drone** — 40–60Hz, seamless loop, ~30s. The floor of everything.
- [ ] **Drone variant (raised)** — act 2, +1 tone tension.
- [ ] **Room tone — tile** (bathroom echo, ~10s loop)
- [ ] **Room tone — carpet** (office hush, ~10s loop)
- [ ] **Room tone — basement** (low hum + reverb, ~10s loop)
- [ ] **House creaks pack** — 8–12 short creak/drip/drip sounds, randomized

### C2. Threat stack (scales with proximity — the fear meter)
- [ ] **Heartbeat** — single beat (layered for tempo 50→90bpm), or pre-rendered at 60/75/90.
- [ ] **Wet breathing (his)** — looped exhale-inhale, ~3s.
- [ ] **Footsteps (his)** — wet/dragging, single-step (sequenced at runtime), positional.
- [ ] **Tonal whine** — high sustained sting for point-blank dread.

### C3. Player SFX
- [ ] **Player footsteps — walk** (surface-agnostic OK for MVP, ideally tile/carpet/wood sets)
- [ ] **Player footsteps — sprint** (faster, heavier)
- [ ] **Player panting** — stamina-drain breath loop.
- [ ] **Flashlight click** — on + off (or one reversible).
- [ ] **Door handle / open**
- [ ] **Note rustle** — paper pickup/read.
- [ ] **Crouch** — fabric rustle, subtle.

### C4. Interaction one-shots
- [ ] **Fuse pickup** — metal click + faint hum.
- [ ] **Fuse insert** — heavy clack + power-up whine.
- [ ] **Breaker engage** — big mechanical clunk + electrical whine (3rd fuse).
- [ ] **Door unlock** — magnetic release clunk.

### C5. Death & win
- [ ] **Death sting** — wet crunch + cut-off breath, hard end. ~0.8s.
- [ ] **His vocalization (THE TWIST + berserk)** — his ONLY voice. Layered, wrong, too-human. ~2s.
- [ ] **Win / escape** — door release + cold rain/street ambience bleed.

### C6. Scare stings (8 — mapped to §8 scares)
- [ ] **Lobby window** — breath-on-glass + faint fingernail tap.
- [ ] **Mirror** — wet inhale, panned just behind ear.
- [ ] **Hallway window** — low double-knock on glass.
- [ ] **Closet drop** — body thud + fabric rustle.
- [ ] **Corner chair** — *(silence — no asset, system only)*.
- [ ] **Strobed silhouette** — *(drone-drop-to-silence — uses C1 system)*.
- [ ] **Twist vocalization** — *(uses C5 His vocalization)*.
- [ ] **Final door** — door-handle click + one wet exhale.

### C7. Music (minimal — horror often musicless)
- [ ] **Title bed** — sparse drone, ~20s loop.
- [ ] *(Optional)* one dissonant string pad for the berserk gauntlet.

**Audio total: ~30 files.** This is the bulk of the asset work.

---

## D. FONTS — HAVE ✅
- ✅ Cinzel (serif — horror titles)
- ✅ Inter (body / HUD)
- [ ] *(Optional)* a distressed/horror display font for title only (e.g. from Google Fonts).

---

## E. SHADERS — to author (not download)
- [ ] Horror post-process (have `horror_effect.gdshader` — tune in Phase 7)
- [ ] Wet-pale skin (monster) — subsurface approx + fresnel rim
- [ ] Fog/volumetric tweak (have via WorldEnvironment)

---

## Sourcing priority order

1. **Audio C1–C6** (highest impact, most files) — Freesound.org CC0, Pixabay
2. **Monster A1** — decision needed (free model vs build vs paid)
3. **A2 objective props** (breaker, fuses) — likely build from primitives
4. **A3 scare props** (closet, body, chair, bulb)
5. **B1 blood decals** — ambientCG / generate
6. **A4 + B2 dressing** — Kenney (have most) + fill gaps
7. **C7 music** — last, optional

---

## Open sourcing questions (need answers)

1. **Visual style direction** — low-poly stylized (matches Kenney, consistent, achievable) vs realistic (clashes with Kenney, harder sourcing). Affects everything.
2. **Monster approach** — free rigged model / build from primitives / paid pack.
3. **Budget** — free-only vs willing to spend $5–20 on a key pack (audio bundle or monster).
