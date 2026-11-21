# Polestar Quest Completion

- Write public repository content in English, including documentation, commit messages, issue and pull request text, and release notes. Keep in-game translations in their target languages, with English as the fallback.
- Keep the addon lightweight by reusing Polestar's quest data and UI and the game's quest status APIs. Keep the code compatible with Lua 5.1 and WoW: Forever.
- Keep `PolestarQuestCompletion.toc` and the runtime source at the repository root. List runtime files in load order in the TOC. Keep generated archives in the build output directory.

## Packaging

Use BigWigs Packager v2.6.0 or later from the checkout root. This command builds the ZIP under `.release/` with uploads disabled. [BigWigs Packager](https://github.com/BigWigsMods/packager)

```sh
bash /path/to/packager/release.sh -d -g forever
```

Check that the ZIP has a single `PolestarQuestCompletion/` directory at its root and that the matching TOC and all referenced Lua files are inside it. `.pkgmeta` records the required dependency on Polestar Guides.

## CurseForge publication

Create a World of Warcraft project with the **Addons** class and **Quests & Leveling** category in the CurseForge author dashboard. Provide an English title, summary, and description, a project icon, and the author's chosen license. Set **Manage Project → Source** to `https://github.com/Syntax555/PolestarQuestCompletion`. [CurseForge project submission guide](https://support.curseforge.com/support/solutions/articles/9000199552-project-submission-guide-and-tips)

For a direct upload, submit the built ZIP as **Beta** for **WoW Forever 1.60.1**, and select **Polestar Guides** (project `1744437`) as a required dependency under **Related Projects**. Automatic publication can use a CurseForge repository webhook or a BigWigs Packager upload workflow. [CurseForge file uploads](https://support.curseforge.com/support/solutions/articles/9000197241-creating-and-submitting-a-project) · [Automatic packaging](https://support.curseforge.com/support/solutions/articles/9000197281-automatic-packaging) · [Polestar Guides](https://www.curseforge.com/wow/addons/polestar)
