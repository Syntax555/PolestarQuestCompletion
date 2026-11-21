# Polestar Quest Completion

**0.1.2-beta** adds a quest completion tab to Polestar for World of Warcraft: Forever. Browse quests by zone, search by name or ID, and see how many your character has completed. The addon uses Polestar's quest data and WoW's quest status APIs.

The tab follows the WoW client language. It supports English, German, Spanish (Spain and Latin America), French, Korean, Brazilian Portuguese, Russian, Simplified Chinese, and Traditional Chinese. Other clients use English.

## Install

1. Install the full Polestar release. Enable `Polestar_QuestDB` in the character selection AddOns menu and enable **Quest database** under **Polestar Options → Questing → Quests**. [Polestar releases](https://github.com/fitzforge/polestar/releases)
2. Download the source from **Code → Download ZIP** and extract it. Create `PolestarQuestCompletion` in `World of Warcraft/_forever_/Interface/AddOns/`, then copy `PolestarQuestCompletion.toc` and the Lua files listed in it into that folder. Keep the relative paths from the TOC. [Download source](https://github.com/Syntax555/PolestarQuestCompletion/archive/refs/heads/main.zip)
3. Restart the game fully, log in, and enter `/pqc` or `/polestarquests`.

CurseForge distribution is pending. For a packaged ZIP from a source checkout, see the [packaging instructions](AGENTS.md#packaging).

## Quest progress

- The zone total includes quests in Polestar's database that match your character. Search and filters narrow the visible list. Some quest paths are mutually exclusive, so a zone can stay below 100%.
- **Offered now** means the game is currently offering the quest through the open quest or gossip window. **Likely available** means it passed known checks. Completion, quest log membership, and readiness to turn in come directly from the game.
- Hover over a quest to see known prerequisites. **Check reputation** and **Check profession** identify values the client could not confirm. Some quests have conditions that the client or Polestar's database cannot report.
- Select **Reputation & details** to load `Polestar_Codex` on demand. If Polestar already loaded it, the data is available immediately. The tooltip can show the required and current reputation or profession rank when those values are available. A Codex reputation requirement can also apply to a reward. Select a quest to open Polestar's Lookup.

## Compatibility

Targets WoW: Forever 1.60.1 (interface `16001`). The addon uses the Polestar 0.4.1.1 stable and 0.4.2 prerelease APIs. Live game testing is pending. [Polestar 0.4.1.1](https://github.com/fitzforge/polestar/releases/tag/v0.4.1.1) · [Polestar 0.4.2](https://github.com/fitzforge/polestar/releases/tag/v0.4.2)
