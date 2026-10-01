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
- **Tests never lock in a bug.** When a test finds a bug, add it to [improvements.md](improvements.md) and write the test for the *correct* behavior with `known_bug("... (bug #N)", function() ... end)` (`spec/support/known_bug.lua`).
  - It's reported as pending, so the run stays green, and it becomes an `it` when the bug is fixed.
  - **Every `known_bug` test must fail against the current code**, or it doesn't document anything. With `AG_CHECK_KNOWN_BUGS=1`, each one runs and must fail. CI checks this on every push. Locally: `$env:AG_CHECK_KNOWN_BUGS = "1"; .\scripts\test.ps1`.
  - Plain `pending` is left for open decisions with no test yet, such as how a 0 counts in Yahtzee.
- **Set globals in specs through `_G`** (`_G.RANDOM_ROLL_RESULT = ...`, or a helper that does it). busted gives each spec file its own globals, so a plain assignment there never reaches the addon or the helpers, and the test silently runs without it.
- **Compare scores, not order, to check that one roll beats another.** Two rolls that wrongly tie can come out of a sort in either order, so a check on the order can pass by luck. Order checks are fine when every score is different.
- **Every test starts clean:** fresh addon, fresh database, clock at zero, empty message logs.
- **Work on a branch from `main`** (for example `tests`) and merge it before starting the next plan, so the bug fixes branch already has the tests.

## 4. Tools

| Tool | Why |
|---|---|
| **Lua 5.1** | The Lua version WoW uses. Lua 5.4, which `winget` installs, doesn't work: the addon calls `table.getn`, which was removed after 5.1. |
| **[busted](https://lunarmodules.github.io/busted/)** | The usual Lua test framework: `describe`/`it`, assertions, `pending`, stubs and spies. |
| **[luacheck](https://luacheck.readthedocs.io)** | Static analysis. It finds leaked globals and unused variables even in code the tests never run. |
| **[luacov](https://lunarmodules.github.io/luacov/)** | Test coverage: which lines of the addon the tests run, and which they never do. |
| **Docker** | Runs Lua 5.1 and the three tools above without installing anything on Windows, and uses the same environment locally and in CI. Docker Desktop is already installed and has to be running. |
| **GitHub Actions** | Runs the tests, the known-bug check and luacheck on every push and pull request, and shows the coverage summary. |

## 5. Files

```
AztecGambling/
├── .busted                  -- busted configuration
├── .luacheckrc              -- luacheck configuration
├── .luacov                  -- luacov configuration
├── .gitignore               -- leaves out the coverage output files
├── spec/
│   ├── Dockerfile           -- Lua 5.1 + busted + luacheck + luacov image
│   ├── support/
│   │   ├── clock.lua        -- fake clock and timer queue
│   │   ├── wow_api.lua      -- WoW API stubs
│   │   ├── ace_stubs.lua    -- LibStub and minimal Ace3 / LibDBIcon stand-ins
│   │   ├── ui_stub.lua      -- stand-in object for AceGUI widgets
│   │   ├── loader.lua       -- loads the addon files in .toc order and initializes them
│   │   ├── helpers.lua      -- actions (join, roll, wait), the fake network and log queries
│   │   ├── known_bug.lua    -- known_bug(): pending tests that must still fail
│   │   └── exercise.lua     -- runs as much of the addon as possible (for globals_spec)
│   └── *_spec.lua           -- the tests
├── scripts/
│   ├── test.ps1             -- builds the image and runs the tests from Windows
│   ├── lint.ps1             -- runs luacheck
│   └── coverage.ps1         -- runs the tests with luacov and prints the coverage summary
└── .github/workflows/
    └── tests.yml            -- CI
```

- **`spec/` never goes into the release zip.** [release.yml](../.github/workflows/release.yml) only copies the `.toc`, `*.lua`, `libs` and `LICENSE`.
- **The test files are in the `paths-ignore` list of `release.yml`:** `spec/**`, `scripts/**`, `.busted`, `.luacheckrc`, `.luacov`, `.gitignore` and `.github/workflows/tests.yml`. Otherwise, a push that only changes tests would create a new release.

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
- [x] Write `clock.lua`, `wow_api.lua`, `ace_stubs.lua`, `ui_stub.lua` and `loader.lua`. The loader reads the file order from `AztecGambling.toc`, so new files are picked up automatically.
- [x] **`load_spec.lua`** (smoke test):
  - the addon loads and initializes with no errors;
  - both slash commands are registered;
  - the default database values are in place, and settings saved in a previous session are restored;
  - the minimap button and the companion window's listeners are set up;
  - nothing is sent while loading;
  - every load starts clean.

  It also checks that the three `.toc` files load the same addon files.
- [x] **`fake_clock_spec.lua` and `ace_stubs_spec.lua`:** every roll time limit test depends on the fake clock and the stand-ins, so their behavior has its own tests:
  - timer order;
  - repeating and cancelled timers;
  - callback arguments;
  - a second registration of the same event replacing the first.

### Milestone 3: Rules in isolation
- [x] **`utils_spec.lua`:** `SplitString`, `sortedpairs` (with and without a sort function), `TableLength`, `CopyTable` and `deepcopy`.
- [x] **`game_modes_spec.lua`:** for every mode in `GAME_MODES`, check the roll range for a given bet (`init_game`), `roll_to_score`, `sort_rolls` (winner first, loser last) and `payout`.
  - HiLo and Inverse pay the difference, and Curling pays the distance to the target.
  - Big2s, LilOnes, Yahtzee, Countdown and Blackjack pay the full bet.
  - Countdown has no `roll_to_score` or `sort_rolls`, because it's decided turn by turn; its flow is tested in Milestone 4.
- [x] **Yahtzee's broken cases** from bug #2 are written as `pending`, with the correct expected results. Each one was checked to fail against the current code.
  - A fourth `pending` entry, with no test, records the open decision on whether a 0 counts as 0 or 10.

### Milestone 4: Full rounds
- [x] **`helpers.lua`:** the host's and players' actions (set the bet, channel and mode, click the stage button, type in chat, `/roll`), the clock, and queries on what was sent.
  - Chat events carry `Name-Realm`, as the game sends them, so the addon's `Ambiguate` is exercised.
  - `roll()` reads the range from `roll_range`, which is what players are told to roll and the only thing that changes in Countdown's roll-off.
- [x] **`round_spec.lua`:**
  - a complete HiLo round: welcome message, joins, *Last Call*, automatic start after 10 seconds, rolls, the result message and the rankings update;
  - the `AG_NEW_GAME` and `AG_END_GAME` addon messages and their fields;
  - fewer than 2 players stops the rolls from starting, and the host can try again;
  - banned players can't join, a second `1` from the same player is ignored, and joins stop once rolling starts;
  - rolls with the wrong range, rolls from players who didn't join, and other system messages are ignored;
  - the Status, PAY!, Trade, Reset, Enter and Roll! buttons;
  - `pending` tests for bugs #1, #3, #5, #6 and #9.
- [x] **`tiebreaker_spec.lua`:**
  - winners' tiebreaker;
  - losers' tiebreaker;
  - both, in order;
  - a tie inside a tiebreaker;
  - everyone tied.
- [x] **`timeout_spec.lua`:** one test per row of the README's *Roll Time Limit* table, plus the warning before the end that lists who still has to roll, and each roll phase getting its own time limit.
  - `ROLL_TIME_LIMIT` is a local variable, so the tests read the time left from the round's deadline instead of hardcoding 45 seconds.
  - The README says 60; that mismatch is tracked in the next plan.
- [x] **`modes_flow_spec.lua`:**
  - **Countdown:** the roll-off (and its reroll on a tie), alternating turns, `AG_TURN_UPDATE`, out-of-turn rolls, the 2-player limit, and the player who rolls a 1 losing.
  - **Blackjack:** `hit`, `stand`, busting, a natural 21, a hit reaching 21, and hits from players who are done.
  - **Curling:** the result against a fixed target.
  - **Yahtzee:** each player's hand announced before the payout.
  - **Inverse, Big2s and LilOnes:** a quick round each.
- [x] **Spanish rolls (for bug #3):** `RANDOM_ROLL_RESULT` is `"%s tira los dados y obtiene %d (%d-%d)"` on both esMX and esES, taken from Wago Tools' GlobalStrings table. The `pending` test plays a round with it.
- [x] **Checked that the tests catch real changes:** four deliberate changes to `AztecGambling.lua` were each caught by the expected test:
  - several no-shows in a losers' tiebreaker treated as one;
  - Last Call waiting 5 seconds instead of 10;
  - the player limit ignored;
  - the loser's payout recorded with the wrong sign.
- **Found while writing these tests,** and added to [improvements.md](improvements.md):
  - bug #9: an empty chat message is sent every time rolls start;
  - bug #10: rolls from players on another realm may be ignored. It needs an in-game check.

### Milestone 5: Companion window, commands and globals
- [x] **`client_spec.lua`:** `AGClient` reads `AG_NEW_GAME`, `AG_TURN_UPDATE` and `AG_END_GAME` and shows the right text.
  - Auto-show respects `auto_pop`, and the host's own messages don't open the host's companion window.
  - Covers Roll, Enter and Trade, and how rolls are shared in Guild and Say rounds.
  - Bug #1 is written as `pending` tests for the companion window too.
- [x] **`protocol_spec.lua`:** `helpers:deliver_addon_messages()` passes every `SendCommMessage` from the host to the companion window's callbacks, as if another player were hosting. After each step of a HiLo, Countdown and Blackjack round, the companion window has to agree with the host on what to roll and how the round ended. Pending tests for bugs #5 and #11.
- [x] **`slash_spec.lua`:**
  - `/ag ban`, `unban`, `resetBans`, `stats`, `resetStats`, `auto`, `debug` and `help`, and an unknown command;
  - the `/ag` window cycle and `/agm`;
  - saving the window position;
  - `join` and `leave`.

  Pending tests for bugs #7 and #12.
- [x] **`globals_spec.lua`:** runs as much of the addon as possible (`spec/support/exercise.lua`: a round of every mode, tiebreakers, timeouts, every button and slash command, the companion window). Then it compares the globals created against two lists:
  - **`INTENDED`:** the addon objects, their SavedVariables, and the tables the files share.
  - **`KNOWN_LEAKS`:** today's 21 leaked globals.

  A new leak fails the first test. A leak that gets fixed fails the second until it's removed from the list, so the list stays accurate until it's empty.
- **Found while writing these tests,** and added to [improvements.md](improvements.md):
  - bug #11: after a Blackjack tie, the companion window rolls the wrong range;
  - bug #12: joining the custom channel stops the window position from being saved;
  - `/ag join` without a channel name fails for a player with no guild (added to bug #7).

### Milestone 6: Filling the gaps
Added after the first five milestones, to find what the tests still missed.

- [x] **`known_bug()`** replaces `pending` for known bugs (see *Rules for This Phase*), and CI checks that each one still fails. The 17 existing bug tests were converted; only the open decision about 0s in Yahtzee stays `pending`.
- [x] **luacheck** (`.luacheckrc`, `scripts/lint.ps1`):
  - **The tests must be clean**, and CI blocks on it.
  - **The addon has 136 warnings** (leaked globals, unused variables, empty `if` branches, a reused loop variable). CI reports them without blocking until Part A of the cleanup plan clears them.
  - Unlike `globals_spec`, it also finds leaks in code that never runs, such as `winner`, `loser` and `cash_winnings` in the dead `GameResultsCallback`.
- [x] **luacov** (`.luacov`, `scripts/coverage.ps1`): the tests run **92.8%** of the addon's lines. CI shows the summary on each run's page. What never runs:
  - the current UI (the countdown bar widget, right-click and tooltip handlers), which the redesign replaces;
  - dead code (`AG_MYSTERY`, `GameResultsCallback`, `PrintBanlist`, `PrintTable`, a duplicated block in `EvaluateScores`);
  - the custom channel's `AG` option, waiting on the bug #7 decision;
  - Roulette, which isn't offered;
  - how 0s score in Yahtzee, waiting on a decision.
- [x] **New tests** for gaps found by reviewing the code and by the coverage report:
  - changing the chat channel during a round (bug #13, found here);
  - Blackjack dealing again after a tie;
  - the time warning in Countdown and in Blackjack's hit or stand phase;
  - Status in Countdown (bug #14 on the first turn, found here) and in Blackjack;
  - Reset during Last Call;
  - a losers' tiebreaker narrowing down to the players who tie for last again;
  - a winners' tiebreaker that follows a losers' tiebreaker decided by timeout.

## 8. Done When

- [x] `scripts/test.ps1` runs every test locally, and CI runs them on every push and pull request. CI was confirmed on the first push of the `tests` branch (Actions run 36808502636).
- [x] Every milestone above is complete, with every known bug that can be reproduced outside the game written as a `known_bug` test. Bugs #4 and #10 need an in-game check first.
- [x] The README has a short *Running the Tests* section for contributors.
- [x] The *Automated tests outside the game* item in [improvements.md](improvements.md) is checked off.
