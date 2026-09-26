# Pending Improvements

Code review done against commit `1fe80e8`. Line numbers refer to that commit and may shift as the code changes.

**Suggested priority:** start with bugs 1, 2, 3 and 8. They are self-contained and don't change how the games play.

## 1. Bugs

- [ ] **1. The Trade button throws a Lua error when there's no active game** — [AztecGambling.lua:972](../AztecGambling.lua#L972), [AGClient.lua:166](../AGClient.lua#L166)
  - **Problem:** `OpenTradeWinner()` reads `self.game.data.winner` (and `self.current_game.winner` in the client) without checking that a game exists. Pressed before the first game or after *Reset*, `game.data` is `nil` and it fails with *"attempt to index a nil value"*. The original addon had this check; PR #1 removed it.
  - **Problem 2:** it always opens a trade with the winner, even when the player pressing the button is the winner (it tries to trade with themselves).
  - **Fix:** check that there's a game with a winner before doing anything. If the player is the winner, open the trade with the loser; otherwise, with the winner.

- [ ] **2. Yahtzee scoring is wrong** — [AGGameModes.lua:213-241](../AGGameModes.lua#L213-L241)
  - **Problem:** the scores of the different hands overlap:
    - "Singles, 9 High" scores 9 and beats a pair of 1s, 2s, 3s or 4s (which score 2 to 8).
    - A pair of 0s scores `2 + total` and beats a pair of 9s. For example, `00987` scores 28, while a pair of 9s scores 18.
    - Every four-of-a-kind scores 80, every full house 75 and every three-of-a-kind 30, regardless of the digit. Two hands of the same type with different digits tie and force an unnecessary reroll.
  - **Fix:** score by category, so any hand in a category always beats any hand in a lower one (Yahtzee > four-of-a-kind > full house > three-of-a-kind > pair > high card), and break ties within a category by digit. Decide whether a 0 counts as 0 or 10.

- [ ] **3. Rolls aren't detected when the host plays in another language** — [AztecGambling.lua:810](../AztecGambling.lua#L810)
  - **Problem:** `RollCallback` reads the `/roll` system message by word position, expecting the English format *"Jayred rolls 57 (1-100)"*. On a Spanish (esMX/esES) client the system message is different, so the addon doesn't register any rolls. This matters on US realms, where many Latin American players use the Spanish client.
  - **Fix:** build the match pattern from the `RANDOM_ROLL_RESULT` global string, which the game already localizes for the client's language. Account for locales that use positional arguments (`%1$s`).

- [ ] **4. Say mode likely doesn't work in the open world** — [AztecGambling.lua:51](../AztecGambling.lua#L51), [AztecGambling.lua:104](../AztecGambling.lua#L104)
  - **Problem:** on retail, Blizzard blocks automatic addon messages to Say and to custom channels outside instances unless they come directly from a click. That would affect the automatic start after *LastCall* (10-second timer) and the result announcement (triggered by the last roll). **Needs to be confirmed in-game.**
  - **Problem 2:** in Say mode, the notifications to the companion window are sent over the GUILD addon channel (`addon_const = "GUILD"`), so players outside the guild don't get the pop-up.
  - **Fix:** test it first. If confirmed, make automatic messages in Say wait for a click from the host (for example, the *Status* button), or remove Say as an option outside instances.

- [ ] **5. Reset doesn't notify players** — [AztecGambling.lua:517](../AztecGambling.lua#L517)
  - **Problem:** `ResetGame()` doesn't send any addon message, so the players' companion window keeps showing the cancelled game. It also doesn't close the *Roll Status* window, which `EndGame()` does.
  - **Fix:** send a reset addon message that clears the game in `AGClient`, and release `AG_RollFrame` the same way `EndGame()` does.

- [ ] **6. The gold amount isn't properly validated** — [AztecGambling.lua:576](../AztecGambling.lua#L576)
  - **Problem:** it accepts `0`, which produces a `(1-0)` roll range. If text is entered, it silently falls back to 100 without telling the host.
  - **Fix:** require a number greater than 0 and tell the host (for example, with `self:Print`) when the value is invalid, instead of changing it silently.

- [ ] **7. The custom channel (`/ag join`) is half-finished** — [AztecGambling.lua:81](../AztecGambling.lua#L81), [AGCommon.lua:75](../AGCommon.lua#L75)
  - **Problem:** `/ag join` joins the channel, but that channel isn't in the chat channel dropdown (only Say, Party and Raid are), so games can't be run there. The channel is also left on `PLAYER_LEAVING_WORLD`, which fires on every loading screen, not just when logging out.
  - **Fix:** decide whether to keep the feature. If kept, add the channel to the dropdown while the player is in it, and only leave it on logout (`PLAYER_LOGOUT`). If not, remove `/ag join` and `/ag leave`.

- [ ] **8. Leaked global variables** — for example [AGCommon.lua:103](../AGCommon.lua#L103), [AztecGambling.lua:605](../AztecGambling.lua#L605), [AGGameModes.lua:166](../AGGameModes.lua#L166)
  - **Problem:** variables such as `player`, `label`, `total`, `score`, `hand`, `command`, `command_args`, `winner`, `loser`, `player_score`, `channel_number`, `GAME_MODES`, `GAME_STAGES` and `on_mouse_down` are assigned without `local`, so they end up as game-wide globals. They can clash with other addons using the same names and cause "taint" errors in Blizzard's UI.
  - **Fix:** declare them `local` where they're used.

## 2. New Features

- [ ] **Trade that fills in the gold automatically.** The original addon did this on the second click, with the trade window already open, using `SetTradeMoney` (see commit `e61f67f`, function `OpenTradeWinner`). PR #1 removed it. Needs testing to make sure it still works on the current client.
- [ ] **Hit and Stand buttons** in the companion window for Blackjack. Today players have to type `hit` or `stand` in chat.
- [ ] **Roulette mode.** It's already written in [AGGameModes.lua:134](../AGGameModes.lua#L134) (roll 1-6, whoever rolls a 1 loses), but it isn't in the `GAME_MODES` list at [AztecGambling.lua:133](../AztecGambling.lua#L133). It just needs to be added and tested.
- [ ] **Remove `AG_MYSTERY`** ([AGGameModes.lua:34](../AGGameModes.lua#L34)): it's dead code, a duplicate of HiLo with the same label.
- [ ] **Curling with a hidden target.** The target number is currently announced when the game starts ([AGMessages.lua:90](../AGMessages.lua#L90)), which takes the fun out of it. Reveal it only at the end.
- [ ] **Guild in the chat channel dropdown.** It already exists internally; it's just hidden at [AztecGambling.lua:81](../AztecGambling.lua#L81).
- [ ] **Spanish translation** of the UI and chat messages. The strings are already collected in `AGMessages.lua`, and the AceLocale library is already bundled in `libs/`.
- [ ] **An option to see `/ag stats` privately.** It's currently always posted to the group chat.

## 3. Maintenance and Publishing

- [ ] **Update the interface numbers in the `.toc` files.** `AztecGambling_Wrath.toc` (`30402`, Wrath Classic 3.4.2) no longer matches any live client: Wrath Classic became Cataclysm Classic in 2024 and then Mists of Pandaria Classic. `AztecGambling_Vanilla.toc` (`11403`) is from Classic Era 1.14.3, which is now on 1.15.x. To get a client's number: `/dump select(4, GetBuildInfo())`.
- [ ] **Own version numbering.** For now, `## Version` follows the retail WoW version: `12.1.0` in all three `.toc` files, matching Interface `120100`. Later, switch to the addon's own version numbering.
- [ ] **Automated releases.** A `.pkgmeta` plus a GitHub Action running the BigWigs packager can publish to CurseForge and Wago. The zip comes out with the right folder name (`AztecGambling`, not `AztecGambling-main`) and without `docs/` or `.github/`.
- [ ] **Automated tests outside the game.** The game logic (joins, rolls, scoring, tiebreakers and the roll time limit) is plain Lua, so it can be tested without the game client. Changes like issue #4 could then be checked before testing them in-game.
  - **Setup:** Lua 5.1 (the version WoW uses) with the [busted](https://lunarmodules.github.io/busted/) test framework, run in a Docker container so nothing has to be installed on Windows. Lua 5.4, which is what `winget` installs, doesn't work: the addon uses `table.getn`, which was removed after Lua 5.1.
  - **WoW API stubs** in a `spec/` folder:
    - `SendChatMessage` records each message, so tests can check what was announced.
    - `GetTime` and the timers use a fake clock that tests move forward by hand. For example, a test can jump 50 seconds to check the 10-second warning without waiting.
    - AceGUI windows and the minimap icon are empty objects that accept any call.
    - Ace3 isn't loaded. Only the parts the addon uses are stubbed: events, timers, the database and addon messages.
  - **Tests** play a round by calling the same functions the game calls: a player typing `1` in chat (`ChatChannelCallback`), the `/roll` system message (`RollCallback`, e.g. *"Jayred rolls 57 (1-100)"*), and moving the clock forward. Start with the roll time limit cases from issue #4 and the scoring of each game mode.
  - **CI:** the same setup can run on GitHub Actions on every push and pull request.
  - **Not covered:** how the windows look, Blizzard's restrictions (such as Say outside instances), `/roll` messages in other client languages, and the addon messages between the host and the companion window. These still need an in-game test.
  - Leave `spec/` out of the release zip (see *Automated releases*).
- [ ] **Developer test command.** A command such as `/ag test` that adds fake players to the current round and rolls for them. The host could then play a full round in-game alone, without gathering other players.
- [ ] **Clean up `docs/`.** `buttons.md` and `callbacks.md` describe an XML UI that no longer exists, and `description.md` still mentions "FOUR NEW game modes" and buttons that don't exist (Print Stats, Print Bans, a button that cycles through modes).

## 4. Pending README Fixes

- [ ] **Payout / Known Issues:** the button is called **Trade** in both windows and it works (it opens a trade with the winner). What it doesn't do is fill in the gold. Update row 1 of the main window, the companion window section, step 5 of *How a Round Works* and the **Known Issues** section.
- [ ] **There's no "Start!" button:** the stage button shows the current stage (**NewGame → LastCall → StartRoll → Status**). Fix steps 1 and 3, and explain that *LastCall* announces in chat and starts rolls automatically after 10 seconds. When the round ends, the button goes back to *NewGame* on its own.
- [ ] **`/ag` and the minimap icon don't open the casino directly:** they cycle companion window → casino → hidden ([AGCommon.lua:5-13](../AGCommon.lua#L5-L13)). Fix step 3 of *Installation*. `/agm` does open the casino directly.
- [ ] **Curling:** the target number is announced at the start (it isn't secret), and the loser pays the distance between their roll and the target, not the full bet ([AGGameModes.lua:324](../AGGameModes.lua#L324)). If the hidden target gets implemented, update accordingly.
- [ ] **"Roll for Me" doesn't exist:** the button is called **Roll!**.
- [ ] **`/agm` is listed as a "Legacy alias":** describe it as "opens the casino window".
- [ ] **`/ag stats` posts to the group chat:** mention this in the command table.
