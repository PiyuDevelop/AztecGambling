# Cleanup and UI Redesign Plan

What comes after [testing-plan.md](testing-plan.md), in two parts:

- **Part A — Bugs and bad practices:** fix the known bugs and clean up the game logic, with the tests as a safety net.
- **Part B — UI redesign:** rebuild every window with native frames and one shared visual style, inspired by the EnhanceQoL addon.

Part A comes first. The redesign builds on logic that already works and is already separated from the UI. Nothing here is implemented yet.

Written against commit `68c327a`. Line numbers refer to that commit and may shift as the code changes. The bug numbers (#1 to #8) are the ones in [improvements.md](improvements.md), which has the full description of each.

## Before You Start

- [x] **The testing plan is done:** the tests run locally and in CI, and every known bug that can be reproduced outside the game is a `known_bug` test.
- [ ] **Link the repo into the game,** so each change can be tested with `/reload`. Move the installed copy out of `<WoW>\_retail_\Interface\AddOns\AztecGambling`, then replace it with a directory junction to the repo:
  ```
  mklink /J "<WoW>\_retail_\Interface\AddOns\AztecGambling" "C:\repos\WoWAddons\AztecGambling"
  ```
  Lua changes only need `/reload`. **Adding files to a `.toc` needs a full game restart.**
- [ ] **Turn on Lua error reporting** with `/console scriptErrors 1`, or install BugSack.

### Branches
- **Part A** goes on a branch from `main`, merged back in small pull requests, so fixes reach a release without waiting for the redesign.
- **Part B** goes on `ui-redesign`. Merge `main` into it once Part A is in.

---

# Part A — Bugs and Bad Practices

## A1. Bug Fixes, Test First

For each bug:
1. Turn its `known_bug(...)` test into an `it(...)` and watch it fail.
2. Fix the code.
3. Watch the test pass.
4. Check it once in-game with the current UI.

CI checks that every remaining `known_bug` test still fails, so a bug fixed without turning its test on is caught.

Suggested order:

- [ ] **#3 Rolls aren't detected in other languages.** The most useful fix for Spanish-speaking players.
  - Build the roll pattern from the `RANDOM_ROLL_RESULT` global string instead of reading words by position ([AztecGambling.lua:1100](../AztecGambling.lua#L1100)), and handle positional arguments (`%1$s`).
  - Test with the English and Spanish strings.
- [ ] **#2 Yahtzee scoring is wrong.**
  - Score by category first (Yahtzee > four-of-a-kind > full house > three-of-a-kind > pair > high card), then by digit within a category.
  - Decide whether a 0 counts as 0 or 10.
- [ ] **#6 The gold amount isn't validated.** Reject 0 and non-numbers, and tell the host with `self:Print` instead of silently using 100.
- [ ] **#1 The Trade button fails without a game.**
  - Check there's a game with a winner.
  - If you are the winner, trade with the loser instead.
  - The host and the companion window each have their own copy of this function ([AztecGambling.lua:1268](../AztecGambling.lua#L1268), [AGClient.lua:166](../AGClient.lua#L166)). Merge them into one shared function.
- [ ] **#8 Leaked globals.** Add `local` where needed, and remove each name from `KNOWN_LEAKS` in `globals_spec.lua` until it's empty. `scripts/lint.ps1` also lists the leaks in code the tests never run, such as `winner`, `loser` and `cash_winnings` in the dead `GameResultsCallback`.
- [ ] **New: the roll time limit doesn't match the README.** The code gives 45 seconds ([AztecGambling.lua:9](../AztecGambling.lua#L9)); the README says "1 minute" and "60 seconds". Decide which is right and update the other.
- [ ] **#4 Say mode outside instances.** It can't be tested outside the game: confirm it in-game first, then decide on the fix described in improvements.md.
- [ ] **#9 An empty message is sent to chat when rolls start.** Remove `roll_msg` from `StartRolls`. Found by the tests.
- [ ] **#10 Rolls from players on another realm may be ignored.** Confirm it in-game with a player from a connected realm. If confirmed, run the roll message's name through `Ambiguate`, and add a test with a `Name-Realm` roll.
- [ ] **#11 After a Blackjack tie, the companion window rolls the wrong range.** Send the 1-21 range to the companion windows when the tiebreaker deals again. Found by the tests.
- [ ] **#13 Changing the chat channel during a round** breaks joining in the new channel and leaves the host listening to the old one for good. Simplest fix: don't allow the change while a round is open. Found by the tests.
- [ ] **#14 Status names both Countdown players on the first turn.** Found by the tests.

## A2. Developer Test Command

- [ ] **`/ag test`** adds fake players to the current round and rolls for them, so a full round can be played in-game alone. This is the *Developer test command* item in improvements.md. Part B needs it too, for example to see Roll Status with 20 players.
- [ ] Make it available only when debug mode is on (`/ag debug`), so players don't stumble on it.

## A3. Separate the Game Logic from the UI

Today the game logic calls the UI directly: `UpdateRollStatusUI()` is called from 14 places ([AztecGambling.lua:333](../AztecGambling.lua#L333), [AztecGambling.lua:1136](../AztecGambling.lua#L1136), and others). The logic also reads from the UI and writes to it:

- `SetGoldAmount` reads the bet from the edit box ([AztecGambling.lua:865](../AztecGambling.lua#L865));
- `SetChatChannel`, `SetGameMode` and `SetGameStage` fill the dropdowns and the stage button ([AztecGambling.lua:81-180](../AztecGambling.lua#L81-L180)).

This step changes where code lives, not how the game plays. **Every existing test has to keep passing.**

- [ ] **Internal messages.** The logic announces what happened with AceEvent's `SendMessage`, and the UI listens with `RegisterMessage`:

  | Message | Arguments | Sent when |
  |---|---|---|
  | `AG_GAME_STARTED` | mode, roll range, bet | Entries open |
  | `AG_PLAYER_JOINED` | player | A player types `1` |
  | `AG_ROLL_PHASE_STARTED` | seconds | A timed roll phase begins |
  | `AG_ROLL_RECORDED` | player, roll | A valid roll, a Blackjack hit or a stand |
  | `AG_STAGE_CHANGED` | stage | The stage button changes |
  | `AG_GAME_ENDED` | winner, loser, amount | The round is settled |
  | `AG_GAME_RESET` | — | Reset or a cancelled round |

  ```lua
  -- Game logic
  self:SendMessage("AG_ROLL_RECORDED", player, roll)

  -- UI module
  function RollStatus:OnEnable()
      self:RegisterMessage("AG_ROLL_RECORDED", "Refresh")
  end
  ```
- [ ] **The logic stops reading the UI.** The UI passes the bet, the channel and the mode as arguments, for example `StartGame(bet)`. The logic stops filling the dropdowns itself.
- [ ] **Move the current UI code (still AceGUI) into modules** (`AztecGambling:NewModule(...)`) that listen to the internal messages. Part B later replaces each module's inside without touching the logic.
- [ ] **Update the tests.**
  - Check the internal messages instead of calls on the UI stand-in.
  - The logic no longer calls the UI, so `ui_stub.lua` should be needed only for the tests that load the windows.
- [ ] **Fix the overwritten `PLAYER_LEAVING_WORLD` handler** (bug #12 in improvements.md, with a `known_bug` test in `slash_spec.lua`).
  - [AztecGambling.lua:1485](../AztecGambling.lua#L1485) registers it to save the window position.
  - [AGCommon.lua:75](../AGCommon.lua#L75) registers it on the same object to leave the custom channel.
  - AceEvent keeps one handler per event per object, so after `/ag join` the position stops being saved.
- [ ] **#5 Reset notifies players.** Add an addon message that clears the round in the companion window. Also send `AG_GAME_RESET`, so Roll Status closes as it does at the end of a round.
- [ ] **#7 The custom channel.** Decide whether to keep it.
  - If kept, show it in the dropdown while you're in the channel, and only leave it on `PLAYER_LOGOUT`.
  - If not, remove `/ag join` and `/ag leave`.

## A4. General Cleanup

- [ ] **`AGClient` depends on `AztecGambling`** for `PrintDebug`, `SplitString` and `db.global.custom_channel`. Move the shared helpers into a common module that both use.
- [ ] **Remove the unused libraries.**
  - `AceHook` and `AceSerializer` are listed in both `NewAddon` calls ([AztecGambling.lua:2](../AztecGambling.lua#L2), [AGClient.lua:3](../AGClient.lua#L3)) but never used.
  - `AceConfig`, `AceDBOptions`, `AceTab` and `AceBucket` are loaded by the `.toc` files but never used.
- [ ] **Build `GAME_MODES` and `GAME_STAGES` once.** Today they're rebuilt (and leak as globals) every time `SetGameMode` and `SetGameStage` run ([AztecGambling.lua:143](../AztecGambling.lua#L143), [AztecGambling.lua:168](../AztecGambling.lua#L168)).
- [ ] **Remove dead code:**
  - `AG_MYSTERY` ([AGGameModes.lua:38](../AGGameModes.lua#L38));
  - the unused `total_rolls` ([AztecGambling.lua:889](../AztecGambling.lua#L889));
  - `AztecGambling:GameResultsCallback` ([AztecGambling.lua:815](../AztecGambling.lua#L815)), which nothing registers. Only the companion window's own version is used;
  - `PrintBanlist` ([AztecGambling.lua:1212](../AztecGambling.lua#L1212)), which no command calls, and `PrintTable` ([AGUtils.lua:27](../AGUtils.lua#L27));
  - the second copy of the block that saves the payout rolls in `EvaluateScores` ([AztecGambling.lua:945](../AztecGambling.lua#L945)), which repeats the one at [AztecGambling.lua:930](../AztecGambling.lua#L930);
  - the empty `if` branches in `EvaluateScores` that luacheck reports.

  The test coverage report (`scripts/coverage.ps1`) shows these as lines that never run.
- [ ] **Clear the rest of luacheck's warnings** (`scripts/lint.ps1`): unused variables, and the loop variable `digit` reused inside its own loop in Yahtzee's scoring.
- [ ] **Fix `self.game.accepting_rolls = false`** in `CheckRollsComplete` ([AztecGambling.lua:450](../AztecGambling.lua#L450)). It should be `self.game.data.accepting_rolls`. Today it creates a field nobody reads, so the round keeps accepting rolls after everyone has rolled. Nothing visible breaks, because the chat events are unregistered right after.
- [ ] **Replace `table.getn(t)` with `#t`.**

## Part A Done When

- [ ] Every `known_bug` test is an `it` and passing, except the bugs that need an in-game check first.
- [ ] `KNOWN_LEAKS` in `globals_spec.lua` is empty.
- [ ] `scripts/lint.ps1` reports no warnings for the addon. Then make CI's *Lint the addon* step blocking, by removing its `continue-on-error`.
- [ ] The game logic doesn't call or read any window.
- [ ] A round of every mode plays the same in-game as before.
- [ ] The fixes are merged into `main` and released.

---

# Part B — UI Redesign

## B0. Goals and Reference

- **A modern, consistent look:** every window shares one visual style.
- **Light and under our control:** no heavy libraries; we write only the widgets the addon needs.
- **Inspired by EnhanceQoL, not copied from it.**

### What EnhanceQoL does

The version studied is **13.5.2**, installed from CurseForge/Wago. Its source can be read in `Interface\AddOns\EnhanceQoL`. An older fork (5.1.1) that used AceGUI and a `TreeGroup` was reviewed first; the current version no longer works that way.

- **It no longer uses AceAddon, AceDB, AceEvent or AceGUI.** Windows are built with two in-house libraries: `LibSettingsDesigner` (settings, about 12,000 lines) and a library for Blizzard's Edit Mode (about 5,000 lines).
- **Its panels use Blizzard's tooltip textures** (`Interface\Tooltips\UI-Tooltip-Background` and `UI-Tooltip-Border`) through `BackdropTemplate`, recolored with `SetBackdropColor` and `SetBackdropBorderColor`.
- **Every color is defined once, with a name,** in a palette with normal, hover, selected and disabled states (`libs/LibSettingsDesigner/LibSettingsDesignerUI.lua`, around line 676). It uses near-black backgrounds, semi-transparent gold borders, and gold as the accent.
- **Most-used Blizzard APIs** (across all its modules): `BackdropTemplate` (212 uses), `SetAtlas` (187), `StaticPopup_Show` (107), `UIPanelButtonTemplate` (92), class colors (89), `GameTooltip` (82), `MenuUtil` (77) and animation groups (32).
- **Every optional API is checked before use,** for example `if not MenuUtil then return end`.

### Problems the redesign removes
- **Roll Status rebuilds itself on every roll**, and its height is fixed at twice the casino window's ([AztecGambling.lua:1045](../AztecGambling.lua#L1045)).
- **Wrong color and font use.**
  - `label:SetColor(255, 255, 0)` only works because the values get clamped: AceGUI expects 0-1 ([AztecGambling.lua:1085](../AztecGambling.lua#L1085)).
  - The hardcoded `Fonts\FRIZQT__.TTF` can't display Russian, Korean or Chinese characters ([AztecGambling.lua:1084](../AztecGambling.lua#L1084)).
- **Invisible buttons are used as spacers** to center each row ([AztecGambling.lua:1393](../AztecGambling.lua#L1393)).
- **Window positions are copied on every loading screen** with `CopyTable`.
- **No options window,** and the minimap button cycles companion window → casino → hidden.
- **Windows don't close with Escape** and can be dragged off screen.

## B1. Libraries and Native APIs

### Libraries
| Library | Decision |
|---|---|
| AceAddon, AceConsole, AceTimer, AceComm, AceDB, AceEvent | **Keep.** |
| AceLocale | **Start using** for the translation (B7). |
| AceGUI | **Replace** with native frames; remove it at the end of B5. |
| LibDBIcon + LibDataBroker | **Keep.** |
| LibSettingsDesigner, EnhanceQoL's Edit Mode library | **Don't use.** They have their own license, target Retail, and are far larger (12,000 and 5,000 lines) than all of Aztec Gambling (about 2,700). |
| LibSharedMedia, LibCustomGlow, LibDeflate | **Not needed.** |

### Native Blizzard APIs
**Use.** These should exist on both Retail and Classic Era, but Classic still needs an in-game test.
- **`BackdropTemplate` with the tooltip textures**, recolored from our palette. This is the base of the whole style.
- **`StatusBar` rows**, created once and reused by index.
- **`UIPanelCloseButton`**, **`InputBoxTemplate`** and **`GameTooltip`**.
- **`StaticPopupDialogs`** for confirmations.
- **`RAID_CLASS_COLORS`** for player names.
- **`AnimationGroup`** to highlight the winner.
- **`UISpecialFrames`** so windows close with Escape (it needs named frames), and **`SetClampedToScreen`** so they can't be dragged off screen.
- **`CreateFont`**, based on Blizzard's fonts so text works in every client language.
- **`UIPanelScrollFrameTemplate`** for the stats and ban lists.

**Use only when present:**
- **`MenuUtil`** for dropdowns, with a fallback for Classic.
- **The Blizzard settings panel entry** (`Settings.RegisterCanvasLayoutCategory`).
- **The addon compartment** (`AddonCompartmentFrame`).
- **`## IconTexture`** in the `.toc`.

**Don't use:**
- **Edit Mode:** the casino window is a dialog, not a HUD element.
- **ScrollBox:** our lists don't need it.
- **`SetAtlas`:** atlas names change between game versions. Use `Interface\Icons\...` textures.

## B2. New Code

```
AztecGambling/
├── AGUI/
│   ├── Theme.lua        -- color palette, backdrop styles, font objects
│   ├── Widgets.lua      -- window, button, edit box, dropdown, sidebar, bar row, countdown bar
│   ├── RollStatus.lua   -- Roll Status panel
│   ├── Client.lua       -- companion window
│   ├── Casino.lua       -- casino window
│   ├── Options.lua      -- options window with the sidebar
│   └── Popups.lua       -- StaticPopupDialogs
└── ...
```

- Each window is one of the AceAddon modules created in A3.
- List the new files in all three `.toc` files.
- **Add `AGUI` to the `cp` line in [release.yml](../.github/workflows/release.yml)**, or the release zips won't include it and the addon won't load.

### Theme
Our own palette. The dark background with gold follows EnhanceQoL and suits "Aztec"; jade marks a win and red a loss.

```lua
AGUI.Theme.colors = {
    windowBg     = { 0.04, 0.045, 0.05, 0.95 },
    border       = { 0.62, 0.52, 0.32, 0.60 },
    borderHover  = { 0.95, 0.72, 0.30, 0.80 },
    rowBg        = { 0.06, 0.065, 0.07, 0.50 },
    rowHoverBg   = { 0.13, 0.10, 0.05, 0.60 },
    text         = { 0.94, 0.91, 0.84, 1 },
    textMuted    = { 0.70, 0.67, 0.60, 1 },
    textDisabled = { 0.38, 0.36, 0.33, 1 },
    accent       = { 1.00, 0.82, 0.36, 1 },  -- gold
    win          = { 0.27, 0.78, 0.62, 1 },  -- jade
    lose         = { 0.85, 0.30, 0.25, 1 },  -- red
}

function AGUI.Theme.ApplyBackdrop(frame, bgKey, borderKey)
    frame:SetBackdrop(AGUI.Theme.backdrop)  -- tooltip background + border textures
    frame:SetBackdropColor(unpack(AGUI.Theme.colors[bgKey]))
    frame:SetBackdropBorderColor(unpack(AGUI.Theme.colors[borderKey]))
end
```

## B3. Windows

```
Casino (compact, for playing)          Options (opens from the gear)
┌──────────────────────────── ⚙ ✕ ┐    ┌─────────────────────────────────────── ✕ ┐
│ [Enter]   [Roll!]   [Trade]      │    │ General     │                            │
│ ┌ Casino ──────────────────────┐ │    │ Statistics  │   selected page            │
│ │ [ 500g ] [Party ▾] [HiLo ▾]  │ │    │ Bans        │                            │
│ │ [New Game] [Reset] [PAY!]    │ │    │ Commands    │                            │
│ └──────────────────────────────┘ │    │             │                            │
│ Rolling ▓▓▓▓▓▓▓▓░░░░░░░░   32s   │    │             │                            │
└──────────────────────────────────┘    └─────────────┴────────────────────────────┘
```

- **Casino:** stays compact, with the same controls as today, plus a gear button in the title bar that opens Options.
- **Roll Status:** a panel docked to the casino window.
  - One bar per player: class-colored name, the roll formatted with the mode's `fmt_score`, and a fill showing how far the roll is along the range.
  - Players who haven't rolled show in grey; when the round ends, the winner shows in jade and the loser in red.
  - Each mode can define an optional `bar_fraction(roll, data)` in [AGGameModes.lua](../AGGameModes.lua): Blackjack uses `total / 21`, and Yahtzee hides the fill.
- **Companion window:**
  - Compact, with the round info in the header ("HiLo · (1-500) · 500g") and the roll countdown bar.
  - **Hit** and **Stand** buttons appear only in Blackjack.
  - A gear button opens Options on the General page.
- **Options:** a separate window (about 600x420) with a sidebar.
  - **General:** auto-show the companion window, show the minimap button, default chat channel, default game mode.
  - **Statistics:** the Hall of Fame and Hall of Shame as private tables, with *Announce in chat* and *Reset stats* (with confirmation) buttons.
  - **Bans:** the banned players, each with a *Remove* button, plus a field and button to add a player.
  - **Commands:** the list of `/ag` commands.
- **Ways to open Options:**
  - the gear buttons;
  - right click on the minimap button (left click toggles the casino);
  - `/ag config`;
  - the *Open* button in Blizzard's *Options → AddOns*;
  - the addon compartment.
- **Future:** if the game modes get their own pages (rules and settings per mode), the sidebar can grow into a tree with a *Game Modes* group. Build it so a second level can be added without a rewrite.

## B4. Phases

### Phase 1: Visual foundation
- [ ] Create `AGUI/Theme.lua` and `AGUI/Widgets.lua`.
- [ ] Rebuild the `RollCountdown` widget ([AztecGambling.lua:1488](../AztecGambling.lua#L1488)) as a native frame.
- [ ] Add `## IconTexture` to the `.toc` files.

### Phase 2: Roll Status
- [ ] Build the native Roll Status panel described in *Windows*.
- [ ] Remove the old AceGUI version ([AztecGambling.lua:1045-1097](../AztecGambling.lua#L1045-L1097)).

### Phase 3: Companion window
- [ ] **Send the game mode** as a fifth field of `AG_NEW_GAME` ([AztecGambling.lua:244](../AztecGambling.lua#L244)). Older clients only read the first four fields; new clients must handle the field missing from older hosts.
- [ ] **Add a new addon message for the start of the roll phase,** so the companion window can show the countdown.
- [ ] **Add the Hit and Stand buttons.** They send `hit` or `stand` in the game's chat channel, which the host already parses.
- [ ] **Tests:** extend `protocol_spec.lua` with the new field and the new message.

### Phase 4: Casino window
- [ ] Rebuild it as a native frame, with the dropdown wrapper and the gear button.
- [ ] **Remove AceGUI** from the `.toc` files.

### Phase 5: Options window
- [ ] Build the window with the sidebar and its four pages.
- [ ] Add confirmations for `resetStats`, `resetBans`, and Reset during a live round.
- [ ] Add every way to open it, and update the README.

### Phase 6: Translation
- [ ] Add AceLocale with `enUS`, `esES` and `esMX`. Convert the new windows first, then [AGMessages.lua](../AGMessages.lua).
- [ ] Keep the chat keywords (`1`, `hit`, `stand`) the same in every language, because the host parses them.

## B5. Open Decisions

- **Classic Era support:** only Retail is installed for testing. Should the Classic Era build be kept as best effort (with API checks and no in-game testing), or should Aztec Gambling become Retail-only?

## B6. In-Game Testing Checklist

- [ ] Windows keep their position after `/reload`, after logging out, and after `/ag join`.
- [ ] Escape closes the windows, and they can't be dragged off screen.
- [ ] Roll Status with 2 players and with 20 or more (use `/ag test`): height, sorting, and rows left over from a bigger round.
- [ ] Roll Status in Blackjack (running totals), Countdown (turns) and Yahtzee (no fill).
- [ ] In Say, players outside your group show in the default color.
- [ ] A new companion window against an older host, and the other way around.
- [ ] Every way of opening Options works, and each page saves its changes.
- [ ] If Classic is kept: the Classic Era client loads with no Lua errors.
