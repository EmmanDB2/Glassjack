# Glassjack

A cozy blackjack game for iOS, built in SwiftUI on iOS 26's Liquid Glass.

No timers, no streak pressure, no dark patterns. The table is a slab of glass with
the house rules printed on it, the chips are glass beads, and the room's light
follows your clock.

## Requirements

| | |
|---|---|
| Xcode | 26 or later |
| iOS | 26.0 (deployment target) |
| Swift | 6.0, strict concurrency |
| Bundle id | `com.emmanuelwalters.Glassjack` |

No third-party dependencies.

> **The Xcode project is not in this repository.** `Glassjack.xcodeproj` sits one
> directory above this folder, so a checkout of this repo alone will not build.
> See [Repository layout](#repository-layout).

## Running it

Open `Glassjack.xcodeproj` (in the parent directory) and run. Or from the command
line, from the directory that contains the project:

```bash
xcodebuild -project Glassjack.xcodeproj -target Glassjack -sdk iphonesimulator -configuration Debug build
```

Multiplayer needs two devices on the same Wi-Fi. Two simulators on one Mac work.

## How it is put together

Everything that decides how the game plays or looks lives in `Config/`. No engine
code knows a literal payout, deck count, betting limit or colour.

```
TablePreset  ─┬─  GameConfig   rules: payouts, limits, decks, dealer behaviour
              └─  ThemeConfig  look: colours, chips, card backs, glass tints
```

Swapping the active `TablePreset` re-skins the whole app *and* changes how the game
plays, in one assignment. Adding a table is a new `TablePreset` — no new views.

```
Config/       GameConfig, ThemeConfig, TablePreset
Models/       Cards, hands, the shoe, outcomes
ViewModels/   BlackjackGame — the engine and all game state
Services/     Persistence, unlocks, haptics, audio, dynamic lighting
Views/        Screens and the glass component kit
Multiplayer/  Shared tables over MultipeerConnectivity
Sounds/       Music and effects
```

`BlackjackGame` is the single source of truth for a round. Views read from it and
call into it; none of them hold game state.

## What is in it

**Five tables.** Casino Floor, High Roller Room, Midnight, Morning Café and
Fractured. Each carries its own rules *and* its own look, and each unlocks a
different way — a balance, an hour of the day, a daily streak.

**Fractured** runs off a separate session stack that never touches your balance,
with rule modifiers and wild cards you pick before sitting down. Nothing carries
over in either direction.

**The Game Room** is the progression. No XP bars and no levels — playing quietly
fills out a room with card backs, chip sets, felts and decor. Things appear on the
shelf; nothing nags you about them.

**Multiplayer** seats up to four people on one shared table over
MultipeerConnectivity, no server and no account. The host advertises a
six-character room code and deals; everyone else sends intents and renders what
comes back. Two rules shape the implementation:

- *Hands stay private.* The host redacts every snapshot per recipient, so another
  player's cards are genuinely absent from the wire until the round resolves —
  not merely undrawn.
- *Balances never leave the device.* Only the stake and the hand state sync. Each
  player debits and credits their own bankroll locally.

`MultiplayerTransport` is a protocol, so a server-backed transport could replace
the peer-to-peer one without touching anything above it.

**Dynamic lighting** recomputes the specular highlight and ambient tint from the
device clock, so the glass warms and cools through the day.

## Performance

Liquid Glass is expensive, and a table's worth of it is more expensive still. Two
rules keep it in hand:

- Every glass surface goes through `glassSurface` / `glassFelt` rather than calling
  `glassEffect` directly, so all of it degrades to a flat translucent surface in one
  place when full blur is off.
- The table slab uses the *clear* glass variant. At half the screen, `.regular`
  frosts the entire room — the dark tables especially — into milky grey.

Full blur is a setting, and defaults off on devices that report fewer than 6 cores
or under 4 GB of memory.

## Repository layout

This repository's root is the `Glassjack/` **source folder**. The Xcode project is
its sibling on disk, outside the repo:

```
IdeaProjects/Glassjack/
├── Glassjack.xcodeproj      ← not tracked
└── Glassjack/               ← this repository's root
    ├── Config/  Models/  ViewModels/  Services/  Views/  Multiplayer/  Sounds/
    ├── GlassjackApp.swift
    └── Info.plist
```

Two consequences worth knowing before you contribute:

1. **A fresh clone will not build**, because there is no project file in it.
2. **New source files must be added to the Xcode target by hand.** The project uses
   explicit file references rather than synchronized groups, and that registration
   lives in the untracked `project.pbxproj` — so adding a `.swift` file here is not
   enough to get it compiled on anyone else's machine.

Moving the repository root up one level would fix both. Until then, new files need
a matching project change passed along out of band.
