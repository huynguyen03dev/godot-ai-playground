# 🔦 BLACKOUT

> *Three fuses. One way out. Something is awake in the dark.*

A first-person horror escape. The power is out. Find three fuses, slot them in
the breaker, and reach the front door — without waking what's listening. Your
flashlight is your only light, and its beacon. Sprint to escape, but it hears
you run. The whole game is the tension between **light vs. noise**.

Built in **Godot 4.6**, developed and verified headlessly with an AI agent
driving the editor via [godot-mcp](https://github.com/).

---

## 🎮 Play

Pre-built binaries are on the **[Releases](../../releases)** page — no Godot
install needed. Just download, unzip, and run:

| Build | File |
|-------|------|
| **Linux** (x86_64) | `Blackout-Linux-x86_64.zip` |
| **Windows** (x86_64) | `Blackout-Windows-x86_64.zip` |

> The builds have the game data embedded (single executable). Linux: make the
> file executable (`chmod +x Blackout.x86_64`). Windows: run `Blackout.exe`.

### Controls

| Action | Key |
|--------|-----|
| Move | `WASD` |
| Sprint | `Shift` (stamina-limited) |
| Crouch | `Ctrl` (silent) |
| Flashlight | `F` |
| Interact (pick up / insert) | `E` |
| Release mouse | `Esc` |
| Start / Restart | click or `F` |

### How to survive
- **Crouch + darkness = invisible.** That's your only safe state.
- **The flashlight sees far** — yours lights the way, but it's a beacon the
  monster can spot from across the room.
- **Sprinting is loud.** It hears you run. Walk or crouch when it's near.
- A wet breathing and heartbeat bed rises as it closes — listen for it.

---

## 🎯 Objective loop

1. Explore the dark rooms; find **3 glowing fuses**.
2. Bring them to the **breaker box** and slot them (`E`).
3. Power restores → the magnetic lock on the **front door** releases.
4. Reach the open door to escape.

The monster roams, then hunts when it sees your light or hears your noise.
Caught = death screen → retry.

---

## 🛠️ Build from source

Requires **Godot 4.6+** (stable) with export templates installed.

```bash
git clone <this-repo>
# Open in Godot editor → Project → Export, or headless:
bash prototypes/horror-house/export.sh   # builds Linux + Windows x86_64 into build/
```

---

## 🧱 Architecture

Everything lives in [`prototypes/horror-house/`](prototypes/horror-house/):

| File | Role |
|------|------|
| `game.gd` | Central state machine: fuses, power, door, win/death, flow input |
| `player.gd` | FPS controller: walk/sprint/crouch, stamina, flashlight, proximity interaction |
| `monster.gd` | Light + noise detection model, steering pursuit, catch = death |
| `breaker.gd` / `fuse_pickup.gd` / `exit_door.gd` | Interactables |
| `audio_manager.gd` | Autoload: ambient/threat beds, one-shot SFX, proximity ducking |
| `hud.gd` | Diegetic HUD + title/win/death overlays (reactive to game signals) |
| `world_environment_setup.gd` | Dark env, ACES tonemap, volumetric fog, SSAO |
| `horror_effect.gdshader` | Post-FX: vignette, grain, chromatic aberration (threat-scaled) |
| `test_loop.gd` | Headless self-test harness (drives the full loop, prints PASS/FAIL) |

Systems are **decoupled via signals** — the game broadcasts state; HUD, audio,
and the monster react without holding hard references.

---

## Credits & License

- **3D models** — [Kenney](https://kenney.nl) (dungeon kit) + [Quaternius](https://quaternius.com/)
  (zombie) — [CC0](https://creativecommons.org/publicdomain/zero/1.0/).
- **Sound** — [freesound.org](https://freesound.org) creators (CC0/CC-BY). Full
  attribution in [`prototypes/horror-house/ATTRIBUTION.md`](prototypes/horror-house/ATTRIBUTION.md).
- **Code** — MIT, see [LICENSE](LICENSE).

> This is a prototype / vertical slice. It's atmospheric and complete-loop, but
> short — built to be a downloadable taste of the mechanic.
