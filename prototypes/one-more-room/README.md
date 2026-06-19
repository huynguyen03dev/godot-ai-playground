# 🏚️ One More Room

A push-your-luck dungeon-crawler card game prototype. Delve into three
expeditions, push deeper for bigger gold, and bank before a duplicate
hazard busts you.

> Prototype built with the [Godot MCP](https://github.com/) workflow.
> See `DESIGN.md` for the full design, `PLAN.md` for the build plan, and
> `FUN_REPORT.md` for the playtest verdict.

---

## 🎮 How to Play

### Goal
Survive **3 expeditions** and end with as much gold in your **vault** as possible.

### Each turn
- **PUSH (one more room)** — draw the next room card:
  - 💰 **Treasure** → adds gold to your *unbanked* pile (deeper rooms pay more)
  - ⚠️ **Hazard** (gas, cave-in, spiders, flood, curse) → first sighting is free;
    a **second sighting of the same type BUSTS** you (lose all unbanked gold!)
  - ✨ **Special** → bonus event
- **BANK** — lock your unbanked gold into the vault and start the next expedition.
  Banked gold is safe — a bust can never touch it.

### Read the risk
- **DANGER (next flip)** rises as you see more hazard types. When it climbs
  past 25% it turns yellow, past 50% red.
- The deeper you go, the more gold per room — but the more likely a bust.

### Relic: 🔦 Lantern (once per expedition)
Peek at the next card before deciding to push or bank. Use it when the
danger is high and you need to know.

---

## ⌨️ Controls

| Action | Key |
|--------|-----|
| Push (one more room) | **P** |
| Bank | **B** |
| Lantern (peek) | **L** |

> The on-screen **PUSH** / **BANK** / **Lantern** buttons are also clickable
> with the mouse.

---

## ▶️ Run It

### From a release binary (Linux)
1. Download `one-more-room-linux-x86_64` from the [GitHub Releases](../../releases)
2. Make it executable: `chmod +x one-more-room-linux-x86_64`
3. Run: `./one-more-room-linux-x86_64`

### From source (Godot 4.6+)
1. Open this project's parent (`godot-ai-playground`) in the Godot editor
2. The main scene is `res://prototypes/one-more-room/one_more_room.tscn`
3. Press **F5** (Play) or **F6** (Play Scene)

---

## 🎯 Design Pillars

1. **Tension > complexity** — one meaningful decision per turn
2. **Honest risk** — the danger number reflects real odds
3. ** readable at a glance** — vault / unbanked / danger always visible
4. **Loss is fair** — busts hurt but banked gold is sacred

---

## 📐 Numbers (MVP tuning)

- **Deck:** 18 treasure + 15 hazard (5 types × 3) + 2 special = 35 cards
- **Gold curve:** `10 × (1 + 0.18 × depth)` per treasure, ±15% jitter
- **Danger:** `distinct hazards seen ÷ cards remaining`
- **Run:** 3 expeditions

See `DESIGN.md` §6 for the full tables and §11 for tuning notes.
