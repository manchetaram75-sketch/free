#!/usr/bin/env python3
"""Design-time checker for the Two Keepers gardens.

Reads the tuning table out of src/core/config.gd and src/core/forms.gd, reads
the geometry out of the level scripts, and then answers the questions a level
designer actually has:

  * can either keeper physically cross this gap, or is it a trap?
  * is this ledge inside a jump, or does it need a device?
  * does anybody spawn inside a wall or over a hole?
  * does a gate's travel path run through the goal or a spawn?

It also prints a coarse ASCII map per level, which is the fastest way to spot
a platform that ended up in the wrong place.

Usage:
    python3 tools/level_check.py            # check every level
    python3 tools/level_check.py canalgate  # check one (substring match)

Only files inside this repository are read; coordinates are evaluated with a
restricted evaluator (numbers and the level's own constants only).
"""

from __future__ import annotations

import math
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / "src" / "core" / "config.gd"
FORMS = ROOT / "src" / "core" / "forms.gd"
LEVELS_DIR = ROOT / "src" / "levels"

FAIL = "FAIL"
WARN = "WARN"
INFO = "INFO"


def parse_constants(path: Path) -> dict[str, float]:
    out: dict[str, float] = {}
    for match in re.finditer(r"^const\s+([A-Z0-9_]+)\s*:=\s*(-?[\d.]+)", path.read_text(), re.M):
        out[match.group(1)] = float(match.group(2))
    return out


def parse_stats(path: Path) -> dict[int, dict[str, float]]:
    text = path.read_text()
    block = text[text.index("const STATS") :]
    stats: dict[int, dict[str, float]] = {}
    for kind in (0, 1):
        start = block.index(f"\t{kind}: {{")
        end = block.index("\t},", start)
        chunk = block[start:end]
        entry: dict[str, float] = {}
        for match in re.finditer(r'"([a-z_]+)":\s*(-?[\d.]+)', chunk):
            entry[match.group(1)] = float(match.group(2))
        for match in re.finditer(r'"([a-z_]+)":\s*(true|false)', chunk):
            entry[match.group(1)] = 1.0 if match.group(2) == "true" else 0.0
        stats[kind] = entry
    return stats


class Envelope:
    """Mirrors Forms.max_rise / max_gap so the tool and the game agree."""

    def __init__(self, cfg: dict[str, float], stats: dict[int, dict[str, float]]):
        self.forms = {}
        for kind, s in stats.items():
            gravity = cfg["GRAVITY"] * s["gravity_scale"]
            rise = s["jump"] ** 2 / (2 * gravity)
            time = s["jump"] / gravity
            if s.get("double_jump", 0.0) > 0:
                power = s.get("double_jump_power", 0.0)
                rise += power**2 / (2 * gravity)
                time += power / gravity
            fall = cfg["GLIDE_FALL_SPEED"] if s.get("glide", 0.0) > 0 else cfg["MAX_FALL_SPEED"]
            time += rise / fall
            self.forms[kind] = {
                "name": "Zam" if kind == 0 else "Vayu",
                "rise": rise,
                "gap": s["speed"] * time * 0.85,
                "height": s["height"],
                "width": s["radius"] * 2.0,
            }

    def best_gap(self) -> float:
        return max(f["gap"] for f in self.forms.values())

    def best_rise(self) -> float:
        return max(f["rise"] for f in self.forms.values())

    def describe(self) -> str:
        lines = []
        for kind, f in sorted(self.forms.items()):
            lines.append(
                f"    {f['name']:<5} rise {f['rise']:6.1f}px   gap {f['gap']:6.1f}px   "
                f"body {f['width']:.0f}x{f['height']:.0f}"
            )
        return "\n".join(lines)


@dataclass
class Level:
    name: str
    constants: dict[str, float] = field(default_factory=dict)
    solids: list[tuple[float, float, float, float, str]] = field(default_factory=list)
    platforms: list[tuple[float, float, float, float, str]] = field(default_factory=list)
    gates: list[dict] = field(default_factory=list)
    plates: list[tuple[float, float, str]] = field(default_factory=list)
    winds: list[dict] = field(default_factory=list)
    rings: list[tuple[float, float]] = field(default_factory=list)
    waystones: list[tuple[float, float]] = field(default_factory=list)
    spawns: list[tuple[float, float]] = field(default_factory=list)
    goal: tuple[float, float, float, float] | None = None
    bounds: tuple[float, float, float, float] | None = None

    def rects(self) -> list[tuple[float, float, float, float, str]]:
        return self.solids + self.platforms


def _num(expr: str, env: dict[str, float]) -> float:
    safe = re.sub(r"[^0-9A-Za-z_+\-*/.()\s]", "", expr)
    for name in sorted(env, key=len, reverse=True):
        safe = re.sub(rf"\b{name}\b", repr(env[name]), safe)
    try:
        return float(eval(safe, {"__builtins__": {}}, {}))  # noqa: S307 - restricted
    except Exception as exc:  # pragma: no cover - authoring error
        raise SystemExit(f"cannot evaluate {expr!r}: {exc}") from exc


def parse_level(path: Path) -> Level:
    text = path.read_text()
    level = Level(name=path.stem)
    level.constants = {k: float(v) for k, v in re.findall(r"^const\s+([A-Z0-9_]+)\s*:=\s*(-?[\d.]+)", text, re.M)}
    env = dict(level.constants)
    env.update({"UP": 0.0, "DOWN": 0.0, "LEFT": 0.0, "RIGHT": 0.0, "PI": math.pi, "TAU": math.tau})

    def rect2(expr: str) -> tuple[float, float, float, float]:
        parts = [p.strip() for p in expr.split(",")]
        if len(parts) != 4:
            raise SystemExit(f"{path.name}: Rect2 needs four numbers, got {expr!r}")
        return tuple(_num(p, env) for p in parts)  # type: ignore[return-value]

    def vector2(expr: str) -> tuple[float, float]:
        parts = [p.strip() for p in expr.split(",")]
        if len(parts) != 2:
            raise SystemExit(f"{path.name}: Vector2 needs two numbers, got {expr!r}")
        return (_num(parts[0], env), _num(parts[1], env))

    def calls(name: str) -> list[str]:
        return re.findall(rf"{name}\(([^\n]*?)\)(?:\s*,|\s*$|\s*\))", text, re.M)

    for match in re.finditer(r"add_solid\(Rect2\(([^)]*)\)\s*,\s*\"(\w+)\"", text):
        x, y, w, h = rect2(match.group(1))
        level.solids.append((x, y, w, h, match.group(2)))
    for match in re.finditer(r"add_ground\(Rect2\(([^)]*)\)\)", text):
        x, y, w, h = rect2(match.group(1))
        level.solids.append((x, y, w, h, "ground"))
    for match in re.finditer(r"add_platform\(Vector2\(([^)]*)\)\s*,\s*Vector2\(([^)]*)\)(?:\s*,\s*\"(\w+)\")?\)", text):
        x, y = vector2(match.group(1))
        w, h = vector2(match.group(2))
        level.platforms.append((x, y, w, h, match.group(3) or "brick"))
    for match in re.finditer(r"add_gate\(Vector2\(([^)]*)\)\s*,\s*Vector2\(([^)]*)\)\s*,\s*\"(\w+)\"\s*,\s*Vector2\(([^)]*)\)", text):
        x, y = vector2(match.group(1))
        w, h = vector2(match.group(2))
        ox, oy = vector2(match.group(4))
        level.gates.append({"pos": (x, y), "size": (w, h), "channel": match.group(3), "offset": (ox, oy)})
    for match in re.finditer(r"add_plate\(Vector2\(([^)]*)\)\s*,\s*\"(\w+)\"", text):
        x, y = vector2(match.group(1))
        level.plates.append((x, y, match.group(2)))
    for match in re.finditer(r"add_wind\(Vector2\(([^)]*)\)\s*,\s*Rect2\(([^)]*)\)\s*,\s*Vector2\.(\w+)\s*,\s*(-?[\d.]+)", text):
        x, y = vector2(match.group(1))
        ax, ay, aw, ah = rect2(match.group(2))
        level.winds.append({"pos": (x, y), "area": (ax, ay, aw, ah), "dir": match.group(3), "strength": float(match.group(4))})
    for match in re.finditer(r"add_ring\(Vector2\(([^)]*)\)\)", text):
        level.rings.append(vector2(match.group(1)))
    for match in re.finditer(r"add_waystone\(Vector2\(([^)]*)\)", text):
        level.waystones.append(vector2(match.group(1)))
    match = re.search(r"spawn\(Vector2\(([^)]*)\)\s*,\s*Vector2\(([^)]*)\)\)", text)
    if match:
        level.spawns = [vector2(match.group(1)), vector2(match.group(2))]
    match = re.search(r"goal_rect\s*=\s*Rect2\(([^)]*)\)", text)
    if match:
        level.goal = rect2(match.group(1))
    match = re.search(r"bounds\s*=\s*Rect2\(([^)]*)\)", text)
    if match:
        level.bounds = rect2(match.group(1))
    return level


def surface_below(level: Level, x: float, y: float, limit: float = 400.0) -> float | None:
    """Topmost surface strictly below (x, y) within limit pixels."""
    best = None
    for sx, sy, sw, sh, _style in level.rects():
        if sx <= x <= sx + sw and y <= sy <= y + limit:
            best = sy if best is None else min(best, sy)
    for gate in level.gates:
        gx, gy = gate["pos"]
        gw, gh = gate["size"]
        top = gy
        if gx - gw / 2 <= x <= gx + gw / 2 and y <= top <= y + limit:
            best = top if best is None else min(best, top)
    return best


def check_level(level: Level, env: Envelope) -> tuple[list[str], list[str], list[str]]:
    failures: list[str] = []
    warnings: list[str] = []
    infos: list[str] = []

    # 1. Spawns and goal must have ground under them, and no wall inside them.
    for index, (sx, sy) in enumerate(level.spawns):
        if surface_below(level, sx, sy, 300.0) is None:
            failures.append(f"spawn {index + 1} at ({sx:.0f}, {sy:.0f}) has no floor within 300px")
        for rx, ry, rw, rh, _style in level.rects():
            # A keeper's origin is at its feet, so standing exactly on a
            # surface is legal; only a spawn strictly inside stone is an error.
            if rx <= sx <= rx + rw and ry + 1.0 < sy <= ry + rh:
                failures.append(f"spawn {index + 1} at ({sx:.0f}, {sy:.0f}) is inside a solid")
    if level.goal is None:
        failures.append("no goal_rect: the level cannot be finished")
    else:
        gx, gy, gw, gh = level.goal
        cx = gx + gw / 2
        if surface_below(level, cx, gy + gh, 200.0) is None:
            failures.append("the goal area has no floor under it")
        for gate in level.gates:
            px, py = gate["pos"]
            ox, oy = gate["offset"]
            for t in (0.0, 0.5, 1.0):
                rx, ry = px + ox * t, py + oy * t
                w, h = gate["size"]
                if rx - w / 2 < gx + gw and rx + w / 2 > gx and ry - h / 2 < gy + gh and ry + h / 2 > gy:
                    warnings.append(f"gate '{gate['channel']}' passes through the goal area at t={t:.1f}")

    # 2. Devices that live on a floor must actually sit on it. A plate or a
    #    waystone hanging in mid-air still "has floor below it" but can never
    #    be used, so check the distance, not just the presence.
    for index, (wx, wy) in enumerate(level.waystones):
        surface = surface_below(level, wx, wy, 200.0)
        if surface is None:
            failures.append(f"waystone {index + 1} at ({wx:.0f}, {wy:.0f}) floats above nothing")
        elif surface - wy > 12.0:
            failures.append(f"waystone {index + 1} at ({wx:.0f}, {wy:.0f}) hangs {surface - wy:.0f}px above its floor at y={surface:.0f}")
    for px, py, channel in level.plates:
        surface = surface_below(level, px, py, 200.0)
        if surface is None:
            failures.append(f"plate '{channel}' at ({px:.0f}, {py:.0f}) floats above nothing")
        elif surface - py > 12.0:
            failures.append(f"plate '{channel}' at ({px:.0f}, {py:.0f}) hangs {surface - py:.0f}px above its floor at y={surface:.0f}")
    if not level.waystones:
        infos.append("no waystones: a spill respawns at the start (acceptable for a short garden)")

    # 3. Every gap between two surfaces at the same height must be crossable by
    #    somebody, or have a device (ring / bridge gate) in it.
    tops: list[tuple[float, float, float]] = []
    for x, y, w, h, _style in level.rects():
        tops.append((x, x + w, y))
    tops.sort()
    seen: set[tuple[float, float]] = set()
    for i, (a0, a1, ay) in enumerate(tops):
        for b0, b1, by in tops[i + 1 :]:
            if abs(ay - by) > 2.0:
                continue
            gap = b0 - a1
            if gap <= 0.0:
                continue
            key = (round(a1), round(b0))
            if key in seen:
                continue
            seen.add(key)
            if gap > env.best_gap() + 1.0:
                mid_x = (a1 + b0) / 2
                bridge = any(
                    g["channel"] and abs(g["pos"][0] - mid_x) < max(gap, 400) and abs(g["pos"][1] - ay) < 260
                    for g in level.gates
                )
                ring = any(abs(rx - mid_x) < gap and abs(ry - ay) < 340 for rx, ry in level.rings)
                wind = any(
                    w["pos"][0] + w["area"][0] <= mid_x <= w["pos"][0] + w["area"][0] + w["area"][2]
                    and w["pos"][1] + w["area"][1] <= ay <= w["pos"][1] + w["area"][1] + w["area"][3]
                    for w in level.winds
                )
                message = (
                    f"{gap:6.0f}px gap at x={mid_x:6.0f}, y={ay:6.0f} is wider than any jump "
                    f"({env.best_gap():.0f}px)"
                )
                if bridge or ring or wind:
                    infos.append(message + (" [bridge nearby]" if bridge else " [ring nearby]" if ring else " [wind nearby]"))
                else:
                    failures.append(message + " with no ring, bridge or wind in it: a trap")

    # 4. Stepping stones that need help: rises beyond a single keeper's jump
    #    are only reported, since lifts, launches and wind are legitimate
    #    answers that a static checker cannot fully model.
    surfaces = sorted({(round(y, 1), x, x + w) for x, y, w, h, _style in level.rects()}, key=lambda s: (s[0], s[1]))
    for i, (ay, a0, a1) in enumerate(surfaces):
        for by, b0, b1 in surfaces[i + 1 :]:
            rise = ay - by
            if rise <= 0 or rise > 420:
                continue
            if a1 < b0 - 260 or b1 < a0 - 260:
                continue
            if rise > env.best_rise() + 1.0:
                mid_x = (max(a0, b0) + min(a1, b1)) / 2 if a1 > b0 and b1 > a0 else (a1 + b0) / 2
                helped = (
                    any(abs(g["pos"][0] - mid_x) < 320 for g in level.gates)
                    or any(abs(rx - mid_x) < 320 for rx, ry in level.rings)
                    or any(abs(w["pos"][0] - mid_x) < 320 for w in level.winds)
                    or any(abs(px - mid_x) < 320 for px, py, _c in level.plates)
                )
                text = f"{rise:6.0f}px rise from y={ay:6.0f} to y={by:6.0f} near x={mid_x:6.0f} needs help"
                if helped:
                    infos.append(text + " [device nearby]")
                else:
                    warnings.append(text + " - no lift, launcher, ring or wind within reach")

    # 5. Keep everything inside bounds.
    if level.bounds:
        bx, by, bw, bh = level.bounds
        for x, y, w, h, style in level.rects():
            if x < bx - 60 or x + w > bx + bw + 60:
                warnings.append(f"solid '{style}' at x={x:.0f}..{x + w:.0f} pokes outside the level bounds")
    return failures, warnings, infos


def ascii_map(level: Level, width: int = 100, height: int = 34) -> str:
    if not level.bounds:
        return "    (no bounds declared)"
    bx, by, bw, bh = level.bounds
    grid = [[" "] * width for _ in range(height)]

    def plot(x: float, y: float, ch: str) -> None:
        col = int((x - bx) / bw * (width - 1))
        row = int((y - by) / bh * (height - 1))
        if 0 <= col < width and 0 <= row < height:
            grid[row][col] = ch

    def fill_rect(x: float, y: float, w: float, h: float, ch: str) -> None:
        for t in range(0, 21):
            plot(x + w * t / 20.0, y, ch)
            plot(x + w * t / 20.0, y + h, ch)
        for t in range(0, 21):
            plot(x, y + h * t / 20.0, ch)
            plot(x + w, y + h * t / 20.0, ch)

    for x, y, w, h, _style in level.rects():
        fill_rect(x, y, w, h, "#")
    for gate in level.gates:
        gx, gy = gate["pos"]
        ox, oy = gate["offset"]
        fill_rect(gx - gate["size"][0] / 2, gy - gate["size"][1] / 2, gate["size"][0], gate["size"][1], "G")
        plot(gx + ox, gy + oy, "g")
    for px, py, _channel in level.plates:
        plot(px, py, "P")
    for wind in level.winds:
        ax, ay, aw, ah = wind["area"]
        fill_rect(wind["pos"][0] + ax, wind["pos"][1] + ay, aw, ah, "~")
    for rx, ry in level.rings:
        plot(rx, ry, "O")
    for sx, sy in level.waystones:
        plot(sx, sy, "W")
    for index, (sx, sy) in enumerate(level.spawns):
        plot(sx, sy, str(index + 1))
    if level.goal:
        gx, gy, gw, gh = level.goal
        fill_rect(gx, gy, gw, gh, "*")
    return "\n".join("    " + "".join(row) for row in grid)


def main() -> int:
    cfg = parse_constants(CONFIG)
    stats = parse_stats(FORMS)
    env = Envelope(cfg, stats)
    print("Movement envelope derived from src/core/config.gd + src/core/forms.gd:")
    print(env.describe())
    print()

    patterns = [a.lower() for a in sys.argv[1:]]
    files = sorted(LEVELS_DIR.glob("*.gd"))
    files = [f for f in files if f.stem != "level_base"]
    if patterns:
        files = [f for f in files if any(p in f.stem.lower() for p in patterns)]

    total_failures = 0
    for path in files:
        level = parse_level(path)
        failures, warnings, infos = check_level(level, env)
        total_failures += len(failures)
        print(f"== {level.name} ==")
        print(f"    solids {len(level.rects())}  gates {len(level.gates)}  plates {len(level.plates)}  "
              f"winds {len(level.winds)}  rings {len(level.rings)}  waystones {len(level.waystones)}")
        for line in failures:
            print(f"    {FAIL}: {line}")
        for line in warnings:
            print(f"    {WARN}: {line}")
        for line in infos:
            print(f"    {INFO}: {line}")
        if not failures and not warnings:
            print("    OK: no blocking design problems found")
        print()
        print(ascii_map(level))
        print()

    print(f"checked {len(files)} level(s); {total_failures} blocking problem(s)")
    return 1 if total_failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
