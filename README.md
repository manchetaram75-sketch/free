# Two Keepers — Gardens of Cyrus

A local two-player cooperative puzzle platformer for Windows, made with **Godot 4.3**.
Two apprentice keepers restore the ruined garden canals of **Pasargadae**, the
palace-city begun under **Cyrus the Great**.

The design borrows the *appeal* of transformation-and-puzzle co-op — two players
who reshape themselves to solve rooms together — and builds it from original
mechanics, original art (all of it drawn in code), original level layouts and an
original setting. No code, assets, characters, levels or branding from any other
game are used or reproduced. See "History and originality" below.

---

## What the game is

Two players share one screen. Each controls one keeper. Both keepers can wear
either of two **Aspects**:

| | **Zam — Earth** | **Vayu — Air** |
|---|---|---|
| Body | 30 × 60 px, heavy | 18 × 38 px, light |
| Jump | single, 131 px | double + glide, 189 px |
| Speed | 205 px/s | 265 px/s |
| Owns | **root** (hold ACTION), **carry**, **shoulder launch** | **tether** to a ring or to the partner, **reel**, ride gusts |
| Fits | wide doorways | 44 px vents |

Two rules turn that into a conversation:

1. **Attunement** — you may only change Aspect while standing near your partner
   (the braid of light between you brightens). Splitting up has a cost.
2. **The shared reservoir** — every change is paid for out of one garden well.
   Refill by standing in a well; refill *three times faster* by standing in it
   together.

Every room is built from the consequences: a low tunnel only Vayu fits through,
a stone door only Zam's weight can hold open, a crosswind that can only be
plugged by the heavy keeper's body, a 300 px face that only a *launched*
partner can reach.

### Failure states

There is no health and no game over. A keeper who falls, drowns, or is swept
away is **spilled**: they reappear at the last lit waystone (checkpoint) after a
short grace period. The HUD counts spills, the flood garden pushes its water back
when you spill, and the results screen treats a clean run as a bonus rather than
the requirement. The two hard walls are geometry and the clock, never a
punishment screen.

---

## Controls

Three schemes, switchable at any time from the pause menu or the title screen
(no restart needed):

**Shared keyboard** (default)

| | Move | Jump | Add / act | Change shape | Restart |
|---|---|---|---|---|---|
| Keeper 1 | `A` `D` | `Space` or `W` | `S` | `F` | `R` |
| Keeper 2 | `←` `→` | `Z`, `↑` or Num `0` | `X` | `C` | `V` |

**Pause:** `Esc` / `P` · **Reset garden:** `Backspace`

**Two controllers:** left stick or d-pad to move, `A` jump, `X` act, `Y` change
shape, `Start` pause. Controller 1 drives keeper 1, controller 2 keeper 2.

**Auto** (the default): keyboard for both keepers, and the moment a pad is
touched it is handed to **keeper 2** first, then to keeper 1. Keyboard input
keeps working for whoever is still on the keyboard.

`ACTION` is both a tap and a hold, which is why it is a single button:

* **Zam** — *hold* to root yourself to the floor (rooting also makes you press
  harder on plates); *tap* beside your partner to lift them onto your shoulders;
  while carrying, **hold** to keep the grip and press **JUMP** to launch them.
* **Vayu** — *tap* to throw the tether (nearest ring, or your partner);
  *hold* to reel in; *tap* again to let go.

---

## Running it

1. Install **Godot 4.3** (standard build, not .NET).
2. Open the project folder (`project.godot`) — the editor will import it; there
   are no external assets, so import takes a second.
3. Press **F5**. The title screen appears; pick a garden.

The project renders with the GL Compatibility renderer, so it runs on integrated
graphics and older Windows machines. The window is 1280×720 and scales to any
window size or fullscreen resolution.

### Download the Windows build

Every push builds a playable Windows binary and publishes it:

**<https://github.com/manchetaram75-sketch/free/releases/tag/windows-build>**

Download `TwoKeepers-Windows.zip`, unzip it and run `TwoKeepers.exe`. Keep the
two `lib*.dll` files next to the .exe (they are the ANGLE libraries that give
the compatibility renderer a safe path on older Windows GPUs). The zip also
contains `HOW-TO-RUN.txt` with the controls.

The build is not code-signed, so the first run shows the Windows SmartScreen
prompt: *More info* → *Run anyway*.

### Exporting it yourself

The project ships with a committed export preset (`export_presets.cfg`,
"Windows Desktop", x86_64, game data embedded in the .exe), so this is all it
takes:

```bash
godot --headless --path . --import
godot --headless --path . --export-release "Windows Desktop" build/TwoKeepers.exe
```

Install the Godot 4.3 export templates first (`Editor → Manage Export
Templates`), or let CI do it — `.github/workflows/windows-build.yml` downloads
the engine and the templates, exports, zips `build/` and refreshes that release.
There is nothing to install and no plugins or native code, so the exported build
is self-contained.

Two cosmetic gaps remain: the .exe keeps Godot's icon and file properties,
because the preset deliberately exports with `application/modify_resources=false`
(that skips `rcedit`, which a Linux CI runner would otherwise need Wine to run).
Adding an `.ico` plus a rcedit step is the follow-up.

---

## Tests

Everything runs headless, so it works in CI and on a machine without a GPU.

```bash
# behavioural test suite (movement envelopes, size split, wind, carry, launch,
# attunement, reservoir, and every garden's build + spawn integrity)
godot --headless --path . res://tests/test_runner.tscn
# exit code 0 = all checks passed

# design-time geometry check: gaps, rises, spawns, gate travel, ASCII maps
python3 tools/level_check.py
python3 tools/level_check.py canal      # filter by level name

# smoke-run one garden for 240 frames (for CI logs / crash hunting)
godot --headless --path . res://src/main.tscn --quit-after 240 -- --level=1
```

The test suite asserts the *design claims*, not just the code: that a jump
cannot beat the envelope the level checker uses, that the tutorial tunnel really
is passable by Vayu and really is not passable by Zam, that a gust really does
lift the light keeper and not the heavy one, that a shoulder launch really does
out-reach a double jump, and that a keeper really cannot change shape when too
far from their partner. If a designer changes a number in
`src/core/config.gd`, both the game and the checks move together.

### Continuous integration

`.github/workflows/tests.yml` runs the same gates on every push, so a garden
can never land half-built:

1. **Import** - `godot --headless --path . --import` loads every resource.
2. **Compile** - `godot --headless --path . --editor --quit` parses and
   type-checks the whole project with the autoloads registered.
3. **Suite** - the behavioural checks above (`130 checks`), exit code 0.
4. **Design** - `python3 tools/level_check.py`: reachability, gaps, spawns and
   no blocking geometry.
5. **Smoke** - every garden boots for 240 frames with a clean log.

A failing smoke run prints a deduplicated summary of the errors together with
the engine's own `at: <call site>` line, so one annotation names the exact
engine call that misbehaved instead of a wall of repeated lines.

---

## Project structure

```
project.godot             Window, autoloads, input-map defaults (built in code)
src/
  main.gd                 Scene root: garden list, loading, HUD wiring
  main.tscn               The only scene file in the project
  core/
    config.gd             Every tunable number (physics, reservoir, wind, mercy)
    forms.gd              The two Aspects + the movement envelope formulas
    palette.gd            Colours and stone-drawing helpers
    tether.gd             Rope maths as pure functions (unit tested)
    keeper_world.gd       The world contract a keeper runs inside
    device.gd             Base class for level devices (ticked in a fixed order)
  actors/
    keeper.gd             Movement, aspects, carry, tether, wind, water, spills
  devices/
    well.gd               Garden well: refills the shared reservoir
    wind_channel.gd       Gust / current / pluggable vent
    pressure_plate.gd     Weight plates (rooting presses harder)
    gate.gd               Stone doors, drawbridges and lifts
    tether_ring.gd        Swing anchor
    waystone.gd           Checkpoint
    water_sheet.gd        The flood, drawn behind and in front of the keepers
  levels/
    level_base.gd         Building helpers, devices, checkpoints, goal, camera
    canal_gate.gd         Garden 1 - sizes, verbs, one-holds-for-the-other
    wind_walk.gd          Garden 2 - gusts, sealing, the shoulder launch
    twin_terraces.gd      Garden 3 - weight, root, hold-the-lift, launch
    flooded_court.gd      Garden 4 - rising water, currents, everything at once
  ui/
    hud.gd / hud_panel.gd Gameplay HUD, pause menu, results panel
    menu.gd               Title screen and garden select
    link_ribbon.gd        The attunement braid and the tether rope
    backdrop.gd           Procedural sky and ridges
    solid_art.gd / decor_art.gd / text_art.gd   Stone, columns, hint panels
tests/
  test_runner.gd/.tscn    Headless behavioural suite
tools/
  level_check.py          Design-time geometry checker + ASCII maps
```

### Adding a garden

1. Create `src/levels/my_garden.gd` extending `LevelBase` and implement
   `_build()` (and `_step(delta)` if it needs to change over time).
2. Build with the helpers: `add_ground`, `add_platform`, `add_solid`, `add_well`,
   `add_wind`, `add_plate`, `add_gate`, `add_ring`, `add_waystone`, `add_decor`,
   `add_text`, `add_heart`, and `spawn(a, b)`.
3. Add the script to `LEVELS` in `src/main.gd` and an entry to `LEVELS` in
   `src/autoload/game_state.gd`.
4. Run `python3 tools/level_check.py my_garden` and
   `godot --headless --path . res://tests/test_runner.tscn`.

Latch channels are just strings: a plate publishes `channel`, a gate listens to
it, and `_step()` can combine them (`set_latch("vent_sealed", plugged or other)`).

---

## Accessibility

Everything below is real, not aspirational, and lives in `src/autoload/settings.gd`:

* **Assist mode** — widens the attunement radius from 250 to 520 px (so distant
  partners can still transform) and slows environmental hazards to 45 %.
* **Screen shake** — a 0–1 slider; at 0 the camera never shakes, and the HUD
  still flashes, so no information is lost.
* **UI scale** — 80 %–160 % for all HUD text.
* **High contrast** — bright outlines on keepers, devices and rings.
* **No colour-only information** — keeper 1 always carries a square badge and
  keeper 2 a ring; devices change shape as well as colour; every state shown as
  an icon is also written in words on the HUD.
* **Forgiving failure** — no lives, generous coyote time (0.10 s) and jump
  buffering (0.12 s), checkpoint respawns, and a flood that gives ground back
  when you drown.
* **Several solutions per room** — the crosswind can be sealed *or* swung
  through; the weight plates accept a rooted keeper *or* both keepers; the
  terraces can be climbed by lift *or* by a launched partner.
* **Difficulty ceiling** — no timer on the goal (the HUD timer is for
  comparison only) and no penalty for taking your time, except in the flooded
  court where the water is the whole idea.
* **Pause menu** with in-game controls reference; assist mode is one toggle away.

---

## History and originality

**Setting.** The garden uses the world of Cyrus the Great and the Achaemenid
Persian empire: Pasargadae, garden canals (*pairidaēza*), garden wells, waystones
and wind channels, and a royal palette of lapis, turquoise, ochre, terracotta and
limestone. Names in the game are either the historical names of the places and
the dynasty (`Pasargadae`, `Achaemenid`, `Cyrus`) or invented for this game
(`Two Keepers`, `Zam`, `Vayu`, `waystone`, `garden heart`). The keepers are
fictional apprentices; nothing in the game claims to depict a real person's
words or deeds.

**What the game does not claim.** Everything here is stylised. The columns,
carved bands, lotus rosettes and winged motifs are *echoes* of Achaemenid
architectural vocabulary, drawn procedurally and reduced to flat shapes — they
are not reconstructions, and they are not copied from any photograph, scan,
inscription or museum asset. Where the historical record is uncertain (court
dress, the shape of garden hydraulics, the layout of the Pasargadae water
channels) the game invents a plausible-looking garden for play rather than
asserting a fact, and it does not stage or quote any historical event.

**What the game is not.** No code, art, audio, level layout, character, name or
branding from any other game has been used. The mechanics here (body-size
transformation, one shared transformation budget, attunement-gated shapeshifting,
body-plugging vents, shoulder launching, weight plates) are this project's own.

---

## Known limitations / next steps

* Audio is not implemented; the game is currently silent (a follow-up should add
  a simple procedural wood-and-water ambience).
* Local co-op only. There is no online play, and no plans for any: the design
  assumes two people in one room, talking.
* Pause-menu and results text is English-only.
* Drop-through for one-way platforms is not implemented (one-way platforms are
  not used by any shipping garden).
* Gamepad prompts are shown as names ("PAD 1"), not as button glyphs; a glyph
  set would need per-controller art.
