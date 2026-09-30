# Testing Plan

A plan for adding automated tests that run outside the game. This is the first step, before fixing bugs or rebuilding the UI (see [cleanup-and-ui-plan.md](cleanup-and-ui-plan.md)). It expands the *Automated tests outside the game* item in [improvements.md](improvements.md). Nothing here is implemented yet.

Written against commit `68c327a`. Line numbers refer to that commit and may shift as the code changes.

## 1. Why Tests Come First

- **Safe refactoring.** The next plan moves UI calls out of the game logic. Tests that play whole rounds and check what gets announced in chat show right away if that change broke anything. Without them, every game mode has to be replayed by hand in-game.
- **Bugs fixed test-first.** Most bugs in [improvements.md](improvements.md) can be reproduced by a test before they're fixed: Yahtzee scoring (#2), rolls in other languages (#3), gold validation (#6), the Trade button (#1) and leaked globals (#8).
- **A record of the rules.** The tests describe how each mode, tiebreaker and timeout should behave, next to the code.

## 2. Scope

**Covered:**
- **Helper functions:** splitting text, sorting players by roll, and counting and copying tables.
- **Game mode rules:** roll ranges, scoring, winner and loser order, and payout.
- **Full rounds:** players joining, the Last Call countdown, rolls, tiebreakers, the roll time limit, results, and the rankings saved.
- **What gets announced:** chat messages, and addon messages to the companion window (`AG_NEW_GAME`, `AG_END_GAME`, `AG_TURN_UPDATE`).
- **The companion window's logic:** reading the host's messages and the round info it shows.
- **Host and companion together:** a fake network carries the host's addon messages to the companion.
- **Slash commands:** `ban`, `unban`, `resetStats`, `resetBans` and `auto`.
- **Globals:** no new global variables leak.

**Not covered** (still needs in-game testing):
- How the windows look and respond to clicks.
- Blizzard's restrictions, such as automatic messages in Say outside instances ([improvements.md](improvements.md), bug #4).
- The real chat and addon message delivery between players.
- The exact `/roll` text of each client language. The tests can use it once it's copied from the game (see Milestone 4).

## 3. Rules for This Phase

- **The addon's code doesn't change.** The tests describe the current behavior.
- **Tests never lock in a bug.** When a test finds a bug, add it to [improvements.md](improvements.md) and write the test for the *correct* behavior as `pending("bug #N")`. It shows up in the report without failing the run, and it gets turned on when the bug is fixed.
- **Every test starts clean:** fresh addon, fresh database, clock at zero, empty message logs.
- **Work on a branch from `main`** (for example `tests`) and merge it before starting the next plan, so the bug fixes branch already has the tests.

## 4. Tools

| Tool | Why |
|---|---|
| **Lua 5.1** | The Lua version WoW uses. Lua 5.4, which `winget` installs, doesn't work: the addon calls `table.getn`, which was removed after 5.1. |
| **[busted](https://lunarmodules.github.io/busted/)** | The usual Lua test framework: `describe`/`it`, assertions, `pending`, stubs and spies. |
| **Docker** | Runs Lua 5.1 and busted without installing anything on Windows, and uses the same environment locally and in CI. Docker Desktop is already installed and has to be running. |
| **GitHub Actions** | Runs the tests on every push and pull request. |

## 5. Files

```
AztecGambling/
├── .busted                  -- busted configuration
├── spec/
│   ├── Dockerfile           -- Lua 5.1 + busted image
│   ├── support/
│   │   ├── clock.lua        -- fake clock and timer queue
│   │   ├── wow_api.lua      -- WoW API stubs
│   │   ├── ace_stubs.lua    -- LibStub and minimal Ace3 / LibDBIcon stand-ins
│   │   ├── ui_stub.lua      -- stand-in object for AceGUI widgets
│   │   ├── loader.lua       -- loads the addon files in .toc order and initializes them
│   │   └── helpers.lua      -- actions (join, roll, wait) and log queries
│   └── *_spec.lua           -- the tests
├── scripts/
│   └── test.ps1             -- builds the image and runs the tests from Windows
└── .github/workflows/
    └── tests.yml            -- CI
```

- **`spec/` never goes into the release zip.** [release.yml](../.github/workflows/release.yml) only copies the `.toc`, `*.lua`, `libs` and `LICENSE`.
- **Add `spec/**`, `scripts/**`, `.busted` and `.github/workflows/tests.yml` to the `paths-ignore` list in `release.yml`.** Otherwise, a push that only changes tests creates a new release.

## 6. The Test Environment

### What the addon calls

Measured at commit `68c327a`:

- **WoW API:**
  - chat: `SendChatMessage`, `SendSystemMessage`;
  - rolls and trades: `RandomRoll`, `InitiateTrade`;
  - time: `GetTime`;
  - player and guild: `UnitName`, `Ambiguate`, `GetGuildInfo`;
  - the custom channel: `GetChannelName`, `LeaveChannelByName`, `SlashCmdList["JOIN"]`;
  - frames: `CreateFrame`, `UIParent`.
- **Ace3 (all through `self:`):**
  - events: `RegisterEvent`, `UnregisterEvent`;
  - addon messages: `RegisterComm`, `SendCommMessage`;
  - timers: `ScheduleTimer`, `ScheduleRepeatingTimer`, `CancelTimer`, `CancelAllTimers`;
  - console: `Print`, `RegisterChatCommand`;
  - plus `AceDB:New`, `AceGUI:Create` and `LibDBIcon:Register`.
- **Randomness:** only Curling's hidden target (`math.random`, [AGGameModes.lua:306](../AGGameModes.lua#L306)).

### Stand-ins

The real Ace3 isn't loaded: it needs too much of the game client. These stand-ins mimic only what the addon uses, including **how callbacks are called**, because the addon reads their arguments by position.

- **Events** (`RegisterEvent`): a handler given as a function is called as `handler(event, ...)`, and one given as a method name as `self[method](self, event, ...)`. For example, `ChatChannelCallback` reads the message as `select(2, ...)` and the sender as `select(3, ...)`. Registering the same event twice on the same object replaces the first handler, as AceEvent does.
- **Addon messages** (`RegisterComm` / `SendCommMessage`): the callback gets `(prefix, message, distribution, sender)`. Sent messages are recorded.
- **Timers:** each timer is queued with its due time on the fake clock. `advance(seconds)` runs the due timers in order, including repeating ones, and `CancelTimer` removes them.
- **AceDB:** `New(name, defaults)` returns an object whose `global` is a deep copy of `defaults.global`.
- **AceConsole:** `Print` is recorded, so tests can check what the host sees.
- **AceGUI** (`ui_stub.lua`): `Create` returns an object that accepts any method call or field, including nested ones such as `widget.frame:SetAlpha(1)`, and returns `nil`. Tests can override single methods when the logic reads from the UI. For example, `SetGoldAmount` reads the bet from `ui.gold_amount_entry:GetText()` ([AztecGambling.lua:865](../AztecGambling.lua#L865)), so a helper replaces `GetText`.
- **WoW API:**
  - `SendChatMessage`, `SendSystemMessage`, `RandomRoll` and `InitiateTrade` are recorded.
  - `GetTime` reads the fake clock.
  - `UnitName("player")` returns a configurable host name.
  - `Ambiguate` removes the realm.
  - `CreateFrame` returns the same stand-in object as AceGUI.
- **Randomness:** tests that need a fixed Curling target stub `math.random`.

### Loader
`loader.lua` installs the stand-ins, then loads the addon files in the same order as `AztecGambling.toc`: `AGMessages.lua`, `AztecGambling.lua`, `AGUtils.lua`, `AGGameModes.lua`, `AGClient.lua`, `AGCommon.lua`. Finally it calls `OnInitialize` on `AztecGambling` and `AGClient`, as the game does on `ADDON_LOADED`. Every test calls it in `before_each`, so each test starts from a clean state.

### Helpers
Actions are named after what a player does. Each one sends the same event the game would:

```lua
local ag = loader.load()                  -- fresh addon
helpers.set_bet("500")                    -- what the host typed in the gold box
helpers.set_channel("PARTY")
helpers.click_stage()                     -- the stage button: New Game → Last Call → Start Rolling → Status
helpers.say("Jayred", "1")                -- CHAT_MSG_PARTY from a player
helpers.roll("Jayred", 57, 1, 500)        -- CHAT_MSG_SYSTEM "Jayred rolls 57 (1-500)"
helpers.advance(35)                       -- move the clock forward and run due timers

assert.is_true(helpers.chat_contains("owes"))
assert.are.same(-443, ag.db.global.rankings["Piyu"])
```

`helpers.roll` builds its text from `RANDOM_ROLL_RESULT` (the English `"%s rolls %d (%d-%d)"` by default), so the Spanish version can be added later for bug #3.

## 7. Milestones

### Milestone 1: The tools run
- [x] **`spec/Dockerfile`**: Alpine 3.20 with Lua 5.1, LuaRocks and busted 2.2.0 (pinned). The image builds in about 30 seconds and holds only the tools; the repo is mounted at `/addon` when the tests run, so code changes never need a rebuild.
- [x] **`.busted`** pointing at `spec/` with the `_spec` pattern. Specs can `require("spec.support.<name>")` from the repo root.
- [x] **`scripts/test.ps1`** builds the image (cached after the first run) and runs busted. Any arguments go straight to busted:
  - `.\scripts\test.ps1` runs everything;
  - `.\scripts\test.ps1 spec\round_spec.lua` runs one file;
  - `.\scripts\test.ps1 --filter "HiLo"` runs the tests whose name matches.

  A failing test exits with code 1.
- [x] **`spec/toolchain_spec.lua`** checks the environment itself: Lua 5.1, with `table.getn` available.
- [x] **`.github/workflows/tests.yml`** builds the same image and runs it on every push and pull request. It still has to be confirmed on GitHub after the first push.
- [x] **Update `paths-ignore` in `release.yml`** (see *Files*).

### Milestone 2: The addon loads
- [ ] Write `clock.lua`, `wow_api.lua`, `ace_stubs.lua`, `ui_stub.lua` and `loader.lua`.
- [ ] **Smoke test:** the addon loads and initializes with no errors, both slash commands are registered, and the default database values are in place.

### Milestone 3: Rules in isolation
- [ ] **`utils_spec.lua`:** `SplitString`, `sortedpairs` (with and without a sort function), `TableLength`, `CopyTable` and `deepcopy`.
- [ ] **`game_modes_spec.lua`:** for every mode in `GAME_MODES`, check the roll range for a given bet (`init_game`), `roll_to_score`, `sort_rolls` (winner first, loser last) and `payout`.
  - HiLo and Inverse pay the difference, and Curling pays the distance to the target.
  - Big2s, LilOnes and Yahtzee pay the full bet.
- [ ] **Yahtzee's broken cases** from bug #2 are written as `pending`, with the correct expected results.

### Milestone 4: Full rounds
- [ ] **`round_spec.lua`:**
  - a complete HiLo round: welcome message, joins, *Last Call*, automatic start after 10 seconds, rolls, the result message and the rankings update;
  - the `AG_NEW_GAME` and `AG_END_GAME` addon messages and their fields;
  - fewer than 2 players cancels the round;
  - banned players can't join, a second `1` from the same player is ignored, and joins stop once rolling starts;
  - rolls with the wrong range, and rolls from players who didn't join, are ignored.
- [ ] **`tiebreaker_spec.lua`:**
  - winners' tiebreaker;
  - losers' tiebreaker;
  - everyone tied, including HiLo and Inverse (`everyone_tied_removes`);
  - a tie inside a tiebreaker.
- [ ] **`timeout_spec.lua`:** one test per row of the README's *Roll Time Limit* table, plus the warning 10 seconds before the end that lists who still has to roll.
  - Use the `ROLL_TIME_LIMIT` constant ([AztecGambling.lua:9](../AztecGambling.lua#L9), currently 45 seconds) rather than hardcoding a number. The README says 60; that mismatch is tracked in the next plan.
- [ ] **`modes_flow_spec.lua`:**
  - **Countdown:** the roll-off, alternating turns, `AG_TURN_UPDATE`, and the player who rolls a 1 losing.
  - **Blackjack:** `hit`, `stand`, busting, a natural 21 and the automatic stand at timeout.
  - **Curling:** the result against a fixed target.
  - **Yahtzee:** each player's hand announced before the payout.
- [ ] **Spanish rolls (for bug #3):** copy the real `RANDOM_ROLL_RESULT` from a Spanish client (`/dump RANDOM_ROLL_RESULT`). Add a `pending` test that plays a round with it.

### Milestone 5: Companion window, commands and globals
- [ ] **`client_spec.lua`:** `AGClient` reads `AG_NEW_GAME`, `AG_TURN_UPDATE` and `AG_END_GAME` and shows the right text. Auto-show respects `auto_pop`, and the host's own messages don't open the host's companion window.
- [ ] **`protocol_spec.lua`:** a fake network passes every `SendCommMessage` from the host to the companion's registered callbacks. After each step of a round, the companion's `current_game` has to match the host's game.
- [ ] **`slash_spec.lua`:** `/ag ban`, `unban`, `resetStats`, `resetBans` and `auto` change the database as expected, and an unknown command prints the help hint.
- [ ] **`globals_spec.lua`:** load the addon in a clean environment and compare the globals it creates against an allow list.
  - The list starts with today's leaked globals, so the test passes now.
  - Fixing bug #8 then means removing names from the list, and a new leak fails the test right away.

## 8. Done When

- [ ] `scripts/test.ps1` runs every test locally, and CI runs them on every push and pull request.
- [ ] Every milestone above is complete, with every known bug written as a `pending` test.
- [ ] The README gets a short *Running the tests* section for contributors.
- [ ] The *Automated tests outside the game* item in [improvements.md](improvements.md) is checked off.
