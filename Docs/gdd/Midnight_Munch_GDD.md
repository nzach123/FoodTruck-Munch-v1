# Midnight Munch — Master Game Design Document

**Version:** 3.1 (Master / Consolidated — all open questions resolved)
**Author:** Nick
**Date:** April 2026
**Status:** Source of Truth for Claude Code implementation
**Engine:** Godot 4.6 (GDScript only — no C#)
**Platform:** Web (HTML5 / WebGL2)
**Genre:** Cozy Time-Management Cooking Sim
**Prototype Scope:** 3 weeks, 12-task MVP. One truck (taco). Core cooking loop. Day 0 tutorial. No driving.
**Performance Target:** 60 FPS on a 2019 MacBook Air or equivalent Windows laptop.

---

## 0. Source-of-Truth Reconciliation

This master document supersedes all prior design files. Where conflicts exist, precedence is:

1. **This document (v3.1 Master)** — final authority.
2. **`Midnight_Munch_-_Game_Playloop.md` (v2.0)** — authoritative on mechanics, economy, scope.
3. **`New_into_GDD.md` (addendum)** — authoritative on keybindings, hand-slot assignments, station-specific UX, customer navigation, sauce overfill behaviour.
4. **`Midnight_Munch_-_Design_Document.md` (v1.0)** — preserved for narrative pitch, customer archetypes, asset list, physics layers.
5. **Godot scene `TruckInterior.tscn`** — reflects current node-tree reality; class/node names below mirror it.

### 0.1 Resolved Decisions Log (v3.0 → v3.1)

| # | Decision | Resolution |
|---|---|---|
| Q1 | Trompo mash semantics | **Discrete 3-slice counter.** Each `E` press = 1 slice = 1 visible meat fragment placed on tortilla. 3 presses required to register the Meat ingredient. No radial bar. |
| Q2 | Mouse-look extent | **Full free-look.** Yaw 360° unclamped; pitch ±89°. No crouch, no jump. |
| Q3 | Sauce overfill outcome | **Equivalent to red zone** (sloppy + tip lost). Visual differentiator only: extra GPU particle output ("over-spray"), no additional mechanical penalty. |
| Q4 | Customer waypoint marker | **Internal navigation only.** `Marker3D` driving `NavigationAgent3D.target_position`. Not visible to player. |
| Q5 | Crouch components | **Out of scope. Removed.** Strip `CrouchingCollisionShape` and `CrouchRayCast` from the Player node. |
| Q6 | Order sequencing | **Strictly enforced.** Tortilla → Meat (3 slices) → Toppings → Sauces → Bell. Stations downstream of the current step are locked until prerequisites are met. |
| Q7 | Topping sloppy-flag stickiness | **Sticky.** First miss permanently sets the orange flag for that topping, even if a retry hits. |
| Q8 | Sauce bottle handling | **Contextual animation, not carried.** On `F` press at a sauce station, the bottle animates from counter → left side of screen, sprays during squishing, animates back to counter on commit. The player never carries the bottle between stations. |
| **Q9** | **NEW: Developer Debug Overlay** | **In scope.** Toggleable `F3` overlay showing live game state, flags, current order, queue, state machine, and EventBus log. Spec'd in §12.11. |

---

## 1. Project Summary

### 1.1 Pitch

Midnight Munch is a first-person cozy time-management cooking sim. The player runs a taco food truck. Customers queue at the serving window with procedurally-generated orders, lose patience in real time, and leave if ignored too long. The player moves freely between a **back counter** (tortilla, meat) and a **front counter** (toppings, sauces, bell), assembles each order in a strict sequence, and rings the bell to serve. Each day is a 5-minute session. Profits fund upgrades. The pressure ramps Days 1 → 7 then plateaus — further progression comes from skill, not escalating numbers.

### 1.2 Inspiration

- **Cook, Serve, Delicious!** — the rhythm of reading an order and executing under pressure, extended by making each ingredient feel physically distinct rather than mapped to a single key.
- **Overcooked** — escalating queue pressure and the satisfaction of a clean service, stripped of co-op chaos and replaced with personal skill expression.
- **Stardew Valley** — the cozy grind: each day is self-contained, profits roll over, upgrades compound.

### 1.3 Player Experience

The player stands first-person inside a taco truck, moves freely with WASD, looks with mouse (full yaw + clamped pitch). Through the serving window they see a queue of up to three customers — each with a patience arc and a speech bubble showing required ingredients. The player clicks a customer to accept, then walks to the back counter (tortilla → trompo) and front counter (toppings → sauces → bell). Emotional arc: calm and methodical at the start of a day, tense and rhythmic as the queue fills and patience bars tick down faster.

### 1.4 Target Audience

Casual and cozy gamers; cooking-rhythm-game fans who enjoy grinding and watching a bank balance grow. Core appeal is competence — starting clumsy, becoming fast, accurate, and efficient.

### 1.5 Engine & Platform Constraints

| Constraint | Value | Rationale |
|---|---|---|
| Engine | Godot 4.6 | Project standard |
| Language | GDScript only | C# is incompatible with Web/WASM build size targets |
| Platform | HTML5 / WebGL2 | Browser-first delivery |
| Resolution | 1280 × 720 (16:9 web canvas) | Default web target |
| Frame budget | 16.6 ms/frame (60 FPS) | 2019 MacBook Air baseline |
| Save target | <4 KB JSON to `user://save.json` (IndexedDB-backed) | Tab-crash-resilient |

### 1.6 Browser Compatibility Matrix

| Browser | Version | Tier |
|---|---|---|
| Chrome | 110+ | Primary — test daily |
| Firefox | 110+ | Primary — test weekly |
| Edge | 110+ | Secondary — Chromium parity assumed |
| Safari | Latest | Best-effort — test pre-launch |
| Mobile browsers | — | Out of scope for prototype |

---

## 2. Main Menu

| Element | Spec |
|---|---|
| Background | Low-poly taco truck parked at night, neon "Midnight Munch" sign glowing |
| Ambience | Soft city ambience, distant crowd, truck engine idling |
| Buttons | `[New Game]` / `[Continue]` / `[Settings]` / `[Credits]` |

**Logic:**
- `[New Game]` appears only if no save file exists.
- `[Continue]` appears if a save file exists; loads directly to the saved day.
- `[Settings]` exposes audio volume sliders only for the prototype.
- First-time players go straight to **Day 0 (tutorial)** after `[New Game]`.

---

## 3. Session Structure

### 3.1 Day 0 — Tutorial (Required Scope)

A scripted sequence of five orders. **No timer. No patience bars. No penalties. Player cannot fail.**

| Order | Ingredients | Guidance |
|---|---|---|
| 1 | Tortilla + Meat | Full guided prompts at every station |
| 2 | Tortilla + Meat + Red Sauce | Guided prompts for sauce only |
| 3 | Tortilla + Meat + 1 Topping | Guided prompt for topping only |
| 4 | Tortilla + Meat + both Sauces + 2 Toppings | Light prompts |
| 5 | Full random order | No prompts — player flies solo |

**Guided prompt system:** A world-space arrow + text label appears above the next required station (e.g. "Press E to grab a tortilla"). Fades the moment the action completes. Never tells the player what *not* to do — only points toward what to do next.

**Feedback on correct action:** Green particle burst + chime. Establishes that the rhythm of a good order feels good before any stakes are introduced.

**End of Day 0:** Transition screen — *"The truck is ready. Real customers start tomorrow. Don't keep them waiting."* → `[Open for Business]` → Day 1 begins.

### 3.2 Day 1+ — Full Session

A countdown timer (visible as a clock on the truck wall, mirrored top-left HUD) runs **5:00 → 0:00**. Customers arrive throughout. When the timer hits zero the serving window closes, the end-of-day screen appears, and any in-progress order is abandoned without penalty.

### 3.3 Day Progression Schedule

Each new day increases pressure automatically. No player-facing difficulty announcement — the heat just builds. Values held flat from Day 7 onward.

| Day | Patience (sec) | Spawn Rate | Max Concurrent | Feel |
|---|---|---|---|---|
| 0 | ∞ | Scripted | 1 | Tutorial — no pressure |
| 1 | 60 | 1 per 45 s | 2 | Forgiving. Establish the loop. |
| 2 | 55 | 1 per 40 s | 2 | Barely noticeable shift. |
| 3 | 50 | 1 per 35 s | 3 | Queue starts filling. |
| 4 | 45 | 1 per 30 s | 3 | Rush feeling emerges. |
| 5 | 40 | 1 per 25 s | 3 | Expert territory begins. |
| 6 | 35 | 1 per 22 s | 3 | Mastery required. |
| 7+ | 30 | 1 per 20 s | 3 | Ceiling. Held indefinitely. |

> **Implementation:** Schedule lives in `res://data/difficulty_schedule.tres` (a `Resource` subclass with an array of per-day entries). Read by `GameManager.gd` at day start; never hardcoded.

### 3.4 End-of-Day Screen

Appears after the 5-minute timer expires. **Auto-saves before any button is pressed** (tab-crash insurance).

1. Total money earned (animated count-up).
2. Orders completed / orders attempted.
3. Total tips earned.
4. Upgrade shop (visible; greyed out if unaffordable).
5. `[Save & Exit]` — returns to main menu.
6. `[Next Day]` — begins next day immediately.

---

## 4. Customer Queue & Triage

### 4.1 Queue Rules

- **Maximum 3 customers** visible at once (data-driven via `Resource`; configurable without code change).
- Each unaccepted customer carries a persistent speech bubble showing their required ingredients (small, world-space, always visible).
- Each customer has a **patience arc** above their head that depletes from the moment they arrive — **even before the player accepts their order.**

### 4.2 Customer Spawning & Navigation

- Customers spawn at an off-screen spawn point and pathfind to the serving window using a **`NavigationAgent3D`** per NPC.
- Three queue slots are pre-defined as `Marker3D` nodes in the scene; the `CustomerSpawner` assigns the nearest unoccupied marker to each new arrival as the agent's `target_position`.
- The waypoint marker is **internal navigation only** — never visible to the player.
- When a customer leaves (served or angry), the queue compacts forward; subsequent arrivals re-target the now-vacant marker.

### 4.3 One Order at a Time

The player accepts one customer's order at a time. That order **locks into the top-right HUD**. The player cannot accept a second order until the current taco is served. **All other customers' patience continues draining while the player cooks.**

> **The skill is triage:** choosing which order to take first — a simple order from an impatient customer vs. a complex order from a patient one. This decision repeats every 60–90 s and is the primary strategic layer.

### 4.4 Accepting an Order

- Player clicks on a customer (raycast from `Camera3D`, 3.0 m reach).
- Speech bubble is replaced by a small `[WAITING]` indicator.
- Order moves to the top-right HUD panel.
- Assembly begins, gated by §5.2 sequence rules.

### 4.5 Customer Archetypes

Customers are not enemies — they are the clock. Their job is to create urgency and prioritisation decisions.

| Archetype | Patience | Order Profile | Tip | Status |
|---|---|---|---|---|
| **Standard** | Per-day default (see §3.3) | 1–2 optional ingredients | Standard curve | **Prototype — only this archetype** |
| **Picky** | Short | Requires all optional ingredients | High on perfect | Stretch goal |
| **Chill** | Long | Meat + tortilla only | Low | Stretch goal |

### 4.6 Patience Expiry

When an arc bar hits zero:
- Customer plays anger animation and leaves.
- Bank balance is debited **$1.50** (capped — cannot push balance below $0).
- Queue shifts forward; new customer may arrive on the next spawn tick.

### 4.7 Soft Bail-Out

If the player ends a day at $0.00, a "Regular Customer" appears at the start of the next day and hands over **$2.00** before the clock starts. Diegetic, once per failed day. Balance never goes negative across sessions.

---

## 5. Order System

### 5.1 Recipe Structure

Every taco always contains:

- **Tortilla** (always)
- **Meat** (always — 3 slices to register complete)

Plus any combination of optional ingredients:

| Ingredient | Optional |
|---|---|
| Red Sauce | Yes |
| White Sauce | Yes |
| Cilantro | Yes |
| Tomato | Yes |
| Onion | Yes |

Orders are procedurally generated. Combination is random per customer. No two customers are guaranteed the same order.

> **Implementation:** Recipes generated by `OrderManager.gd` from a `Recipe` resource template that defines required vs. optional ingredients and weighted probabilities per optional. Per-day weight tuning via `.tres`.

### 5.2 Strict Assembly Sequence (Authoritative)

Recipes enforce a fixed assembly order. Stations downstream of the current step are **locked** (cannot be activated) until prerequisites are satisfied. The dynamic UI prompt (§6.8) shows the disabled reason when the player aims at a locked station.

```
1. TORTILLA      (always available)
        ↓
2. MEAT          (requires: tortilla in hand)               3 slices required
        ↓
3. TOPPINGS      (requires: meat complete)                  in any order among themselves
        ↓
4. SAUCES        (requires: all required toppings placed)   in any order among themselves
        ↓
5. BELL          (always usable, but validates the order on press)
```

**Topping/Sauce conditional:** If a customer's order does **not** include any toppings, sauce stations unlock immediately after meat is complete. If the order includes no sauces, the bell is the next valid step after toppings.

**Locked-station feedback:** When the player aims at a station whose prerequisites are not met, the world-space prompt reads e.g. `Sauce locked — place toppings first`. The station's `Area3D` still highlights (cursor over interactable) but the input is rejected with a soft buzz SFX.

### 5.3 Order HUD Pills (Top-Right Panel)

Always visible once an order is accepted. Never fades. Disappears only on serve. Each ingredient is a pill that changes state in real time:

| State | Visual | Meaning |
|---|---|---|
| Grey outline | `[ Red Sauce ]` | Required, not yet added |
| Pulsing white | `[ Red Sauce ]` | Currently being interacted with |
| Green + checkmark | `[✓ Red Sauce ]` | Added perfectly |
| Orange + tilde | `[~ Red Sauce ]` | Added (sloppy execution) |
| Red + X | `[✗ Red Sauce ]` | Bell rung — this item was missing |

The cognitive challenge is **speed and triage**, not memorisation. The HUD is the ground truth.

---

## 6. Cooking Mechanics

Four interaction primitives. Each is physically and mechanically distinct. Learn once, apply everywhere.

### 6.1 Keybinding Map (Authoritative)

| Action | Input | Hand |
|---|---|---|
| Move | `W` `A` `S` `D` | — |
| Look | Mouse (yaw 360° free, pitch ±89°) | — |
| Accept Customer / Aim at Station | Mouse cursor | — |
| Place Topping (timed click) | `Left Mouse Button` | — |
| Grab Tortilla (back counter) | `E` | Right (held after grab) |
| Slice Meat at Trompo (back counter) | `E` (3 discrete presses) | Right hand holds tortilla; meat fragments fall onto it |
| Apply Sauce (front counter) | `F` (tap-to-squish, accumulates) | Bottle animates into left side of screen, sprays onto tortilla in right hand, animates back |
| Ring Service Bell (front counter) | `F` | — |
| **Toggle Debug Overlay** | `F3` | See §12.11 |

**Design rationale for `E` / `F`:**
- `E` = take/grab actions (back counter: tortilla, meat slicing).
- `F` = apply/serve actions (front counter: sauce squish, bell).
- `LMB` = aim-based timing actions (toppings, customer selection).

### 6.2 Interaction Primitives

| Primitive | Input Pattern | Visual Feedback | Used For |
|---|---|---|---|
| **Click (Instant)** | Single key press | None | Tortilla grab, bell |
| **Discrete Counter** | N discrete key presses | Per-press fragment placement + counter UI | Meat slicing |
| **Tap-Accumulate** | Repeated key presses; auto-commit on input idle | Vertical gauge fills in pulses with each press | Sauces |
| **Shrinking Circle (Timing)** | Click at the right moment | Circle shrinks toward target band | Toppings |

### 6.3 Station: Tortilla — Click

- **Location:** Tortilla stack on the **back counter**.
- **Input:** `E`.
- **Effect:** A tortilla spawns directly into the player's **right hand**. Held-item icon appears bottom-centre HUD. The tortilla persists in-hand through every subsequent step until served.
- **Fail state:** None. Stack is always available.

### 6.4 Station: Trompo (Meat) — Discrete 3-Slice Counter

- **Location:** Vertical al pastor spit on the **back counter**, beside the tortilla stack.
- **Input:** `E` (three discrete presses required).
- **Visual:** The meat **spins continuously** as the player approaches.
- **Effect:** Each `E` press triggers a slice flash on the trompo and visually transfers **one** meat fragment onto the tortilla in the right hand. A counter UI displays `Slices: 1/3`, `2/3`, `3/3` during the action. **On the third press**, the Meat ingredient registers complete (HUD pill turns green) and a final stacking thud confirms.
- **No bar.** This is a discrete press counter, not a power bar — the gauge mechanic now lives on the sauce.
- **Timing logic:** Press detection runs in `_physics_process` for web stability. Per-press deltas are **not** sampled in `_input`.
- **Feedback:**
  - Per press: trompo flash + brief sizzle/scrape SFX + meat fragment particle landing on tortilla.
  - On 3rd press: meat-portion thud + counter hides + HUD pill green.
- **Upgrade — Sharper Knife:** Required slices reduced from 3 → 2.

### 6.5 Station: Sauce (Red & White) — Tap-Accumulate Power Bar

- **Location:** Two distinct bottles (red, white) on the **front counter**, near the serving window.
- **Input:** `F` (repeated discrete presses; bottle "squishes" once per press; gauge accumulates).
- **Bottle animation lifecycle:**
  1. Player faces sauce station and presses `F` for the first time.
  2. Bottle animates from its position on the counter → **left side of the screen** (player's left hand visible holding it).
  3. Each subsequent `F` press triggers a single bottle squish animation + a GPU particle burst spraying onto the tortilla in the right hand + an incremental gauge tick.
  4. After **0.4 s of `F` input idle**, the current gauge level commits the outcome.
  5. Bottle animates back from left side of screen → counter resting position.
- **Vertical gauge:** Three zones, visible from the moment the player faces the station.

| Commit Zone | Outcome | HUD State | Tip Impact |
|---|---|---|---|
| Below green (under-pour) | Sauce **not added.** Player can retry from zero. | Pill remains grey | None |
| Green band | Sauce added cleanly. **Marked perfect.** | Pill turns green ✓ | None (positive) |
| Past green into red (over-pour) | Sauce added but over-poured. **Marked sloppy.** | Pill turns orange ~ | Disqualifies tip |
| **Held to max meter (overfill / over-spray)** | Mechanically equivalent to red zone. **Visual differentiator only:** GPU particle output increases dramatically (over-spray VFX). Same sloppy + tip-lost result. | Pill turns orange ~ | Disqualifies tip |

- **Particle spray auto-stop conditions:** (a) commit triggered (any zone), (b) bottle animating back to counter.
- **Under-pour recovery:** Player can immediately retry. The gauge resets to zero on each new attempt; no penalty for under-pours.
- **Over-pour note:** Once committed in red zone, the sauce is on the taco; cannot be undone. Order will complete but tip is forfeit.
- **Feedback:**
  - Each `F` press during interaction: bottle pump animation + small particle pulse + soft squish SFX.
  - While accumulating in green band: soft pleasant hum overlay.
  - While accumulating past green: warning tone (audio plays *after* visual, never as a sync reference — web latency).
  - On commit (green): clean squirt SFX + green pill flash.
  - On commit (red): splatter SFX + orange pill flash.
  - On overfill: heavier splatter + extra particle burst + orange pill flash.
- **Upgrade — Better Sauce Bottle:** Green zone band is ~40 % wider on the gauge.

### 6.6 Station: Toppings (Cilantro, Tomato, Onion) — Shrinking Circle

- **Location:** Three bins — cilantro (green), tomato (red), onion (white) — on the **front counter** between the trompo and the sauce bottles.
- **Input:** `Left Mouse Button` (timed click). First LMB on bin opens the mini-game; the next LMB commits the timing.
- **Mini-game:** A large circle centres on screen and shrinks toward a visible **target band**. Player clicks LMB when the shrinking ring enters the target band.
- **Critical web implementation note:**
  - Timing logic runs on `_physics_process` only.
  - Audio feedback plays **after** hit confirmation — never as a sync cue.
  - Timing window is **30 % wider** than a native equivalent to compensate for WASM input latency.
  - **Build this first as a Week 1 standalone spike in Chrome before any other interaction work.**

| Result | Condition | Consequence |
|---|---|---|
| Hit | Click inside target band | Topping placed in taco. HUD pill turns green ✓. |
| Miss | Click outside band | Topping drops on floor. **−$0.05** deducted. Player can retry. **Sloppy flag set permanently for this topping**, even if a retry hits. |

- **Target band:** Visible from frame 1 of the animation. Player always knows where to aim.
- **Sticky sloppy flag:** Once any miss occurs on a given topping in the current order, the pill commits to orange (`~`) on eventual placement, regardless of subsequent retry quality.
- **Drop recovery:** A missed topping sits on the floor as a **pooled `RigidBody3D`**, frozen on impact. Player clicks the bin again to try fresh. Dropped item despawns after **10 s** and is recycled to the pool.
- **Feedback:**
  - Hit (clean): topping lands in taco + green flash + HUD update + satisfying sound.
  - Hit (after prior miss): topping lands + orange flash + HUD update.
  - Miss: topping bounces on floor + dull thud + `−$0.05` ticker on screen (1 s float-and-fade).

### 6.7 Station: Service Bell — Click (Serve + Ring)

- **Location:** Bell on the **front counter**, beside the serving window. A **Designated Serving Area** (`SnapZone` `Area3D`) sits adjacent to the bell.
- **Input:** `F`.
- **Single-action behaviour:** Pressing `F` at the bell does both in one step:
  1. The held taco detaches from the player's right hand and snaps into the Serving Area transform (presented to the customer through the window).
  2. The bell rings.
  3. Order validation runs immediately.
- **Validation logic:**

| Condition | Outcome |
|---|---|
| All HUD pills green or orange (all ingredients present) | Serve immediately — see §7 scoring |
| Any HUD pill still grey (missing ingredient) | Confirmation popup appears; taco remains in hand pending decision |

- **Confirmation popup (missing ingredient):**
  > *"This order is missing [ingredient name]. Serve anyway?"*
  > `[YES — Serve]` / `[NO — Keep Cooking]`
  - `[YES]` → submit incomplete → customer rejects → food cost deducted → customer leaves.
  - `[NO]` → popup closes; no penalty; player returns to cooking.

This guard prevents a single misclick from triggering a $2+ penalty. Submitting a wrong order must be a deliberate choice.

### 6.8 Dynamic Station UI Prompts

Every station emits **interactability state** in real time:

- When the camera raycast (3.0 m) intersects a station's `Area3D` **and** the §5.2 sequence prerequisites are met, a world-space prompt appears: e.g. `[E] Grab Tortilla`, `[E] Slice Meat (1/3)`, `[F] Squish Sauce`, `[LMB] Time the Topping`, `[F] Ring Bell`.
- When sequence prerequisites are **not** met, the prompt shows a dimmed disabled state with a reason — e.g. `Trompo locked — grab a tortilla first`, `Sauce locked — place toppings first`. Input is rejected with a soft buzz SFX if the player presses anyway.
- Cursor states: default crosshair dot / larger circle + context icon over an interactable / dimmed dot over nothing.
- **One-station-active rule:** only the station the cursor is currently over can be interacted with. Adjacent stations do not highlight simultaneously.

---

## 7. Quality & Scoring

### 7.1 Per-Order Quality Flags

The game tracks quality flags across the entire assembly of one taco:

| Interaction | Perfect flag | Sloppy flag |
|---|---|---|
| Sauce | Committed in green zone | Committed in red zone, or held to overfill |
| Topping | Hit target band on first try | Missed at least once (sticky — retry quality irrelevant) |
| Meat | Always neutral (3 presses always work the same) | N/A |
| Tortilla | Always neutral | N/A |

### 7.2 Outcome Table

| Condition | Payment | Tip | Notes |
|---|---|---|---|
| All interactions perfect (0 sloppy flags) | $3.50 | $1.00 | All HUD pills green |
| 1 sloppy flag | $3.50 | $0.50 | One orange pill |
| 2+ sloppy flags | $3.50 | $0.00 | Multiple orange pills |
| Missing ingredient (confirmed submission) | $0.00 | $0.00 | Customer rejects. Food cost deducted. |

---

## 8. Economy

### 8.1 Starting Balance

Player begins Day 1 with **$5.00**. Enough to absorb one rejection and one angry customer — but not both. Designed to feel precarious without being cruel.

### 8.2 Revenue

| Source | Amount |
|---|---|
| Taco sale (any completion) | +$3.50 |
| Tip — 0 sloppy flags | +$1.00 |
| Tip — 1 sloppy flag | +$0.50 |
| Tip — 2+ sloppy flags | +$0.00 |
| Soft bail-out (Regular Customer, after $0 day) | +$2.00 (once, start of next day) |

### 8.3 Deductions

| Event | Deduction | Notes |
|---|---|---|
| Drop topping | $0.05 | Per drop |
| Under-pour sauce (retry only) | $0.00 | No penalty — just lost time |
| Over-pour / overfill sauce | $0.00 | Penalty is the lost tip, not a direct deduction |
| Customer patience expires | $1.50 | Capped — cannot push below $0 |
| Wrong order confirmed + rejected | Food cost of taco | See §8.4 |

### 8.4 Food Cost Per Ingredient

| Ingredient | Cost |
|---|---|
| Tortilla | $0.25 |
| Meat (per fully sliced portion = 3 slices) | $0.75 |
| Red Sauce | $0.15 |
| White Sauce | $0.15 |
| Cilantro | $0.10 |
| Tomato | $0.10 |
| Onion | $0.10 |

- Base taco (meat + tortilla): **$1.00** food cost.
- Fully loaded taco: **$1.60** food cost.
- Player margin per successful order (before tips): **$1.90 – $2.50**.

### 8.5 Economy Floor

Balance cannot go below **$0.00**. Any penalty that would push below zero is **capped at the current balance**. If a day ends at $0, the bail-out Regular Customer appears at the start of the next day (+$2.00).

### 8.6 Economy Arc (Target Pacing)

| Days | Typical Balance | Feel |
|---|---|---|
| 1–2 | $5–$25 | Scraping by. Upgrades out of reach. Every mistake stings. |
| 3–4 | $25–$60 | First upgrade affordable. Noticeable rhythm improvement. |
| 5–7 | $60–$150+ | Second upgrade in reach. Skill + upgrades compound. Flow state emerges. |

---

## 9. Upgrade Shop

Available on the end-of-day screen when funds permit. **No day unlock gates** — earn it, buy it.

| Upgrade | Cost | Effect |
|---|---|---|
| Sharper Knife | $25 | Required trompo slices reduced from 3 → 2 |
| Better Sauce Bottle | $40 | Green zone band ~40 % wider on sauce gauge |

Both purchasable in any order. No dependency tree. Each is a one-time purchase.

**Design rationale:** A good Day 1 earns ~$15–20. The knife is tantalisingly out of reach on Day 1 and comfortably affordable by Day 2–3. The sauce bottle follows once the knife is purchased. Together they transform Days 5–7 from punishing to satisfying.

*Future upgrades (post-prototype): topping timing window assist, patience extender, second bell slot.*

---

## 10. HUD Layout

**Resolution:** 1280 × 720 (16:9 web canvas).

| Element | Position | Behaviour |
|---|---|---|
| Day timer | Top-left | Counts down 5:00 → 0:00. Truck-wall clock face (world-space) mirrors the number. |
| Bank balance | Top-left, below timer | Updates live on every transaction. Brief green flash on credit, red flash on debit. |
| Current order panel | Top-right | Ingredient pills with live state feedback. Always visible once order is accepted. Disappears on serve. |
| Held item icon | Bottom-centre | Shows what is currently in the player's hand. Empty = no icon. |
| Interaction prompt | World-space above station | Contextual: `[E] Grab` / `[E] Slice (n/3)` / `[F] Squish Sauce` / `[LMB] Time` / `[F] Ring Bell`. Hover only. Includes locked-state messaging per §6.8. |
| Patience arcs | World-space above NPCs | Arc depletes in real time. Turns red in last 10 s. |
| Slice counter | Screen-centre (contextual) | `Slices: n/3` visible only while at trompo. |
| Sauce gauge | Screen-centre (contextual) | Visible only during sauce interaction. Green zone visible before interaction begins. |
| Shrinking circle | Screen-centre (contextual) | Visible only during topping placement. Target band visible from frame 1. |
| Penalty ticker | Screen-centre (brief) | "−$0.05" floats and fades over 1 s on topping drop. |
| Bell confirmation popup | Screen-centre (modal) | Blocks interaction until dismissed. "Missing [X]. Serve anyway?" |
| **Debug overlay (F3)** | Top-right corner stack | See §12.11 — toggleable developer overlay. |

---

## 11. Scene Layout & Camera

### 11.1 Camera & Movement

**WASD movement + full mouse-look. No crouch. No jump.**

The player moves freely inside the food truck using WASD. Mouse-look rotates the camera 360° horizontally (yaw unclamped) and ±89° vertically (pitch clamped just shy of straight up/down to avoid gimbal flip). The player can face any station from anywhere in the truck.

- Mouse → camera rotation (continuous, full free-look).
- WASD → player movement within truck bounds.
- LMB → interact with whatever the crosshair targets (or accept customer).

### 11.2 Station Layout (Top-Down ASCII)

```
═══════════════════[ SERVING WINDOW ]═══════════════════
              [ Customer queue (3 slots) visible here ]

[ Bell + Serving Area ]  [ Cilantro ] [ Tomato ] [ Onion ] [ Red Sauce ] [ White Sauce ]
←———————————————————— FRONT COUNTER (customer-facing) ————————————————————→

                          ↑ player moves ↑↓

                    [ Tortilla Stack ]   [ Trompo ]
←————————————————— BACK COUNTER (truck interior rear) —————————————————→
```

Player workflow (locked sequence, §5.2): walk to the **back** for tortilla + meat, then turn and walk to the **front** for toppings → sauces → bell.

### 11.3 Designated Serving Area

A `SnapZone` `Area3D` sits adjacent to the bell on the front counter. When the bell is rung **and** validation passes (or the popup confirms incomplete service), the held taco is detached from the player's hand and snapped into the serving area's transform for a brief presentation animation before being despawned/pooled.

### 11.4 Interaction Hitboxes

Each station has:
- A visual mesh (the actual object).
- An invisible `Area3D` proxy **1.5× larger** than the mesh, used as the raycast target.

The raycast originates from `Camera3D` and has a reach of **3.0 m** — enough to interact with any station the player is standing in front of, but not enough to accidentally trigger stations across the truck.

### 11.5 Physics Layers

| Layer | Contents |
|---|---|
| 1 | Environment (walls, counters, truck body) |
| 2 | Player raycast |
| 3 | Interactable stations and items |
| 4 | Snap zones (serving area, in-hand attachment) |

---

## 12. Technical Architecture

### 12.1 Core Principles

- **GDScript only.** No C#. Required for Web/WASM build size and compatibility.
- **Signal Up, Call Down.** Components emit signals to their direct parent. No sibling-to-sibling signal connections.
- **EventBus for cross-system events.** All game-wide state changes route through `EventBus.gd`.
- **Resources for all data.** Recipes, upgrade stats, pricing, and difficulty schedule defined in `.tres` files. Nothing hardcoded in script.
- **Object pooling.** Pre-instantiate all food item nodes at scene load. Recycle on serve or trash. **Never `queue_free()` during gameplay.**
- **`_physics_process` for all timing-sensitive logic.** `_process` and `_input` are jittery on WASM.

### 12.2 Project Folder Layout

```
res://
├── _src/
├── autoloads/
│   ├── EconomyManager.gd
│   ├── EventBus.gd
│   ├── GameManager.gd
│   └── NodePool.gd
├── data/                  # .tres resources (recipes, prices, schedule)
├── entities/              # Customer NPC scene + script
├── interactables/         # Per-station scenes + scripts
├── levels/
│   └── TruckInterior.tscn
├── player/                # TruckPlayer + InteractionStateMachine
├── ui/
│   ├── hud/               # MidnightMunchHUD + pills + popups + end-of-day + main menu
│   └── debug/             # DebugOverlay scenes (§12.11)
└── addons/
```

### 12.3 Autoload Singletons

| Singleton | Path | Responsibility |
|---|---|---|
| `EventBus` | `res://autoloads/EventBus.gd` | Global signals — see §12.6 |
| `GameManager` | `res://autoloads/GameManager.gd` | Day state (tutorial / playing / end-of-day), 5-min timer, phase transitions |
| `EconomyManager` | `res://autoloads/EconomyManager.gd` | Bank balance, all debits/credits, end-of-day tally, $0 floor enforcement |
| `NodePool` | `res://autoloads/NodePool.gd` | Object pool — checkout/return for all food items and NPC nodes |

### 12.4 Scene Tree (TruckInterior.tscn — v3.1 target)

```
TruckInterior (Node3D)
├── Player (CharacterBody3D)
│   ├── StandingCollisionShape (CollisionShape3D)
│   ├── StaircheckRayCast3D (RayCast3D)
│   ├── Body (Node3D — visual + Camera3D + interaction RayCast3D)
│   ├── MidnightMunchHUD (CanvasLayer)
│   ├── GUI (Control)
│   ├── InteractionStateMachine (Node)
│   ├── DebugOverlay (CanvasLayer, toggleable, debug-build-only)    # §12.11
│   └── NavigationAgent3D (NavigationAgent3D)                       # delete if unused for player
├── CSGGeo (Node3D)                                                 # placeholder geometry, replaced by Kenney models
│   ├── CSGCounter, CSGToppingsCounter, CSGStove
│   ├── CSGBody (CSGCombiner3D — truck shell)
│   └── CSGDrinks, Toppings, CSGFloor
├── Stations (Node3D)
│   ├── TortillaStation     (Area3D + mesh, interaction_type = INSTANT,           key = E)
│   ├── TrompoStation       (Area3D + mesh, interaction_type = DISCRETE_COUNTER,  key = E, count = 3)
│   ├── BellStation         (Area3D + mesh + SnapZone, interaction_type = INSTANT, key = F)
│   ├── WhiteSauceStation   (Area3D + mesh, interaction_type = TAP_ACCUMULATE,    key = F)
│   ├── RedSauceStation     (Area3D + mesh, interaction_type = TAP_ACCUMULATE,    key = F)
│   ├── CilantroStation     (Area3D + mesh, interaction_type = TIMING,            key = LMB)
│   ├── TomatoStation       (Area3D + mesh, interaction_type = TIMING,            key = LMB)
│   └── OnionStation        (Area3D + mesh, interaction_type = TIMING,            key = LMB)
├── QueueSlots (Node3D)                                             # §4.2 — internal nav targets
│   ├── Slot1 (Marker3D)
│   ├── Slot2 (Marker3D)
│   └── Slot3 (Marker3D)
└── Lighting (Node3D)
    ├── OmniLight3D
    ├── WorldEnvironment
    └── DirectionalLight3D
```

> **Cleanup task (Week 1, Task 1):** Remove `CrouchingCollisionShape` and `CrouchRayCast` from the existing Player node. Crouch is out of scope (Q5).

### 12.5 Object Pool Sizes (`NodePool.gd`)

| Pool | Count | Notes |
|---|---|---|
| Tortilla nodes | 10 | 3 active max + buffer |
| Meat fragment particles | 30 | Up to 3 per active tortilla × 3 active + buffer |
| Sauce stream (`GPUParticles3D`) | 50 | Shared between red / white |
| Topping items (per type) | 15 each | Floor drop + persistence |
| Customer NPC nodes | 5 | 3 active + 2 refill buffer |

### 12.6 EventBus Signals (Authoritative List)

```gdscript
# autoloads/EventBus.gd
signal order_accepted(customer_id: int, recipe: Recipe)
signal order_step_completed(ingredient: StringName, quality: int) # 0=perfect, 1=sloppy
signal order_completed(payment: float, tip: float)
signal order_rejected(food_cost: float)
signal customer_left_angry(penalty: float)
signal balance_changed(new_balance: float, delta: float)
signal upgrade_purchased(upgrade_id: StringName)
signal day_started(day_number: int)
signal day_ended(summary: Dictionary)
signal tutorial_step_advanced(step_index: int)
signal station_locked_attempt(station_id: StringName, reason: String) # for debug overlay
```

### 12.7 Core Signal Flow

```
SnapZone.item_snapped         → TruckStation.on_item_received    → OrderManager.complete_step
OrderManager.step_completed   → ObjectiveHUD.update_pill_state
Bell.rung                     → OrderManager.validate_order
    ├─ (complete)             → EconomyManager.process_payment   → EventBus.order_completed
    └─ (incomplete)           → BellConfirmationPopup.show
            └─ (confirmed)    → EconomyManager.deduct_food_cost   → EventBus.order_rejected
GameManager.day_ended         → EndOfDayScreen.show              → EconomyManager.tally_day
CustomerSpawner               → Customer.set_patience            → PatienceArc.start_drain
PatienceArc.depleted          → Customer.leave_angry             → EconomyManager.apply_penalty
```

### 12.8 Input State Machine

A single `InteractionStateMachine` on the `Player` node routes **all interaction input**. WASD movement is handled separately in `TruckPlayer.gd` and **does not interrupt** any active interaction state — the player can continue squishing, slicing, or timing while walking.

```
IDLE
  └─ (camera raycast enters station Area3D & §5.2 prerequisites met) → HOVER
       └─ (interaction key pressed) → ACTIVE
            ├─ station.interaction_type == INSTANT          → INSTANT_INTERACTION → IDLE
            ├─ station.interaction_type == DISCRETE_COUNTER → COUNTER_INTERACTION → (on N presses) → IDLE
            ├─ station.interaction_type == TAP_ACCUMULATE   → ACCUMULATE_INTERACTION → (0.4s input idle → commit) → IDLE
            └─ station.interaction_type == TIMING           → TIMING_INTERACTION → (on click commit) → IDLE
```

- Each station declares its `interaction_type` as an exported enum and its `interaction_key` as an exported `StringName` (`"interact_e"`, `"interact_f"`, `"interact_lmb"` — defined in the project Input Map).
- Stations **never** check their own input. The state machine owns input context entirely.
- Transition `HOVER → IDLE` fires when the raycast leaves the station Area3D *or* prerequisites become invalid.
- Locked stations (prerequisites unmet) emit `station_locked_attempt` to `EventBus` on key press for debug overlay logging and play the soft buzz SFX.

### 12.9 Web-Safety Rules for Timing Mechanics

- All time-sensitive logic (slice counter, sauce gauge accumulation, sauce idle-commit timer, topping shrinking circle) runs in `_physics_process` — **never** `_process` or `_input` deltas.
- Audio feedback fires **after** visual confirmation; never used as a sync reference.
- All timing windows are **30 % wider** than their native equivalents to compensate for WASM input latency.
- **Week 1 spike (Task 2):** build the shrinking circle as the first standalone test and verify feel in Chrome **before** any other interaction work proceeds.

### 12.10 Save System

- **Format:** Single JSON file at `user://save.json` (maps to `IndexedDB` on web via Godot `FileAccess`).

```json
{
  "current_day": 4,
  "balance": 42.50,
  "upgrades": ["sharper_knife"],
  "stats": {
    "total_orders_completed": 23,
    "total_orders_rejected": 2,
    "total_tips_earned": 12.50,
    "best_day_earnings": 32.00
  }
}
```

- **Auto-save:** Triggers automatically on the end-of-day screen, **before any player input.** `[Save & Exit]` returns to the main menu. Auto-save means tab crashes never cause progress loss.
- **Size budget:** <4 KB. All recipe, upgrade, and pricing data lives in bundled `.tres` Resources — never serialised to the save file.

### 12.11 Developer Debug Overlay

A toggleable in-game overlay surfacing live state for development, tuning, and bug-hunting. **Not shipped to the public build** — gated behind `OS.is_debug_build()` so it cannot toggle on in the released WASM.

#### 12.11.1 Toggle & Layout

- **Hotkey:** `F3` toggles the entire overlay. Toggle state persists across days via `user://debug_prefs.json` (dev-only).
- **Layout:** `CanvasLayer` rendered above the HUD. Top-right column of grouped panels. Semi-transparent dark background (`Color(0, 0, 0, 0.7)`), monospace font, 12 pt.
- **Always-on rendering:** even during modals (popup confirmation, end-of-day screen) so the dev can inspect state during transitions.

#### 12.11.2 Panel Groups

| Panel | Contents |
|---|---|
| **Game State** | Current day number, day phase (`TUTORIAL` / `PLAYING` / `END_OF_DAY`), day timer (live), spawn rate / patience / max-concurrent values from the active difficulty entry. |
| **Economy** | Live bank balance (with delta highlight on change), session totals (orders completed / rejected / tips earned / best day). |
| **Current Order** | Customer ID, full required ingredient list, per-ingredient pill state (`grey` / `pulsing` / `green` / `orange` / `red`), per-ingredient sloppy-flag boolean, total sloppy count, projected tip outcome. |
| **Customer Queue** | One row per active customer: ID, queue slot, accepted state (`waiting` / `accepted` / `cooking`), patience seconds remaining, requested ingredients. |
| **Player & Interaction** | Position (X, Y, Z), camera yaw/pitch, current `InteractionStateMachine` state (`IDLE` / `HOVER` / `ACTIVE`), hovered station ID, raycast hit distance, currently held item, current sequence step (`TORTILLA` / `MEAT` / `TOPPINGS` / `SAUCES` / `BELL`). |
| **Stations** | Per-station status: locked (with reason from §6.8) / unlocked / active. |
| **Object Pools** | Per-pool live count: in-use / available / total. Visible budget overruns highlighted red. |
| **Recent EventBus** | Rolling log of the last 20 EventBus emissions with timestamp, signal name, and arguments. |

#### 12.11.3 Debug Hotkeys (also gated to debug builds)

| Key | Action |
|---|---|
| `F3` | Toggle overlay |
| `F4` | Skip to end-of-day (force `GameManager.day_ended`) |
| `F5` | Spawn one customer immediately |
| `F6` | Add $50 to balance |
| `F7` | Toggle infinite patience (all active customers) |
| `F8` | Print full EventBus log to console |

#### 12.11.4 Implementation Notes

- The overlay is purely a **subscriber** to `EventBus` and a **read-only inspector** of autoload state. It must **never write** to game state except via the explicit hotkeys above.
- Each panel is a separate `Control` scene under `res://ui/debug/`, instantiated once at scene load and held inactive by default.
- The Recent EventBus log uses a fixed-size circular buffer (20 entries) to bound memory.
- The overlay must not affect frame budget when hidden — all per-frame label updates are gated behind `if visible:`.

---

## 13. Art & Tone Direction

### 13.1 Visual Style

Low-poly PS1 aesthetic. Chunky geometry. Unfiltered, low-resolution textures. No anti-aliasing. No bloom. Point filtering on all sprites and textures.

> **Prototype exception:** PS1 retexturing is a **post-prototype** task (Week 4+). The prototype uses Kenney library assets raw and grey-box CSG placeholders where models do not exist. Mechanics ship before aesthetics are refined.

### 13.2 Tone — Cozy-Uncanny

Comfortable and slightly wrong. Twin Peaks undertone: warm but off, familiar but strange. Specific implementations (1–2 days total — biggest tone ROI for minimal budget):

- Customers are slightly too still when waiting; idle animation loops a beat too long.
- The truck radio occasionally plays a few seconds of reversed speech, then returns to normal.
- Ambient crowd noise outside fades correctly except for one laugh that loops slightly out of time.
- The light above the prep counter flickers once per minute for half a second. Then nothing.

### 13.3 Colour Logic

| Zone | Palette | Purpose |
|---|---|---|
| Truck interior | Warm amber + cream | Kitchen comfort, safety |
| Customer queue (through window) | Cooler, slightly desaturated | Outside vs. inside contrast |
| Interaction feedback — perfect | Bright green | Universal positive |
| Interaction feedback — sloppy | Amber / orange | Warning, recoverable |
| Interaction feedback — fail | Red | Stop, wrong, penalty |
| UI elements | White + gold on dark | Legible, slightly luxe |

### 13.4 Asset List (Prototype)

**Environment**
- Truck interior (counter, walls, window, floor)
- Trompo (vertical meat spit with meat block, animated spin)
- Sauce bottles (red and white, distinct shapes; on-counter rest pose + on-screen-left squish pose)
- Topping bins (cilantro, tomato, onion)
- Tortilla stack
- Service bell + adjacent serving-area snap zone
- Wall clock (mirrors day timer)

**Characters**
- Customer base model (Kenney library — low-poly humanoid)
- Patience arc (world-space UI above head)
- Speech bubble (world-space, shows ingredient icons)

**Food Items**
- Tortilla (in-hand and placed states)
- Meat fragment (per-slice particle) + cumulative meat portion (post-3-slices visual)
- Sauce pour (`GPUParticles3D` stream with normal-output and over-spray-output variants)
- Topping items (cilantro, tomato, onion — floor drop state)
- Assembled taco (final served state)

### 13.5 Audio Requirements

**Music**
- Gameplay loop: lo-fi diner jazz with a subtle unsettling undertone. Upbeat enough to maintain rhythm, strange enough to maintain vibe.
- End-of-day screen: slower, contemplative. One instrument drops out.

**SFX**
- Slice (per press): sharp scrape / sizzle.
- Slice complete (3rd press): satisfying thud.
- Sauce squish (per press): wet pump.
- Sauce hum (in green band): soft pleasant tone.
- Sauce warning (in red band): low warning tone.
- Sauce commit — perfect: clean squirt + short positive note.
- Sauce commit — sloppy: splatter + dull note.
- Sauce commit — overfill: heavier splatter + extra burst.
- Topping hit: satisfying thud / crunch.
- Topping miss: drop + floor bounce.
- Locked-station buzz: short soft denial tone.
- Bell ring: clean, bright ding.
- Order complete: warm register chime.
- Order rejected: buzzer + disappointed murmur.
- Customer leaves (patience): door slam + muttering.
- Penalty deduction: brief low tone.

---

## 14. Development Timeline — 12-Task MVP (Authoritative)

### 14.1 Week 1 — Interactions

| # | Task | Type | Acceptance Criterion |
|---|---|---|---|
| 1 | Truck interior scene. Two-sided station layout (front/back). WASD player movement. Mouse-look (yaw 360° unclamped, pitch ±89°). **Strip crouch components from Player node.** Wire **F3 debug overlay** scaffold (Game State + Player & Interaction panels minimum) — used throughout subsequent tasks. | Code | Player walks, looks, collides with walls. F3 toggles overlay showing live position + camera angles. |
| 2 | **SPIKE: Shrinking circle interaction — test on web in Chrome. Verify feel.** | Code | Hit/miss feels fair on web export at 60 FPS. |
| 3 | Tortilla grab (`E` → spawns in right hand) — back counter. | Code | Tortilla persists in hand across walking, until served. |
| 4 | Meat slice (`E` × 3 discrete presses → 3 visible fragments → ingredient complete) — back counter. Counter UI displays `Slices: n/3`. | Code | Each press places one fragment; meat pill turns green on 3rd press. |
| 5 | Sauce tap-accumulate (`F` press to squish, gauge fills incrementally, 0.4 s idle commits, three zones + overfill VFX) — front counter. Bottle animates to/from screen-left. | Code | All four commit outcomes (under / green / red / overfill) demonstrably distinct. Bottle animation completes round-trip. |
| 6 | Topping shrinking circle (`LMB` timing → place or drop) — front counter. Sticky sloppy flag on first miss. | Code | Hit places, miss drops as pooled `RigidBody3D`; retry after miss commits orange pill. |

### 14.2 Week 2 — Loop

| # | Task | Type | Acceptance Criterion |
|---|---|---|---|
| 7 | Bell + order validation (`F` → snap taco to serving area, ring, validate; confirmation popup on incomplete). | Code | Popup blocks until dismissed; correct routing both ways; taco snaps to serving area. |
| 8 | Order system: procedural recipe generation, HUD ingredient pills with state feedback, **strict §5.2 sequence enforcement** with locked-station prompts. | Code | Random orders generate; pills cycle all five states; locked stations buzz on press attempt. |
| 9 | Customer queue: 3 NPCs, `NavigationAgent3D` to `QueueSlots` `Marker3D`s, patience arcs, one-order-at-a-time acceptance. | Code | NPCs spawn, walk to slots, decay patience, leave angry on zero. |
| 10 | `EconomyManager`: all credits/debits, $0 floor, live balance display, soft bail-out. Wire economy panel of debug overlay. | Code | All transactions match §8 tables; balance never negative. |
| 11 | Day timer (5 min), end-of-day screen, basic tally display, auto-save. | Code | Timer auto-ends day; tally shows correct counts; auto-save fires before input. |

### 14.3 Week 3 — Polish & Ship

| # | Task | Type | Acceptance Criterion |
|---|---|---|---|
| 12 | Day 0 tutorial: scripted 5-order sequence, guided prompts, no timer. | Code | All five tutorial orders complete with prompt fades on success. |
| — | Upgrade shop, day loop (next-day load with difficulty schedule), save/load. | Code | Stretch: only if Tasks 1–12 complete. |
| — | Web export. Chrome + Firefox testing. 60 FPS pass. Audio latency verification. **Confirm debug overlay disabled in non-debug builds.** | QA | Locked browser test pass before ship. |
| — | Kenney asset swap (replace grey CSG boxes where models exist). Placeholder audio (beeps). | Art / Audio | One-pass swap; no custom retex. |

### 14.4 Art Strategy

All art is placeholder for the 3-week prototype. Grey-box CSG labelled objects where models don't exist. Kenney library assets used raw, no PS1 retexture. One customer NPC model from Kenney, idle animation only. PS1 aesthetic and custom assets are a post-prototype pass.

### 14.5 Stretch Goals (Only If MVP Locks Early)

| # | Feature | Type |
|---|---|---|
| S1 | Customer archetypes (Picky / Chill) | Code |
| S2 | Particle polish — sauce stream, meat fall, topping drop | Art / Code |
| S3 | Second truck type (Shawarma or Burger) | Code / Art |
| S4 | Driving / travel screen between locations | Code |
| S5 | Narrative layer — mid-life crisis story beats between days | Code |
| S6 | Additional upgrades (topping timing assist, patience extender) | Code |

---

## 15. Out of Scope (Prototype)

| Feature | Status |
|---|---|
| Driving / third-person vehicle mode | Post-prototype |
| City map / location selection | Post-prototype |
| Multiple truck types | Post-prototype |
| PS1 retexture / custom art pass | Post-prototype (Week 4+) |
| Customer archetypes (Picky / Chill) | Stretch goal |
| Particle system polish | Stretch goal |
| Narrative / story beats between days | Post-prototype |
| Mobile / controller / touch input | Out of scope |
| Soundtrack (original music) | Post-prototype |
| Customer dialogue | Post-prototype |
| Crouch / jump | Out of scope (removed in v3.1) |

---

## 16. Glossary

| Term | Meaning |
|---|---|
| **Pill** | A single ingredient indicator in the top-right Order HUD panel. |
| **Sloppy flag** | A per-order quality flag set by an over-pour, overfill, or a topping miss. **Sticky** for toppings. |
| **Triage** | Choosing which queued customer to serve first; the game's primary strategic decision. |
| **Snap zone** | An `Area3D` that captures a held item into a fixed transform on a defined event. |
| **Trompo** | The vertical al pastor meat spit; the back-counter meat station. Requires 3 discrete `E` presses. |
| **Tap-accumulate** | The sauce mechanic: repeated `F` presses pump the gauge incrementally; commit after 0.4 s of input idle. |
| **Overfill / over-spray** | Sauce gauge held to the max — extra GPU particle output, mechanically equal to red-zone sloppy. |
| **Shrinking circle** | The topping-placement timing mini-game. |
| **Bail-out customer** | The diegetic +$2.00 hand-out at the start of a day after a $0 finish. |
| **Sequence lock** | A station rejecting input because §5.2 prerequisites are not met. |
| **Debug overlay** | The `F3`-toggleable developer inspector — see §12.11. |

---

*End of Master GDD v3.1. All implementation tasks should reference this document by section number. v3.0's open-questions section is removed; resolved decisions are captured in §0.1.*
