# Aztec Gambling

Aztec Gambling is a World of Warcraft addon for running group gambling games over `/roll` in Raid, Party, or Say chat. One person runs the "casino" from the main window; everyone else can play along with a lightweight companion window that pops up automatically when a round starts.

Only the host needs the addon installed — anyone else can join by typing `1` in the game's chat channel and rolling with `/roll`. The companion window is just a convenience.

## Requirements

- Interface: `120100` (see `AztecGambling.toc` / `_Vanilla.toc` / `_Wrath.toc` for the version matching your client)
- Bundled libraries (no separate download needed): Ace3, LibDBIcon-1.0

## Installation

1. Copy the `AztecGambling` folder into your `Interface/AddOns` directory.
   - If you downloaded the ZIP from GitHub, the extracted folder is named `AztecGambling-main` — rename it to `AztecGambling`, or WoW won't load the addon (the folder name must match the `.toc` name).
2. Enable it at the character select screen (or in-game addon list).
3. Click the coin minimap icon, or type `/ag`, to open the casino window.

## How a Round Works

1. **Host** picks a chat channel, a game mode, and a gold amount, then presses **Start!** to open entries.
2. **Players** join by pressing **Enter** in the companion window (or typing `1` in the chosen chat channel).
3. The host presses **Start!** again to close entries and begin accepting rolls — every player rolls the range shown in chat (or clicks **Roll!**/uses **Roll for Me**).
   - Players have **1 minute** to roll. Pressing **Status** posts in chat who still needs to roll and how many seconds are left. Nothing happens automatically when time runs out — the host decides whether to keep waiting or **Reset** the round.
4. Once everyone has rolled, the addon scores the round, resolves ties automatically with a reroll among the tied players, and announces the result: `<loser> owes <winner> <amount> gold!`
5. Settle up in-game (currently manual — see [Known Issues](#known-issues)), then press **Start!** again for a new round, or **Reset** to cancel the current one.

## Game Modes

Selected from the mode dropdown in the **Casino** box. All modes pay out the bet entered in the gold field unless noted otherwise.

| Mode | Roll Range | Rule |
|---|---|---|
| **HiLo** | 1 – bet amount | Highest roll wins; the lowest roller pays them the *difference* between the two rolls. |
| **Inverse** | 1 – bet amount | The mirror of HiLo: lowest roll wins, and the highest roller pays them the difference. |
| **Big2s** | 1 – 2 | Coin-flip HiLo — highest of a 1-or-2 roll wins the full bet. Ties (and there will be many) trigger a reroll. |
| **LilOnes** | 1 – 2 | The mirror of Big2s — lowest of a 1-or-2 roll wins the full bet. |
| **Yahtzee** | 11111 – 99999 | Roll is read as 5 dice. Scored like Yahtzee (five-of-a-kind > four-of-a-kind > full house > three-of-a-kind > doubles > high card); best hand wins the full bet. Everyone's hand is announced in chat before payout. |
| **Curling** | 1 – bet amount | The host's roll range hides a secret target number. Closest roll to the target wins; the loser pays the full bet, and the addon reveals how close the bullseye was. |
| **Countdown** | 1 – bet amount (1v1 only) | A roll-war between exactly two players. Whoever rolls first is decided by a 1-100 roll-off; from there each roll sets the ceiling for the opponent's next roll. Whoever rolls a 1 loses the full bet. |
| **Blackjack** | 1 – 21, then hits of 1 – 10 | Roll your starting hand (1-21). A natural 21 stands automatically. Otherwise, type `hit` in chat to draw again (adds a 1-10 roll to your total) or `stand` to lock it in. Busting past 21 is an automatic loss; closest to 21 without busting wins the full bet. |

## Main Window (Casino / Host)

- **Row 1:** `Enter` (send a `1` on your own behalf), `Roll!` (roll the current range for yourself), `Payout` (currently disabled — see [Known Issues](#known-issues)).
- **Casino box:**
  - **Row 2:** gold amount entry, chat channel select (Say / Party / Raid), game mode select.
  - **Row 3:** the game stage button (cycles New Game → Last Call → Start Rolling → Status, and shows the current stage as its label), `Reset` (cancels the active round), `PAY!` (re-announces the last payout message, in case it was missed or a new round started before anyone settled up).
- Right-click the window to swap to the companion client window.

## Companion Window (Players)

Pops up automatically for anyone with the addon installed when a round starts on their channel (toggle this with `/ag auto`). Buttons: `Enter`, `Roll` (rolls the correct range automatically), `Payout` (currently disabled — see [Known Issues](#known-issues)).

## Slash Commands

All commands are under `/ag`:

| Command | Effect |
|---|---|
| `/ag` | Toggle the casino or companion window (same as clicking the minimap icon). |
| `/ag auto` | Toggle whether the companion window auto-opens when a round starts. |
| `/ag stats` | Print the Hall of Fame/Shame (lifetime gold won/lost per player). |
| `/ag resetStats` | Clear the Hall of Fame/Shame. |
| `/ag ban <player>` | Prevent a player from entering rounds. |
| `/ag unban <player>` | Remove a player from the ban list. |
| `/ag resetBans` | Clear the ban list. |
| `/ag join [channel]` | Join (or create) a custom gambling chat channel for your guild. |
| `/ag leave` | Leave the custom gambling channel. |
| `/ag help` | Print this command list in-game. |
| `/agm` | Legacy alias for opening the casino window. |

## Known Issues

- **Payout** is disabled on both windows — it isn't wiring up the trade window correctly right now. Use the **PAY!** button (or just read the chat message) to see who owes whom, and trade manually.

## Credits

### Aztec Gambling

- [PiyuDevelop](https://github.com/PiyuDevelop)
- Angel Quinones

### Calm Down and Gamble (original addon)

Aztec Gambling is based on [Calm Down and Gamble](https://github.com/manistal/calmdownandgamble) (2015–2023), also published on [CurseForge](https://www.curseforge.com/wow/addons/calm-down-and-gamble).

- **Fuzz** Magtheridon-US (Mal'Ganis-US) — original author (`metafuzz` on CurseForge).
- **Miguel Nistal** ([manistal](https://github.com/manistal)) — main developer and owner of the original repository.
- **Phones** ([phoones](https://github.com/phoones)) — Developer.
- [ejwagner713](https://github.com/ejwagner713) — Contributor.
- **Spikedude** — Beta Tester.
- **[Calm Down] US-Magtheridon** — a raiding guild with a gambling problem, and the guild that made this necessary.
