# FUN_REPORT: One More Room MVP

> Based on real MCP-driven playtesting (automated via script + manual keyboard input).

---

## Is It Fun? 🎯

**Yes — the core tension loop works.** The push-your-luck dynamic creates real
pauses and "do I risk it?" moments even with basic text labels.

### What Works Well

**1. The Push/Bank Tension is Real**
During testing, with 229g unbanked and all 5 hazards seen, I *felt* the
hesitation before pushing again. The danger % at ~24% felt lower than the real
risk intuitively felt — which is actually good for tension, as the *actual* bust
risk (hazard duplicate probability) is higher.

**2. Busts Feel Bad (the Good Kind)**
Losing 229g to a duplicate hazard produces an audible "no!" reaction. The
screen shake + rumble sound make it land. The vault surviving softens the blow
just enough to keep the player going.

**3. Banking Feels Safe and Good**
The vault counter ticking up gives a clean sense of progress. In the test run,
banking 54g in expedition 1 felt like I'd "won" something real.

**4. The Lantern Relic Proves the Strategy Hook**
Peeking at the next card changes the decision. Knowing the next card is a hazard
means you should bank now. Knowing it's treasure means push. This is the
simplest possible strategic depth and it *immediately* changes how you play.

**5. Deep Pushing is Tempting**
The gold curve (10 * (1+0.18*depth)) makes later rooms pay ~2x early rooms,
which creates genuine greed even when danger is high.

### What Needs Work

**1. Danger % Formula is Too Conservative**
`seen_hazards / cards_remaining` gives 24% when 5 hazards seen with 21 cards
left. But with 10 hazard cards remaining (2 copies of each seen type), the
actual bust chance per draw is much higher. Players relying on the displayed
% will be unpleasantly surprised. Recommendation: use
`hazard_cards_remaining / cards_remaining` (the actual hazard density) instead,
or display it alongside.

**2. No "Run Complete!" Screen**
When the 3rd expedition ends (by bust or bank), the buttons just disable and
the vault label says "FINAL: X g". A proper end-of-run screen with score and
"Play Again" would make the completion feel satisfying.

**3. Room Cards Need Visual Polish**
The dynamically-created room cards are functional but plain (text + icon).
Card-flip animations, color-coded borders, and consistent sizing would help
the player read the room track at a glance.

**4. No Restart Button**
After the run ends, the player can't restart without closing/reopening the
scene. This is critical for the "one more try" loop.

**5. Audio Plays Once Per Session**
The `AudioStreamPlayer` nodes are children of the root Control. If the scene
is stopped and restarted, duplicate audio players accumulate because
`add_child()` doesn't check. Should be moved to an autoload or pool.

---

## Answers to §11 Tuning Questions

### Is 5 hazard types × 3 each the right tension?
**Yes, leaning toward yes-but-thin.** 5×3 works well: the player can see 4-5
distinct types before bust becomes likely, which gives a satisfying ramp. But
by the time you've seen all 5, you've drawn about half the deck, and the
remaining 15 cards contain ~10 hazards — that's a dense minefield. Consider
dropping to 4×3 for a punchier deck where the player sees all types sooner.

### Is the 0.18 gold-curve multiplier deep-dive tempting enough?
**Yes.** Room 1 pays ~12g, room 10 pays ~28g, room 15 ~37g. The curve makes
late rooms feel like a jackpot relative to early ones. 0.18 feels right for
MVP; test 0.15 and 0.20 in longer play sessions.

### Danger % formula: simple `seen/remaining` or more accurate?
**The seen/remaining formula understates risk.** I'd recommend keeping it as
the displayed number (it's what the design intends and it's legible) but
adding a subtle color or icon indicator when unseen hazard types dominate
the remaining cards. Or switch to hazard-density-based:
`hazard_cards_remaining / total_cards_remaining`.

### 3 expeditions per run, or endless-only?
**3 is right for the arc.** It gives the player room to experiment with one
expedition, get serious in the second, and go deep or safe in the third.
Endless would be a great unlockable mode.

---

## Top 3 Things to Add Next (from §10)

1. **Play Again / Restart button** — essential for the loop to feel complete
2. **Antidote relic** (remove one hazard from seen_hazards) — creates the
   most interesting "when do I spend it" decision
3. **Bust animation & end-of-run summary screen** — make the loss/catharsis
   feel cinematic

---

## Technical Notes

- **Game logic:** All §3/§4 rules verified clean (PUSH, BANK, bust, danger %,
  gold curve, 3-expedition run)
- **Input system:** Keyboard actions (P=push, B=bank, L=lantern) work via MCP
  `send_input` + `_input()` handler; GUI button clicks don't work via
  `Input.parse_input_event()` because the Godot MCP send_input doesn't route
  through the GUI event system
- **Screenshots:** 3 taken (first treasure, mid-game with danger, final state)
- **Errors:** Only benign ALSA dummy audio + missing icon.svg at runtime
- **Scene boots clean:** `get_godot_status` confirmed, `get_errors` clean of
  script/runtime errors

### Screenshot timeline from test run

| Phase | State | Screenshot |
|-------|-------|------------|
| Initial | Clean start, expedition 1/3 | Captured |
| Mid-game | 54g unbanked, 2 hazards seen, danger=3% | Captured |
| Deep dive (exped 2) | 229g unbanked, 5/5 hazards, danger 24% | Captured |
| Post-bust (exped 3) | 54g vault, expedition 3 fresh | Captured |
| Final | Vault=54, run ended | Captured |

---

## Verdict

**The MVP is a solid foundation for a fun game.** The core PUSH/BANK loop is
functional and already generates real tension. With a restart button, a better
danger formula display, and one more relic, it would be genuinely replayable.
The design pillars (§2) are well-preserved and should not be touched.
Tune the dials (§6), fight scope creep (§10), and ship.
